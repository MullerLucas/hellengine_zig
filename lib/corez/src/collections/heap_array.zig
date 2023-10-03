const std = @import("std");

pub fn HeapArray(comptime T: type, comptime n: usize, comptime is_min: bool) type {
    return struct {
        items: [n]T = undefined,
        len:   usize = 0,

        const Self = @This();
        const capacity = n;

        pub const Error = error {
            capacity_exceeded,
        };

        pub inline fn is_full(self: *const Self) bool {
            return self.len == capacity;
        }

        pub inline fn is_empty(self: *const Self) bool {
            return self.len == 0;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.is_empty()) {
                return null;
            }
            return self.items[0];
        }

        pub fn pop(self: *Self) ?T {
            if (self.is_empty()) {
                return null;
            }

            const result = self.items[0];
            self.items[0] = self.items[self.len - 1];
            self.len -= 1;
            self.heapify_down();
            return result;
        }

        pub fn push(self: *Self, item: T) !void {
            if (self.is_full()) {
                return Error.capacity_exceeded;
            }

            self.items[self.len] = item;
            self.len += 1;
            self.heapify_up();
        }

        pub fn print(self: *const Self) void {
            if (self.len == 0) {
                std.debug.print("empty\n", .{});
                return;
            }

            for (0..self.len) |idx| {
                std.debug.print("[{d}] => {any}\n", .{idx, self.items[idx]});
            }
        }

        fn node_left_child_idx (parent_idx: usize) usize { return 2 * parent_idx + 1; }
        fn node_right_child_idx(parent_idx: usize) usize { return 2 * parent_idx + 2; }
        fn node_parent_idx     (child_idx: usize)  usize { return (child_idx - 1) / 2 ; }

        fn node_has_left_child (self: *const Self, parent_idx: usize) bool { return Self.node_left_child_idx (parent_idx) < self.len; }
        fn node_has_right_child(self: *const Self, parent_idx: usize) bool { return Self.node_right_child_idx(parent_idx) < self.len; }
        fn node_has_parent     (_: *const Self, child_idx: usize) bool {
            if (child_idx == 0) {
                return false;
            }
            return true;
        }

        fn node_left_child (self: *const Self, parent_idx: usize) T { return self.items[Self.node_left_child_idx(parent_idx)]; }
        fn node_right_child(self: *const Self, parent_idx: usize) T { return self.items[Self.node_right_child_idx(parent_idx)]; }
        fn node_parent     (self: *const Self, child_idx: usize)  T { return self.items[Self.node_parent_idx(child_idx)]; }

        fn swap_nodes(self: *Self, a_idx: usize, b_idx: usize) void {
            const tmp = self.items[a_idx];
            self.items[a_idx] = self.items[b_idx];
            self.items[b_idx] = tmp;
        }

        inline fn compare_up(self: *const Self, a_idx: usize, b_idx: usize) bool {
            if (is_min) {
                return self.items[a_idx] > self.items[b_idx];
            } else {
                return self.items[a_idx] < self.items[b_idx];
            }
        }

        inline fn compare_down(self: *const Self, a_idx: usize, b_idx: usize) bool {
            if (is_min) {
                return self.items[a_idx] < self.items[b_idx];
            } else {
                return self.items[a_idx] > self.items[b_idx];
            }
        }

        fn heapify_up(self: *Self) void {
            var idx = self.len - 1;

            while (self.node_has_parent(idx)) {
                if (self.compare_up(idx, Self.node_parent_idx(idx))) {
                    break;
                }

                self.swap_nodes(Self.node_parent_idx(idx), idx);
                idx = Self.node_parent_idx(idx);
            }
        }

        fn heapify_down(self: *Self) void {
            var idx: usize = 0;

            while (self.node_has_left_child(idx)) {
                const closest_child_idx = if (self.node_has_right_child(idx)
                                          and self.compare_down(Self.node_right_child_idx(idx), Self.node_left_child_idx(idx)))
                            Self.node_right_child_idx(idx)
                        else
                            Self.node_left_child_idx(idx);

                if (self.compare_down(idx, closest_child_idx)) {
                    break;
                }

                self.swap_nodes(idx, closest_child_idx);
                idx = closest_child_idx;
            }
        }
    };
}

// ----------------------------------------------

test "basic_usage_min_heap" {
    const testing = std.testing;

    const MinHeap = HeapArray(u32, 8, true);

    var h1: MinHeap = .{};
    try testing.expectEqual(@as(?u32, null), h1.peek());
    try testing.expectEqual(@as(?u32, null), h1.pop());

    try h1.push(10);
    try testing.expectEqual(@as(?u32, 10), h1.peek());
    try testing.expectEqual(@as(?u32, 10), h1.pop());

    try h1.push(10);
    try h1.push(20);
    try h1.push(3);
    try h1.push(10);
    try h1.push(5);
    try h1.push(100);
    try h1.push(70);
    try h1.push(1);

    try testing.expectError(MinHeap.Error.capacity_exceeded, h1.push(23));

    try testing.expectEqual(@as(?u32, 1),    h1.pop());
    try testing.expectEqual(@as(?u32, 3),    h1.pop());
    try testing.expectEqual(@as(?u32, 5),    h1.pop());
    try testing.expectEqual(@as(?u32, 10),   h1.pop());
    try testing.expectEqual(@as(?u32, 10),   h1.pop());
    try testing.expectEqual(@as(?u32, 20),   h1.pop());
    try testing.expectEqual(@as(?u32, 70),   h1.pop());
    try testing.expectEqual(@as(?u32, 100),  h1.pop());
    try testing.expectEqual(@as(?u32, null), h1.pop());
}

test "basic_usage_max_heap" {
    const testing = std.testing;

    const MaxHeap = HeapArray(u32, 8, false);

    var h1: MaxHeap = .{};
    try testing.expectEqual(@as(?u32, null), h1.peek());
    try testing.expectEqual(@as(?u32, null), h1.pop());

    try h1.push(10);
    try testing.expectEqual(@as(?u32, 10), h1.peek());
    try testing.expectEqual(@as(?u32, 10), h1.pop());

    try h1.push(10);
    try h1.push(20);
    try h1.push(3);
    try h1.push(10);
    try h1.push(5);
    try h1.push(100);
    try h1.push(70);
    try h1.push(1);

    try testing.expectError(MaxHeap.Error.capacity_exceeded, h1.push(23));

    try testing.expectEqual(@as(?u32, 100),  h1.pop());
    try testing.expectEqual(@as(?u32, 70),   h1.pop());
    try testing.expectEqual(@as(?u32, 20),   h1.pop());
    try testing.expectEqual(@as(?u32, 10),   h1.pop());
    try testing.expectEqual(@as(?u32, 10),   h1.pop());
    try testing.expectEqual(@as(?u32, 5),    h1.pop());
    try testing.expectEqual(@as(?u32, 3),    h1.pop());
    try testing.expectEqual(@as(?u32, 1),    h1.pop());
    try testing.expectEqual(@as(?u32, null), h1.pop());
}
