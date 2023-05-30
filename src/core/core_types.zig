const std = @import("std");



// ----------------------------------------------------------------------------

pub const ResourceHandle = struct {
    pub const invalid: ResourceHandle = .{ .value = std.math.maxInt(usize) };

    value: usize,

    pub fn eql(self: *const ResourceHandle, other: *const ResourceHandle) bool {
        return self.value == other.value;
    }
};

// ----------------------------------------------------------------------------

pub fn Range(comptime T: type) type {
    return struct {
        offset: T,
        size: T,
    };
}

// ----------------------------------------------------------------------------
