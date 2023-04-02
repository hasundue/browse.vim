const std = @import("std");
const m = @import("mecha");

const testing = std.testing;
const debug = std.debug;

//
// Structure of HTML
//
// Ref: https://html.spec.whatwg.org/multipage/syntax.html
//
const doc = m.combine(.{
    m.discard(m.opt(m.utf8.char(0xEFBBBF))),
    m.discard(m.many(m.oneOf(.{
        comment,
        ws,
    }), .{ .collect = false })),
    m.discard(doctype),
    m.discard(m.many(m.oneOf(.{
        comment,
        ws,
    }), .{ .collect = false })),
    html,
});

fn start_tag(comptime name: []const u8) Parser {
    return struct {
        fn func(allocator: std.mem.Allocator, s: []const u8) ParserReturn {
            return m.combine(.{
                m.utf8.char('<'),
                m.string(name),
                m.discard(m.opt(m.combine(.{
                    m.discard(wss(1)),
                    m.many(attribute, .{
                        .collect = false,
                        .min = 1,
                        .separator = m.discard(wss(1)),
                    }),
                }))),
                m.utf8.char('>'),
            })(allocator, s);
        }
    }.func;
}

fn end_tag(comptime name: []const u8) Parser {
    return struct {
        fn func(allocator: std.mem.Allocator, s: []const u8) ParserReturn {
            return m.combine(.{
                m.utf8.char('<'),
                m.utf8.char('/'),
                m.string(name),
                m.discard(wss(0)),
                m.utf8.char('>'),
            })(allocator, s);
        }
    }.func;
}

// TODO
const attribute = text;

const element = m.oneOf(.{
    html,
});

/// Note: This must be inside an element.
const text = m.asStr(m.many(char, .{ .collect = true, .min = 0 }));

test "text" {
    try expectMatch(text, "", "");
    try expectMatch(text, "text", "text");
    try expectMatch(text, " text ", " text ");
}

// TODO: add restriction that the text must not start with the string ">",
// nor start with the string "->", nor contain the strings "<!--", "-->",
// or "--!>", nor end with the string "<!-".
const comment = m.discard(m.bracket(
    m.string("<!--"),
    text,
    m.string("-->"),
));

test "comment" {
    try testing.expect(@TypeOf(comment) == m.Parser(void));
    try expectMatch(comment, {}, "<!-- comment -->");
}

// TODO: add an optional DOCTYPE legacy string
const doctype = m.combine(.{
    m.string("<!DOCTYPE"),
    m.discard(wss(1)),
    m.string("html"),
    m.discard(wss(0)),
    m.utf8.char('>'),
});

const html = text;

// const body = combine(.{
//     tag("body"),
//     opt(header),
//     many(element, .{}),
//     end("body"),
// });

// TODO: define the contents
// const head = combine(.{ tag("head"), end("head") });

// const header = combine(.{ tag("header"), many(element, .{}), end("header") });

//
// Parsers for elements
//
// const h = m.oneOf(.{ h1, h2 });

// const h1 = combine(.{ tag("h1"), many(_element, .{}), end("h1") });
// const h2 = combine(.{ tag("h2"), many(_element, .{}), end("h2") });

const ws = m.utf8.range(0x0000, 0x0020);

const char = m.oneOf(.{
    m.utf8.range(0x0000, 0x003B),
    escape('>'),
    m.utf8.char(0x003D),
    escape('<'),
    m.utf8.range(0x003F, 0x27BF),
});

test "char" {
    try expectMatch(char, 'a', "a");
    try expectMatch(char, '\n',
        \\
        \\
    );
    try expectMatch(char, '>', "\\>");
    try expectError(char, ParserFailed, ">");
    try expectMatch(char, '<', "\\<");
    try expectError(char, ParserFailed, "<");
}

fn escape(comptime c: u21) m.Parser(u21) {
    return m.combine(.{
        m.discard(m.utf8.char('\\')),
        m.utf8.char(c),
    });
}

//
// Utilities
//
const Parser = m.Parser([]const u8);
const ParserResult = m.Result([]const u8);
const ParserReturn = m.Error!ParserResult;
const ParserFailed = m.Error.ParserFailed;

fn wss(comptime min: usize) m.Parser([]const u8) {
    return m.many(ws, .{ .min = min, .collect = false });
}

// const chunk = m.many(char, .{ .collect = false, .min = 1 });

// const text = m.many(chunk, .{
//     .collect = false,
//     .min = 1,
//     .separator = wss(1),
// });

// fn many(comptime parser: Parser, comptime options: m.ManyOptions) Parser {
//     return struct {
//         fn func(allocator: std.mem.Allocator, s: []const u8) ParserReturn {
//             const r = try m.many(parser, options)(allocator, s);
//             return ParserResult{
//                 .value = try std.mem.concat(allocator, u8, r.value),
//                 .rest = r.rest,
//             };
//         }
//     }.func;
// }

// fn combine(comptime parsers: anytype) Parser {
//     return struct {
//         fn func(allocator: std.mem.Allocator, s: []const u8) ParserReturn {
//             const r = try m.combine(parsers)(allocator, s);
//             const t = m.ParserResult(@TypeOf(m.combine(parsers)));
//             switch (t) {
//                 []const u8 => return r,
//                 void => return ParserResult{ .value = "", .rest = r.rest },
//                 else => {
//                     // r.value should be a tuple of []const u8
//                     var list = std.ArrayList(u8).init(allocator);
//                     defer list.deinit();
//                     inline for (r.value) |str| {
//                         if (@TypeOf(str) != []const u8) {
//                             @compileError("combine() only accepts a tuple of []const u8");
//                         }
//                         try list.appendSlice(str);
//                     }
//                     return ParserResult{ .value = list.items, .rest = r.rest };
//                 },
//             }
//         }
//     }.func;
// }

// fn nullToStr(value: ?[]const u8) []const u8 {
//     return value orelse "";
// }

// fn opt(comptime parser: Parser) Parser {
//     return m.map(nullToStr, m.opt(parser));
// }

// fn tag(comptime name: []const u8) m.Parser(void) {
//     return m.discard(m.string("<" ++ name ++ ">"));
// }

// fn end(comptime name: []const u8) m.Parser(void) {
//     return m.discard(m.string("</" ++ name ++ ">"));
// }

// const _element = m.ref(elementRef);

// fn elementRef() Parser {
//     return element;
// }

//
// Tests
//

// test "chunk" {
//     try expectMatch(chunk, "a", "a");
//     try expectError(chunk, ParserFailed, " ");
//     try expectMatch(chunk, "Vim", "Vim");
//     try expectError(chunk, ParserFailed, "<h1>");
//     try expectMatch(chunk, "browse.vim", "browse.vim");
//     try expectError(chunk, ParserFailed, " browse.vim");
//     try expectResult(chunk, .{ .value = "browse", .rest = " vim" }, "browse vim");
// }

// test "ws" {
//     try expectError(ws, ParserFailed, "");
//     try expectMatch(ws, ' ', " ");
// }

// test "string" {
//     try expectMatch(text, "a", "a");
//     try expectError(text, ParserFailed, " ");
//     try expectMatch(text, "Vim", "Vim");
//     try expectError(text, ParserFailed, "<h1>");
//     try expectMatch(text, "browse.vim", "browse.vim");
//     try expectMatch(text, "browse vim", "browse vim");
//     try expectError(text, ParserFailed, " browse vim");
//     try expectResult(text, .{ .value = "browse vim", .rest = " " }, "browse vim ");
// }

// test "combine" {
//     try expectMatch(combine(.{ tag("a"), text, end("a") }), "Vim",
//         \\<a>Vim</a>
//     );
//     try expectMatch(combine(.{ tag("a"), m.discard(text), end("a") }), "",
//         \\<a>Vim</a>
//     );
// }

// test "many" {
//     try expectMatch(many(chunk, .{ .min = 1 }), "Vim", "Vim");
//     // try expectMatch(many(h, .{ .min = 1 }), "h1", "<h1>h1</h1>");
//     // try expectMatch(many(h, .{ .min = 1 }), "h1h2", "<h1>h1</h1><h2>h2</h2>");
// }

// test "doctype" {
//     try expectMatch(doctype, @typeInfo(void).Void,
//         \\<!DOCTYPE html>
//     );
// }

// test "head" {
//     try expectMatch(head, "",
//         \\<head></head>
//     );
// }

// test "h" {
//     try expectMatch(h, "browse.vim",
//         \\<h1>browse.vim</h1>
//     );
// }

// test "header" {
//     try expectMatch(header, "browse.vim",
//         \\<header><h1>browse.vim</h1></header>
//     );
//     try expectMatch(header, "browse.vim",
//         \\<header>
//         \\    <h1>browse.vim</h1>
//         \\</header>
//     );
// }

// test "body" {
//     try expectMatch(body, "",
//         \\<body></body>
//     );
//     try expectMatch(body, "browse.vim",
//         \\<body>
//         \\    <header>
//         \\        <h1>browse.vim</h1>
//         \\    </header>
//         \\</body>
//     );
// }

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

fn expectResult(
    comptime parser: anytype,
    comptime expected: m.Result(m.ParserResult(@TypeOf(parser))),
    comptime source: []const u8,
) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const res = try parser(arena.allocator(), source);

    switch (@TypeOf(expected.value)) {
        []const u8 => try testing.expectEqualStrings(expected.value, res.value),
        else => try testing.expectEqual(expected.value, res.value),
    }
    try testing.expectEqualStrings(expected.rest, res.rest);
}
