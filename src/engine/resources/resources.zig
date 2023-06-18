const std = @import("std");
const engine = @import("../engine.zig");
const vk = @import("vulkan");

const ResourceHandle = engine.core.ResourceHandle;

pub const files = @import("files.zig");
pub const Logger = @import("../core/core.zig").log.scoped(.resources);
pub const FrameNumber = engine.render.FrameNumber;


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

pub const Material = struct {
    pub const MaterialName = engine.core.StackArray(u8, 128);

    name:     MaterialName,
    textures: [engine.config.max_uniform_samplers_per_instance]ResourceHandle = undefined,
    internals: backend_resources.MaterialInternals = .{},

    frame_updated_at: FrameNumber = std.math.maxInt(FrameNumber),
};

// ----------------------------------------------

// @Performance: think about using stack memory instead
pub const Mesh = struct {
    pub const IndexType = u32;
    // @Todo: use sensible values
    pub const sub_mesh_limit = 16;

    vertices:   []Vertex,
    indices:    []IndexType,
    sub_meshes: engine.core.StackArray(SubMesh, sub_mesh_limit) = .{},

    internals: backend_resources.MeshInternals = undefined,
};

// ----------------------------------------------

// https://registry.khronos.org/vulkan/specs/1.3-khr-extensions/html/vkspec.html#vkCmdDrawIndexed
pub const SubMesh = struct {
    // first_index is the base index within the index buffer.
    first_index: usize,
    /// index_count is the number of vertices to draw.
    index_count: usize,
    /// material used by this submesh
    material_h: ResourceHandle,
};

