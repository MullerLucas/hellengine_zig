const builtin = @import("builtin");



pub const MAX_FRAMES_IN_FLIGHT: u32 = 2;
pub const APP_NAME    = "hell-app";
pub const WIDTH:  u32 = 1000;
pub const HEIGHT: u32 = 800;

pub const shader_attribute_limit: usize = 16;


pub const enable_validation_layers: bool = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};
