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

const element = m.oneOf(.{
    string,
    h,
});

const header = combine(.{ start("header"), many(element), end("header") });

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

fn many(comptime parser: Parser) Parser {
    return struct {
        fn func(allocator: std.mem.Allocator, s: []const u8) ParserReturn {
            const r = try m.many(parser, .{})(allocator, s);
            return ParserResult{
                .value = try std.mem.concat(allocator, u8, r.value),
                .rest = r.rest,
            };
        }
    }.func;
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
    try expectMatch(char, 'a', "a");
    try expectMatch(char, '\n', "\n");

    try expectMatch(char, '>', "\\>");
    try expectError(char, m.Error.ParserFailed, ">");

    try expectMatch(char, '<', "\\<");
    try expectError(char, m.Error.ParserFailed, "<");
}

test "string" {
    try expectMatch(string, "hello", "hello");
    try expectMatch(string, "a", "a");
    try expectMatch(string, "Vim", "Vim");

    try expectError(string, m.Error.ParserFailed, "<h1>");
}

test "combine" {
    try expectMatch(combine(.{ start("a"), string, end("a") }), "Vim",
        \\<a>Vim</a>
    );
    try expectMatch(combine(.{ start("a"), m.discard(string), end("a") }), "",
        \\<a>Vim</a>
    );
}

test "many" {
    try expectMatch(many(h), "h1", "<h1>h1</h1>");
    try expectMatch(many(h), "h1h2", "<h1>h1</h1><h2>h2</h2>");
}

test "doctype" {
    try expectMatch(doctype, @typeInfo(void).Void,
        \\<!DOCTYPE html>
    );
}

test "head" {
    try expectMatch(head, "",
        \\<head></head>
    );
    try expectMatch(head, "browse.vim",
        \\<head>browse.vim</head>
    );
}

test "h" {
    try expectMatch(h, "browse.vim",
        \\<h1>browse.vim</h1>
    );
}

test "header" {
    try expectMatch(header, "browse.vim",
        \\<header><h1>browse.vim</h1></header>
    );
}

//
// Test helpers
//
fn expectMatch(
    comptime parser: anytype,
    comptime expected: m.ParserResult(@TypeOf(parser)),
    comptime source: []const u8,
) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const res = try parser(arena.allocator(), source);
    try testing.expectEqualStrings("", res.rest);

    switch (@TypeOf(expected)) {
        []const u8 => try testing.expectEqualStrings(expected, res.value),
        else => try testing.expectEqual(expected, res.value),
    }
}

fn expectError(
    comptime parser: anytype,
    comptime expected: m.Error,
    comptime source: []const u8,
) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(expected, parser(arena.allocator(), source));
}
