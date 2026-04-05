// Port of musl j0.c (j0 and y0, f64 only) to Zig with extended-precision
// intermediates to avoid catastrophic cancellation near Bessel function zeros.
//
// The musl C implementation computes:
//   j0(x) = sqrt(2/(pi*x)) * [P0(x)*cos(x-pi/4) - Q0(x)*sin(x-pi/4)]
// Near zeros of J0, P0*cos(x-pi/4) ≈ Q0*sin(x-pi/4), so their difference
// loses all significant digits in f64 arithmetic. By computing in extended
// precision (f80 on x86, f128 elsewhere), we preserve enough bits through
// the cancellation for the final f64 result.
//
// f32 versions (j0f, y0f) remain in C musl as they pass accuracy tests.

const std = @import("std");
const math = std.math;
const builtin = @import("builtin");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&j0_, "j0");
        symbol(&y0_, "y0");
    }
}

// Extended precision type: f80 on x86/x86_64 (hardware), f128 elsewhere.
const F = if (builtin.cpu.arch == .x86 or builtin.cpu.arch == .x86_64) f80 else f128;

const invsqrtpi: f64 = 5.64189583547756279280e-01; // 0x3FE20DD7, 0x50429B6D
const tpi: f64 = 6.36619772367581382433e-01; // 0x3FE45F30, 0x6DC9C883

// Asymptotic expansion for |x| >= 2.
// j0(x) = sqrt(2/(pi*x)) * (P0(x)*cos(x-pi/4) - Q0(x)*sin(x-pi/4))
// y0(x) = sqrt(2/(pi*x)) * (P0(x)*sin(x-pi/4) + Q0(x)*cos(x-pi/4))
fn common(ix: u32, x_: f64, y0_flag: bool) f64 {
    const x: F = @floatCast(x_);

    const s: F = @sin(x);
    var c: F = @cos(x);

    if (y0_flag) c = -c;

    var cc: F = s + c;
    var ss: F = s - c;

    // Avoid overflow in 2*x, big ulp error when x >= 0x1p1023
    if (ix < 0x7fe00000) {
        // Use identity sin(x)±cos(x) = -cos(2x)/(sin(x)∓cos(x))
        // to recompute the less accurate of cc, ss.
        const z: F = -@cos(@as(F, 2.0) * x);
        if (s * c < 0)
            cc = z / ss
        else
            ss = z / cc;

        if (ix < 0x48000000) {
            if (y0_flag) ss = -ss;
            cc = pzero(x) * cc - qzero(x) * ss;
        }
    }

    const c_invsqrtpi: F = @floatCast(invsqrtpi);
    return @floatCast(c_invsqrtpi * cc / @sqrt(x));
}

// R0/S0 on [0, 2.00]
const R02: f64 = 1.56249999999999947958e-02; // 0x3F8FFFFF, 0xFFFFFFFD
const R03: f64 = -1.89979294238854721751e-04; // 0xBF28E6A5, 0xB61AC6E9
const R04: f64 = 1.82954049532700665670e-06; // 0x3EBEB1D1, 0x0C503919
const R05: f64 = -4.61832688532103189199e-09; // 0xBE33D5E7, 0x73D63FCE
const S01: f64 = 1.56191029464890010492e-02; // 0x3F8FFCE8, 0x82C8C2A4
const S02: f64 = 1.16926784663337450260e-04; // 0x3F1EA6D2, 0xDD57DBF4
const S03: f64 = 5.13546550207318111446e-07; // 0x3EA13B54, 0xCE84D5A9
const S04: f64 = 1.16614003333790000205e-09; // 0x3E1408BC, 0xF4745D8F

fn j0_(x_: f64) callconv(.c) f64 {
    const bits: u64 = @bitCast(x_);
    var ix: u32 = @truncate(bits >> 32);
    ix &= 0x7fffffff;

    // j0(+-inf)=0, j0(nan)=nan
    if (ix >= 0x7ff00000)
        return 1 / (x_ * x_);

    const x: f64 = @abs(x_);

    if (ix >= 0x40000000) // |x| >= 2
        return common(ix, x, false);

    // 1 - x*x/4 + x*x*R(x^2)/S(x^2)
    if (ix >= 0x3f200000) { // |x| >= 2**-13
        const z = x * x;
        const r = z * (R02 + z * (R03 + z * (R04 + z * R05)));
        const s = 1 + z * (S01 + z * (S02 + z * (S03 + z * S04)));
        return (1 + x / 2) * (1 - x / 2) + z * (r / s);
    }

    // 1 - x*x/4
    if (ix >= 0x38000000) // |x| >= 2**-127
        return 1 - 0.25 * x * x;

    return 1 - x;
}

const y0_u00: f64 = -7.38042951086872317523e-02; // 0xBFB2E4D6, 0x99CBD01F
const y0_u01: f64 = 1.76666452509181115538e-01; // 0x3FC69D01, 0x9DE9E3FC
const y0_u02: f64 = -1.38185671945596898896e-02; // 0xBF8C4CE8, 0xB16CFA97
const y0_u03: f64 = 3.47453432093683650238e-04; // 0x3F36C54D, 0x20B29B6B
const y0_u04: f64 = -3.81407053724364161125e-06; // 0xBECFFEA7, 0x73D25CAD
const y0_u05: f64 = 1.95590137035022920206e-08; // 0x3E550057, 0x3B4EABD4
const y0_u06: f64 = -3.98205194132103398453e-11; // 0xBDC5E43D, 0x693FB3C8
const y0_v01: f64 = 1.27304834834123699328e-02; // 0x3F8A1270, 0x91C9C71A
const y0_v02: f64 = 7.60068627350353253702e-05; // 0x3F13ECBB, 0xF578C6C1
const y0_v03: f64 = 2.59150851840457805467e-07; // 0x3E91642D, 0x7FF202FD
const y0_v04: f64 = 4.41110311332675467403e-10; // 0x3DFE5018, 0x3BD6D9EF

fn y0_(x_: f64) callconv(.c) f64 {
    const bits: u64 = @bitCast(x_);
    const ix: u32 = @truncate(bits >> 32);
    const lx: u32 = @truncate(bits);

    // y0(nan)=nan, y0(<0)=nan, y0(0)=-inf, y0(inf)=0
    if ((ix << 1 | lx) == 0)
        return -1.0 / @as(f64, 0.0);
    if (ix >> 31 != 0)
        return @as(f64, 0.0) / @as(f64, 0.0);
    if (ix >= 0x7ff00000)
        return 1 / x_;

    if (ix >= 0x40000000) // x >= 2
        return common(ix, x_, true);

    // U(x^2)/V(x^2) + (2/pi)*j0(x)*log(x)
    if (ix >= 0x3e400000) { // x >= 2**-27
        const z = x_ * x_;
        const u = y0_u00 + z * (y0_u01 + z * (y0_u02 + z * (y0_u03 + z * (y0_u04 + z * (y0_u05 + z * y0_u06)))));
        const v = 1.0 + z * (y0_v01 + z * (y0_v02 + z * (y0_v03 + z * y0_v04)));
        return u / v + tpi * (j0_(x_) * @log(x_));
    }
    return y0_u00 + tpi * @log(x_);
}

// ========== pzero/qzero asymptotic expansions ==========
//
// pzero(x) = 1 + R(1/x^2)/S(1/x^2), |error| <= 2**-60.26
// qzero(x) = (-1/8 + R(1/x^2)/S(1/x^2))/x, |error| <= 2**-61.22

const pR8 = [6]f64{
    0.00000000000000000000e+00, // 0x00000000, 0x00000000
    -7.03124999999900357484e-02, // 0xBFB1FFFF, 0xFFFFFD32
    -8.08167041275349795626e+00, // 0xC02029D0, 0xB44FA779
    -2.57063105679704847262e+02, // 0xC0701102, 0x7B19E863
    -2.48521641009428822144e+03, // 0xC0A36A6E, 0xCD4DCAFC
    -5.25304380490729545272e+03, // 0xC0B4850B, 0x36CC643D
};
const pS8 = [5]f64{
    1.16534364619668181717e+02, // 0x405D2233, 0x07A96751
    3.83374475364121826715e+03, // 0x40ADF37D, 0x50596938
    4.05978572648472545552e+04, // 0x40E3D2BB, 0x6EB6B05F
    1.16752972564375915681e+05, // 0x40FC810F, 0x8F9FA9BD
    4.76277284146730962675e+04, // 0x40E74177, 0x4F2C49DC
};

const pR5 = [6]f64{ // for x in [8,4.5454]=1/[0.125,0.22001]
    -1.14125464691894502584e-11, // 0xBDA918B1, 0x47E495CC
    -7.03124940873599280078e-02, // 0xBFB1FFFF, 0xE69AFBC6
    -4.15961064470587782438e+00, // 0xC010A370, 0xF90C6BBF
    -6.76747652265167261021e+01, // 0xC050EB2F, 0x5A7D1783
    -3.31231299649172967747e+02, // 0xC074B3B3, 0x6742CC63
    -3.46433388365604912451e+02, // 0xC075A6EF, 0x28A38BD7
};
const pS5 = [5]f64{
    6.07539382692300335975e+01, // 0x404E6081, 0x0C98C5DE
    1.05125230595704579173e+03, // 0x40906D02, 0x5C7E2864
    5.97897094333855784498e+03, // 0x40B75AF8, 0x0FBE1D60
    9.62544514357774460223e+03, // 0x40C2CCB8, 0xFA76FA38
    2.40605815922939109441e+03, // 0x40A2CC1D, 0xC70BE864
};

const pR3 = [6]f64{ // for x in [4.547,2.8571]=1/[0.2199,0.35001]
    -2.54704601771951915620e-09, // 0xBE25E103, 0x6FE1AA86
    -7.03119616381481654654e-02, // 0xBFB1FFF6, 0xF7C0E24B
    -2.40903221549529611423e+00, // 0xC00345B2, 0xAEA48074
    -2.19659774734883086467e+01, // 0xC035F74A, 0x4CB94E14
    -5.80791704701737572236e+01, // 0xC04D0A22, 0x420A1A45
    -3.14479470594888503854e+01, // 0xC03F72AC, 0xA892D80F
};
const pS3 = [5]f64{
    3.58560338055209726349e+01, // 0x4041ED92, 0x84077DD3
    3.61513983050303863820e+02, // 0x40769839, 0x464A7C0E
    1.19360783792111533330e+03, // 0x4092A66E, 0x6D1061D6
    1.12799679856907414432e+03, // 0x40919FFC, 0xB8C39B7E
    1.73580930813335754692e+02, // 0x4065B296, 0xFC379081
};

const pR2 = [6]f64{ // for x in [2.8570,2]=1/[0.3499,0.5]
    -8.87534333032526411254e-08, // 0xBE77D316, 0xE927026D
    -7.03030995483624743247e-02, // 0xBFB1FF62, 0x495E1E42
    -1.45073846780952986357e+00, // 0xBFF73639, 0x8A24A843
    -7.63569613823527770791e+00, // 0xC01E8AF3, 0xEDAFA7F3
    -1.11931668860356747786e+01, // 0xC02662E6, 0xC5246303
    -3.23364579351335335033e+00, // 0xC009DE81, 0xAF8FE70F
};
const pS2 = [5]f64{
    2.22202997532088808441e+01, // 0x40363865, 0x908B5959
    1.36206794218215208048e+02, // 0x4061069E, 0x0EE8878F
    2.70470278658083486789e+02, // 0x4070E786, 0x42EA079B
    1.53875394208320329881e+02, // 0x40633C03, 0x3AB6FAFF
    1.46576176948256193810e+01, // 0x402D50B3, 0x44391809
};

fn pzero(x: F) F {
    const xf: f64 = @floatCast(x);
    const bits: u64 = @bitCast(xf);
    var ix: u32 = @truncate(bits >> 32);
    ix &= 0x7fffffff;

    const p: [6]f64 = if (ix >= 0x40200000)
        pR8
    else if (ix >= 0x40122E8B)
        pR5
    else if (ix >= 0x4006DB6D)
        pR3
    else
        pR2;

    const q: [5]f64 = if (ix >= 0x40200000)
        pS8
    else if (ix >= 0x40122E8B)
        pS5
    else if (ix >= 0x4006DB6D)
        pS3
    else
        pS2;

    const z: F = 1.0 / (x * x);
    const r: F = @as(F, p[0]) + z * (@as(F, p[1]) + z * (@as(F, p[2]) + z * (@as(F, p[3]) + z * (@as(F, p[4]) + z * @as(F, p[5])))));
    const s: F = 1.0 + z * (@as(F, q[0]) + z * (@as(F, q[1]) + z * (@as(F, q[2]) + z * (@as(F, q[3]) + z * @as(F, q[4])))));
    return 1.0 + r / s;
}

const qR8 = [6]f64{
    0.00000000000000000000e+00, // 0x00000000, 0x00000000
    7.32421874999935051953e-02, // 0x3FB2BFFF, 0xFFFFFE2C
    1.17682064682252693899e+01, // 0x40278952, 0x5BB334D6
    5.57673380256401856059e+02, // 0x40816D63, 0x15301825
    8.85919720756468632317e+03, // 0x40C14D99, 0x3E18F46D
    3.70146267776887834771e+04, // 0x40E212D4, 0x0E901566
};
const qS8 = [6]f64{
    1.63776026895689824414e+02, // 0x406478D5, 0x365B39BC
    8.09834494656449805916e+03, // 0x40BFA258, 0x4E6B0563
    1.42538291419120476348e+05, // 0x41016652, 0x54D38C3F
    8.03309257119514397345e+05, // 0x412883DA, 0x83A52B43
    8.40501579819060512818e+05, // 0x4129A66B, 0x28DE0B3D
    -3.43899293537866615225e+05, // 0xC114FD6D, 0x2C9530C5
};

const qR5 = [6]f64{ // for x in [8,4.5454]=1/[0.125,0.22001]
    1.84085963594515531381e-11, // 0x3DB43D8F, 0x29CC8CD9
    7.32421766612684765896e-02, // 0x3FB2BFFF, 0xD172B04C
    5.83563508962056953777e+00, // 0x401757B0, 0xB9953DD3
    1.35111577286449829671e+02, // 0x4060E392, 0x0A8788E9
    1.02724376596164097464e+03, // 0x40900CF9, 0x9DC8C481
    1.98997785864605384631e+03, // 0x409F17E9, 0x53C6E3A6
};
const qS5 = [6]f64{
    8.27766102236537761883e+01, // 0x4054B1B3, 0xFB5E1543
    2.07781416421392987104e+03, // 0x40A03BA0, 0xDA21C0CE
    1.88472887785718085070e+04, // 0x40D267D2, 0x7B591E6D
    5.67511122894947329769e+04, // 0x40EBB5E3, 0x97E02372
    3.59767538425114471465e+04, // 0x40E19118, 0x1F7A54A0
    -5.35434275601944773371e+03, // 0xC0B4EA57, 0xBEDBC609
};

const qR3 = [6]f64{ // for x in [4.547,2.8571]=1/[0.2199,0.35001]
    4.37741014089738620906e-09, // 0x3E32CD03, 0x6ADECB82
    7.32411180042911447163e-02, // 0x3FB2BFEE, 0x0E8D0842
    3.34423137516170720929e+00, // 0x400AC0FC, 0x61149CF5
    4.26218440745412650017e+01, // 0x40454F98, 0x962DAEDD
    1.70808091340565596283e+02, // 0x406559DB, 0xE25EFD1F
    1.66733948696651168575e+02, // 0x4064D77C, 0x81FA21E0
};
const qS3 = [6]f64{
    4.87588729724587182091e+01, // 0x40486122, 0xBFE343A6
    7.09689221056606015736e+02, // 0x40862D83, 0x86544EB3
    3.70414822620111362994e+03, // 0x40ACF04B, 0xE44DFC63
    6.46042516752568917582e+03, // 0x40B93C6C, 0xD7C76A28
    2.51633368920368957333e+03, // 0x40A3A8AA, 0xD94FB1C0
    -1.49247451836156386662e+02, // 0xC062A7EB, 0x201CF40F
};

const qR2 = [6]f64{ // for x in [2.8570,2]=1/[0.3499,0.5]
    1.50444444886983272379e-07, // 0x3E84313B, 0x54F76BDB
    7.32234265963079278272e-02, // 0x3FB2BEC5, 0x3E883E34
    1.99819174093815998816e+00, // 0x3FFFF897, 0xE727779C
    1.44956029347885735348e+01, // 0x402CFDBF, 0xAAF96FE5
    3.16662317504781540833e+01, // 0x403FAA8E, 0x29FBDC4A
    1.62527075710929267416e+01, // 0x403040B1, 0x71814BB4
};
const qS2 = [6]f64{
    3.03655848355219184498e+01, // 0x403E5D96, 0xF7C07AED
    2.69348118608049844624e+02, // 0x4070D591, 0xE4D14B40
    8.44783757595320139444e+02, // 0x408A6645, 0x22B3BF22
    8.82935845112488550512e+02, // 0x408B977C, 0x9C5CC214
    2.12666388511798828631e+02, // 0x406A9553, 0x0E001365
    -5.31095493882666946917e+00, // 0xC0153E6A, 0xF8B32931
};

fn qzero(x: F) F {
    const xf: f64 = @floatCast(x);
    const bits: u64 = @bitCast(xf);
    var ix: u32 = @truncate(bits >> 32);
    ix &= 0x7fffffff;

    const p: [6]f64 = if (ix >= 0x40200000)
        qR8
    else if (ix >= 0x40122E8B)
        qR5
    else if (ix >= 0x4006DB6D)
        qR3
    else
        qR2;

    const q: [6]f64 = if (ix >= 0x40200000)
        qS8
    else if (ix >= 0x40122E8B)
        qS5
    else if (ix >= 0x4006DB6D)
        qS3
    else
        qS2;

    const z: F = 1.0 / (x * x);
    const r: F = @as(F, p[0]) + z * (@as(F, p[1]) + z * (@as(F, p[2]) + z * (@as(F, p[3]) + z * (@as(F, p[4]) + z * @as(F, p[5])))));
    const s: F = 1.0 + z * (@as(F, q[0]) + z * (@as(F, q[1]) + z * (@as(F, q[2]) + z * (@as(F, q[3]) + z * (@as(F, q[4]) + z * @as(F, q[5]))))));
    return (-0.125 + r / s) / x;
}
