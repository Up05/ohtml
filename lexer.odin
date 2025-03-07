package ohtml

TokenType :: enum {
    NONE, 
    ELEMENT,        // <div>                = ELEMENT:   "div"
    TAG_END,        // <div>                = TAG_END    ">"
    ELEMENT_END,    // </div>               = ELEM_END   "/div"       and    </ div> = ELEM_END "div"
    A_KEY,          // <a href='a.com'>     = A_KEY      "'href'"     and    <img crossorigin> = A_KEY "crossorigin"
    A_VALUE,        // <a href='a.com'>     = A_VALUE    "'a.com'"
    WHITESPACE,     // <div  id=main>       = WHITESPACE "  "
    TEXT,           // <script> 8===D </script>  =  TEXT " 8===D "
}

@(private="file") T :: proc(text: string, type: TokenType) -> Token { return { text = text, type = type } }
Token :: struct {
    text: string,
    type: TokenType
}

lex :: proc(raw_tokens: [] string, alloc := context.temp_allocator) -> [] Token {
    tokens := make_dynamic_array_len_cap([dynamic] Token, 0, len(raw_tokens), alloc)

    in_tag: bool
    for i := 0; i < len(raw_tokens); i += 1 {
        prev := find_nows(raw_tokens, i, -1) 
        curr :=           raw_tokens [i]
        next := find_nows(raw_tokens, i, +1)

        switch {
        case curr == "<":
            in_tag = true
        case prev == "<":
            if starts_with(curr, "/") {
                if len(curr) == 1 && is_not_special(next) {
                    append(&tokens, T(next, .ELEMENT_END))
                    i += 2
                    break
                }
                append(&tokens, T(curr, .ELEMENT_END))
                i += 1
                break
            }
            if ends_with(curr, "/") {
                if len(curr) == 1 {
                    append(&tokens, T(curr, .ELEMENT_END))
                    break
                } else {
                    append(&tokens, T(curr[:len(curr) - 1], .ELEMENT))
                    append(&tokens, T(curr[len(curr) - 1:], .ELEMENT_END))
                    break
                }
            
            }

            append(&tokens, T(curr, .ELEMENT))
        case curr == ">":         
            append(&tokens, T(curr, .TAG_END))
            in_tag = false
        case curr == "/":
            append(&tokens, T(curr, .ELEMENT_END))
        case next == "=":
            curr = trim_quotes(curr)
            append(&tokens, T(curr, .A_KEY))
            i += 1
        case prev == "=":
            curr = trim_quotes(curr)
            append(&tokens, T(curr, .A_VALUE))
        case in_tag && is_ident(curr):
            curr = trim_quotes(curr)
            append(&tokens, T(curr, .A_KEY))
        case:
            is_all_ws := true
            for r in curr do if !is_ws_rune(r) { is_all_ws = false; break }
            if is_all_ws do append(&tokens, T(curr, .WHITESPACE))
            else do append(&tokens, T(curr, .TEXT))
        }

    }


    return tokens[:]
}

// skips white-space
find_nows :: proc(raw_tokens: [] string, origin: int, velocity: int) -> string {
    result := ""
    for i := origin + velocity; i >= 0 && i < len(raw_tokens); i += velocity {
        if !is_ws(raw_tokens[i]) do return raw_tokens[i] 
    }
    return result
}

trim_quotes :: proc(s: string) -> string {
    s := s

    l := len(s); if l < 1 do return s
    if s[0] == '"' || s[0] == '\'' do s = s[1:]
    l  = len(s); if l < 1 do return s
    if s[l-1] == '"' || s[l-1] == '\'' do s = s[:l-1]

    return s
}

