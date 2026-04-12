const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&getsubopt, "getsubopt");
    }
}

fn getsubopt(opt: *[*:0]u8, keys: [*:null]const ?[*:0]const u8, val: *?[*:0]u8) callconv(.c) c_int {
    const s: [*:0]u8 = opt.*;
    val.* = null;

    // Find the comma or end of string.
    var end: usize = 0;
    while (s[end] != 0 and s[end] != ',') : (end += 1) {}

    if (s[end] == ',') {
        s[end] = 0;
        opt.* = @ptrCast(s + end + 1);
    } else {
        opt.* = @ptrCast(s + end);
    }

    // Search for matching key.
    var i: c_int = 0;
    while (keys[@intCast(i)]) |key| : (i += 1) {
        var l: usize = 0;
        while (key[l] != 0) : (l += 1) {}
        if (l == 0) continue;

        // Compare key with beginning of s.
        var match = true;
        for (0..l) |j| {
            if (s[j] != key[j]) {
                match = false;
                break;
            }
        }
        if (!match) continue;

        if (s[l] == '=') {
            val.* = @ptrCast(s + l + 1);
        } else if (s[l] != 0) {
            continue;
        }
        return i;
    }
    return -1;
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&getpriorityLinux, "getpriority");
        symbol(&setpriorityLinux, "setpriority");
        symbol(&getresuidLinux, "getresuid");
        symbol(&getresgidLinux, "getresgid");
        symbol(&setdomainnameLinux, "setdomainname");
    }
}

fn getpriorityLinux(which: c_int, who: c_uint) callconv(.c) c_int {
    const rc = errno(linux.syscall2(.getpriority, @as(usize, @bitCast(@as(isize, which))), @as(usize, who)));
    if (rc < 0) return rc;
    return 20 - rc;
}

fn setpriorityLinux(which: c_int, who: c_uint, prio: c_int) callconv(.c) c_int {
    return errno(linux.syscall3(.setpriority, @as(usize, @bitCast(@as(isize, which))), @as(usize, who), @as(usize, @bitCast(@as(isize, prio)))));
}

fn getresuidLinux(ruid: *linux.uid_t, euid: *linux.uid_t, suid: *linux.uid_t) callconv(.c) c_int {
    return errno(linux.getresuid(ruid, euid, suid));
}

fn getresgidLinux(rgid: *linux.gid_t, egid: *linux.gid_t, sgid: *linux.gid_t) callconv(.c) c_int {
    return errno(linux.getresgid(rgid, egid, sgid));
}

fn setdomainnameLinux(name: [*]const u8, len: usize) callconv(.c) c_int {
    return errno(linux.syscall2(.setdomainname, @intFromPtr(name), len));
        symbol(&gethostid, "gethostid");
        symbol(&getdomainnameLinux, "getdomainname");
        symbol(&getrlimitLinux, "getrlimit");
        symbol(&setrlimitLinux, "setrlimit");
    }
    if (builtin.target.isWasiLibC()) {
        symbol(&gethostid, "gethostid");
    }
}

fn gethostid() callconv(.c) c_long {
    return 0;
}

fn getdomainnameLinux(name: [*]u8, len: usize) callconv(.c) c_int {
    var uts: linux.utsname = undefined;
    const rc: isize = @bitCast(linux.uname(&uts));
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&login_ttyLinux, "login_tty");
    }
    if (builtin.link_libc) {
        symbol(&initgroups, "initgroups");
    }
}

fn login_ttyLinux(fd: c_int) callconv(.c) c_int {
    _ = linux.setsid();
    const rc: isize = @bitCast(linux.ioctl(@intCast(fd), linux.T.IOCSCTTY, 0));
    if (rc < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-rc);
        return -1;
    }
    const domain = std.mem.sliceTo(&uts.domainname, 0);
    if (len == 0 or domain.len >= len) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    @memcpy(name[0..domain.len], domain);
    name[domain.len] = 0;
    return 0;
}

fn getrlimitLinux(resource: c_int, rlim: *linux.rlimit) callconv(.c) c_int {
    return errno(linux.getrlimit(@enumFromInt(resource), rlim));
}

fn setrlimitLinux(resource: c_int, rlim: *const linux.rlimit) callconv(.c) c_int {
    return errno(linux.setrlimit(@enumFromInt(resource), rlim));
        symbol(&basename, "basename");
        symbol(&basename, "__xpg_basename");
        symbol(&dirname, "dirname");
        symbol(&a64l, "a64l");
        symbol(&l64a, "l64a");
    }
}

fn basename(s: ?[*:0]u8) callconv(.c) [*:0]const u8 {
    const str = s orelse return ".";
    if (str[0] == 0) return ".";

    // Find end of string.
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    i -= 1;

    // Strip trailing slashes.
    while (i > 0 and str[i] == '/') : (i -= 1) {
        str[i] = 0;
    }
    if (i == 0 and str[0] == '/') return str[0..1 :0];

    // Find last slash.
    while (i > 0 and str[i - 1] != '/') : (i -= 1) {}

    return @ptrCast(str + i);
}

fn dirname(s: ?[*:0]u8) callconv(.c) [*:0]const u8 {
    const str = s orelse return ".";
    if (str[0] == 0) return ".";

    // Find end of string.
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    i -= 1;

    // Strip trailing slashes.
    while (str[i] == '/') {
        if (i == 0) return "/";
        i -= 1;
    }
    // Strip trailing component.
    while (str[i] != '/') {
        if (i == 0) return ".";
        i -= 1;
    }
    // Strip trailing slashes again.
    while (str[i] == '/') {
        if (i == 0) return "/";
        i -= 1;
    }

    str[i + 1] = 0;
    return @ptrCast(str);
}

const digits = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

fn a64l(str: [*:0]const u8) callconv(.c) c_long {
    var x: u32 = 0;
    var e: u5 = 0;
    var p = str;
    while (e < 36 and p[0] != 0) : ({
        e += 6;
        p += 1;
    }) {
        const c = p[0];
        const d: u32 = for (digits, 0..) |ch, idx| {
            if (ch == c) break @intCast(idx);
        } else break;
        x |= d << e;
    }
    return @as(c_long, @as(i32, @bitCast(x)));
}

var l64a_buf: [7]u8 = undefined;

fn l64a(x0: c_long) callconv(.c) [*:0]u8 {
    var x: u32 = @bitCast(@as(c_int, @intCast(x0)));
    var i: usize = 0;
    while (x != 0 and i < 6) : (i += 1) {
        l64a_buf[i] = digits[x & 63];
        x >>= 6;
    }
    l64a_buf[i] = 0;
    return l64a_buf[0..i :0];
}
        symbol(&getrusageLinux, "getrusage");
        symbol(&getentropyLinux, "getentropy");
    }
}

fn getrusageLinux(who: c_int, usage: *linux.rusage) callconv(.c) c_int {
    return errno(linux.getrusage(who, usage));
}

fn getentropyLinux(buffer: [*]u8, len: usize) callconv(.c) c_int {
    if (len > 256) {
        std.c._errno().* = @intFromEnum(linux.E.IO);
        return -1;
    }
    var pos: usize = 0;
    while (pos < len) {
        const rc: isize = @bitCast(linux.getrandom(buffer + pos, len - pos, 0));
        if (rc < 0) {
            @branchHint(.unlikely);
            if (-rc == @intFromEnum(linux.E.INTR)) continue;
            std.c._errno().* = @intCast(-rc);
            return -1;
        }
        pos += @intCast(rc);
    }
    return 0;
    _ = linux.dup2(fd, 0);
    _ = linux.dup2(fd, 1);
    _ = linux.dup2(fd, 2);
    if (fd > 2) _ = linux.close(fd);
    return 0;
}

const NGROUPS_MAX = 32;

extern "c" fn getgrouplist(user: [*:0]const u8, group: linux.gid_t, groups: [*]linux.gid_t, ngroups: *c_int) c_int;
extern "c" fn setgroups(size: usize, list: [*]const linux.gid_t) c_int;

fn initgroups(user: [*:0]const u8, gid: linux.gid_t) callconv(.c) c_int {
    var groups: [NGROUPS_MAX]linux.gid_t = undefined;
    var count: c_int = NGROUPS_MAX;
    if (getgrouplist(user, gid, &groups, &count) < 0) return -1;
    return setgroups(@intCast(count), &groups);
    if (builtin.link_libc) {
        symbol(&lockf, "lockf");
        symbol(&ptsname, "ptsname");
    }
}

// lockf command constants
const F_ULOCK = 0;
const F_LOCK = 1;
const F_TLOCK = 2;
const F_TEST = 3;

// fcntl commands
const F_GETLK = 5;
const F_SETLK = 6;
const F_SETLKW = 7;

// flock types
const F_RDLCK: c_short = 0;
const F_WRLCK: c_short = 1;
const F_UNLCK: c_short = 2;

const SEEK_CUR: c_short = 1;

const flock = extern struct {
    l_type: c_short,
    l_whence: c_short,
    l_start: i64,
    l_len: i64,
    l_pid: c_int,
};

extern "c" fn fcntl(fd: c_int, cmd: c_int, ...) c_int;
extern "c" fn getpid() c_int;

fn lockf(fd: c_int, op: c_int, size: i64) callconv(.c) c_int {
    var l = flock{
        .l_type = F_WRLCK,
        .l_whence = SEEK_CUR,
        .l_start = 0,
        .l_len = size,
        .l_pid = 0,
    };
    switch (op) {
        F_TEST => {
            l.l_type = F_RDLCK;
            if (fcntl(fd, F_GETLK, &l) < 0) return -1;
            if (l.l_type == F_UNLCK or l.l_pid == getpid()) return 0;
            std.c._errno().* = @intFromEnum(linux.E.ACCES);
            return -1;
        },
        F_ULOCK => {
            l.l_type = F_UNLCK;
            return fcntl(fd, F_SETLK, &l);
        },
        F_TLOCK => return fcntl(fd, F_SETLK, &l),
        F_LOCK => return fcntl(fd, F_SETLKW, &l),
        else => {
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
            return -1;
        },
    }
}

extern "c" fn __ptsname_r(fd: c_int, buf: [*]u8, len: usize) c_int;

var ptsname_buf: [9 + @sizeOf(c_int) * 3 + 1]u8 = undefined;

fn ptsname(fd: c_int) callconv(.c) ?[*:0]u8 {
    const err = __ptsname_r(fd, &ptsname_buf, ptsname_buf.len);
    if (err != 0) {
        std.c._errno().* = err;
        return null;
    }
    // Find the null terminator to create a sentinel-terminated pointer.
    for (&ptsname_buf, 0..) |*c, i| {
        if (c.* == 0) return ptsname_buf[0..i :0];
    }
    return null;
        symbol(&posix_openptLinux, "posix_openpt");
        symbol(&grantpt, "grantpt");
        symbol(&unlockptLinux, "unlockpt");
        symbol(&__ptsname_rLinux, "__ptsname_r");
        symbol(&__ptsname_rLinux, "ptsname_r");
    }
}

fn posix_openptLinux(flags: c_int) callconv(.c) c_int {
    const rc: isize = @bitCast(linux.open("/dev/ptmx", @bitCast(@as(u32, @bitCast(flags))), 0));
    if (rc < 0) {
        @branchHint(.unlikely);
        const e: u16 = @intCast(-rc);
        // Map ENOSPC to EAGAIN per POSIX.
        if (e == @intFromEnum(linux.E.NOSPC)) {
            std.c._errno().* = @intFromEnum(linux.E.AGAIN);
        } else {
            std.c._errno().* = @intCast(e);
        }
        return -1;
    }
    return @intCast(rc);
}

fn grantpt(_: c_int) callconv(.c) c_int {
    return 0;
}

fn unlockptLinux(fd: c_int) callconv(.c) c_int {
    var unlock: c_int = 0;
    return errno(linux.ioctl(@intCast(fd), linux.T.IOCSPTLCK, @intFromPtr(&unlock)));
}

fn __ptsname_rLinux(fd: c_int, buf: ?[*]u8, len: usize) callconv(.c) c_int {
    var pty: c_uint = undefined;
    const rc: isize = @bitCast(linux.ioctl(@intCast(fd), linux.T.IOCGPTN, @intFromPtr(&pty)));
    if (rc < 0) return @intCast(-rc);

    const b = buf orelse return @intFromEnum(linux.E.RANGE);

    const prefix = "/dev/pts/";
    if (len < prefix.len + 1) return @intFromEnum(linux.E.RANGE);
    @memcpy(b[0..prefix.len], prefix);

    // Format the pty number into the buffer after the prefix.
    var num_buf: [10]u8 = undefined;
    var num_len: usize = 0;
    var n: c_uint = pty;
    if (n == 0) {
        num_buf[0] = '0';
        num_len = 1;
    } else {
        while (n > 0) : (num_len += 1) {
            num_buf[num_len] = @intCast('0' + n % 10);
            n /= 10;
        }
        // Reverse.
        var lo: usize = 0;
        var hi: usize = num_len - 1;
        while (lo < hi) {
            const tmp = num_buf[lo];
            num_buf[lo] = num_buf[hi];
            num_buf[hi] = tmp;
            lo += 1;
            hi -= 1;
        }
    }

    if (prefix.len + num_len >= len) return @intFromEnum(linux.E.RANGE);
    @memcpy(b[prefix.len .. prefix.len + num_len], num_buf[0..num_len]);
    b[prefix.len + num_len] = 0;
    return 0;
    if (builtin.link_libc) {
        symbol(&openpty, "openpty");
        symbol(&forkpty, "forkpty");
    }
}

extern "c" fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn ioctl(fd: c_int, req: c_int, ...) c_int;
extern "c" fn login_tty(fd: c_int) c_int;
extern "c" fn fork() c_int;
extern "c" fn write(fd: c_int, buf: *const anyopaque, count: usize) isize;
extern "c" fn read(fd: c_int, buf: *anyopaque, count: usize) isize;
extern "c" fn _exit(code: c_int) noreturn;
extern "c" fn waitpid(pid: c_int, status: ?*c_int, options: c_int) c_int;
extern "c" fn pipe2(fds: *[2]c_int, flags: c_int) c_int;
extern "c" fn tcsetattr(fd: c_int, action: c_int, termios_p: *const anyopaque) c_int;
extern "c" fn snprintf(buf: [*]u8, size: usize, fmt: [*:0]const u8, ...) c_int;

const O_RDWR = 2;
const O_NOCTTY = 0o400;
const O_CLOEXEC = 0o2000000;
const TCSANOW = 0;

fn openpty(
    pm: *c_int,
    ps: *c_int,
    name: ?[*]u8,
    tio: ?*const anyopaque,
    ws: ?*const anyopaque,
) callconv(.c) c_int {
    var n: c_int = 0;
    var buf: [20]u8 = undefined;

    const m = open("/dev/ptmx", O_RDWR | O_NOCTTY);
    if (m < 0) return -1;

    if (ioctl(m, @as(c_int, @bitCast(@as(c_uint, linux.T.IOCSPTLCK))), &n) != 0 or
        ioctl(m, @as(c_int, @bitCast(@as(c_uint, linux.T.IOCGPTN))), &n) != 0)
    {
        _ = close(m);
        return -1;
    }

    const namebuf: [*]u8 = name orelse &buf;
    _ = snprintf(namebuf, 20, "/dev/pts/%d", n);

    const s = open(@ptrCast(namebuf), O_RDWR | O_NOCTTY);
    if (s < 0) {
        _ = close(m);
        return -1;
    }

    if (tio) |t| _ = tcsetattr(s, TCSANOW, t);
    if (ws) |w| _ = ioctl(s, @as(c_int, @bitCast(@as(c_uint, linux.T.IOCSWINSZ))), w);

    pm.* = m;
    ps.* = s;
    return 0;
}

fn forkpty(
    pm: *c_int,
    name: ?[*]u8,
    tio: ?*const anyopaque,
    ws: ?*const anyopaque,
) callconv(.c) c_int {
    var m: c_int = undefined;
    var s: c_int = undefined;
    var p: [2]c_int = undefined;

    if (openpty(&m, &s, name, tio, ws) < 0) return -1;

    if (pipe2(&p, O_CLOEXEC) != 0) {
        _ = close(s);
        _ = close(m);
        return -1;
    }

    const pid = fork();
    if (pid == 0) {
        // Child.
        _ = close(m);
        _ = close(p[0]);
        if (login_tty(s) != 0) {
            const e = std.c._errno().*;
            _ = write(p[1], &e, @sizeOf(c_int));
            _exit(127);
        }
        _ = close(p[1]);
        return 0;
    }

    // Parent.
    _ = close(s);
    _ = close(p[1]);

    if (pid < 0) {
        _ = close(p[0]);
        _ = close(m);
        return -1;
    }

    var ec: c_int = undefined;
    if (read(p[0], &ec, @sizeOf(c_int)) > 0) {
        var status: c_int = undefined;
        _ = waitpid(pid, &status, 0);
        _ = close(p[0]);
        _ = close(m);
        std.c._errno().* = ec;
        return -1;
    }
    _ = close(p[0]);

    pm.* = m;
    return pid;
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&fmtmsg, "fmtmsg");
    }
}

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]u8;
extern "c" fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn dprintf(fd: c_int, fmt: [*:0]const u8, ...) c_int;
extern "c" fn strchr(s: [*:0]u8, c: c_int) ?[*:0]u8;

const O_WRONLY = 1;
const MM_CONSOLE: c_long = 512;
const MM_PRINT: c_long = 256;
const MM_HALT: c_int = 1;
const MM_ERROR: c_int = 2;
const MM_WARNING: c_int = 3;
const MM_INFO: c_int = 4;
const MM_NOCON = 4;
const MM_NOMSG = 1;
const MM_NOTOK = -1;

const empty: [*:0]const u8 = "";

fn strcolcmp(lstr: [*:0]const u8, bstr: [*:0]const u8) bool {
    var i: usize = 0;
    while (lstr[i] != 0 and bstr[i] != 0 and bstr[i] == lstr[i]) : (i += 1) {}
    return lstr[i] == 0 and (bstr[i] == 0 or bstr[i] == ':');
}

fn fmtmsg(
    classification: c_long,
    label: ?[*:0]const u8,
    severity: c_int,
    text: ?[*:0]const u8,
    action: ?[*:0]const u8,
    tag: ?[*:0]const u8,
) callconv(.c) c_int {
    var ret: c_int = 0;

    const errstring: [*:0]const u8 = switch (severity) {
        MM_HALT => "HALT: ",
        MM_ERROR => "ERROR: ",
        MM_WARNING => "WARNING: ",
        MM_INFO => "INFO: ",
        else => empty,
    };

    if (classification & MM_CONSOLE != 0) {
        const consolefd = open("/dev/console", O_WRONLY);
        if (consolefd < 0) {
            ret = MM_NOCON;
        } else {
            if (dprintf(consolefd, "%s%s%s%s%s%s%s%s\n",
                if (label) |l| l else empty, if (label != null) @as([*:0]const u8, ": ") else empty,
                if (severity != 0) errstring else empty, if (text) |t| t else empty,
                if (action != null) @as([*:0]const u8, "\nTO FIX: ") else empty,
                if (action) |a| a else empty, if (action != null) @as([*:0]const u8, " ") else empty,
                if (tag) |t| t else empty) < 1)
                ret = MM_NOCON;
            _ = close(consolefd);
        }
    }

    if (classification & MM_PRINT != 0) {
        var verb: c_int = 0;
        var cmsg: ?[*:0]u8 = getenv("MSGVERB");
        const msgs = [_][*:0]const u8{ "label", "severity", "text", "action", "tag" };

        while (cmsg) |cm| {
            if (cm[0] == 0) break;
            var found = false;
            for (msgs, 0..) |m, i| {
                if (strcolcmp(m, cm)) {
                    verb |= @as(c_int, 1) << @intCast(i);
                    found = true;
                    break;
                }
            }
            if (!found) { verb = 0xFF; break; }
            cmsg = if (strchr(cm, ':')) |p| @ptrCast(@as([*]u8, @ptrCast(p)) + 1) else null;
        }
        if (verb == 0) verb = 0xFF;

        if (dprintf(2, "%s%s%s%s%s%s%s%s\n",
            if (verb & 1 != 0 and label != null) label.? else empty,
            if (verb & 1 != 0 and label != null) @as([*:0]const u8, ": ") else empty,
            if (verb & 2 != 0 and severity != 0) errstring else empty,
            if (verb & 4 != 0 and text != null) text.? else empty,
            if (verb & 8 != 0 and action != null) @as([*:0]const u8, "\nTO FIX: ") else empty,
            if (verb & 8 != 0 and action != null) action.? else empty,
            if (verb & 8 != 0 and action != null) @as([*:0]const u8, " ") else empty,
            if (verb & 16 != 0 and tag != null) tag.? else empty) < 1)
            ret |= MM_NOMSG;
    }

    if (ret & (MM_NOCON | MM_NOMSG) == (MM_NOCON | MM_NOMSG))
        ret = MM_NOTOK;

    return ret;
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&get_current_dir_name, "get_current_dir_name");
        symbol(&setmntent, "setmntent");
        symbol(&endmntent, "endmntent");
        symbol(&getmntent, "getmntent");
        symbol(&getmntent_r, "getmntent_r");
        symbol(&addmntent, "addmntent");
        symbol(&hasmntopt, "hasmntopt");
    }
}

// ── get_current_dir_name ───────────────────────────────────────────────

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;
extern "c" fn strdup(s: [*:0]const u8) ?[*:0]u8;
extern "c" fn getcwd(buf: ?[*]u8, size: usize) ?[*:0]u8;

// Use opaque stat buffers and compare dev+ino fields.
const STAT_BUF_SIZE = 256;
extern "c" fn stat(path: [*:0]const u8, buf: *[STAT_BUF_SIZE]u8) c_int;

fn get_current_dir_name() callconv(.c) ?[*:0]u8 {
    const res = getenv("PWD") orelse return getcwd(null, 0);
    if (res[0] == 0) return getcwd(null, 0);
    var a: [STAT_BUF_SIZE]u8 = undefined;
    var b: [STAT_BUF_SIZE]u8 = undefined;
    if (stat(res, &a) != 0 or stat(".", &b) != 0) return getcwd(null, 0);
    // Compare st_dev (first field) and st_ino (second field on most archs).
    // Both are typically 8 bytes each, starting at offset 0.
    if (@as(*const u64, @ptrCast(@alignCast(&a[0]))).* == @as(*const u64, @ptrCast(@alignCast(&b[0]))).* and
        @as(*const u64, @ptrCast(@alignCast(&a[8]))).* == @as(*const u64, @ptrCast(@alignCast(&b[8]))).*) {
        return strdup(res);
    }
    return getcwd(null, 0);
}

// ── mntent ─────────────────────────────────────────────────────────────

const FILE = anyopaque;
extern "c" fn fopen(path: [*:0]const u8, mode: [*:0]const u8) ?*FILE;
extern "c" fn fclose(f: *FILE) c_int;
extern "c" fn fgets(buf: [*]u8, size: c_int, f: *FILE) ?[*]u8;
extern "c" fn feof(f: *FILE) c_int;
extern "c" fn ferror(f: *FILE) c_int;
extern "c" fn fscanf(f: *FILE, fmt: [*:0]const u8, ...) c_int;
extern "c" fn sscanf(s: [*]const u8, fmt: [*:0]const u8, ...) c_int;
extern "c" fn fprintf(f: *FILE, fmt: [*:0]const u8, ...) c_int;
extern "c" fn fseek(f: *FILE, offset: c_long, whence: c_int) c_int;
extern "c" fn strlen(s: [*:0]const u8) usize;
extern "c" fn strchr(s: [*:0]const u8, c: c_int) ?[*:0]const u8;
extern "c" fn strstr(haystack: [*:0]const u8, needle: [*:0]const u8) ?[*:0]const u8;
extern "c" fn getline(lineptr: *?[*:0]u8, n: *usize, f: *FILE) isize;

const SEEK_END = 2;

const mntent = extern struct {
    mnt_fsname: ?[*:0]u8,
    mnt_dir: ?[*:0]u8,
    mnt_type: ?[*:0]u8,
    mnt_opts: ?[*:0]u8,
    mnt_freq: c_int,
    mnt_passno: c_int,
};

fn setmntent(name: [*:0]const u8, mode: [*:0]const u8) callconv(.c) ?*FILE {
    return fopen(name, mode);
}

fn endmntent(f: ?*FILE) callconv(.c) c_int {
    if (f) |stream| _ = fclose(stream);
    return 1;
}

var internal_buf: ?[*:0]u8 = null;
var internal_bufsize: usize = 0;
var static_mnt: mntent = undefined;

fn unescape_ent(beg: [*:0]u8) [*:0]u8 {
    var dest: [*]u8 = @ptrCast(beg);
    var src: [*]const u8 = @ptrCast(beg);
    while (src[0] != 0) {
        if (src[0] != '\\') {
            dest[0] = src[0];
            dest += 1;
            src += 1;
            continue;
        }
        if (src[1] == '\\') {
            src += 1;
            dest[0] = src[0];
            dest += 1;
            src += 1;
            continue;
        }
        var cval: u8 = 0;
        var val: [*]const u8 = src + 1;
        for (0..3) |_| {
            if (val[0] >= '0' and val[0] <= '7') {
                cval = (cval << 3) + (val[0] - '0');
                val += 1;
            } else break;
        }
        if (cval != 0) {
            dest[0] = cval;
            dest += 1;
            src = val;
        } else {
            dest[0] = src[0];
            dest += 1;
            src += 1;
        }
    }
    dest[0] = 0;
    return beg;
}

const SENTINEL: [*]u8 = @ptrCast(&internal_buf);

fn getmntent_r(f: *FILE, mnt_out: *mntent, linebuf_arg: [*]u8, buflen: c_int) callconv(.c) ?*mntent {
    const use_internal = (linebuf_arg == SENTINEL);
    var n: [8]c_int = undefined;

    mnt_out.mnt_freq = 0;
    mnt_out.mnt_passno = 0;

    while (true) {
        var linebuf: [*:0]u8 = undefined;
        if (use_internal) {
            _ = getline(&internal_buf, &internal_bufsize, f);
            linebuf = internal_buf orelse return null;
        } else {
            if (fgets(linebuf_arg, buflen, f) == null) return null;
            linebuf = @ptrCast(linebuf_arg);
        }
        if (feof(f) != 0 or ferror(f) != 0) return null;

        const len: c_int = @intCast(strlen(linebuf));
        for (&n) |*p| p.* = len;
        _ = sscanf(linebuf, " %n%*[^ \t]%n %n%*[^ \t]%n %n%*[^ \t]%n %n%*[^ \t]%n %d %d",
            &n[0], &n[1], &n[2], &n[3], &n[4], &n[5], &n[6], &n[7],
            &mnt_out.mnt_freq, &mnt_out.mnt_passno);

        const lb: [*]u8 = @ptrCast(linebuf);
        if (lb[@intCast(n[0])] == '#' or n[1] == len) continue;

        lb[@intCast(n[1])] = 0;
        lb[@intCast(n[3])] = 0;
        lb[@intCast(n[5])] = 0;
        lb[@intCast(n[7])] = 0;

        mnt_out.mnt_fsname = unescape_ent(@ptrCast(lb + @as(usize, @intCast(n[0]))));
        mnt_out.mnt_dir = unescape_ent(@ptrCast(lb + @as(usize, @intCast(n[2]))));
        mnt_out.mnt_type = unescape_ent(@ptrCast(lb + @as(usize, @intCast(n[4]))));
        mnt_out.mnt_opts = unescape_ent(@ptrCast(lb + @as(usize, @intCast(n[6]))));

        return mnt_out;
    }
}

fn getmntent(f: *FILE) callconv(.c) ?*mntent {
    return getmntent_r(f, &static_mnt, SENTINEL, 0);
}

fn addmntent(f: *FILE, mnt_in: *const mntent) callconv(.c) c_int {
    if (fseek(f, 0, SEEK_END) != 0) return 1;
    return if (fprintf(f, "%s\t%s\t%s\t%s\t%d\t%d\n",
        mnt_in.mnt_fsname, mnt_in.mnt_dir, mnt_in.mnt_type, mnt_in.mnt_opts,
        mnt_in.mnt_freq, mnt_in.mnt_passno) < 0) @as(c_int, 1) else 0;
}

fn hasmntopt(mnt_in: *const mntent, opt: [*:0]const u8) callconv(.c) ?[*:0]const u8 {
    return strstr(mnt_in.mnt_opts orelse return null, opt);
}
    if (builtin.link_libc) {
        symbol(&realpath, "realpath");
    }
}

extern "c" fn getcwd(buf: [*]u8, size: usize) ?[*:0]u8;
extern "c" fn readlink(path: [*:0]const u8, buf: [*]u8, bufsiz: usize) isize;
extern "c" fn strdup(s: [*:0]const u8) ?[*:0]u8;
extern "c" fn __strchrnul(s: [*:0]const u8, c: c_int) [*:0]const u8;
extern "c" fn strnlen(s: [*]const u8, maxlen: usize) usize;
extern "c" fn memcpy(dst: *anyopaque, src: *const anyopaque, n: usize) *anyopaque;
extern "c" fn memmove(dst: *anyopaque, src: *const anyopaque, n: usize) *anyopaque;
extern "c" fn strlen(s: [*:0]const u8) usize;

const PATH_MAX = 4096;
const SYMLOOP_MAX = 40;

fn slash_len(s: []const u8) usize {
    var n: usize = 0;
    while (n < s.len and s[n] == '/') : (n += 1) {}
    return n;
}

fn realpath(filename: ?[*:0]const u8, resolved: ?[*]u8) callconv(.c) ?[*:0]u8 {
    const fname = filename orelse {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return null;
    };
    const l = strnlen(@ptrCast(fname), PATH_MAX + 1);
    if (l == 0) {
        std.c._errno().* = @intFromEnum(linux.E.NOENT);
        return null;
    }
    if (l >= PATH_MAX) {
        std.c._errno().* = @intFromEnum(linux.E.NAMETOOLONG);
        return null;
    }

    var stack: [PATH_MAX + 1]u8 = undefined;
    var output: [PATH_MAX]u8 = undefined;
    var cnt: usize = 0;
    var nup: usize = 0;
    var check_dir: bool = false;

    var p: usize = PATH_MAX + 1 - l - 1;
    var q: usize = 0;
    _ = memcpy(@ptrCast(&stack[p]), @as(*const anyopaque, @ptrCast(fname)), l + 1);

    restart: while (true) {
        while (true) {
            p += slash_len(stack[p..]);
            if (stack[p] == '/') {
                check_dir = false;
                nup = 0;
                q = 0;
                output[q] = '/';
                q += 1;
                p += 1;
                if (stack[p] == '/' and stack[p + 1] != '/') {
                    output[q] = '/';
                    q += 1;
                }
                continue;
            }

            const z = @intFromPtr(__strchrnul(@ptrCast(stack[p..].ptr), '/')) - @intFromPtr(&stack[p]);
            const l0 = z;
            var comp_l = z;

            if (comp_l == 0 and !check_dir) break;

            if (comp_l == 1 and stack[p] == '.') {
                p += comp_l;
                continue;
            }

            if (q > 0 and output[q - 1] != '/') {
                if (p == 0) {
                    std.c._errno().* = @intFromEnum(linux.E.NAMETOOLONG);
                    return null;
                }
                p -= 1;
                stack[p] = '/';
                comp_l += 1;
            }
            if (q + comp_l >= PATH_MAX) {
                std.c._errno().* = @intFromEnum(linux.E.NAMETOOLONG);
                return null;
            }
            _ = memcpy(@ptrCast(&output[q]), @as(*const anyopaque, @ptrCast(&stack[p])), comp_l);
            output[q + comp_l] = 0;
            p += comp_l;

            var up = false;
            if (l0 == 2 and stack[p - 2] == '.' and stack[p - 1] == '.') {
                up = true;
                if (q <= 3 * nup) {
                    nup += 1;
                    q += comp_l;
                    continue;
                }
                if (!check_dir) {
                    // skip_readlink path
                    check_dir = false;
                    while (q > 0 and output[q - 1] != '/') q -= 1;
                    if (q > 1 and (q > 2 or output[0] != '/')) q -= 1;
                    continue;
                }
            }
            const k = readlink(@ptrCast(output[0..q + comp_l :0]), &stack, p);
            if (k == @as(isize, @intCast(p))) {
                std.c._errno().* = @intFromEnum(linux.E.NAMETOOLONG);
                return null;
            }
            if (k == 0) {
                std.c._errno().* = @intFromEnum(linux.E.NOENT);
                return null;
            }
            if (k < 0) {
                if (std.c._errno().* != @intFromEnum(linux.E.INVAL)) return null;
                // Not a symlink — skip_readlink
                check_dir = false;
                if (up) {
                    while (q > 0 and output[q - 1] != '/') q -= 1;
                    if (q > 1 and (q > 2 or output[0] != '/')) q -= 1;
                    continue;
                }
                if (l0 != 0) q += comp_l;
                check_dir = stack[p] != 0;
                continue;
            }
            cnt += 1;
            if (cnt == SYMLOOP_MAX) {
                std.c._errno().* = @intFromEnum(linux.E.LOOP);
                return null;
            }
            const uk: usize = @intCast(k);
            if (stack[uk - 1] == '/') {
                while (stack[p] == '/') p += 1;
            }
            p -= uk;
            _ = memmove(@ptrCast(&stack[p]), @as(*const anyopaque, @ptrCast(&stack[0])), uk);
            continue :restart;
        }
        break;
    }

    output[q] = 0;

    if (output[0] != '/') {
        if (getcwd(&stack, stack.len) == null) return null;
        var gl: usize = strlen(@ptrCast(&stack));
        p = 0;
        while (nup > 0) : (nup -= 1) {
            while (gl > 1 and stack[gl - 1] != '/') gl -= 1;
            if (gl > 1) gl -= 1;
            p += 2;
            if (p < q) p += 1;
        }
        if (q - p > 0 and stack[gl - 1] != '/') {
            stack[gl] = '/';
            gl += 1;
        }
        if (gl + (q - p) + 1 >= PATH_MAX) {
            std.c._errno().* = @intFromEnum(linux.E.NAMETOOLONG);
            return null;
        }
        _ = memmove(@ptrCast(&output[gl]), @as(*const anyopaque, @ptrCast(&output[p])), q - p + 1);
        _ = memcpy(@ptrCast(&output), @as(*const anyopaque, @ptrCast(&stack)), gl);
        q = gl + q - p;
    }

    if (resolved) |r| {
        _ = memcpy(r, @as(*const anyopaque, @ptrCast(&output)), q + 1);
        return @ptrCast(r);
    } else {
        return strdup(@ptrCast(output[0..q :0]));
    }
// C library dependencies.
extern "c" fn mbtowc(pwc: ?*c_uint, s: [*]const u8, n: usize) c_int;
extern "c" fn fputs(s: [*:0]const u8, f: *anyopaque) c_int;
extern "c" fn fwrite(ptr: *const anyopaque, size: usize, nmemb: usize, f: *anyopaque) usize;
extern "c" fn putc(c: c_int, f: *anyopaque) c_int;
extern "c" fn strlen(s: [*:0]const u8) usize;
extern "c" fn flockfile(f: *anyopaque) void;
extern "c" fn funlockfile(f: *anyopaque) void;
extern "c" var stderr: *anyopaque;

const MB_LEN_MAX = 4;

// ── Global state ───────────────────────────────────────────────────────

var optarg_val: ?[*:0]u8 = null;
var optind_val: c_int = 1;
var opterr_val: c_int = 1;
var optopt_val: c_int = 0;
var optpos_val: c_int = 0;
var optreset_val: c_int = 0;

comptime {
    if (builtin.link_libc) {
        @export(&optarg_val, .{ .name = "optarg" });
        symbol(&optind_val, "optind");
        symbol(&opterr_val, "opterr");
        symbol(&optopt_val, "optopt");
        symbol(&optpos_val, "__optpos");
        symbol(&optreset_val, "__optreset");
        symbol(&optreset_val, "optreset");
        symbol(&__getopt_msg, "__getopt_msg");
        symbol(&getopt_fn, "getopt");
        symbol(&getopt_fn, "__posix_getopt");
    }
}

fn __getopt_msg(a: [*:0]const u8, b: [*:0]const u8, c_ptr: [*]const u8, l: usize) callconv(.c) void {
    const f = stderr;
    flockfile(f);
    _ = fputs(a, f);
    _ = fwrite(b, strlen(b), 1, f);
    _ = fwrite(c_ptr, 1, l, f);
    _ = putc('\n', f);
    funlockfile(f);
}

fn getopt_fn(
    argc: c_int,
    argv: [*]const ?[*:0]u8,
    optstring_arg: [*:0]const u8,
) callconv(.c) c_int {
    if (optind_val == 0 or optreset_val != 0) {
        optreset_val = 0;
        optpos_val = 0;
        optind_val = 1;
    }

    if (optind_val >= argc) return -1;
    const cur = argv[@intCast(optind_val)] orelse return -1;
    if (cur[0] != '-') {
        if (optstring_arg[0] == '-') {
            optarg_val = @constCast(cur);
            optind_val += 1;
            return 1;
        }
        return -1;
    }
    if (cur[1] == 0) return -1;
    if (cur[1] == '-' and cur[2] == 0) {
        optind_val += 1;
        return -1;
    }

    if (optpos_val == 0) optpos_val = 1;

    var c: c_uint = undefined;
    const cur_bytes: [*]const u8 = @ptrCast(cur);
    var k = mbtowc(&c, cur_bytes + @as(usize, @intCast(optpos_val)), MB_LEN_MAX);
    if (k < 0) {
        k = 1;
        c = 0xfffd;
    }
    const optchar: [*]const u8 = cur_bytes + @as(usize, @intCast(optpos_val));
    optpos_val += k;

    if (cur[@intCast(optpos_val)] == 0) {
        optind_val += 1;
        optpos_val = 0;
    }

    var optstring = optstring_arg;
    if (optstring[0] == '-' or optstring[0] == '+') optstring = @ptrCast(@as([*]const u8, @ptrCast(optstring)) + 1);

    var i: usize = 0;
    var d: c_uint = 0;
    while (true) {
        const os_bytes: [*]const u8 = @ptrCast(optstring);
        const l = mbtowc(&d, os_bytes + i, MB_LEN_MAX);
        if (l > 0) {
            i += @intCast(l);
        } else {
            i += 1;
        }
        if (l == 0 or d == c) break;
    }

    if (d != c or c == ':') {
        optopt_val = @intCast(c);
        if (optstring_arg[0] != ':' and opterr_val != 0)
            __getopt_msg(@ptrCast(argv[0].?), ": unrecognized option: ", optchar, @intCast(k));
        return '?';
    }

    const os_bytes: [*]const u8 = @ptrCast(optstring);
    if (os_bytes[i] == ':') {
        optarg_val = null;
        if (os_bytes[i + 1] != ':' or optpos_val != 0) {
            if (optind_val >= argc) {
                optopt_val = @intCast(c);
                if (optstring_arg[0] == ':') return ':';
                if (opterr_val != 0)
                    __getopt_msg(@ptrCast(argv[0].?), ": option requires an argument: ", optchar, @intCast(k));
                return '?';
            }
            const next = argv[@intCast(optind_val)] orelse null;
            optind_val += 1;
            if (optpos_val != 0) {
                if (next) |n| {
                    optarg_val = @ptrCast(@constCast(@as([*]const u8, @ptrCast(n)) + @as(usize, @intCast(optpos_val))));
                }
            } else {
                optarg_val = @constCast(next);
            }
            optpos_val = 0;
        }
    }
    return @intCast(c);
}
