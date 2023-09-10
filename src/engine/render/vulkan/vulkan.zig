pub usingnamespace @import("vulkan_types.zig");

pub const VulkanBackend = @import("vulkan_backend.zig").VulkanBackend;
pub const resources     = @import("resources.zig");
pub const engine        = @import("../../engine.zig");

pub const Logger = engine.logging.scoped(.vulkan);
