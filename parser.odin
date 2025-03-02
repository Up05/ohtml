package ohtml

import bits "core:container/bit_array"

Element :: struct {
    type:       string,                 // This is just the tag name
    text:       [dynamic] string,       // All text from all direct children (TODO maybe not how it works?)
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
    if current + o < len(tokens) do return tokens[current + o]
    return { }
}

@(private="file")
peek :: proc(o := 0) -> Token {
    if current + o < len(tokens) do return tokens[current + o] 
    return { }
}

parse :: proc(html: string, intermediate_allocator := context.temp_allocator) -> ^Element {
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
            bits.set(&elem.ordering, bits.len(&elem.ordering), true)
            next()

        } else if peek().type == .ELEMENT {
            child := parse_elem()
            if child == nil do continue
            append(&elem.children, child)
            child.parent = elem
            bits.set(&elem.ordering, bits.len(&elem.ordering), false)

        } else if peek().type == .WHITESPACE {
            next()

        } else do break
    }
    
    return elem
}

parse_elem :: proc(pre := false) -> ^Element {
    if peek().type != .ELEMENT do return nil
    
    elem := new(Element)
    elem.type = next().text

    pre := pre || elem.type == "pre"

    for current < len(tokens) {
        #partial switch peek().type {
        case .A_KEY:
            if peek(1).type == .A_VALUE {
                elem.attrs[peek().text] = next(1).text
            } else {
                elem.attrs[peek().text] = "true"
                next()
            }
        case .TAG_END:
            next()

            if !is_closed(elem.type) {
                return elem // I think, that this is how tag omission works, kind of anyways?    
            }

            for current < len(tokens) {

                if peek().type == .TEXT {
                    append(&elem.text, peek().text)
                    bits.set(&elem.ordering, bits.len(&elem.ordering))
                    next()

                } else if peek().type == .ELEMENT {
                    child := parse_elem(pre)
                    if child == nil do continue
                    append(&elem.children, child)
                    child.parent = elem
                    bits.set(&elem.ordering, bits.len(&elem.ordering), false)
                    
                } else if peek().type == .WHITESPACE {
                    txt := peek().text if pre else trim_ws(peek().text)
                    append(&elem.text, peek().text)
                    bits.set(&elem.ordering, bits.len(&elem.ordering), true)
                    next()

                } else do break
            }
        case .ELEMENT_END:
            if !ends_with(next().text, elem.type) do break
            if peek().type == .TAG_END do next()
            return elem

        case: current += 1
        } // switch  
    } // for 

    return elem
}

// obviously, there can be <br> anywhere...
is_closed :: proc(tag: string) -> bool {
    level := 0
    for t in tokens[current:] {
        if t.type == .ELEMENT && t.text == tag {
           level += 1
        } else if t.type == .ELEMENT_END && ends_with(t.text, tag) {
            if level <= 0 do return true
            level -= 1
        }
    }
    return false
}

// super quick and dirty printer, mostly for debugging 
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
// }



