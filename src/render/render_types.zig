const vk = @import("vulkan");
const za = @import("zalgebra");

// ----------------------------------------------

pub const UniformBufferObject = struct {
    model: za.Mat4 align(16),
    view: za.Mat4 align(16),
    proj: za.Mat4 align(16),
};

// ----------------------------------------------

