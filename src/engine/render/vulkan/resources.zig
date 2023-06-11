const core   = @import("../../core/core.zig");
const ResourceHandle = core.ResourceHandle;



pub const MeshInternals = struct {
    vertex_buffer_h: ResourceHandle = ResourceHandle.invalid,
    index_buffer_h:  ResourceHandle = ResourceHandle.invalid,
    // TODO(lm): texture should be optional
    texture_h:       ResourceHandle = ResourceHandle.invalid,
};
