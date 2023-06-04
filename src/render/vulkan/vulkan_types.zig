const std    = @import("std");
const vk     = @import("vulkan");
const CFG = @import("../../config.zig");
const core   = @import("../../core/core.zig");
const ResourceHandle = core.ResourceHandle;
const render = @import("../render.zig");
const ShaderScope = render.shader.ShaderScope;
const MemRange = core.MemRange;

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
    .cmdPushConstants = true,
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

pub const SwapChainSupportDetails = struct {
    allocator: std.mem.Allocator,
    capabilities: vk.SurfaceCapabilitiesKHR = undefined,
    formats: ?[]vk.SurfaceFormatKHR = null,
    present_modes: ?[]vk.PresentModeKHR = null,

    pub fn init(allocator: std.mem.Allocator) SwapChainSupportDetails {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: SwapChainSupportDetails) void {
        if (self.formats != null) self.allocator.free(self.formats.?);
        if (self.present_modes != null) self.allocator.free(self.present_modes.?);
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

pub const ShaderAttributeArray = core.StackArray(vk.VertexInputAttributeDescription, CFG.max_attributes_per_shader);

pub const ShaderInternals = struct {
    scopes: [4]ShaderScopeInternals = [_]ShaderScopeInternals { .{} } ** 4,
    pipeline: GraphicsPipeline = .{},
    descriptor_pool: vk.DescriptorPool = .null_handle,

    push_constant_internals: PushConstantInternalsStack = .{},

    attributes: ShaderAttributeArray = .{},

    /// used for all scopes except 'local'
    uniform_buffer:         Buffer = undefined,
    uniform_buffer_mapping: []u8   = undefined,
    uniform_buffer_total_size_aligned: usize = 0,
    /// used for 'local' scope only
    storage_buffer:         Buffer = undefined,
    storage_buffer_mapping: []u8   = undefined,
    storage_buffer_total_size_aligned: usize = 0,

    bound_buffer: *Buffer = undefined,
    bound_scope: ShaderScope = .global,
    bound_instance_h: ResourceHandle = ResourceHandle.invalid,

    pub fn get_scope(self: *const ShaderInternals, scope: ShaderScope) *const ShaderScopeInternals {
        return &self.scopes[@enumToInt(scope)];
    }
};

// ----------------------------------------------

pub const ShaderScopeInternals = struct {
    buffer_offset: usize = 0,
    buffer_size_aligned: usize = 0,
    buffer_descriptor_type: vk.DescriptorType = undefined,

    // NOTE: minUniformBufferOffsetAlignment is the minimum required alignment, in bytes, for the offset member of the VkDescriptorBufferInfo structure for uniform buffers.
    // When a descriptor of type VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER or VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC is updated,
    // the offset must be an integer multiple of this limit.
    // Similarly, dynamic offsets for uniform buffers must be multiples of this limit. The value must be a power of two.
    // NOTE: minStorageBufferOffsetAlignment ...
    buffer_instance_size_unalinged: usize = 0,
    buffer_instance_size_alinged:   usize = 0,

    descriptor_set_layout: vk.DescriptorSetLayout = .null_handle,

    // TODO(lm): optimize - most scopes only have one instance
    instances: core.StackArray(ShaderInstanceInternals, CFG.max_scope_instances_per_shader) = .{},
};

// ----------------------------------------------

pub const ShaderInstanceInternals = struct {
    sampler_images:  [CFG.max_uniform_samplers_per_shader]ResourceHandle = [_]ResourceHandle { ResourceHandle.invalid } ** CFG.max_uniform_samplers_per_instance,
    descriptor_sets: [CFG.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet = [_]vk.DescriptorSet { .null_handle } ** CFG.MAX_FRAMES_IN_FLIGHT,
};

// ----------------------------------------------

pub const PushConstantInternals = struct {
    // Spec: Both offset and size are in units of bytes and must be a multiple of 4
    range: MemRange,
};

pub const PushConstantInternalsStack = core.StackArray(PushConstantInternals, CFG.vulkan_push_constant_stack_limit);

// ----------------------------------------------
