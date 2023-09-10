const engine   = @import("../engine.zig");
const MemRange = engine.core.MemRange;


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
