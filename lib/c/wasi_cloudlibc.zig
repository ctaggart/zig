// SPDX-License-Identifier: BSD-2-Clause
//
// Zig implementations of CloudLibc WASI libc functions.
// Migrated from lib/libc/wasi/libc-bottom-half/cloudlibc/src/libc/

const builtin = @import("builtin");
const std = @import("std");
const wasi = std.os.wasi;
const sym = @import("../c.zig").symbol;

// ========================================================
// Extern C library functions used by implementations below
// ========================================================

extern "c" fn c_close(fd: c_int) c_int;
comptime {
    if (builtin.target.isWasiLibC())
        @export(&c_close, .{ .name = "close" });
}

extern "c" fn c_malloc(size: usize) ?[*]align(@alignOf(usize)) u8;
comptime {
    if (builtin.target.isWasiLibC())
        @export(&c_malloc, .{ .name = "malloc" });
}

extern "c" fn c_free(ptr: ?*anyopaque) void;
comptime {
    if (builtin.target.isWasiLibC())
        @export(&c_free, .{ .name = "free" });
}

extern "c" fn c_realloc(ptr: ?*anyopaque, size: usize) ?[*]align(@alignOf(usize)) u8;
comptime {
    if (builtin.target.isWasiLibC())
        @export(&c_realloc, .{ .name = "realloc" });
}

extern "c" fn c_qsort(
    base: ?*anyopaque,
    nmemb: usize,
    size: usize,
    compar: *const fn (*const anyopaque, *const anyopaque) callconv(.c) c_int,
) void;
comptime {
    if (builtin.target.isWasiLibC())
        @export(&c_qsort, .{ .name = "qsort" });
}

extern "c" fn c_openat_nomode(dir: c_int, path: [*:0]const u8, flags: c_int) c_int;
comptime {
    if (builtin.target.isWasiLibC())
        @export(&c_openat_nomode, .{ .name = "__wasilibc_nocwd_openat_nomode" });
}

// ========================================================
// Type definitions matching C ABI
// ========================================================

const DIRENT_DEFAULT_BUFFER_SIZE: usize = 4096;

/// Internal DIR structure matching cloudlibc dirent_impl.h
const DIR = extern struct {
    fd: c_int,
    cookie: wasi.dircookie_t,
    buffer: ?[*]u8,
    buffer_processed: usize,
    buffer_size: usize,
    buffer_used: usize,
    dirent_ptr: ?[*]u8,
    dirent_size: usize,
};

/// Layout helper to compute offsetof(struct dirent, d_name).
const DirentLayout = extern struct {
    d_ino: u64,
    d_type: u8,
    d_name: [1]u8,
};
const DIRENT_D_NAME_OFFSET = @offsetOf(DirentLayout, "d_name");

const PollFd = extern struct {
    fd: c_int,
    events: c_short,
    revents: c_short,
};

const FD_SETSIZE = 1024;
const FdSet = extern struct {
    __nfds: usize,
    __fds: [FD_SETSIZE]c_int,
};

const ClockId = extern struct {
    id: wasi.clockid_t,
};

const Timespec = extern struct {
    tv_sec: c_longlong,
    tv_nsec: c_long,
};

const Timeval = extern struct {
    tv_sec: c_longlong,
    tv_usec: c_longlong,
};

// Poll event flags (from __header_poll.h)
const POLLRDNORM: c_short = 0x1;
const POLLWRNORM: c_short = 0x2;
const POLLERR: c_short = 0x1000;
const POLLHUP: c_short = 0x2000;
const POLLNVAL: c_short = 0x4000;

// ioctl requests (from __header_sys_ioctl.h)
const FIONREAD: c_int = 1;
const FIONBIO: c_int = 2;

// O_* flags for WASI (from __header_fcntl.h)
const O_NONBLOCK: c_int = 4; // __WASI_FDFLAGS_NONBLOCK
const O_DIRECTORY: c_int = 2 << 12; // __WASI_OFLAGS_DIRECTORY << 12
const O_RDONLY: c_int = 0x04000000;

const NSEC_PER_SEC: u64 = 1_000_000_000;

// ========================================================
// Helpers
// ========================================================

fn setErrno(err: wasi.errno_t) void {
    std.c._errno().* = @intFromEnum(err);
}

/// Grow a buffer (via realloc) to at least `target_size`.
/// Returns null on allocation failure.
fn grow(buf: ?[*]u8, buf_size: *usize, target_size: usize) ?[*]u8 {
    if (buf_size.* >= target_size) return buf;
    var new_size = buf_size.*;
    while (new_size < target_size) new_size *= 2;
    const new_buf = c_realloc(@ptrCast(buf), new_size) orelse return null;
    buf_size.* = new_size;
    return new_buf;
}

// ========================================================
// Symbol exports
// ========================================================

comptime {
    if (builtin.target.isWasiLibC()) {
        // stdlib
        sym(&exitWasi, "_Exit");
        sym(&exitWasi, "_exit");

        // time constants (data symbols)
        @export(&clock_monotonic, .{ .name = "_CLOCK_MONOTONIC", .linkage = .weak, .visibility = .hidden });
        @export(&clock_realtime, .{ .name = "_CLOCK_REALTIME", .linkage = .weak, .visibility = .hidden });

        // errno
        @export(&wasi_errno, .{ .name = "errno", .linkage = .weak, .visibility = .hidden });

        // dirent
        sym(&closedirWasi, "closedir");
        sym(&dirfdWasi, "dirfd");
        sym(&fdclosedirWasi, "fdclosedir");
        sym(&fdopendirWasi, "fdopendir");
        sym(&opendiratWasi, "__wasilibc_nocwd_opendirat");
        sym(&readdirWasi, "readdir");
        sym(&rewinddirWasi, "rewinddir");
        sym(&scandiratWasi, "__wasilibc_nocwd_scandirat");
        sym(&seekdirWasi, "seekdir");
        sym(&telldirWasi, "telldir");

        // poll/select
        sym(&pollWasi, "poll");
        sym(&pselectWasi, "pselect");
        sym(&selectWasi, "select");

        // ioctl
        sym(&ioctlWasi, "ioctl");
    }
}

// ========================================================
// _Exit / _exit
// ========================================================

fn exitWasi(status: c_int) callconv(.c) noreturn {
    wasi.proc_exit(@bitCast(status));
}

// ========================================================
// CLOCK_MONOTONIC / CLOCK_REALTIME
// ========================================================

const clock_monotonic = ClockId{ .id = .MONOTONIC };
const clock_realtime = ClockId{ .id = .REALTIME };

// ========================================================
// errno
// ========================================================

threadlocal var wasi_errno: c_int = 0;

// ========================================================
// dirent functions
// ========================================================

fn dirfdWasi(dirp: *DIR) callconv(.c) c_int {
    return dirp.fd;
}

fn telldirWasi(dirp: *DIR) callconv(.c) c_long {
    return @bitCast(@as(c_ulong, @truncate(dirp.cookie)));
}

fn seekdirWasi(dirp: *DIR, loc: c_long) callconv(.c) void {
    dirp.cookie = @as(c_ulong, @bitCast(loc));
    dirp.buffer_used = dirp.buffer_size;
    dirp.buffer_processed = dirp.buffer_size;
}

fn rewinddirWasi(dirp: *DIR) callconv(.c) void {
    dirp.cookie = wasi.DIRCOOKIE_START;
    dirp.buffer_used = dirp.buffer_size;
    dirp.buffer_processed = dirp.buffer_size;
}

fn fdclosedirWasi(dirp: *DIR) callconv(.c) c_int {
    const fd = dirp.fd;
    c_free(@ptrCast(dirp.buffer));
    c_free(@ptrCast(dirp.dirent_ptr));
    c_free(@ptrCast(dirp));
    return fd;
}

fn closedirWasi(dirp: *DIR) callconv(.c) c_int {
    return c_close(fdclosedirWasi(dirp));
}

fn fdopendirWasi(fd: c_int) callconv(.c) ?*DIR {
    const dirp: *DIR = @ptrCast(@alignCast(c_malloc(@sizeOf(DIR)) orelse return null));
    dirp.buffer = c_malloc(DIRENT_DEFAULT_BUFFER_SIZE) orelse {
        c_free(@ptrCast(dirp));
        return null;
    };

    // Load the first chunk to verify this is a directory.
    switch (wasi.fd_readdir(fd, dirp.buffer.?, DIRENT_DEFAULT_BUFFER_SIZE, wasi.DIRCOOKIE_START, &dirp.buffer_used)) {
        .SUCCESS => {},
        else => |err| {
            c_free(@ptrCast(dirp.buffer));
            c_free(@ptrCast(dirp));
            setErrno(err);
            return null;
        },
    }

    dirp.fd = fd;
    dirp.cookie = wasi.DIRCOOKIE_START;
    dirp.buffer_processed = 0;
    dirp.buffer_size = DIRENT_DEFAULT_BUFFER_SIZE;
    dirp.dirent_ptr = null;
    dirp.dirent_size = 1;
    return dirp;
}

fn opendiratWasi(dir: c_int, dirname: [*:0]const u8) callconv(.c) ?*DIR {
    const fd = c_openat_nomode(dir, dirname, O_RDONLY | O_NONBLOCK | O_DIRECTORY);
    if (fd == -1) return null;

    const result = fdopendirWasi(fd);
    if (result == null) _ = c_close(fd);
    return result;
}

fn readdirWasi(dirp: *DIR) callconv(.c) ?*anyopaque {
    while (true) {
        const buffer_left = dirp.buffer_used - dirp.buffer_processed;
        if (buffer_left < @sizeOf(wasi.dirent_t)) {
            if (dirp.buffer_used < dirp.buffer_size) return null;
            readEntries(dirp) orelse return null;
            continue;
        }

        // Extract the dirent header.
        var entry: wasi.dirent_t = undefined;
        const entry_bytes: [*]const u8 = @ptrCast(&entry);
        const src = dirp.buffer.?[dirp.buffer_processed..][0..@sizeOf(wasi.dirent_t)];
        @memcpy(@constCast(entry_bytes[0..@sizeOf(wasi.dirent_t)]), src);

        const entry_size = @sizeOf(wasi.dirent_t) + entry.namlen;
        if (entry.namlen == 0) {
            dirp.buffer_processed += entry_size;
            continue;
        }

        // Ensure the full entry is in the buffer.
        if (buffer_left < entry_size) {
            dirp.buffer = grow(dirp.buffer, &dirp.buffer_size, entry_size) orelse return null;
            readEntries(dirp) orelse return null;
            continue;
        }

        // Skip entries with null bytes in the filename.
        const name = dirp.buffer.?[dirp.buffer_processed + @sizeOf(wasi.dirent_t) ..][0..entry.namlen];
        if (std.mem.indexOfScalar(u8, name, 0) != null) {
            dirp.buffer_processed += entry_size;
            continue;
        }

        // Ensure the dirent buffer is large enough for the filename.
        const needed = DIRENT_D_NAME_OFFSET + entry.namlen + 1;
        dirp.dirent_ptr = grow(dirp.dirent_ptr, &dirp.dirent_size, needed) orelse return null;
        const dirent_bytes = dirp.dirent_ptr.?;

        // Write d_type.
        dirent_bytes[8] = @intFromEnum(entry.type);
        // Write d_name.
        @memcpy(dirent_bytes[DIRENT_D_NAME_OFFSET..][0..entry.namlen], name);
        dirent_bytes[DIRENT_D_NAME_OFFSET + entry.namlen] = 0;

        // Resolve inode number if unknown.
        var d_ino: u64 = entry.ino;
        var d_type: u8 = @intFromEnum(entry.type);
        if (d_ino == 0) {
            // Check if this is ".." which we can't stat.
            const d_name_slice = dirent_bytes[DIRENT_D_NAME_OFFSET..][0..entry.namlen];
            if (!std.mem.eql(u8, d_name_slice, "..")) {
                var filestat: wasi.filestat_t = undefined;
                switch (wasi.path_filestat_get(dirp.fd, .{}, name.ptr, name.len, &filestat)) {
                    .SUCCESS => {
                        d_ino = filestat.ino;
                        d_type = @intFromEnum(filestat.filetype);
                    },
                    .NOENT => {
                        // File disappeared, skip it.
                        dirp.buffer_processed += entry_size;
                        continue;
                    },
                    else => return null,
                }
            }
        }

        // Write d_ino (u64, offset 0).
        @as(*align(1) u64, @ptrCast(dirent_bytes)).* = d_ino;
        // Update d_type in case it was resolved via stat.
        dirent_bytes[8] = d_type;

        dirp.cookie = entry.next;
        dirp.buffer_processed += entry_size;
        return @ptrCast(dirent_bytes);
    }
}

fn readEntries(dirp: *DIR) ?void {
    dirp.buffer_used = dirp.buffer_size;
    dirp.buffer_processed = dirp.buffer_size;
    switch (wasi.fd_readdir(dirp.fd, dirp.buffer.?, dirp.buffer_size, dirp.cookie, &dirp.buffer_used)) {
        .SUCCESS => {
            dirp.buffer_processed = 0;
        },
        else => |err| {
            setErrno(err);
            return null;
        },
    }
}

fn scandiratWasi(
    dirfd: c_int,
    dir: [*:0]const u8,
    namelist: *?[*]*anyopaque,
    sel: ?*const fn (*const anyopaque) callconv(.c) c_int,
    compar: *const fn (*const anyopaque, *const anyopaque) callconv(.c) c_int,
) callconv(.c) c_int {
    const fd = c_openat_nomode(dirfd, dir, O_RDONLY | O_NONBLOCK | O_DIRECTORY);
    if (fd == -1) return -1;

    var buffer_size: usize = DIRENT_DEFAULT_BUFFER_SIZE;
    var buffer: ?[*]u8 = @ptrCast(c_malloc(buffer_size));
    if (buffer == null) {
        _ = c_close(fd);
        return -1;
    }
    var buffer_processed: usize = buffer_size;
    var buffer_used: usize = buffer_size;

    var dirents: ?[*]*anyopaque = null;
    var dirents_size: usize = 0;
    var dirents_used: usize = 0;

    var cookie: wasi.dircookie_t = wasi.DIRCOOKIE_START;
    var done = false;
    while (!done) {
        const buffer_left = buffer_used - buffer_processed;
        if (buffer_left < @sizeOf(wasi.dirent_t)) {
            if (buffer_used < buffer_size) {
                done = true;
                continue;
            }
            // Read more entries.
            switch (wasi.fd_readdir(fd, buffer.?, buffer_size, cookie, &buffer_used)) {
                .SUCCESS => buffer_processed = 0,
                else => |err| {
                    setErrno(err);
                    scandiratFree(dirents, dirents_used);
                    c_free(@ptrCast(buffer));
                    _ = c_close(fd);
                    return -1;
                },
            }
            continue;
        }

        var entry: wasi.dirent_t = undefined;
        const entry_ptr: [*]u8 = @ptrCast(&entry);
        @memcpy(entry_ptr[0..@sizeOf(wasi.dirent_t)], buffer.?[buffer_processed..][0..@sizeOf(wasi.dirent_t)]);

        const entry_size = @sizeOf(wasi.dirent_t) + entry.namlen;
        if (entry.namlen == 0) {
            buffer_processed += entry_size;
            continue;
        }

        if (buffer_left < entry_size) {
            while (buffer_size < entry_size) buffer_size *= 2;
            buffer = @ptrCast(c_realloc(@ptrCast(buffer), buffer_size) orelse {
                scandiratFree(dirents, dirents_used);
                c_free(@ptrCast(buffer));
                _ = c_close(fd);
                return -1;
            });
            // Read entries again with larger buffer.
            switch (wasi.fd_readdir(fd, buffer.?, buffer_size, cookie, &buffer_used)) {
                .SUCCESS => buffer_processed = 0,
                else => |err| {
                    setErrno(err);
                    scandiratFree(dirents, dirents_used);
                    c_free(@ptrCast(buffer));
                    _ = c_close(fd);
                    return -1;
                },
            }
            continue;
        }

        const name = buffer.?[buffer_processed + @sizeOf(wasi.dirent_t) ..][0..entry.namlen];
        buffer_processed += entry_size;

        // Skip entries with null bytes in the filename.
        if (std.mem.indexOfScalar(u8, name, 0) != null) continue;

        // Allocate a new dirent.
        const alloc_size = DIRENT_D_NAME_OFFSET + entry.namlen + 1;
        const dirent_bytes: [*]u8 = @ptrCast(c_malloc(alloc_size) orelse {
            scandiratFree(dirents, dirents_used);
            c_free(@ptrCast(buffer));
            _ = c_close(fd);
            return -1;
        });

        dirent_bytes[8] = @intFromEnum(entry.type);
        @memcpy(dirent_bytes[DIRENT_D_NAME_OFFSET..][0..entry.namlen], name);
        dirent_bytes[DIRENT_D_NAME_OFFSET + entry.namlen] = 0;

        // Resolve inode if unknown.
        var d_ino: u64 = entry.ino;
        var d_type: u8 = @intFromEnum(entry.type);
        if (d_ino == 0) {
            var filestat: wasi.filestat_t = undefined;
            switch (wasi.path_filestat_get(fd, .{}, name.ptr, name.len, &filestat)) {
                .SUCCESS => {
                    d_ino = filestat.ino;
                    d_type = @intFromEnum(filestat.filetype);
                },
                else => {
                    c_free(@ptrCast(dirent_bytes));
                    scandiratFree(dirents, dirents_used);
                    c_free(@ptrCast(buffer));
                    _ = c_close(fd);
                    return -1;
                },
            }
        }
        @as(*align(1) u64, @ptrCast(dirent_bytes)).* = d_ino;
        dirent_bytes[8] = d_type;

        cookie = entry.next;

        // Apply selection filter.
        const selected = if (sel) |sel_fn| sel_fn(@ptrCast(dirent_bytes)) != 0 else true;
        if (selected) {
            // Grow dirents array if needed.
            if (dirents_used == dirents_size) {
                dirents_size = if (dirents_size < 8) 8 else dirents_size * 2;
                const new_dirents: ?[*]*anyopaque = @ptrCast(@alignCast(c_realloc(
                    @ptrCast(dirents),
                    dirents_size * @sizeOf(*anyopaque),
                )));
                if (new_dirents == null) {
                    c_free(@ptrCast(dirent_bytes));
                    scandiratFree(dirents, dirents_used);
                    c_free(@ptrCast(buffer));
                    _ = c_close(fd);
                    return -1;
                }
                dirents = new_dirents;
            }
            dirents.?[dirents_used] = @ptrCast(dirent_bytes);
            dirents_used += 1;
        } else {
            c_free(@ptrCast(dirent_bytes));
        }
    }

    // Sort and return results.
    c_free(@ptrCast(buffer));
    _ = c_close(fd);
    c_qsort(@ptrCast(dirents), dirents_used, @sizeOf(*anyopaque), compar);
    namelist.* = dirents;
    return @intCast(dirents_used);
}

fn scandiratFree(dirents: ?[*]*anyopaque, count: usize) void {
    if (dirents) |d| {
        for (d[0..count]) |entry| c_free(entry);
        c_free(@ptrCast(d));
    }
}

// ========================================================
// poll
// ========================================================

fn pollWasi(fds: ?[*]PollFd, nfds: usize, timeout: c_int) callconv(.c) c_int {
    return pollWasiP1(fds, nfds, timeout);
}

fn pollWasiP1(fds: ?[*]PollFd, nfds: usize, timeout: c_int) c_int {
    const max_subs = 2 * nfds + 1;
    if (max_subs == 0) {
        setErrno(.NOTSUP);
        return -1;
    }

    // Allocate subscription and event arrays.
    const subs_bytes = max_subs * @sizeOf(wasi.subscription_t);
    const subs_mem: [*]align(@alignOf(wasi.subscription_t)) u8 = @alignCast(c_malloc(subs_bytes) orelse {
        setErrno(.NOMEM);
        return -1;
    });
    const subs: [*]wasi.subscription_t = @ptrCast(subs_mem);
    defer c_free(@ptrCast(subs_mem));

    var nsubs: usize = 0;

    if (fds) |fds_ptr| {
        for (fds_ptr[0..nfds]) |*pollfd| {
            if (pollfd.fd < 0) continue;
            var created = false;
            if (pollfd.events & POLLRDNORM != 0) {
                subs[nsubs] = std.mem.zeroes(wasi.subscription_t);
                subs[nsubs].userdata = @intFromPtr(pollfd);
                subs[nsubs].u.tag = .FD_READ;
                subs[nsubs].u.u.fd_read.fd = pollfd.fd;
                nsubs += 1;
                created = true;
            }
            if (pollfd.events & POLLWRNORM != 0) {
                subs[nsubs] = std.mem.zeroes(wasi.subscription_t);
                subs[nsubs].userdata = @intFromPtr(pollfd);
                subs[nsubs].u.tag = .FD_WRITE;
                subs[nsubs].u.u.fd_write.fd = pollfd.fd;
                nsubs += 1;
                created = true;
            }
            if (!created) {
                setErrno(.NOSYS);
                return -1;
            }
        }
    }

    // Create timeout subscription if applicable.
    if (timeout >= 0) {
        subs[nsubs] = std.mem.zeroes(wasi.subscription_t);
        subs[nsubs].u.tag = .CLOCK;
        subs[nsubs].u.u.clock.id = .REALTIME;
        subs[nsubs].u.u.clock.timeout = @as(wasi.timestamp_t, @intCast(timeout)) * 1_000_000;
        nsubs += 1;
    }

    if (nsubs == 0) {
        setErrno(.NOTSUP);
        return -1;
    }

    // Allocate events array.
    const events_mem: [*]align(@alignOf(wasi.event_t)) u8 = @alignCast(c_malloc(nsubs * @sizeOf(wasi.event_t)) orelse {
        setErrno(.NOMEM);
        return -1;
    });
    const events: [*]wasi.event_t = @ptrCast(events_mem);
    defer c_free(@ptrCast(events_mem));

    var nevents: usize = 0;
    switch (wasi.poll_oneoff(&subs[0], &events[0], nsubs, &nevents)) {
        .SUCCESS => {},
        else => |err| {
            if (nsubs == 0)
                setErrno(.NOTSUP)
            else
                setErrno(err);
            return -1;
        },
    }

    // Clear revents.
    if (fds) |fds_ptr| {
        for (fds_ptr[0..nfds]) |*pollfd| pollfd.revents = 0;
    }

    // Set revents from events.
    for (events[0..nevents]) |*event| {
        if (event.type == .FD_READ or event.type == .FD_WRITE) {
            const pollfd: *PollFd = @ptrFromInt(event.userdata);
            if (event.@"error" == .BADF) {
                pollfd.revents |= POLLNVAL;
            } else if (event.@"error" == .PIPE) {
                pollfd.revents |= POLLHUP;
            } else if (event.@"error" != .SUCCESS) {
                pollfd.revents |= POLLERR;
            } else {
                if (event.type == .FD_READ) {
                    pollfd.revents |= POLLRDNORM;
                    if (event.fd_readwrite.flags & wasi.EVENT_FD_READWRITE_HANGUP != 0)
                        pollfd.revents |= POLLHUP;
                } else if (event.type == .FD_WRITE) {
                    pollfd.revents |= POLLWRNORM;
                    if (event.fd_readwrite.flags & wasi.EVENT_FD_READWRITE_HANGUP != 0)
                        pollfd.revents |= POLLHUP;
                }
            }
        }
    }

    // Count fds with non-zero revents.
    var retval: c_int = 0;
    if (fds) |fds_ptr| {
        for (fds_ptr[0..nfds]) |*pollfd| {
            if (pollfd.revents & POLLHUP != 0)
                pollfd.revents &= ~POLLWRNORM;
            if (pollfd.revents != 0)
                retval += 1;
        }
    }
    return retval;
}

// ========================================================
// pselect / select
// ========================================================

fn pselectWasi(
    nfds: c_int,
    readfds: ?*FdSet,
    writefds: ?*FdSet,
    errorfds: ?*const FdSet,
    timeout: ?*const Timespec,
    _: ?*const u8, // sigset_t, unused on WASI
) callconv(.c) c_int {
    if (nfds < 0) {
        setErrno(.INVAL);
        return -1;
    }

    if (errorfds) |ef| {
        if (ef.__nfds > 0) {
            setErrno(.NOSYS);
            return -1;
        }
    }

    // Use empty sets for null pointers.
    var empty1 = std.mem.zeroes(FdSet);
    var empty2 = std.mem.zeroes(FdSet);
    const rds = readfds orelse &empty1;
    const wrs = writefds orelse &empty2;

    const poll_nfds_max = rds.__nfds + wrs.__nfds;
    const poll_fds_mem: ?[*]align(@alignOf(PollFd)) u8 = if (poll_nfds_max > 0)
        @alignCast(c_malloc(poll_nfds_max * @sizeOf(PollFd)) orelse {
            setErrno(.NOMEM);
            return -1;
        })
    else
        null;
    defer if (poll_fds_mem) |m| c_free(@ptrCast(m));

    const poll_fds: [*]PollFd = if (poll_fds_mem) |m| @ptrCast(m) else @as([*]PollFd, undefined);
    var poll_nfds: usize = 0;

    for (rds.__fds[0..rds.__nfds]) |fd| {
        if (fd < nfds) {
            poll_fds[poll_nfds] = PollFd{ .fd = fd, .events = POLLRDNORM, .revents = 0 };
            poll_nfds += 1;
        }
    }
    for (wrs.__fds[0..wrs.__nfds]) |fd| {
        if (fd < nfds) {
            poll_fds[poll_nfds] = PollFd{ .fd = fd, .events = POLLWRNORM, .revents = 0 };
            poll_nfds += 1;
        }
    }

    var poll_timeout: c_int = undefined;
    if (timeout) |ts| {
        if (ts.tv_nsec < 0 or ts.tv_nsec >= @as(c_long, @intCast(NSEC_PER_SEC))) {
            setErrno(.INVAL);
            return -1;
        }
        if (ts.tv_sec < 0) {
            poll_timeout = 0;
        } else {
            // Convert to milliseconds with clamping.
            const sec: u64 = @intCast(ts.tv_sec);
            const mul_result = @mulWithOverflow(sec, NSEC_PER_SEC);
            if (mul_result[1] != 0) {
                poll_timeout = std.math.maxInt(c_int);
            } else {
                const add_result = @addWithOverflow(mul_result[0], @as(u64, @intCast(ts.tv_nsec)));
                if (add_result[1] != 0) {
                    poll_timeout = std.math.maxInt(c_int);
                } else {
                    const ms = add_result[0] / 1_000_000;
                    poll_timeout = if (ms > @as(u64, @intCast(std.math.maxInt(c_int))))
                        std.math.maxInt(c_int)
                    else
                        @intCast(ms);
                }
            }
        }
    } else {
        poll_timeout = -1;
    }

    if (pollWasi(if (poll_nfds > 0) poll_fds else null, poll_nfds, poll_timeout) < 0)
        return -1;

    // Clear and rebuild fd sets.
    rds.__nfds = 0;
    wrs.__nfds = 0;
    for (0..poll_nfds) |i| {
        if (poll_fds[i].revents & POLLRDNORM != 0) {
            rds.__fds[rds.__nfds] = poll_fds[i].fd;
            rds.__nfds += 1;
        }
        if (poll_fds[i].revents & POLLWRNORM != 0) {
            wrs.__fds[wrs.__nfds] = poll_fds[i].fd;
            wrs.__nfds += 1;
        }
    }

    return @intCast(rds.__nfds + wrs.__nfds);
}

fn selectWasi(
    nfds: c_int,
    readfds: ?*FdSet,
    writefds: ?*FdSet,
    errorfds: ?*const FdSet,
    timeout: ?*Timeval,
) callconv(.c) c_int {
    if (timeout) |tv| {
        if (tv.tv_usec < 0 or tv.tv_usec >= 1_000_000) {
            setErrno(.INVAL);
            return -1;
        }
        const ts = Timespec{
            .tv_sec = tv.tv_sec,
            .tv_nsec = @intCast(tv.tv_usec * 1000),
        };
        return pselectWasi(nfds, readfds, writefds, errorfds, &ts, null);
    } else {
        return pselectWasi(nfds, readfds, writefds, errorfds, null, null);
    }
}

// ========================================================
// ioctl
// ========================================================

fn ioctlWasi(fildes: c_int, request: c_int, ...) callconv(.c) c_int {
    switch (request) {
        FIONREAD => {
            // Poll to determine bytes available for reading.
            var subs = [2]wasi.subscription_t{
                std.mem.zeroes(wasi.subscription_t),
                std.mem.zeroes(wasi.subscription_t),
            };
            subs[0].u.tag = .FD_READ;
            subs[0].u.u.fd_read.fd = fildes;
            subs[1].u.tag = .CLOCK;
            subs[1].u.u.clock.id = .MONOTONIC;

            var events: [2]wasi.event_t = undefined;
            var nevents: usize = 0;
            switch (wasi.poll_oneoff(&subs[0], &events[0], 2, &nevents)) {
                .SUCCESS => {},
                else => |err| {
                    setErrno(err);
                    return -1;
                },
            }

            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            const result: *c_int = @cVaArg(&ap, *c_int);

            for (events[0..nevents]) |*event| {
                if (event.@"error" != .SUCCESS) {
                    setErrno(event.@"error");
                    return -1;
                }
                if (event.type == .FD_READ) {
                    result.* = @intCast(event.fd_readwrite.nbytes);
                    return 0;
                }
            }
            result.* = 0;
            return 0;
        },
        FIONBIO => {
            var fds: wasi.fdstat_t = undefined;
            switch (wasi.fd_fdstat_get(fildes, &fds)) {
                .SUCCESS => {},
                else => |err| {
                    setErrno(err);
                    return -1;
                },
            }

            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            const val: *const c_int = @cVaArg(&ap, *const c_int);

            if (val.* != 0)
                fds.fs_flags.NONBLOCK = true
            else
                fds.fs_flags.NONBLOCK = false;

            switch (wasi.fd_fdstat_set_flags(fildes, fds.fs_flags)) {
                .SUCCESS => return 0,
                else => |err| {
                    setErrno(err);
                    return -1;
                },
            }
        },
        else => {
            setErrno(.INVAL);
            return -1;
        },
    }
}
