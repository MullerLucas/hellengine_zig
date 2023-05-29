pub const VulkanBackend = @import("vulkan_backend.zig").VulkanBackend;

const vulkan_types           = @import("vulkan_types.zig");
pub const BaseDispatch       = vulkan_types.BaseDispatch;
pub const InstanceDispatch   = vulkan_types.InstanceDispatch;
pub const DeviceDispatch     = vulkan_types.DeviceDispatch;
pub const QueueFamilyIndices = vulkan_types.QueueFamilyIndices;
pub const Buffer             = vulkan_types.Buffer;
pub const BufferList         = vulkan_types.BufferList;
pub const Image              = vulkan_types.Image;
pub const ImageArrayList     = vulkan_types.ImageArrayList;
pub const GraphicsPipeline   = vulkan_types.GraphicsPipeline;
pub const GraphicsPipelineArrayList = vulkan_types.GraphicsPipelineArrayList;

pub const ShaderInternals = vulkan_types.ShaderInternals;
pub const ShaderScopeInternals = vulkan_types.ShaderScopeInternals;
pub const ShaderInstanceInternals = vulkan_types.ShaderInstanceInternals;

pub const Logger = @import("../../core/log.zig").scoped(.vulkan);

