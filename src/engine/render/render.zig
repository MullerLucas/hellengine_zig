pub const vulkan   = @import("vulkan/vulkan.zig");
pub const Renderer = @import("renderer.zig").Renderer;

const render_types            = @import("render_types.zig");
pub const UniformBufferObject = render_types.UniformBufferObject;
pub const Vertex              = render_types.Vertex;
pub const Mesh                = render_types.Mesh;
pub const MeshList            = render_types.MeshList;
pub const RenderData          = render_types.RenderData;
pub const NumberFormat        = render_types.NumberFormat;


pub const shader        = @import("shader.zig");
pub const ShaderProgram = shader.ShaderProgram;
pub const ShaderInfo  = shader.ShaderInfo;


pub const Logger = @import("../core/log.zig").scoped(.render);
