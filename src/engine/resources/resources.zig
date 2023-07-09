const std = @import("std");
const engine = @import("../engine.zig");
const vk = @import("vulkan");

const ResourceHandle = engine.core.ResourceHandle;

pub const obj_file = @import("obj_file.zig");
pub const Logger = @import("../core/core.zig").log.scoped(.resources);
pub const FrameNumber = engine.render.FrameNumber;

// @Todo
const backend_resources = if (true)
    engine.render.vulkan.resources
 else
    engine.render.vulkan.resources;


// ----------------------------------------------

pub const Vertex = struct {
    position: [3]f32 = .{ 0, 0, 0 },
    normal:   [3]f32 = .{ 0, 0, 0 },
    color:    [3]f32 = .{ 1, 1, 1 },
    uv:       [2]f32 = .{ 0, 0 },

    // @Todo: don't use vk stuff in here
    pub fn get_binding_description() vk.VertexInputBindingDescription {
        return vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .input_rate = .vertex,
        };
    }
};

// ----------------------------------------------

pub const RawImage = struct {
    width:    u32 = 0,
    height:   u32 = 0,
    channels: u32 = 0,
    pixels:   [*]u8 = undefined,
};

// ----------------------------------------------

pub const Texture = struct {
    pub const name_limit: usize = 128;

    path: [name_limit]u8 = undefined,
    internals: backend_resources.TextureInternals = .{},
};

// ----------------------------------------------

pub const IlluminationModel = enum(u8) {
    ColorOnAmbientOff                                         = 0,
    ColorOnAmbientOn                                          = 1,
    HighlightOn                                               = 2,
    ReflectionOnRayTraceOn                                    = 3,
    Transparency                                              = 4,
    ReflectionFresnelOnAndRayTraceOn                          = 5,
    TransparencyRefractionOnReflectionFresnelOffAndRayTraceOn = 6,
    TransparencyRefractionOnReflectionFresnelOnAndRayTraceOn  = 7,
    ReflectionOnAndRayTraceOff                                = 8,
    TransparencyGlassOnReflectionRayTraceOff                  = 9,
    CastsShadowsOntoInvisibleSurfaces                         = 10,
};

pub const MaterialInfo = struct {
    pub const MaterialName = engine.core.StackArray(u8, 512);

    name: MaterialName,
    /// *Ka*
    ambient_color:      [3]f32 = .{ 1.0, 1.0, 1.0 },
    /// *Kd*
    diffuse_color:      [3]f32 = .{ 0.0, 0.0, 0.0 },
    /// *Ks*
    specular_color:     [3]f32 = .{ 0.0, 0.0, 0.0 },
    /// *Ns*
    specular_exponent:  f32    = 1.0,
    /// *d* or *Tr*
    /// 1.0: fully opaque
    alpha:              f32    = 1.0,
    /// optical density: *Ni*
    /// 0.001 - 10.0
    /// 1.0: light does not bend as it passes through the object
    refraction_index:   f32     = 1.0,
    illumination_model: ?IlluminationModel = null,
};

pub const MaterialCreateInfo = struct {
    pub const List = std.ArrayList(MaterialCreateInfo);

    info:                   MaterialInfo,

    /// *map_Ka*
    ambient_color_map:      ?MaterialInfo.MaterialName = null,
    /// *map_Kd*
    diffuse_color_map:      ?MaterialInfo.MaterialName = null,
    /// *map_Ks*
    specular_color_map:     ?MaterialInfo.MaterialName = null,
    /// *map_Ns*
    specular_highlight_map: ?MaterialInfo.MaterialName = null,
    /// *map_d*
    alpha_map:              ?MaterialInfo.MaterialName = null,
    /// *map_bump* or *bump*
    bump_map:               ?MaterialInfo.MaterialName = null,
    /// *map_disp*
    displacement_map:       ?MaterialInfo.MaterialName = null,
    /// *decal*
    stencil_decal_map:      ?MaterialInfo.MaterialName = null,
};

// ----------------------------------------------

pub const Material = struct {
    pub const MaterialName = engine.core.StackArray(u8, 128);

    info:       MaterialInfo,
    program_h:  ResourceHandle,
    textures_h: [engine.config.max_uniform_samplers_per_instance]ResourceHandle = undefined,
    internals:  backend_resources.MaterialInternals = .{},

    frame_updated_at: FrameNumber = std.math.maxInt(FrameNumber),
};

// ----------------------------------------------

pub const GeometryConfig = struct {
    pub const IndexType = u32;
    vertices:   []Vertex,
    indices:    []IndexType,

    material_name: [512]u8,
    material_name_len: usize,

    // extends_min:
    // extends_max

    pub fn material_name_slice(self: *GeometryConfig) []const u8 {
        return self.material_name[0..self.material_name_len];
    }
};

// https://registry.khronos.org/vulkan/specs/1.3-khr-extensions/html/vkspec.html#vkCmdDrawIndexed
pub const Geometry = struct {
    pub const IndexType = u32;
    vertices:   []Vertex,
    indices:    []IndexType,

    // first_index is the base index within the index buffer.
    first_index: usize,
    /// index_count is the number of vertices to draw.
    index_count: usize,
    /// material used by this submesh
    material_h: ResourceHandle,

    internals: backend_resources.GeometryInternals = undefined,
};

