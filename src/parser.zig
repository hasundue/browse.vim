const std = @import("std");
const m = @import("mecha");

const testing = std.testing;
const debug = std.debug;

//
// Grammer for HTML
//
const doc = m.combine(.{ doctype, html });

const doctype = start("!DOCTYPE html");

const html = m.combine(.{ m.opt(head), body });

const head = m.combine(.{ start("head"), m.opt(string), end("head") });

const body = m.combine(.{
    start("body"),
    m.opt(header),
    m.many(element),
    end("body"),
});

const header = m.combine(.{ start("header"), m.many(element), end("header") });

const element = m.oneOf(.{
    string,
});

//
// Parsers for elements
//

const string = m.asStr(m.many(char, .{ .min = 1 }));

const char = m.oneOf(.{
    m.utf8.range(0x0027, 0x003B),
    m.utf8.char(0x003D),
    m.utf8.range(0x003F, 0x27BF),
});

fn start(comptime tag: []const u8) m.Parser(void) {
    return m.discard(m.string("<" ++ tag ++ ">"));
}

fn end(comptime tag: []const u8) m.Parser(void) {
    return m.discard(m.string("</" ++ tag ++ ">"));
}

//
// Tests
//
test "char" {
    try expectParseAll(u21, char, "a");
}

test "string" {
    try expectParseAll([]const u8, string, "hello");
}

test "doctype" {
    try expectParseAll(void, doctype, "<!DOCTYPE html>");
}

test "head" {
    try expectParseAll(?[]const u8, head,
        \\<head>hello</head>
    );
}

//
// Test helpers
//
fn expectParseAll(comptime T: type, parser: m.Parser(T), s: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const res = try parser(arena.allocator(), s);
    try testing.expectEqualStrings("", res.rest);
}
