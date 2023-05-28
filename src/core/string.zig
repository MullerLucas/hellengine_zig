const std = @import("std");


const ByteArrayList = std.ArrayList(u8);

pub const String = struct {
    data: ByteArrayList,

    pub fn from_slice(allocator: std.mem.Allocator, value: []const u8) !String {
        var self = String {
            .data = try ByteArrayList.initCapacity(allocator, value.len),
        };

        return self;
    }

    pub fn deinit(self: String) void {
        self.data.deinit();
    }

    pub fn as_slice(self: *const String) []const u8 {
        return self.data.items[0..];
    }
};
