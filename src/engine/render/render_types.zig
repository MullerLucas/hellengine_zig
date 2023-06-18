const std = @import("std");
const vk  = @import("vulkan");
const za  = @import("zalgebra");
const core_types = @import("../core/core_types.zig");
const ResourceHandle = core_types.ResourceHandle;

const engine = @import("../../engine/engine.zig");
const Mesh = engine.resources.Mesh;

const core = @import("../core/core.zig");
const config = @import("../config.zig");
const Logger = core.log.scoped(.render);

const assert = std.debug.assert;

// ----------------------------------------------

pub const FrameNumber = usize;

// ----------------------------------------------

// TODO(lm): make sure that 'extern' makes sense
pub const GlobalShaderData = extern struct {
    view:  za.Mat4 align(16),
    proj:  za.Mat4 align(16),
    reserved_0: za.Mat4 align(16) = undefined,
    reserved_1: za.Mat4 align(16) = undefined,
};

// ----------------------------------------------

// TODO(lm): make sure that 'extern' makes sense
pub const SceneShaderData = extern struct {
    model: za.Mat4 align(16),
    reserved_0: za.Mat4 align(16) = undefined,
    reserved_1: za.Mat4 align(16) = undefined,
    reserved_2: za.Mat4 align(16) = undefined,
};

// ----------------------------------------------

pub const RenderData = struct {
    pub const mesh_limit: usize = 1024;
    meshes: core.StackArray(*const Mesh, mesh_limit) = .{},
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
        return switch (self){
            .r32g32_sfloat       => @sizeOf(f32) * 2,
            .r32g32b32_sfloat    => @sizeOf(f32) * 3,
            .r32g32b32a32_sfloat => @sizeOf(f32) * 4,
            else => 0,
        };
    }
};

// ----------------------------------------------
