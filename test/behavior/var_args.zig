const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

fn add(args: anytype) i32 {
    var sum = @as(i32, 0);
    {
        comptime var i: usize = 0;
        inline while (i < args.len) : (i += 1) {
            sum += args[i];
        }
    }
    return sum;
}

test "add arbitrary args" {
    try expect(add(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3), @as(i32, 4) }) == 10);
    try expect(add(.{@as(i32, 1234)}) == 1234);
    try expect(add(.{}) == 0);
}

fn readFirstVarArg(args: anytype) void {
    _ = args[0];
}

test "send void arg to var args" {
    readFirstVarArg(.{{}});
}

test "pass args directly" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(addSomeStuff(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3), @as(i32, 4) }) == 10);
    try expect(addSomeStuff(.{@as(i32, 1234)}) == 1234);
    try expect(addSomeStuff(.{}) == 0);
}

fn addSomeStuff(args: anytype) i32 {
    return add(args);
}

test "runtime parameter before var args" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect((try extraFn(10, .{})) == 0);
    try expect((try extraFn(10, .{false})) == 1);
    try expect((try extraFn(10, .{ false, true })) == 2);

    comptime {
        try expect((try extraFn(10, .{})) == 0);
        try expect((try extraFn(10, .{false})) == 1);
        try expect((try extraFn(10, .{ false, true })) == 2);
    }
}

fn extraFn(extra: u32, args: anytype) !usize {
    _ = extra;
    if (args.len >= 1) {
        try expect(args[0] == false);
    }
    if (args.len >= 2) {
        try expect(args[1] == true);
    }
    return args.len;
}

const foos = [_]fn (anytype) bool{
    foo1,
    foo2,
};

fn foo1(args: anytype) bool {
    _ = args;
    return true;
}
fn foo2(args: anytype) bool {
    _ = args;
    return false;
}

test "array of var args functions" {
    try expect(foos[0](.{}));
    try expect(!foos[1](.{}));
}

test "pass zero length array to var args param" {
    doNothingWithFirstArg(.{""});
}

fn doNothingWithFirstArg(args: anytype) void {
    _ = args[0];
}

test "simple variadic function" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.cpu.arch == .s390x and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21350
    if (builtin.cpu.arch.isSPARC() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/23718
    if (builtin.cpu.arch.isRISCV() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/25064

    const S = struct {
        fn simple(...) callconv(.c) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            return @cVaArg(&ap, c_int);
        }

        fn compatible(_: c_int, ...) callconv(.c) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            return @cVaArg(&ap, c_int);
        }

        fn add(count: c_int, ...) callconv(.c) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            var i: usize = 0;
            var sum: c_int = 0;
            while (i < count) : (i += 1) {
                sum += @cVaArg(&ap, c_int);
            }
            return sum;
        }
    };

    if (builtin.zig_backend != .stage2_c) {
        // pre C23 doesn't support varargs without a preceding runtime arg.
        try std.testing.expectEqual(@as(c_int, 0), S.simple(@as(c_int, 0)));
        try std.testing.expectEqual(@as(c_int, 1024), S.simple(@as(c_int, 1024)));
    }
    try std.testing.expectEqual(@as(c_int, 0), S.compatible(undefined, @as(c_int, 0)));
    try std.testing.expectEqual(@as(c_int, 1024), S.compatible(undefined, @as(c_int, 1024)));
    try std.testing.expectEqual(@as(c_int, 0), S.add(0));
    try std.testing.expectEqual(@as(c_int, 1), S.add(1, @as(c_int, 1)));
    try std.testing.expectEqual(@as(c_int, 3), S.add(2, @as(c_int, 1), @as(c_int, 2)));

    {
        // Test type coercion of a var args argument.
        // Originally reported at https://github.com/ziglang/zig/issues/16197
        var runtime: bool = true;
        var a: i32 = 1;
        var b: i32 = 2;
        _ = .{ &runtime, &a, &b };
        try expect(1 == S.add(1, if (runtime) a else b));
    }
}

test "coerce reference to var arg" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.cpu.arch == .s390x and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21350

    const S = struct {
        fn addPtr(count: c_int, ...) callconv(.c) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            var i: usize = 0;
            var sum: c_int = 0;
            while (i < count) : (i += 1) {
                sum += @cVaArg(&ap, *c_int).*;
            }
            return sum;
        }
    };

    // Originally reported at https://github.com/ziglang/zig/issues/17494
    var a: i32 = 12;
    var b: i32 = 34;
    try expect(46 == S.addPtr(2, &a, &b));
}

test "variadic functions" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.cpu.arch == .s390x and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21350
    if (builtin.cpu.arch.isSPARC() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/23718
    if (builtin.cpu.arch.isRISCV() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/25064

    const S = struct {
        fn printf(buffer: [*]u8, format: [*:0]const u8, ...) callconv(.c) void {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            vprintf(buffer, format, &ap);
        }

        fn vprintf(buffer: [*]u8, format: [*:0]const u8, ap: *std.builtin.VaList) callconv(.c) void {
            var i: usize = 0;
            for (format[0..3]) |byte| switch (byte) {
                's' => {
                    const arg = @cVaArg(ap, [*:0]const u8);
                    buffer[i..][0..5].* = arg[0..5].*;
                    i += 5;
                },
                'd' => {
                    const arg = @cVaArg(ap, c_int);
                    switch (arg) {
                        1 => {
                            buffer[i] = '1';
                            i += 1;
                        },
                        5 => {
                            buffer[i] = '5';
                            i += 1;
                        },
                        else => unreachable,
                    }
                },
                else => unreachable,
            };
        }
    };

    var buffer: [7]u8 = undefined;
    S.printf(&buffer, "dsd", @as(c_int, 1), @as([*:0]const u8, "hello"), @as(c_int, 5));
    try expect(std.mem.eql(u8, &buffer, "1hello5"));
}

test "copy VaList" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.cpu.arch == .s390x and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21350
    if (builtin.cpu.arch.isSPARC() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/23718
    if (builtin.cpu.arch.isRISCV() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/25064

    const S = struct {
        fn add(count: c_int, ...) callconv(.c) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            var copy = @cVaCopy(&ap);
            defer @cVaEnd(&copy);
            var i: usize = 0;
            var sum: c_int = 0;
            while (i < count) : (i += 1) {
                sum += @cVaArg(&ap, c_int);
                sum += @cVaArg(&copy, c_int) * 2;
            }
            return sum;
        }
    };

    try std.testing.expectEqual(@as(c_int, 0), S.add(0));
    try std.testing.expectEqual(@as(c_int, 3), S.add(1, @as(c_int, 1)));
    try std.testing.expectEqual(@as(c_int, 9), S.add(2, @as(c_int, 1), @as(c_int, 2)));
}

test "unused VaList arg" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.cpu.arch == .s390x and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21350
    if (builtin.cpu.arch.isSPARC() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/23718
    if (builtin.cpu.arch.isRISCV() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/25064

    const S = struct {
        fn thirdArg(dummy: c_int, ...) callconv(.c) c_int {
            _ = dummy;

            var ap = @cVaStart();
            defer @cVaEnd(&ap);

            _ = @cVaArg(&ap, c_int);
            return @cVaArg(&ap, c_int);
        }
    };
    const x = S.thirdArg(0, @as(c_int, 1), @as(c_int, 2));
    try std.testing.expectEqual(@as(c_int, 2), x);
}

test "variadic function with GP register spill (aarch64 #251)" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.cpu.arch == .s390x and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21350
    if (builtin.cpu.arch.isSPARC() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/23718
    if (builtin.cpu.arch.isRISCV() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/25064

    // AAPCS64 has 8 GP argument registers (x0-x7). With `count` consuming x0,
    // passing 10 variadic c_long forces the last ~3 values to spill onto the
    // stack, exercising both the in-regs and on-stack paths in the manually
    // lowered va_arg (see ctaggart/zig#251).
    const S = struct {
        fn sum(count: c_int, ...) callconv(.c) c_long {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            var i: c_int = 0;
            var acc: c_long = 0;
            while (i < count) : (i += 1) acc += @cVaArg(&ap, c_long);
            return acc;
        }
    };
    const total = S.sum(
        10,
        @as(c_long, 1),
        @as(c_long, 2),
        @as(c_long, 3),
        @as(c_long, 4),
        @as(c_long, 5),
        @as(c_long, 6),
        @as(c_long, 7),
        @as(c_long, 8),
        @as(c_long, 9),
        @as(c_long, 10),
    );
    try std.testing.expectEqual(@as(c_long, 55), total);
}

test "floating point VaList args" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/16961

    // Float register arguments are handled specially on cc == .x86_64_win, so it's important that we test all 4 slots,
    // and pre-C23 doesn't allow a variadic function without at least one non-variadic argument.
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const S = struct {
        fn proxy(...) callconv(.c) void {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);

            var out_f32: [3]f32 = undefined;
            var out_f64: [3]f64 = undefined;
            out_f32[0] = @cVaArg(&ap, f32);
            out_f64[0] = @cVaArg(&ap, f64);
            out_f32[1] = @cVaArg(&ap, f32);
            out_f64[1] = @cVaArg(&ap, f64);
            out_f32[2] = @cVaArg(&ap, f32);
            out_f64[2] = @cVaArg(&ap, f64);
            @cVaArg(&ap, *[3]f32).* = out_f32;
            @cVaArg(&ap, *[3]f64).* = out_f64;
        }
    };

    const expected_f32: []const f32 = &.{ 1000, std.math.floatMax(f32), std.math.floatMin(f32) };
    const expected_f64: []const f64 = &.{ 2000, std.math.floatMax(f64), std.math.floatMin(f64) };
    var actual_f32: [3]f32 = undefined;
    var actual_f64: [3]f64 = undefined;
    S.proxy(
        expected_f32[0],
        expected_f64[0],
        expected_f32[1],
        expected_f64[1],
        expected_f32[2],
        expected_f64[2],
        &actual_f32,
        &actual_f64,
    );

    try std.testing.expectEqualSlices(f32, expected_f32, &actual_f32);
    try std.testing.expectEqualSlices(f64, expected_f64, &actual_f64);
}

test "variadic function with indirect aggregate args (Win64)" {
    // Win64 variadic ABI passes arguments whose size is > 8 bytes or not a
    // power-of-two indirectly (slot contains a pointer to the real value).
    // SysV has different rules but should also handle these via classifyV
    // + va_arg. This test exercises both the direct and indirect slot
    // arithmetic. See https://github.com/ctaggart/zig/issues/247.
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO self-hosted x86_64 backend crashes on indirect variadic aggregates (pre-existing)
    if (builtin.zig_backend == .stage2_llvm and !builtin.os.tag.isDarwin() and builtin.cpu.arch.isAARCH64()) {
        // https://github.com/ziglang/zig/issues/14096
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch == .s390x and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.cpu.arch.isSPARC() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.cpu.arch.isRISCV() and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    // aarch64-windows has a separate va_arg ABI that this fix does not address.
    if (builtin.cpu.arch.isAARCH64() and builtin.os.tag == .windows and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    const Odd = extern struct { a: u8, b: u8, c: u8 }; // 3 bytes, indirect on Win64
    const Eight = extern struct { x: u32, y: u32 }; // 8 bytes, direct on Win64
    const Big = extern struct { a: u64, b: u64, c: u64 }; // 24 bytes, indirect on Win64

    const S = struct {
        fn check(count: c_int, ...) callconv(.c) c_int {
            var ap = @cVaStart();
            defer @cVaEnd(&ap);
            var total: c_int = 0;
            var i: c_int = 0;
            while (i < count) : (i += 1) {
                const tag = @cVaArg(&ap, c_int);
                switch (tag) {
                    1 => { // c_int
                        total += @cVaArg(&ap, c_int);
                    },
                    2 => { // Odd
                        const v = @cVaArg(&ap, Odd);
                        total += @as(c_int, v.a) + @as(c_int, v.b) + @as(c_int, v.c);
                    },
                    3 => { // Eight
                        const v = @cVaArg(&ap, Eight);
                        total += @as(c_int, @intCast(v.x + v.y));
                    },
                    4 => { // Big
                        const v = @cVaArg(&ap, Big);
                        total += @as(c_int, @intCast(v.a + v.b + v.c));
                    },
                    else => unreachable,
                }
            }
            return total;
        }
    };

    const odd: Odd = .{ .a = 1, .b = 2, .c = 3 }; // 6
    const eight: Eight = .{ .x = 10, .y = 20 }; // 30
    const big: Big = .{ .a = 100, .b = 200, .c = 300 }; // 600
    const got = S.check(
        4,
        @as(c_int, 1), @as(c_int, 42), // direct scalar: 42
        @as(c_int, 2), odd, // indirect 3-byte: 6
        @as(c_int, 3), eight, // direct 8-byte: 30
        @as(c_int, 4), big, // indirect 24-byte: 600
    );
    try std.testing.expectEqual(@as(c_int, 42 + 6 + 30 + 600), got);
}
