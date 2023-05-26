const std = @import("std");
const vk  = @import("vulkan");
const za  = @import("zalgebra");
const core_types = @import("../core/core_types.zig");
const ResourceHandle = core_types.ResourceHandle;

const assert = std.debug.assert;

// ----------------------------------------------

pub const UniformBufferObject = struct {
    model: za.Mat4 align(16),
    view: za.Mat4 align(16),
    proj: za.Mat4 align(16),
};

// ----------------------------------------------

pub const Vertex = struct {
    pos:       [3]f32 = .{ 0, 0, 0 },
    color:     [3]f32 = .{ 0, 0, 0 },
    tex_coord: [2]f32 = .{ 0, 0 },

    pub fn get_binding_description() vk.VertexInputBindingDescription {
        return vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .input_rate = .vertex,
        };
    }

    pub fn get_attribute_descriptions() [3]vk.VertexInputAttributeDescription {
        return [_]vk.VertexInputAttributeDescription{
            .{
                .binding = 0,
                .location = 0,
                .format = .r32g32b32_sfloat,
                .offset = @offsetOf(Vertex, "pos"),
            },
            .{
                .binding = 0,
                .location = 1,
                .format = .r32g32b32_sfloat,
                .offset = @offsetOf(Vertex, "color"),
            },
            .{
                .binding = 0,
                .location = 2,
                .format = .r32g32_sfloat,
                .offset = @offsetOf(Vertex, "tex_coord"),
            },
        };
    }
};

// ----------------------------------------------

pub const Mesh = struct{
    vertices: [4]Vertex,
    indices : [6]u16,
    vertex_buffer: ResourceHandle = ResourceHandle.invalid,
    index_buffer:  ResourceHandle = ResourceHandle.invalid,
    texture:       ResourceHandle = ResourceHandle.invalid,
};

pub const MeshList = std.ArrayList(Mesh);

// ----------------------------------------------

pub const RenderData = struct {
    pub const DATA_LIMIT: usize = 1024;
    len: usize = 0,
    meshes: [DATA_LIMIT]*Mesh = undefined,

    pub fn add_mesh(self: *RenderData, mesh: *Mesh) void {
        assert(self.len < RenderData.DATA_LIMIT);

        self.meshes[self.len] = mesh;
        self.len += 1;
    }

    pub fn mesh_slice(self: *const RenderData) []const *const Mesh {
        return self.meshes[0..self.len];
    }
};

// ----------------------------------------------
