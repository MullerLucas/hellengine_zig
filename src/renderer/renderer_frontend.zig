
pub const RendererFrontend = struct {
    pub const Self = @This();


    pub fn init() Self {
        return Self{};
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
