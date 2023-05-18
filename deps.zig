// zig fmt: off
const std = @import("std");
const builtin = @import("builtin");
const string = []const u8;
const ModuleDependency = std.build.ModuleDependency;

pub const cache = ".zigmod/deps";

pub fn addAllTo(exe: *std.build.LibExeObjStep) void {
    checkMinZig(builtin.zig_version, exe);
    const b = exe.step.owner;
    @setEvalBranchQuota(1_000_000);
    for (packages) |pkg| {
        const moddep = pkg.zp(b);
        exe.addModule(moddep.name, moddep.module);
    }
    var llc = false;
    var vcpkg = false;
    inline for (comptime std.meta.declarations(package_data)) |decl| {
        const pkg = @as(Package, @field(package_data, decl.name));
        for (pkg.system_libs) |item| {
            exe.linkSystemLibrary(item);
            llc = true;
        }
        for (pkg.frameworks) |item| {
            if (!builtin.target.isDarwin()) @panic(b.fmt("a dependency is attempting to link to the framework {s}, which is only possible under Darwin", .{item}));
            exe.linkFramework(item);
            llc = true;
        }
        for (pkg.c_include_dirs) |item| {
            exe.addIncludePath(b.fmt("{s}/{s}", .{ @field(dirs, decl.name), item }));
            llc = true;
        }
        for (pkg.c_source_files) |item| {
            exe.addCSourceFile(b.fmt("{s}/{s}", .{ @field(dirs, decl.name), item }), pkg.c_source_flags);
            llc = true;
        }
        vcpkg = vcpkg or pkg.vcpkg;
    }
    if (llc) exe.linkLibC();
    if (builtin.os.tag == .windows and vcpkg) exe.addVcpkgPaths(.static) catch |err| @panic(@errorName(err));
}

pub const Package = struct {
    directory: string,
    pkg: ?Pkg = null,
    c_include_dirs: []const string = &.{},
    c_source_files: []const string = &.{},
    c_source_flags: []const string = &.{},
    system_libs: []const string = &.{},
    frameworks: []const string = &.{},
    vcpkg: bool = false,
    module: ?ModuleDependency = null,

    pub fn zp(self: *Package, b: *std.build.Builder) ModuleDependency {
        var temp: [100]ModuleDependency = undefined;
        const pkg = self.pkg.?;
        for (pkg.dependencies, 0..) |item, i| {
            temp[i] = item.zp(b);
        }
        if (self.module) |mod| {
            return mod;
        }
        const result = ModuleDependency{
            .name = pkg.name,
            .module = b.createModule(.{
                .source_file = pkg.source,
                .dependencies = b.allocator.dupe(ModuleDependency, temp[0..pkg.dependencies.len]) catch @panic("oom"),
            }),
        };
        self.module = result;
        return result;
    }
};

pub const Pkg = struct {
    name: string,
    source: std.build.FileSource,
    dependencies: []const *Package,
};

fn checkMinZig(current: std.SemanticVersion, exe: *std.build.LibExeObjStep) void {
    const min = std.SemanticVersion.parse("null") catch return;
    if (current.order(min).compare(.lt)) @panic(exe.step.owner.fmt("Your Zig version v{} does not meet the minimum build requirement of v{}", .{current, min}));
}

pub const dirs = struct {
    pub const _root = "";
    pub const _pyhxnurs24bq = cache ++ "/../..";
    pub const _csnhcd93wrg3 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _ejo6kd3iffi3 = cache ++ "/v/git/github.com/Vulfox/wavefront-obj/branch-stage2";
    pub const _al1d3deiv60z = cache ++ "/git/github.com/ziglibs/zlm";
    pub const _grvmsgjb9gdm = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _uxw7q1ovyv4z = cache ++ "/git/github.com/Snektron/vulkan-zig";
    pub const _2ql5xwn2ehqb = cache ++ "/git/github.com/nothings/stb";
};

pub const package_data = struct {
    pub var _pyhxnurs24bq = Package{
        .directory = dirs._pyhxnurs24bq,
    };
    pub var _csnhcd93wrg3 = Package{
        .directory = dirs._csnhcd93wrg3,
        .pkg = Pkg{ .name = "zalgebra", .source = .{ .path = dirs._csnhcd93wrg3 ++ "/src/main.zig" }, .dependencies = &.{} },
    };
    pub var _al1d3deiv60z = Package{
        .directory = dirs._al1d3deiv60z,
        .pkg = Pkg{ .name = "zlm", .source = .{ .path = dirs._al1d3deiv60z ++ "/src/zlm.zig" }, .dependencies = &.{} },
    };
    pub var _ejo6kd3iffi3 = Package{
        .directory = dirs._ejo6kd3iffi3,
        .pkg = Pkg{ .name = "wavefront-obj", .source = .{ .path = dirs._ejo6kd3iffi3 ++ "/wavefront-obj.zig" }, .dependencies = &.{ &_al1d3deiv60z } },
    };
    pub var _grvmsgjb9gdm = Package{
        .directory = dirs._grvmsgjb9gdm,
        .pkg = Pkg{ .name = "build_glfw", .source = .{ .path = dirs._grvmsgjb9gdm ++ "/build.zig" }, .dependencies = &.{} },
    };
    pub var _uxw7q1ovyv4z = Package{
        .directory = dirs._uxw7q1ovyv4z,
        .pkg = Pkg{ .name = "vk_gen", .source = .{ .path = dirs._uxw7q1ovyv4z ++ "/generator/index.zig" }, .dependencies = &.{} },
    };
    pub var _2ql5xwn2ehqb = Package{
        .directory = dirs._2ql5xwn2ehqb,
        .pkg = Pkg{ .name = "stb", .source = .{ .path = dirs._2ql5xwn2ehqb ++ "/''" }, .dependencies = &.{} },
    };
    pub var _root = Package{
        .directory = dirs._root,
    };
};

pub const packages = &[_]*Package{
    &package_data._csnhcd93wrg3,
    &package_data._ejo6kd3iffi3,
};

pub const pkgs = struct {
    pub const zalgebra = &package_data._csnhcd93wrg3;
    pub const wavefront_obj = &package_data._ejo6kd3iffi3;
};

pub const imports = struct {
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
    pub const vk_gen = @import(".zigmod/deps/git/github.com/Snektron/vulkan-zig/generator/index.zig");
    pub const vk_build = @import(".zigmod/deps/git/github.com/Snektron/vulkan-zig/build.zig");
    pub const stb = @import(".zigmod/deps/git/github.com/nothings/stb/''");
};
