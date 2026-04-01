const builtin = @import("builtin");

const std = @import("std");
const math = std.math;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const expectApproxEqRel = std.testing.expectApproxEqRel;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMinGW()) {
        symbol(&isnan, "isnan");
        symbol(&isnan, "__isnan");
        symbol(&isnanf, "isnanf");
        symbol(&isnanf, "__isnanf");
        symbol(&isnanl, "isnanl");
        symbol(&isnanl, "__isnanl");

        symbol(&math.floatTrueMin(f64), "__DENORM");
        symbol(&math.inf(f64), "__INF");
        symbol(&math.nan(f64), "__QNAN");
        symbol(&math.snan(f64), "__SNAN");

        symbol(&math.floatTrueMin(f32), "__DENORMF");
        symbol(&math.inf(f32), "__INFF");
        symbol(&math.nan(f32), "__QNANF");
        symbol(&math.snan(f32), "__SNANF");

        symbol(&math.floatTrueMin(c_longdouble), "__DENORML");
        symbol(&math.inf(c_longdouble), "__INFL");
        symbol(&math.nan(c_longdouble), "__QNANL");
        symbol(&math.snan(c_longdouble), "__SNANL");
    }

    if (builtin.target.isMinGW() or builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&coshf, "coshf");
        symbol(&hypotf, "hypotf");
        symbol(&hypotl, "hypotl");
        symbol(&modff, "modff");
        symbol(&modfl, "modfl");
        symbol(&nan, "nan");
        symbol(&nanf, "nanf");
        symbol(&nanl, "nanl");
        symbol(&tanhf, "tanhf");
    }

    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&acos, "acos");
        symbol(&acosf, "acosf");
        symbol(&acoshf, "acoshf");
        symbol(&asin, "asin");
        symbol(&atan, "atan");
        symbol(&atanf, "atanf");
        symbol(&atanl, "atanl");
        symbol(&cbrt, "cbrt");
        symbol(&cbrtf, "cbrtf");
        symbol(&cosh, "cosh");
        symbol(&exp10, "exp10");
        symbol(&exp10f, "exp10f");
        symbol(&frexp_, "frexp");
        symbol(&frexpf_, "frexpf");
        symbol(&frexpl_, "frexpl");
        symbol(&hypot, "hypot");
        symbol(&ilogb_, "ilogb");
        symbol(&ilogbf_, "ilogbf");
        symbol(&ilogbl_, "ilogbl");
        symbol(&ldexp_, "ldexp");
        symbol(&ldexpf_, "ldexpf");
        symbol(&ldexpl_, "ldexpl");
        symbol(&logb_, "logb");
        symbol(&logbf_, "logbf");
        symbol(&logbl_, "logbl");
        symbol(&modf, "modf");
        symbol(&pow, "pow");
        symbol(&pow10, "pow10");
        symbol(&pow10f, "pow10f");
        symbol(&scalbln_, "scalbln");
        symbol(&scalblnf_, "scalblnf");
        symbol(&scalblnl_, "scalblnl");
        symbol(&scalbn_, "scalbn");
        symbol(&scalbnf_, "scalbnf");
        symbol(&scalbnl_, "scalbnl");
        symbol(&significand_, "significand");
        symbol(&significandf_, "significandf");
        symbol(&tanh, "tanh");
    }

    if (builtin.target.isMuslLibC()) {
        symbol(&copysign, "copysign");
        symbol(&copysignf, "copysignf");
        symbol(&rint, "rint");
    }

    symbol(&copysignl, "copysignl");
}

fn acos(x: f64) callconv(.c) f64 {
    return math.acos(x);
}

fn acosf(x: f32) callconv(.c) f32 {
    return math.acos(x);
}

fn acoshf(x: f32) callconv(.c) f32 {
    return math.acosh(x);
}

fn asin(x: f64) callconv(.c) f64 {
    return math.asin(x);
}

fn atan(x: f64) callconv(.c) f64 {
    return math.atan(x);
}

fn atanf(x: f32) callconv(.c) f32 {
    return math.atan(x);
}

fn atanl(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.atan(@as(f16, @floatCast(x))),
        32 => math.atan(@as(f32, @floatCast(x))),
        64 => math.atan(@as(f64, @floatCast(x))),
        80 => math.atan(@as(f80, @floatCast(x))),
        128 => math.atan(@as(f128, @floatCast(x))),
        else => unreachable,
    };
}

fn cbrt(x: f64) callconv(.c) f64 {
    return math.cbrt(x);
}

fn cbrtf(x: f32) callconv(.c) f32 {
    return math.cbrt(x);
}

fn copysign(x: f64, y: f64) callconv(.c) f64 {
    return math.copysign(x, y);
}

fn copysignf(x: f32, y: f32) callconv(.c) f32 {
    return math.copysign(x, y);
}

fn copysignl(x: c_longdouble, y: c_longdouble) callconv(.c) c_longdouble {
    return math.copysign(x, y);
}

fn cosh(x: f64) callconv(.c) f64 {
    return math.cosh(x);
}

fn coshf(x: f32) callconv(.c) f32 {
    return math.cosh(x);
}

fn exp10(x: f64) callconv(.c) f64 {
    return math.pow(f64, 10.0, x);
}

fn exp10f(x: f32) callconv(.c) f32 {
    return math.pow(f32, 10.0, x);
}

fn frexp_(x: f64, e: *c_int) callconv(.c) f64 {
    const r = math.frexp(x);
    e.* = r.exponent;
    return r.significand;
}

fn frexpf_(x: f32, e: *c_int) callconv(.c) f32 {
    const r = math.frexp(x);
    e.* = r.exponent;
    return r.significand;
}

fn frexpl_(x: c_longdouble, e: *c_int) callconv(.c) c_longdouble {
    const r = math.frexp(x);
    e.* = r.exponent;
    return r.significand;
}

test "frexp" {
    var e: c_int = undefined;
    try expectEqual(@as(f64, 0.75), frexp_(1.5, &e));
    try expectEqual(@as(c_int, 1), e);
    try expectEqual(@as(f64, 0.5), frexp_(1.0, &e));
    try expectEqual(@as(c_int, 1), e);
    try expectEqual(@as(f32, 0.75), frexpf_(1.5, &e));
    try expectEqual(@as(c_int, 1), e);
}

fn ilogb_(x: f64) callconv(.c) c_int {
    return math.ilogb(x);
}

fn ilogbf_(x: f32) callconv(.c) c_int {
    return math.ilogb(x);
}

fn ilogbl_(x: c_longdouble) callconv(.c) c_int {
    return math.ilogb(x);
}

test "ilogb" {
    try expectEqual(@as(c_int, 0), ilogb_(1.0));
    try expectEqual(@as(c_int, 3), ilogb_(10.0));
    try expectEqual(@as(c_int, 0), ilogbf_(1.0));
    try expectEqual(@as(c_int, 3), ilogbf_(10.0));
}

fn ldexp_(x: f64, n: c_int) callconv(.c) f64 {
    return math.ldexp(x, n);
}

fn ldexpf_(x: f32, n: c_int) callconv(.c) f32 {
    return math.ldexp(x, n);
}

fn ldexpl_(x: c_longdouble, n: c_int) callconv(.c) c_longdouble {
    return math.ldexp(x, n);
}

test "ldexp" {
    try expectEqual(@as(f64, 8.0), ldexp_(1.0, 3));
    try expectEqual(@as(f64, 0.5), ldexp_(1.0, -1));
    try expectEqual(@as(f32, 8.0), ldexpf_(1.0, 3));
}

fn logbGeneric(comptime T: type, x: T) T {
    if (math.isNan(x)) return x;
    if (math.isInf(x)) return math.inf(T);
    if (x == 0) {
        return -1.0 / @as(T, 0.0);
    }
    return @floatFromInt(math.ilogb(x));
}

fn logb_(x: f64) callconv(.c) f64 {
    return logbGeneric(f64, x);
}

fn logbf_(x: f32) callconv(.c) f32 {
    return logbGeneric(f32, x);
}

fn logbl_(x: c_longdouble) callconv(.c) c_longdouble {
    return logbGeneric(c_longdouble, x);
}

test "logb" {
    try expectEqual(@as(f64, 0.0), logb_(1.0));
    try expectEqual(@as(f64, 3.0), logb_(10.0));
    try expectEqual(math.inf(f64), logb_(math.inf(f64)));
    try expect(math.isNan(logb_(math.nan(f64))));
    try expectEqual(@as(f32, 0.0), logbf_(1.0));
    try expectEqual(@as(f32, 3.0), logbf_(10.0));
}

fn hypot(x: f64, y: f64) callconv(.c) f64 {
    return math.hypot(x, y);
}

fn hypotf(x: f32, y: f32) callconv(.c) f32 {
    return math.hypot(x, y);
}

fn hypotl(x: c_longdouble, y: c_longdouble) callconv(.c) c_longdouble {
    return math.hypot(x, y);
}

fn isnan(x: f64) callconv(.c) c_int {
    return if (math.isNan(x)) 1 else 0;
}

fn isnanf(x: f32) callconv(.c) c_int {
    return if (math.isNan(x)) 1 else 0;
}

fn isnanl(x: c_longdouble) callconv(.c) c_int {
    return if (math.isNan(x)) 1 else 0;
}

fn modfGeneric(comptime T: type, x: T, iptr: *T) T {
    if (math.isNegativeInf(x)) {
        iptr.* = -math.inf(T);
        return -0.0;
    }

    if (math.isPositiveInf(x)) {
        iptr.* = math.inf(T);
        return 0.0;
    }

    if (math.isNan(x)) {
        iptr.* = math.nan(T);
        return math.nan(T);
    }

    const r = math.modf(x);
    iptr.* = r.ipart;

    // If the result is a negative zero, we must be explicit about
    // returning a negative zero.
    return if (math.isNegativeZero(x) or (x < 0.0 and x == r.ipart)) -0.0 else r.fpart;
}

fn modf(x: f64, iptr: *f64) callconv(.c) f64 {
    return modfGeneric(f64, x, iptr);
}

fn modff(x: f32, iptr: *f32) callconv(.c) f32 {
    return modfGeneric(f32, x, iptr);
}

fn modfl(x: c_longdouble, iptr: *c_longdouble) callconv(.c) c_longdouble {
    return modfGeneric(c_longdouble, x, iptr);
}

fn testModf(comptime T: type) !void {
    // Choose the appropriate `modf` impl to test based on type
    const f = switch (T) {
        f32 => modff,
        f64 => modf,
        c_longdouble => modfl,
        else => @compileError("modf not implemented for " ++ @typeName(T)),
    };

    var int: T = undefined;
    const iptr = &int;
    const eps_val: comptime_float = @max(1e-6, math.floatEps(T));

    const normal_frac = f(@as(T, 1234.567), iptr);
    // Account for precision error
    const expected = 1234.567 - @as(T, 1234);
    try expectApproxEqAbs(expected, normal_frac, eps_val);
    try expectApproxEqRel(@as(T, 1234.0), iptr.*, eps_val);

    // When `x` is a NaN, NaN is returned and `*iptr` is set to NaN
    const nan_frac = f(math.nan(T), iptr);
    try expect(math.isNan(nan_frac));
    try expect(math.isNan(iptr.*));

    // When `x` is positive infinity, +0 is returned and `*iptr` is set to
    // positive infinity
    const pos_zero_frac = f(math.inf(T), iptr);
    try expect(math.isPositiveZero(pos_zero_frac));
    try expect(math.isPositiveInf(iptr.*));

    // When `x` is negative infinity, -0 is returned and `*iptr` is set to
    // negative infinity
    const neg_zero_frac = f(-math.inf(T), iptr);
    try expect(math.isNegativeZero(neg_zero_frac));
    try expect(math.isNegativeInf(iptr.*));

    // Return -0 when `x` is a negative integer
    const nz_frac = f(@as(T, -1000.0), iptr);
    try expect(math.isNegativeZero(nz_frac));
    try expectEqual(@as(T, -1000.0), iptr.*);

    // Return +0 when `x` is a positive integer
    const pz_frac = f(@as(T, 1000.0), iptr);
    try expect(math.isPositiveZero(pz_frac));
    try expectEqual(@as(T, 1000.0), iptr.*);
}

test "modf" {
    try testModf(f32);
    try testModf(f64);
    try testModf(c_longdouble);
}

fn nan(_: [*:0]const c_char) callconv(.c) f64 {
    return math.nan(f64);
}

fn nanf(_: [*:0]const c_char) callconv(.c) f32 {
    return math.nan(f32);
}

fn nanl(_: [*:0]const c_char) callconv(.c) c_longdouble {
    return math.nan(c_longdouble);
}

fn pow(x: f64, y: f64) callconv(.c) f64 {
    return math.pow(f64, x, y);
}

fn pow10(x: f64) callconv(.c) f64 {
    return exp10(x);
}

fn pow10f(x: f32) callconv(.c) f32 {
    return exp10f(x);
}

fn rint(x: f64) callconv(.c) f64 {
    const toint: f64 = 1.0 / @as(f64, math.floatEps(f64));
    const a: u64 = @bitCast(x);
    const e = a >> 52 & 0x7ff;
    const s = a >> 63;
    var y: f64 = undefined;

    if (e >= 0x3ff + 52) {
        return x;
    }
    if (s == 1) {
        y = x - toint + toint;
    } else {
        y = x + toint - toint;
    }
    if (y == 0) {
        return if (s == 1) -0.0 else 0;
    }
    return y;
}

test "rint" {
    // Positive numbers round correctly
    try expectEqual(@as(f64, 42.0), rint(42.2));
    try expectEqual(@as(f64, 42.0), rint(41.8));

    // Negative numbers round correctly
    try expectEqual(@as(f64, -6.0), rint(-5.9));
    try expectEqual(@as(f64, -6.0), rint(-6.1));

    // No rounding needed test
    try expectEqual(@as(f64, 5.0), rint(5.0));
    try expectEqual(@as(f64, -10.0), rint(-10.0));
    try expectEqual(@as(f64, 0.0), rint(0.0));

    // Very large numbers return unchanged
    const large: f64 = 9007199254740992.0; // 2^53
    try expectEqual(large, rint(large));
    try expectEqual(-large, rint(-large));

    // Small positive numbers round to zero
    const pos_result = rint(0.3);
    try expectEqual(@as(f64, 0.0), pos_result);
    try expect(@as(u64, @bitCast(pos_result)) == 0);

    // Small negative numbers round to negative zero
    const neg_result = rint(-0.3);
    try expectEqual(@as(f64, 0.0), neg_result);
    const bits: u64 = @bitCast(neg_result);
    try expect((bits >> 63) == 1);

    // Exact half rounds to nearest even (banker's rounding)
    try expectEqual(@as(f64, 2.0), rint(2.5));
    try expectEqual(@as(f64, 4.0), rint(3.5));
}

fn scalbln_(x: f64, n: c_long) callconv(.c) f64 {
    const ni: c_int = if (n > maxInt(c_int)) maxInt(c_int) else if (n < minInt(c_int)) minInt(c_int) else @intCast(n);
    return math.scalbn(x, ni);
}

fn scalblnf_(x: f32, n: c_long) callconv(.c) f32 {
    const ni: c_int = if (n > maxInt(c_int)) maxInt(c_int) else if (n < minInt(c_int)) minInt(c_int) else @intCast(n);
    return math.scalbn(x, ni);
}

fn scalblnl_(x: c_longdouble, n: c_long) callconv(.c) c_longdouble {
    const ni: c_int = if (n > maxInt(c_int)) maxInt(c_int) else if (n < minInt(c_int)) minInt(c_int) else @intCast(n);
    return math.scalbn(x, ni);
}

test "scalbln" {
    try expectEqual(@as(f64, 8.0), scalbln_(1.0, 3));
    try expectEqual(@as(f64, 0.5), scalbln_(1.0, -1));
    try expectEqual(@as(f32, 8.0), scalblnf_(1.0, 3));
}

fn scalbn_(x: f64, n: c_int) callconv(.c) f64 {
    return math.scalbn(x, n);
}

fn scalbnf_(x: f32, n: c_int) callconv(.c) f32 {
    return math.scalbn(x, n);
}

fn scalbnl_(x: c_longdouble, n: c_int) callconv(.c) c_longdouble {
    return math.scalbn(x, n);
}

test "scalbn" {
    try expectEqual(@as(f64, 8.0), scalbn_(1.0, 3));
    try expectEqual(@as(f64, 0.5), scalbn_(1.0, -1));
    try expectEqual(@as(f32, 8.0), scalbnf_(1.0, 3));
}

fn significand_(x: f64) callconv(.c) f64 {
    return math.scalbn(x, -math.ilogb(x));
}

fn significandf_(x: f32) callconv(.c) f32 {
    return math.scalbn(x, -math.ilogb(x));
}

test "significand" {
    try expectEqual(@as(f64, 1.5), significand_(3.0));
    try expectEqual(@as(f64, 1.25), significand_(10.0));
    try expectEqual(@as(f32, 1.5), significandf_(3.0));
}

fn tanh(x: f64) callconv(.c) f64 {
    return math.tanh(x);
}

fn tanhf(x: f32) callconv(.c) f32 {
    return math.tanh(x);
}
