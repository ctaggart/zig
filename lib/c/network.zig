const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

const protoent = extern struct {
    p_name: [*:0]u8,
    p_aliases: *?[*:0]u8,
    p_proto: c_int,
};

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&endprotoent_impl, "endprotoent");
        symbol(&setprotoent_impl, "setprotoent");
        symbol(&getprotoent_impl, "getprotoent");
        symbol(&getprotobyname_impl, "getprotobyname");
        symbol(&getprotobynumber_impl, "getprotobynumber");
    }
}

// Protocol table: each entry is [protocol_number, name_bytes..., 0]
const protos = "\x00ip\x00" ++
    "\x01icmp\x00" ++
    "\x02igmp\x00" ++
    "\x03ggp\x00" ++
    "\x04ipencap\x00" ++
    "\x05st\x00" ++
    "\x06tcp\x00" ++
    "\x08egp\x00" ++
    "\x0cpup\x00" ++
    "\x11udp\x00" ++
    "\x14hmp\x00" ++
    "\x16xns-idp\x00" ++
    "\x1brdp\x00" ++
    "\x1diso-tp4\x00" ++
    "\x24xtp\x00" ++
    "\x25ddp\x00" ++
    "\x26idpr-cmtp\x00" ++
    "\x29ipv6\x00" ++
    "\x2bipv6-route\x00" ++
    "\x2cipv6-frag\x00" ++
    "\x2didrp\x00" ++
    "\x2ersvp\x00" ++
    "\x2fgre\x00" ++
    "\x32esp\x00" ++
    "\x33ah\x00" ++
    "\x39skip\x00" ++
    "\x3aipv6-icmp\x00" ++
    "\x3bipv6-nonxt\x00" ++
    "\x3cipv6-opts\x00" ++
    "\x49rspf\x00" ++
    "\x51vmtp\x00" ++
    "\x59ospf\x00" ++
    "\x5eipip\x00" ++
    "\x62encap\x00" ++
    "\x67pim\x00" ++
    "\xffraw\x00";

const State = struct {
    var idx: usize = 0;
    var p: protoent = undefined;
    var aliases: ?[*:0]u8 = null;
};

fn endprotoent_impl() callconv(.c) void {
    State.idx = 0;
}

fn setprotoent_impl(_: c_int) callconv(.c) void {
    State.idx = 0;
}

fn getprotoent_impl() callconv(.c) ?*protoent {
    if (State.idx >= protos.len) return null;
    State.p.p_proto = @intCast(protos[State.idx]);
    const name_start = State.idx + 1;
    // Find the null terminator for this name
    var end = name_start;
    while (end < protos.len and protos[end] != 0) : (end += 1) {}
    State.p.p_name = @ptrCast(@constCast(protos[name_start..end :0].ptr));
    State.p.p_aliases = @ptrCast(&State.aliases);
    State.idx = end + 1;
    return &State.p;
}

fn getprotobyname_impl(name: [*:0]const u8) callconv(.c) ?*protoent {
    State.idx = 0;
    while (getprotoent_impl()) |p| {
        if (std.mem.orderZ(u8, p.p_name, name) == .eq) return p;
    }
    return null;
}

fn getprotobynumber_impl(num: c_int) callconv(.c) ?*protoent {
    State.idx = 0;
    while (getprotoent_impl()) |p| {
        if (p.p_proto == num) return p;
    }
    return null;
}

test getprotobyname_impl {
    const tcp = getprotobyname_impl("tcp");
    try std.testing.expect(tcp != null);
    try std.testing.expectEqual(@as(c_int, 6), tcp.?.p_proto);

    const udp = getprotobyname_impl("udp");
    try std.testing.expect(udp != null);
    try std.testing.expectEqual(@as(c_int, 17), udp.?.p_proto);

    try std.testing.expect(getprotobyname_impl("nonexistent") == null);
}

test getprotobynumber_impl {
    const tcp = getprotobynumber_impl(6);
    try std.testing.expect(tcp != null);
    try std.testing.expectEqualStrings("tcp", std.mem.sliceTo(tcp.?.p_name, 0));

    try std.testing.expect(getprotobynumber_impl(999) == null);
}
