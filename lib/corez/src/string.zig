const engine = @import("../engine.zig");
const Logger = engine.core.log.scoped(.string);

pub usingnamespace @import("./string/static_string.zig");
pub usingnamespace @import("./string/dynamic_string.zig");
