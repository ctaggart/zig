const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&endusershell, "endusershell");
        symbol(&setusershell, "setusershell");
        symbol(&getusershell, "getusershell");
        symbol(&getpass, "getpass");
    }
}

// ── getusershell ───────────────────────────────────────────────────────

const FILE = anyopaque;
extern "c" fn fopen(path: [*:0]const u8, mode: [*:0]const u8) ?*FILE;
extern "c" fn fclose(stream: *FILE) c_int;
extern "c" fn fmemopen(buf: *const anyopaque, size: usize, mode: [*:0]const u8) ?*FILE;
extern "c" fn getline(lineptr: *?[*:0]u8, n: *usize, stream: *FILE) isize;

const defshells = "/bin/sh\n/bin/csh\n";

var us_line: ?[*:0]u8 = null;
var us_linesize: usize = 0;
var us_f: ?*FILE = null;

fn endusershell() callconv(.c) void {
    if (us_f) |stream| {
        _ = fclose(stream);
        us_f = null;
    }
}

fn setusershell() callconv(.c) void {
    if (us_f == null) us_f = fopen("/etc/shells", "rbe");
    if (us_f == null) us_f = fmemopen(@ptrCast(@constCast(defshells)), defshells.len, "rb");
}

fn getusershell() callconv(.c) ?[*:0]u8 {
    if (us_f == null) setusershell();
    const stream = us_f orelse return null;
    const l = getline(&us_line, &us_linesize, stream);
    if (l <= 0) return null;
    const line = us_line orelse return null;
    if (line[@intCast(l - 1)] == '\n') line[@intCast(l - 1)] = 0;
    return line;
}

// ── getpass ─────────────────────────────────────────────────────────────

extern "c" fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn read(fd: c_int, buf: [*]u8, count: usize) isize;
extern "c" fn tcgetattr(fd: c_int, termios_p: *anyopaque) c_int;
extern "c" fn tcsetattr(fd: c_int, action: c_int, termios_p: *const anyopaque) c_int;
extern "c" fn tcdrain(fd: c_int) c_int;
extern "c" fn dprintf(fd: c_int, fmt: [*:0]const u8, ...) c_int;

const O_RDWR = 2;
const O_NOCTTY = 0o400;
const O_CLOEXEC = 0o2000000;
const TCSAFLUSH = 2;

// termios struct is large and arch-specific; use an opaque buffer
const TERMIOS_SIZE = 60; // sizeof(struct termios) on Linux

var password: [128]u8 = undefined;

fn getpass(prompt: [*:0]const u8) callconv(.c) ?[*:0]u8 {
    const fd = open("/dev/tty", O_RDWR | O_NOCTTY | O_CLOEXEC);
    if (fd < 0) return null;

    var saved: [TERMIOS_SIZE]u8 = undefined;
    var current: [TERMIOS_SIZE]u8 = undefined;
    _ = tcgetattr(fd, &current);
    saved = current;

    // Modify c_lflag: clear ECHO (0o10) and ISIG (1), set ICANON (2)
    // c_lflag is at offset 12 in struct termios on Linux (after c_iflag, c_oflag, c_cflag)
    const lflag_offset = 12;
    var lflag: u32 = @bitCast(current[lflag_offset..][0..4].*);
    lflag &= ~@as(u32, 0o10 | 1); // clear ECHO | ISIG
    lflag |= 2; // set ICANON
    current[lflag_offset..][0..4].* = @bitCast(lflag);

    // Modify c_iflag: clear INLCR (0o100) and IGNCR (0o200), set ICRNL (0o400)
    var iflag: u32 = @bitCast(current[0..4].*);
    iflag &= ~@as(u32, 0o100 | 0o200); // clear INLCR | IGNCR
    iflag |= 0o400; // set ICRNL
    current[0..4].* = @bitCast(iflag);

    _ = tcsetattr(fd, TCSAFLUSH, &current);
    _ = tcdrain(fd);

    _ = dprintf(fd, "%s", prompt);

    const l = read(fd, &password, password.len);

    if (l >= 0) {
        var end: usize = @intCast(l);
        if ((end > 0 and password[end - 1] == '\n') or end == password.len) end -= 1;
        password[end] = 0;
    }

    _ = tcsetattr(fd, TCSAFLUSH, &saved);
    _ = dprintf(fd, "\n");
    _ = close(fd);

    return if (l < 0) null else @ptrCast(&password);
}
