pub const VulkanBackend = @import("vulkan_backend.zig").VulkanBackend;

const vulkan_types         = @import("vulkan_types.zig");
pub const BaseDispatch     = vulkan_types.BaseDispatch;
pub const InstanceDispatch = vulkan_types.InstanceDispatch;
pub const DeviceDispatch   = vulkan_types.DeviceDispatch;
pub const Buffer           = vulkan_types.Buffer;
pub const BufferList       = vulkan_types.BufferList;

