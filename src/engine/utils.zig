const std = @import("std");
const engine = @import("../engine.zig");

// ----------------------------------------------------------------------------

const corez = @import("corez");
pub const ResourceHandle = corez.utils.UniqueHandle(@intFromEnum(engine.UniqueHandleType.ResourceHandle));

// ----------------------------------------------------------------------------

pub fn Range(comptime T: type) type {
    return struct {
        offset: T,
        size: T,
    };
}

pub const MemRange = Range(usize);

// ----------------------------------------------------------------------------

pub fn get_aligned(operand: usize, granularity: usize) usize {
    return ((operand + (granularity - 1)) & ~(granularity - 1));
}

pub fn get_aligned_range(offset: usize, size: usize, granularity: usize) MemRange {
    return .{
        .offset = get_aligned(offset, granularity),
        .size   = get_aligned(size, granularity)
    };
}

// ----------------------------------------------------------------------------
