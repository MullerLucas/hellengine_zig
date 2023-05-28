const builtin = @import("builtin");



pub const MAX_FRAMES_IN_FLIGHT: u32 = 2;
pub const APP_NAME    = "hell-app";
pub const WIDTH:  u32 = 1000;
pub const HEIGHT: u32 = 800;

pub const shader_attribute_limit: usize = 16;
pub const shader_uniform_limit: usize = 32;
pub const shader_max_textures_per_scope = 31;

pub const shader_buffer_descriptor_limit = 1024;
pub const shader_sampler_descriptor_limit = 1024;
pub const shader_descriptor_set_limit = 1024;


pub const enable_validation_layers: bool = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};
