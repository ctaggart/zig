const builtin = @import("builtin");
const std = @import("std");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        // Functions specific to musl and wasi-libc.
        symbol(&isalnum, "isalnum");
        symbol(&isalpha, "isalpha");
        symbol(&isblank, "isblank");
        symbol(&iscntrl, "iscntrl");
        symbol(&isdigit, "isdigit");
        symbol(&isgraph, "isgraph");
        symbol(&islower, "islower");
        symbol(&isprint, "isprint");
        symbol(&ispunct, "ispunct");
        symbol(&isspace, "isspace");
        symbol(&isupper, "isupper");
        symbol(&isxdigit, "isxdigit");
        symbol(&tolower, "tolower");
        symbol(&toupper, "toupper");

        symbol(&__isalnum_l, "__isalnum_l");
        symbol(&__isalpha_l, "__isalpha_l");
        symbol(&__isblank_l, "__isblank_l");
        symbol(&__iscntrl_l, "__iscntrl_l");
        symbol(&__isdigit_l, "__isdigit_l");
        symbol(&__isgraph_l, "__isgraph_l");
        symbol(&__islower_l, "__islower_l");
        symbol(&__isprint_l, "__isprint_l");
        symbol(&__ispunct_l, "__ispunct_l");
        symbol(&__isspace_l, "__isspace_l");
        symbol(&__isupper_l, "__isupper_l");
        symbol(&__isxdigit_l, "__isxdigit_l");
        symbol(&__tolower_l, "__tolower_l");
        symbol(&__toupper_l, "__toupper_l");

        symbol(&__isalnum_l, "isalnum_l");
        symbol(&__isalpha_l, "isalpha_l");
        symbol(&__isblank_l, "isblank_l");
        symbol(&__iscntrl_l, "iscntrl_l");
        symbol(&__isdigit_l, "isdigit_l");
        symbol(&__isgraph_l, "isgraph_l");
        symbol(&__islower_l, "islower_l");
        symbol(&__isprint_l, "isprint_l");
        symbol(&__ispunct_l, "ispunct_l");
        symbol(&__isspace_l, "isspace_l");
        symbol(&__isupper_l, "isupper_l");
        symbol(&__isxdigit_l, "isxdigit_l");
        symbol(&__tolower_l, "tolower_l");
        symbol(&__toupper_l, "toupper_l");

        symbol(&isascii, "isascii");
        symbol(&toascii, "toascii");

        symbol(&iswblank, "iswblank");
        symbol(&iswcntrl, "iswcntrl");
        symbol(&iswdigit, "iswdigit");
        symbol(&iswgraph, "iswgraph");
        symbol(&iswprint, "iswprint");
        symbol(&iswspace, "iswspace");
        symbol(&iswxdigit, "iswxdigit");

        symbol(&__iswblank_l, "__iswblank_l");
        symbol(&__iswcntrl_l, "__iswcntrl_l");
        symbol(&__iswdigit_l, "__iswdigit_l");
        symbol(&__iswgraph_l, "__iswgraph_l");
        symbol(&__iswprint_l, "__iswprint_l");
        symbol(&__iswspace_l, "__iswspace_l");
        symbol(&__iswxdigit_l, "__iswxdigit_l");

        symbol(&__iswblank_l, "iswblank_l");
        symbol(&__iswcntrl_l, "iswcntrl_l");
        symbol(&__iswdigit_l, "iswdigit_l");
        symbol(&__iswgraph_l, "iswgraph_l");
        symbol(&__iswprint_l, "iswprint_l");
        symbol(&__iswspace_l, "iswspace_l");
        symbol(&__iswxdigit_l, "iswxdigit_l");
    }
}

// NOTE: If the input is not representable as an unsigned char or is not EOF (which is a negative integer value) the behaviour is undefined.

fn isalnum(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isAlphanumeric(@truncate(@as(c_uint, @bitCast(c))))); // @truncate instead of @intCast as we have to handle EOF
}

fn __isalnum_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isalnum(c);
}

fn isalpha(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isAlphabetic(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __isalpha_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isalpha(c);
}

fn isblank(c: c_int) callconv(.c) c_int {
    return @intFromBool(c == ' ' or c == '\t');
}

fn __isblank_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isblank(c);
}

fn iscntrl(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isControl(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __iscntrl_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return iscntrl(c);
}

fn isdigit(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isDigit(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __isdigit_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isdigit(c);
}

fn isgraph(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isGraphical(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __isgraph_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isgraph(c);
}

fn islower(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isLower(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __islower_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return islower(c);
}

fn isprint(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isPrint(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __isprint_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isprint(c);
}

fn ispunct(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isPunctuation(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __ispunct_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return ispunct(c);
}

fn isspace(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isWhitespace(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __isspace_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isspace(c);
}

fn isupper(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isUpper(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __isupper_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isupper(c);
}

fn isxdigit(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isHex(@truncate(@as(c_uint, @bitCast(c)))));
}

fn __isxdigit_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return isxdigit(c);
}

fn tolower(c: c_int) callconv(.c) c_int {
    return std.ascii.toLower(@truncate(@as(c_uint, @bitCast(c))));
}

fn __tolower_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return tolower(c);
}

fn toupper(c: c_int) callconv(.c) c_int {
    return std.ascii.toUpper(@truncate(@as(c_uint, @bitCast(c))));
}

fn __toupper_l(c: c_int, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return toupper(c);
}

fn isascii(c: c_int) callconv(.c) c_int {
    return @intFromBool(std.ascii.isAscii(@truncate(@as(c_uint, @bitCast(c)))));
}

fn toascii(c: c_int) callconv(.c) c_int {
    return c & 0x7F;
}

const wint_t = std.c.wint_t;

fn iswblank(wc: wint_t) callconv(.c) c_int {
    return @intFromBool(wc == ' ' or wc == '\t');
}

fn __iswblank_l(wc: wint_t, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return iswblank(wc);
}

fn iswcntrl(wc: wint_t) callconv(.c) c_int {
    return @intFromBool((wc >= 0 and wc < 32) or
        (wc >= 0x7f and wc < 0xa0) or
        (wc >= 0x2028 and wc <= 0x2029) or
        (wc >= 0xfff9 and wc <= 0xfffb));
}

fn __iswcntrl_l(wc: wint_t, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return iswcntrl(wc);
}

fn iswdigit(wc: wint_t) callconv(.c) c_int {
    return @intFromBool(wc >= '0' and wc <= '9');
}

fn __iswdigit_l(wc: wint_t, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return iswdigit(wc);
}

fn iswgraph(wc: wint_t) callconv(.c) c_int {
    return @intFromBool(iswspace(wc) == 0 and iswprint(wc) != 0);
}

fn __iswgraph_l(wc: wint_t, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return iswgraph(wc);
}

/// Consider all legal codepoints as printable except for:
/// - C0 and C1 control characters
/// - U+2028 and U+2029 (line/para break)
/// - U+FFF9 through U+FFFB (interlinear annotation controls)
/// - Surrogates (U+D800-U+DFFF)
/// - Non-characters (last two codepoints of each plane)
/// - Beyond Unicode range (> U+10FFFF)
fn iswprint(wc: wint_t) callconv(.c) c_int {
    const w = std.math.cast(c_uint, wc) orelse return 0;
    if (w < 0xff) return @intFromBool(((w +% 1) & 0x7f) >= 0x21);
    if (w < 0x2028 or w -% 0x202a < 0xd800 - 0x202a or w -% 0xe000 < 0xfff9 - 0xe000)
        return 1;
    if (w -% 0xfffc > 0x10ffff - 0xfffc or (w & 0xfffe) == 0xfffe)
        return 0;
    return 1;
}

fn __iswprint_l(wc: wint_t, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return iswprint(wc);
}

fn iswspace(wc: wint_t) callconv(.c) c_int {
    if (wc == 0) return 0;
    return @intFromBool(switch (wc) {
        ' ', '\t', '\n', '\r', 11, 12, 0x0085,
        0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005,
        0x2006, 0x2008, 0x2009, 0x200a,
        0x2028, 0x2029, 0x205f, 0x3000,
        => true,
        else => false,
    });
}

fn __iswspace_l(wc: wint_t, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return iswspace(wc);
}

fn iswxdigit(wc: wint_t) callconv(.c) c_int {
    return @intFromBool((wc >= '0' and wc <= '9') or (wc >= 'A' and wc <= 'F') or (wc >= 'a' and wc <= 'f'));
}

fn __iswxdigit_l(wc: wint_t, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return iswxdigit(wc);
}

test iswblank {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(c_int, 1), iswblank(' '));
    try expectEqual(@as(c_int, 1), iswblank('\t'));
    try expectEqual(@as(c_int, 0), iswblank('\n'));
    try expectEqual(@as(c_int, 0), iswblank('a'));
    try expectEqual(@as(c_int, 0), iswblank(0));
}

test iswcntrl {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(c_int, 1), iswcntrl(0));
    try expectEqual(@as(c_int, 1), iswcntrl(0x1f));
    try expectEqual(@as(c_int, 1), iswcntrl(0x7f));
    try expectEqual(@as(c_int, 1), iswcntrl(0x9f));
    try expectEqual(@as(c_int, 1), iswcntrl(0x2028));
    try expectEqual(@as(c_int, 1), iswcntrl(0x2029));
    try expectEqual(@as(c_int, 1), iswcntrl(0xfff9));
    try expectEqual(@as(c_int, 1), iswcntrl(0xfffb));
    try expectEqual(@as(c_int, 0), iswcntrl(' '));
    try expectEqual(@as(c_int, 0), iswcntrl('A'));
    try expectEqual(@as(c_int, 0), iswcntrl(0xa0));
    try expectEqual(@as(c_int, 0), iswcntrl(0x2027));
}

test iswdigit {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(c_int, 1), iswdigit('0'));
    try expectEqual(@as(c_int, 1), iswdigit('9'));
    try expectEqual(@as(c_int, 0), iswdigit('a'));
    try expectEqual(@as(c_int, 0), iswdigit(0x0660));
}

test iswgraph {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(c_int, 1), iswgraph('A'));
    try expectEqual(@as(c_int, 1), iswgraph('!'));
    try expectEqual(@as(c_int, 0), iswgraph(' '));
    try expectEqual(@as(c_int, 0), iswgraph('\t'));
    try expectEqual(@as(c_int, 0), iswgraph(0));
}

test iswprint {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(c_int, 1), iswprint(' '));
    try expectEqual(@as(c_int, 1), iswprint('A'));
    try expectEqual(@as(c_int, 1), iswprint('~'));
    try expectEqual(@as(c_int, 1), iswprint(0xa0));
    try expectEqual(@as(c_int, 0), iswprint(0));
    try expectEqual(@as(c_int, 0), iswprint(0x7f));
    try expectEqual(@as(c_int, 0), iswprint(0x9f));
    try expectEqual(@as(c_int, 0), iswprint(0x2028));
    if (@bitSizeOf(wint_t) > 16) {
        try expectEqual(@as(c_int, 1), iswprint(0x10000));
        try expectEqual(@as(c_int, 0), iswprint(0xfffe));
        try expectEqual(@as(c_int, 0), iswprint(0xd800));
    }
}

test iswspace {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(c_int, 1), iswspace(' '));
    try expectEqual(@as(c_int, 1), iswspace('\t'));
    try expectEqual(@as(c_int, 1), iswspace('\n'));
    try expectEqual(@as(c_int, 1), iswspace(0x2000));
    try expectEqual(@as(c_int, 1), iswspace(0x3000));
    try expectEqual(@as(c_int, 0), iswspace(0));
    try expectEqual(@as(c_int, 0), iswspace('A'));
    try expectEqual(@as(c_int, 0), iswspace(0xa0));
}

test iswxdigit {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(c_int, 1), iswxdigit('0'));
    try expectEqual(@as(c_int, 1), iswxdigit('f'));
    try expectEqual(@as(c_int, 1), iswxdigit('F'));
    try expectEqual(@as(c_int, 0), iswxdigit('g'));
    try expectEqual(@as(c_int, 0), iswxdigit(' '));
}
