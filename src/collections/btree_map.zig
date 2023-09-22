const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

pub fn BTreeMap(comptime K: type, comptime V: type, comptime N: usize) type {
    return struct {
        alloc: Allocator,
        root:  ?*Node,

        const Self = @This();

        const Node = struct {
            keys:     [N-1]K    = undefined,
            values:   [N-1]V    = undefined,
            children: ?[N]*Node = undefined,
            len:      usize     = 0,

            pub fn insert(self: *Node, key: K, value: V) !void {
                if (self.len == N-1) {
                    // split
                } else {
                    self.keys  [self.len] = key;
                    self.values[self.len] = value;
                    self.len += 1;
                }
            }

            /// insert a key-value pair into the tree
            /// nodes will be split aggressively while traversing the tree
            fn insert_aggressive(root: *Node, key: K, value: V) !void {
                // not a leave node
                if (root.children) |children| {
                    const child: *Node = blk: {
                        for (root.keys[0..root.len], children[0..root.len]) |child_key, child| {
                            if (key < child_key) {
                                break :blk child;
                            }
                        }
                        break :blk children[root.len];
                    };

                    if (child.len == N - 1) {
                        // split
                    } else {
                        child.insert_assuming_capacity(key, value);
                    }
                }
                // leave node
                else {
                    root.insert_assuming_capacity(key, value);
                }
            }

            fn insert_assuming_capacity(self: *Node, key: K, value: V) void {
                assert(self.len < N - 1);

                // find slot
                var i: usize = 0;
                while (i < self.len) : (i += 1) {
                    if (key < self.keys[i]) { break; }
                }

                // shift right
                var n = self.len -| 2;
                while (n > i) : (n -= 1) {
                    self.keys  [n] = self.keys  [n - 1];
                    self.values[n] = self.values[n - 1];
                    // NOTE(lm): in order to insert, this must be a leave node, children must be *null*
                }

                // insert
                self.keys  [i] = key;
                self.values[i] = value;
                self.len += 1;
            }

            // TODO(lm): implement
            fn split(self: *Node, alloc: Allocator) !.{ K, V, *Node } {
                assert(self.len > 1);
                const mid_idx = self.len / 2;
                const new_node_len = self.len - mid_idx - 1;

                if (new_node_len > 0) {
                    const new_node = try alloc.create(Node);
                    new_node.* = .{};

                    // copy everything to the right into the new node
                    new_node.len = new_node_len;
                    @memcpy(new_node.keys  [0..new_node_len], self.keys  [new_node_len..self.len]);
                    @memcpy(new_node.values[0..new_node_len], self.values[new_node_len..self.len]);
                }

                @panic("not implemented");
            }

            pub fn traverse_pre_order(self: @This(), ctx: anytype, func: fn (ctx: @TypeOf(ctx), *const K, *const V) void) void {
                if (self.len == 0) { return; }

                for (self.keys[0..self.len], self.values[0..self.len], 0..) |*key, *value, i| {
                    if (self.children) |children| {
                        children[i].traverse_pre_order(ctx, func);
                    }
                    func(ctx, key, value);
                }

                if (self.children) |children| {
                    children[self.len].traverse_pre_order(ctx, func);
                }
            }
        };

        pub fn init(alloc: Allocator) Self {
            return .{
                .alloc = alloc,
                .root  = null,
            };
        }

        pub fn deinit(self: *Self) void {
            // TODO(lm): implement

            if (self.root) |root| {
                self.alloc.destroy(root);
            }
        }

        pub fn insert(self: *Self, key: K, value: V) !void {
            if (self.root == null) {
                self.root = try self.alloc.create(Node);
                self.root.?.* = .{};
            }

            try self.root.?.insert_aggressive(key, value);
        }

        pub fn traverse_pre_order(self: @This(), ctx: anytype, func: fn (ctx: @TypeOf(ctx), *const K, *const V) void) void {
            if (self.root) |root| {
                root.traverse_pre_order(ctx, func);
            }
        }
    };
}


fn collect_map(collector: *std.ArrayList(usize), key: *const usize, value: *const []const u8) void {
    collector.append(key.*) catch unreachable;
    std.debug.print("TEST: {d} - {s}\n", .{key.*, value.*});
}

test "basic_usage" {
    const testing = std.testing;

    const TestMap = BTreeMap(usize, []const u8, 3);
    var map = TestMap.init(testing.allocator);
    defer map.deinit();

    try map.insert(10, "a");
    var collector = std.ArrayList(usize).init(testing.allocator);
    defer collector.deinit();
    map.traverse_pre_order(&collector, collect_map);

    try testing.expectEqualSlices(usize, collector.items, &[_]usize {10});
}


