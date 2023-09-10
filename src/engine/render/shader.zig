const vk     = @import("vulkan-zig");
const std    = @import("std");
const engine = @import("../../engine/engine.zig");

const ResourceHandle = engine.core.ResourceHandle;
const Logger         = engine.logging.scoped(.render);
const String         = engine.string.String;

const NumberFormat    = engine.render.NumberFormat;
const ShaderInternals = engine.render.vulkan.ShaderInternals;

const StackArray = engine.collections.StackArray;

// ----------------------------------------------

pub const ShaderAttribute = struct
{
    format: NumberFormat,
    binding: usize,
    layout: usize,
};

// ----------------------------------------------

pub const ShaderAttributeInfo = struct
{
    format: NumberFormat,
    binding: usize,
    location: usize,
};

pub const ShaderAttributeInfoArray = StackArray(ShaderAttributeInfo, engine.config.max_attributes_per_shader);

// ----------------------------------------------

pub const ShaderScope = enum(usize)
{
    global   = 0,
    scene    = 1,
    material = 2,
    object   = 3,
};

// ----------------------------------------------

pub const ShaderUniformInfo = struct
{
    name: String,
    size: usize,
};

pub const ShaderUniformInfoArray = StackArray(ShaderUniformInfo, engine.config.max_uniform_buffers_per_shader);

// ----------------------------------------------

pub const ShaderSamplerInfo = struct
{
    name: String,
};

pub const ShaderSamplerInfoArray = StackArray(ShaderSamplerInfo, engine.config.max_uniform_samplers_per_shader);

// ----------------------------------------------

pub const ShaderScopeInfo = struct
{
    buffers:  ShaderUniformInfoArray = .{},
    samplers: ShaderSamplerInfoArray = .{},
    instance_count: usize = 1,
};

// ----------------------------------------------

pub const ShaderInfo = struct
{
    attributes: ShaderAttributeInfoArray  = .{},
    scopes: [4]ShaderScopeInfo = [_]ShaderScopeInfo {
        .{ .instance_count = 1 },
        .{ .instance_count = engine.config.shader_scene_instance_limit },
        .{ .instance_count = engine.config.shader_material_instance_limit },
        .{ .instance_count = 1 },
    },

    pub fn deinit(self: *ShaderInfo) void
    {
        Logger.debug("deinitializing shader-info\n", .{});

        // TODO(lm): improve
        for (self.scopes) |scope|
        {
            for (scope.buffers.as_slice()) |buffer| {
                buffer.name.deinit();
            }
            for (scope.samplers.as_slice()) |sampler| {
                sampler.name.deinit();
            }
        }
    }

    pub fn add_attribute(self: *ShaderInfo, format: NumberFormat, binding: usize, location: usize) void
    {
        Logger.debug("add attribute with format {}, binding {} and location {}\n", .{format, binding, location});

        self.attributes.push(.{
            .format   = format,
            .binding  = binding,
            .location = location,
        });
    }

    pub fn add_uniform_buffer(self: *ShaderInfo, allocator: std.mem.Allocator, scope: ShaderScope, name: []const u8, size: usize) !void
    {
        Logger.debug("add uniform-info with scope {}, name {s} and size {}\n", .{scope, name, size});

        self.scopes[@intFromEnum(scope)].buffers.push(ShaderUniformInfo
        {
            .name = try String.from_slice(allocator, name),
            .size = size,
        });
    }

    pub fn add_uniform_sampler(self: *ShaderInfo, allocator: std.mem.Allocator, scope: ShaderScope, name: []const u8) !void {
        Logger.debug("add sampler-info with scope {}, name {s}\n", .{scope, name});

        self.scopes[@intFromEnum(scope)].samplers.push(ShaderSamplerInfo
        {
            .name = try String.from_slice(allocator, name),
        });
    }
};

// ----------------------------------------------

pub const ShaderProgram = struct
    {
    info: ShaderInfo,
    /// data specific to the used backend
    internals: ShaderInternals = undefined,

    pub fn deinit(self: *ShaderProgram) void
    {
        self.info.deinit();
    }
};

// ----------------------------------------------
