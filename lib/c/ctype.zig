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

        symbol(&__ctype_b_loc, "__ctype_b_loc");
        symbol(&__ctype_tolower_loc, "__ctype_tolower_loc");
        symbol(&__ctype_toupper_loc, "__ctype_toupper_loc");
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

// glibc-compatible character classification table.
// Indexed from -128..127 (ptable points to table[128]).
// Values are 16-bit flags stored in target byte order.
const native_endian = builtin.cpu.arch.endian();

fn bx(v: u16) u16 {
    return if (native_endian == .big) v else @byteSwap(v);
}

const ctype_b_table = [384]u16{
    // -128..-1: zeros
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // 0..31: control characters
    bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200),
    bx(0x200), bx(0x320), bx(0x220), bx(0x220), bx(0x220), bx(0x220), bx(0x200), bx(0x200),
    bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200),
    bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200), bx(0x200),
    // 32..63: space, punctuation, digits
    bx(0x160), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0),
    bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0),
    bx(0x8d8), bx(0x8d8), bx(0x8d8), bx(0x8d8), bx(0x8d8), bx(0x8d8), bx(0x8d8), bx(0x8d8),
    bx(0x8d8), bx(0x8d8), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0),
    // 64..95: @, uppercase, punctuation
    bx(0x4c0), bx(0x8d5), bx(0x8d5), bx(0x8d5), bx(0x8d5), bx(0x8d5), bx(0x8d5), bx(0x8c5),
    bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5),
    bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x8c5),
    bx(0x8c5), bx(0x8c5), bx(0x8c5), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0),
    // 96..127: `, lowercase, punctuation, DEL
    bx(0x4c0), bx(0x8d6), bx(0x8d6), bx(0x8d6), bx(0x8d6), bx(0x8d6), bx(0x8d6), bx(0x8c6),
    bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6),
    bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x8c6),
    bx(0x8c6), bx(0x8c6), bx(0x8c6), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x4c0), bx(0x200),
    // 128..255: zeros (high bytes)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const ctype_b_ptr: [*]const u16 = ctype_b_table[128..].ptr;

fn __ctype_b_loc() callconv(.c) *const [*]const u16 {
    return &ctype_b_ptr;
}

// glibc-compatible tolower mapping table. Identity for non-alpha, A-Z → a-z.
const ctype_tolower_table = [384]i32{
    // -128..-1: zeros
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // 0..127: identity with A-Z → a-z
    0,   1,   2,   3,   4,   5,   6,   7,   8,   9,   10,  11,  12,  13,  14,  15,
    16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,
    32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,
    48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  62,  63,
    64,  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    91,  92,  93,  94,  95,  96,
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    123, 124, 125, 126, 127,
    // 128..255: zeros
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const ctype_tolower_ptr: [*]const i32 = ctype_tolower_table[128..].ptr;

fn __ctype_tolower_loc() callconv(.c) *const [*]const i32 {
    return &ctype_tolower_ptr;
}

// glibc-compatible toupper mapping table. Identity for non-alpha, a-z → A-Z.
const ctype_toupper_table = [384]i32{
    // -128..-1: zeros
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // 0..127: identity with a-z → A-Z
    0,   1,   2,   3,   4,   5,   6,   7,   8,   9,   10,  11,  12,  13,  14,  15,
    16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,
    32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,
    48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  62,  63,
    64,  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    91,  92,  93,  94,  95,  96,
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    123, 124, 125, 126, 127,
    // 128..255: zeros
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const ctype_toupper_ptr: [*]const i32 = ctype_toupper_table[128..].ptr;

fn __ctype_toupper_loc() callconv(.c) *const [*]const i32 {
    return &ctype_toupper_ptr;
}
