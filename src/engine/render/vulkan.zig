pub usingnamespace @import("vulkan/vulkan_types.zig");

pub const VulkanBackend = @import("vulkan/vulkan_backend.zig").VulkanBackend;
pub const resources     = @import("vulkan/resources.zig");
pub const engine        = @import("../../engine.zig");

pub const Logger = engine.logging.scoped(.vulkan);
