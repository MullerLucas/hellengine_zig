const vk = @import("vulkan");
const za = @import("zalgebra");

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

    pub fn getBindingDescription() vk.VertexInputBindingDescription {
        return vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .input_rate = .vertex,
        };
    }

    pub fn getAttributeDescriptions() [3]vk.VertexInputAttributeDescription {
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
    vertices: [8]Vertex,
    indices : [12]u16,

};

// ----------------------------------------------
