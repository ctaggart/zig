//! WASI mmap emulation backed by malloc.

const std = @import("std");
const builtin = @import("builtin");
const wasi = std.os.wasi;
const symbol = @import("../c.zig").symbol;

comptime {
    if (!builtin.target.isWasiLibC() and !builtin.is_test) @compileError("wasi_mman.zig is only for WASI");
    if (builtin.target.isWasiLibC()) {
        symbol(&mmap, "mmap");
        symbol(&munmap, "munmap");
        symbol(&mprotect, "mprotect");
        symbol(&msync, "msync");
    }
}

extern "c" fn malloc(size: usize) ?*anyopaque;
extern "c" fn free(ptr: ?*anyopaque) void;

const MAP_FAILED: usize = std.math.maxInt(usize);

const MAP_SHARED: c_int = 0x01;
const MAP_PRIVATE: c_int = 0x02;
const MAP_SHARED_VALIDATE: c_int = 0x03;
const MAP_TYPE: c_int = 0x0f;
const MAP_FIXED: c_int = 0x10;
const MAP_ANON: c_int = 0x20;
const MAP_NORESERVE: c_int = 0x4000;
const MAP_GROWSDOWN: c_int = 0x0100;
const MAP_HUGETLB: c_int = 0x40000;
const MAP_FIXED_NOREPLACE: c_int = 0x100000;

const PROT_NONE: c_int = 0;
const PROT_EXEC: c_int = 4;

const initial_mapping_capacity: usize = 8;

const Mapping = struct {
    ptr: [*]u8,
    length: usize,
};

var static_mappings: [initial_mapping_capacity]Mapping = undefined;
var dynamic_mappings: ?[*]Mapping = null;
var mapping_capacity: usize = initial_mapping_capacity;
var mapping_count: usize = 0;

fn mappings() [*]Mapping {
    return dynamic_mappings orelse static_mappings[0..].ptr;
}

fn setErrno(e: wasi.errno_t) void {
    std.c._errno().* = @intFromEnum(e);
}

fn mmapFailed() ?*anyopaque {
    return @ptrFromInt(MAP_FAILED);
}

fn fail(e: wasi.errno_t) ?*anyopaque {
    setErrno(e);
    return mmapFailed();
}

fn ensureMappingCapacity() bool {
    if (mapping_count < mapping_capacity) return true;
    const new_capacity = std.math.mul(usize, mapping_capacity, 2) catch return false;
    const bytes = std.math.mul(usize, @sizeOf(Mapping), new_capacity) catch return false;
    const mem = malloc(bytes) orelse return false;
    const new_mappings: [*]Mapping = @ptrCast(@alignCast(mem));
    @memcpy(new_mappings[0..mapping_count], mappings()[0..mapping_count]);
    if (dynamic_mappings) |old| free(@ptrCast(old));
    dynamic_mappings = new_mappings;
    mapping_capacity = new_capacity;
    return true;
}

fn addMapping(ptr: [*]u8, length: usize) bool {
    if (!ensureMappingCapacity()) return false;
    mappings()[mapping_count] = .{ .ptr = ptr, .length = length };
    mapping_count += 1;
    return true;
}

fn readFileIntoBuffer(fd: c_int, buf: [*]u8, length: usize, offset: i64) bool {
    if (fd < 0) {
        setErrno(.BADF);
        return false;
    }
    if (offset < 0) {
        setErrno(.INVAL);
        return false;
    }

    var remaining = length;
    var body = buf;
    var file_offset: wasi.filesize_t = @intCast(offset);
    while (remaining > 0) {
        var nread: usize = 0;
        const iov = wasi.iovec_t{ .base = body, .len = remaining };
        switch (wasi.fd_pread(@intCast(fd), @ptrCast(&iov), 1, file_offset, &nread)) {
            .SUCCESS => {
                if (nread == 0) return true;
                remaining -= nread;
                file_offset = std.math.add(wasi.filesize_t, file_offset, nread) catch {
                    setErrno(.INVAL);
                    return false;
                };
                body += nread;
            },
            .INTR => continue,
            else => |e| {
                setErrno(e);
                return false;
            },
        }
    }
    return true;
}

fn mmap(addr: ?*anyopaque, length: usize, prot: c_int, flags: c_int, fd: c_int, offset: i64) callconv(.c) ?*anyopaque {
    _ = addr;

    if ((flags & (MAP_PRIVATE | MAP_SHARED)) == 0 or
        (flags & MAP_FIXED) != 0 or
        (flags & MAP_TYPE) == MAP_SHARED_VALIDATE or
        (flags & MAP_NORESERVE) != 0 or
        (flags & MAP_GROWSDOWN) != 0 or
        (flags & MAP_HUGETLB) != 0 or
        (flags & MAP_FIXED_NOREPLACE) != 0)
    {
        if ((flags & MAP_FIXED) != 0) return fail(.OPNOTSUPP);
        return fail(.INVAL);
    }

    if (prot == PROT_NONE or (prot & PROT_EXEC) != 0) return fail(.INVAL);
    if (length == 0) return fail(.INVAL);

    const mem = malloc(length) orelse return fail(.NOMEM);
    const buf: [*]u8 = @ptrCast(mem);

    if ((flags & MAP_ANON) == 0) {
        if (!readFileIntoBuffer(fd, buf, length, offset)) {
            free(mem);
            return mmapFailed();
        }
    } else {
        @memset(buf[0..length], 0);
    }

    if (!addMapping(buf, length)) {
        free(mem);
        return fail(.NOMEM);
    }

    return @ptrCast(mem);
}

fn munmap(addr: ?*anyopaque, length: usize) callconv(.c) c_int {
    const mem = addr orelse {
        setErrno(.INVAL);
        return -1;
    };
    const ptr: [*]u8 = @ptrCast(mem);
    const table = mappings();
    var i: usize = 0;
    while (i < mapping_count) : (i += 1) {
        if (table[i].ptr == ptr) {
            if (table[i].length != length) {
                setErrno(.INVAL);
                return -1;
            }
            free(mem);
            mapping_count -= 1;
            if (i != mapping_count) table[i] = table[mapping_count];
            return 0;
        }
    }

    setErrno(.INVAL);
    return -1;
}

fn mprotect(addr: ?*anyopaque, length: usize, prot: c_int) callconv(.c) c_int {
    _ = addr;
    _ = length;
    _ = prot;
    return 0;
}

fn msync(addr: ?*anyopaque, length: usize, flags: c_int) callconv(.c) c_int {
    _ = addr;
    _ = length;
    _ = flags;
    return 0;
}

test "wasi_mman basic" {
    if (!builtin.target.isWasiLibC()) return error.SkipZigTest;
}
