const builtin = @import("builtin");



pub const MAX_FRAMES_IN_FLIGHT: u32 = 2;
pub const APP_NAME    = "hell-app";
pub const WIDTH:  u32 = 1000;
pub const HEIGHT: u32 = 800;

pub const max_attributes_per_shader: usize = 16;
pub const max_uniform_buffers_per_shader: usize = 32;
pub const max_uniform_samplers_per_shader = 32;
pub const max_uniform_samplers_per_instance = 32;
pub const max_scope_instances_per_shader = 1024;


pub const shader_uniform_buffer_descriptor_limit = 1024;
pub const shader_image_sampler_descriptor_limit = 1024;
pub const shader_storage_buffer_descriptor_limit = 1024;

pub const shader_descriptor_set_limit = 1024;

pub const shader_unit_instance_limit = 1024;
pub const shader_local_instance_limit = 100000;

// NOTE: spec only guarantees 128 bytes with 4-byte alignment
pub const vulkan_push_constant_range_limit = 128;
pub const vulkan_push_constant_alignment = 4;

pub const vulkan_push_constant_stack_limit = 16;

// required by some nvidia cards?
// TODO(lm): s->required_ubo_alignment = context->device.properties.limits.minUniformBufferOffsetAlignment;
// pub const vulkan_ubo_alignment = 256;
pub const vulkan_ubo_alignment = 256;


pub const enable_validation_layers: bool = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};
