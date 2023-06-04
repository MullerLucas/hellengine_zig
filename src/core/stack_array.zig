const std = @import("std");



pub fn StackArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items_raw: [capacity]T = undefined,
        len: usize = 0,

        pub fn push(self: *Self, value: T) void {
            std.debug.assert(self.len < capacity);
            self.items_raw[self.len] = value;
            self.len += 1;
        }

        pub fn pop(self: *Self) T {
            std.debug.assert(self.len > 0);
            defer self.len -= 1;
            return self.items_raw[self.len];
        }

        pub inline fn is_full(self: *const Self) bool {
            return self.len == capacity;
        }

        pub inline fn is_empty(self: *const Self) bool {
            return self.len == 0;
        }

        pub inline fn as_slice(self: *const Self) []const T {
            return self.items_raw[0..self.len];
        }

        pub fn get(self: *const Self, idx: usize) *const T {
            std.debug.assert(self.len > idx);
            return &self.items_raw[idx];
        }

        pub fn get_mut(self: *Self, idx: usize) *T {
            std.debug.assert(self.len > idx);
            return &self.items_raw[idx];
        }
    };
}
