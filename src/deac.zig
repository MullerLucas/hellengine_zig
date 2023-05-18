const std  = @import("std");
const glfw = @import("glfw");
const vk   = @import("vulkan");

const WIDTH:  u32 = 800;
const HEIGHT: u32 = 600;

const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
});

const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
});

// ----------------------------------------------

const TutorialApp = struct {
    const Self = @This();

    window: ?glfw.Window = null,
    vkb: BaseDispatch = undefined,
    vki: InstanceDispatch = undefined,
    instance: vk.Instance = .null_handle,



    pub fn init() Self {
        return Self { };
    }

    pub fn run(self: *Self) !void {
        try self.initWindow();
        try self.initVulkan();
        try self.mainLoop();
    }

    fn initWindow(self: *Self) !void {
        _ = glfw.init(.{});

        self.window = glfw.Window.create(WIDTH, HEIGHT, "Tutorial-App", null, null, .{
            .client_api = .no_api,
            .resizable = false,
        });
    }

    fn initVulkan(self: *Self) !void {
        try self.createInstance();
    }

    fn mainLoop(self: *Self) !void {
        while (!self.window.?.shouldClose()) {
            glfw.pollEvents();
        }
    }

    fn deinit(self: *Self) void {
        if (self.instance != .null_handle) { self.vki.destroyInstance(self.instance, null); }
        if (self.window   != null        ) { self.window.?.destroy(); }

        glfw.terminate();
    }

    fn createInstance(self: *Self) !void {
        const vk_proc = @ptrCast(*const fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.C) vk.PfnVoidFunction, &glfw.getInstanceProcAddress);
        self.vkb = try BaseDispatch.load(vk_proc);

        const app_info = vk.ApplicationInfo {
            .p_application_name = "Tutorial-App",
            .application_version = vk.makeApiVersion(1, 0, 0, 0),
            .p_engine_name = "No Engine",
            .engine_version = vk.makeApiVersion(1, 0, 0, 0),
            .api_version   = vk.API_VERSION_1_2,
        };

        const glfw_extensions = glfw.getRequiredInstanceExtensions();

        self.instance = try self.vkb.createInstance(&.{
            .flags = .{},
            .p_application_info = &app_info,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
            .enabled_extension_count = @intCast(u32, glfw_extensions.len),
            .pp_enabled_extension_names = glfw_extensions.ptr,
        }, null);

        self.vki = try InstanceDispatch.load(self.instance, vk_proc);
    }
};



pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var app = TutorialApp.init();
    defer app.deinit();

    app.run() catch |err| {
        std.log.err("application exited with error: {any}", .{err});
        return;
    };
}
