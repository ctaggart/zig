const std = @import("std");
const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&insque, "insque");
        symbol(&remque, "remque");
        symbol(&tfind, "tfind");
        symbol(&twalk, "twalk");
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

// AVL tree node structure matching musl's struct node in tsearch.h
const TreeNode = extern struct {
    key: *const anyopaque,
    children: [2]*anyopaque,
    h: c_int,
};

const CmpFn = *const fn (*const anyopaque, *const anyopaque) callconv(.c) c_int;

fn tfind(key: *const anyopaque, rootp: ?*const ?*anyopaque, cmp: CmpFn) callconv(.c) ?*anyopaque {
    const rp = rootp orelse return null;
    var n: ?*TreeNode = @ptrCast(@alignCast(rp.*));
    while (n) |node| {
        const c = cmp(key, node.key);
        if (c == 0) return @ptrCast(node);
        n = @ptrCast(@alignCast(node.children[@intFromBool(c > 0)]));
    }
    return null;
}

const VISIT = enum(c_int) { preorder, postorder, endorder, leaf };
const ActionFn = *const fn (*const anyopaque, VISIT, c_int) callconv(.c) void;

fn walk(r: ?*const TreeNode, action: ActionFn, d: c_int) void {
    const node = r orelse return;
    if (node.h == 1) {
        action(node, .leaf, d);
    } else {
        action(node, .preorder, d);
        walk(@ptrCast(@alignCast(node.children[0])), action, d + 1);
        action(node, .postorder, d);
        walk(@ptrCast(@alignCast(node.children[1])), action, d + 1);
        action(node, .endorder, d);
    }
}

fn twalk(root: ?*const anyopaque, action: ActionFn) callconv(.c) void {
    walk(@ptrCast(@alignCast(root)), action, 0);
}
