pub usingnamespace @import("vulkan_types.zig");

pub const VulkanBackend = @import("vulkan_backend.zig").VulkanBackend;
pub const resources     = @import("resources.zig");
pub const Logger        = @import("../../core/log.zig").scoped(.vulkan);
