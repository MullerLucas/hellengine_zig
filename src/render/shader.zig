const vk = @import("vulkan");

const render = @import("render.zig");
const core = @import("../core/core.zig");
const config = @import("../config.zig");

const NumberFormat = render.NumberFormat;
const ResourceHandle = core.ResourceHandle;
const Logger = core.log.scoped(.render);


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

pub const ShaderConfig = struct {
    attributes: ShaderAttributeInfoArray = .{},

    pub fn add_attribute(self: *ShaderConfig, format: NumberFormat, binding: usize, location: usize) void {
        Logger.debug("add attribute with format '{}', binding '{}' and location '{}'\n", .{format, binding, location});

        self.attributes.push(.{
            .format   = format,
            .binding  = binding,
            .location = location,
        });
    }
};

// ----------------------------------------------

pub const ShaderProgram = struct {
    config: ShaderConfig,
    /// data specific to the used backend
    internals_h: ResourceHandle = ResourceHandle.invalid,
};

// ----------------------------------------------

