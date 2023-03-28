const std = @import("std");
const m = @import("mecha");

const testing = std.testing;
const debug = std.debug;

//
// Structure of HTML
//
const doc = m.combine(.{ doctype, html });

const doctype = start("!DOCTYPE html");

const html = m.combine(.{ m.opt(head), body });

const head = m.combine(.{ start("head"), m.opt(string), end("head") });

const body = m.combine(.{
    start("body"),
    m.opt(header),
    many(m.oneOf(.{
        h,
        element,
    })),
    end("body"),
});

const header = m.combine(.{ start("header"), many(element), end("header") });

const element = m.oneOf(.{
    string,
    h,
});

//
// Parsers for elements
//
const Parser = m.Parser([]const u8);

const string = m.many(char, .{ .collect = false, .min = 1 });

const char = m.oneOf(.{
    m.utf8.range(0x0000, 0x003B),
    escape('>'),
    m.utf8.char(0x003D),
    escape('<'),
    m.utf8.range(0x003F, 0x27BF),
});

const h = m.oneOf(.{ h1, h2, h3, h4, h5, h6 });

const h1 = m.combine(.{ start("h1"), many(_element), end("h1") });
const h2 = m.combine(.{ start("h2"), many(_element), end("h2") });
const h3 = m.combine(.{ start("h3"), many(_element), end("h3") });
const h4 = m.combine(.{ start("h4"), many(_element), end("h4") });
const h5 = m.combine(.{ start("h5"), many(_element), end("h5") });
const h6 = m.combine(.{ start("h6"), many(_element), end("h6") });

//
// Utilities
//
fn many(comptime parser: anytype) Parser {
    return m.many(parser, .{ .collect = false });
}

fn start(comptime tag: []const u8) m.Parser(void) {
    return m.discard(m.string("<" ++ tag ++ ">"));
}

fn end(comptime tag: []const u8) m.Parser(void) {
    return m.discard(m.string("</" ++ tag ++ ">"));
}

const _element = m.ref(elementRef);

fn elementRef() Parser {
    return element;
}

fn escape(comptime c: u21) m.Parser(u21) {
    return m.combine(.{
        m.discard(m.utf8.char('\\')),
        m.utf8.char(c),
    });
}

//
// Tests
//
test "char" {
    try expectMatch(u21, char, "a");
    try expectMatch(u21, char, "\n");
    try expectMatch(u21, char, "\\>");
    try expectMatch(u21, char, "\\<");
}

test "string" {
    try expectMatch([]const u8, string, "hello");
}

test "doctype" {
    try expectMatch(void, doctype,
        \\<!DOCTYPE html>
    );
}

test "head" {
    try expectMatch(?[]const u8, head,
        \\<head></head>
    );
    try expectMatch(?[]const u8, head,
        \\<head>browse.vim</head>
    );
}

test "header" {
    try expectMatch([]const u8, header,
        \\<header>browse.vim</header>
    );
}

test "h1" {
    try expectMatch([]const u8, h1,
        \\<h1>browse.vim</h1>
    );
}

//
// Test helpers
//
fn expectMatch(comptime T: type, parser: m.Parser(T), s: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const res = try parser(arena.allocator(), s);
    try testing.expectEqualStrings("", res.rest);
}
