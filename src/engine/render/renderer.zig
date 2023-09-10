const std    = @import("std");
const c      = @import("../c.zig");
const engine = @import("../engine.zig");

const ResourceHandle = engine.core.ResourceHandle;
const FrameTimer     = engine.core.time.FrameTimer(4096);

const VulkanBackend = engine.render.vulkan.VulkanBackend;

const Logger     = engine.render.Logger;
const RenderData = engine.render.RenderData;

const GlfwWindow    = engine.render.GlfwWindow;
const ShaderScope   = engine.render.shader.ShaderScope;
const ShaderProgram = engine.render.shader.ShaderProgram;
const ShaderInfo    = engine.render.shader.ShaderInfo;

const Vertex             = engine.resources.Vertex;
const Texture            = engine.resources.Texture;
const Material           = engine.resources.Material;
const MaterialCreateInfo = engine.resources.MaterialCreateInfo;
const Geometry           = engine.resources.Geometry;
const GeometryConfig     = engine.resources.GeometryConfig;
const GeometryInternals  = engine.render.vulkan.resources.GeometryInternals;

const ObjFace                    = engine.resources.obj_file.ObjFace;
const ObjParseState              = engine.resources.obj_file.ObjFileParseState;
const ObjFileParseResult         = engine.resources.obj_file.ObjFileParseResult;
const ObjFileLoader              = engine.resources.obj_file.ObjFileLoader;
const ObjMaterialFileParseResult = engine.resources.obj_file.ObjMaterialFileParseResult;




// ----------------------------------------------

pub const Renderer = struct
{
    // @Todo: come up with sensible values
    const geometry_limit: usize = 1024;
    const texture_limit:  usize = 1024;
    const material_limit: usize = 1024;
    const program_limit:  usize = 1024;

    allocator:   std.mem.Allocator,
    frame_timer: FrameTimer,
    backend:     VulkanBackend,
    geometries:  engine.core.StackArray(Geometry, geometry_limit) = .{},
    textures:    engine.core.StackArray(Texture,  texture_limit) = .{},
    materials:   engine.core.StackArray(Material, material_limit) = .{},
    programs:    engine.core.StackArray(*ShaderProgram, program_limit) = .{},

    current_frame: usize = 0,


    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !Renderer
    {
        Logger.info("initializing renderer-frontend\n", .{});

        var timer = try engine.core.time.SimpleTimer.init();
        defer Logger.debug("renderer initialized in {} us\n", .{timer.read_us()});

        var self = Renderer {
            .allocator   = allocator,
            .frame_timer = try FrameTimer.init(),
            .backend     = try VulkanBackend.init(allocator, window),
        };

        try self.create_default_material();
        return self;
    }

    pub fn deinit(self: *Renderer) void
    {
        Logger.info("deinitializing renderer-frontend\n", .{});

        // @Hack
        for (0..self.textures.len) |idx|
        {
            self.destroy_texture(ResourceHandle { .value = idx });
        }

        self.backend.deinit();
    }

    pub fn begin_frame(self: *Renderer) void
    {
        self.current_frame += 1;
    }

    pub fn end_frame(self: *Renderer) void
    {
        _ = self;
    }

    pub fn draw_geometries(self: *Renderer, geometries_h: []const ResourceHandle, program: *ShaderProgram) !void
    {
        if (self.frame_timer.is_frame_0()) {
            Logger.debug("Timings - frame (us): {}\n", .{self.frame_timer.avg_frame_time_us()});
        }

        // @Perf: order geometries in a useful way
        var render_data = RenderData {};
        for (geometries_h) |geometry_h|
        {
            render_data.geometries.push(self.get_geometry(geometry_h));
        }

        // start frame
        self.frame_timer.start_frame();
        try self.backend.start_render_pass(&program.info, &program.internals);

        // iterate geometries
        for (render_data.geometries.as_slice(), 0..) |geometry, idx|
        {
            try self.backend.upload_shader_data(&program.internals, geometry, idx);

            // @Perf: don't switch materials on a per geometry basis
            const material = self.get_material_mut(geometry.material_h);
            try self.backend.shader_apply_material(program, material, self.current_frame);

            try self.backend.draw_geometry(geometry);
        }

        // end frame
        try self.backend.submit_render_pass();
        self.frame_timer.stop_frame();
    }

    pub fn device_wait_idle(self: *Renderer) !void
    {
        try self.backend.wait_device_idle();
    }

    // ------------------------------------------

    pub fn create_shader_program(self: *Renderer, info: ShaderInfo) !ResourceHandle
    {
        const program_h = ResourceHandle { .value = self.programs.len };
        Logger.debug("creating shader-program '{}'\n", .{program_h.value});

        var program = try self.allocator.create(ShaderProgram);
        program.* = ShaderProgram {
            .info = info,
        };
        self.programs.push(program);

        try self.backend.create_shader_internals(&info, &program.internals);
        return program_h;
    }

    pub fn destroy_shader_program(self: *Renderer, program_h: ResourceHandle) void
    {
        Logger.debug("destroy shader-program\n", .{});

        const program = self.get_shader_program_mut(program_h);
        self.backend.destroy_shader_internals(&program.internals);
        program.deinit();
        self.allocator.destroy(program);
    }

    pub fn get_shader_program(self: *const Renderer, program_h: ResourceHandle) *const ShaderProgram
    {
        return self.programs.get(program_h.value).*;
    }

    pub fn get_shader_program_mut(self: *Renderer, program_h: ResourceHandle) *ShaderProgram
    {
        return self.programs.get_mut(program_h.value).*;
    }

    // ------------------------------------------

    // @Todo: move somewhere else
    pub fn create_raw_image_from_file(path: [*:0]const u8) !engine.resources.RawImage
    {
        var width:    c_int = undefined;
        var height:   c_int = undefined;
        var channels: c_int = undefined;

        var pixels: ?[*]u8 = c.stbi_load(path, &width, &height, &channels, c.STBI_rgb_alpha);
        errdefer c.stbi_image_free(pixels);

        if (pixels == null)
        {
            Logger.err("failed to load image '{s}'\n", .{path});
            return error.ImageLoadFailure;
        }

        return engine.resources.RawImage {
            .width  = @intCast(width),
            .height = @intCast(height),
            .pixels = pixels.?,
        };
    }

    // @Todo: move somewhere else
    pub fn destroy_raw_image(image: *engine.resources.RawImage) void
    {
        c.stbi_image_free(image.pixels);
    }

    pub fn create_texture(self: *Renderer, path: [*:0]const u8) !ResourceHandle
    {
        const texture_h = ResourceHandle { .value = self.textures.len };
        Logger.debug("create texture '{}' from path '{s}\n", .{texture_h.value, path});

        self.textures.push(Texture { });
        const texture = self.get_texture_mut(texture_h);

        // create internals
        {
            var raw_image = try Renderer.create_raw_image_from_file(path);
            defer Renderer.destroy_raw_image(&raw_image);
            try self.backend.create_texture_internals(texture, &raw_image);
        }

        // @Todo: think about using a string
        // set path
        {
            const path_len = std.mem.indexOfSentinel(u8, 0, path);
            std.debug.assert(path_len <= Texture.name_limit);
            @memcpy(texture.path[0..path_len], path[0..path_len]);
        }

        return texture_h;
    }

    pub fn destroy_texture(self: *Renderer, texture_h: ResourceHandle) void
    {
        Logger.debug("destroy texture '{}'\n", .{texture_h.value});
        const texture = self.get_texture_mut(texture_h);
        self.backend.destroy_texture_internals(texture);
    }

    pub fn get_texture(self: *const Renderer, texture_h: ResourceHandle) *const Texture
    {
        return self.textures.get(texture_h.value);
    }

    pub fn get_texture_mut(self: *Renderer, texture_h: ResourceHandle) *Texture
    {
        return self.textures.get_mut(texture_h.value);
    }

    // ------------------------------------------

    pub fn create_material(self: *Renderer, program_h: ResourceHandle, create_info: *const MaterialCreateInfo) !ResourceHandle
    {
        const material_h = ResourceHandle { .value = self.materials.len };
        Logger.debug("creating material '{}'\n", .{material_h.value});

        self.materials.push(Material {
            .info      = create_info.info,
            .program_h = program_h,
        });
        const material = self.get_material_mut(material_h);

        // @Hack
        material.textures_h[0] = try self.create_texture(create_info.diffuse_color_map.?.as_sentinel_ptr(0));

        const program = self.get_shader_program_mut(program_h);
        try self.backend.create_material_internals(program, material, Renderer.get_default_material());
        // @Hack
        _ = try self.backend.shader_acquire_instance_resources(&program.info, &program.internals, .global, Renderer.get_default_material());
        _ = try self.backend.shader_acquire_instance_resources(&program.info, &program.internals, .scene,  Renderer.get_default_material());

        const texture = self.get_texture(material.textures_h[0]);
        self.backend.shader_set_material_texture_image(&program.internals, &material.internals, &texture.internals);

        return material_h;
    }

    pub fn destroy_material(self: *Renderer, material_h: ResourceHandle) void
    {
        Logger.debug("destroying material '{}'\n", .{material_h.value});
        const material = self.get_material_mut(material_h);
        self.backend.destroy_material_internals(material);
        material.internals = undefined;
    }

    // @Todo: actually implement
    pub fn create_default_material(_: *Renderer) !void
    {
        Logger.err("@Todo: create default material\n", .{});
    }

    // @Todo: actually implement
    pub fn get_default_material() ResourceHandle
    {
        return ResourceHandle.zero;
    }

    pub fn get_material(self: *Renderer, material_h: ResourceHandle) *const Material
    {
        return self.materials.get(material_h.value);
    }

    pub fn get_material_mut(self: *Renderer, material_h: ResourceHandle) *Material
    {
        return self.materials.get_mut(material_h.value);
    }

    // @Todo: actually implement
    pub fn find_material(self: *const Renderer, material_name: []const u8) ?ResourceHandle
    {
        for (self.materials.as_slice(), 0..) |material, idx| {
            if (material.info.name.eql_slice(material_name)) {
                // @Hack
                return ResourceHandle { .value = idx };
            }
        }
        return null;
    }

    // ------------------------------------------

    pub fn create_geometries_from_file(self: *Renderer, path: []const u8, program_h: ResourceHandle) !std.ArrayList(ResourceHandle)
    {
        Logger.debug("creating geometry '{}' from file '{s}'\n", .{self.geometries.len, path});

        const geo_file = std.fs.cwd().openFile(path, .{}) catch |err| {
            Logger.err("failed to open obj file '{s}'\n", .{path});
            return err;
        };
        defer geo_file.close();
        var geo_reader = std.io.bufferedReader(geo_file.reader());

        var geo_result = ObjFileParseResult.init(self.allocator);
        try ObjFileLoader.parse_obj_file(self.allocator, geo_reader.reader(), &geo_result);
        defer geo_result.deinit();

        // create materials
        if (geo_result.matlib_path) |_| {
            const dirname = std.fs.path.dirname(path).?;

            // const qualified_path = try std.fs.path.join(self.allocator, &[_][]const u8 {dirname, matlib_path.as_slice()});
            geo_result.matlib_path.?.insert_slices(0, &.{dirname, "/"});
            const matlib_path = geo_result.matlib_path.?.as_slice();

            // const mat_file = std.fs.cwd().openFile(geo_result.matlib_path.?.as_slice(), .{}) catch |err| {
            const mat_file = std.fs.cwd().openFile(matlib_path, .{}) catch |err| {
                Logger.err("failed to open matlib file '{s}'\n", .{matlib_path});
                return err;
            };
            defer mat_file.close();
            var mat_reader = std.io.bufferedReader(mat_file.reader());

            var mat_result = ObjMaterialFileParseResult.init(self.allocator);
            defer mat_result.deinit();
            try ObjFileLoader.parse_obj_material_file(self.allocator, mat_reader.reader(), &mat_result, dirname);

            // @Todo: use mat_result
            for (mat_result.create_infos.items) |create_info| {
                // @Perf: copy?
                _ = try self.create_material(program_h, &create_info);
            }
        }

        // create geometries
        var geometries_h = try std.ArrayList(ResourceHandle).initCapacity(self.allocator, geo_result.geometry_configs.items.len);
        for (0..geo_result.geometry_configs.items.len) |idx| {
            var config = geo_result.geometry_configs.items[idx];

            try geometries_h.append(try self.create_geometry(&config));
        }

        return geometries_h;
    }

    pub fn create_geometry(self: *Renderer, config: *GeometryConfig) !ResourceHandle
    {
        var internals = GeometryInternals { };
        try self.backend.create_geometry_internals(config, &internals);

        var material_h = self.find_material(config.material_name_slice());

        // @Todo
        if (material_h == null) {
            Logger.err("could not find material '{s}'\n", .{config.material_name_slice()});
            material_h = Renderer.get_default_material();
        }

        var geometry = Geometry {
            .vertices = config.vertices,
            .indices  = config.indices,

            .first_index = 0,
            .index_count = config.indices.len,
            .material_h  = material_h.?,
            .internals   = internals,
        };

        self.geometries.push(geometry);

        return ResourceHandle { .value = self.geometries.len - 1 };
    }

    pub fn destroy_geometry(self: *Renderer, geometry_h: ResourceHandle) void
    {
        const geometry = self.get_geometry_mut(geometry_h);

        self.backend.destroy_geometry_internals(geometry);

        self.allocator.free(geometry.vertices);
        self.allocator.free(geometry.indices);
    }

    pub fn get_geometry(self: *const Renderer, geometry_h: ResourceHandle) *const Geometry
    {
        return self.geometries.get(geometry_h.value);
    }

    pub fn get_geometry_mut(self: *Renderer, geometry_h: ResourceHandle) *Geometry
    {
        return self.geometries.get_mut(geometry_h.value);
    }
};

