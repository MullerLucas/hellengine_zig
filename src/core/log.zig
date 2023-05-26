const std = @import("std");


pub const AnsiColor8 = enum(u8) {
    black = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,
    default = 9,

    fn as_fg_str(comptime self: AnsiColor8) []const u8 {
        return std.fmt.comptimePrint("\x1b[3{}m", .{ @enumToInt(self) });
    }

    fn as_bg_str(comptime self: AnsiColor8) []const u8 {
        return std.fmt.comptimePrint("\x1b[4{}m", .{ @enumToInt(self) });
    }
};

const ANSI_256_FG_RED = "\x1b[38;5;196m";




pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,

    pub fn as_text(comptime self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info  => "INFO ",
            .warn  => "WARN ",
            .err   => "ERROR",
        };
    }

    pub fn as_color(comptime self: LogLevel) AnsiColor8 {
        return switch (self) {
            .debug => AnsiColor8.blue,
            .info  => AnsiColor8.green,
            .warn  => AnsiColor8.yellow,
            .err   => AnsiColor8.red,
        };
    }
};


pub fn scoped(comptime scope: @TypeOf(.EnumLiteral)) type {
    return struct {
        const Self = @This();

        pub fn log(
            comptime level: LogLevel,
            comptime format: []const u8,
            args: anytype
        ) void {
            const scope_txt = "(" ++ @tagName(scope) ++ ")";
            const level_txt = "[" ++ comptime level.as_text() ++ "]";

            std.debug.getStderrMutex().lock();
            defer std.debug.getStderrMutex().unlock();
            const stderr = std.io.getStdErr().writer();

            nosuspend stderr.print(
                comptime level.as_color().as_fg_str() ++
                level_txt ++
                scope_txt ++
                ": " ++
                format ++
                AnsiColor8.default.as_fg_str(),
                args
            ) catch return;
        }

        /// Log an error message.
        pub fn err(comptime format: []const u8, args: anytype) void {
            @setCold(true);
            Self.log(.err, format, args);
        }

        /// Log an warning message.
        pub fn warn(comptime format: []const u8, args: anytype) void {
            Self.log(.warn, format, args);
        }

        /// Log an info message.
        pub fn info(comptime format: []const u8, args: anytype) void {
            Self.log(.info, format, args);
        }

        /// Log an debug message.
        pub fn debug(comptime format: []const u8, args: anytype) void {
            Self.log(.debug, format, args);
        }
    };
}
