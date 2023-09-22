const std    = @import("std");

const corez      = @import("../main.zig");
const StackArray = corez.collections.StackArray;

// ----------------------------------------------

pub const StringS8    = StringS(8);
pub const StringS16   = StringS(16);
pub const StringS32   = StringS(32);
pub const StringS64   = StringS(64);
pub const StringS128  = StringS(128);
pub const StringS256  = StringS(256);
pub const StringS512  = StringS(512);
pub const StringS1024 = StringS(1024);
pub const StringS2048 = StringS(2048);
pub const StringS4096 = StringS(4096);

// ----------------------------------------------

pub fn StringS(comptime capacity: usize) type {
    return struct {
        const Self = @This();
        const CharacterArray = StackArray(u8, capacity);

        raw: CharacterArray = .{},

        pub inline fn from(other: Self) Self {
            return Self.from_slice(other.as_slice());
        }

        pub inline fn from_slice(slice: []const u8) Self {
            return Self {
                .raw = CharacterArray.from_slice(slice),
            };
        }

        pub inline fn from_slices(slices: []const []const u8) Self {
            return Self {
                .raw = CharacterArray.from_slices(slices),
            };
        }

        pub inline fn from_slice_with_zero_terminator(slice: []const u8) Self {
            return Self {
                .raw = CharacterArray.from_slice_with_sentinel(0, slice),
            };
        }

        pub inline fn from_slices_with_zero_terminator(slices: []const []const u8) Self {
            return Self {
                .raw = CharacterArray.from_slices_with_sentinel(0, slices),
            };
        }

        pub inline fn push(self: *Self, value: u8) void {
            self.raw.push(value);
        }

        pub inline fn push_slice(self: *Self, other: []const u8) void {
            self.raw.push_slice(other);
        }

        pub inline fn insert_slices(self: *Self, idx: usize, other: []const []const u8) void {
            self.raw.insert_slices(idx, other);
        }

        pub inline fn pop(self: *Self) u8 {
            return self.raw.pop();
        }

        pub inline fn is_full(self: *const Self) bool {
            return self.raw.is_full();
        }

        pub inline fn is_empty(self: *const Self) bool {
            return self.raw.is_empty();
        }

        pub inline fn as_slice(self: *const Self) []const u8 {
            return self.raw.as_slice();
        }

        pub inline fn as_sentinel_slice(self: *const Self, comptime s: u8) [:s]const u8 {
            return self.raw.as_sentinel_slice(s);
        }

        pub inline fn as_sentinel_ptr(self: *const Self, comptime s: u8) [*:s]const u8 {
            return self.raw.as_sentinel_ptr(s);
        }

        pub inline fn get(self: *const Self, idx: usize) *const u8 {
            return self.raw.get(idx);
        }

        pub inline fn get_mut(self: *Self, idx: usize) *u8 {
            return self.raw.get_mut(idx);
        }

        pub inline fn eql_slice(self: *const Self, other: []const u8) bool {
            return self.raw.eql_slice(other);
        }
    };
}
