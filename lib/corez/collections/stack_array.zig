const std = @import("std");

pub fn StackArray(comptime T: type, comptime capacity_init: usize) type {
    return struct {
        const Self = @This();
        pub const capacity = capacity_init;

        items_raw: [capacity]T = undefined,
        len: usize = 0,

        pub inline fn from(other: Self) Self {
            return Self.from_slice(other.as_slice());
        }

        pub fn from_slice(slice: []const T) Self {
            std.debug.assert(slice.len <= capacity);

            var self = Self {
                .len = slice.len,
            };

            @memcpy(self.items_raw[0..slice.len], slice);
            return self;
        }

        pub fn from_slices(slices: []const []const T) Self {
            var self = Self {
                .len = 0,
            };

            self.insert_slices(0, slices);

            return self;
        }

        pub fn from_slice_with_sentinel(comptime s: T, slice: []const T) Self {
            // @Note: We add 1 to the length to account for the sentinel.
            const total_len = slice.len + 1;
            std.debug.assert(total_len <= capacity);

            var self = Self {
                .len = slice.len,
            };

            @memcpy(self.items_raw[0..slice.len], slice);
            self.items_raw[slice.len] = s;
            return self;
        }

        pub fn from_slices_with_sentinel(comptime s: T, slices: []const []const T) Self {
            var self = Self.from_slices(slices);
            self.push(s);

            std.debug.assert(self.len + 1 <= capacity);
            self.items_raw[self.len] = s;

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

        pub inline fn as_sentinel_slice(self: *const Self, comptime s: T) [:s]const T {
            return self.items_raw[0..self.len];
        }

        pub inline fn as_sentinel_ptr(self: *const Self, comptime s: T) [*:s]const T {
            return @ptrCast(self.items_raw[0..self.len].ptr);
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
