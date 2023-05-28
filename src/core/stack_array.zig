const std = @import("std");



pub fn StackArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        len: usize = 0,

        pub fn push(self: *Self, value: T) void {
            std.debug.assert(self.len < (capacity - 1));
            self.items[self.len] = value;
            self.len += 1;
        }

        pub fn pop(self: *Self) T {
            std.debug.assert(self.len > 0);
            defer self.len -= 1;
            return self.items[self.len];
        }

        pub inline fn is_full(self: *const Self) bool {
            return self.len == (capacity - 1);
        }

        pub inline fn is_empty(self: *const Self) bool {
            return self.len == 0;
        }

        pub inline fn as_slice(self: *const Self) []const T {
            return self.items[0..self.len];
        }
    };
}
