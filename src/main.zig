const std = @import("std");
const VulkanBackend = @import("vulkan/backend.zig").VulkanBackend;



pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) std.log.err("MemLeak", .{});
    }
    const allocator = gpa.allocator();

    var app = VulkanBackend.init(allocator) catch |err| {
        std.log.err("application failed to init with error: {any}", .{err});
        return;
    };
    defer app.deinit();
    app.run() catch |err| {
        std.log.err("application exited with error: {any}", .{err});
        return;
    };
}

