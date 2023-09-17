const engine = @import("../../../engine.zig");
const ResourceHandle = engine.utils.ResourceHandle;

// ----------------------------------------------

pub const TextureInternals = struct {
    image_h: ResourceHandle = ResourceHandle.invalid,
};

// ----------------------------------------------

pub const MaterialInternals = struct {
    instance_h: ResourceHandle = ResourceHandle.invalid,
};

// ----------------------------------------------

pub const GeometryInternals = struct {
    vertex_buffer_h: ResourceHandle = ResourceHandle.invalid,
    index_buffer_h:  ResourceHandle = ResourceHandle.invalid,
};

// ----------------------------------------------
