const std = @import("std");

// ----------------------------------------------------------------------------

pub const ResourceHandle = struct
{
    pub const zero: ResourceHandle    = .{ .value = 0 };
    pub const invalid: ResourceHandle = .{ .value = std.math.maxInt(usize) };

    value: usize,

    pub fn eql(self: ResourceHandle, other: ResourceHandle) bool
    {
        return self.value == other.value;
    }

    pub fn is_valid(self: ResourceHandle) bool
    {
        return self.value != invalid.value;
    }
};

// ----------------------------------------------------------------------------

pub fn Range(comptime T: type) type
{
    return struct {
        offset: T,
        size: T,
    };
}

pub const MemRange = Range(usize);

// ----------------------------------------------------------------------------

pub fn get_aligned(operand: usize, granularity: usize) usize
{
    return ((operand + (granularity - 1)) & ~(granularity - 1));
}

pub fn get_aligned_range(offset: usize, size: usize, granularity: usize) MemRange
{
    return .{
        .offset = get_aligned(offset, granularity),
        .size   = get_aligned(size, granularity)
    };
}

// ----------------------------------------------------------------------------
