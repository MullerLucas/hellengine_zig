const std = @import("std");
const core = @import("core.zig");

const Logger = core.log.scoped(.core);


const ByteArrayList = std.ArrayList(u8);

pub const String = struct {
    data: ByteArrayList,

    pub fn from_slice(allocator: std.mem.Allocator, value: []const u8) !String {
        var self = String {
            .data = try ByteArrayList.initCapacity(allocator, value.len),
        };

        try self.data.appendSlice(value);

        return self;
    }

    /// Release all allocated memory.
    pub fn deinit(self: String) void {
        Logger.debug("deinitializing string '{s}'\n", .{self.data.items});
        self.data.deinit();
    }

    pub fn as_slice(self: *const String) []const u8 {
        return self.data.items[0..];
    }
};
