const std = @import("std");
const m = @import("mecha");

const testing = std.testing;
const debug = std.debug;

//
// Structure of HTML
//
const doc = combine(.{ doctype, html });

const doctype = start("!DOCTYPE html");

const html = combine(.{ m.opt(head), body });

const head = combine(.{ start("head"), opt(string), end("head") });

const body = combine(.{
    start("body"),
    opt(header),
    many(m.oneOf(.{
        h,
        element,
    })),
    end("body"),
});

const header = combine(.{ start("header"), many(element), end("header") });

const element = m.oneOf(.{
    string,
    h,
});

//
// Parsers for elements
//
const string = m.many(char, .{ .collect = false, .min = 1 });

const char = m.oneOf(.{
    m.utf8.range(0x0000, 0x003B),
    escape('>'),
    m.utf8.char(0x003D),
    escape('<'),
    m.utf8.range(0x003F, 0x27BF),
});

const h = m.oneOf(.{ h1, h2, h3, h4, h5, h6 });

const h1 = combine(.{ start("h1"), many(_element), end("h1") });
const h2 = combine(.{ start("h2"), many(_element), end("h2") });
const h3 = combine(.{ start("h3"), many(_element), end("h3") });
const h4 = combine(.{ start("h4"), many(_element), end("h4") });
const h5 = combine(.{ start("h5"), many(_element), end("h5") });
const h6 = combine(.{ start("h6"), many(_element), end("h6") });

//
// Utilities
//
const Parser = m.Parser([]const u8);
const ParserResult = m.Result([]const u8);
const ParserReturn = m.Error!ParserResult;

fn many(comptime parser: anytype) Parser {
    return m.many(parser, .{ .collect = false });
}

fn combine(comptime parsers: anytype) Parser {
    return struct {
        fn func(allocator: std.mem.Allocator, s: []const u8) ParserReturn {
            const r = try m.combine(parsers)(allocator, s);
            const t = m.ParserResult(@TypeOf(m.combine(parsers)));
            switch (t) {
                [][]const u8 => {
                    const value = try std.mem.concat(allocator, u8, r.value);
                    return ParserResult{ .value = value, .rest = r.rest };
                },
                []const u8 => return r,
                void => return ParserResult{ .value = "", .rest = r.rest },
                else => unreachable,
            }
        }
    }.func;
}

fn nullToStr(value: ?[]const u8) []const u8 {
    return value orelse "";
}

fn opt(comptime parser: Parser) Parser {
    return m.map(nullToStr, m.opt(parser));
}

test "combine" {
    try expectMatch([]const u8, combine(.{ start("a"), string, end("a") }),
        \\<a>Vim</a>
    );
    try expectMatch([]const u8, combine(.{ m.discard(start("a")), string, end("a") }),
        \\<a>Vim</a>
    );
    try expectMatch([]const u8, combine(.{
        m.discard(start("a")),
        string,
        m.discard(end("a")),
    }),
        \\<a>Vim</a>
    );
    try expectMatch([]const u8, combine(.{
        m.discard(start("a")),
        m.discard(string),
        m.discard(end("a")),
    }),
        \\<a>Vim</a>
    );
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
    try expectMatch([]const u8, head,
        \\<head></head>
    );
    try expectMatch([]const u8, head,
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
