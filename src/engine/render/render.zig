pub const vulkan   = @import("vulkan/vulkan.zig");
pub const Renderer = @import("renderer.zig").Renderer;

const render_types            = @import("render_types.zig");
pub const SceneShaderData = render_types.SceneShaderData;
pub const GlobalShaderData = render_types.GlobalShaderData;
pub const RenderData          = render_types.RenderData;
pub const NumberFormat        = render_types.NumberFormat;
pub const FrameNumber         = render_types.FrameNumber;

pub const shader        = @import("shader.zig");
pub const ShaderProgram = shader.ShaderProgram;
pub const ShaderInfo  = shader.ShaderInfo;


pub const Logger = @import("../core/log.zig").scoped(.render);
