const builtin = @import("builtin");
const std = @import("std");
const symbol = @import("../c.zig").symbol;

/// fexcept_t type matching musl's arch-specific bits/fenv.h definitions.
const fexcept_t = switch (builtin.cpu.arch) {
    .x86_64, .x86, .mips, .mipsel, .mips64, .mips64el => c_ushort,
    .aarch64,
    .aarch64_be,
    .riscv32,
    .riscv64,
    .loongarch64,
    .m68k,
    .powerpc,
    .powerpcle,
    .powerpc64,
    .powerpc64le,
    .s390x,
    => c_uint,
    else => c_ulong,
};

const FE_TONEAREST: c_int = 0;

const FE_ALL_EXCEPT: c_int = switch (builtin.cpu.arch) {
    .x86_64, .x86, .hexagon => 0x3f,
    .aarch64,
    .aarch64_be,
    .arm,
    .armeb,
    .thumb,
    .thumbeb,
    .riscv32,
    .riscv64,
    => 0x1f,
    .loongarch64 => 0x1f0000,
    .m68k => 0xf8,
    .mips, .mipsel, .mips64, .mips64el => 0x7c,
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => 0x3e000000,
    .s390x => 0xf80000,
    else => 0,
};

const FE_TOWARDZERO: ?c_int = switch (builtin.cpu.arch) {
    .x86_64, .x86 => 0xc00,
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb => @as(c_int, 0xc00000),
    .riscv32,
    .riscv64,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .powerpc,
    .powerpcle,
    .powerpc64,
    .powerpc64le,
    .s390x,
    => 1,
    .hexagon => 0x01,
    .loongarch64 => 0x100,
    .m68k => 16,
    else => null,
};

const FE_UPWARD: ?c_int = switch (builtin.cpu.arch) {
    .x86_64, .x86 => 0x800,
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb => 0x400000,
    .riscv32, .riscv64 => 3,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .powerpc,
    .powerpcle,
    .powerpc64,
    .powerpc64le,
    .s390x,
    => 2,
    .hexagon => 0x03,
    .loongarch64 => 0x200,
    .m68k => 48,
    else => null,
};

const FE_DOWNWARD: ?c_int = switch (builtin.cpu.arch) {
    .x86_64, .x86 => 0x400,
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb => @as(c_int, 0x800000),
    .riscv32, .riscv64 => 2,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .powerpc,
    .powerpcle,
    .powerpc64,
    .powerpc64le,
    .s390x,
    => 3,
    .hexagon => 0x02,
    .loongarch64 => 0x300,
    .m68k => 32,
    else => null,
};

const arch = builtin.cpu.arch;
const abi = builtin.abi;
const is_loongarch64_sf = arch == .loongarch64 and abi == .muslsf;
const has_zig_fenv = is_loongarch64_sf or arch == .s390x;

comptime {
    if (builtin.link_libc) {
        // Weak generic fallbacks (from fenv.c).
        // Overridden by arch-specific implementations at link time.
        if (has_zig_fenv) {
            symbol(&feclearexcept_impl, "feclearexcept");
            symbol(&feraiseexcept_impl, "feraiseexcept");
            symbol(&fetestexcept_impl, "fetestexcept");
            symbol(&fegetround_impl, "fegetround");
            symbol(&__fesetround_impl, "__fesetround");
            symbol(&fegetenv_impl, "fegetenv");
            symbol(&fesetenv_impl, "fesetenv");
        } else {
            symbol(&feclearexcept, "feclearexcept");
            symbol(&feraiseexcept, "feraiseexcept");
            symbol(&fetestexcept, "fetestexcept");
            symbol(&fegetround, "fegetround");
            symbol(&__fesetround, "__fesetround");
            symbol(&fegetenv, "fegetenv");
            symbol(&fesetenv, "fesetenv");
        }

        // Generic callers (no arch-specific overrides for these).
        symbol(&__flt_rounds, "__flt_rounds");
        symbol(&fegetexceptflag, "fegetexceptflag");
        symbol(&feholdexcept, "feholdexcept");
        symbol(&fesetexceptflag, "fesetexceptflag");
        symbol(&fesetround, "fesetround");
        symbol(&feupdateenv, "feupdateenv");
    }
}

// Weak generic fallbacks for archs without arch-specific fenv.
// On archs with FPU support, the arch-specific assembly provides
// strong definitions that override these at link time.

fn feclearexcept(mask: c_int) callconv(.c) c_int {
    return feclearexcept_impl(mask);
}

fn feraiseexcept(mask: c_int) callconv(.c) c_int {
    return feraiseexcept_impl(mask);
}

fn fetestexcept(mask: c_int) callconv(.c) c_int {
    return fetestexcept_impl(mask);
}

fn fegetround() callconv(.c) c_int {
    return fegetround_impl();
}

fn __fesetround(r: c_int) callconv(.c) c_int {
    return __fesetround_impl(r);
}

fn fegetenv(envp: *anyopaque) callconv(.c) c_int {
    return fegetenv_impl(envp);
}

fn fesetenv(envp: *const anyopaque) callconv(.c) c_int {
    return fesetenv_impl(envp);
}

fn feclearexcept_impl(mask_arg: c_int) callconv(.c) c_int {
    return switch (arch) {
        .s390x => {
            const mask: c_uint = @bitCast(mask_arg & FE_ALL_EXCEPT);
            set_fpc(get_fpc() & ~mask);
            return 0;
        },
        else => 0,
    };
}

fn feraiseexcept_impl(mask_arg: c_int) callconv(.c) c_int {
    return switch (arch) {
        .s390x => {
            const mask: c_uint = @bitCast(mask_arg & FE_ALL_EXCEPT);
            set_fpc(get_fpc() | mask);
            return 0;
        },
        else => 0,
    };
}

fn fetestexcept_impl(mask_arg: c_int) callconv(.c) c_int {
    return switch (arch) {
        .s390x => return @bitCast(get_fpc() & @as(c_uint, @bitCast(mask_arg)) & @as(c_uint, @bitCast(FE_ALL_EXCEPT))),
        else => 0,
    };
}

fn fegetround_impl() callconv(.c) c_int {
    return switch (arch) {
        .s390x => @intCast(get_fpc() & 3),
        else => FE_TONEAREST,
    };
}

fn __fesetround_impl(r_arg: c_int) callconv(.c) c_int {
    return switch (arch) {
        .s390x => {
            const r: c_uint = @bitCast(r_arg);
            set_fpc((get_fpc() & ~@as(c_uint, 3)) | r);
            return 0;
        },
        else => 0,
    };
}

fn fegetenv_impl(envp: *anyopaque) callconv(.c) c_int {
    switch (arch) {
        .s390x => @as(*c_uint, @ptrCast(@alignCast(envp))).* = get_fpc(),
        else => {},
    }
    return 0;
}

fn fesetenv_impl(envp: *const anyopaque) callconv(.c) c_int {
    switch (arch) {
        .s390x => {
            const env: usize = @intFromPtr(envp);
            set_fpc(if (env != std.math.maxInt(usize)) @as(*const c_uint, @ptrCast(@alignCast(envp))).* else 0);
        },
        else => {},
    }
    return 0;
}

fn get_fpc() c_uint {
    return asm ("efpc %[fpc]"
        : [fpc] "=r" (-> c_uint),
    );
}

fn set_fpc(fpc: c_uint) void {
    asm volatile ("sfpc %[fpc]"
        :
        : [fpc] "r" (fpc),
    );
}

// Generic callers: these call the fenv functions above (or their
// arch-specific overrides) and are always compiled for all architectures.

fn __flt_rounds() callconv(.c) c_int {
    const round = fegetround();
    if (FE_TOWARDZERO) |v| {
        if (round == v) return 0;
    }
    if (round == FE_TONEAREST) return 1;
    if (FE_UPWARD) |v| {
        if (round == v) return 2;
    }
    if (FE_DOWNWARD) |v| {
        if (round == v) return 3;
    }
    return -1;
}

fn fegetexceptflag(fp: *fexcept_t, mask: c_int) callconv(.c) c_int {
    fp.* = @intCast(@as(c_uint, @bitCast(fetestexcept(mask))));
    return 0;
}

fn feholdexcept(envp: *anyopaque) callconv(.c) c_int {
    _ = fegetenv(envp);
    _ = feclearexcept(FE_ALL_EXCEPT);
    return 0;
}

fn fesetexceptflag(fp: *const fexcept_t, mask: c_int) callconv(.c) c_int {
    const fp_int: c_int = @intCast(fp.*);
    _ = feclearexcept(~fp_int & mask);
    _ = feraiseexcept(fp_int & mask);
    return 0;
}

fn fesetround(r: c_int) callconv(.c) c_int {
    if (r == FE_TONEAREST) return __fesetround(r);
    if (FE_DOWNWARD) |v| {
        if (r == v) return __fesetround(r);
    }
    if (FE_UPWARD) |v| {
        if (r == v) return __fesetround(r);
    }
    if (FE_TOWARDZERO) |v| {
        if (r == v) return __fesetround(r);
    }
    return -1;
}

fn feupdateenv(envp: *const anyopaque) callconv(.c) c_int {
    const ex = fetestexcept(FE_ALL_EXCEPT);
    _ = fesetenv(envp);
    _ = feraiseexcept(ex);
    return 0;
}
