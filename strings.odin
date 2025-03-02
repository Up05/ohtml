package ohtml

starts_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && a[:len(b)] == b
}

ends_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && a[len(a) - len(b):] == b
}

index_str :: proc(haystack: string, needle: string, offset := 0) -> (int, int) {
    c: int
    for _, i in haystack[offset:] {
        defer c += 1
        if starts_with(haystack[i + offset:], needle) do return i + offset, c + offset // technically, I would need to do rune_count(offset), but whatever
    }
    return -1, -1
}

index_rune :: proc(haystack: string, needle: rune, offset := 0) -> (int, int) {
    c: int
    for r, i in haystack[offset:] {
        defer c += 1
        if r == needle do return i + offset, c + offset
    }
    return -1, -1
}

index :: proc {  index_str, index_rune  }

// partially stolen from the std lib
rune_size :: proc(r: rune) -> int {
    assert(r >= 0)
	switch {
	case r > 0x10ffff:  return 4
	case r > 1 << 16 :  return 3
	case r > 1 << 11 :  return 2
	} return 1
}

first_rune :: proc(s: string) -> rune {
    for r in s do return r // TODO later replace with an actual impl, maybe
    panic("string is empty, cannot get first rune!")
}

any_of :: proc(a: $T, bees: ..T) -> bool {
    for b in bees do if a == b do return true
    return false
}

range :: proc(a, lo, hi: $T) -> bool {
    return a >= lo && a <= hi
}

// An identifier is a name, e.g.: 'number' or 'my-elem', but not '=' or '<' 
is_ident_rune :: proc(r: rune) -> bool {
    return range(r, 'A', 'Z') || range(r, 'a', 'z') || range(r, '0', '9')
}
is_ident :: proc(s: string) -> bool {
    return len(s) > 0 && is_ident_rune(first_rune(s))
}

// Is white-space
is_ws_rune :: proc(r: rune) -> bool {
    return any_of(r, ' ', '\t', '\v', '\n', '\r')
}
is_ws :: proc(s: string) -> bool {
    return len(s) > 0 && is_ws_rune(first_rune(s)) // TODO change this to 'first_rune' and change the len(
}

is_special_rune :: proc(r: rune) -> bool {
    return any_of(r, '<', '>', '=', '"', '\'')
}
is_special :: proc(s: string) -> bool {
    return len(s) > 0 && is_special_rune(first_rune(s))
}

is_not_special :: proc(str: string) -> bool {
    for r in str {
        if is_special_rune(r) do return false
    }
    return true
}

trim_ws :: proc(s: string) -> string {
    s := s
    for r, i in s {
        if r != ' ' && r == '\t' {
            s = s[i:]
        }
    }
    
    #reverse for r, i in s {
        if r != ' ' && r == '\t' {
            s = s[:i+1]
        }
    }

    return s
}

last :: proc(array: [dynamic] $T) -> ^T {
    return &array[len(array) - 1]
}


