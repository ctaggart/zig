// SPDX-License-Identifier: MIT
// Zig translation of musl erf.c / erff.c
// origin: FreeBSD /usr/src/lib/msun/src/s_erf.c
// origin: FreeBSD /usr/src/lib/msun/src/s_erff.c
//
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
// Developed at SunPro, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice is preserved.

const std = @import("std");
const math = std.math;
const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&erf_, "erf");
        symbol(&erfc_, "erfc");
        symbol(&erff_, "erff");
        symbol(&erfcf_, "erfcf");
    }
}

// ============================================================
// f64 constants
// ============================================================

const erx: f64 = 8.45062911510467529297e-01; // 0x3FEB0AC1, 0x60000000

// Coefficients for approximation to erf on [0,0.84375]
const efx8: f64 = 1.02703333676410069053e+00; // 0x3FF06EBA, 0x8214DB69
const pp0: f64 = 1.28379167095512558561e-01; // 0x3FC06EBA, 0x8214DB68
const pp1: f64 = -3.25042107247001499370e-01; // 0xBFD4CD7D, 0x691CB913
const pp2: f64 = -2.84817495755985104766e-02; // 0xBF9D2A51, 0xDBD7194F
const pp3: f64 = -5.77027029648944159157e-03; // 0xBF77A291, 0x236668E4
const pp4: f64 = -2.37630166566501626084e-05; // 0xBEF8EAD6, 0x120016AC
const qq1: f64 = 3.97917223959155352819e-01; // 0x3FD97779, 0xCDDADC09
const qq2: f64 = 6.50222499887672944485e-02; // 0x3FB0A54C, 0x5536CEBA
const qq3: f64 = 5.08130628187576562776e-03; // 0x3F74D022, 0xC4D36B0F
const qq4: f64 = 1.32494738004321644526e-04; // 0x3F215DC9, 0x221C1A10
const qq5: f64 = -3.96022827877536812320e-06; // 0xBED09C43, 0x42A26120

// Coefficients for approximation to erf in [0.84375,1.25]
const pa0: f64 = -2.36211856075265944077e-03; // 0xBF6359B8, 0xBEF77538
const pa1: f64 = 4.14856118683748331666e-01; // 0x3FDA8D00, 0xAD92B34D
const pa2: f64 = -3.72207876035701323847e-01; // 0xBFD7D240, 0xFBB8C3F1
const pa3: f64 = 3.18346619901161753674e-01; // 0x3FD45FCA, 0x805120E4
const pa4: f64 = -1.10894694282396677476e-01; // 0xBFBC6398, 0x3D3E28EC
const pa5: f64 = 3.54783043256182359371e-02; // 0x3FA22A36, 0x599795EB
const pa6: f64 = -2.16637559486879084300e-03; // 0xBF61BF38, 0x0A96073F
const qa1: f64 = 1.06420880400844228286e-01; // 0x3FBB3E66, 0x18EEE323
const qa2: f64 = 5.40397917702171048937e-01; // 0x3FE14AF0, 0x92EB6F33
const qa3: f64 = 7.18286544141962662868e-02; // 0x3FB2635C, 0xD99FE9A7
const qa4: f64 = 1.26171219808761642112e-01; // 0x3FC02660, 0xE763351F
const qa5: f64 = 1.36370839120290507362e-02; // 0x3F8BEDC2, 0x6B51DD1C
const qa6: f64 = 1.19844998467991074170e-02; // 0x3F888B54, 0x5735151D

// Coefficients for approximation to erfc in [1.25,1/0.35]
const ra0: f64 = -9.86494403484714822705e-03; // 0xBF843412, 0x600D6435
const ra1: f64 = -6.93858572707181764372e-01; // 0xBFE63416, 0xE4BA7360
const ra2: f64 = -1.05586262253232909814e+01; // 0xC0251E04, 0x41B0E726
const ra3: f64 = -6.23753324503260060396e+01; // 0xC04F300A, 0xE4CBA38D
const ra4: f64 = -1.62396669462573470355e+02; // 0xC0644CB1, 0x84282266
const ra5: f64 = -1.84605092906711035994e+02; // 0xC067135C, 0xEBCCABB2
const ra6: f64 = -8.12874355063065934246e+01; // 0xC0545265, 0x57E4D2F2
const ra7: f64 = -9.81432934416914548592e+00; // 0xC023A0EF, 0xC69AC25C
const sa1: f64 = 1.96512716674392571292e+01; // 0x4033A6B9, 0xBD707687
const sa2: f64 = 1.37657754143519042600e+02; // 0x4061350C, 0x526AE721
const sa3: f64 = 4.34565877475229228821e+02; // 0x407B290D, 0xD58A1A71
const sa4: f64 = 6.45387271733267880336e+02; // 0x40842B19, 0x21EC2868
const sa5: f64 = 4.29008140027567833386e+02; // 0x407AD021, 0x57700314
const sa6: f64 = 1.08635005541779435134e+02; // 0x405B28A3, 0xEE48AE2C
const sa7: f64 = 6.57024977031928170135e+00; // 0x401A47EF, 0x8E484A93
const sa8: f64 = -6.04244152148580987438e-02; // 0xBFAEEFF2, 0xEE749A62

// Coefficients for approximation to erfc in [1/.35,28]
const rb0: f64 = -9.86494292470009928597e-03; // 0xBF843412, 0x39E86F4A
const rb1: f64 = -7.99283237680523006574e-01; // 0xBFE993BA, 0x70C285DE
const rb2: f64 = -1.77579549177547519889e+01; // 0xC031C209, 0x555F995A
const rb3: f64 = -1.60636384855821916062e+02; // 0xC064145D, 0x43C5ED98
const rb4: f64 = -6.37566443368389627722e+02; // 0xC083EC88, 0x1375F228
const rb5: f64 = -1.02509513161107724954e+03; // 0xC0900461, 0x6A2E5992
const rb6: f64 = -4.83519191608651397019e+02; // 0xC07E384E, 0x9BDC383F
const sb1: f64 = 3.03380607434824582924e+01; // 0x403E568B, 0x261D5190
const sb2: f64 = 3.25792512996573918826e+02; // 0x40745CAE, 0x221B9F0A
const sb3: f64 = 1.53672958608443695994e+03; // 0x409802EB, 0x189D5118
const sb4: f64 = 3.19985821950859553908e+03; // 0x40A8FFB7, 0x688C246A
const sb5: f64 = 2.55305040643316442583e+03; // 0x40A3F219, 0xCEDF3BE6
const sb6: f64 = 4.74528541206955367215e+02; // 0x407DA874, 0xE79FE763
const sb7: f64 = -2.24409524465858183362e+01; // 0xC03670E2, 0x42712D62

// ============================================================
// f32 constants
// ============================================================

const erxf: f32 = 8.4506291151e-01; // 0x3f58560b

// Coefficients for approximation to erf on [0,0.84375]
const efx8f: f32 = 1.0270333290e+00; // 0x3f8375d4
const pp0f: f32 = 1.2837916613e-01; // 0x3e0375d4
const pp1f: f32 = -3.2504209876e-01; // 0xbea66beb
const pp2f: f32 = -2.8481749818e-02; // 0xbce9528f
const pp3f: f32 = -5.7702702470e-03; // 0xbbbd1489
const pp4f: f32 = -2.3763017452e-05; // 0xb7c756b1
const qq1f: f32 = 3.9791721106e-01; // 0x3ecbbbce
const qq2f: f32 = 6.5022252500e-02; // 0x3d852a63
const qq3f: f32 = 5.0813062117e-03; // 0x3ba68116
const qq4f: f32 = 1.3249473704e-04; // 0x390aee49
const qq5f: f32 = -3.9602282413e-06; // 0xb684e21a

// Coefficients for approximation to erf in [0.84375,1.25]
const pa0f: f32 = -2.3621185683e-03; // 0xbb1acdc6
const pa1f: f32 = 4.1485610604e-01; // 0x3ed46805
const pa2f: f32 = -3.7220788002e-01; // 0xbebe9208
const pa3f: f32 = 3.1834661961e-01; // 0x3ea2fe54
const pa4f: f32 = -1.1089469492e-01; // 0xbde31cc2
const pa5f: f32 = 3.5478305072e-02; // 0x3d1151b3
const pa6f: f32 = -2.1663755178e-03; // 0xbb0df9c0
const qa1f: f32 = 1.0642088205e-01; // 0x3dd9f331
const qa2f: f32 = 5.4039794207e-01; // 0x3f0a5785
const qa3f: f32 = 7.1828655899e-02; // 0x3d931ae7
const qa4f: f32 = 1.2617121637e-01; // 0x3e013307
const qa5f: f32 = 1.3637083583e-02; // 0x3c5f6e13
const qa6f: f32 = 1.1984500103e-02; // 0x3c445aa3

// Coefficients for approximation to erfc in [1.25,1/0.35]
const ra0f: f32 = -9.8649440333e-03; // 0xbc21a093
const ra1f: f32 = -6.9385856390e-01; // 0xbf31a0b7
const ra2f: f32 = -1.0558626175e+01; // 0xc128f022
const ra3f: f32 = -6.2375331879e+01; // 0xc2798057
const ra4f: f32 = -1.6239666748e+02; // 0xc322658c
const ra5f: f32 = -1.8460508728e+02; // 0xc3389ae7
const ra6f: f32 = -8.1287437439e+01; // 0xc2a2932b
const ra7f: f32 = -9.8143291473e+00; // 0xc11d077e
const sa1f: f32 = 1.9651271820e+01; // 0x419d35ce
const sa2f: f32 = 1.3765776062e+02; // 0x4309a863
const sa3f: f32 = 4.3456588745e+02; // 0x43d9486f
const sa4f: f32 = 6.4538726807e+02; // 0x442158c9
const sa5f: f32 = 4.2900814819e+02; // 0x43d6810b
const sa6f: f32 = 1.0863500214e+02; // 0x42d9451f
const sa7f: f32 = 6.5702495575e+00; // 0x40d23f7c
const sa8f: f32 = -6.0424413532e-02; // 0xbd777f97

// Coefficients for approximation to erfc in [1/.35,28]
const rb0f: f32 = -9.8649431020e-03; // 0xbc21a092
const rb1f: f32 = -7.9928326607e-01; // 0xbf4c9dd4
const rb2f: f32 = -1.7757955551e+01; // 0xc18e104b
const rb3f: f32 = -1.6063638306e+02; // 0xc320a2ea
const rb4f: f32 = -6.3756646729e+02; // 0xc41f6441
const rb5f: f32 = -1.0250950928e+03; // 0xc480230b
const rb6f: f32 = -4.8351919556e+02; // 0xc3f1c275
const sb1f: f32 = 3.0338060379e+01; // 0x41f2b459
const sb2f: f32 = 3.2579251099e+02; // 0x43a2e571
const sb3f: f32 = 1.5367296143e+03; // 0x44c01759
const sb4f: f32 = 3.1998581543e+03; // 0x4547fdbb
const sb5f: f32 = 2.5530502930e+03; // 0x451f90ce
const sb6f: f32 = 4.7452853394e+02; // 0x43ed43a7
const sb7f: f32 = -2.2440952301e+01; // 0xc1b38712

// ============================================================
// f64 helpers
// ============================================================

fn erfc1_64(x: f64) f64 {
    const s: f64 = @abs(x) - 1;
    const P: f64 = pa0 + s * (pa1 + s * (pa2 + s * (pa3 + s * (pa4 + s * (pa5 + s * pa6)))));
    const Q: f64 = 1 + s * (qa1 + s * (qa2 + s * (qa3 + s * (qa4 + s * (qa5 + s * qa6)))));
    return 1 - erx - P / Q;
}

fn erfc2_64(ix: u32, x_arg: f64) f64 {
    var x: f64 = x_arg;

    if (ix < 0x3ff40000) // |x| < 1.25
        return erfc1_64(x);

    x = @abs(x);
    const s: f64 = 1 / (x * x);
    var R: f64 = undefined;
    var S: f64 = undefined;
    if (ix < 0x4006db6d) { // |x| < 1/.35 ~ 2.85714
        R = ra0 + s * (ra1 + s * (ra2 + s * (ra3 + s * (ra4 + s * (ra5 + s * (ra6 + s * ra7))))));
        S = 1.0 + s * (sa1 + s * (sa2 + s * (sa3 + s * (sa4 + s * (sa5 + s * (sa6 + s * (sa7 + s * sa8)))))));
    } else { // |x| > 1/.35
        R = rb0 + s * (rb1 + s * (rb2 + s * (rb3 + s * (rb4 + s * (rb5 + s * rb6)))));
        S = 1.0 + s * (sb1 + s * (sb2 + s * (sb3 + s * (sb4 + s * (sb5 + s * (sb6 + s * sb7))))));
    }
    // SET_LOW_WORD(z, 0): clear low 32 bits
    const z: f64 = @bitCast(@as(u64, @bitCast(x)) & 0xFFFFFFFF_00000000);
    return @exp(-z * z - 0.5625) * @exp((z - x) * (z + x) + R / S) / x;
}

// ============================================================
// f32 helpers
// ============================================================

fn erfc1_32(x: f32) f32 {
    const s: f32 = @abs(x) - 1;
    const P: f32 = pa0f + s * (pa1f + s * (pa2f + s * (pa3f + s * (pa4f + s * (pa5f + s * pa6f)))));
    const Q: f32 = 1 + s * (qa1f + s * (qa2f + s * (qa3f + s * (qa4f + s * (qa5f + s * qa6f)))));
    return 1 - erxf - P / Q;
}

fn erfc2_32(ix_arg: u32, x_arg: f32) f32 {
    var ix: u32 = ix_arg;
    var x: f32 = x_arg;

    if (ix < 0x3fa00000) // |x| < 1.25
        return erfc1_32(x);

    x = @abs(x);
    const s: f32 = 1 / (x * x);
    var R: f32 = undefined;
    var S: f32 = undefined;
    if (ix < 0x4036db6d) { // |x| < 1/0.35
        R = ra0f + s * (ra1f + s * (ra2f + s * (ra3f + s * (ra4f + s * (ra5f + s * (ra6f + s * ra7f))))));
        S = 1.0 + s * (sa1f + s * (sa2f + s * (sa3f + s * (sa4f + s * (sa5f + s * (sa6f + s * (sa7f + s * sa8f)))))));
    } else { // |x| >= 1/0.35
        R = rb0f + s * (rb1f + s * (rb2f + s * (rb3f + s * (rb4f + s * (rb5f + s * rb6f)))));
        S = 1.0 + s * (sb1f + s * (sb2f + s * (sb3f + s * (sb4f + s * (sb5f + s * (sb6f + s * sb7f))))));
    }
    // GET_FLOAT_WORD / SET_FLOAT_WORD: mask low 13 bits of significand
    ix = @as(u32, @bitCast(x));
    const z: f32 = @bitCast(ix & 0xffffe000);
    return @exp(-z * z - 0.5625) * @exp((z - x) * (z + x) + R / S) / x;
}

// ============================================================
// Exported f64 functions
// ============================================================

fn erf_(x: f64) callconv(.c) f64 {
    var ix: u32 = @truncate(@as(u64, @bitCast(x)) >> 32);
    const sign: bool = ix >> 31 != 0;
    ix &= 0x7fffffff;
    if (ix >= 0x7ff00000) {
        // erf(nan)=nan, erf(+-inf)=+-1
        const s: f64 = if (sign) -1.0 else 1.0;
        return s + 1.0 / x;
    }
    if (ix < 0x3feb0000) { // |x| < 0.84375
        if (ix < 0x3e300000) { // |x| < 2**-28
            // avoid underflow
            return 0.125 * (8 * x + efx8 * x);
        }
        const z: f64 = x * x;
        const r: f64 = pp0 + z * (pp1 + z * (pp2 + z * (pp3 + z * pp4)));
        const s: f64 = 1.0 + z * (qq1 + z * (qq2 + z * (qq3 + z * (qq4 + z * qq5))));
        const y: f64 = r / s;
        return x + x * y;
    }
    var y: f64 = undefined;
    if (ix < 0x40180000) // 0.84375 <= |x| < 6
        y = 1 - erfc2_64(ix, x)
    else
        y = 1 - 0x1p-1022;
    return if (sign) -y else y;
}

fn erfc_(x: f64) callconv(.c) f64 {
    var ix: u32 = @truncate(@as(u64, @bitCast(x)) >> 32);
    const sign: bool = ix >> 31 != 0;
    ix &= 0x7fffffff;
    if (ix >= 0x7ff00000) {
        // erfc(nan)=nan, erfc(+-inf)=0,2
        const s: f64 = if (sign) 2.0 else 0.0;
        return s + 1.0 / x;
    }
    if (ix < 0x3feb0000) { // |x| < 0.84375
        if (ix < 0x3c700000) // |x| < 2**-56
            return 1.0 - x;
        const z: f64 = x * x;
        const r: f64 = pp0 + z * (pp1 + z * (pp2 + z * (pp3 + z * pp4)));
        const s: f64 = 1.0 + z * (qq1 + z * (qq2 + z * (qq3 + z * (qq4 + z * qq5))));
        const y: f64 = r / s;
        if (sign or ix < 0x3fd00000) { // x < 1/4
            return 1.0 - (x + x * y);
        }
        return 0.5 - (x - 0.5 + x * y);
    }
    if (ix < 0x403c0000) { // 0.84375 <= |x| < 28
        return if (sign) 2 - erfc2_64(ix, x) else erfc2_64(ix, x);
    }
    return if (sign) 2 - 0x1p-1022 else 0x1p-1022 * 0x1p-1022;
}

// ============================================================
// Exported f32 functions
// ============================================================

fn erff_(x: f32) callconv(.c) f32 {
    var ix: u32 = @bitCast(x);
    const sign: bool = ix >> 31 != 0;
    ix &= 0x7fffffff;
    if (ix >= 0x7f800000) {
        // erf(nan)=nan, erf(+-inf)=+-1
        const s: f32 = if (sign) -1.0 else 1.0;
        return s + 1.0 / x;
    }
    if (ix < 0x3f580000) { // |x| < 0.84375
        if (ix < 0x31800000) { // |x| < 2**-28
            // avoid underflow
            return 0.125 * (8 * x + efx8f * x);
        }
        const z: f32 = x * x;
        const r: f32 = pp0f + z * (pp1f + z * (pp2f + z * (pp3f + z * pp4f)));
        const s: f32 = 1 + z * (qq1f + z * (qq2f + z * (qq3f + z * (qq4f + z * qq5f))));
        const y: f32 = r / s;
        return x + x * y;
    }
    var y: f32 = undefined;
    if (ix < 0x40c00000) // |x| < 6
        y = 1 - erfc2_32(ix, x)
    else
        y = 1 - 0x1p-120;
    return if (sign) -y else y;
}

fn erfcf_(x: f32) callconv(.c) f32 {
    var ix: u32 = @bitCast(x);
    const sign: bool = ix >> 31 != 0;
    ix &= 0x7fffffff;
    if (ix >= 0x7f800000) {
        // erfc(nan)=nan, erfc(+-inf)=0,2
        const s: f32 = if (sign) 2.0 else 0.0;
        return s + 1.0 / x;
    }
    if (ix < 0x3f580000) { // |x| < 0.84375
        if (ix < 0x23800000) // |x| < 2**-56
            return 1.0 - x;
        const z: f32 = x * x;
        const r: f32 = pp0f + z * (pp1f + z * (pp2f + z * (pp3f + z * pp4f)));
        const s: f32 = 1.0 + z * (qq1f + z * (qq2f + z * (qq3f + z * (qq4f + z * qq5f))));
        const y: f32 = r / s;
        if (sign or ix < 0x3e800000) // x < 1/4
            return 1.0 - (x + x * y);
        return 0.5 - (x - 0.5 + x * y);
    }
    if (ix < 0x41e00000) { // |x| < 28
        return if (sign) 2 - erfc2_32(ix, x) else erfc2_32(ix, x);
    }
    return if (sign) 2 - 0x1p-120 else 0x1p-120 * 0x1p-120;
}
