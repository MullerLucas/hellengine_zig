const std       = @import("std");
const assert    = std.debug.assert;
const Allocator = std.mem.Allocator;

const vk               = @import("vulkan");
const za               = @import("zalgebra");

const GlfwWindow       = @import("../../GlfwWindow.zig");

const CFG       = @import("../../config.zig");
const resources = @import("resources");

const core           = @import("../../core/core.zig");
const SlotArray      = core.SlotArray;
const ResourceHandle = core.ResourceHandle;
const MemRange       = core.MemRange;

const render              = @import("../render.zig");
const Vertex              = render.Vertex;
const RenderData          = render.RenderData;
const UniformBufferObject = render.UniformBufferObject;
const ShaderInfo        = render.ShaderInfo;

const vulkan     = @import("./vulkan.zig");
const Logger     = vulkan.Logger;
const Buffer     = vulkan.Buffer;
const BufferList = vulkan.BufferList;
const Image      = vulkan.Image;
const ImageArrayList     = vulkan.ImageArrayList;
const QueueFamilyIndices = vulkan.QueueFamilyIndices;
const GraphicsPipeline   = vulkan.GraphicsPipeline;
const SwapChainSupportDetails = vulkan.SwapChainSupportDetails;

const ShaderInternals = vulkan.ShaderInternals;
const ShaderScope = render.shader.ShaderScope;
const ShaderScopeInternals = vulkan.ShaderInternals;
const ShaderInstanceInternals = vulkan.ShaderInstanceInternals;
const PushConstantInternals = vulkan.PushConstantInternals;


const c = @cImport({
    @cInclude("stb_image.h");
});

// ----------------------------------------------

const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
const device_extensions = [_][*:0]const u8{vk.extension_info.khr_swapchain.name};
const BUFFER_BINDING_IDX = 0;
const IMAGE_SAMPLER_BINDING_IDX = 1;

// ----------------------------------------------

const DescriptorSetLayoutBindingStack = core.StackArray(vk.DescriptorSetLayoutBinding, 2);
const DescriptorImageInfoStack = core.StackArray(vk.DescriptorImageInfo, CFG.max_uniform_samplers_per_shader);
const PushConstantRangeStack = core.StackArray(vk.PushConstantRange, CFG.vulkan_push_constant_stack_limit);

// ----------------------------------------------

fn get_aligned(operand: usize, granularity: usize) usize {
    return ((operand + (granularity - 1)) & ~(granularity - 1));
}

fn get_aligned_range(offset: usize, size: usize, granularity: usize) MemRange {
    return .{
        .offset = get_aligned(offset, granularity),
        .size   = get_aligned(size, granularity)
    };
}

// ----------------------------------------------

const SCOPE_SET_INDICES = [_]usize { 0, 1, 2, 3 };
pub inline fn scope_set_index(scope: ShaderScope) usize {
    return SCOPE_SET_INDICES[@enumToInt(scope)];
}

// ----------------------------------------------

const PushConstantData = struct {
    local_idx: usize,
};

// ----------------------------------------------

pub const VulkanBackend = struct {
    const Self = @This();
    allocator: Allocator,

    window: *GlfwWindow = undefined,

    vkb: vulkan.BaseDispatch     = undefined,
    vki: vulkan.InstanceDispatch = undefined,
    vkd: vulkan.DeviceDispatch   = undefined,

    instance: vk.Instance = .null_handle,
    debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle,
    surface: vk.SurfaceKHR = .null_handle,

    physical_device: vk.PhysicalDevice = .null_handle,
    device: vk.Device = .null_handle,

    graphics_queue: vk.Queue = .null_handle,
    present_queue: vk.Queue = .null_handle,

    swap_chain: vk.SwapchainKHR = .null_handle,
    swap_chain_images: ?[]vk.Image = null,
    swap_chain_image_format: vk.Format = .@"undefined",
    swap_chain_extent: vk.Extent2D = .{ .width = 0, .height = 0 },
    swap_chain_image_views: ?[]vk.ImageView = null,
    swap_chain_framebuffers: ?[]vk.Framebuffer = null,

    command_pool: vk.CommandPool = .null_handle,
    command_buffers: ?[]vk.CommandBuffer = null,

    buffers: BufferList = BufferList{},
    images: ImageArrayList = ImageArrayList{},
    depth_image_handle: ResourceHandle = ResourceHandle.invalid,


    image_available_semaphores: ?[]vk.Semaphore = null,
    render_finished_semaphores: ?[]vk.Semaphore = null,
    in_flight_fences: ?[]vk.Fence = null,
    current_frame: u32 = 0,

    start_time: std.time.Instant,

    render_pass: vk.RenderPass = .null_handle,


    pub fn init(allocator: Allocator, window: *GlfwWindow) !Self {
        var self = Self{
            .allocator = allocator,
            .start_time = try std.time.Instant.now(),
            .window = window,
        };

        try self.createInstance();
        try self.setup_debug_messenger();
        try self.create_surface();
        try self.pick_physical_device();
        try self.create_logical_device();
        try self.create_swap_chain();
        try self.create_image_views();

        self.render_pass = try self.create_render_pass();

        try self.createCommandPool();
        try self.create_depth_resources();
        try self.create_framebuffers();

        try self.create_command_buffers();
        try self.create_sync_objects();

        return self;
    }

    pub fn wait_device_idle(self: *VulkanBackend) !void {
        try self.vkd.deviceWaitIdle(self.device);
    }

    fn cleanup_swap_chain(self: *Self) void {
        self.free_image(self.depth_image_handle);

        if (self.swap_chain_framebuffers != null) {
            for (self.swap_chain_framebuffers.?) |framebuffer| {
                self.vkd.destroyFramebuffer(self.device, framebuffer, null);
            }
            self.allocator.free(self.swap_chain_framebuffers.?);
            self.swap_chain_framebuffers = null;
        }

        if (self.swap_chain_image_views != null) {
            for (self.swap_chain_image_views.?) |image_view| {
                self.vkd.destroyImageView(self.device, image_view, null);
            }
            self.allocator.free(self.swap_chain_image_views.?);
            self.swap_chain_image_views = null;
        }

        if (self.swap_chain_images != null) {
            self.allocator.free(self.swap_chain_images.?);
            self.swap_chain_images = null;
        }

        if (self.swap_chain != .null_handle) {
            self.vkd.destroySwapchainKHR(self.device, self.swap_chain, null);
            self.swap_chain = .null_handle;
        }
    }

    pub fn deinit(self: *Self) void {
        Logger.info("deinitializing vulkan backend\n", .{});

        self.cleanup_swap_chain();

        self.images.deinit(self.allocator);
        self.buffers.deinit(self.allocator);

        if (self.render_finished_semaphores != null) {
            for (self.render_finished_semaphores.?) |semaphore| {
                self.vkd.destroySemaphore(self.device, semaphore, null);
            }
            self.allocator.free(self.render_finished_semaphores.?);
        }
        if (self.image_available_semaphores != null) {
            for (self.image_available_semaphores.?) |semaphore| {
                self.vkd.destroySemaphore(self.device, semaphore, null);
            }
            self.allocator.free(self.image_available_semaphores.?);
        }
        if (self.in_flight_fences != null) {
            for (self.in_flight_fences.?) |fence| {
                self.vkd.destroyFence(self.device, fence, null);
            }
            self.allocator.free(self.in_flight_fences.?);
        }

        if (self.command_pool != .null_handle) self.vkd.destroyCommandPool(self.device, self.command_pool, null);
        if (self.command_buffers != null) self.allocator.free(self.command_buffers.?);

        if (self.device != .null_handle) self.vkd.destroyDevice(self.device, null);

        if (CFG.enable_validation_layers and self.debug_messenger != .null_handle) self.vki.destroyDebugUtilsMessengerEXT(self.instance, self.debug_messenger, null);

        if (self.surface != .null_handle) self.vki.destroySurfaceKHR(self.instance, self.surface, null);
        if (self.instance != .null_handle) self.vki.destroyInstance(self.instance, null);
    }

    fn recreate_swap_chain(self: *Self) !void {
        var size = self.window.get_framebuffer_size();

        while (size.width == 0 or size.height == 0) {
            size = self.window.get_framebuffer_size();
            GlfwWindow.wait_events();
        }

        try self.vkd.deviceWaitIdle(self.device);

        self.cleanup_swap_chain();

        try self.create_swap_chain();
        try self.create_image_views();
        try self.create_depth_resources();
        try self.create_framebuffers();
    }

    fn createInstance(self: *Self) !void {
        const vk_proc = @ptrCast(*const fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.C) vk.PfnVoidFunction, &GlfwWindow.get_instance_proc_address);
        self.vkb = try vulkan.BaseDispatch.load(vk_proc);

        if (CFG.enable_validation_layers and !try self.check_validation_layer_support()) {
            return error.MissingValidationLayer;
        }

        const app_info = vk.ApplicationInfo{
            .p_application_name = "Hello Triangle",
            .application_version = vk.makeApiVersion(1, 0, 0, 0),
            .p_engine_name = "No Engine",
            .engine_version = vk.makeApiVersion(1, 0, 0, 0),
            .api_version = vk.API_VERSION_1_2,
        };

        const extensions = try get_required_extensions(self.allocator);
        defer extensions.deinit();

        var create_info = vk.InstanceCreateInfo{
            .flags = .{},
            .p_application_info = &app_info,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
            .enabled_extension_count = @intCast(u32, extensions.items.len),
            .pp_enabled_extension_names = extensions.items.ptr,
        };

        if (CFG.enable_validation_layers) {
            create_info.enabled_layer_count = validation_layers.len;
            create_info.pp_enabled_layer_names = &validation_layers;

            var debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT = undefined;
            populate_debug_messenger_create_info(&debug_create_info);
            create_info.p_next = &debug_create_info;
        }

        self.instance = try self.vkb.createInstance(&create_info, null);

        self.vki = try vulkan.InstanceDispatch.load(self.instance, vk_proc);
    }

    fn populate_debug_messenger_create_info(create_info: *vk.DebugUtilsMessengerCreateInfoEXT) void {
        create_info.* = .{
            .flags = .{},
            .message_severity = .{
                .verbose_bit_ext = true,
                .warning_bit_ext = true,
                .error_bit_ext = true,
            },
            .message_type = .{
                .general_bit_ext = true,
                .validation_bit_ext = true,
                .performance_bit_ext = true,
            },
            .pfn_user_callback = debug_callback,
            .p_user_data = null,
        };
    }

    fn setup_debug_messenger(self: *Self) !void {
        if (!CFG.enable_validation_layers) return;

        var create_info: vk.DebugUtilsMessengerCreateInfoEXT = undefined;
        populate_debug_messenger_create_info(&create_info);

        self.debug_messenger = try self.vki.createDebugUtilsMessengerEXT(self.instance, &create_info, null);
    }

    fn create_surface(self: *Self) !void {
        if ((self.window.create_window_surface(self.instance, &self.surface)) != @enumToInt(vk.Result.success)) {
            return error.SurfaceInitFailed;
        }
    }

    fn pick_physical_device(self: *Self) !void {
        var device_count: u32 = undefined;
        _ = try self.vki.enumeratePhysicalDevices(self.instance, &device_count, null);

        if (device_count == 0) {
            return error.NoGPUsSupportVulkan;
        }

        const devices = try self.allocator.alloc(vk.PhysicalDevice, device_count);
        defer self.allocator.free(devices);
        _ = try self.vki.enumeratePhysicalDevices(self.instance, &device_count, devices.ptr);

        for (devices) |device| {
            if (try self.is_device_suitable(device)) {
                self.physical_device = device;
                break;
            }
        }

        if (self.physical_device == .null_handle) {
            return error.NoSuitableDevice;
        }
    }

    fn create_logical_device(self: *Self) !void {
        const indices = try self.find_queue_families(self.physical_device);
        const queue_priority = [_]f32{1};

        var queue_create_info = [_]vk.DeviceQueueCreateInfo{
            .{
                .flags = .{},
                .queue_family_index = indices.graphics_family.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priority,
            },
            .{
                .flags = .{},
                .queue_family_index = indices.present_family.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priority,
            },
        };

        const device_features = vk.PhysicalDeviceFeatures{
            .sampler_anisotropy = vk.TRUE,
        };

        var create_info = vk.DeviceCreateInfo{
            .flags = .{},
            .queue_create_info_count = queue_create_info.len,
            .p_queue_create_infos = &queue_create_info,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
            .enabled_extension_count = device_extensions.len,
            .pp_enabled_extension_names = &device_extensions,
            .p_enabled_features = &device_features,
        };

        if (CFG.enable_validation_layers) {
            create_info.enabled_layer_count = validation_layers.len;
            create_info.pp_enabled_layer_names = &validation_layers;
        }

        self.device = try self.vki.createDevice(self.physical_device, &create_info, null);

        self.vkd = try vulkan.DeviceDispatch.load(self.device, self.vki.dispatch.vkGetDeviceProcAddr);

        self.graphics_queue = self.vkd.getDeviceQueue(self.device, indices.graphics_family.?, 0);
        self.present_queue = self.vkd.getDeviceQueue(self.device, indices.present_family.?, 0);
    }

    fn create_swap_chain(self: *Self) !void {
        const swap_chain_support = try self.query_swap_chain_support(self.physical_device);
        defer swap_chain_support.deinit();

        const surface_format: vk.SurfaceFormatKHR = choose_swap_surface_format(swap_chain_support.formats.?);
        const present_mode: vk.PresentModeKHR = choose_swap_present_mode(swap_chain_support.present_modes.?);
        const extent: vk.Extent2D = try self.choose_swap_extent(swap_chain_support.capabilities);

        Logger.debug("using present-mode {}\n", .{present_mode});

        var image_count = swap_chain_support.capabilities.min_image_count + 1;
        if (swap_chain_support.capabilities.max_image_count > 0) {
            image_count = std.math.min(image_count, swap_chain_support.capabilities.max_image_count);
        }

        const indices = try self.find_queue_families(self.physical_device);
        const queue_family_indices = [_]u32{ indices.graphics_family.?, indices.present_family.? };
        const sharing_mode: vk.SharingMode = if (indices.graphics_family.? != indices.present_family.?)
            .concurrent
        else
            .exclusive;

        self.swap_chain = try self.vkd.createSwapchainKHR(self.device, &.{
            .flags = .{},
            .surface = self.surface,
            .min_image_count = image_count,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = extent,
            .image_array_layers = 1,
            .image_usage = .{ .color_attachment_bit = true },
            .image_sharing_mode = sharing_mode,
            .queue_family_index_count = queue_family_indices.len,
            .p_queue_family_indices = &queue_family_indices,
            .pre_transform = swap_chain_support.capabilities.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = .null_handle,
        }, null);

        _ = try self.vkd.getSwapchainImagesKHR(self.device, self.swap_chain, &image_count, null);
        self.swap_chain_images = try self.allocator.alloc(vk.Image, image_count);
        _ = try self.vkd.getSwapchainImagesKHR(self.device, self.swap_chain, &image_count, self.swap_chain_images.?.ptr);

        self.swap_chain_image_format = surface_format.format;
        self.swap_chain_extent = extent;
    }

    fn create_image_views(self: *Self) !void {
        self.swap_chain_image_views = try self.allocator.alloc(vk.ImageView, self.swap_chain_images.?.len);

        for (self.swap_chain_images.?, 0..) |image, i| {
            self.swap_chain_image_views.?[i] = try self.create_image_view(image, self.swap_chain_image_format, .{ .color_bit = true });
        }
    }

    fn create_render_pass(self: *Self) !vk.RenderPass {
        const attachments = [_]vk.AttachmentDescription{
            .{
                .flags = .{},
                .format = self.swap_chain_image_format,
                .samples = .{ .@"1_bit" = true },
                .load_op = .clear,
                .store_op = .store,
                .stencil_load_op = .dont_care,
                .stencil_store_op = .dont_care,
                .initial_layout = .@"undefined",
                .final_layout = .present_src_khr,
            },
            .{
                .flags = .{},
                .format = try self.findDepthFormat(),
                .samples = .{ .@"1_bit" = true },
                .load_op = .clear,
                .store_op = .dont_care,
                .stencil_load_op = .dont_care,
                .stencil_store_op = .dont_care,
                .initial_layout = .@"undefined",
                .final_layout = .depth_stencil_attachment_optimal,
            },
        };

        const color_attachment_ref = [_]vk.AttachmentReference{.{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        }};

        const depth_attachment_ref = vk.AttachmentReference{
            .attachment = 1,
            .layout = .depth_stencil_attachment_optimal,
        };

        const subpass = [_]vk.SubpassDescription{.{
            .flags = .{},
            .pipeline_bind_point = .graphics,
            .input_attachment_count = 0,
            .p_input_attachments = undefined,
            .color_attachment_count = color_attachment_ref.len,
            .p_color_attachments = &color_attachment_ref,
            .p_resolve_attachments = null,
            .p_depth_stencil_attachment = &depth_attachment_ref,
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        }};

        const dependencies = [_]vk.SubpassDependency{.{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true, .early_fragment_tests_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true, .early_fragment_tests_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true, .depth_stencil_attachment_write_bit = true },
            .dependency_flags = .{},
        }};

        return try self.vkd.createRenderPass(self.device, &.{
            .flags = .{},
            .attachment_count = attachments.len,
            .p_attachments = &attachments,
            .subpass_count = subpass.len,
            .p_subpasses = &subpass,
            .dependency_count = dependencies.len,
            .p_dependencies = &dependencies,
        }, null);
    }

    fn create_framebuffers(self: *Self) !void {
        self.swap_chain_framebuffers = try self.allocator.alloc(vk.Framebuffer, self.swap_chain_image_views.?.len);

        for (self.swap_chain_framebuffers.?, 0..) |*framebuffer, i| {
            const depth_image = self.get_image(self.depth_image_handle);
            const attachments = [_]vk.ImageView{ self.swap_chain_image_views.?[i], depth_image.view };

            framebuffer.* = try self.vkd.createFramebuffer(self.device, &.{
                .flags = .{},
                .render_pass = self.render_pass,
                .attachment_count = attachments.len,
                .p_attachments = &attachments,
                .width = self.swap_chain_extent.width,
                .height = self.swap_chain_extent.height,
                .layers = 1,
            }, null);
        }
    }

    fn createCommandPool(self: *Self) !void {
        const queue_family_indices = try self.find_queue_families(self.physical_device);

        self.command_pool = try self.vkd.createCommandPool(self.device, &.{
            .flags = .{ .reset_command_buffer_bit = true },
            .queue_family_index = queue_family_indices.graphics_family.?,
        }, null);
    }

    fn create_depth_resources(self: *Self) !void {
        const depth_format = try self.findDepthFormat();

        self.depth_image_handle = try self.create_image(self.swap_chain_extent.width, self.swap_chain_extent.height, depth_format, .optimal, .{ .depth_stencil_attachment_bit = true }, .{ .device_local_bit = true });
        var depth_image = self.get_image(self.depth_image_handle);
        depth_image.view = try self.create_image_view(depth_image.img, depth_format, .{ .depth_bit = true });

        self.set_image(self.depth_image_handle, depth_image);
    }

    fn find_supported_format(self: *Self, candidates: []const vk.Format, tiling: vk.ImageTiling, features: vk.FormatFeatureFlags) !vk.Format {
        for (candidates) |format| {
            var props = self.vki.getPhysicalDeviceFormatProperties(self.physical_device, format);

            if (tiling == .linear and props.linear_tiling_features.contains(features)) {
                return format;
            } else if (tiling == .optimal and props.optimal_tiling_features.contains(features)) {
                return format;
            }
        }

        return error.NoSupportedFormat;
    }

    fn findDepthFormat(self: *Self) !vk.Format {
        const preferred = [_]vk.Format{ .d32_sfloat, .d32_sfloat_s8_uint, .d24_unorm_s8_uint };
        return try self.find_supported_format(preferred[0..], .optimal, .{ .depth_stencil_attachment_bit = true });
    }

    fn hasStencilComponent(format: vk.Format) bool {
        return format == .d32_sfloat_s8_uint or format == .d24_unorm_s8_uint;
    }

    pub fn create_texture_image(self: *Self, path: [*:0]const u8) !ResourceHandle {
        var tex_width: c_int = undefined;
        var tex_height: c_int = undefined;
        var channels: c_int = undefined;
        const pixels = c.stbi_load(path, &tex_width, &tex_height, &channels, c.STBI_rgb_alpha);
        defer c.stbi_image_free(pixels);
        if (pixels == null) {
            Logger.err("failed to load image '{s}'\n", .{path});
            return error.ImageLoadFailure;
        }

        const image_size: vk.DeviceSize = @intCast(u64, tex_width) * @intCast(u64, tex_height) * 4;

        const staging_buf_handle = try self.create_buffer(image_size, .{ .transfer_src_bit = true }, .{ .host_visible_bit = true, .host_coherent_bit = true });
        const staging_buffer     = self.get_buffer(staging_buf_handle);
        defer self.free_buffer_h(staging_buf_handle);

        const data = try self.vkd.mapMemory(self.device, staging_buffer.mem, 0, image_size, .{});
        std.mem.copy(u8, @ptrCast([*]u8, data.?)[0..image_size], pixels[0..image_size]);
        self.vkd.unmapMemory(self.device, staging_buffer.mem);

        const texture_image_handle = try self.create_image(@intCast(u32, tex_width), @intCast(u32, tex_height), .r8g8b8a8_srgb, .optimal, .{ .transfer_dst_bit = true, .sampled_bit = true }, .{ .device_local_bit = true });
        var texture_image = self.get_image(texture_image_handle);

        try self.transition_image_layout(texture_image.img, .r8g8b8a8_srgb, .@"undefined", .transfer_dst_optimal);
        try self.copy_buffer_to_image(staging_buffer.buf, texture_image.img, @intCast(u32, tex_width), @intCast(u32, tex_height));
        try self.transition_image_layout(texture_image.img, .r8g8b8a8_srgb, .transfer_dst_optimal, .shader_read_only_optimal);

        texture_image.view    = try self.create_image_view(texture_image.img, .r8g8b8a8_srgb, .{ .color_bit = true });
        texture_image.sampler = try self.create_texture_sampler();
        self.set_image(texture_image_handle, texture_image);

        return texture_image_handle;
    }

    fn create_texture_sampler(self: *Self) !vk.Sampler {
        const properties = self.vki.getPhysicalDeviceProperties(self.physical_device);

        const sampler_info = vk.SamplerCreateInfo{
            .flags = .{},
            .mip_lod_bias = 0,
            .min_lod = 0,
            .max_lod = 0,
            .mag_filter = .linear,
            .min_filter = .linear,
            .address_mode_u = .repeat,
            .address_mode_v = .repeat,
            .address_mode_w = .repeat,
            .anisotropy_enable = vk.TRUE,
            .max_anisotropy = properties.limits.max_sampler_anisotropy,
            .border_color = .int_opaque_black,
            .unnormalized_coordinates = vk.FALSE,
            .compare_enable = vk.FALSE,
            .compare_op = .always,
            .mipmap_mode = .linear,
        };

        return try self.vkd.createSampler(self.device, &sampler_info, null);
    }

    fn create_image_view(self: *Self, image: vk.Image, format: vk.Format, aspect_flags: vk.ImageAspectFlags) !vk.ImageView {
        const view_info = vk.ImageViewCreateInfo{
            .flags = .{},
            .image = image,
            .view_type = .@"2d",
            .format = format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = aspect_flags,
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        };
        return try self.vkd.createImageView(self.device, &view_info, null);
    }

    fn create_image(self: *Self, image_width: u32, image_height: u32, format: vk.Format, tiling: vk.ImageTiling, usage: vk.ImageUsageFlags, properties: vk.MemoryPropertyFlags) !ResourceHandle {
        Logger.debug("create image {}\n", .{ self.images.len });

        const image_info = vk.ImageCreateInfo{
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
            .image_type = .@"2d",
            .extent = .{
                .width = image_width,
                .height = image_height,
                .depth = 1,
            },
            .mip_levels = 1,
            .array_layers = 1,
            .format = format,
            .tiling = tiling,
            .initial_layout = .@"undefined",
            .usage = usage,
            .samples = .{ .@"1_bit" = true },
            .sharing_mode = .exclusive,
        };

        const image = try self.vkd.createImage(self.device, &image_info, null);

        const mem_requirements = self.vkd.getImageMemoryRequirements(self.device, image);

        const alloc_info = vk.MemoryAllocateInfo{
            .allocation_size = mem_requirements.size,
            .memory_type_index = try self.find_memory_type(mem_requirements.memory_type_bits, properties),
        };

        const image_memory = try self.vkd.allocateMemory(self.device, &alloc_info, null);
        try self.vkd.bindImageMemory(self.device, image, image_memory, 0);

        try self.images.append(self.allocator, Image {
            .img = image,
            .mem = image_memory,
        });

        return ResourceHandle { .value = self.images.len - 1 };
    }

    fn get_image(self: *Self, handle: ResourceHandle) Image {
        return self.images.get(handle.value);
    }

    // TODO (lm): remvoe
    fn set_image(self: *Self, handle: ResourceHandle, image: Image) void {
        return self.images.set(handle.value, image);
    }

    pub fn free_image(self: *Self, handle: ResourceHandle) void {
        Logger.debug("free image {}\n", .{ handle.value });

        const image = self.get_image(handle);
        self.vkd.destroyImageView(self.device, image.view, null);
        self.vkd.destroyImage    (self.device, image.img,  null);
        self.vkd.freeMemory      (self.device, image.mem,  null);
        if (image.sampler) |sampler| {
            self.vkd.destroySampler(self.device, sampler, null);
        }
    }

    fn transition_image_layout(self: *Self, image: vk.Image, _: vk.Format, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) !void {
        const command_buffer = try self.begin_single_time_commands();

        var barrier = [_]vk.ImageMemoryBarrier{.{
            .old_layout = old_layout,
            .new_layout = new_layout,
            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .src_access_mask = .{},
            .dst_access_mask = .{},
            .image = image,
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }};

        var source_stage: vk.PipelineStageFlags = undefined;
        var destination_stage: vk.PipelineStageFlags = undefined;

        if (old_layout == .@"undefined" and new_layout == .transfer_dst_optimal) {
            barrier[0].src_access_mask = .{};
            barrier[0].dst_access_mask = .{ .transfer_write_bit = true };

            source_stage = .{ .top_of_pipe_bit = true };
            destination_stage = .{ .transfer_bit = true };
        } else if (old_layout == .transfer_dst_optimal and new_layout == .shader_read_only_optimal) {
            barrier[0].src_access_mask = .{ .transfer_write_bit = true };
            barrier[0].dst_access_mask = .{ .shader_read_bit = true };

            source_stage = .{ .transfer_bit = true };
            destination_stage = .{ .fragment_shader_bit = true };
        } else {
            return error.UnsupportedLayoutTransition;
        }

        self.vkd.cmdPipelineBarrier(command_buffer, source_stage, destination_stage, .{}, 0, undefined, 0, undefined, barrier.len, &barrier);

        try self.end_single_time_commands(command_buffer);
    }

    fn copy_buffer_to_image(self: *Self, buffer: vk.Buffer, image: vk.Image, image_width: u32, image_height: u32) !void {
        const command_buffer = try self.begin_single_time_commands();

        const region = [_]vk.BufferImageCopy{.{
            .buffer_offset = 0,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = 1,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{ .width = image_width, .height = image_height, .depth = 1 },
        }};

        self.vkd.cmdCopyBufferToImage(command_buffer, buffer, image, .transfer_dst_optimal, region.len, &region);

        try self.end_single_time_commands(command_buffer);
    }

    pub fn create_vertex_buffer(self: *Self, vertices: []const Vertex) !ResourceHandle {
        const buffer_size: vk.DeviceSize = @sizeOf(Vertex) * vertices.len;
        Logger.debug("creating vertex-buffer of size: {}\n", .{buffer_size});

        const staging_buffer_handle = try create_buffer(self, buffer_size, .{ .transfer_src_bit = true }, .{ .host_visible_bit = true, .host_coherent_bit = true });
        const staging_buffer = self.get_buffer(staging_buffer_handle);
        defer self.free_buffer_h(staging_buffer_handle);

        const data = try self.vkd.mapMemory(self.device, staging_buffer.mem, 0, buffer_size, .{});
        std.mem.copy(u8, @ptrCast([*]u8, data.?)[0..buffer_size], std.mem.sliceAsBytes(vertices));
        self.vkd.unmapMemory(self.device, staging_buffer.mem);

        const vertex_buffer_handle = try create_buffer(self, buffer_size, .{ .transfer_dst_bit = true, .vertex_buffer_bit = true }, .{ .device_local_bit = true });
        const vertex_buffer = self.get_buffer(vertex_buffer_handle);

        try copy_buffer(self, staging_buffer.buf, vertex_buffer.buf, buffer_size);

        return vertex_buffer_handle;
    }

    pub fn createIndexBuffer(self: *Self, indices: []const u16) !ResourceHandle {
        const buffer_size: vk.DeviceSize = @sizeOf(u16) * indices.len;
        Logger.debug("creating index-buffer of size: {}\n", .{buffer_size});

        const staging_buffer_handle = try create_buffer(self, buffer_size, .{ .transfer_src_bit = true }, .{ .host_visible_bit = true, .host_coherent_bit = true });
        const staging_buffer = self.get_buffer(staging_buffer_handle);
        defer self.free_buffer_h(staging_buffer_handle);

        const data = try self.vkd.mapMemory(self.device, staging_buffer.mem, 0, buffer_size, .{});
        std.mem.copy(u8, @ptrCast([*]u8, data.?)[0..buffer_size], std.mem.sliceAsBytes(indices));
        self.vkd.unmapMemory(self.device, staging_buffer.mem);

        const index_buffer_handle = try create_buffer(self, buffer_size, .{ .transfer_dst_bit = true, .index_buffer_bit = true }, .{ .device_local_bit = true });
        const index_buffer = self.get_buffer(index_buffer_handle);

        try copy_buffer(self, staging_buffer.buf, index_buffer.buf, buffer_size);

        return index_buffer_handle;
    }

    inline fn create_uniform_buffer(self: *Self, buffer_size: vk.DeviceSize) !ResourceHandle {
        return try self.create_buffer(buffer_size, .{ .uniform_buffer_bit = true }, .{ .host_visible_bit = true, .host_coherent_bit = true });
    }

    inline fn create_storage_buffer(self: *Self, buffer_size: vk.DeviceSize) !ResourceHandle {
        return try self.create_buffer(buffer_size, .{ .storage_buffer_bit = true }, .{ .host_visible_bit = true, .host_coherent_bit = true });
    }

    fn create_descriptor_pool(self: *Self) !vk.DescriptorPool {
        const pool_sizes = [_]vk.DescriptorPoolSize{
            .{
                .type = .uniform_buffer,
                .descriptor_count = CFG.shader_uniform_buffer_descriptor_limit,
            },
            .{
                .type = .combined_image_sampler,
                .descriptor_count = CFG.shader_image_sampler_descriptor_limit,
            },
            .{
                .type = .storage_buffer,
                .descriptor_count = CFG.shader_storage_buffer_descriptor_limit,
            },
        };

        const pool_info = vk.DescriptorPoolCreateInfo{
            .flags = .{},
            .pool_size_count = pool_sizes.len,
            .p_pool_sizes = &pool_sizes,
            .max_sets = CFG.shader_descriptor_set_limit,
        };

        return try self.vkd.createDescriptorPool(self.device, &pool_info, null);
    }

    fn create_buffer(self: *Self, size: vk.DeviceSize, usage: vk.BufferUsageFlags, properties: vk.MemoryPropertyFlags) !ResourceHandle {
        Logger.debug("create buffer {}\n", .{ self.buffers.len });

        const buffer = try self.vkd.createBuffer(self.device, &.{
            .flags = .{},
            .size = size,
            .usage = usage,
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        }, null);

        const mem_requirements = self.vkd.getBufferMemoryRequirements(self.device, buffer);

        const buffer_memory = try self.vkd.allocateMemory(self.device, &.{
            .allocation_size = mem_requirements.size,
            .memory_type_index = try self.find_memory_type(mem_requirements.memory_type_bits, properties),
        }, null);
        try self.vkd.bindBufferMemory(self.device, buffer, buffer_memory, 0);

        try self.buffers.append(self.allocator, Buffer {
            .buf = buffer,
            .mem = buffer_memory
        });

        return ResourceHandle { .value = self.buffers.len - 1 };
    }

    // TODO(lm): use reference to buffer
    pub fn free_buffer(self: *Self, buffer: Buffer) void {
        Logger.debug("free buffer\n", .{});

        self.vkd.destroyBuffer(self.device, buffer.buf, null);
        // buffer.buf = undefined;
        self.vkd.freeMemory   (self.device, buffer.mem, null);
        // buffer.mem = undefined;
    }

    // TODO(lm): remove
    pub fn free_buffer_h(self: *Self, handle: ResourceHandle) void {
        self.free_buffer(self.get_buffer(handle));
    }

    fn get_buffer(self: *Self, handle: ResourceHandle) Buffer {
        return self.buffers.get(handle.value);
    }

    fn begin_single_time_commands(self: *Self) !vk.CommandBuffer {
        const alloc_info = vk.CommandBufferAllocateInfo{
            .level = .primary,
            .command_pool = self.command_pool,
            .command_buffer_count = 1,
        };

        var command_buffer: vk.CommandBuffer = undefined;
        try self.vkd.allocateCommandBuffers(self.device, &alloc_info, @ptrCast([*]vk.CommandBuffer, &command_buffer));

        const begin_info = vk.CommandBufferBeginInfo{
            .flags = .{ .one_time_submit_bit = true },
            .p_inheritance_info = null,
        };

        try self.vkd.beginCommandBuffer(command_buffer, &begin_info);

        return command_buffer;
    }

    fn end_single_time_commands(self: *Self, command_buffer: vk.CommandBuffer) !void {
        try self.vkd.endCommandBuffer(command_buffer);

        const submit_infos = [_]vk.SubmitInfo{.{
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &command_buffer),
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        }};
        try self.vkd.queueSubmit(self.graphics_queue, submit_infos.len, &submit_infos, .null_handle);
        try self.vkd.queueWaitIdle(self.graphics_queue);

        self.vkd.freeCommandBuffers(self.device, self.command_pool, 1, @ptrCast([*]const vk.CommandBuffer, &command_buffer));
    }

    fn copy_buffer(self: *Self, src_buffer: vk.Buffer, dst_buffer: vk.Buffer, size: vk.DeviceSize) !void {
        var command_buffer = try self.begin_single_time_commands();

        const copy_region = [_]vk.BufferCopy{.{
            .src_offset = 0,
            .dst_offset = 0,
            .size = size,
        }};
        self.vkd.cmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region);

        try self.end_single_time_commands(command_buffer);
    }

    fn find_memory_type(self: *Self, type_filter: u32, properties: vk.MemoryPropertyFlags) !u32 {
        const mem_properties = self.vki.getPhysicalDeviceMemoryProperties(self.physical_device);
        for (mem_properties.memory_types[0..mem_properties.memory_type_count], 0..) |mem_type, i| {
            if (type_filter & (@as(u32, 1) << @truncate(u5, i)) != 0 and mem_type.property_flags.contains(properties)) {
                return @truncate(u32, i);
            }
        }

        return error.NoSuitableMemoryType;
    }

    fn create_command_buffers(self: *Self) !void {
        self.command_buffers = try self.allocator.alloc(vk.CommandBuffer, CFG.MAX_FRAMES_IN_FLIGHT);

        try self.vkd.allocateCommandBuffers(self.device, &.{
            .command_pool = self.command_pool,
            .level = .primary,
            .command_buffer_count = @intCast(u32, self.command_buffers.?.len),
        }, self.command_buffers.?.ptr);
    }

    fn record_command_buffer(self: *Self, command_buffer: vk.CommandBuffer, image_index: u32, render_data: *const RenderData, info: *const ShaderInfo, internals: *ShaderInternals) !void {
        try self.vkd.beginCommandBuffer(command_buffer, &.{
            .flags = .{},
            .p_inheritance_info = null,
        });

        try self.update_shader_uniform_buffer(info, internals);

        const clear_values = [_]vk.ClearValue{
            .{ .color = .{ .float_32 = .{ 0, 0, 0, 1 } } },
            .{ .depth_stencil = .{ .depth = 1.0, .stencil = 0 } },
        };

        const render_pass_info = vk.RenderPassBeginInfo{
            .render_pass = internals.pipeline.render_pass,
            .framebuffer = self.swap_chain_framebuffers.?[image_index],
            .render_area = vk.Rect2D{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.swap_chain_extent,
            },
            .clear_value_count = clear_values.len,
            .p_clear_values = &clear_values,
        };

        self.vkd.cmdBeginRenderPass(command_buffer, &render_pass_info, .@"inline");
        {
            self.vkd.cmdBindPipeline(command_buffer, .graphics, internals.pipeline.pipeline);

            const viewports = [_]vk.Viewport{.{
                .x = 0,
                .y = 0,
                .width = @intToFloat(f32, self.swap_chain_extent.width),
                .height = @intToFloat(f32, self.swap_chain_extent.height),
                .min_depth = 0,
                .max_depth = 1,
            }};
            self.vkd.cmdSetViewport(command_buffer, 0, viewports.len, &viewports);

            const scissors = [_]vk.Rect2D{.{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.swap_chain_extent,
            }};
            self.vkd.cmdSetScissor(command_buffer, 0, scissors.len, &scissors);

            // TODO(lm):
            const scope_internals    = internals.get_scope(.global);
            const instance_internals = scope_internals.instances.get(0);
            _ = instance_internals;

            for (render_data.mesh_slice()) |mesh| {
                const offsets = [_]vk.DeviceSize{0};
                const vertex_buffers = [_]vk.Buffer{self.get_buffer(mesh.vertex_buffer).buf};
                const index_buffer = self.get_buffer(mesh.index_buffer).buf;
                const index_count = @intCast(u32, mesh.indices.len);

                self.vkd.cmdBindVertexBuffers(command_buffer, 0, 1, &vertex_buffers, &offsets);
                self.vkd.cmdBindIndexBuffer(command_buffer, index_buffer, 0, vk.IndexType.uint16);

                // self.vkd.cmdBindDescriptorSets(
                //     command_buffer,
                //     .graphics,
                //     internals.pipeline.pipeline_layout,
                //     0,
                //     1,
                //     @ptrCast([*]const
                //         vk.DescriptorSet,
                //         &instance_internals.descriptor_sets[self.current_frame]),
                //     0,
                //     undefined
                // );

                self.vkd.cmdDrawIndexed(command_buffer, index_count, 1, 0, 0, 0);
            }
        }
        self.vkd.cmdEndRenderPass(command_buffer);

        try self.vkd.endCommandBuffer(command_buffer);
    }

    fn create_sync_objects(self: *Self) !void {
        self.image_available_semaphores = try self.allocator.alloc(vk.Semaphore, CFG.MAX_FRAMES_IN_FLIGHT);
        self.render_finished_semaphores = try self.allocator.alloc(vk.Semaphore, CFG.MAX_FRAMES_IN_FLIGHT);
        self.in_flight_fences = try self.allocator.alloc(vk.Fence, CFG.MAX_FRAMES_IN_FLIGHT);

        var i: usize = 0;
        while (i < CFG.MAX_FRAMES_IN_FLIGHT) : (i += 1) {
            self.image_available_semaphores.?[i] = try self.vkd.createSemaphore(self.device, &.{ .flags = .{} }, null);
            self.render_finished_semaphores.?[i] = try self.vkd.createSemaphore(self.device, &.{ .flags = .{} }, null);
            self.in_flight_fences.?[i] = try self.vkd.createFence(self.device, &.{ .flags = .{ .signaled_bit = true } }, null);
        }
    }

    pub fn draw_frame(self: *Self, render_data: *const RenderData, info: *const ShaderInfo, internals: *ShaderInternals) !void {
        _ = try self.vkd.waitForFences(self.device, 1, @ptrCast([*]const vk.Fence, &self.in_flight_fences.?[self.current_frame]), vk.TRUE, std.math.maxInt(u64));

        const result = self.vkd.acquireNextImageKHR(self.device, self.swap_chain, std.math.maxInt(u64), self.image_available_semaphores.?[self.current_frame], .null_handle) catch |err| switch (err) {
            error.OutOfDateKHR => {
                try self.recreate_swap_chain();
                return;
            },
            else => |e| return e,
        };

        if (result.result != .success and result.result != .suboptimal_khr) {
            return error.ImageAcquireFailed;
        }

        try self.vkd.resetFences(self.device, 1, @ptrCast([*]const vk.Fence, &self.in_flight_fences.?[self.current_frame]));

        try self.vkd.resetCommandBuffer(self.command_buffers.?[self.current_frame], .{});
        try self.record_command_buffer(self.command_buffers.?[self.current_frame], result.image_index, render_data, info, internals);

        const wait_semaphores = [_]vk.Semaphore{self.image_available_semaphores.?[self.current_frame]};
        const wait_stages = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
        const signal_semaphores = [_]vk.Semaphore{self.render_finished_semaphores.?[self.current_frame]};

        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = wait_semaphores.len,
            .p_wait_semaphores = &wait_semaphores,
            .p_wait_dst_stage_mask = &wait_stages,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &self.command_buffers.?[self.current_frame]),
            .signal_semaphore_count = signal_semaphores.len,
            .p_signal_semaphores = &signal_semaphores,
        };
        _ = try self.vkd.queueSubmit(self.graphics_queue, 1, &[_]vk.SubmitInfo{submit_info}, self.in_flight_fences.?[self.current_frame]);

        const present_result = self.vkd.queuePresentKHR(self.present_queue, &.{
            .wait_semaphore_count = signal_semaphores.len,
            .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &signal_semaphores),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast([*]const vk.SwapchainKHR, &self.swap_chain),
            .p_image_indices = @ptrCast([*]const u32, &result.image_index),
            .p_results = null,
        }) catch |err| switch (err) {
            error.OutOfDateKHR => vk.Result.error_out_of_date_khr,
            else => return err,
        };

        if (present_result == .error_out_of_date_khr or present_result == .suboptimal_khr or self.window.framebuffer_resized) {
            self.window.framebuffer_resized = false;
            try self.recreate_swap_chain();
        } else if (present_result != .success) {
            return error.ImagePresentFailed;
        }

        self.current_frame = (self.current_frame + 1) % CFG.MAX_FRAMES_IN_FLIGHT;
    }

    fn create_shader_module(self: *Self, code: []const u8) !vk.ShaderModule {
        return try self.vkd.createShaderModule(self.device, &.{
            .flags = .{},
            .code_size = code.len,
            // NOTE (lm): added alignCast
            .p_code = @ptrCast([*]const u32, @alignCast(4, code)),
        }, null);
    }

    fn choose_swap_surface_format(available_formats: []vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
        for (available_formats) |available_format| {
            if (available_format.format == .b8g8r8a8_srgb and available_format.color_space == .srgb_nonlinear_khr) {
                return available_format;
            }
        }

        return available_formats[0];
    }

    fn choose_swap_present_mode(available_present_modes: []vk.PresentModeKHR) vk.PresentModeKHR {
        _ = available_present_modes;
        return .immediate_khr;
        // for (available_present_modes) |available_present_mode| {
        //     if (available_present_mode == .mailbox_khr) {
        //         return available_present_mode;
        //     }
        // }
        //
        // return .fifo_khr;
    }

    fn choose_swap_extent(self: *Self, capabilities: vk.SurfaceCapabilitiesKHR) !vk.Extent2D {
        if (capabilities.current_extent.width != 0xFFFF_FFFF) {
            return capabilities.current_extent;
        } else {
            const window_size = self.window.get_framebuffer_size();

            return vk.Extent2D{
                .width = std.math.clamp(window_size.width, capabilities.min_image_extent.width, capabilities.max_image_extent.width),
                .height = std.math.clamp(window_size.height, capabilities.min_image_extent.height, capabilities.max_image_extent.height),
            };
        }
    }

    fn query_swap_chain_support(self: *Self, device: vk.PhysicalDevice) !SwapChainSupportDetails {
        var details = SwapChainSupportDetails.init(self.allocator);

        details.capabilities = try self.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(device, self.surface);

        var format_count: u32 = undefined;
        _ = try self.vki.getPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &format_count, null);

        if (format_count != 0) {
            details.formats = try details.allocator.alloc(vk.SurfaceFormatKHR, format_count);
            _ = try self.vki.getPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &format_count, details.formats.?.ptr);
        }

        var present_mode_count: u32 = undefined;
        _ = try self.vki.getPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &present_mode_count, null);

        if (present_mode_count != 0) {
            details.present_modes = try details.allocator.alloc(vk.PresentModeKHR, present_mode_count);
            _ = try self.vki.getPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &present_mode_count, details.present_modes.?.ptr);
        }

        return details;
    }

    fn is_device_suitable(self: *Self, device: vk.PhysicalDevice) !bool {
        const indices = try self.find_queue_families(device);

        const extensions_supported = try self.check_device_extension_support(device);

        var swap_chain_adequate = false;
        if (extensions_supported) {
            const swap_chain_support = try self.query_swap_chain_support(device);
            defer swap_chain_support.deinit();

            swap_chain_adequate = swap_chain_support.formats != null and swap_chain_support.present_modes != null;
        }

        const supported_features = self.vki.getPhysicalDeviceFeatures(device);

        return indices.isComplete() and extensions_supported and swap_chain_adequate and supported_features.sampler_anisotropy == vk.TRUE;
    }

    fn check_device_extension_support(self: *Self, device: vk.PhysicalDevice) !bool {
        var extension_count: u32 = undefined;
        _ = try self.vki.enumerateDeviceExtensionProperties(device, null, &extension_count, null);

        const available_extensions = try self.allocator.alloc(vk.ExtensionProperties, extension_count);
        defer self.allocator.free(available_extensions);
        _ = try self.vki.enumerateDeviceExtensionProperties(device, null, &extension_count, available_extensions.ptr);

        const required_extensions = device_extensions[0..];

        for (required_extensions) |required_extension| {
            for (available_extensions) |available_extension| {
                const len = std.mem.indexOfScalar(u8, &available_extension.extension_name, 0).?;
                const available_extension_name = available_extension.extension_name[0..len];
                if (std.mem.eql(u8, std.mem.span(required_extension), available_extension_name)) {
                    break;
                }
            } else {
                return false;
            }
        }

        return true;
    }

    fn find_queue_families(self: *Self, device: vk.PhysicalDevice) !QueueFamilyIndices {
        var indices: QueueFamilyIndices = .{};

        var queue_family_count: u32 = 0;
        self.vki.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

        const queue_families = try self.allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
        defer self.allocator.free(queue_families);
        self.vki.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

        for (queue_families, 0..) |queue_family, i| {
            if (indices.graphics_family == null and queue_family.queue_flags.graphics_bit) {
                indices.graphics_family = @intCast(u32, i);
            } else if (indices.present_family == null and (try self.vki.getPhysicalDeviceSurfaceSupportKHR(device, @intCast(u32, i), self.surface)) == vk.TRUE) {
                indices.present_family = @intCast(u32, i);
            }

            if (indices.isComplete()) {
                break;
            }
        }

        return indices;
    }

    fn get_required_extensions(allocator: Allocator) !std.ArrayListAligned([*:0]const u8, null) {
        var extensions = std.ArrayList([*:0]const u8).init(allocator);
        try extensions.appendSlice(GlfwWindow.get_required_instance_extensions() orelse @panic("failed to get extensions"));

        if (CFG.enable_validation_layers) {
            try extensions.append(vk.extension_info.ext_debug_utils.name);
        }

        return extensions;
    }

    fn check_validation_layer_support(self: *Self) !bool {
        var layer_count: u32 = undefined;
        _ = try self.vkb.enumerateInstanceLayerProperties(&layer_count, null);

        var available_layers = try self.allocator.alloc(vk.LayerProperties, layer_count);
        defer self.allocator.free(available_layers);
        _ = try self.vkb.enumerateInstanceLayerProperties(&layer_count, available_layers.ptr);

        for (validation_layers) |layer_name| {
            var layer_found: bool = false;

            for (available_layers) |layer_properties| {
                const available_len = std.mem.indexOfScalar(u8, &layer_properties.layer_name, 0).?;
                const available_layer_name = layer_properties.layer_name[0..available_len];
                if (std.mem.eql(u8, std.mem.span(layer_name), available_layer_name)) {
                    layer_found = true;
                    break;
                }
            }

            if (!layer_found) {
                return false;
            }
        }

        return true;
    }

    fn debug_callback(severity: vk.DebugUtilsMessageSeverityFlagsEXT, _: vk.DebugUtilsMessageTypeFlagsEXT, p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT, _: ?*anyopaque) callconv(vk.vulkan_call_conv) vk.Bool32 {
        if (p_callback_data != null) {
            if (severity.verbose_bit_ext) {
                Logger.debug("DBG-CB: {s}\n", .{p_callback_data.?.p_message});
            } else if (severity.info_bit_ext) {
                Logger.info("DBG-CB: {s}\n", .{p_callback_data.?.p_message});
            } else if (severity.warning_bit_ext) {
                Logger.warn("DBG-CB: {s}\n", .{p_callback_data.?.p_message});
            } else {
                Logger.err("DBG-CB: {s}\n", .{p_callback_data.?.p_message});
                @panic("render-error occurred");
            }
        }

        return vk.FALSE;
    }

    // ------------------------------------------

    fn create_graphics_pipeline(
        self: *Self,
        render_pass: vk.RenderPass,
        descriptor_set_layouts: []const vk.DescriptorSetLayout,
        attribute_descriptions: []const vk.VertexInputAttributeDescription,
        push_constant_internals: []const PushConstantInternals
    ) !GraphicsPipeline {
        Logger.debug("create graphics-pipeline\n", .{});

        const vert_shader_module: vk.ShaderModule = try self.create_shader_module(&resources.vert_27);
        defer self.vkd.destroyShaderModule(self.device, vert_shader_module, null);
        const frag_shader_module: vk.ShaderModule = try self.create_shader_module(&resources.frag_27);
        defer self.vkd.destroyShaderModule(self.device, frag_shader_module, null);

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .flags = .{},
                .stage = .{ .vertex_bit = true },
                .module = vert_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
            .{
                .flags = .{},
                .stage = .{ .fragment_bit = true },
                .module = frag_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
        };

        // TODO(lm): don't hardcode
        const binding_description = Vertex.get_binding_description();

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo {
            .flags = .{},
            .vertex_binding_description_count   = 1,
            .p_vertex_binding_descriptions      = @ptrCast([*]const vk.VertexInputBindingDescription, &binding_description),
            .vertex_attribute_description_count = @intCast(u32, attribute_descriptions.len),
            .p_vertex_attribute_descriptions    = @ptrCast([*]const vk.VertexInputAttributeDescription ,attribute_descriptions),
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .flags = .{},
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .flags = .{},
            .viewport_count = 1,
            .p_viewports = undefined,
            .scissor_count = 1,
            .p_scissors = undefined,
        };

        const rasterizer = vk.PipelineRasterizationStateCreateInfo{
            .flags = .{},
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .cull_mode = .{ .back_bit = true },
            .front_face = .counter_clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1,
        };

        const multisampling = vk.PipelineMultisampleStateCreateInfo{
            .flags = .{},
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 1,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        const depth_stencil = vk.PipelineDepthStencilStateCreateInfo{
            .flags = .{},
            .depth_test_enable = vk.TRUE,
            .depth_write_enable = vk.TRUE,
            .depth_compare_op = vk.CompareOp.less,
            .depth_bounds_test_enable = vk.FALSE,
            .stencil_test_enable = vk.FALSE,
            .front = undefined,
            .back = undefined,
            .min_depth_bounds = 0,
            .max_depth_bounds = 1,
        };

        const color_blend_attachment = [_]vk.PipelineColorBlendAttachmentState{.{
            .blend_enable = vk.FALSE,
            .src_color_blend_factor = .one,
            .dst_color_blend_factor = .zero,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        }};

        const color_blending = vk.PipelineColorBlendStateCreateInfo{
            .flags = .{},
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = color_blend_attachment.len,
            .p_attachments = &color_blend_attachment,
            .blend_constants = [_]f32{ 0, 0, 0, 0 },
        };
        const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };

        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .flags = .{},
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        };

        // push constants
        // let mut push_constants: DynArray<vk::PushConstantRange, {config::VULKAN_SHADER_MAX_PUSH_CONSTANTS}> = DynArray::default();
        // for pcr in push_constant_infos {
        //     push_constants.push(vk::PushConstantRange::builder()
        //         .offset(pcr.range.offset as u32)
        //         .size(pcr.range.range as u32)
        //         .stage_flags(vk::ShaderStageFlags::ALL_GRAPHICS) // TODO: make selectable
        //         .build())
        // }

        var push_constant_ranges = PushConstantRangeStack{};
        for (push_constant_internals) |pci| {
            push_constant_ranges.push(vk.PushConstantRange {
                .offset = @intCast(u32, pci.range.offset),
                .size   = @intCast(u32, pci.range.size),
                // TODO(lm): make selectable
                .stage_flags = .{
                    // .all_graphics_bit = true,  // NOTE(lm): not working *shrug*
                    .vertex_bit = true,
                    .fragment_bit = true,
                },
            });
        }

        const pipeline_layout = try self.vkd.createPipelineLayout(self.device, &.{
            .flags = .{},
            .set_layout_count = @intCast(u32,descriptor_set_layouts.len),
            .p_set_layouts    = @ptrCast([*]const vk.DescriptorSetLayout, descriptor_set_layouts),
            .push_constant_range_count = @intCast(u32, push_constant_ranges.len),
            .p_push_constant_ranges    = @ptrCast([*]const vk.PushConstantRange, &push_constant_ranges.items_raw),
        }, null);

        const pipeline_info = [_]vk.GraphicsPipelineCreateInfo{.{
            .flags = .{},
            .stage_count = shader_stages.len,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input_info,
            .p_input_assembly_state = &input_assembly,
            .p_tessellation_state = null,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterizer,
            .p_multisample_state = &multisampling,
            .p_depth_stencil_state = &depth_stencil,
            .p_color_blend_state = &color_blending,
            .p_dynamic_state = &dynamic_state,
            .layout = pipeline_layout,
            .render_pass = render_pass,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        }};

        var pipeline: vk.Pipeline = undefined;
        _ = try self.vkd.createGraphicsPipelines(
            self.device,
            .null_handle,
            pipeline_info.len,
            &pipeline_info,
            null,
            @ptrCast([*]vk.Pipeline, &pipeline),
        );

        return GraphicsPipeline {
            .render_pass = render_pass,
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
        };
    }

    fn destroy_graphics_pipeline(self: *Self, pipeline: *GraphicsPipeline) void {
        Logger.debug("destroy graphics-pipeline\n", .{});

        self.vkd.destroyPipeline(self.device, pipeline.pipeline, null);
        self.vkd.destroyPipelineLayout(self.device, pipeline.pipeline_layout, null);
        self.vkd.destroyRenderPass(self.device, pipeline.render_pass, null);
    }

    // ------------------------------------------

    pub fn create_shader_internals(self: *Self, info: *const ShaderInfo, internals: *ShaderInternals) !void {
        Logger.debug("creating shader-program\n", .{});

        // TODO(lm):
        // errdefer self.destroy_shader_internals(&internals);

        // create attributes
        {
            var attr_stride: usize = 0;

            for (info.attributes.as_slice()) |attr| {
                internals.attributes.push(.{
                    .binding  = @intCast(u32, attr.binding),
                    .location = @intCast(u32, attr.location),
                    .format   = attr.format.to_vk_format(),
                    .offset   = @intCast(u32, attr_stride),
                });

                attr_stride += attr.format.size();
            }
        }

        // create uniform-buffer
        {
            var total_aligned_buffer_size: usize  = 0;

            // iterate all scopes except 'local'
            for (0..3) |scope_idx| {
                const scope_info = info.scopes[scope_idx];
                var scope_internals = &internals.scopes[scope_idx];
                scope_internals.buffer_offset = total_aligned_buffer_size;
                scope_internals.buffer_descriptor_type = .uniform_buffer;

                for (scope_info.buffers.as_slice()) |buff| {
                    scope_internals.buffer_instance_size_unalinged += buff.size;
                }

                // align buffer-instance-size
                while (scope_internals.buffer_instance_size_alinged < scope_internals.buffer_instance_size_unalinged) {
                    scope_internals.buffer_instance_size_alinged += CFG.vulkan_ubo_alignment;
                }

                total_aligned_buffer_size += scope_internals.buffer_instance_size_alinged * scope_info.instance_count;
            }

            Logger.debug("total uniform-buffer size: {} byte\n", .{total_aligned_buffer_size});

            const buffer_h                   = try self.create_uniform_buffer(total_aligned_buffer_size);
            internals.uniform_buffer         = self.get_buffer(buffer_h);
            internals.uniform_buffer_mapping = @ptrCast([*]u8,
                try self.vkd.mapMemory(self.device, internals.uniform_buffer.mem, 0, total_aligned_buffer_size, .{}),
            )[0..total_aligned_buffer_size];
        }

        // create storage-buffer
        {
            const scope_idx = @enumToInt(ShaderScope.local);
            var total_aligned_buffer_size: usize  = 0;

            const scope_info    = info.scopes[scope_idx];
            var scope_internals = &internals.scopes[scope_idx];

            scope_internals.buffer_descriptor_type = .storage_buffer;

            for (scope_info.buffers.as_slice()) |buff| {
                scope_internals.buffer_instance_size_unalinged += buff.size;
            }

            // align buffer-instance-size
            while (scope_internals.buffer_instance_size_alinged < scope_internals.buffer_instance_size_unalinged) {
                scope_internals.buffer_instance_size_alinged += CFG.vulkan_ubo_alignment;
            }

            total_aligned_buffer_size += scope_internals.buffer_instance_size_alinged * scope_info.instance_count;

            Logger.debug("total storage-buffer size: {} byte\n", .{total_aligned_buffer_size});

            // TODO(lm): consider making 'storage_buffer' nullable
            if (total_aligned_buffer_size > 0) {
                const buffer_h = try self.create_storage_buffer(total_aligned_buffer_size);
                internals.storage_buffer = self.get_buffer(buffer_h);
                internals.storage_buffer_mapping = @ptrCast([*]u8,
                    try self.vkd.mapMemory(self.device, internals.storage_buffer.mem, 0, total_aligned_buffer_size, .{}),
                )[0..total_aligned_buffer_size];
            }
        }

        // create descriptor-sets
        {
            internals.descriptor_pool = try self.create_descriptor_pool();

            for (info.scopes, 0..) |scope_info, idx| {
                // create layout
                // -------------
                var bindings = DescriptorSetLayoutBindingStack{};
                var scope_internals = &internals.scopes[idx];

                if (!scope_info.buffers.is_empty()) {
                    if (idx != @enumToInt(ShaderScope.local)) {
                        Logger.debug("add uniform-buffer to scope {} at binding {}\n", .{idx, BUFFER_BINDING_IDX});

                        // use uniform-buffers for non-local scopes
                        bindings.push(.{
                            .binding = BUFFER_BINDING_IDX,
                            .descriptor_count = 1,
                            .descriptor_type = .uniform_buffer,
                            .p_immutable_samplers = null,
                            .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
                        });
                    }
                    else {
                        Logger.debug("add storage-buffer to scope {} at binding {}\n", .{idx, BUFFER_BINDING_IDX});

                        // use storage-buffers for local scope
                        bindings.push(.{
                            .binding = BUFFER_BINDING_IDX,
                            .descriptor_count = 1,
                            .descriptor_type = .storage_buffer,
                            .p_immutable_samplers = null,
                            .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
                        });
                    }
                }

                if (!scope_info.samplers.is_empty()) {
                    Logger.debug("add sampler-layout to scope {} at binding {} with {} samplers\n", .{idx, IMAGE_SAMPLER_BINDING_IDX, scope_info.samplers.len});
                    bindings.push(.{
                        .binding = IMAGE_SAMPLER_BINDING_IDX,
                        .descriptor_count = @intCast(u32, scope_info.samplers.len),
                        .descriptor_type = .combined_image_sampler,
                        .p_immutable_samplers = null,
                        .stage_flags = .{ .fragment_bit = true },
                    });
                }

                // NOTE(lm): when there are no bindings, we are still creating an empty set, so that we don't have to use dynamic set indices
                //           -> set 0 is always 'global', set 3 is always 'local'
                const layout_info = vk.DescriptorSetLayoutCreateInfo {
                    .flags         = .{},
                    .binding_count = @intCast(u32, bindings.len),
                    .p_bindings    = if (bindings.is_empty()) null else &bindings.items_raw,
                };

                scope_internals.descriptor_set_layout = try self.vkd.createDescriptorSetLayout(self.device, &layout_info, null);
            }
        }

        // add push constants
        {
            Logger.debug("add local push constant\n", .{});

            var scope_internals = &info.scopes[@enumToInt(ShaderScope.local)]; if (!scope_internals.buffers.is_empty()) {
                const size_unaligned = @sizeOf(PushConstantData);
                const range = get_aligned_range(0, size_unaligned, CFG.vulkan_push_constant_alignment);
                internals.push_constant_internals.push(.{
                    .range = range,
                });
            }
        }

        var all_layouts: [4]vk.DescriptorSetLayout = undefined;
        inline for (0..4) |idx| {
            all_layouts[idx] = internals.scopes[idx].descriptor_set_layout;
        }

        internals.pipeline = try self.create_graphics_pipeline(
            self.render_pass,
            all_layouts[0..],
            internals.attributes.as_slice(),
            internals.push_constant_internals.as_slice());
    }

    pub fn destroy_shader_internals(self: *Self, internals: *ShaderInternals) void {
        Logger.debug("destroying shader-internals\n", .{});

        for (internals.scopes) |scope| {
            if (scope.descriptor_set_layout != .null_handle) {
                self.vkd.destroyDescriptorSetLayout(self.device, scope.descriptor_set_layout, null);
            }
        }

        if (internals.descriptor_pool != .null_handle) self.vkd.destroyDescriptorPool(self.device, internals.descriptor_pool, null);

        // cleanup uniform buffer
        self.vkd.unmapMemory(self.device, internals.uniform_buffer.mem);
        internals.uniform_buffer_mapping = undefined;
        self.free_buffer(internals.uniform_buffer);

        // cleanup storage buffer
        self.vkd.unmapMemory(self.device, internals.storage_buffer.mem);
        internals.storage_buffer_mapping = undefined;
        self.free_buffer(internals.storage_buffer);

        self.destroy_graphics_pipeline(&internals.pipeline);
    }

    pub fn get_shader_internals(self: *Self, internals_h: ResourceHandle) *ShaderInternals {
        return self.internals.get_mut(internals_h.value).*;
    }

    // TODO(lm): use actuall instance-idx
    fn update_shader_uniform_buffer(self: *Self, info: *const ShaderInfo, internals: *ShaderInternals) !void {
        const time: f32 = (@intToFloat(f32, (try std.time.Instant.now()).since(self.start_time)) / @intToFloat(f32, std.time.ns_per_s));

        var ubo = UniformBufferObject{
            .model = za.Mat4.identity().rotate(time * 90.0, za.Vec3.new(0.0, 0.0, 1.0)),
            .view = za.lookAt(za.Vec3.new(2, 2, 2), za.Vec3.new(0, 0, 0), za.Vec3.new(0, 0, 1)),
            .proj = za.perspective(45.0, @intToFloat(f32, self.swap_chain_extent.width) / @intToFloat(f32, self.swap_chain_extent.height), 0.1, 10),
        };
        ubo.proj.data[1][1] *= -1;

        const instance_h = ResourceHandle.zero;

        // update and bind global scope
        {
            self.shader_bind_scope(internals, .global, instance_h);
            self.shader_set_uniform_buffer(internals, &ubo);
            try self.shader_apply_uniform_scope(.global, instance_h, info, internals);
        }

        // update and bind .module scope
        {
            self.shader_bind_scope(internals, .module, instance_h);
            self.shader_set_uniform_buffer(internals, &ubo);
            try self.shader_apply_uniform_scope(.module, instance_h, info, internals);
        }

        // update and bind .unit scope
        {
            self.shader_bind_scope(internals, .unit, instance_h);
            self.shader_set_uniform_buffer(internals, &ubo);
            try self.shader_apply_uniform_scope(.unit, instance_h, info, internals);
        }

        // update and bind .local scope
        {
            self.shader_bind_scope(internals, .local, instance_h);
            self.shader_set_uniform_buffer(internals, &ubo);
            try self.shader_apply_uniform_scope(.local, instance_h, info, internals);
        }
    }

    pub fn shader_acquire_instance_resources(self: *const Self, info: *const ShaderInfo, internals: *ShaderInternals, scope: ShaderScope, default_image: ResourceHandle) !void {
        const scope_info    = &info.scopes[@enumToInt(scope)];
        var scope_internals = &internals.scopes[@enumToInt(scope)];

        Logger.debug("acquire instance resources for scope {} and instance {}\n", .{scope, scope_internals.instances.len});

        scope_internals.instances.push(ShaderInstanceInternals{});
        var instance_internals = scope_internals.instances.get_mut(scope_internals.instances.len - 1);

        // set all textures to the default texture
        // TODO(lm): actually use default-texture
        for (0..scope_info.samplers.len) |idx| {
            instance_internals.sampler_images[idx] = default_image;
        }

        // allocate descriptor-sets for this instance
        const layouts: [CFG.MAX_FRAMES_IN_FLIGHT]vk.DescriptorSetLayout = [_]vk.DescriptorSetLayout { scope_internals.descriptor_set_layout } ** CFG.MAX_FRAMES_IN_FLIGHT;

        const alloc_info = vk.DescriptorSetAllocateInfo {
            .descriptor_pool = internals.descriptor_pool,
            .descriptor_set_count = CFG.MAX_FRAMES_IN_FLIGHT,
            .p_set_layouts = &layouts,
        };

        try self.vkd.allocateDescriptorSets(self.device, &alloc_info, &instance_internals.descriptor_sets);
    }

    pub fn shader_bind_scope(_: *Self, internals: *ShaderInternals, scope: ShaderScope, instance_h: ResourceHandle) void {
        internals.bound_scope = scope;
        internals.bound_instance_h = instance_h;
    }

    /// scope and instance must be set before calling this function
    pub fn shader_set_uniform_sampler(_: *const Self, internals: *ShaderInternals, images_h: []const ResourceHandle) void {
        Logger.debug("set uniform sampler at scope {} and instance {} with {} images\n", .{internals.bound_scope, internals.bound_instance_h, images_h.len});

        // TODO(lm): validate dynamic length
        assert(images_h.len <= CFG.max_uniform_samplers_per_instance);

        const scope_internals    = &internals.scopes[@enumToInt(internals.bound_scope)];
        const instance_internals = scope_internals.instances.get_mut(internals.bound_instance_h.value);

        for (images_h, 0..) |image_h, idx| {
            instance_internals.sampler_images[idx] = image_h;
        }
    }

    // TODO(lm): think about storing the offset + stride in the instance struct
    // TODO(lm): make value dynamic
    /// update the uniform-buffer at the given location with new data
    pub fn shader_set_uniform_buffer(_: *const Self, internals: *const ShaderInternals, value: *const UniformBufferObject) void {
        const scope_internals = internals.scopes[@enumToInt(internals.bound_scope)];
        const start_index = scope_internals.buffer_offset * (internals.bound_instance_h.value + 1);
        const end_index   = start_index + @sizeOf(UniformBufferObject);

        const buffer_mapping = if (scope_internals.buffer_descriptor_type == .uniform_buffer) internals.uniform_buffer_mapping
                               else internals.storage_buffer_mapping;

        assert(@sizeOf(UniformBufferObject) < scope_internals.buffer_instance_size_alinged);

        @memcpy(
            buffer_mapping[start_index..end_index],
            std.mem.asBytes(value)
        );
    }

    /// updates and binds the specified descriptor sets
    pub fn shader_apply_uniform_scope(
        self: *Self,
        scope: ShaderScope,
        instance_h: ResourceHandle,
        info: *const ShaderInfo,
        internals: *const ShaderInternals,
    ) !void
    {
        const scope_info         = &info.scopes[@enumToInt(scope)];
        const scope_internals    = &internals.scopes[@enumToInt(scope)];
        const instance_internals = scope_internals.instances.get(instance_h.value);
        const descriptor_set     = instance_internals.descriptor_sets[self.current_frame];

        const buffer = if (scope_internals.buffer_descriptor_type == .uniform_buffer) &internals.uniform_buffer
                       else &internals.storage_buffer;

        const instance_offset = scope_internals.buffer_offset + (scope_internals.buffer_instance_size_alinged * instance_h.value);

        const buffer_info = [_]vk.DescriptorBufferInfo {.{
            .buffer = buffer.buf,
            .offset = instance_offset,
            .range  = scope_internals.buffer_instance_size_alinged,
        }};

        var image_info = DescriptorImageInfoStack {};

        for (scope_info.samplers.as_slice(), 0..) |_, idx| {
            const sampler_image_h = instance_internals.sampler_images[idx];
            assert(sampler_image_h.is_valid());
            const sampler_image = self.get_image(sampler_image_h);

            image_info.push(.{
                .image_layout = .shader_read_only_optimal,
                .image_view = sampler_image.view,
                .sampler = sampler_image.sampler.?, // TODO (lm): don't unwrap
            });
        }

        const descriptor_writes = [_]vk.WriteDescriptorSet{
            .{
                .dst_set = descriptor_set,
                .dst_binding = 0,
                .dst_array_element = 0,
                .descriptor_type = scope_internals.buffer_descriptor_type,
                .descriptor_count = 1,
                .p_buffer_info = &buffer_info,
                .p_image_info = undefined,
                .p_texel_buffer_view = undefined,
            },
            .{
                .dst_set = descriptor_set,
                .dst_binding = 1,
                .dst_array_element = 0,
                .descriptor_type = .combined_image_sampler,
                .descriptor_count = 1,
                .p_buffer_info = undefined,
                .p_image_info = &image_info.items_raw,
                .p_texel_buffer_view = undefined,
            },
        };

        // update descriptor set
        self.vkd.updateDescriptorSets(self.device, descriptor_writes.len, &descriptor_writes, 0, undefined);

        // bind descriptor set
        const command_buffer = self.command_buffers.?[self.current_frame];
        const first_set = @intCast(u32, scope_set_index(scope));
        self.vkd.cmdBindDescriptorSets(
            command_buffer,
            .graphics,
            internals.pipeline.pipeline_layout,
            first_set,
            1,
            @ptrCast([*]const
                vk.DescriptorSet,
                &instance_internals.descriptor_sets[self.current_frame]),
            0,
            undefined
        );
    }

    // ------------------------------------------
};
