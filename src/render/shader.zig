const vk = @import("vulkan");

const std = @import("std");

const render = @import("render.zig");
const core = @import("../core/core.zig");
const config = @import("../config.zig");

const NumberFormat = render.NumberFormat;
const ResourceHandle = core.ResourceHandle;
const Logger = core.log.scoped(.render);
const String = core.String;

const vulkan = @import("vulkan/vulkan.zig");


pub const ShaderAttribute = struct {
    format: NumberFormat,
    binding: usize,
    layout: usize,
};

// ----------------------------------------------

pub const ShaderAttributeInfo = struct {
    format: NumberFormat,
    binding: usize,
    location: usize,
};

pub const ShaderAttributeInfoArray = core.StackArray(ShaderAttributeInfo, config.max_attributes_per_shader);

// ----------------------------------------------

pub const ShaderScope = enum(usize) {
    global        = 0,
    module        = 1,
    unit          = 2,
    local         = 3,
};

// ----------------------------------------------

pub const ShaderUniformInfo = struct {
    name: String,
    size: usize,
};

pub const ShaderUniformInfoArray = core.StackArray(ShaderUniformInfo, config.max_uniform_buffers_per_shader);

// ----------------------------------------------

pub const ShaderSamplerInfo = struct {
    name: String,
};

pub const ShaderSamplerInfoArray = core.StackArray(ShaderSamplerInfo, config.max_uniform_samplers_per_shader);

// ----------------------------------------------

pub const ShaderScopeInfo = struct {
    buffers:  ShaderUniformInfoArray = .{},
    samplers: ShaderSamplerInfoArray = .{},
    instance_count: usize = 1,
};

// ----------------------------------------------

pub const ShaderInfo = struct {
    attributes: ShaderAttributeInfoArray  = .{},
    scopes: [4]ShaderScopeInfo = [_]ShaderScopeInfo {
        .{ .instance_count = 1 },
        .{ .instance_count = 1 },
        .{ .instance_count = config.shader_instance_limit },
        .{ .instance_count = 1 },
    },

    pub fn deinit(self: *ShaderInfo) void {
        Logger.debug("deinitializing shader-info\n", .{});

        // TODO(lm): improve
        for (self.scopes) |scope| {
            for (scope.buffers.as_slice()) |buffer| {
                buffer.name.deinit();
            }
            for (scope.samplers.as_slice()) |sampler| {
                sampler.name.deinit();
            }
        }
    }

    pub fn add_attribute(self: *ShaderInfo, format: NumberFormat, binding: usize, location: usize) void {
        Logger.debug("add attribute with format {}, binding {} and location {}\n", .{format, binding, location});

        self.attributes.push(.{
            .format   = format,
            .binding  = binding,
            .location = location,
        });
    }

    pub fn add_uniform_buffer(self: *ShaderInfo, allocator: std.mem.Allocator, scope: ShaderScope, name: []const u8, size: usize) !void {
        Logger.debug("add uniform-info with scope {}, name {s} and size {}\n", .{scope, name, size});

        self.scopes[@enumToInt(scope)].buffers.push(ShaderUniformInfo {
            .name = try String.from_slice(allocator, name),
            .size = size,
        });
    }

    pub fn add_uniform_sampler(self: *ShaderInfo, allocator: std.mem.Allocator, scope: ShaderScope, name: []const u8) !void {
        Logger.debug("add sampler-info with scope {}, name {s}\n", .{scope, name});

        self.scopes[@enumToInt(scope)].samplers.push(ShaderSamplerInfo {
            .name = try String.from_slice(allocator, name),
        });
    }
};

// ----------------------------------------------

pub const ShaderProgram = struct {
    info: ShaderInfo,
    /// data specific to the used backend
    internals: vulkan.ShaderInternals = undefined,

    pub fn deinit(self: *ShaderProgram) void {
        self.info.deinit();
    }
};

// ----------------------------------------------

