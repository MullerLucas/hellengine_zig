const std = @import("std");
const engine = @import("../../engine.zig");


pub const String = struct {
    pub const CharacterList = std.ArrayList(u8);

    raw: CharacterList,

    /// Release all allocated memory.
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !String {
        return String {
            .raw = try CharacterList.initCapacity(allocator, capacity),
        };
    }

    /// Release all allocated memory.
    pub fn deinit(self: String) void {
        self.raw.deinit();
    }

    pub fn from_slice(allocator: std.mem.Allocator, value: []const u8) !String {
        var self = try String.init(allocator, value.len);
        try self.raw.appendSlice(value);
        return self;
    }

    pub fn from_slice_with_sentinel(allocator: std.mem.Allocator, value: []const u8) !String {
        var self = try from_slice(allocator, value);
        try self.append_sentinel();
        return self;
    }

    pub inline fn append_sentinel(self: *String) !void {
        try self.raw.append(&.{0});
    }

    pub inline fn as_slice(self: *const String) []const u8 {
        return self.raw.items;
    }
};
