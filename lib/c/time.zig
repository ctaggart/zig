const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;
const TZNAME_MAX = 6;
const NAME_MAX = linux.NAME_MAX;
const PATH_MAX = linux.PATH_MAX;
const timeb = extern struct {
    time: linux.time_t,
    millitm: c_ushort,
    timezone: c_short,
    dstflag: c_short,
};
const time_t = linux.time_t;
const tm = extern struct {
    tm_sec: c_int,
    tm_min: c_int,
    tm_hour: c_int,
    tm_mday: c_int,
    tm_mon: c_int,
    tm_year: c_int,
    tm_wday: c_int,
    tm_yday: c_int,
    tm_isdst: c_int,
    __tm_gmtoff: c_long,
    __tm_zone: ?[*:0]const u8,
};
const __utc: [3:0]u8 = "UTC".*;
var __timezone: c_long = 0;
var __daylight: c_int = 0;
var __tzname: [2]?[*:0]const u8 = .{ null, null };
var std_name: [TZNAME_MAX + 1:0]u8 = [_:0]u8{0} ** (TZNAME_MAX + 1);
var dst_name: [TZNAME_MAX + 1:0]u8 = [_:0]u8{0} ** (TZNAME_MAX + 1);
var dst_off: c_int = 0;
var r0: [5]c_int = .{0} ** 5;
var r1: [5]c_int = .{0} ** 5;
var zi: ?[*]const u8 = null;
var trans: [*]const u8 = undefined;
var index: [*]const u8 = undefined;
var types: [*]const u8 = undefined;
var abbrevs: [*]const u8 = undefined;
var abbrevs_end: [*]const u8 = undefined;
var map_size: usize = 0;
var old_tz_buf: [32:0]u8 = [_:0]u8{0} ** 32;
var old_tz: ?[*]u8 = &old_tz_buf;
var old_tz_size: usize = 32;
var timezone_lock: c_int = 0;
var __timezone_lockptr: *volatile c_int = &timezone_lock;
const LibC = extern struct {
    can_do_threads: u8,
    threaded: u8,
    secure: u8,
    need_locks: i8,
};
extern var __libc: LibC;
const secs_through_month = [12]c_int{
    0,           31 * 86400,  59 * 86400,  90 * 86400,
    120 * 86400, 151 * 86400, 181 * 86400, 212 * 86400,
    243 * 86400, 273 * 86400, 304 * 86400, 334 * 86400,
};
const LEAPOCH = 946684800 + 86400 * (31 + 29);
const DAYS_PER_400Y = 365 * 400 + 97;
const DAYS_PER_100Y = 365 * 100 + 24;
const DAYS_PER_4Y = 365 * 4 + 1;
const days_in_month = [12]u8{ 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 31, 29 };
var gmtime_buf: tm = undefined;
const day_abbr = [7]*const [3]u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
const mon_abbr = [12]*const [3]u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
var asctime_buf: [26]u8 = undefined;
// ctime/ctime_r depend on localtime which is provided by the C library
extern "c" fn localtime(t: *const time_t) callconv(.c) ?*tm;
extern "c" fn localtime_r(t: *const time_t, result: *tm) callconv(.c) ?*tm;
// Internal helpers (remain as C or from other Zig PRs)
var localtime_buf: tm = undefined;
extern "c" fn getenv(name: [*:0]const u8) callconv(.c) ?[*:0]const u8;
extern "c" fn fopen(path: [*:0]const u8, mode: [*:0]const u8) callconv(.c) ?*anyopaque;
extern "c" fn fgets(buf: [*]u8, size: c_int, stream: *anyopaque) callconv(.c) ?[*]u8;
extern "c" fn fclose(stream: *anyopaque) callconv(.c) c_int;
extern "c" fn ferror(stream: *anyopaque) callconv(.c) c_int;
extern "c" fn strptime(s: [*:0]const u8, fmt: [*:0]const u8, t: *tm) callconv(.c) ?[*:0]const u8;
extern "c" fn pthread_setcancelstate(state: c_int, oldstate: ?*c_int) callconv(.c) c_int;
extern "c" fn malloc(size: usize) callconv(.c) ?*anyopaque;
extern "c" fn __map_file(pathname: [*:0]const u8, size: *usize) callconv(.c) ?[*]const u8;
extern "c" fn __lock(l: *volatile c_int) callconv(.c) void;
extern "c" fn __unlock(l: *volatile c_int) callconv(.c) void;
const PTHREAD_CANCEL_DEFERRED = 0;
var getdate_err: c_int = 0;
var tmbuf: tm = undefined;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&ftimeLinux, "ftime");
        symbol(&__localtime_r, "localtime_r");
        symbol(&nanosleepLinux, "nanosleep");
        symbol(&clock_nanosleepLinux, "clock_nanosleep");
        symbol(&clock_nanosleepLinux, "__clock_nanosleep");
        symbol(&__gmtime_r, "gmtime_r");
        symbol(&timespec_getLinux, "timespec_get");
        symbol(&clock_gettimeLinux, "clock_gettime");
        symbol(&clock_gettimeLinux, "__clock_gettime");
        symbol(&clock_settimeLinux, "clock_settime");
        symbol(&clock_getresLinux, "clock_getres");
        symbol(&gettimeofdayLinux, "gettimeofday");
        symbol(&timeLinux, "time");
        symbol(&clockLinux, "clock");
        symbol(&clock_getcpuclockidLinux, "clock_getcpuclockid");
        symbol(&timer_deleteLinux, "timer_delete");
        symbol(&timer_getoverrunLinux, "timer_getoverrun");
        symbol(&timer_gettimeLinux, "timer_gettime");
        symbol(&__secs_to_zone, "__secs_to_zone");
        symbol(&__tzset, "__tzset");
        symbol(&__tzset, "tzset");
        symbol(&__tm_to_tzname, "__tm_to_tzname");
        symbol(&__timezone, "__timezone");
        symbol(&__timezone, "timezone");
        symbol(&__daylight, "__daylight");
        symbol(&__daylight, "daylight");
        symbol(&__tzname, "__tzname");
        symbol(&__tzname, "tzname");
        @export(&__timezone_lockptr, .{ .name = "__timezone_lockptr", .linkage = .weak, .visibility = .hidden });
    }
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&difftimeImpl, "difftime");
        symbol(&__month_to_secs, "__month_to_secs");
        symbol(&__year_to_secs, "__year_to_secs");
        symbol(&__secs_to_tm, "__secs_to_tm");
        symbol(&__tm_to_secs, "__tm_to_secs");
        symbol(&timegmImpl, "timegm");
        symbol(&__gmtime_r, "__gmtime_r");
        symbol(&gmtimeImpl, "gmtime");
        symbol(&__utc, "__utc");
        symbol(&__asctime_r, "__asctime_r");
        symbol(&asctimeImpl, "asctime");
    }
    if (builtin.link_libc) {
        symbol(&ctimeImpl, "ctime");
        symbol(&ctime_rImpl, "ctime_r");
        symbol(&__localtime_r, "__localtime_r");
        symbol(&localtimeImpl, "localtime");
        symbol(&mktimeImpl, "mktime");
        symbol(&getdate_err, "getdate_err");
        symbol(&getdateImpl, "getdate");
    }
}

fn clock_gettimeLinux(clk: c_int, ts: *linux.timespec) callconv(.c) c_int {
    return errno(linux.clock_gettime(@enumFromInt(@as(u32, @bitCast(clk))), ts));
}

fn clock_settimeLinux(clk: c_int, ts: *const linux.timespec) callconv(.c) c_int {
    return errno(linux.clock_settime(@enumFromInt(@as(u32, @bitCast(clk))), ts));
}

fn clock_getresLinux(clk: c_int, ts: *linux.timespec) callconv(.c) c_int {
    return errno(linux.clock_getres(@enumFromInt(@as(u32, @bitCast(clk))), ts));
}

fn gettimeofdayLinux(tv: ?*linux.timeval, _: ?*anyopaque) callconv(.c) c_int {
    const t = tv orelse return 0;
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.REALTIME, &ts);
    t.sec = ts.sec;
    t.usec = @intCast(@divTrunc(ts.nsec, 1000));
    return 0;
}

fn timeLinux(t: ?*linux.time_t) callconv(.c) linux.time_t {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.REALTIME, &ts);
    const sec: linux.time_t = @intCast(ts.sec);
    if (t) |ptr| ptr.* = sec;
    return sec;
}

fn cStringLen(s: [*:0]const u8) usize {
    var i: usize = 0;
    while (s[i] != 0) : (i += 1) {}
    return i;
}

fn cStringEq(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: usize = 0;
    while (a[i] == b[i]) : (i += 1) {
        if (a[i] == 0) return true;
    }
    return false;
}

fn cStringChr(s: [*:0]const u8, c: u8) bool {
    var i: usize = 0;
    while (s[i] != 0) : (i += 1) {
        if (s[i] == c) return true;
    }
    return false;
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c | 32) >= 'a' and (c | 32) <= 'z';
}

fn lockTimezone() void {
    __lock(&timezone_lock);
}

fn unlockTimezone() void {
    __unlock(&timezone_lock);
}

fn clockLinux() callconv(.c) c_long {
    var ts: linux.timespec = undefined;
    if (errno(linux.clock_gettime(.PROCESS_CPUTIME_ID, &ts)) != 0) return -1;
    const max = std.math.maxInt(c_long);
    if (ts.sec > @divTrunc(max, 1000000)) return -1;
    const usec: c_long = @intCast(@divTrunc(ts.nsec, 1000));
    const sec_usec: c_long = @as(c_long, @intCast(ts.sec)) * 1000000;
    if (usec > max - sec_usec) return -1;
    return sec_usec + usec;
}

fn clock_getcpuclockidLinux(pid: linux.pid_t, clk: *linux.clockid_t) callconv(.c) c_int {
    var ts: linux.timespec = undefined;
    const id_raw: u32 = @bitCast((-pid -% 1) *% 8 +% 2);
    const id: linux.clockid_t = @enumFromInt(id_raw);
    const signed: isize = @bitCast(linux.clock_getres(id, &ts));
    if (signed == -@as(isize, @intFromEnum(linux.E.INVAL))) {
        return @intFromEnum(linux.E.SRCH);
    }
    if (signed < 0) return @intCast(-signed);
    clk.* = id;
    return 0;
}

fn difftimeImpl(t1: linux.time_t, t0: linux.time_t) callconv(.c) f64 {
    return @floatFromInt(t1 -% t0);
}

fn ftimeLinux(tp: *timeb) callconv(.c) c_int {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.REALTIME, &ts);
    tp.time = @intCast(ts.sec);
    tp.millitm = @intCast(@divTrunc(ts.nsec, 1000000));
    tp.timezone = 0;
    tp.dstflag = 0;
    return 0;
}

fn timespec_getLinux(ts: *linux.timespec, base: c_int) callconv(.c) c_int {
    if (base != 1) return 0; // TIME_UTC = 1
    if (errno(linux.clock_gettime(.REALTIME, ts)) < 0) return 0;
    return base;
}

fn __month_to_secs(month: c_int, is_leap: c_int) callconv(.c) c_int {
    var t = secs_through_month[@intCast(@as(c_uint, @bitCast(month)))];
    if (is_leap != 0 and month >= 2) t += 86400;
    return t;
}

fn __year_to_secs(year: c_longlong, is_leap: ?*c_int) callconv(.c) c_longlong {
    const y_u: u64 = @bitCast(year);
    if (y_u -% 2 <= 136) {
        const y: c_int = @intCast(year);
        var leaps = @divTrunc(y - 68, 4);
        if (@rem(y - 68, 4) == 0) {
            leaps -= 1;
            if (is_leap) |p| p.* = 1;
        } else {
            if (is_leap) |p| p.* = 0;
        }
        return @as(c_longlong, 31536000) * (y - 70) + @as(c_longlong, 86400) * leaps;
    }

    var dummy: c_int = undefined;
    const leap_ptr = is_leap orelse &dummy;

    var cycles: c_int = @intCast(@divTrunc(year - 100, 400));
    var rem: c_int = @intCast(@rem(year - 100, 400));
    if (rem < 0) {
        cycles -= 1;
        rem += 400;
    }

    var centuries: c_int = undefined;
    var leaps: c_int = undefined;
    if (rem == 0) {
        leap_ptr.* = 1;
        centuries = 0;
        leaps = 0;
    } else {
        if (rem >= 200) {
            if (rem >= 300) {
                centuries = 3;
                rem -= 300;
            } else {
                centuries = 2;
                rem -= 200;
            }
        } else {
            if (rem >= 100) {
                centuries = 1;
                rem -= 100;
            } else {
                centuries = 0;
            }
        }
        if (rem == 0) {
            leap_ptr.* = 0;
            leaps = 0;
        } else {
            leaps = @intCast(@divTrunc(@as(c_uint, @bitCast(rem)), 4));
            rem = @intCast(@as(c_uint, @bitCast(rem)) % 4);
            leap_ptr.* = @intFromBool(rem == 0);
        }
    }

    leaps += 97 * cycles + 24 * centuries - leap_ptr.*;
    return (year - 100) * 31536000 + @as(c_longlong, leaps) * 86400 + 946684800 + 86400;
}

fn __secs_to_tm(t: c_longlong, r: *tm) callconv(.c) c_int {
    if (t < @as(c_longlong, std.math.minInt(c_int)) * 31622400 or
        t > @as(c_longlong, std.math.maxInt(c_int)) * 31622400) return -1;

    const secs = t - LEAPOCH;
    var days = @divTrunc(secs, 86400);
    var remsecs: c_int = @intCast(@rem(secs, 86400));
    if (remsecs < 0) {
        remsecs += 86400;
        days -= 1;
    }

    var wday: c_int = @intCast(@rem(3 + days, 7));
    if (wday < 0) wday += 7;

    var qc_cycles: c_int = @intCast(@divTrunc(days, DAYS_PER_400Y));
    var remdays: c_int = @intCast(@rem(days, DAYS_PER_400Y));
    if (remdays < 0) {
        remdays += DAYS_PER_400Y;
        qc_cycles -= 1;
    }

    var c_cycles = @divTrunc(remdays, DAYS_PER_100Y);
    if (c_cycles == 4) c_cycles -= 1;
    remdays -= c_cycles * DAYS_PER_100Y;

    var q_cycles = @divTrunc(remdays, DAYS_PER_4Y);
    if (q_cycles == 25) q_cycles -= 1;
    remdays -= q_cycles * DAYS_PER_4Y;

    var remyears = @divTrunc(remdays, 365);
    if (remyears == 4) remyears -= 1;
    remdays -= remyears * 365;

    const leap: c_int = @intFromBool(remyears == 0 and (q_cycles != 0 or c_cycles == 0));
    var yday = remdays + 31 + 28 + leap;
    if (yday >= 365 + leap) yday -= 365 + leap;

    const years: c_longlong = @as(c_longlong, remyears) + 4 * q_cycles + 100 * c_cycles + @as(c_longlong, 400) * qc_cycles;

    var months: c_int = 0;
    while (days_in_month[@intCast(@as(c_uint, @bitCast(months)))] <= @as(u8, @intCast(@as(c_uint, @bitCast(remdays))))) {
        remdays -= @intCast(days_in_month[@intCast(@as(c_uint, @bitCast(months)))]);
        months += 1;
    }

    if (months >= 10) {
        months -= 12;
        const y2 = years + 1;
        if (y2 + 100 > std.math.maxInt(c_int) or y2 + 100 < std.math.minInt(c_int)) return -1;
        r.tm_year = @intCast(y2 + 100);
    } else {
        if (years + 100 > std.math.maxInt(c_int) or years + 100 < std.math.minInt(c_int)) return -1;
        r.tm_year = @intCast(years + 100);
    }
    r.tm_mon = months + 2;
    r.tm_mday = remdays + 1;
    r.tm_wday = wday;
    r.tm_yday = yday;
    r.tm_hour = @divTrunc(remsecs, 3600);
    r.tm_min = @rem(@divTrunc(remsecs, 60), 60);
    r.tm_sec = @rem(remsecs, 60);
    return 0;
}

fn __tm_to_secs(t: *const tm) callconv(.c) c_longlong {
    var year: c_longlong = t.tm_year;
    var month = t.tm_mon;
    if (month >= 12 or month < 0) {
        var adj = @divTrunc(month, 12);
        month = @rem(month, 12);
        if (month < 0) {
            adj -= 1;
            month += 12;
        }
        year += adj;
    }
    var result = __year_to_secs(year, null);
    result += __month_to_secs(month, @intFromBool(false));
    result += @as(c_longlong, 86400) * (t.tm_mday - 1);
    result += @as(c_longlong, 3600) * t.tm_hour;
    result += @as(c_longlong, 60) * t.tm_min;
    result += t.tm_sec;
    return result;
}

fn timegmImpl(t: *tm) callconv(.c) time_t {
    var new: tm = undefined;
    const secs = __tm_to_secs(t);
    if (__secs_to_tm(secs, &new) < 0) {
        std.c._errno().* = @intFromEnum(linux.E.OVERFLOW);
        return -1;
    }
    new.tm_isdst = 0;
    new.__tm_gmtoff = 0;
    new.__tm_zone = &__utc;
    t.* = new;
    return @intCast(secs);
}

fn __gmtime_r(t: *const time_t, r: *tm) callconv(.c) ?*tm {
    if (__secs_to_tm(t.*, r) < 0) {
        std.c._errno().* = @intFromEnum(linux.E.OVERFLOW);
        return null;
    }
    r.tm_isdst = 0;
    r.__tm_gmtoff = 0;
    r.__tm_zone = &__utc;
    return r;
}

fn gmtimeImpl(t: *const time_t) callconv(.c) ?*tm {
    return __gmtime_r(t, &gmtime_buf);
}

fn writeDecimal(buf: [*]u8, value: c_int, width: u8) void {
    var v: u32 = if (value < 0) @intCast(-value) else @intCast(value);
    var i: u8 = width;
    while (i > 0) {
        i -= 1;
        buf[i] = '0' + @as(u8, @intCast(v % 10));
        v /= 10;
    }
    if (value < 0 and width > 0) buf[0] = '-';
}

fn __asctime_r(t: *const tm, buf: [*]u8) callconv(.c) [*]u8 {
    const wday: usize = @intCast(@as(c_uint, @bitCast(t.tm_wday)) % 7);
    const mon: usize = @intCast(@as(c_uint, @bitCast(t.tm_mon)) % 12);

    // "Sun Jan  1 00:00:00 2000\n\0" = 26 bytes
    @memcpy(buf[0..3], day_abbr[wday]);
    buf[3] = ' ';
    @memcpy(buf[4..7], mon_abbr[mon]);

    // day of month (space-padded to 3 chars)
    const mday = t.tm_mday;
    if (mday < 10) {
        buf[7] = ' ';
        buf[8] = ' ';
        buf[9] = '0' + @as(u8, @intCast(@as(c_uint, @bitCast(mday))));
    } else if (mday < 100) {
        buf[7] = ' ';
        buf[8] = '0' + @as(u8, @intCast(@as(c_uint, @bitCast(mday)) / 10));
        buf[9] = '0' + @as(u8, @intCast(@as(c_uint, @bitCast(mday)) % 10));
    } else {
        writeDecimal(buf + 7, mday, 3);
    }
    buf[10] = ' ';

    writeDecimal(buf + 11, t.tm_hour, 2);
    buf[13] = ':';
    writeDecimal(buf + 14, t.tm_min, 2);
    buf[16] = ':';
    writeDecimal(buf + 17, t.tm_sec, 2);
    buf[19] = ' ';

    // year (1900 + tm_year)
    const year = 1900 + t.tm_year;
    if (year >= 0 and year <= 9999) {
        writeDecimal(buf + 20, year, 4);
    } else {
        writeDecimal(buf + 20, year, 4);
    }
    buf[24] = '\n';
    buf[25] = 0;
    return buf;
}

fn asctimeImpl(t: *const tm) callconv(.c) [*]u8 {
    return __asctime_r(t, &asctime_buf);
}

fn ctimeImpl(t: *const time_t) callconv(.c) ?[*]u8 {
    const r = localtime(t) orelse return null;
    return asctimeImpl(r);
}

fn ctime_rImpl(t: *const time_t, buf: [*]u8) callconv(.c) ?[*]u8 {
    var result: tm = undefined;
    const r = localtime_r(t, &result) orelse return null;
    return __asctime_r(r, buf);
}

fn getint(p: *[*:0]const u8) c_int {
    var x: c_uint = 0;
    while (isDigit(p.*[0])) : (p.* += 1) x = @as(c_uint, p.*[0] - '0') + 10 * x;
    return @intCast(x);
}

fn getoff(p: *[*:0]const u8) c_int {
    var neg = false;
    if (p.*[0] == '-') {
        p.* += 1;
        neg = true;
    } else if (p.*[0] == '+') p.* += 1;
    var off: c_int = 3600 * getint(p);
    if (p.*[0] == ':') {
        p.* += 1;
        off += 60 * getint(p);
        if (p.*[0] == ':') {
            p.* += 1;
            off += getint(p);
        }
    }
    return if (neg) -off else off;
}

fn getrule(p: *[*:0]const u8, rule: *[5]c_int) void {
    const r: c_int = p.*[0];
    rule[0] = r;
    if (r != 'M') {
        if (r == 'J') p.* += 1 else rule[0] = 0;
        rule[1] = getint(p);
    } else {
        p.* += 1;
        rule[1] = getint(p);
        p.* += 1;
        rule[2] = getint(p);
        p.* += 1;
        rule[3] = getint(p);
    }
    if (p.*[0] == '/') {
        p.* += 1;
        rule[4] = getoff(p);
    } else rule[4] = 7200;
}

fn getname(d: [*:0]u8, p: *[*:0]const u8) void {
    var i: usize = 0;
    if (p.*[0] == '<') {
        p.* += 1;
        while (p.*[i] != 0 and p.*[i] != '>') : (i += 1) {
            if (i < TZNAME_MAX) d[i] = p.*[i];
        }
        if (p.*[i] != 0) p.* += 1;
    } else while (isAlpha(p.*[i])) : (i += 1) {
        if (i < TZNAME_MAX) d[i] = p.*[i];
    }
    p.* += i;
    d[if (i < TZNAME_MAX) i else TZNAME_MAX] = 0;
}

fn ziRead32(z: [*]const u8) u32 {
    return @as(u32, z[0]) << 24 | @as(u32, z[1]) << 16 | @as(u32, z[2]) << 8 | z[3];
}
fn ziDotprod(z_start: [*]const u8, v: []const u8) usize {
    var z = z_start;
    var y: usize = 0;
    for (v) |coef| {
        y += @as(usize, ziRead32(z)) * coef;
        z += 4;
    }
    return y;
}

fn doTzset() void {
    var buf: [NAME_MAX + 25:0]u8 = [_:0]u8{0} ** (NAME_MAX + 25);
    const pathname_base: [*:0]u8 = @ptrCast((&buf).ptr + 24);
    var map: ?[*]const u8 = null;
    var s = getenv("TZ") orelse "/etc/localtime";
    if (s[0] == 0) s = &__utc;
    if (old_tz) |ot| if (cStringEq(@ptrCast(ot), s)) return;
    for (0..5) |i| {
        r0[i] = 0;
        r1[i] = 0;
    }
    if (zi) |z| _ = linux.munmap(z, map_size);
    zi = null;
    var s_len = cStringLen(s);
    if (s_len > PATH_MAX + 1) {
        s = &__utc;
        s_len = 3;
    }
    if (s_len >= old_tz_size) {
        old_tz_size *= 2;
        if (s_len >= old_tz_size) old_tz_size = s_len + 1;
        if (old_tz_size > PATH_MAX + 2) old_tz_size = PATH_MAX + 2;
        old_tz = @ptrCast(malloc(old_tz_size));
    }
    if (old_tz) |ot| @memcpy(ot[0 .. s_len + 1], s[0 .. s_len + 1]);
    var posix_form = false;
    if (s[0] != ':') {
        var p2 = s;
        var dummy_name: [TZNAME_MAX + 1:0]u8 = [_:0]u8{0} ** (TZNAME_MAX + 1);
        getname(&dummy_name, &p2);
        if (p2 != s and (p2[0] == '+' or p2[0] == '-' or isDigit(p2[0]) or cStringEq(&dummy_name, "UTC") or cStringEq(&dummy_name, "GMT"))) posix_form = true;
    }
    if (!posix_form) {
        if (s[0] == ':') s += 1;
        if (s[0] == '/' or s[0] == '.') {
            if (__libc.secure == 0 or cStringEq(s, "/etc/localtime")) map = __map_file(s, &map_size);
        } else {
            const l0 = cStringLen(s);
            if (l0 <= NAME_MAX and !cStringChr(s, '.')) {
                @memcpy(pathname_base[0 .. l0 + 1], s[0 .. l0 + 1]);
                pathname_base[l0] = 0;
                const search = "/usr/share/zoneinfo/\x00/share/zoneinfo/\x00/etc/zoneinfo/\x00";
                var try_idx: usize = 0;
                while (map == null and search[try_idx] != 0) {
                    const try_path: [*:0]const u8 = @ptrCast(search.ptr + try_idx);
                    const l = cStringLen(try_path);
                    @memcpy((pathname_base - l)[0..l], try_path[0..l]);
                    map = __map_file(pathname_base - l, &map_size);
                    try_idx += l + 1;
                }
            }
        }
        if (map == null) s = &__utc;
    }
    if (map) |m| if (map_size < 44 or !std.mem.eql(u8, m[0..4], "TZif")) {
        _ = linux.munmap(m, map_size);
        map = null;
        s = &__utc;
    };
    zi = map;
    if (map) |m| {
        var scale: u5 = 2;
        if (m[4] != '1') {
            const skip = ziDotprod(m + 20, &.{ 1, 1, 8, 5, 6, 1 });
            trans = m + skip + 44 + 44;
            scale += 1;
        } else trans = m + 44;
        index = trans + (ziRead32(trans - 12) << scale);
        types = index + ziRead32(trans - 12);
        abbrevs = types + 6 * ziRead32(trans - 8);
        abbrevs_end = abbrevs + ziRead32(trans - 4);
        if (m[map_size - 1] == '\n') {
            var pos = map_size - 2;
            while (m[pos] != '\n') : (pos -= 1) {}
            s = @ptrCast(m + pos + 1);
        } else {
            __tzname = .{ null, null };
            __daylight = 0;
            __timezone = 0;
            dst_off = 0;
            var tp = types;
            while (@intFromPtr(tp) < @intFromPtr(abbrevs)) : (tp += 6) {
                if (tp[4] == 0 and __tzname[0] == null) {
                    __tzname[0] = @ptrCast(abbrevs + tp[5]);
                    __timezone = -@as(c_long, @intCast(@as(i32, @bitCast(ziRead32(tp)))));
                }
                if (tp[4] != 0 and __tzname[1] == null) {
                    __tzname[1] = @ptrCast(abbrevs + tp[5]);
                    dst_off = -@as(c_int, @bitCast(ziRead32(tp)));
                    __daylight = 1;
                }
            }
            if (__tzname[0] == null) __tzname[0] = __tzname[1];
            if (__tzname[0] == null) __tzname[0] = &__utc;
            if (__daylight == 0) {
                __tzname[1] = __tzname[0];
                dst_off = @intCast(__timezone);
            }
            return;
        }
    }
    getname(&std_name, &s);
    __tzname[0] = &std_name;
    __timezone = getoff(&s);
    getname(&dst_name, &s);
    __tzname[1] = &dst_name;
    if (dst_name[0] != 0) {
        __daylight = 1;
        if (s[0] == '+' or s[0] == '-' or isDigit(s[0])) dst_off = getoff(&s) else dst_off = @intCast(__timezone - 3600);
    } else {
        __daylight = 0;
        dst_off = @intCast(__timezone);
    }
    if (s[0] == ',') {
        s += 1;
        getrule(&s, &r0);
    }
    if (s[0] == ',') {
        s += 1;
        getrule(&s, &r1);
    }
}

fn scanTrans(t: c_longlong, local: c_int, alt: ?*usize) usize {
    const z = zi.?;
    const scale: u5 = 3 - @intFromBool(trans == z + 44);
    var off: c_int = 0;
    var a: usize = 0;
    var n: usize = (@intFromPtr(index) - @intFromPtr(trans)) >> scale;
    if (n == 0) {
        if (alt) |ap| ap.* = 0;
        return 0;
    }
    while (n > 1) {
        const m = a + n / 2;
        var xu = @as(u64, ziRead32(trans + (m << scale)));
        const x: c_longlong = if (scale == 3) blk: {
            xu = xu << 32 | ziRead32(trans + (m << scale) + 4);
            break :blk @bitCast(xu);
        } else @as(i32, @bitCast(@as(u32, @intCast(xu))));
        if (local != 0) off = @bitCast(ziRead32(types + 6 * index[m - 1]));
        if (t - off < x) n /= 2 else {
            a = m;
            n -= n / 2;
        }
    }
    n = (@intFromPtr(index) - @intFromPtr(trans)) >> scale;
    if (a == n - 1) return std.math.maxInt(usize);
    if (a == 0) {
        var xu = @as(u64, ziRead32(trans));
        const x: c_longlong = if (scale == 3) blk: {
            xu = xu << 32 | ziRead32(trans + 4);
            break :blk @bitCast(xu);
        } else @as(i32, @bitCast(@as(u32, @intCast(xu))));
        var j: usize = 0;
        var i: usize = @intFromPtr(abbrevs) - @intFromPtr(types);
        while (i != 0) {
            i -= 6;
            if (types[i + 4] == 0) j = i;
        }
        if (local != 0) off = @bitCast(ziRead32(types + j));
        if (t - off < x) {
            if (alt) |ap| ap.* = index[0];
            return j / 6;
        }
    }
    if (alt) |ap| {
        if (a != 0 and types[6 * index[a - 1] + 4] != types[6 * index[a] + 4]) ap.* = index[a - 1] else if (a + 1 < n and types[6 * index[a + 1] + 4] != types[6 * index[a] + 4]) ap.* = index[a + 1] else ap.* = index[a];
    }
    return index[a];
}

fn daysInMonth(m: c_int, is_leap: c_int) c_int {
    if (m == 2) return 28 + is_leap;
    return 30 + @as(c_int, @intCast((@as(u32, 0xad5) >> @intCast(m - 1)) & 1));
}

fn ruleToSecs(rule: *const [5]c_int, year: c_longlong) c_longlong {
    var is_leap: c_int = undefined;
    var t = __year_to_secs(year, &is_leap);
    if (rule[0] != 'M') {
        var x = rule[1];
        if (rule[0] == 'J' and (x < 60 or is_leap == 0)) x -= 1;
        t += 86400 * @as(c_longlong, x);
    } else {
        var n = rule[2];
        t += __month_to_secs(rule[1] - 1, is_leap);
        const wday: c_int = @intCast(@divTrunc(@mod(t + 4 * 86400, 7 * 86400), 86400));
        var days = rule[3] - wday;
        if (days < 0) days += 7;
        if (n == 5 and days + 28 >= daysInMonth(rule[1], is_leap)) n = 4;
        t += 86400 * @as(c_longlong, days + 7 * (n - 1));
    }
    t += rule[4];
    return t;
}

fn __secs_to_zone(t: c_longlong, local: c_int, isdst: *c_int, offset: *c_long, oppoff: ?*c_long, zonename: *?[*:0]const u8) callconv(.c) void {
    lockTimezone();
    doTzset();
    if (zi != null) {
        var alt: usize = undefined;
        const i = scanTrans(t, local, &alt);
        if (i != std.math.maxInt(usize)) {
            isdst.* = types[6 * i + 4];
            offset.* = @as(i32, @bitCast(ziRead32(types + 6 * i)));
            zonename.* = @ptrCast(abbrevs + types[6 * i + 5]);
            if (oppoff) |op| op.* = @as(i32, @bitCast(ziRead32(types + 6 * alt)));
            unlockTimezone();
            return;
        }
    }
    if (__daylight != 0) {
        var y: c_longlong = @divTrunc(t, 31556952) + 70;
        while (__year_to_secs(y, null) > t) y -= 1;
        while (__year_to_secs(y + 1, null) < t) y += 1;
        var t0 = ruleToSecs(&r0, y);
        var t1 = ruleToSecs(&r1, y);
        if (local == 0) {
            t0 += __timezone;
            t1 += dst_off;
        }
        if (t0 < t1) {
            if (t >= t0 and t < t1) {
                isdst.* = 1;
                offset.* = -dst_off;
                if (oppoff) |op| op.* = -__timezone;
                zonename.* = __tzname[1];
                unlockTimezone();
                return;
            }
        } else if (!(t >= t1 and t < t0)) {
            isdst.* = 1;
            offset.* = -dst_off;
            if (oppoff) |op| op.* = -__timezone;
            zonename.* = __tzname[1];
            unlockTimezone();
            return;
        }
    }
    isdst.* = 0;
    offset.* = -__timezone;
    if (oppoff) |op| op.* = -dst_off;
    zonename.* = __tzname[0];
    unlockTimezone();
}

fn __tzset() callconv(.c) void {
    lockTimezone();
    doTzset();
    unlockTimezone();
}

fn __tm_to_tzname(t: *const tm) callconv(.c) [*:0]const u8 {
    var p = t.__tm_zone orelse return "";
    lockTimezone();
    doTzset();
    if (p != &__utc and p != __tzname[0] and p != __tzname[1]) {
        if (zi == null or @intFromPtr(p) -% @intFromPtr(abbrevs) >= @intFromPtr(abbrevs_end) - @intFromPtr(abbrevs)) p = "";
    }
    unlockTimezone();
    return p;
}

fn __localtime_r(t: *const time_t, r: *tm) callconv(.c) ?*tm {
    const t64: c_longlong = t.*;
    if (t64 < @as(c_longlong, std.math.minInt(c_int)) * 31622400 or
        t64 > @as(c_longlong, std.math.maxInt(c_int)) * 31622400)
    {
        std.c._errno().* = @intFromEnum(linux.E.OVERFLOW);
        return null;
    }
    __secs_to_zone(t64, 0, &r.tm_isdst, &r.__tm_gmtoff, null, &r.__tm_zone);
    if (__secs_to_tm(t64 + r.__tm_gmtoff, r) < 0) {
        std.c._errno().* = @intFromEnum(linux.E.OVERFLOW);
        return null;
    }
    return r;
}

fn localtimeImpl(t: *const time_t) callconv(.c) ?*tm {
    return __localtime_r(t, &localtime_buf);
}

fn mktimeImpl(t: *tm) callconv(.c) time_t {
    var new: tm = undefined;
    var opp: c_long = undefined;
    var secs = __tm_to_secs(t);

    __secs_to_zone(secs, 1, &new.tm_isdst, &new.__tm_gmtoff, &opp, &new.__tm_zone);

    if (t.tm_isdst >= 0 and new.tm_isdst != t.tm_isdst)
        secs -= opp - new.__tm_gmtoff;

    secs -= new.__tm_gmtoff;

    __secs_to_zone(secs, 0, &new.tm_isdst, &new.__tm_gmtoff, &opp, &new.__tm_zone);

    if (__secs_to_tm(secs + new.__tm_gmtoff, &new) < 0) {
        std.c._errno().* = @intFromEnum(linux.E.OVERFLOW);
        return -1;
    }

    t.* = new;
    return @intCast(secs);
}

fn getdateImpl(s: [*:0]const u8) callconv(.c) ?*tm {
    var ret: ?*tm = null;
    var cs: c_int = undefined;
    _ = pthread_setcancelstate(PTHREAD_CANCEL_DEFERRED, &cs);

    const datemsk = getenv("DATEMSK") orelse {
        getdate_err = 1;
        _ = pthread_setcancelstate(cs, null);
        return null;
    };

    const f = fopen(datemsk, "rbe") orelse {
        if (std.c._errno().* == @intFromEnum(linux.E.NOMEM))
            getdate_err = 6
        else
            getdate_err = 2;
        _ = pthread_setcancelstate(cs, null);
        return null;
    };

    var fmt: [100]u8 = undefined;
    while (fgets(&fmt, 100, f)) |_| {
        const p = strptime(s, @ptrCast(&fmt), &tmbuf);
        if (p) |pp| {
            if (pp[0] == 0) {
                ret = &tmbuf;
                break;
            }
        }
    } else {
        if (ferror(f) != 0)
            getdate_err = 5
        else
            getdate_err = 7;
    }

    _ = fclose(f);
    _ = pthread_setcancelstate(cs, null);
    return ret;
}

fn nanosleepLinux(req: *const linux.timespec, rem: ?*linux.timespec) callconv(.c) c_int {
    return errno(linux.nanosleep(req, rem));
}

fn clock_nanosleepLinux(clk: c_int, flags: c_int, req: *const linux.timespec, rem: ?*linux.timespec) callconv(.c) c_int {
    const r = linux.clock_nanosleep(@enumFromInt(@as(u32, @bitCast(clk))), @bitCast(@as(u32, @bitCast(flags))), req, rem);
    if (r != 0) {
        std.c._errno().* = @intCast(r);
        return -1;
    }
    return 0;
}

// timer_delete.c
const SIGTIMER: usize = 32;
const ptr_size = @sizeOf(usize);
const tls_above_tp = switch (builtin.cpu.arch) {
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb, .riscv64, .riscv32, .mips, .mipsel, .mips64, .mips64el, .powerpc, .powerpcle, .powerpc64, .powerpc64le, .loongarch64, .m68k => true,
    else => false,
};
const part1_size: usize = if (tls_above_tp) 4 * ptr_size else 6 * ptr_size;
const map_base_off: usize = if (ptr_size == 8) 24 else 20;
const off_tid = part1_size;
const off_timer_id = part1_size + map_base_off + 11 * ptr_size + 4;

fn timer_deleteLinux(t: *opaque {}) callconv(.c) c_int {
    const t_int: isize = @bitCast(@intFromPtr(t));
    if (t_int < 0) {
        const td_addr: usize = @intFromPtr(t) << 1;
        const timer_id_ptr: *volatile c_int = @ptrFromInt(td_addr + off_timer_id);
        const old_val = @atomicLoad(c_int, timer_id_ptr, .seq_cst);
        @atomicStore(c_int, timer_id_ptr, old_val | std.math.minInt(c_int), .seq_cst);
        const tid: c_int = (@as(*const c_int, @ptrFromInt(td_addr + off_tid))).*;
        _ = linux.syscall2(.tkill, @as(usize, @intCast(tid)), SIGTIMER);
        return 0;
    }
    return errno(linux.syscall1(.timer_delete, @intFromPtr(t)));
}

// timer_getoverrun.c
fn timer_getoverrunLinux(t: *opaque {}) callconv(.c) c_int {
    var sys_t: usize = @intFromPtr(t);
    const t_int: isize = @bitCast(sys_t);
    if (t_int < 0) {
        const td_addr: usize = sys_t << 1;
        const timer_id: c_int = (@as(*const c_int, @ptrFromInt(td_addr + off_timer_id))).*;
        sys_t = @as(usize, @intCast(timer_id & std.math.maxInt(c_int)));
    }
    return errno(linux.syscall1(.timer_getoverrun, sys_t));
}

// timer_gettime.c
fn timer_gettimeLinux(t: *opaque {}, val: *linux.itimerspec) callconv(.c) c_int {
    var sys_t: usize = @intFromPtr(t);
    const t_int: isize = @bitCast(sys_t);
    if (t_int < 0) {
        const td_addr: usize = sys_t << 1;
        const timer_id: c_int = (@as(*const c_int, @ptrFromInt(td_addr + off_timer_id))).*;
        sys_t = @as(usize, @intCast(timer_id & std.math.maxInt(c_int)));
    }

    if (comptime !@hasField(linux.SYS, "timer_gettime64")) {
        // 64-bit-time arches: timer_gettime is the kernel's natural 64-bit-time entry.
        return errno(linux.syscall2(.timer_gettime, sys_t, @intFromPtr(val)));
    }
    if (comptime !@hasField(linux.SYS, "timer_gettime")) {
        // 32-bit-time-only arches (riscv32, loongarch32): only timer_gettime64 exists.
        return errno(linux.syscall2(.timer_gettime64, sys_t, @intFromPtr(val)));
    }
    // Legacy 32-bit arches with both: prefer time64, fall back to legacy on -ENOSYS.
    const enosys: isize = -@as(isize, @intFromEnum(linux.E.NOSYS));
    var r: isize = enosys;
    if (@sizeOf(linux.time_t) > 4) {
        r = @bitCast(linux.syscall2(.timer_gettime64, sys_t, @intFromPtr(val)));
    }
    if (r != enosys) {
        return errno(@as(usize, @bitCast(r)));
    }
    var val32: [4]c_long = undefined;
    r = @bitCast(linux.syscall2(.timer_gettime, sys_t, @intFromPtr(&val32)));
    if (r == 0) {
        val.it_interval.sec = @intCast(val32[0]);
        val.it_interval.nsec = @intCast(val32[1]);
        val.it_value.sec = @intCast(val32[2]);
        val.it_value.nsec = @intCast(val32[3]);
    }
    return errno(@as(usize, @bitCast(r)));
}
