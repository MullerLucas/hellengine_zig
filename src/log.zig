const std = @import("std");


const ANSI_FG_BLACK   = "\x1b[30m";
const ANSI_FG_RED     = "\x1b[31m";
const ANSI_FG_GREEN   = "\x1b[32m";
const ANSI_FG_YELLOW  = "\x1b[33m";
const ANSI_FG_BLUE    = "\x1b[34m";
const ANSI_FG_MAGENTA = "\x1b[35m";
const ANSI_FG_CYAN    = "\x1b[36m";
const ANSI_FG_WHITE   = "\x1b[37m";
const ANSI_FG_DEFAULT = "\x1b[39m";

const ANSI_BG_BLACK   = "\x1b[40m";
const ANSI_BG_RED     = "\x1b[41m";
const ANSI_BG_GREEN   = "\x1b[42m";
const ANSI_BG_YELLOW  = "\x1b[43m";
const ANSI_BG_BLUE    = "\x1b[44m";
const ANSI_BG_MAGENTA = "\x1b[45m";
const ANSI_BG_CYAN    = "\x1b[46m";
const ANSI_BG_WHITE   = "\x1b[47m";
const ANSI_BG_DEFAULT = "\x1b[49m";



const LogLevel = enum {
    debug,
    info,
    warn,
    err,

    pub fn asText(comptime self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info  => "INFO ",
            .warn  => "WARN ",
            .err   => "ERROR",
        };
    }

    pub fn asFgColor(comptime self: LogLevel) []const u8 {
        return switch (self) {
            .debug => ANSI_FG_BLUE,
            .info  => ANSI_FG_GREEN,
            .warn  => ANSI_FG_YELLOW,
            .err   => ANSI_FG_RED,
        };
    }

    pub fn asBgColor(comptime self: LogLevel) []const u8 {
        return switch (self) {
            .debug => ANSI_BG_BLUE,
            .info  => ANSI_BG_GREEN,
            .warn  => ANSI_BG_YELLOW,
            .err   => ANSI_BG_RED,
        };
    }
};


fn log(
    comptime level: LogLevel,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype
) void {
    const color_set_txt   = comptime level.asFgColor();
    const color_reset_txt = ANSI_FG_DEFAULT;
    const scope_txt = "(" ++ @tagName(scope) ++ ")";
    const level_txt = "[" ++ comptime level.asText() ++ "]";

    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    const stderr = std.io.getStdErr().writer();

    nosuspend stderr.print(
        color_set_txt ++ level_txt ++ scope_txt ++ ": " ++ format ++ color_reset_txt,
        args
    ) catch return;
}

pub fn scoped(comptime scope: @TypeOf(.EnumLiteral)) type {
    return struct {
        /// Log an error message.
        pub fn err(comptime format: []const u8, args: anytype) void {
            @setCold(true);
            log(.err, scope, format, args);
        }

        /// Log an warning message.
        pub fn warn(comptime format: []const u8, args: anytype) void {
            log(.warn, scope, format, args);
        }

        /// Log an info message.
        pub fn info(comptime format: []const u8, args: anytype) void {
            log(.info, scope, format, args);
        }

        /// Log an debug message.
        pub fn debug(comptime format: []const u8, args: anytype) void {
            log(.debug, scope, format, args);
        }
    };
}
