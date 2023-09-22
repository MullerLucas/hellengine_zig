const std       = @import("std");
const vk        = @import("vulkan-zig");
const za        = @import("zalgebra");

const assert = std.debug.assert;

const engine         = @import("../../engine.zig");
const ResourceHandle = engine.core.core_types.ResourceHandle;
const Logger         = engine.core.log.scoped(.render);
const Geometry       = engine.resources.Geometry;

const corez      = @import("corez");
const StackArray = corez.collections.StackArray;


// ----------------------------------------------

pub const FrameNumber = usize;

// ----------------------------------------------

pub const GlobalShaderData = extern struct {
    view:       za.Mat4 align(16),
    proj:       za.Mat4 align(16),
    reserved_0: za.Mat4 align(16) = undefined,
    reserved_1: za.Mat4 align(16) = undefined,
};

// ----------------------------------------------

pub const SceneShaderData = extern struct {
    model:      za.Mat4 align(16),
    reserved_0: za.Mat4 align(16) = undefined,
    reserved_1: za.Mat4 align(16) = undefined,
    reserved_2: za.Mat4 align(16) = undefined,
};

// ----------------------------------------------

pub const RenderData = struct {
    pub const geometry_limit: usize = 1024;
    geometries: StackArray(*const Geometry, geometry_limit) = .{},
};

// ----------------------------------------------

pub const NumberFormat = enum {
    undefined,
    r32g32_sfloat,
    r32g32b32_sfloat,
    r32g32b32a32_sfloat,


    pub fn to_vk_format(self: NumberFormat) vk.Format {
        return switch (self) {
            .r32g32_sfloat       => .r32g32_sfloat,
            .r32g32b32_sfloat    => .r32g32b32_sfloat,
            .r32g32b32a32_sfloat => .r32g32b32a32_sfloat,
            else => .undefined,
        };
    }

    pub fn size(self: NumberFormat) usize {
        return switch (self) {
            .r32g32_sfloat       => @sizeOf(f32) * 2,
            .r32g32b32_sfloat    => @sizeOf(f32) * 3,
            .r32g32b32a32_sfloat => @sizeOf(f32) * 4,
            else => 0,
        };
    }
};

// ----------------------------------------------
