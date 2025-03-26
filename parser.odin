package ohtml

import bits "core:container/bit_array"

Element :: struct {
    type:       string,                 // This is just the tag name
    text:       [dynamic] string,       // All text from all direct children
    attrs:      map [string] string,    // Attribute map, key = value, attrs[key] == value
    parent:     ^Element,               // The parent element (can be nil, obviously)
    children:   [dynamic] ^Element,     // All children elements...
    ordering:   bits.Bit_Array,         // 0 is for Element, 1 is for Text
}

@(private="file") tokens:  [] Token
@(private="file") current: int

@(private="file")
next :: proc(o := 0) -> Token {
    defer current += 1 + o
    if current + o < len(tokens) { return tokens[current + o] }
    return { }
}

@(private="file")
peek :: proc(o := 0) -> Token {
    if current + o < len(tokens) { return tokens[current + o]  }
    return { }
}

parse :: proc(html: string, intermediate_allocator := context.temp_allocator) -> ^Element {
    tokens = {}
    current = 0

    raw_tokens := tokenize(html, intermediate_allocator)
    lexed_tokens := lex(raw_tokens, intermediate_allocator)

    defer free_all(intermediate_allocator)

    tokens = lexed_tokens
    elem := new(Element)
    elem.type = "root"

    // Kind of, copied from parse_elem, tbh i cba
    for current < len(tokens) {
        if peek().type == .TEXT {
            append(&elem.text, peek().text)
            bits.set(&elem.ordering, len(elem.ordering.bits), true)
            next()

        } else if peek().type == .ELEMENT {
            child := parse_elem()
            if child == nil { continue }
            append(&elem.children, child)
            child.parent = elem
            bits.set(&elem.ordering, len(elem.ordering.bits), false)

        } else if peek().type == .WHITESPACE {
            next()

        } else { break }
    }
    return elem
}

// TODO: hashset MAY be faster (since, I can fast hash str -> i32)

// Void tags should not have any children or closing tags
VOID_TAGS : [] string : {
    "meta", "link", "base", "frame", "img", "br", "wbr", "embed", "hr", "input", "keygen", "col", "command",
    "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track",
}

// An inline element should not contain a block level element
INLINE_TAGS : [] string : {
    "object", "base", "font", "tt", "i", "b", "u", "big", "small", "em", "strong", "dfn", "code", "samp", "kbd",
    "var", "cite", "abbr", "time", "acronym", "mark", "ruby", "rt", "rp", "rtc", "a", "img", "br", "wbr", "map", "q",
    "sub", "sup", "bdo", "iframe", "embed", "span", "input", "select", "textarea", "label", "optgroup",
    "option", "legend", "datalist", "keygen", "output", "progress", "meter", "area", "param", "source", "track",
    "summary", "command", "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track",
    "data", "bdi", "s", "strike", "nobr",
    "rb", // deprecated but still known / special handling
    "text", // in SVG NS
    "mi", "mo", "msup", "mn", "mtext",
}
BLOCK_TAGS : [] string : {
    "html", "head", "body", "frameset", "script", "noscript", "style", "meta", "link", "title", "frame",
    "noframes", "section", "nav", "aside", "hgroup", "header", "footer", "p", "h1", "h2", "h3", "h4", "h5", "h6",
    "ul", "ol", "pre", "div", "blockquote", "hr", "address", "figure", "figcaption", "form", "fieldset", "ins",
    "del", "dl", "dt", "dd", "li", "table", "caption", "thead", "tfoot", "tbody", "colgroup", "col", "tr", "th",
    "td", "video", "audio", "canvas", "details", "menu", "plaintext", "template", "article", "main",
    "svg", "math", "center", "template",
    "dir", "applet", "marquee", "listing",
}

KEEP_WHITESPACE : [] string : { "pre", "plaintext", "title", "textarea" }

parse_elem :: proc(pre := false) -> ^Element {//{{{
    if peek().type != .ELEMENT { return nil }

    elem := new(Element)
    elem.type = next().text

    pre := pre || any_of(elem.type, ..KEEP_WHITESPACE)
    is_inline := any_of(elem.type, ..INLINE_TAGS)

    for current < len(tokens) {
        #partial switch peek().type {
        case .A_KEY:
            key := to_lower_copy(peek().text) // TODO, This sucks ass.
            if peek(1).type == .A_VALUE {
                elem.attrs[key] = next(1).text
            } else {
                elem.attrs[key] = "true"
                next()
            }
        case .TAG_END:
            next()

            if any_of(elem.type, ..VOID_TAGS) {
                return elem
            }

            has_closing_tag := is_closed(elem.type)
            inner_for: for current < len(tokens) {

                switch {
                case peek().type == .TEXT:
                    append(&elem.text, peek().text)
                    bits.set(&elem.ordering, len(elem.ordering.bits))
                    next()

                case peek().type == .ELEMENT:
                    if any_of(peek().text, ..BLOCK_TAGS) {
                        if !has_closing_tag && eq(peek().text, elem.type) { return elem }
                        if is_inline { return elem }
                    }

                    child := parse_elem(pre)
                    if child == nil { continue }
                    append(&elem.children, child)
                    child.parent = elem
                    bits.set(&elem.ordering, len(elem.ordering.bits), false)

                case peek().type == .WHITESPACE:
                    txt := peek().text if pre else trim_ws(peek().text)
                    append(&elem.text, peek().text)
                    bits.set(&elem.ordering, len(elem.ordering.bits), true)
                    next()

                case peek().type == .ELEMENT_END && ends_with(peek().text, elem.type):
                    return elem

                case:
                    if peek().type == .ELEMENT_END { next()   }
                    else { break inner_for }
                }
            }
        case .ELEMENT_END:
            if !ends_with(peek().text, elem.type) && peek().text != "/" { break }
            if peek().type == .ELEMENT_END { next() }
            if peek().type == .TAG_END { next() }
            return elem

        case: current += 1
        } // switch
    } // for

    return elem
}//}}}

// obviously, there can be <br> anywhere...
is_closed :: proc(tag: string) -> bool {//{{{
    level := 0
    for t in tokens[current:] {
        if t.type == .ELEMENT && eq(t.text, tag) {
           level += 1
        } else if t.type == .ELEMENT_END && ends_with(t.text, tag) {
            if level <= 0 { return true }
            level -= 1
        }
    }
    return false
}//}}}


dbg_fmt_tags :: proc(element: ^Element, level := 0) -> string {//{{{
    I := "    "
    result: [dynamic] u8

    fmt_attr :: proc(result: ^[dynamic] u8, value: string) {
        append_elems(result, u8(' '), u8('['))
        append_elems(result, .. transmute([]u8) value)
        append_elems(result, u8(']'), u8(' '))
    }

    for child in element.children {
        for i in 0..<level { append_elems(&result, .. transmute([]u8) I) }
        append_elems(&result, .. transmute([]u8) child.type)
        if "id" in child.attrs {
            fmt_attr(&result, child.attrs["id"])
        } else if "name" in child.attrs {
            fmt_attr(&result, child.attrs["name"])
        } else if "rel" in child.attrs {
            fmt_attr(&result, child.attrs["rel"])
        } else if "title" in child.attrs {
            fmt_attr(&result, child.attrs["title"])
        } else {
            append_elems(&result, u8(' '), u8('['), u8(']'), u8(' '))
        }
        append_elems(&result, u8('\n'))
        append_elems(&result, .. transmute([]u8) dbg_fmt_tags(child, level + 1))
    }

    return string(result[:])
}//}}}

// super quick and dirty printer, mostly for debugging {{{
// print_parser :: proc(element: ^Element, level := 0) {
//     I := "                                                                                                                                "
//     print :: proc(strs: ..string, end := "\n") {
//         for s in strs do pstr(s)
//     }
//     print_attrs :: proc(e: ^Element) {
//         for k, v in e.attrs do print(k, "=", v, " ")
//     }
//     print("<", element.type, " ")
//     print_attrs(element)
//     print(">")
//     child, text: int
//     iter := bits.make_iterator(&element.ordering)
//     for {
//         is_text, index, ok := bits.iterate_by_all(&iter)
//         if !ok do break
//         if is_text {
//             if element.type != "pre" do pstr(I[:level+1])
//             pstr(element.text[text])
//             text += 1
//         } else {
//             print_parser(element.children[child], level + 2 if element.type != "pre" else 0)
//             child += 1
//         }
//     }
//     print(I[:level], "</", element.type, ">\n")
// }}}}
