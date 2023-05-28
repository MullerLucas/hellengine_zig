const vk = @import("vulkan");

const std = @import("std");

const render = @import("render.zig");
const core = @import("../core/core.zig");
const config = @import("../config.zig");

const NumberFormat = render.NumberFormat;
const ResourceHandle = core.ResourceHandle;
const Logger = core.log.scoped(.render);
const String = core.String;


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

pub const ShaderAttributeInfoArray = core.StackArray(ShaderAttributeInfo, config.shader_attribute_limit);

// ----------------------------------------------

pub const ShaderScope = enum(usize) {
    global   = 0,
    shared   = 1,
    instance = 2,
    local    = 3,
};

// ----------------------------------------------

pub const ShaderUniformInfo = struct {
    name: String,
    size: usize,
};

pub const ShaderUniformInfoArray = core.StackArray(ShaderUniformInfo, config.shader_attribute_limit);

// ----------------------------------------------

pub const ShaderScopeInfo = struct {
    buffers: ShaderUniformInfoArray = .{},
    samplers: ShaderUniformInfoArray = .{},
};

// ----------------------------------------------

pub const ShaderInfo = struct {
    attributes: ShaderAttributeInfoArray  = .{},
    scopes:     [4]ShaderScopeInfo = [_]ShaderScopeInfo { .{} } ** 4,

    pub fn deinit(self: *ShaderInfo) void {
        // TODO(lm): improve
        for (self.scopes) |scope| {
            for (scope.buffers.items) |buffer| {
                buffer.name.deinit();
            }
            for (scope.samplers.items) |sampler| {
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

    pub fn add_uniform(self: *ShaderInfo, allocator: std.mem.Allocator, scope: ShaderScope, name: []const u8, size: usize) !void {
        Logger.debug("add uniform-info with scope {}, name {s} and size {}\n", .{scope, name, size});

        self.scopes[@enumToInt(scope)].buffers.push(ShaderUniformInfo {
            .name = try String.from_slice(allocator, name),
            .size = size,
        });
    }
};

// ----------------------------------------------

pub const ShaderProgram = struct {
    info: ShaderInfo,
    /// data specific to the used backend
    internals_h: ResourceHandle = ResourceHandle.invalid,

    pub fn deinit(self: *ShaderProgram) void {
        self.info.deinit();
    }
};

// ----------------------------------------------

