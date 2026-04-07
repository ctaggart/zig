const builtin = @import("builtin");

const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const expectApproxEqRel = std.testing.expectApproxEqRel;

const symbol = @import("../c.zig").symbol;

// lgamma signgam global variable
export var __signgam: c_int = 0;

comptime {
    @export(&__signgam, .{ .name = "signgam", .linkage = .weak });
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
        symbol(&fdim, "fdim");
        symbol(&hypot, "hypot");
        symbol(&lgamma_, "lgamma");
        symbol(&lgammaf_, "lgammaf");
        symbol(&lgamma_r, "__lgamma_r");
        symbol(&lgamma_r, "lgamma_r");
        symbol(&lgammaf_r, "__lgammaf_r");
        symbol(&lgammaf_r, "lgammaf_r");
        symbol(&modf, "modf");
        symbol(&pow, "pow");
        symbol(&pow10, "pow10");
        symbol(&pow10f, "pow10f");
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

fn fdim(x: f64, y: f64) callconv(.c) f64 {
    if (math.isNan(x)) {
        return x;
    }
    if (math.isNan(y)) {
        return y;
    }
    if (x > y) {
        return x - y;
    }
    return 0;
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

// =========================================================================
// lgamma — logarithm of the absolute value of the Gamma function
// Ported from musl libc (origin: FreeBSD /usr/src/lib/msun/src/e_lgamma_r.c)
// =========================================================================

// lgamma_r f64 polynomial coefficients
const lg_pi: f64 = 3.14159265358979311600e+00; // 0x400921FB, 0x54442D18
const lg_a0: f64 = 7.72156649015328655494e-02; // 0x3FB3C467, 0xE37DB0C8
const lg_a1: f64 = 3.22467033424113591611e-01; // 0x3FD4A34C, 0xC4A60FAD
const lg_a2: f64 = 6.73523010531292681824e-02; // 0x3FB13E00, 0x1A5562A7
const lg_a3: f64 = 2.05808084325167332806e-02; // 0x3F951322, 0xAC92547B
const lg_a4: f64 = 7.38555086081402883957e-03; // 0x3F7E404F, 0xB68FEFE8
const lg_a5: f64 = 2.89051383673415629091e-03; // 0x3F67ADD8, 0xCCB7926B
const lg_a6: f64 = 1.19270763183362067845e-03; // 0x3F538A94, 0x116F3F5D
const lg_a7: f64 = 5.10069792153511336608e-04; // 0x3F40B6C6, 0x89B99C00
const lg_a8: f64 = 2.20862790713908385557e-04; // 0x3F2CF2EC, 0xED10E54D
const lg_a9: f64 = 1.08011567247583939954e-04; // 0x3F1C5088, 0x987DFB07
const lg_a10: f64 = 2.52144565451257326939e-05; // 0x3EFA7074, 0x428CFA52
const lg_a11: f64 = 4.48640949618915160150e-05; // 0x3F07858E, 0x90A45837
const lg_tc: f64 = 1.46163214496836224576e+00; // 0x3FF762D8, 0x6356BE3F
const lg_tf: f64 = -1.21486290535849611461e-01; // 0xBFBF19B9, 0xBCC38A42
const lg_tt: f64 = -3.63867699703950536541e-18; // 0xBC50C7CA, 0xA48A971F
const lg_t0: f64 = 4.83836122723810047042e-01; // 0x3FDEF72B, 0xC8EE38A2
const lg_t1: f64 = -1.47587722994593911752e-01; // 0xBFC2E427, 0x8DC6C509
const lg_t2: f64 = 6.46249402391333854778e-02; // 0x3FB08B42, 0x94D5419B
const lg_t3: f64 = -3.27885410759859649565e-02; // 0xBFA0C9A8, 0xDF35B713
const lg_t4: f64 = 1.79706750811820387126e-02; // 0x3F9266E7, 0x970AF9EC
const lg_t5: f64 = -1.03142241298341437450e-02; // 0xBF851F9F, 0xBA91EC6A
const lg_t6: f64 = 6.10053870246291332635e-03; // 0x3F78FCE0, 0xE370E344
const lg_t7: f64 = -3.68452016781138256760e-03; // 0xBF6E2EFF, 0xB3E914D7
const lg_t8: f64 = 2.25964780900612472250e-03; // 0x3F6282D3, 0x2E15C915
const lg_t9: f64 = -1.40346469989232843813e-03; // 0xBF56FE8E, 0xBF2D1AF1
const lg_t10: f64 = 8.81081882437654011382e-04; // 0x3F4CDF0C, 0xEF61A8E9
const lg_t11: f64 = -5.38595305356740546715e-04; // 0xBF41A610, 0x9C73E0EC
const lg_t12: f64 = 3.15632070903625950361e-04; // 0x3F34AF6D, 0x6C0EBBF7
const lg_t13: f64 = -3.12754168375120860518e-04; // 0xBF347F24, 0xECC38C38
const lg_t14: f64 = 3.35529192635519073543e-04; // 0x3F35FD3E, 0xE8C2D3F4
const lg_u0: f64 = -7.72156649015328655494e-02; // 0xBFB3C467, 0xE37DB0C8
const lg_u1: f64 = 6.32827064025093366517e-01; // 0x3FE4401E, 0x8B005DFF
const lg_u2: f64 = 1.45492250137234768737e+00; // 0x3FF7475C, 0xD119BD6F
const lg_u3: f64 = 9.77717527963372745603e-01; // 0x3FEF4976, 0x44EA8450
const lg_u4: f64 = 2.28963728064692451092e-01; // 0x3FCD4EAE, 0xF6010924
const lg_u5: f64 = 1.33810918536787660377e-02; // 0x3F8B678B, 0xBF2BAB09
const lg_v1: f64 = 2.45597793713041134822e+00; // 0x4003A5D7, 0xC2BD619C
const lg_v2: f64 = 2.12848976379893395361e+00; // 0x40010725, 0xA42B18F5
const lg_v3: f64 = 7.69285150456672783825e-01; // 0x3FE89DFB, 0xE45050AF
const lg_v4: f64 = 1.04222645593369134254e-01; // 0x3FBAAE55, 0xD6537C88
const lg_v5: f64 = 3.21709242282423911810e-03; // 0x3F6A5ABB, 0x57D0CF61
const lg_s0: f64 = -7.72156649015328655494e-02; // 0xBFB3C467, 0xE37DB0C8
const lg_s1: f64 = 2.14982415960608852501e-01; // 0x3FCB848B, 0x36E20878
const lg_s2: f64 = 3.25778796408930981787e-01; // 0x3FD4D98F, 0x4F139F59
const lg_s3: f64 = 1.46350472652464452805e-01; // 0x3FC2BB9C, 0xBEE5F2F7
const lg_s4: f64 = 2.66422703033638609560e-02; // 0x3F9B481C, 0x7E939961
const lg_s5: f64 = 1.84028451407337715652e-03; // 0x3F5E26B6, 0x7368F239
const lg_s6: f64 = 3.19475326584100867617e-05; // 0x3F00BFEC, 0xDD17E945
const lg_r1: f64 = 1.39200533467621045958e+00; // 0x3FF645A7, 0x62C4AB74
const lg_r2: f64 = 7.21935547567138069525e-01; // 0x3FE71A18, 0x93D3DCDC
const lg_r3: f64 = 1.71933865632803078993e-01; // 0x3FC601ED, 0xCCFBDF27
const lg_r4: f64 = 1.86459191715652901344e-02; // 0x3F9317EA, 0x742ED475
const lg_r5: f64 = 7.77942496381893596434e-04; // 0x3F497DDA, 0xCA41A95B
const lg_r6: f64 = 7.32668430744625636189e-06; // 0x3EDEBAF7, 0xA5B38140
const lg_w0: f64 = 4.18938533204672725052e-01; // 0x3FDACFE3, 0x90C97D69
const lg_w1: f64 = 8.33333333333329678849e-02; // 0x3FB55555, 0x5555553B
const lg_w2: f64 = -2.77777777728775536470e-03; // 0xBF66C16C, 0x16B02E5C
const lg_w3: f64 = 7.93650558643019558500e-04; // 0x3F4A019F, 0x98CF38B6
const lg_w4: f64 = -5.95187557450339963135e-04; // 0xBF4380CB, 0x8C0FE741
const lg_w5: f64 = 8.36339918996282139126e-04; // 0x3F4B67BA, 0x4CDAD5D1
const lg_w6: f64 = -1.63092934096575273989e-03; // 0xBF5AB89D, 0x0B9E43E4

/// sin(pi*x) assuming x > 2^-100, if sin(pi*x)==0 the sign is arbitrary
fn sin_pi64(x_: f64) f64 {
    var x = x_;
    x = 2.0 * (x * 0.5 - @floor(x * 0.5)); // x mod 2.0
    var n: usize = @intFromFloat(x * 4.0);
    n = (n + 1) / 2;
    x -= @as(f64, @floatFromInt(n)) * 0.5;
    x *= lg_pi;
    return switch (n) {
        0, 4 => @sin(x),
        1 => @cos(x),
        2 => @sin(-x),
        3 => -@cos(x),
        else => unreachable,
    };
}

fn lgamma_r(x_: f64, signgamp: *c_int) callconv(.c) f64 {
    const u: u64 = @bitCast(x_);
    const ix: u32 = @truncate(u >> 32);
    const ix_abs = ix & 0x7fffffff;
    const sign: bool = (u >> 63) != 0;

    var x = x_;
    var r: f64 = undefined;
    var nadj: f64 = undefined;

    // purge off +-inf, NaN, +-0, tiny and negative arguments
    signgamp.* = 1;
    if (ix_abs >= 0x7ff00000)
        return x * x;
    if (ix_abs < (0x3ff - 70) << 20) { // |x|<2**-70, return -log(|x|)
        if (sign) {
            x = -x;
            signgamp.* = -1;
        }
        return -@log(x);
    }
    if (sign) {
        x = -x;
        const t = sin_pi64(x);
        if (t == 0.0) // -integer
            return 1.0 / (x - x);
        if (t > 0.0)
            signgamp.* = -1;
        nadj = @log(lg_pi / (@abs(t) * x));
    }

    // purge off 1 and 2
    if ((ix_abs == 0x3ff00000 or ix_abs == 0x40000000) and @as(u32, @truncate(u)) == 0) {
        r = 0;
    } else if (ix_abs < 0x40000000) {
        // for x < 2.0
        var y: f64 = undefined;
        var i: u32 = undefined;
        if (ix_abs <= 0x3feccccc) { // lgamma(x) = lgamma(x+1)-log(x)
            r = -@log(x);
            if (ix_abs >= 0x3FE76944) {
                y = 1.0 - x;
                i = 0;
            } else if (ix_abs >= 0x3FCDA661) {
                y = x - (lg_tc - 1.0);
                i = 1;
            } else {
                y = x;
                i = 2;
            }
        } else {
            r = 0.0;
            if (ix_abs >= 0x3FFBB4C3) { // [1.7316,2]
                y = 2.0 - x;
                i = 0;
            } else if (ix_abs >= 0x3FF3B4C4) { // [1.23,1.73]
                y = x - lg_tc;
                i = 1;
            } else {
                y = x - 1.0;
                i = 2;
            }
        }
        switch (i) {
            0 => {
                const z = y * y;
                const p1 = lg_a0 + z * (lg_a2 + z * (lg_a4 + z * (lg_a6 + z * (lg_a8 + z * lg_a10))));
                const p2 = z * (lg_a1 + z * (lg_a3 + z * (lg_a5 + z * (lg_a7 + z * (lg_a9 + z * lg_a11)))));
                const p = y * p1 + p2;
                r += (p - 0.5 * y);
            },
            1 => {
                const z = y * y;
                const w = z * y;
                const p1 = lg_t0 + w * (lg_t3 + w * (lg_t6 + w * (lg_t9 + w * lg_t12)));
                const p2 = lg_t1 + w * (lg_t4 + w * (lg_t7 + w * (lg_t10 + w * lg_t13)));
                const p3 = lg_t2 + w * (lg_t5 + w * (lg_t8 + w * (lg_t11 + w * lg_t14)));
                const p = z * p1 - (lg_tt - w * (p2 + y * p3));
                r += lg_tf + p;
            },
            2 => {
                const p1 = y * (lg_u0 + y * (lg_u1 + y * (lg_u2 + y * (lg_u3 + y * (lg_u4 + y * lg_u5)))));
                const p2 = 1.0 + y * (lg_v1 + y * (lg_v2 + y * (lg_v3 + y * (lg_v4 + y * lg_v5))));
                r += -0.5 * y + p1 / p2;
            },
            else => unreachable,
        }
    } else if (ix_abs < 0x40200000) { // x < 8.0
        const i: usize = @intFromFloat(x);
        const y = x - @as(f64, @floatFromInt(i));
        const p = y * (lg_s0 + y * (lg_s1 + y * (lg_s2 + y * (lg_s3 + y * (lg_s4 + y * (lg_s5 + y * lg_s6))))));
        const q = 1.0 + y * (lg_r1 + y * (lg_r2 + y * (lg_r3 + y * (lg_r4 + y * (lg_r5 + y * lg_r6)))));
        r = 0.5 * y + p / q;
        // lgamma(1+s) = log(s) + lgamma(s)
        if (i >= 3) {
            var z: f64 = 1.0;
            var j: usize = i;
            while (j >= 3) : (j -= 1) {
                z *= y + @as(f64, @floatFromInt(j)) - 1.0;
            }
            r += @log(z);
        }
    } else if (ix_abs < 0x43900000) { // 8.0 <= x < 2**58
        const t = @log(x);
        const z = 1.0 / x;
        const y = z * z;
        const w = lg_w0 + z * (lg_w1 + y * (lg_w2 + y * (lg_w3 + y * (lg_w4 + y * (lg_w5 + y * lg_w6)))));
        r = (x - 0.5) * (t - 1.0) + w;
    } else {
        // 2**58 <= x <= inf
        r = x * (@log(x) - 1.0);
    }
    if (sign)
        r = nadj - r;
    return r;
}

fn lgamma_(x: f64) callconv(.c) f64 {
    return lgamma_r(x, &__signgam);
}

// =========================================================================
// lgammaf — float version
// Ported from musl libc (origin: FreeBSD /usr/src/lib/msun/src/e_lgammaf_r.c)
// =========================================================================

// lgammaf_r f32 polynomial coefficients
const lgf_pi: f32 = 3.1415927410e+00; // 0x40490fdb
const lgf_a0: f32 = 7.7215664089e-02; // 0x3d9e233f
const lgf_a1: f32 = 3.2246702909e-01; // 0x3ea51a66
const lgf_a2: f32 = 6.7352302372e-02; // 0x3d89f001
const lgf_a3: f32 = 2.0580807701e-02; // 0x3ca89915
const lgf_a4: f32 = 7.3855509982e-03; // 0x3bf2027e
const lgf_a5: f32 = 2.8905137442e-03; // 0x3b3d6ec6
const lgf_a6: f32 = 1.1927076848e-03; // 0x3a9c54a1
const lgf_a7: f32 = 5.1006977446e-04; // 0x3a05b634
const lgf_a8: f32 = 2.2086278477e-04; // 0x39679767
const lgf_a9: f32 = 1.0801156895e-04; // 0x38e28445
const lgf_a10: f32 = 2.5214456400e-05; // 0x37d383a2
const lgf_a11: f32 = 4.4864096708e-05; // 0x383c2c75
const lgf_tc: f32 = 1.4616321325e+00; // 0x3fbb16c3
const lgf_tf: f32 = -1.2148628384e-01; // 0xbdf8cdcd
const lgf_tt: f32 = 6.6971006518e-09; // 0x31e61c52
const lgf_t0: f32 = 4.8383611441e-01; // 0x3ef7b95e
const lgf_t1: f32 = -1.4758771658e-01; // 0xbe17213c
const lgf_t2: f32 = 6.4624942839e-02; // 0x3d845a15
const lgf_t3: f32 = -3.2788541168e-02; // 0xbd064d47
const lgf_t4: f32 = 1.7970675603e-02; // 0x3c93373d
const lgf_t5: f32 = -1.0314224288e-02; // 0xbc28fcfe
const lgf_t6: f32 = 6.1005386524e-03; // 0x3bc7e707
const lgf_t7: f32 = -3.6845202558e-03; // 0xbb7177fe
const lgf_t8: f32 = 2.2596477065e-03; // 0x3b141699
const lgf_t9: f32 = -1.4034647029e-03; // 0xbab7f476
const lgf_t10: f32 = 8.8108185446e-04; // 0x3a66f867
const lgf_t11: f32 = -5.3859531181e-04; // 0xba0d3085
const lgf_t12: f32 = 3.1563205994e-04; // 0x39a57b6b
const lgf_t13: f32 = -3.1275415677e-04; // 0xb9a3f927
const lgf_t14: f32 = 3.3552918467e-04; // 0x39afe9f7
const lgf_u0: f32 = -7.7215664089e-02; // 0xbd9e233f
const lgf_u1: f32 = 6.3282704353e-01; // 0x3f2200f4
const lgf_u2: f32 = 1.4549225569e+00; // 0x3fba3ae7
const lgf_u3: f32 = 9.7771751881e-01; // 0x3f7a4bb2
const lgf_u4: f32 = 2.2896373272e-01; // 0x3e6a7578
const lgf_u5: f32 = 1.3381091878e-02; // 0x3c5b3c5e
const lgf_v1: f32 = 2.4559779167e+00; // 0x401d2ebe
const lgf_v2: f32 = 2.1284897327e+00; // 0x4008392d
const lgf_v3: f32 = 7.6928514242e-01; // 0x3f44efdf
const lgf_v4: f32 = 1.0422264785e-01; // 0x3dd572af
const lgf_v5: f32 = 3.2170924824e-03; // 0x3b52d5db
const lgf_s0: f32 = -7.7215664089e-02; // 0xbd9e233f
const lgf_s1: f32 = 2.1498242021e-01; // 0x3e5c245a
const lgf_s2: f32 = 3.2577878237e-01; // 0x3ea6cc7a
const lgf_s3: f32 = 1.4635047317e-01; // 0x3e15dce6
const lgf_s4: f32 = 2.6642270386e-02; // 0x3cda40e4
const lgf_s5: f32 = 1.8402845599e-03; // 0x3af135b4
const lgf_s6: f32 = 3.1947532989e-05; // 0x3805ff67
const lgf_r1: f32 = 1.3920053244e+00; // 0x3fb22d3b
const lgf_r2: f32 = 7.2193557024e-01; // 0x3f38d0c5
const lgf_r3: f32 = 1.7193385959e-01; // 0x3e300f6e
const lgf_r4: f32 = 1.8645919859e-02; // 0x3c98bf54
const lgf_r5: f32 = 7.7794247773e-04; // 0x3a4beed6
const lgf_r6: f32 = 7.3266842264e-06; // 0x36f5d7bd
const lgf_w0: f32 = 4.1893854737e-01; // 0x3ed67f1d
const lgf_w1: f32 = 8.3333335817e-02; // 0x3daaaaab
const lgf_w2: f32 = -2.7777778450e-03; // 0xbb360b61
const lgf_w3: f32 = 7.9365057172e-04; // 0x3a500cfd
const lgf_w4: f32 = -5.9518753551e-04; // 0xba1c065c
const lgf_w5: f32 = 8.3633989561e-04; // 0x3a5b3dd2
const lgf_w6: f32 = -1.6309292987e-03; // 0xbad5c4e8

/// sin(pi*x) for float, assuming x > 2^-100
fn sin_pi32(x_: f64) f32 {
    var y: f64 = undefined;
    var x = x_;
    x = 2.0 * (x * 0.5 - @floor(x * 0.5)); // x mod 2.0
    var n: usize = @intFromFloat(x * 4.0);
    n = (n + 1) / 2;
    y = x - @as(f64, @floatFromInt(n)) * 0.5;
    y *= 3.14159265358979323846;
    const result: f64 = switch (n) {
        0, 4 => @sin(y),
        1 => @cos(y),
        2 => @sin(-y),
        3 => -@cos(y),
        else => unreachable,
    };
    return @floatCast(result);
}

fn lgammaf_r(x_: f32, signgamp: *c_int) callconv(.c) f32 {
    const u: u32 = @bitCast(x_);
    const ix: u32 = u & 0x7fffffff;
    const sign_bit: bool = (u >> 31) != 0;

    var x: f32 = x_;
    var r: f32 = undefined;
    var nadj: f32 = undefined;

    // purge off +-inf, NaN, +-0, tiny and negative arguments
    signgamp.* = 1;
    if (ix >= 0x7f800000)
        return x * x;
    if (ix < 0x35000000) { // |x| < 2**-21, return -log(|x|)
        if (sign_bit) {
            signgamp.* = -1;
            x = -x;
        }
        return -@log(x);
    }
    if (sign_bit) {
        x = -x;
        const t = sin_pi32(x);
        if (t == 0.0) // -integer
            return 1.0 / (x - x);
        if (t > 0.0)
            signgamp.* = -1;
        nadj = @log(lgf_pi / (@abs(t) * x));
    }

    // purge off 1 and 2
    if (ix == 0x3f800000 or ix == 0x40000000) {
        r = 0;
    } else if (ix < 0x40000000) {
        // for x < 2.0
        var y: f32 = undefined;
        var i: u32 = undefined;
        if (ix <= 0x3f666666) { // lgamma(x) = lgamma(x+1)-log(x)
            r = -@log(x);
            if (ix >= 0x3f3b4a20) {
                y = 1.0 - x;
                i = 0;
            } else if (ix >= 0x3e6d3308) {
                y = x - (lgf_tc - 1.0);
                i = 1;
            } else {
                y = x;
                i = 2;
            }
        } else {
            r = 0.0;
            if (ix >= 0x3fdda618) { // [1.7316,2]
                y = 2.0 - x;
                i = 0;
            } else if (ix >= 0x3F9da620) { // [1.23,1.73]
                y = x - lgf_tc;
                i = 1;
            } else {
                y = x - 1.0;
                i = 2;
            }
        }
        switch (i) {
            0 => {
                const z = y * y;
                const p1 = lgf_a0 + z * (lgf_a2 + z * (lgf_a4 + z * (lgf_a6 + z * (lgf_a8 + z * lgf_a10))));
                const p2 = z * (lgf_a1 + z * (lgf_a3 + z * (lgf_a5 + z * (lgf_a7 + z * (lgf_a9 + z * lgf_a11)))));
                const p = y * p1 + p2;
                r += p - 0.5 * y;
            },
            1 => {
                const z = y * y;
                const w = z * y;
                const p1 = lgf_t0 + w * (lgf_t3 + w * (lgf_t6 + w * (lgf_t9 + w * lgf_t12)));
                const p2 = lgf_t1 + w * (lgf_t4 + w * (lgf_t7 + w * (lgf_t10 + w * lgf_t13)));
                const p3 = lgf_t2 + w * (lgf_t5 + w * (lgf_t8 + w * (lgf_t11 + w * lgf_t14)));
                const p = z * p1 - (lgf_tt - w * (p2 + y * p3));
                r += (lgf_tf + p);
            },
            2 => {
                const p1 = y * (lgf_u0 + y * (lgf_u1 + y * (lgf_u2 + y * (lgf_u3 + y * (lgf_u4 + y * lgf_u5)))));
                const p2 = 1.0 + y * (lgf_v1 + y * (lgf_v2 + y * (lgf_v3 + y * (lgf_v4 + y * lgf_v5))));
                r += -0.5 * y + p1 / p2;
            },
            else => unreachable,
        }
    } else if (ix < 0x41000000) { // x < 8.0
        const i: usize = @intFromFloat(x);
        const y = x - @as(f32, @floatFromInt(i));
        const p = y * (lgf_s0 + y * (lgf_s1 + y * (lgf_s2 + y * (lgf_s3 + y * (lgf_s4 + y * (lgf_s5 + y * lgf_s6))))));
        const q = 1.0 + y * (lgf_r1 + y * (lgf_r2 + y * (lgf_r3 + y * (lgf_r4 + y * (lgf_r5 + y * lgf_r6)))));
        r = 0.5 * y + p / q;
        // lgamma(1+s) = log(s) + lgamma(s)
        if (i >= 3) {
            var z: f32 = 1.0;
            var j: usize = i;
            while (j >= 3) : (j -= 1) {
                z *= y + @as(f32, @floatFromInt(j)) - 1.0;
            }
            r += @log(z);
        }
    } else if (ix < 0x5c800000) { // 8.0 <= x < 2**58
        const t = @log(x);
        const z: f32 = 1.0 / x;
        const y = z * z;
        const w = lgf_w0 + z * (lgf_w1 + y * (lgf_w2 + y * (lgf_w3 + y * (lgf_w4 + y * (lgf_w5 + y * lgf_w6)))));
        r = (x - 0.5) * (t - 1.0) + w;
    } else {
        // 2**58 <= x <= inf
        r = x * (@log(x) - 1.0);
    }
    if (sign_bit)
        r = nadj - r;
    return r;
}

fn lgammaf_(x: f32) callconv(.c) f32 {
    return lgammaf_r(x, &__signgam);
}

fn tanh(x: f64) callconv(.c) f64 {
    return math.tanh(x);
}

fn tanhf(x: f32) callconv(.c) f32 {
    return math.tanh(x);
}
