const std    = @import("std");
const vk     = @import("vulkan");
const CFG = @import("../../config.zig");
const core   = @import("../../core/core.zig");
const ResourceHandle = core.ResourceHandle;
const render = @import("../render.zig");
const ShaderScope = render.shader.ShaderScope;

// ----------------------------------------------

pub const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceLayerProperties = true,
});

// ----------------------------------------------

pub const InstanceDispatch = vk.InstanceWrapper(.{
    .createDebugUtilsMessengerEXT = CFG.enable_validation_layers,
    .createDevice = true,
    .destroyDebugUtilsMessengerEXT = CFG.enable_validation_layers,
    .destroyInstance = true,
    .destroySurfaceKHR = true,
    .enumerateDeviceExtensionProperties = true,
    .enumeratePhysicalDevices = true,
    .getDeviceProcAddr = true,
    .getPhysicalDeviceFeatures = true,
    .getPhysicalDeviceFormatProperties = true,
    .getPhysicalDeviceMemoryProperties = true,
    .getPhysicalDeviceProperties = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
    .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
    .getPhysicalDeviceSurfaceFormatsKHR = true,
    .getPhysicalDeviceSurfacePresentModesKHR = true,
    .getPhysicalDeviceSurfaceSupportKHR = true,
});

// ----------------------------------------------

pub const DeviceDispatch = vk.DeviceWrapper(.{
    .acquireNextImageKHR = true,
    .allocateCommandBuffers = true,
    .allocateDescriptorSets = true,
    .allocateMemory = true,
    .beginCommandBuffer = true,
    .bindBufferMemory = true,
    .bindImageMemory = true,
    .cmdBeginRenderPass = true,
    .cmdBindDescriptorSets = true,
    .cmdBindIndexBuffer = true,
    .cmdBindPipeline = true,
    .cmdBindVertexBuffers = true,
    .cmdCopyBuffer = true,
    .cmdCopyBufferToImage = true,
    .cmdDrawIndexed = true,
    .cmdEndRenderPass = true,
    .cmdPipelineBarrier = true,
    .cmdSetViewport = true,
    .cmdSetScissor = true,
    .createBuffer = true,
    .createCommandPool = true,
    .createDescriptorPool = true,
    .createDescriptorSetLayout = true,
    .createFence = true,
    .createFramebuffer = true,
    .createGraphicsPipelines = true,
    .createImage = true,
    .createImageView = true,
    .createPipelineLayout = true,
    .createRenderPass = true,
    .createSampler = true,
    .createSemaphore = true,
    .createShaderModule = true,
    .createSwapchainKHR = true,
    .destroyBuffer = true,
    .destroyCommandPool = true,
    .destroyDescriptorPool = true,
    .destroyDescriptorSetLayout = true,
    .destroyDevice = true,
    .destroyFence = true,
    .destroyFramebuffer = true,
    .destroyImage = true,
    .destroyImageView = true,
    .destroyPipeline = true,
    .destroyPipelineLayout = true,
    .destroyRenderPass = true,
    .destroySampler = true,
    .destroySemaphore = true,
    .destroyShaderModule = true,
    .destroySwapchainKHR = true,
    .deviceWaitIdle = true,
    .endCommandBuffer = true,
    .freeCommandBuffers = true,
    .freeMemory = true,
    .getBufferMemoryRequirements = true,
    .getDeviceQueue = true,
    .getImageMemoryRequirements = true,
    .getSwapchainImagesKHR = true,
    .mapMemory = true,
    .queuePresentKHR = true,
    .queueSubmit = true,
    .queueWaitIdle = true,
    .resetCommandBuffer = true,
    .resetFences = true,
    .unmapMemory = true,
    .updateDescriptorSets = true,
    .waitForFences = true,
});

// ----------------------------------------------

pub const QueueFamilyIndices = struct {
    graphics_family: ?u32 = null,
    present_family: ?u32 = null,

    pub fn isComplete(self: *const QueueFamilyIndices) bool {
        return self.graphics_family != null and self.present_family != null;
    }
};

// ----------------------------------------------

pub const Buffer = struct {
    mem: vk.DeviceMemory,
    buf: vk.Buffer,
};

pub const BufferList = std.MultiArrayList(Buffer);

// ----------------------------------------------

pub const Image = struct {
    mem: vk.DeviceMemory,
    img: vk.Image,
    view: vk.ImageView = .null_handle,
    sampler: ?vk.Sampler = null,
};

pub const ImageArrayList = std.MultiArrayList(Image);

// ----------------------------------------------

pub const GraphicsPipeline = struct {
    render_pass: vk.RenderPass = .null_handle,
    pipeline_layout: vk.PipelineLayout = .null_handle,
    pipeline: vk.Pipeline = .null_handle,
};

// ----------------------------------------------

pub const ShaderAttributeArray = core.StackArray(vk.VertexInputAttributeDescription, CFG.shader_attribute_limit);

pub const ShaderInternals = struct {
    scopes: [4]ShaderScopeInternals = [_]ShaderScopeInternals { .{} } ** 4,
    pipeline: GraphicsPipeline = .{},
    // uniform_buffers: ?[]ResourceHandle = null,
    descriptor_pool: vk.DescriptorPool = .null_handle,
    // descriptor_sets: ?[]vk.DescriptorSet = null,

    attributes: ShaderAttributeArray = .{},

    uniform_buffer:         Buffer = undefined,
    mapped_uniform_buffer:  []u8   = undefined,

    pub fn get_scope(self: *const ShaderInternals, scope: ShaderScope) *const ShaderScopeInternals {
        return &self.scopes[@enumToInt(scope)];
    }
};

// ----------------------------------------------

pub const ShaderScopeInternals = struct {
    buffer_offset: usize = 0,
    buffer_range: usize = 0,
    descriptor_set_layout: vk.DescriptorSetLayout = .null_handle,
    descriptor_sets: [CFG.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet = [_]vk.DescriptorSet { .null_handle } ** CFG.MAX_FRAMES_IN_FLIGHT,
};
