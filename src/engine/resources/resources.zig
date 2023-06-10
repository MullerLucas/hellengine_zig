const std = @import("std");
const engine = @import("../engine.zig");
const vk = @import("vulkan");

pub const files = @import("files.zig");
pub const Logger = @import("../core/core.zig").log.scoped(.resources);




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

pub const Mesh = struct {
    pub const IndexType = u32;

    vertices: []Vertex,
    indices:  []IndexType,
    // TODO(lm): make backend generic
    internals: engine.render.vulkan.resources.MeshInternals = undefined,

};
