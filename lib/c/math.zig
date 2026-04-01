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
        symbol(&hypot, "hypot");
        symbol(&modf, "modf");
        symbol(&pow, "pow");
        symbol(&pow10, "pow10");
        symbol(&pow10f, "pow10f");
        symbol(&remainder_, "remainder");
        symbol(&remainder_, "drem");
        symbol(&remainderf_, "remainderf");
        symbol(&remainderf_, "dremf");
        symbol(&remainderl_, "remainderl");
        symbol(&remquo_, "remquo");
        symbol(&remquof_, "remquof");
        symbol(&remquol_, "remquol");
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

fn remainder_(x: f64, y: f64) callconv(.c) f64 {
    var q: c_int = undefined;
    return remquo_(x, y, &q);
}

fn remainderf_(x: f32, y: f32) callconv(.c) f32 {
    var q: c_int = undefined;
    return remquof_(x, y, &q);
}

fn remainderl_(x: c_longdouble, y: c_longdouble) callconv(.c) c_longdouble {
    var q: c_int = undefined;
    return remquol_(x, y, &q);
}

/// Translated from musl/src/math/remquof.c
fn remquof_(x_: f32, y_: f32, quo: *c_int) callconv(.c) f32 {
    var x: f32 = x_;
    var y: f32 = y_;
    var uxi: u32 = @bitCast(x);
    var uyi: u32 = @bitCast(y);
    var ex: i32 = @intCast(uxi >> 23 & 0xff);
    var ey: i32 = @intCast(uyi >> 23 & 0xff);
    const sx: u32 = uxi >> 31;
    const sy: u32 = uyi >> 31;
    var q: u32 = undefined;

    quo.* = 0;
    if (uyi << 1 == 0 or math.isNan(y) or ex == 0xff)
        return (x * y) / (x * y);
    if (uxi << 1 == 0)
        return x;

    // normalize x and y
    if (ex == 0) {
        var i = uxi << 9;
        while (i >> 31 == 0) : (i <<= 1) {
            ex -= 1;
        }
        uxi <<= @intCast(@as(u32, @bitCast(-ex + 1)));
    } else {
        uxi &= 0x007fffff;
        uxi |= 0x00800000;
    }
    if (ey == 0) {
        var i = uyi << 9;
        while (i >> 31 == 0) : (i <<= 1) {
            ey -= 1;
        }
        uyi <<= @intCast(@as(u32, @bitCast(-ey + 1)));
    } else {
        uyi &= 0x007fffff;
        uyi |= 0x00800000;
    }

    q = 0;
    if (ex >= ey) {
        // x mod y
        while (ex > ey) : (ex -= 1) {
            const i = uxi -% uyi;
            if (i >> 31 == 0) {
                uxi = i;
                q +%= 1;
            }
            uxi <<= 1;
            q = q *% 2;
        }
        {
            const i = uxi -% uyi;
            if (i >> 31 == 0) {
                uxi = i;
                q +%= 1;
            }
        }
        if (uxi == 0) {
            ex = -30;
        } else {
            while (uxi >> 23 == 0) {
                uxi <<= 1;
                ex -= 1;
            }
        }
    } else if (ex + 1 != ey) {
        return x;
    }

    // scale result and decide between |x| and |x|-|y|
    if (ex > 0) {
        uxi -= 1 << 23;
        uxi |= @as(u32, @intCast(ex)) << 23;
    } else {
        uxi >>= @intCast(@as(u32, @bitCast(-ex + 1)));
    }
    x = @bitCast(uxi);
    if (sy != 0) y = -y;
    if (ex == ey or (ex + 1 == ey and (2.0 * x > y or (2.0 * x == y and q % 2 != 0)))) {
        x -= y;
        q +%= 1;
    }
    q &= 0x7fffffff;
    const qi: c_int = @intCast(q);
    quo.* = if (sx ^ sy != 0) -qi else qi;
    return if (sx != 0) -x else x;
}

/// Translated from musl/src/math/remquo.c
fn remquo_(x_: f64, y_: f64, quo: *c_int) callconv(.c) f64 {
    var x: f64 = x_;
    var y: f64 = y_;
    var uxi: u64 = @bitCast(x);
    var uyi: u64 = @bitCast(y);
    var ex: i32 = @intCast(uxi >> 52 & 0x7ff);
    var ey: i32 = @intCast(uyi >> 52 & 0x7ff);
    const sx: u64 = uxi >> 63;
    const sy: u64 = uyi >> 63;
    var q: u32 = undefined;

    quo.* = 0;
    if (uyi << 1 == 0 or math.isNan(y) or ex == 0x7ff)
        return (x * y) / (x * y);
    if (uxi << 1 == 0)
        return x;

    // normalize x and y
    if (ex == 0) {
        var i = uxi << 12;
        while (i >> 63 == 0) : (i <<= 1) {
            ex -= 1;
        }
        uxi <<= @intCast(@as(u32, @bitCast(-ex + 1)));
    } else {
        uxi &= 0x000fffffffffffff;
        uxi |= 0x0010000000000000;
    }
    if (ey == 0) {
        var i = uyi << 12;
        while (i >> 63 == 0) : (i <<= 1) {
            ey -= 1;
        }
        uyi <<= @intCast(@as(u32, @bitCast(-ey + 1)));
    } else {
        uyi &= 0x000fffffffffffff;
        uyi |= 0x0010000000000000;
    }

    q = 0;
    if (ex >= ey) {
        // x mod y
        while (ex > ey) : (ex -= 1) {
            const i = uxi -% uyi;
            if (i >> 63 == 0) {
                uxi = i;
                q +%= 1;
            }
            uxi <<= 1;
            q = q *% 2;
        }
        {
            const i = uxi -% uyi;
            if (i >> 63 == 0) {
                uxi = i;
                q +%= 1;
            }
        }
        if (uxi == 0) {
            ex = -60;
        } else {
            while (uxi >> 52 == 0) {
                uxi <<= 1;
                ex -= 1;
            }
        }
    } else if (ex + 1 != ey) {
        return x;
    }

    // scale result and decide between |x| and |x|-|y|
    if (ex > 0) {
        uxi -= @as(u64, 1) << 52;
        uxi |= @as(u64, @intCast(ex)) << 52;
    } else {
        uxi >>= @intCast(@as(u32, @bitCast(-ex + 1)));
    }
    x = @bitCast(uxi);
    if (sy != 0) y = -y;
    if (ex == ey or (ex + 1 == ey and (2.0 * x > y or (2.0 * x == y and q % 2 != 0)))) {
        x -= y;
        q +%= 1;
    }
    q &= 0x7fffffff;
    const qi: c_int = @intCast(q);
    quo.* = if (sx ^ sy != 0) -qi else qi;
    return if (sx != 0) -x else x;
}

/// Translated from musl/src/math/remquol.c
fn remquol_(x_: c_longdouble, y_: c_longdouble, quo: *c_int) callconv(.c) c_longdouble {
    const ld = @typeInfo(c_longdouble).float;
    if (ld.bits == 64) {
        return @floatCast(remquo_(@as(f64, @floatCast(x_)), @as(f64, @floatCast(y_)), quo));
    }
    if (ld.bits == 80) {
        return remquox(f80, x_, y_, quo);
    }
    if (ld.bits == 128) {
        return remquox(f128, x_, y_, quo);
    }
    unreachable;
}

fn remquox(comptime F: type, x_: c_longdouble, y_: c_longdouble, quo: *c_int) c_longdouble {
    const bits = @typeInfo(F).float.bits;
    const Bits = std.meta.Int(.unsigned, bits);
    const se_shift: comptime_int = bits - 16;
    const se_mask: Bits = @as(Bits, 0xFFFF) << se_shift;

    var x: F = @floatCast(x_);
    var y: F = @floatCast(y_);
    var ux: Bits = @bitCast(x);
    var uy: Bits = @bitCast(y);
    var ux_se: u16 = @truncate(ux >> se_shift);
    const uy_se: u16 = @truncate(uy >> se_shift);
    var ex: i32 = @intCast(ux_se & 0x7fff);
    var ey: i32 = @intCast(uy_se & 0x7fff);
    const sx: u16 = ux_se >> 15;
    const sy: u16 = uy_se >> 15;
    var q: u32 = 0;

    quo.* = 0;
    if (y == 0 or math.isNan(y) or ex == 0x7fff)
        return @floatCast((x * y) / (x * y));
    if (x == 0)
        return @floatCast(x);

    // normalize x
    if (ex == 0) {
        ux = ux & ~se_mask;
        x = @bitCast(ux);
        x *= 0x1p120;
        ux = @bitCast(x);
        ux_se = @truncate(ux >> se_shift);
        ex = @as(i32, @intCast(ux_se & 0x7fff)) - 120;
    }
    // normalize y
    if (ey == 0) {
        uy = uy & ~se_mask;
        y = @bitCast(uy);
        y *= 0x1p120;
        uy = @bitCast(y);
        ey = @as(i32, @intCast(@as(u16, @truncate(uy >> se_shift)) & 0x7fff)) - 120;
    }

    q = 0;
    if (ex >= ey) {
        if (bits == 80) {
            // f80: 64-bit mantissa in bits[63:0]
            var mx: u64 = @truncate(ux);
            const my: u64 = @truncate(uy);
            while (ex > ey) : (ex -= 1) {
                if (mx >= my) {
                    mx = (mx - my) *% 2;
                    q +%= 1;
                    q = q *% 2;
                } else if (mx *% 2 < mx) {
                    mx = mx *% 2 -% my;
                    q = q *% 2;
                    q +%= 1;
                } else {
                    mx = mx * 2;
                    q = q *% 2;
                }
            }
            if (mx >= my) {
                mx = mx - my;
                q +%= 1;
            }
            if (mx == 0) {
                ex = -120;
            } else {
                while (mx >> 63 == 0) {
                    mx *%= 2;
                    ex -= 1;
                }
            }
            ux = (ux & se_mask) | @as(Bits, mx);
        } else {
            // f128: mantissa split into hi (48 bits) and lo (64 bits)
            var xhi: u64 = (@as(u64, @truncate(ux >> 64)) & (std.math.maxInt(u64) >> 16)) | (@as(u64, 1) << 48);
            const yhi: u64 = (@as(u64, @truncate(uy >> 64)) & (std.math.maxInt(u64) >> 16)) | (@as(u64, 1) << 48);
            var xlo: u64 = @truncate(ux);
            const ylo: u64 = @truncate(uy);
            while (ex > ey) : (ex -= 1) {
                var hi = xhi -% yhi;
                const lo = xlo -% ylo;
                if (xlo < ylo)
                    hi -%= 1;
                if (hi >> 63 == 0) {
                    xhi = hi *% 2 +% (lo >> 63);
                    xlo = lo *% 2;
                    q +%= 1;
                } else {
                    xhi = xhi *% 2 +% (xlo >> 63);
                    xlo = xlo *% 2;
                }
                q = q *% 2;
            }
            {
                var hi = xhi -% yhi;
                const lo = xlo -% ylo;
                if (xlo < ylo)
                    hi -%= 1;
                if (hi >> 63 == 0) {
                    xhi = hi;
                    xlo = lo;
                    q +%= 1;
                }
            }
            if ((xhi | xlo) == 0) {
                ex = -120;
            } else {
                while (xhi >> 48 == 0) {
                    xhi = xhi *% 2 +% (xlo >> 63);
                    xlo = xlo *% 2;
                    ex -= 1;
                }
            }
            ux = (@as(Bits, xhi) << 64) | @as(Bits, xlo);
        }
    }

    // scale result and decide between |x| and |x|-|y|
    if (ex <= 0) {
        ux_se = @intCast(@as(u32, @bitCast(ex + 120)));
        ux = (ux & ~se_mask) | (@as(Bits, ux_se) << se_shift);
        x = @bitCast(ux);
        x *= 0x1p-120;
    } else {
        ux_se = @intCast(@as(u32, @bitCast(ex)));
        ux = (ux & ~se_mask) | (@as(Bits, ux_se) << se_shift);
        x = @bitCast(ux);
    }
    if (sy != 0) y = -y;
    if (ex == ey or (ex + 1 == ey and (2.0 * x > y or (2.0 * x == y and q % 2 != 0)))) {
        x -= y;
        q +%= 1;
    }
    q &= 0x7fffffff;
    const qi: c_int = @intCast(q);
    quo.* = if (sx ^ sy != 0) -qi else qi;
    return @floatCast(if (sx != 0) -x else x);
}

test "remquof" {
    var q: c_int = undefined;

    // basic: 10 mod 3 = 1, quotient 3
    try expectEqual(@as(f32, 1.0), remquof_(10.0, 3.0, &q));
    try expectEqual(@as(c_int, 3), q & 0x7);

    // negative x: -10 mod 3 = -1, quotient -3
    try expectEqual(@as(f32, -1.0), remquof_(-10.0, 3.0, &q));
    try expectEqual(@as(c_int, -3), q);

    // remainder rounds to nearest: remquo(5.5, 2) -> -0.5 quotient 3
    try expectEqual(@as(f32, -0.5), remquof_(5.5, 2.0, &q));
    try expectEqual(@as(c_int, 3), q);

    // y == 0 -> NaN
    try expect(math.isNan(remquof_(1.0, 0.0, &q)));

    // x == NaN -> NaN
    try expect(math.isNan(remquof_(math.nan(f32), 1.0, &q)));

    // x == inf -> NaN
    try expect(math.isNan(remquof_(math.inf(f32), 1.0, &q)));

    // x == 0 -> 0
    try expectEqual(@as(f32, 0.0), remquof_(0.0, 1.0, &q));
    try expectEqual(@as(c_int, 0), q);
}

test "remquo" {
    var q: c_int = undefined;

    try expectEqual(@as(f64, 1.0), remquo_(10.0, 3.0, &q));
    try expectEqual(@as(c_int, 3), q & 0x7);

    try expectEqual(@as(f64, -1.0), remquo_(-10.0, 3.0, &q));
    try expectEqual(@as(c_int, -3), q);

    try expectEqual(@as(f64, -0.5), remquo_(5.5, 2.0, &q));
    try expectEqual(@as(c_int, 3), q);

    try expect(math.isNan(remquo_(1.0, 0.0, &q)));
    try expect(math.isNan(remquo_(math.nan(f64), 1.0, &q)));
    try expect(math.isNan(remquo_(math.inf(f64), 1.0, &q)));

    try expectEqual(@as(f64, 0.0), remquo_(0.0, 1.0, &q));
    try expectEqual(@as(c_int, 0), q);
}

test "remainderf" {
    try expectEqual(@as(f32, 1.0), remainderf_(10.0, 3.0));
    try expectEqual(@as(f32, -1.0), remainderf_(-10.0, 3.0));
    try expectEqual(@as(f32, -0.5), remainderf_(5.5, 2.0));
    try expect(math.isNan(remainderf_(1.0, 0.0)));
}

test "remainder" {
    try expectEqual(@as(f64, 1.0), remainder_(10.0, 3.0));
    try expectEqual(@as(f64, -1.0), remainder_(-10.0, 3.0));
    try expectEqual(@as(f64, -0.5), remainder_(5.5, 2.0));
    try expect(math.isNan(remainder_(1.0, 0.0)));
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

fn tanh(x: f64) callconv(.c) f64 {
    return math.tanh(x);
}

fn tanhf(x: f32) callconv(.c) f32 {
    return math.tanh(x);
}

