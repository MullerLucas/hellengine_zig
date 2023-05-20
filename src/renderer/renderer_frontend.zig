const VulkanBackend = @import("../vulkan/backend.zig").VulkanBackend;
const Logger = @import("../core/log.zig").scoped(.renderer);



pub const RendererFrontend = struct {
    pub const Self = @This();

    backend: VulkanBackend = undefined,


    pub fn init() Self {
        Logger.info("Initializing renderer frontend", .{});

        var result = Self{};
        result.backend = VulkanBackend.init();
        return result;
    }

    pub fn deinit(self: *Self) void {
        Logger.info("Deinitializing renderer frontend", .{});
        self.backend.deinit();
    }
};
