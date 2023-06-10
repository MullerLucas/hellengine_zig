const core   = @import("../../core/core.zig");
const ResourceHandle = core.ResourceHandle;



pub const MeshInternals = struct {
    vertex_buffer: ResourceHandle = ResourceHandle.invalid,
    index_buffer:  ResourceHandle = ResourceHandle.invalid,
    // TODO(lm): texture should be optional
    texture:       ResourceHandle = ResourceHandle.invalid,
};
