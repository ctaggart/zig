const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

/// Matches musl's struct __dirstream from __dirent.h.
/// offsetof(buf) must be a multiple of sizeof(off_t) = 8.
const DIR = extern struct {
    tell: i64,
    fd: c_int,
    buf_pos: c_int,
    buf_end: c_int,
    lock: [1]c_int,
    buf: [2048]u8,
};

/// Kernel's linux_dirent64 entry header for buffer parsing.
const Dirent64 = extern struct {
    d_ino: u64,
    d_off: i64,
    d_reclen: u16,
    d_type: u8,
};

comptime {
    if (builtin.target.isMuslLibC()) {
        // Pure functions — no extern libc dependencies.
        symbol(&dirfdLinux, "dirfd");
        symbol(&readdirLinux, "readdir");
        symbol(&readdir_rLinux, "readdir_r");
        symbol(&rewinddirLinux, "rewinddir");
        symbol(&seekdirLinux, "seekdir");
        symbol(&telldirLinux, "telldir");
    }
    if (builtin.link_libc and builtin.target.isMuslLibC()) {
        // Functions depending on libc malloc/free/strcoll etc.
        symbol(&alphasortLinux, "alphasort");
        symbol(&closedirLinux, "closedir");
        symbol(&fdopendirLinux, "fdopendir");
        symbol(&opendirLinux, "opendir");
        symbol(&scandirLinux, "scandir");
        symbol(&versionsortLinux, "versionsort");
    }
}

// Extern libc functions used by the link_libc group.
extern "c" fn calloc(usize, usize) ?*anyopaque;
extern "c" fn free(?*anyopaque) void;
extern "c" fn malloc(usize) ?*anyopaque;
extern "c" fn realloc(?*anyopaque, usize) ?*anyopaque;
extern "c" fn strcoll([*:0]const u8, [*:0]const u8) c_int;
extern "c" fn strverscmp([*:0]const u8, [*:0]const u8) c_int;
extern "c" fn qsort(*anyopaque, usize, usize, *const anyopaque) void;

// Simple spinlock matching musl's volatile int lock[1].
fn dirLock(l: *c_int) void {
    while (@cmpxchgWeak(c_int, l, 0, 1, .acquire, .monotonic) != null) {}
}

fn dirUnlock(l: *c_int) void {
    @atomicStore(c_int, l, 0, .release);
}

// ── Pure functions (no libc deps) ──────────────────────────────────

fn dirfdLinux(dir: *DIR) callconv(.c) c_int {
    return dir.fd;
}

fn telldirLinux(dir: *DIR) callconv(.c) c_long {
    return @intCast(dir.tell);
}

fn readdirLinux(dir: *DIR) callconv(.c) ?*anyopaque {
    if (dir.buf_pos >= dir.buf_end) {
        const rc: isize = @bitCast(linux.getdents64(dir.fd, &dir.buf, dir.buf.len));
        if (rc <= 0) {
            if (rc < 0 and rc != -@as(isize, @intFromEnum(linux.E.NOENT))) {
                std.c._errno().* = @intCast(-rc);
            }
            return null;
        }
        dir.buf_end = @intCast(rc);
        dir.buf_pos = 0;
    }
    const pos: usize = @intCast(dir.buf_pos);
    const de: *Dirent64 = @ptrCast(@alignCast(&dir.buf[pos]));
    dir.buf_pos += @intCast(de.d_reclen);
    dir.tell = de.d_off;
    return @ptrCast(de);
}

fn seekdirLinux(dir: *DIR, off: c_long) callconv(.c) void {
    dirLock(&dir.lock[0]);
    dir.tell = @bitCast(linux.lseek(dir.fd, @intCast(off), 0));
    dir.buf_pos = 0;
    dir.buf_end = 0;
    dirUnlock(&dir.lock[0]);
}

fn rewinddirLinux(dir: *DIR) callconv(.c) void {
    dirLock(&dir.lock[0]);
    _ = linux.lseek(dir.fd, 0, 0);
    dir.buf_pos = 0;
    dir.buf_end = 0;
    dir.tell = 0;
    dirUnlock(&dir.lock[0]);
}

fn readdir_rLinux(
    dir: *DIR,
    buf: *anyopaque,
    result: *?*anyopaque,
) callconv(.c) c_int {
    const errno_save = std.c._errno().*;
    dirLock(&dir.lock[0]);
    std.c._errno().* = 0;
    const de = readdirLinux(dir);
    const ret = std.c._errno().*;
    if (ret != 0) {
        dirUnlock(&dir.lock[0]);
        return ret;
    }
    std.c._errno().* = errno_save;
    if (de) |d| {
        const hdr: *const Dirent64 = @ptrCast(@alignCast(d));
        const n: usize = hdr.d_reclen;
        const src: [*]const u8 = @ptrCast(d);
        const dest: [*]u8 = @ptrCast(buf);
        @memcpy(dest[0..n], src[0..n]);
        result.* = buf;
    } else {
        result.* = null;
    }
    dirUnlock(&dir.lock[0]);
    return 0;
}

// ── Functions requiring libc (under link_libc) ─────────────────────

fn opendirLinux(name: [*:0]const u8) callconv(.c) ?*DIR {
    const rc = linux.openat(
        linux.AT.FDCWD,
        name,
        .{ .DIRECTORY = true, .CLOEXEC = true },
        0,
    );
    const fd: isize = @bitCast(rc);
    if (fd < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-fd);
        return null;
    }
    const ptr = calloc(1, @sizeOf(DIR)) orelse {
        _ = linux.close(@intCast(fd));
        return null;
    };
    const dir: *DIR = @ptrCast(@alignCast(ptr));
    dir.fd = @intCast(fd);
    return dir;
}

fn closedirLinux(dir: *DIR) callconv(.c) c_int {
    const ret = errno(linux.close(dir.fd));
    free(@ptrCast(dir));
    return ret;
}

fn fdopendirLinux(fd: c_int) callconv(.c) ?*DIR {
    // Check the fd is valid and a directory using statx.
    var stx: linux.Statx = undefined;
    const stx_rc: isize = @bitCast(linux.statx(fd, "", 0x1000, linux.STATX.BASIC_STATS, &stx));
    if (stx_rc < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-stx_rc);
        return null;
    }
    // Reject O_PATH file descriptors.
    const fl_rc: isize = @bitCast(linux.syscall3(.fcntl, @bitCast(@as(isize, fd)), linux.F.GETFL, 0));
    if (fl_rc >= 0) {
        const fl: u32 = @truncate(@as(usize, @bitCast(fl_rc)));
        if (fl & @as(u32, @bitCast(linux.O{ .PATH = true })) != 0) {
            std.c._errno().* = @intCast(@intFromEnum(linux.E.BADF));
            return null;
        }
    }
    // Must be a directory.
    if (stx.mode & 0o170000 != 0o040000) {
        std.c._errno().* = @intCast(@intFromEnum(linux.E.NOTDIR));
        return null;
    }
    const ptr = calloc(1, @sizeOf(DIR)) orelse return null;
    const dir: *DIR = @ptrCast(@alignCast(ptr));
    dir.fd = fd;
    // Set close-on-exec.
    _ = linux.syscall3(.fcntl, @bitCast(@as(isize, fd)), linux.F.SETFD, linux.FD_CLOEXEC);
    return dir;
}

fn alphasortLinux(a: *const *const anyopaque, b: *const *const anyopaque) callconv(.c) c_int {
    // d_name is at byte offset 19 inside the dirent (after ino:8+off:8+reclen:2+type:1).
    const name_a: [*:0]const u8 = @ptrCast(@as([*]const u8, @ptrCast(a.*)) + 19);
    const name_b: [*:0]const u8 = @ptrCast(@as([*]const u8, @ptrCast(b.*)) + 19);
    return strcoll(name_a, name_b);
}

fn versionsortLinux(a: *const *const anyopaque, b: *const *const anyopaque) callconv(.c) c_int {
    const name_a: [*:0]const u8 = @ptrCast(@as([*]const u8, @ptrCast(a.*)) + 19);
    const name_b: [*:0]const u8 = @ptrCast(@as([*]const u8, @ptrCast(b.*)) + 19);
    return strverscmp(name_a, name_b);
}

fn scandirLinux(
    path: [*:0]const u8,
    res: *?[*]*anyopaque,
    sel: ?*const fn (*const anyopaque) callconv(.c) c_int,
    cmp: ?*const fn (*const *const anyopaque, *const *const anyopaque) callconv(.c) c_int,
) callconv(.c) c_int {
    const d = opendirLinux(path) orelse return -1;
    var names: ?[*]*anyopaque = null;
    var cnt: usize = 0;
    var len: usize = 0;
    const old_errno = std.c._errno().*;

    while (true) {
        std.c._errno().* = 0;
        const de_opt = readdirLinux(d);
        const de = de_opt orelse break;

        if (sel) |selector| {
            if (selector(de) == 0) continue;
        }
        if (cnt >= len) {
            len = 2 * len + 1;
            if (len > std.math.maxInt(usize) / @sizeOf(*anyopaque)) break;
            const tmp = realloc(@ptrCast(names), len * @sizeOf(*anyopaque)) orelse break;
            names = @ptrCast(@alignCast(tmp));
        }
        const hdr: *const Dirent64 = @ptrCast(@alignCast(de));
        const reclen: usize = hdr.d_reclen;
        const entry = malloc(reclen) orelse break;
        const src: [*]const u8 = @ptrCast(de);
        const dest: [*]u8 = @ptrCast(entry);
        @memcpy(dest[0..reclen], src[0..reclen]);
        names.?[cnt] = @ptrCast(entry);
        cnt += 1;
    }

    _ = closedirLinux(d);

    if (std.c._errno().* != 0) {
        if (names) |n| {
            var i = cnt;
            while (i > 0) {
                i -= 1;
                free(@ptrCast(n[i]));
            }
            free(@ptrCast(n));
        }
        return -1;
    }
    std.c._errno().* = old_errno;

    if (cmp) |comparator| {
        if (names) |n| {
            qsort(@ptrCast(n), cnt, @sizeOf(*anyopaque), @ptrCast(comparator));
        }
    }
    res.* = names;
    return @intCast(cnt);
}
