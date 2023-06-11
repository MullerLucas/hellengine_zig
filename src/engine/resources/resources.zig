const std = @import("std");
const engine = @import("../engine.zig");
const vk = @import("vulkan");

const ResourceHandle = engine.core.ResourceHandle;

pub const files = @import("files.zig");
pub const Logger = @import("../core/core.zig").log.scoped(.resources);


// @Todo
const backend_resources = if (true)
    engine.render.vulkan.resources
 else
    engine.render.vulkan.resources;




// ----------------------------------------------

pub const Vertex = struct {
    position: [3]f32 = .{ 0, 0, 0 },
    normal:   [3]f32 = .{ 0, 0, 0 },
    color:    [3]f32 = .{ 1, 1, 1 },
    uv:       [2]f32 = .{ 0, 0 },

    // @Todo: don't use vk stuff in here
    pub fn get_binding_description() vk.VertexInputBindingDescription {
        return vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .input_rate = .vertex,
        };
    }
};

// ----------------------------------------------

pub const RawImage = struct {
    width:    u32 = 0,
    height:   u32 = 0,
    channels: u32 = 0,
    pixels:   [*]u8 = undefined,
};

// ----------------------------------------------

pub const Texture = struct {
    pub const name_limit: usize = 128;

    path: [name_limit]u8 = undefined,
    internals: backend_resources.TextureInternals = .{},
};

// ----------------------------------------------

pub const Mesh = struct {
    pub const IndexType = u32;

    vertices: []Vertex,
    indices:  []IndexType,
    internals: backend_resources.MeshInternals = undefined,

};
