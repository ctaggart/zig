const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

// The x32 ABI runs on x86_64 and uses the same syscall convention as x86_64:
// arguments are passed in the full 64-bit registers rdi/rsi/rdx/r10/r8/r9.
// Some syscalls (e.g. mmap offset, lseek offset) use the full 64-bit width of
// a single argument register, so arg types are u64 (not u32) to avoid
// truncation. Userland pointers and size_t are 32-bit on x32, so a u32
// `usize` value passed in will be zero-extended to 64 bits automatically.
// The return type stays u32 because x32 usize is 32-bit and callers in
// lib/std/os/linux.zig return `usize`.

pub fn syscall0(number: SYS) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: u64) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: u64, arg2: u64) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: u64, arg2: u64, arg3: u64) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall4(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall5(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall6(
    number: SYS,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
    arg5: u64,
    arg6: u64,
) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
          [arg6] "{r9}" (arg6),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn clone() callconv(.naked) u32 {
    asm volatile (
        \\      movl $0x40000038,%%eax // SYS_clone
        \\      mov %%rdi,%%r11
        \\      mov %%rdx,%%rdi
        \\      mov %%r8,%%rdx
        \\      mov %%r9,%%r8
        \\      mov 8(%%rsp),%%r10
        \\      mov %%r11,%%r9
        \\      and $-16,%%rsi
        \\      sub $8,%%rsi
        \\      mov %%rcx,(%%rsi)
        \\      syscall
        \\      test %%eax,%%eax
        \\      jz 1f
        \\      ret
        \\
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\      .cfi_undefined %%rip
    );
    asm volatile (
        \\      xor %%ebp,%%ebp
        \\
        \\      pop %%rdi
        \\      call *%%r9
        \\      mov %%eax,%%edi
        \\      movl $0x4000003c,%%eax // SYS_exit
        \\      syscall
        \\
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.naked) noreturn {
    switch (builtin.zig_backend) {
        .stage2_c => asm volatile (
            \\ movl %[number], %%eax
            \\ syscall
            :
            : [number] "i" (@intFromEnum(SYS.rt_sigreturn)),
        ),
        else => asm volatile (
            \\ syscall
            :
            : [number] "{rax}" (@intFromEnum(SYS.rt_sigreturn)),
        ),
    }
}

pub const time_t = i32;

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";

    pub const GETCPU_SYM = "__vdso_getcpu";
    pub const GETCPU_VER = "LINUX_2.6";
};

pub const ARCH = struct {
    pub const SET_GS = 0x1001;
    pub const SET_FS = 0x1002;
    pub const GET_FS = 0x1003;
    pub const GET_GS = 0x1004;
};
