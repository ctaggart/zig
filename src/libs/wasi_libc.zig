const std = @import("std");
const mem = std.mem;
const path = std.fs.path;

const Allocator = std.mem.Allocator;
const Compilation = @import("../Compilation.zig");
const build_options = @import("build_options");

pub const CrtFile = enum {
    crt1_reactor_o,
    crt1_command_o,
    libc_a,
};

pub fn execModelCrtFile(wasi_exec_model: std.builtin.WasiExecModel) CrtFile {
    return switch (wasi_exec_model) {
        .reactor => CrtFile.crt1_reactor_o,
        .command => CrtFile.crt1_command_o,
    };
}

pub fn execModelCrtFileFullName(wasi_exec_model: std.builtin.WasiExecModel) []const u8 {
    return switch (execModelCrtFile(wasi_exec_model)) {
        .crt1_reactor_o => "crt1-reactor.o",
        .crt1_command_o => "crt1-command.o",
        else => unreachable,
    };
}

/// TODO replace anyerror with explicit error set, recording user-friendly errors with
/// lockAndSetMiscFailure and returning error.AlreadyReported. see libcxx.zig for example.
pub fn buildCrtFile(comp: *Compilation, crt_file: CrtFile, prog_node: std.Progress.Node) anyerror!void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    switch (crt_file) {
        .crt1_reactor_o => {
            var args = std.array_list.Managed([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, .{});
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try comp.dirs.zig_lib.join(arena, &.{
                        "libc", try sanitize(arena, crt1_reactor_src_file),
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                },
            };

            return comp.build_crt_file("crt1-reactor", .Obj, .@"wasi crt1-reactor.o", prog_node, &files, .{});
        },
        .crt1_command_o => {
            var args = std.array_list.Managed([]const u8).init(arena);
            try addCCArgs(comp, arena, &args, .{});
            try addLibcBottomHalfIncludes(comp, arena, &args);

            var files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try comp.dirs.zig_lib.join(arena, &.{
                        "libc", try sanitize(arena, crt1_command_src_file),
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                },
            };

            return comp.build_crt_file("crt1-command", .Obj, .@"wasi crt1-command.o", prog_node, &files, .{});
        },
        .libc_a => {
            var libc_sources = std.array_list.Managed(Compilation.CSourceFile).init(arena);

            {
                // Compile libc-bottom-half.
                var args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
                try addLibcBottomHalfIncludes(comp, arena, &args);

                for (libc_bottom_half_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                // Compile libc-top-half.
                var args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
                try addLibcTopHalfIncludes(comp, arena, &args);

                for (libc_top_half_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            if (comp.getTarget().cpu.has(.wasm, .exception_handling)) {
                // Compile libsetjmp.
                var args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
                try addLibcTopHalfIncludes(comp, arena, &args);

                for (setjmp_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                // Compile libdl.
                var args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });
                try addLibcTopHalfIncludes(comp, arena, &args);

                for (emulated_dl_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                // Compile libwasi-emulated-process-clocks.
                var args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });

                for (emulated_process_clocks_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                // Compile libwasi-emulated-getpid.
                var args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });

                for (emulated_getpid_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                // Compile libwasi-emulated-mman.
                var args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &args, .{ .want_O3 = true });

                for (emulated_mman_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            }

            {
                // Compile libwasi-emulated-signal.
                var bottom_args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &bottom_args, .{ .want_O3 = true });

                for (emulated_signal_bottom_half_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = bottom_args.items,
                        .owner = undefined,
                    });
                }

                var top_args = std.array_list.Managed([]const u8).init(arena);
                try addCCArgs(comp, arena, &top_args, .{ .want_O3 = true });
                try addLibcTopHalfIncludes(comp, arena, &top_args);
                try top_args.append("-D_WASI_EMULATED_SIGNAL");

                for (emulated_signal_top_half_src_files) |file_path| {
                    try libc_sources.append(.{
                        .src_path = try comp.dirs.zig_lib.join(arena, &.{
                            "libc", try sanitize(arena, file_path),
                        }),
                        .extra_flags = top_args.items,
                        .owner = undefined,
                    });
                }
            }

            try comp.build_crt_file("c", .Lib, .@"wasi libc.a", prog_node, libc_sources.items, .{});
        },
    }
}

fn sanitize(arena: Allocator, file_path: []const u8) ![]const u8 {
    // TODO do this at comptime on the comptime data rather than at runtime
    // probably best to wait until self-hosted is done and our comptime execution
    // is faster and uses less memory.
    const out_path = if (path.sep != '/') blk: {
        const mutable_file_path = try arena.dupe(u8, file_path);
        for (mutable_file_path) |*c| {
            if (c.* == '/') {
                c.* = path.sep;
            }
        }
        break :blk mutable_file_path;
    } else file_path;
    return out_path;
}

const CCOptions = struct {
    want_O3: bool = false,
    no_strict_aliasing: bool = false,
};

fn addCCArgs(
    comp: *Compilation,
    arena: Allocator,
    args: *std.array_list.Managed([]const u8),
    options: CCOptions,
) error{OutOfMemory}!void {
    const target = comp.getTarget();
    const arch_name = std.zig.target.muslArchNameHeaders(target.cpu.arch);
    const os_name = @tagName(target.os.tag);
    const triple = try std.fmt.allocPrint(arena, "{s}-{s}-musl", .{ arch_name, os_name });
    const o_arg = if (options.want_O3) "-O3" else "-Os";

    try args.appendSlice(&[_][]const u8{
        "-std=gnu17",
        "-fno-trapping-math",
        "-w", // ignore all warnings

        o_arg,

        "-mthread-model",
        "single",

        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-bottom-half",
            "cloudlibc",
            "src",
        }),

        "-isystem",
        try comp.dirs.zig_lib.join(arena, &.{ "libc", "include", triple }),
        "-isystem",
        try comp.dirs.zig_lib.join(arena, &.{ "libc", "include", "generic-musl" }),

        "-DBULK_MEMORY_THRESHOLD=32",
    });

    if (options.no_strict_aliasing) {
        try args.appendSlice(&[_][]const u8{"-fno-strict-aliasing"});
    }
}

fn addLibcBottomHalfIncludes(
    comp: *Compilation,
    arena: Allocator,
    args: *std.array_list.Managed([]const u8),
) error{OutOfMemory}!void {
    try args.appendSlice(&[_][]const u8{
        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-bottom-half",
            "headers",
            "private",
        }),

        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-bottom-half",
            "cloudlibc",
            "src",
            "include",
        }),

        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-bottom-half",
            "cloudlibc",
            "src",
        }),

        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "src",
            "include",
        }),
        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "musl",
            "src",
            "include",
        }),
        "-I",

        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "src",
            "internal",
        }),
        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "musl",
            "src",
            "internal",
        }),
    });
}

fn addLibcTopHalfIncludes(
    comp: *Compilation,
    arena: Allocator,
    args: *std.array_list.Managed([]const u8),
) error{OutOfMemory}!void {
    try args.appendSlice(&[_][]const u8{
        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "src",
            "include",
        }),
        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "musl",
            "src",
            "include",
        }),

        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "src",
            "internal",
        }),
        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "musl",
            "src",
            "internal",
        }),

        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-top-half",
            "musl",
            "arch",
            "wasm32",
        }),
        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "musl",
            "arch",
            "generic",
        }),

        "-I",
        try comp.dirs.zig_lib.join(arena, &.{
            "libc",
            "wasi",
            "libc-top-half",
            "headers",
            "private",
        }),
    });
}

// All former cloudlibc C sources (dirent, fcntl, poll, select, socket, …) have
// been migrated to Zig in lib/c/wasi_cloudlibc.zig.  The corresponding C files
// were deleted from lib/libc/wasi/libc-bottom-half/cloudlibc/src/libc/, so this
// list must stay empty.  See #484, #486, #506.
const libc_bottom_half_src_files = [_][]const u8{};

// All remaining stdio top-half sources have been migrated to Zig in
// lib/c/stdio.zig and imported for WASI by lib/c/wasi_stdio.zig.
const libc_top_half_src_files = [_][]const u8{};

const crt1_command_src_file = "wasi/libc-bottom-half/crt/crt1-command.c";
const crt1_reactor_src_file = "wasi/libc-bottom-half/crt/crt1-reactor.c";

const setjmp_src_files = &[_][]const u8{
    "wasi/libc-top-half/musl/src/setjmp/wasm32/rt.c",
};

const emulated_dl_src_files = &[_][]const u8{
    "wasi/libc-top-half/musl/src/misc/dl.c",
};

const emulated_process_clocks_src_files = &[_][]const u8{
    "wasi/libc-bottom-half/clocks/clock.c",
    "wasi/libc-bottom-half/clocks/getrusage.c",
    "wasi/libc-bottom-half/clocks/times.c",
};

const emulated_getpid_src_files = &[_][]const u8{
    "wasi/libc-bottom-half/getpid/getpid.c",
};

const emulated_mman_src_files = &[_][]const u8{
    "wasi/libc-bottom-half/mman/mman.c",
};

const emulated_signal_bottom_half_src_files = &[_][]const u8{
    "wasi/libc-bottom-half/signal/signal.c",
};

const emulated_signal_top_half_src_files = &[_][]const u8{
    "musl/src/signal/psignal.c",
};
