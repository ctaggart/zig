const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;
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
extern "c" fn __secs_to_zone(t: c_longlong, local: c_int, isdst: *c_int, offset: *c_long, oppoff: ?*c_long, zonename: *?[*:0]const u8) callconv(.c) void;
var localtime_buf: tm = undefined;
extern "c" fn getenv(name: [*:0]const u8) callconv(.c) ?[*:0]const u8;
extern "c" fn fopen(path: [*:0]const u8, mode: [*:0]const u8) callconv(.c) ?*anyopaque;
extern "c" fn fgets(buf: [*]u8, size: c_int, stream: *anyopaque) callconv(.c) ?[*]u8;
extern "c" fn fclose(stream: *anyopaque) callconv(.c) c_int;
extern "c" fn ferror(stream: *anyopaque) callconv(.c) c_int;
extern "c" fn strptime(s: [*:0]const u8, fmt: [*:0]const u8, t: *tm) callconv(.c) ?[*:0]const u8;
extern "c" fn pthread_setcancelstate(state: c_int, oldstate: ?*c_int) callconv(.c) c_int;
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
        symbol(&strftimeFmt1, "__strftime_fmt_1");
        symbol(&__strftime_l, "__strftime_l");
        symbol(&strftimeImpl, "strftime");
        symbol(&__strftime_l, "strftime_l");
        symbol(&__wcsftime_l, "__wcsftime_l");
        symbol(&wcsftimeImpl, "wcsftime");
        symbol(&__wcsftime_l, "wcsftime_l");
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

const locale_t = *opaque {};
const nl_item = c_int;
const wchar_t = std.c.wchar_t;

const ABDAY_1: nl_item = 0x20000;
const DAY_1: nl_item = 0x20007;
const ABMON_1: nl_item = 0x2000E;
const MON_1: nl_item = 0x2001A;
const AM_STR: nl_item = 0x20026;
const PM_STR: nl_item = 0x20027;
const D_T_FMT: nl_item = 0x20028;
const D_FMT: nl_item = 0x20029;
const T_FMT: nl_item = 0x2002A;
const T_FMT_AMPM: nl_item = 0x2002B;

extern "c" fn __nl_langinfo_l(item: nl_item, loc: locale_t) callconv(.c) [*:0]const u8;
extern "c" fn __tm_to_tzname(t: *const tm) callconv(.c) [*:0]const u8;
extern "c" fn pthread_self() callconv(.c) *pthread;
extern "c" fn mbstowcs(dest: ?[*]wchar_t, src: [*:0]const u8, n: usize) callconv(.c) usize;

const locale_struct = extern struct { cat: [6]?*const anyopaque };
const pthread = extern struct {
    self: *pthread,
    dtv: if (tls_above_tp) void else *usize,
    prev: *pthread,
    next: *pthread,
    sysinfo: usize,
    canary_pad: if (comptime builtin.cpu.arch == .mips64 or builtin.cpu.arch == .mips64el) usize else void,
    canary: if (tls_above_tp) void else usize,
    tid: c_int,
    errno_val: c_int,
    detach_state: c_int,
    cancel: c_int,
    canceldisable: u8,
    cancelasync: u8,
    tsd_used_dlerror_flag: u8,
    map_base: *u8,
    map_size: usize,
    stack: *anyopaque,
    stack_size: usize,
    guard_size: usize,
    result: *anyopaque,
    cancelbuf: *anyopaque,
    tsd: *?*anyopaque,
    robust_list: extern struct { head: *volatile anyopaque, off: c_long, pending: *volatile anyopaque },
    h_errno_val: c_int,
    timer_id: c_int,
    locale: *locale_struct,
};

fn currentLocale() locale_t {
    return @ptrCast(pthread_self().locale);
}

fn isLeap(y_arg: c_int) c_int {
    var y = y_arg;
    if (y > std.math.maxInt(c_int) - 1900) y -= 2000;
    y += 1900;
    return @intFromBool(@rem(y, 4) == 0 and (@rem(y, 100) != 0 or @rem(y, 400) == 0));
}

fn weekNum(t: *const tm) c_int {
    var val: c_int = @intCast((@as(c_uint, @bitCast(t.tm_yday)) + 7 - ((@as(c_uint, @bitCast(t.tm_wday)) + 6) % 7)) / 7);
    if ((@as(c_uint, @bitCast(t.tm_wday)) + 371 - @as(c_uint, @bitCast(t.tm_yday)) - 2) % 7 <= 2) val += 1;
    if (val == 0) {
        val = 52;
        const dec31 = (@as(c_uint, @bitCast(t.tm_wday)) + 7 - @as(c_uint, @bitCast(t.tm_yday)) - 1) % 7;
        if (dec31 == 4 or (dec31 == 5 and isLeap(@rem(t.tm_year, 400) - 1) != 0)) val += 1;
    } else if (val == 53) {
        const jan1 = (@as(c_uint, @bitCast(t.tm_wday)) + 371 - @as(c_uint, @bitCast(t.tm_yday))) % 7;
        if (jan1 != 4 and (jan1 != 3 or isLeap(t.tm_year) == 0)) val = 1;
    }
    return val;
}

fn cstrLen(s: [*:0]const u8) usize {
    var i: usize = 0;
    while (s[i] != 0) : (i += 1) {}
    return i;
}

fn fmtSigned(buf: *[100]u8, val: c_longlong, width: usize, pad: u8) usize {
    var tmp: [64]u8 = undefined;
    const neg = val < 0;
    var u: u64 = if (neg) @intCast(-(val + 1)) else @intCast(val);
    if (neg) u += 1;
    var pos: usize = tmp.len;
    while (true) {
        pos -= 1;
        tmp[pos] = '0' + @as(u8, @intCast(u % 10));
        u /= 10;
        if (u == 0) break;
    }
    const digits_len = tmp.len - pos;
    var out: usize = 0;
    if (pad == '0') {
        if (neg) {
            buf[out] = '-';
            out += 1;
        }
        var pad_count = if (width > digits_len + @intFromBool(neg)) width - digits_len - @intFromBool(neg) else 0;
        while (pad_count != 0) : (pad_count -= 1) {
            buf[out] = '0';
            out += 1;
        }
    } else {
        var pad_count = if (width > digits_len + @intFromBool(neg)) width - digits_len - @intFromBool(neg) else 0;
        if (pad == '_') while (pad_count != 0) : (pad_count -= 1) {
            buf[out] = ' ';
            out += 1;
        };
        if (neg) {
            buf[out] = '-';
            out += 1;
        }
    }
    @memcpy(buf[out .. out + digits_len], tmp[pos..]);
    out += digits_len;
    buf[out] = 0;
    return out;
}

fn fmtZone(buf: *[100]u8, val: c_long) usize {
    const neg = val < 0;
    var u: c_long = if (neg) -val else val;
    buf[0] = if (neg) '-' else '+';
    var i: usize = 5;
    while (i > 1) {
        i -= 1;
        buf[i] = '0' + @as(u8, @intCast(@rem(u, 10)));
        u = @divTrunc(u, 10);
    }
    buf[5] = 0;
    return 5;
}
fn stringResult(s: [*:0]const u8, len: *usize) [*:0]const u8 {
    len.* = cstrLen(s);
    return s;
}
fn nlStrcat(item: nl_item, loc: locale_t, len: *usize) [*:0]const u8 {
    return stringResult(__nl_langinfo_l(item, loc), len);
}
fn nlStrftime(buf: *[100]u8, len: *usize, item: nl_item, t: *const tm, loc: locale_t) ?[*:0]const u8 {
    return recuStrftime(buf, len, __nl_langinfo_l(item, loc), t, loc);
}
fn recuStrftime(buf: *[100]u8, len: *usize, fmt: [*:0]const u8, t: *const tm, loc: locale_t) ?[*:0]const u8 {
    len.* = __strftime_l(@ptrCast(buf), buf.len, fmt, t, loc);
    if (len.* == 0) return null;
    return @ptrCast(buf);
}

fn strftimeFmt1(buf: *[100]u8, len: *usize, f: c_int, t: *const tm, loc: locale_t, pad_arg: c_int) callconv(.c) ?[*:0]const u8 {
    var val: c_longlong = undefined;
    var width: usize = 2;
    var def_pad: u8 = '0';
    switch (f) {
        'a' => return if (@as(c_uint, @bitCast(t.tm_wday)) > 6) stringResult("-", len) else nlStrcat(ABDAY_1 + t.tm_wday, loc, len),
        'A' => return if (@as(c_uint, @bitCast(t.tm_wday)) > 6) stringResult("-", len) else nlStrcat(DAY_1 + t.tm_wday, loc, len),
        'h', 'b' => return if (@as(c_uint, @bitCast(t.tm_mon)) > 11) stringResult("-", len) else nlStrcat(ABMON_1 + t.tm_mon, loc, len),
        'B' => return if (@as(c_uint, @bitCast(t.tm_mon)) > 11) stringResult("-", len) else nlStrcat(MON_1 + t.tm_mon, loc, len),
        'c' => return nlStrftime(buf, len, D_T_FMT, t, loc),
        'C' => val = @divTrunc(@as(c_longlong, 1900) + t.tm_year, 100),
        'e' => {
            def_pad = '_';
            val = t.tm_mday;
        },
        'd' => val = t.tm_mday,
        'D' => return recuStrftime(buf, len, "%m/%d/%y", t, loc),
        'F' => return recuStrftime(buf, len, "%Y-%m-%d", t, loc),
        'g', 'G' => {
            val = @as(c_longlong, t.tm_year) + 1900;
            if (t.tm_yday < 3 and weekNum(t) != 1) val -= 1 else if (t.tm_yday > 360 and weekNum(t) == 1) val += 1;
            if (f == 'g') val = @rem(val, 100) else width = 4;
        },
        'H' => val = t.tm_hour,
        'I' => {
            val = t.tm_hour;
            if (val == 0) val = 12 else if (val > 12) val -= 12;
        },
        'j' => {
            val = t.tm_yday + 1;
            width = 3;
        },
        'm' => val = t.tm_mon + 1,
        'M' => val = t.tm_min,
        'n' => {
            len.* = 1;
            return "\n";
        },
        'p' => return nlStrcat(if (t.tm_hour >= 12) PM_STR else AM_STR, loc, len),
        'r' => return nlStrftime(buf, len, T_FMT_AMPM, t, loc),
        'R' => return recuStrftime(buf, len, "%H:%M", t, loc),
        's' => {
            val = __tm_to_secs(t) - t.__tm_gmtoff;
            width = 1;
        },
        'S' => val = t.tm_sec,
        't' => {
            len.* = 1;
            return "\t";
        },
        'T' => return recuStrftime(buf, len, "%H:%M:%S", t, loc),
        'u' => {
            val = if (t.tm_wday != 0) t.tm_wday else 7;
            width = 1;
        },
        'U' => val = @intCast((@as(c_uint, @bitCast(t.tm_yday)) + 7 - @as(c_uint, @bitCast(t.tm_wday))) / 7),
        'W' => val = @intCast((@as(c_uint, @bitCast(t.tm_yday)) + 7 - ((@as(c_uint, @bitCast(t.tm_wday)) + 6) % 7)) / 7),
        'V' => val = weekNum(t),
        'w' => {
            val = t.tm_wday;
            width = 1;
        },
        'x' => return nlStrftime(buf, len, D_FMT, t, loc),
        'X' => return nlStrftime(buf, len, T_FMT, t, loc),
        'y' => {
            val = @rem(@as(c_longlong, t.tm_year) + 1900, 100);
            if (val < 0) val = -val;
        },
        'Y' => {
            val = @as(c_longlong, t.tm_year) + 1900;
            if (val >= 10000) {
                len.* = fmtSigned(buf, val, 1, '-');
                if (buf[0] != '-') {
                    std.mem.copyBackwards(u8, buf[1 .. len.* + 1], buf[0..len.*]);
                    buf[0] = '+';
                    len.* += 1;
                    buf[len.*] = 0;
                }
                return @ptrCast(buf);
            }
            width = 4;
        },
        'z' => {
            if (t.tm_isdst < 0) {
                len.* = 0;
                return "";
            }
            len.* = fmtZone(buf, @divTrunc(t.__tm_gmtoff, 3600) * 100 + @divTrunc(@rem(t.__tm_gmtoff, 3600), 60));
            return @ptrCast(buf);
        },
        'Z' => {
            if (t.tm_isdst < 0) {
                len.* = 0;
                return "";
            }
            return stringResult(__tm_to_tzname(t), len);
        },
        '%' => {
            len.* = 1;
            return "%";
        },
        else => return null,
    }
    const pad: u8 = if (pad_arg != 0) @intCast(pad_arg) else def_pad;
    len.* = switch (pad) {
        '-' => fmtSigned(buf, val, 1, '-'),
        '_' => fmtSigned(buf, val, width, '_'),
        else => fmtSigned(buf, val, width, '0'),
    };
    return @ptrCast(buf);
}

fn parseAsciiWidth(f: [*:0]const u8, end: *[*:0]const u8) c_ulong {
    var p = f;
    var width: c_ulong = 0;
    while (p[0] >= '0' and p[0] <= '9') : (p += 1) width = width * 10 + (p[0] - '0');
    end.* = p;
    return width;
}

fn __strftime_l(s: [*]u8, n: usize, f_arg: [*:0]const u8, t: *const tm, loc: locale_t) callconv(.c) usize {
    var l: usize = 0;
    var f = f_arg;
    while (l < n) : (f += 1) {
        if (f[0] == 0) {
            s[l] = 0;
            return l;
        }
        if (f[0] != '%') {
            s[l] = f[0];
            l += 1;
            continue;
        }
        f += 1;
        var pad: c_int = 0;
        if (f[0] == '-' or f[0] == '_' or f[0] == '0') {
            pad = f[0];
            f += 1;
        }
        const plus = f[0] == '+';
        if (plus) f += 1;
        var p: [*:0]const u8 = undefined;
        var width = parseAsciiWidth(f, &p);
        if (p[0] == 'C' or p[0] == 'F' or p[0] == 'G' or p[0] == 'Y') {
            if (width == 0 and p != f) width = 1;
        } else width = 0;
        f = p;
        if (f[0] == 'E' or f[0] == 'O') f += 1;
        var buf: [100]u8 = undefined;
        var k: usize = undefined;
        var text = strftimeFmt1(&buf, &k, f[0], t, loc, pad) orelse break;
        if (width != 0) {
            if (text[0] == '+' or text[0] == '-') {
                text += 1;
                k -= 1;
            }
            while (text[0] == '0' and @as(c_uint, text[1] -% '0') < 10) {
                text += 1;
                k -= 1;
            }
            if (width < k) width = k;
            var d: usize = 0;
            while (@as(c_uint, text[d] -% '0') < 10) : (d += 1) {}
            if (t.tm_year < -1900) {
                s[l] = '-';
                l += 1;
                width -= 1;
            } else if (plus and d + (width - k) >= if (p[0] == 'C') 3 else 5) {
                s[l] = '+';
                l += 1;
                width -= 1;
            }
            while (width > k and l < n) : (width -= 1) {
                s[l] = '0';
                l += 1;
            }
        }
        if (k > n - l) k = n - l;
        @memcpy(s[l .. l + k], text[0..k]);
        l += k;
    }
    if (n != 0) {
        if (l == n) l = n - 1;
        s[l] = 0;
    }
    return 0;
}

fn strftimeImpl(s: [*]u8, n: usize, f: [*:0]const u8, t: *const tm) callconv(.c) usize {
    return __strftime_l(s, n, f, t, currentLocale());
}

fn parseWideWidth(f: [*:0]const wchar_t, end: *[*:0]const wchar_t) c_ulong {
    var p = f;
    var width: c_ulong = 0;
    while (p[0] >= '0' and p[0] <= '9') : (p += 1) width = width * 10 + @as(c_ulong, @intCast(p[0] - '0'));
    end.* = p;
    return width;
}

fn __wcsftime_l(s: [*]wchar_t, n: usize, f_arg: [*:0]const wchar_t, t: *const tm, loc: locale_t) callconv(.c) usize {
    var l: usize = 0;
    var f = f_arg;
    while (l < n) : (f += 1) {
        if (f[0] == 0) {
            s[l] = 0;
            return l;
        }
        if (f[0] != '%') {
            s[l] = f[0];
            l += 1;
            continue;
        }
        f += 1;
        var pad: c_int = 0;
        if (f[0] == '-' or f[0] == '_' or f[0] == '0') {
            pad = @intCast(f[0]);
            f += 1;
        }
        const plus = f[0] == '+';
        if (plus) f += 1;
        var p: [*:0]const wchar_t = undefined;
        var width = parseWideWidth(f, &p);
        if (p[0] == 'C' or p[0] == 'F' or p[0] == 'G' or p[0] == 'Y') {
            if (width == 0 and p != f) width = 1;
        } else width = 0;
        f = p;
        if (f[0] == 'E' or f[0] == 'O') f += 1;
        var buf: [100]u8 = undefined;
        var wbuf: [100]wchar_t = undefined;
        var k: usize = undefined;
        const text_mb = strftimeFmt1(&buf, &k, @intCast(f[0]), t, loc, pad) orelse break;
        k = mbstowcs(&wbuf, text_mb, wbuf.len);
        if (k == std.math.maxInt(usize)) return 0;
        var text: [*]wchar_t = &wbuf;
        if (width != 0) {
            while (text[0] == '+' or text[0] == '-' or (text[0] == '0' and text[1] != 0)) {
                text += 1;
                k -= 1;
            }
            width -= 1;
            if (plus and t.tm_year >= 10000 - 1900) {
                s[l] = '+';
                l += 1;
            } else if (t.tm_year < -1900) {
                s[l] = '-';
                l += 1;
            } else width += 1;
            while (width > k and l < n) : (width -= 1) {
                s[l] = '0';
                l += 1;
            }
        }
        if (k >= n - l) k = n - l;
        @memcpy(s[l .. l + k], text[0..k]);
        l += k;
    }
    if (n != 0) {
        if (l == n) l = n - 1;
        s[l] = 0;
    }
    return 0;
}

fn wcsftimeImpl(s: [*]wchar_t, n: usize, f: [*:0]const wchar_t, t: *const tm) callconv(.c) usize {
    return __wcsftime_l(s, n, f, t, currentLocale());
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
