const std = @import("std");



pub fn StackArray(comptime T: type, comptime capacity_init: usize) type {
    return struct {
        const Self = @This();
        pub const capacity = capacity_init;

        items_raw: [capacity]T = undefined,
        len: usize = 0,

        pub fn from_slice(s: []const T) Self {
            std.debug.assert(s.len <= capacity);

            var self = Self {
                .len = s.len,
            };

            @memcpy(self.items_raw[0..s.len], s);
            return self;
        }

        pub fn push(self: *Self, value: T) void {
            std.debug.assert(self.len < capacity);
            self.items_raw[self.len] = value;
            self.len += 1;
        }

        pub fn push_slice(self: *Self, other: []const T) void {
            const new_len = self.len + other.len;
            std.debug.assert(new_len <= capacity);

            @memcpy(self.items_raw[self.len..new_len], other);
            self.len += other.len;
        }

        pub fn insert_slices(self: *Self, idx: usize, other: []const []const T) void {
            var slice_len: usize = 0;
            for (other) |slice| {
                slice_len += slice.len;
            }

            std.debug.assert(self.len + slice_len <= capacity);

            @memcpy(self.items_raw[(idx + slice_len)..(idx + 2*slice_len)], self.items_raw[idx..(idx + slice_len)]);

            var offset = idx;
            for (other) |slice| {
                @memcpy(self.items_raw[offset..(offset + slice.len)], slice);
                offset += slice.len;
            }

            self.len += slice_len;
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

        pub fn eql_slice(self: *const Self, other: []const T) bool {
            if (self.len != other.len) return false;
            return std.mem.eql(u8, self.items_raw[0..self.len], other);
        }
    };
}
