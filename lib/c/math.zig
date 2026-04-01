const builtin = @import("builtin");

const std = @import("std");
const math = std.math;
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
        symbol(&acosh_, "acosh");
        symbol(&acoshf, "acoshf");
        symbol(&acoshl_, "acoshl");
        symbol(&acosl_, "acosl");
        symbol(&asin, "asin");
        symbol(&asinf_, "asinf");
        symbol(&asinh_, "asinh");
        symbol(&asinhf_, "asinhf");
        symbol(&asinhl_, "asinhl");
        symbol(&asinl_, "asinl");
        symbol(&atan, "atan");
        symbol(&atan2_, "atan2");
        symbol(&atan2f_, "atan2f");
        symbol(&atan2l_, "atan2l");
        symbol(&atanf, "atanf");
        symbol(&atanh_, "atanh");
        symbol(&atanhf_, "atanhf");
        symbol(&atanhl_, "atanhl");
        symbol(&atanl, "atanl");
        symbol(&cbrt, "cbrt");
        symbol(&cbrtf, "cbrtf");
        symbol(&cosh, "cosh");
        symbol(&coshl_, "coshl");
        symbol(&exp10, "exp10");
        symbol(&exp10f, "exp10f");
        symbol(&expm1_, "expm1");
        symbol(&expm1f_, "expm1f");
        symbol(&expm1l_, "expm1l");
        symbol(&hypot, "hypot");
        symbol(&log1p_, "log1p");
        symbol(&log1pf_, "log1pf");
        symbol(&log1pl_, "log1pl");
        symbol(&modf, "modf");
        symbol(&pow, "pow");
        symbol(&pow10, "pow10");
        symbol(&pow10f, "pow10f");
        symbol(&sinh_, "sinh");
        symbol(&sinhf_, "sinhf");
        symbol(&sinhl_, "sinhl");
        symbol(&tanh, "tanh");
        symbol(&tanhl_, "tanhl");
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

fn acosh_(x: f64) callconv(.c) f64 {
    return math.acosh(x);
}

fn acoshf(x: f32) callconv(.c) f32 {
    return math.acosh(x);
}

fn acoshl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.acosh(@as(f16, @floatCast(x))),
        32 => math.acosh(@as(f32, @floatCast(x))),
        64 => math.acosh(@as(f64, @floatCast(x))),
        80 => math.acosh(@as(f80, @floatCast(x))),
        128 => math.acosh(@as(f128, @floatCast(x))),
        else => unreachable,
    };
}

fn acosl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.acos(@as(f16, @floatCast(x))),
        32 => math.acos(@as(f32, @floatCast(x))),
        64 => math.acos(@as(f64, @floatCast(x))),
        80 => math.acos(@as(f80, @floatCast(x))),
        128 => math.acos(@as(f128, @floatCast(x))),
        else => unreachable,
    };
}

fn asin(x: f64) callconv(.c) f64 {
    return math.asin(x);
}

fn asinf_(x: f32) callconv(.c) f32 {
    return math.asin(x);
}

fn asinh_(x: f64) callconv(.c) f64 {
    return math.asinh(x);
}

fn asinhf_(x: f32) callconv(.c) f32 {
    return math.asinh(x);
}

fn asinhl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.asinh(@as(f16, @floatCast(x))),
        32 => math.asinh(@as(f32, @floatCast(x))),
        64 => math.asinh(@as(f64, @floatCast(x))),
        80 => math.asinh(@as(f80, @floatCast(x))),
        128 => math.asinh(@as(f128, @floatCast(x))),
        else => unreachable,
    };
}

fn asinl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.asin(@as(f16, @floatCast(x))),
        32 => math.asin(@as(f32, @floatCast(x))),
        64 => math.asin(@as(f64, @floatCast(x))),
        80 => math.asin(@as(f80, @floatCast(x))),
        128 => math.asin(@as(f128, @floatCast(x))),
        else => unreachable,
    };
}

fn atan(x: f64) callconv(.c) f64 {
    return math.atan(x);
}

fn atan2_(x: f64, y: f64) callconv(.c) f64 {
    return math.atan2(x, y);
}

fn atan2f_(x: f32, y: f32) callconv(.c) f32 {
    return math.atan2(x, y);
}

fn atan2l_(x: c_longdouble, y: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.atan2(@as(f16, @floatCast(x)), @as(f16, @floatCast(y))),
        32 => math.atan2(@as(f32, @floatCast(x)), @as(f32, @floatCast(y))),
        64 => math.atan2(@as(f64, @floatCast(x)), @as(f64, @floatCast(y))),
        80 => math.atan2(@as(f80, @floatCast(x)), @as(f80, @floatCast(y))),
        128 => math.atan2(@as(f128, @floatCast(x)), @as(f128, @floatCast(y))),
        else => unreachable,
    };
}

fn atanf(x: f32) callconv(.c) f32 {
    return math.atan(x);
}

fn atanh_(x: f64) callconv(.c) f64 {
    return math.atanh(x);
}

fn atanhf_(x: f32) callconv(.c) f32 {
    return math.atanh(x);
}

fn atanhl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.atanh(@as(f16, @floatCast(x))),
        32 => math.atanh(@as(f32, @floatCast(x))),
        64 => math.atanh(@as(f64, @floatCast(x))),
        80 => math.atanh(@as(f80, @floatCast(x))),
        128 => math.atanh(@as(f128, @floatCast(x))),
        else => unreachable,
    };
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

fn coshl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.cosh(@as(f16, @floatCast(x))),
        32 => math.cosh(@as(f32, @floatCast(x))),
        64 => math.cosh(@as(f64, @floatCast(x))),
        80 => math.cosh(@as(f80, @floatCast(x))),
        128 => math.cosh(@as(f128, @floatCast(x))),
        else => unreachable,
    };
}

fn exp10(x: f64) callconv(.c) f64 {
    return math.pow(f64, 10.0, x);
}

fn exp10f(x: f32) callconv(.c) f32 {
    return math.pow(f32, 10.0, x);
}

fn expm1_(x: f64) callconv(.c) f64 {
    return math.expm1(x);
}

fn expm1f_(x: f32) callconv(.c) f32 {
    return math.expm1(x);
}

fn expm1l_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.expm1(@as(f16, @floatCast(x))),
        32 => math.expm1(@as(f32, @floatCast(x))),
        64 => math.expm1(@as(f64, @floatCast(x))),
        80 => math.expm1(@as(f80, @floatCast(x))),
        128 => math.expm1(@as(f128, @floatCast(x))),
        else => unreachable,
    };
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

fn log1p_(x: f64) callconv(.c) f64 {
    return math.log1p(x);
}

fn log1pf_(x: f32) callconv(.c) f32 {
    return math.log1p(x);
}

fn log1pl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.log1p(@as(f16, @floatCast(x))),
        32 => math.log1p(@as(f32, @floatCast(x))),
        64 => math.log1p(@as(f64, @floatCast(x))),
        80 => math.log1p(@as(f80, @floatCast(x))),
        128 => math.log1p(@as(f128, @floatCast(x))),
        else => unreachable,
    };
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

fn sinh_(x: f64) callconv(.c) f64 {
    return math.sinh(x);
}

fn sinhf_(x: f32) callconv(.c) f32 {
    return math.sinh(x);
}

fn sinhl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.sinh(@as(f16, @floatCast(x))),
        32 => math.sinh(@as(f32, @floatCast(x))),
        64 => math.sinh(@as(f64, @floatCast(x))),
        80 => math.sinh(@as(f80, @floatCast(x))),
        128 => math.sinh(@as(f128, @floatCast(x))),
        else => unreachable,
    };
}

fn tanh(x: f64) callconv(.c) f64 {
    return math.tanh(x);
}

fn tanhf(x: f32) callconv(.c) f32 {
    return math.tanh(x);
}

fn tanhl_(x: c_longdouble) callconv(.c) c_longdouble {
    return switch (@typeInfo(@TypeOf(x)).float.bits) {
        16 => math.tanh(@as(f16, @floatCast(x))),
        32 => math.tanh(@as(f32, @floatCast(x))),
        64 => math.tanh(@as(f64, @floatCast(x))),
        80 => math.tanh(@as(f80, @floatCast(x))),
        128 => math.tanh(@as(f128, @floatCast(x))),
        else => unreachable,
    };
}
