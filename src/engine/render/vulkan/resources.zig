const core   = @import("../../core/core.zig");
const ResourceHandle = core.ResourceHandle;


// ----------------------------------------------

pub const TextureInternals = struct {
    image_h: ResourceHandle = ResourceHandle.invalid,
};

// ----------------------------------------------

pub const MaterialInternals = struct {
    instance_h: ResourceHandle = ResourceHandle.invalid,
};

// ----------------------------------------------

pub const MeshInternals = struct {
    vertex_buffer_h: ResourceHandle = ResourceHandle.invalid,
    index_buffer_h:  ResourceHandle = ResourceHandle.invalid,
};

// ----------------------------------------------
