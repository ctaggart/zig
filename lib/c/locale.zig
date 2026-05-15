const builtin = @import("builtin");

const std = @import("std");
const symbol = @import("../c.zig").symbol;

comptime {
    // All locale functions depend on internal musl data structures (locale_impl.h,
    // thread-local locale state, gettext catalogs, iconv tables, etc.).
    // Guard with link_libc so they are only exported when a full C library is
    // available to satisfy these internal dependencies.
    if (builtin.link_libc) {
        // __lctrans
        symbol(&__lctrans, "__lctrans");
        symbol(&__lctrans_cur, "__lctrans_cur");

        // __mo_lookup
        symbol(&__mo_lookup, "__mo_lookup");

        // bind_textdomain_codeset
        symbol(&bind_textdomain_codeset, "bind_textdomain_codeset");

        // c_locale
        // (c_locale.c defines the global __c_locale and __c_dot_utf8 objects;
        //  these are data symbols, not functions, so cannot be migrated here)

        // catclose / catgets / catopen
        symbol(&catclose, "catclose");
        symbol(&catgets, "catgets");
        symbol(&catopen, "catopen");

        // dcngettext
        symbol(&dcngettext, "dcngettext");
        symbol(&dcgettext, "dcgettext");
        symbol(&dngettext, "dngettext");
        symbol(&dgettext, "dgettext");
        symbol(&ngettext, "ngettext");
        symbol(&gettext, "gettext");

        // duplocale
        symbol(&duplocale, "duplocale");

        // freelocale
        symbol(&freelocale, "freelocale");

        // iconv / iconv_close
        symbol(&iconv, "iconv");
        symbol(&iconv_close, "iconv_close");

        // langinfo
        symbol(&nl_langinfo, "nl_langinfo");
        symbol(&nl_langinfo_l, "nl_langinfo_l");
        symbol(&__nl_langinfo_l, "__nl_langinfo_l");

        // locale_map
        symbol(&__get_locale, "__get_locale");
        symbol(&__loc_is_allocated, "__loc_is_allocated");

        // localeconv
        symbol(&localeconv, "localeconv");

        // newlocale
        symbol(&newlocale, "newlocale");

        // pleval
        symbol(&__pleval, "__pleval");

        // setlocale
        symbol(&setlocale, "setlocale");

        // strfmon
        symbol(&strfmon, "strfmon");

        // strtod_l
        symbol(&strtod_l, "strtod_l");
        symbol(&strtof_l, "strtof_l");
        symbol(&strtold_l, "strtold_l");

        // textdomain
        symbol(&textdomain, "textdomain");

        // uselocale
        symbol(&uselocale, "uselocale");

        // wcscoll / wcsxfrm
        symbol(&wcscoll, "wcscoll");
        symbol(&__wcscoll_l, "__wcscoll_l");
        symbol(&__wcsxfrm_l, "wcsxfrm_l");
        symbol(&__wcscoll_l, "wcscoll_l");
        symbol(&wcsxfrm, "wcsxfrm");
        symbol(&__wcsxfrm_l, "__wcsxfrm_l");
    }
}

// ─── Stub implementations ──────────────────────────────────────────────────
// These functions are provided as stubs that return appropriate default
// values. When linked against a real C library (link_libc), that library's
// implementations will override these weak symbols.

fn __lctrans(msg: [*:0]const c_char, _: ?*const anyopaque) callconv(.c) [*:0]const c_char {
    return msg;
}

fn __lctrans_cur(msg: [*:0]const c_char) callconv(.c) [*:0]const c_char {
    return msg;
}

fn __mo_lookup(_: ?*const anyopaque, _: usize, _: [*:0]const c_char) callconv(.c) [*:0]const c_char {
    return @ptrCast(@constCast(""));
}

fn bind_textdomain_codeset(_: ?[*:0]const c_char, _: ?[*:0]const c_char) callconv(.c) ?[*:0]c_char {
    return null;
}

fn catclose(_: c_int) callconv(.c) c_int {
    return 0;
}

fn catgets(_: c_int, _: c_int, _: c_int, s: [*:0]const c_char) callconv(.c) [*:0]const c_char {
    return s;
}

fn catopen(_: [*:0]const c_char, _: c_int) callconv(.c) c_int {
    std.c._errno().* = @intFromEnum(std.os.linux.E.NOSYS);
    return -1;
}

fn dcngettext(_: ?[*:0]const c_char, msgid1: [*:0]const c_char, msgid2: [*:0]const c_char, n: c_ulong, _: c_int) callconv(.c) [*:0]const c_char {
    return if (n == 1) @ptrCast(@constCast(msgid1)) else @ptrCast(@constCast(msgid2));
}

fn dcgettext(_: ?[*:0]const c_char, msgid: [*:0]const c_char, _: c_int) callconv(.c) [*:0]const c_char {
    return @ptrCast(@constCast(msgid));
}

fn dngettext(dom: ?[*:0]const c_char, msgid1: [*:0]const c_char, msgid2: [*:0]const c_char, n: c_ulong) callconv(.c) [*:0]const c_char {
    return dcngettext(dom, msgid1, msgid2, n, 5); // LC_MESSAGES = 5
}

fn dgettext(dom: ?[*:0]const c_char, msgid: [*:0]const c_char) callconv(.c) [*:0]const c_char {
    return dcgettext(dom, msgid, 5);
}

fn ngettext(msgid1: [*:0]const c_char, msgid2: [*:0]const c_char, n: c_ulong) callconv(.c) [*:0]const c_char {
    return dngettext(null, msgid1, msgid2, n);
}

fn gettext(msgid: [*:0]const c_char) callconv(.c) [*:0]const c_char {
    return dgettext(null, msgid);
}

fn duplocale(_: ?*anyopaque) callconv(.c) ?*anyopaque {
    return null;
}

fn freelocale(_: ?*anyopaque) callconv(.c) void {}

fn iconv(_: ?*anyopaque, _: ?*?[*]c_char, _: ?*usize, _: ?*?[*]c_char, _: ?*usize) callconv(.c) usize {
    std.c._errno().* = @intFromEnum(std.os.linux.E.INVAL);
    return @as(usize, @bitCast(@as(isize, -1)));
}

fn iconv_close(_: ?*anyopaque) callconv(.c) c_int {
    return 0;
}

const c_locale_str: [:0]const u8 = "C";
const c_utf8_locale_str: [:0]const u8 = "C.UTF-8";

/// Tracks whether the global LC_CTYPE category currently uses UTF-8.
/// Updated by `setlocale(LC_CTYPE, …)`; read by `isLcCtypeUtf8` (which
/// also honours the per-thread `uselocale` override) and through that
/// by `nl_langinfo(CODESET)`, `__ctype_get_mb_cur_max`, and every
/// multibyte / wide-char helper in libzigc.
var lc_ctype_global_utf8: bool = false;

/// Returns `true` iff the LC_CTYPE category of the active locale uses
/// UTF-8 encoding. The active locale is the per-thread override set by
/// `uselocale` if one is installed, otherwise the process-global locale
/// set by `setlocale`.
///
/// Callers in libzigc (multibyte decode/encode, ctype helpers,
/// `nl_langinfo`, the wide-char stdio paths, regex parsing) use this
/// to switch between the single-byte C/POSIX behaviour and UTF-8.
pub fn isLcCtypeUtf8() bool {
    if (thread_locale) |tl| {
        return tl == @as(*anyopaque, @ptrCast(&__c_dot_utf8_locale_obj));
    }
    return lc_ctype_global_utf8;
}

/// Returns `true` for any locale name whose codeset is UTF-8 — including
/// `C.UTF-8`, `POSIX.UTF-8`, `en_US.UTF-8`, plain `UTF-8`, and case
/// variants like `.utf8`. Permissive matching mirrors what libc-test's
/// `t_setutf8` helper expects: applications try several names in
/// sequence (`||`-chained `setlocale` calls) and the first non-NULL
/// return wins.
fn isUtf8LocaleName(name: []const u8) bool {
    if (std.ascii.eqlIgnoreCase(name, "UTF-8")) return true;
    if (std.ascii.eqlIgnoreCase(name, "utf8")) return true;
    if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot| {
        const suffix = name[dot + 1 ..];
        if (std.ascii.eqlIgnoreCase(suffix, "UTF-8")) return true;
        if (std.ascii.eqlIgnoreCase(suffix, "utf8")) return true;
    }
    return false;
}

// C-locale langinfo data (mirrors musl src/locale/langinfo.c).
// Items within a category are stored back-to-back, separated by NULs.
// nl_langinfo walks past `idx` NULs to find the requested item.
const c_time: [:0]const u8 =
    "Sun\x00Mon\x00Tue\x00Wed\x00Thu\x00Fri\x00Sat\x00" ++
    "Sunday\x00Monday\x00Tuesday\x00Wednesday\x00" ++
    "Thursday\x00Friday\x00Saturday\x00" ++
    "Jan\x00Feb\x00Mar\x00Apr\x00May\x00Jun\x00" ++
    "Jul\x00Aug\x00Sep\x00Oct\x00Nov\x00Dec\x00" ++
    "January\x00February\x00March\x00April\x00" ++
    "May\x00June\x00July\x00August\x00" ++
    "September\x00October\x00November\x00December\x00" ++
    "AM\x00PM\x00" ++
    "%a %b %e %T %Y\x00" ++
    "%m/%d/%y\x00" ++
    "%H:%M:%S\x00" ++
    "%I:%M:%S %p\x00" ++
    "\x00" ++
    "\x00" ++
    "%m/%d/%y\x00" ++
    "0123456789\x00" ++
    "%a %b %e %T %Y\x00" ++
    "%H:%M:%S";

const c_messages: [:0]const u8 = "^[yY]\x00^[nN]\x00yes\x00no";
const c_numeric: [:0]const u8 = ".\x00";

// nl_item category codes (musl convention: item >> 16).
const NL_CAT_LC_CTYPE: u32 = 0;
const NL_CAT_LC_NUMERIC: u32 = 1;
const NL_CAT_LC_TIME: u32 = 2;
const NL_CAT_LC_MONETARY: u32 = 4;
const NL_CAT_LC_MESSAGES: u32 = 5;
const NL_CAT_LC_ALL: u32 = 6;

// CODESET item value (musl, langinfo.h).
const NL_ITEM_CODESET: c_int = 14;

fn nlLangInfoImpl(item: c_int) [*:0]const u8 {
    if (item == NL_ITEM_CODESET) {
        return if (isLcCtypeUtf8()) "UTF-8" else "ASCII";
    }
    const u_item = @as(u32, @bitCast(item));
    const cat = u_item >> 16;
    var idx = u_item & 0xffff;

    // _NL_LOCALE_NAME(cat) = (cat << 16) | 0xffff — return locale name.
    if (idx == 0xffff and cat < NL_CAT_LC_ALL) return "C";

    const data: [*:0]const u8 = switch (cat) {
        NL_CAT_LC_NUMERIC => blk: {
            if (idx > 1) return "";
            break :blk c_numeric.ptr;
        },
        NL_CAT_LC_TIME => blk: {
            if (idx > 0x31) return "";
            break :blk c_time.ptr;
        },
        NL_CAT_LC_MONETARY => blk: {
            if (idx > 0) return "";
            break :blk "";
        },
        NL_CAT_LC_MESSAGES => blk: {
            if (idx > 3) return "";
            break :blk c_messages.ptr;
        },
        else => return "",
    };

    var p: [*:0]const u8 = data;
    while (idx > 0) : (idx -= 1) {
        while (p[0] != 0) p += 1;
        p += 1;
    }
    return p;
}

fn nl_langinfo(item: c_int) callconv(.c) [*:0]const c_char {
    return @ptrCast(nlLangInfoImpl(item));
}

fn nl_langinfo_l(item: c_int, _: ?*anyopaque) callconv(.c) [*:0]const c_char {
    return @ptrCast(nlLangInfoImpl(item));
}

fn __nl_langinfo_l(item: c_int, loc: ?*anyopaque) callconv(.c) [*:0]const c_char {
    return nl_langinfo_l(item, loc);
}

fn __get_locale(_: c_int, _: [*:0]const c_char) callconv(.c) ?*const anyopaque {
    return null;
}

fn __loc_is_allocated(_: ?*const anyopaque) callconv(.c) c_int {
    return 0;
}

// Static lconv structure for C locale
const c_lconv = extern struct {
    decimal_point: [*:0]const u8 = ".",
    thousands_sep: [*:0]const u8 = "",
    grouping: [*:0]const u8 = "",
    int_curr_symbol: [*:0]const u8 = "",
    currency_symbol: [*:0]const u8 = "",
    mon_decimal_point: [*:0]const u8 = "",
    mon_thousands_sep: [*:0]const u8 = "",
    mon_grouping: [*:0]const u8 = "",
    positive_sign: [*:0]const u8 = "",
    negative_sign: [*:0]const u8 = "",
    int_frac_digits: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    frac_digits: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    p_cs_precedes: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    p_sep_by_space: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    n_cs_precedes: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    n_sep_by_space: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    p_sign_posn: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    n_sign_posn: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    int_p_cs_precedes: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    int_p_sep_by_space: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    int_n_cs_precedes: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    int_n_sep_by_space: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    int_p_sign_posn: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
    int_n_sign_posn: c_char = std.math.maxInt(c_char), // CHAR_MAX in C with implicit wrap
};

var posix_lconv: c_lconv = .{};

fn localeconv() callconv(.c) *c_lconv {
    return &posix_lconv;
}

fn newlocale(_: c_int, name: ?[*:0]const c_char, base: ?*anyopaque) callconv(.c) ?*anyopaque {
    // The C and POSIX locales always resolve to the same global C-locale
    // object; any UTF-8 codeset name (`C.UTF-8`, `en_US.UTF-8`, …)
    // resolves to the C.UTF-8 locale object. Anything else is unknown
    // and falls back to `base` (matches musl's behaviour for unsupported
    // names with a non-null base).
    if (name) |n_raw| {
        const n = std.mem.span(@as([*:0]const u8, @ptrCast(n_raw)));
        if (n.len == 0 or std.mem.eql(u8, n, "C") or std.mem.eql(u8, n, "POSIX")) {
            return @ptrCast(&__c_locale_obj);
        }
        if (isUtf8LocaleName(n)) {
            return @ptrCast(&__c_dot_utf8_locale_obj);
        }
    }
    return base;
}

fn __pleval(_: [*:0]const c_char, _: c_ulong) callconv(.c) c_ulong {
    return 0;
}

fn setlocale(_: c_int, locale: ?[*:0]const c_char) callconv(.c) ?[*:0]const c_char {
    if (locale) |loc| {
        const l = std.mem.span(@as([*:0]const u8, @ptrCast(loc)));
        // Empty string means "use environment variables" (POSIX). We
        // don't read the env yet, so leave the current LC_CTYPE state
        // alone and return whatever it is.
        if (l.len == 0) {
            return @ptrCast(if (lc_ctype_global_utf8) c_utf8_locale_str.ptr else c_locale_str.ptr);
        }
        if (std.mem.eql(u8, l, "C") or std.mem.eql(u8, l, "POSIX")) {
            lc_ctype_global_utf8 = false;
            return @ptrCast(c_locale_str.ptr);
        }
        if (isUtf8LocaleName(l)) {
            lc_ctype_global_utf8 = true;
            return @ptrCast(c_utf8_locale_str.ptr);
        }
        return null;
    }
    return @ptrCast(if (lc_ctype_global_utf8) c_utf8_locale_str.ptr else c_locale_str.ptr);
}

fn strfmon(_: [*]c_char, _: usize, _: [*:0]const c_char) callconv(.c) isize {
    std.c._errno().* = @intFromEnum(std.os.linux.E.INVAL);
    return -1;
}

fn strtod_l(s: [*:0]const c_char, endp: ?*[*:0]const c_char, _: ?*anyopaque) callconv(.c) f64 {
    _ = endp;
    _ = s;
    return 0;
}

fn strtof_l(s: [*:0]const c_char, endp: ?*[*:0]const c_char, _: ?*anyopaque) callconv(.c) f32 {
    _ = endp;
    _ = s;
    return 0;
}

fn strtold_l(s: [*:0]const c_char, endp: ?*[*:0]const c_char, _: ?*anyopaque) callconv(.c) c_longdouble {
    _ = endp;
    _ = s;
    return 0;
}

fn textdomain(_: ?[*:0]const c_char) callconv(.c) [*:0]const c_char {
    return @ptrCast(@constCast("messages"));
}

// `LC_GLOBAL_LOCALE` is `(locale_t)-1` (langinfo.h / locale.h). It is the
// initial value of every thread's locale (i.e. the per-thread locale is
// not set and the process-wide global locale is used) and is also the
// value used by `uselocale` to mean "restore the global locale".
fn lcGlobalLocale() *anyopaque {
    return @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
}

threadlocal var thread_locale: ?*anyopaque = null;

fn uselocale(new_loc: ?*anyopaque) callconv(.c) ?*anyopaque {
    const global = lcGlobalLocale();
    const old: ?*anyopaque = thread_locale orelse global;
    if (new_loc) |loc| {
        thread_locale = if (loc == global) null else loc;
    }
    return old;
}

fn wcscoll(ws1: [*]const u32, ws2: [*]const u32) callconv(.c) c_int {
    return __wcscoll_l(ws1, ws2, null);
}

fn __wcscoll_l(ws1: [*]const u32, ws2: [*]const u32, _: ?*anyopaque) callconv(.c) c_int {
    var s1 = ws1;
    var s2 = ws2;
    while (s1[0] != 0 and s1[0] == s2[0]) {
        s1 += 1;
        s2 += 1;
    }
    const a: i64 = @intCast(s1[0]);
    const b: i64 = @intCast(s2[0]);
    const diff = a - b;
    return if (diff < 0) -1 else if (diff > 0) @as(c_int, 1) else 0;
}

fn wcsxfrm(dest: [*]u32, src: [*]const u32, n: usize) callconv(.c) usize {
    return __wcsxfrm_l(dest, src, n, null);
}

fn __wcsxfrm_l(dest: [*]u32, src: [*]const u32, n: usize, _: ?*anyopaque) callconv(.c) usize {
    var len: usize = 0;
    var s = src;
    while (s[0] != 0) {
        s += 1;
        len += 1;
    }
    if (len < n) {
        @memcpy(dest[0..len], src[0..len]);
        dest[len] = 0;
    }
    return len;
}

// Internal musl locale objects (stubs for C locale only)
export var __c_locale_obj: c_int = 0;
export var __c_dot_utf8_locale_obj: c_int = 0;

comptime {
    if (builtin.target.isMuslLibC()) {
        @export(&__c_locale_obj, .{ .name = "__c_locale" });
        @export(&__c_dot_utf8_locale_obj, .{ .name = "__c_dot_utf8_locale" });
    }
}