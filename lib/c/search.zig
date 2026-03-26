const std = @import("std");
const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&insque, "insque");
        symbol(&remque, "remque");
        symbol(&lsearch, "lsearch");
        symbol(&lfind, "lfind");
    }
}

const Node = extern struct {
    next: ?*Node,
    prev: ?*Node,
};

fn insque(element: *anyopaque, pred: ?*anyopaque) callconv(.c) void {
    const e: *Node = @ptrCast(@alignCast(element));

    if (pred) |p_ptr| {
        const p: *Node = @ptrCast(@alignCast(p_ptr));
        e.next = p.next;
        e.prev = p;
        p.next = e;

        if (e.next) |next| {
            next.prev = e;
        }
    } else {
        e.next = null;
        e.prev = null;
    }
}

fn remque(element: *anyopaque) callconv(.c) void {
    const e: *Node = @ptrCast(@alignCast(element));

    if (e.next) |next| next.prev = e.prev;
    if (e.prev) |prev| prev.next = e.next;
}

const CompareFn = *const fn (*const anyopaque, *const anyopaque) callconv(.c) c_int;

fn lsearch(key: *const anyopaque, base: *anyopaque, nelp: *usize, width: usize, compar: CompareFn) callconv(.c) *anyopaque {
    const p: [*]u8 = @ptrCast(base);
    const n = nelp.*;
    for (0..n) |i| {
        const elem = p + i * width;
        if (compar(key, elem) == 0) return elem;
    }
    nelp.* = n + 1;
    const dst = p + n * width;
    @memcpy(dst[0..width], @as([*]const u8, @ptrCast(key))[0..width]);
    return dst;
}

fn lfind(key: *const anyopaque, base: *const anyopaque, nelp: *const usize, width: usize, compar: CompareFn) callconv(.c) ?*anyopaque {
    const p: [*]const u8 = @ptrCast(base);
    for (0..nelp.*) |i| {
        const elem = p + i * width;
        if (compar(key, elem) == 0) return @constCast(elem);
    }
    return null;
}

test lsearch {
    const Cmp = struct {
        fn compare(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
            const x: *const i32 = @ptrCast(@alignCast(a));
            const y: *const i32 = @ptrCast(@alignCast(b));
            return if (x.* == y.*) 0 else 1;
        }
    };
    var arr = [_]i32{ 10, 20, 30, 0 };
    var n: usize = 3;
    const key: i32 = 20;
    const found = lsearch(&key, &arr, &n, @sizeOf(i32), Cmp.compare);
    try std.testing.expectEqual(@as(*const i32, @ptrCast(@alignCast(found))).*, 20);
    try std.testing.expectEqual(n, 3);

    const missing: i32 = 40;
    _ = lsearch(&missing, &arr, &n, @sizeOf(i32), Cmp.compare);
    try std.testing.expectEqual(n, 4);
    try std.testing.expectEqual(arr[3], 40);
}

test lfind {
    const Cmp = struct {
        fn compare(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
            const x: *const i32 = @ptrCast(@alignCast(a));
            const y: *const i32 = @ptrCast(@alignCast(b));
            return if (x.* == y.*) 0 else 1;
        }
    };
    const arr = [_]i32{ 10, 20, 30 };
    var n: usize = 3;
    const key: i32 = 20;
    const found = lfind(&key, &arr, &n, @sizeOf(i32), Cmp.compare);
    try std.testing.expect(found != null);

    const missing: i32 = 99;
    try std.testing.expectEqual(lfind(&missing, &arr, &n, @sizeOf(i32), Cmp.compare), null);
}

test "insque and remque" {
    var first = Node{ .next = null, .prev = null };
    var second = Node{ .next = null, .prev = null };
    var third = Node{ .next = null, .prev = null };

    insque(&first, null);
    try std.testing.expectEqual(@as(?*Node, null), first.next);
    try std.testing.expectEqual(@as(?*Node, null), first.prev);

    insque(&second, &first);
    try std.testing.expectEqual(@as(?*Node, &second), first.next);
    try std.testing.expectEqual(@as(?*Node, &first), second.prev);

    insque(&third, &first);
    try std.testing.expectEqual(@as(?*Node, &third), first.next);
    try std.testing.expectEqual(@as(?*Node, &second), third.next);
    try std.testing.expectEqual(@as(?*Node, &first), third.prev);
    try std.testing.expectEqual(@as(?*Node, &third), second.prev);

    remque(&third);
    try std.testing.expectEqual(@as(?*Node, &second), first.next);
    try std.testing.expectEqual(@as(?*Node, &first), second.prev);

    remque(&second);
    try std.testing.expectEqual(@as(?*Node, null), first.next);
}
