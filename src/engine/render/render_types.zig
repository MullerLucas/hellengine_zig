const std = @import("std");
const vk  = @import("vulkan");
const za  = @import("zalgebra");
const core_types = @import("../core/core_types.zig");
const ResourceHandle = core_types.ResourceHandle;

const core = @import("../core/core.zig");
const config = @import("../config.zig");
const Logger = core.log.scoped(.render);

const assert = std.debug.assert;

// ----------------------------------------------

// TODO(lm): make sure that 'extern' makes sense
pub const UniformBufferObject = struct {
    model: za.Mat4 align(16),
    view:  za.Mat4 align(16),
    proj:  za.Mat4 align(16),
    reserved_0: za.Mat4 align(16) = undefined,
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
};

// ----------------------------------------------

pub const Mesh = struct {
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

pub const NumberFormat = enum {
    undefined,
    r32g32_sfloat,
    r32g32b32_sfloat,
    r32g32b32a32_sfloat,


    pub fn to_vk_format(self: NumberFormat) vk.Format {
        return switch (self) {
            .r32g32_sfloat       => .r32g32_sfloat,
            .r32g32b32_sfloat    => .r32g32b32_sfloat,
            .r32g32b32a32_sfloat => .r32g32b32a32_sfloat,
            else => .undefined,
        };
    }

    pub fn size(self: NumberFormat) usize {
        return switch (self){
            .r32g32_sfloat       => @sizeOf(f32) * 2,
            .r32g32b32_sfloat    => @sizeOf(f32) * 3,
            .r32g32b32a32_sfloat => @sizeOf(f32) * 4,
            else => 0,
        };
    }
};

// ----------------------------------------------
