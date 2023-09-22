pub const render      = @import("engine/render.zig");
pub const config      = @import("engine/config.zig");
pub const resources   = @import("engine/resources.zig");
pub const c           = @import("engine/c.zig");

pub const logging = @import("engine/logging.zig");
pub const time    = @import("engine/time.zig");
pub const utils   = @import("engine/utils.zig");

// -----------------------------------------------

pub const UniqueHandleType = enum(usize) {
    ResourceHandle,
};
