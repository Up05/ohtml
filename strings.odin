package ohtml

// a.k.a. _eq_leftover
eq :: proc(a, b: string) -> bool {
    if len(a) != len(b) do return false
    #no_bounds_check for i in 0..<len(a) {
        r1 := a[i]
        r2 := b[i]

        A := r1 - 32*u8(r1 >= 'a' && r1 <= 'z')
        B := r2 - 32*u8(r2 >= 'a' && r2 <= 'z')
        if A != B do return false
    }
    return true
}

starts_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && eq(a[:len(b)], b)
}

ends_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && eq(a[len(a) - len(b):], b)
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

any_of_any :: proc(a: $T, bees: ..T) -> bool {
    for b in bees do if a == b do return true
    return false
}

any_of_str :: proc(a: string, strs: ..string) -> bool {
    for b in strs do if eq(a, b) do return true
    return false
}

any_of :: proc {
    any_of_str, any_of_any
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

// If anyone wants it:
// The speed is, basically, the same with 8/16/32 widths
// but it crashes with bad aignment and my strings will be short
// so eating the leftovers from both ends makes no sense
// eq :: proc(a, b: string) -> bool {
//     using simd
//     a, b := transmute([] u8) a, transmute([] u8) b
//     if len(a) != len(b) do return false
// 
//     W :: 32 // lanes or width
//     l := len(a) - len(a) % W
// 
//     LO   : #simd [W] u8; LO = auto_cast 'a' 
//     HI   : #simd [W] u8; HI = auto_cast 'z'
//     MUL  : #simd [W] u8; MUL = auto_cast 32
//     BOOL : #simd [W] u8; BOOL = auto_cast 1
// 
//     i: int
//     #no_bounds_check for ; i < l; i += W {
//         // _1 := from_slice(#simd [W] u8, transmute([]u8) a[i:i+W]) 
//         // _2 := from_slice(#simd [W] u8, transmute([]u8) b[i:i+W]) 
//         _1 := (cast(^#simd [W] u8)(&a[i+8]))^
//         _2 := (cast(^#simd [W] u8)(&b[i+8]))^
//         A := sub(_1, mul(MUL, bit_and(bit_and( lanes_ge(_1, LO), lanes_ge(_1, HI) ), BOOL) ))
//         B := sub(_2, mul(MUL, bit_and(bit_and( lanes_ge(_2, LO), lanes_ge(_2, HI) ), BOOL) ))
//         if reduce_and( lanes_eq(A, B) ) == 0 do return false
// 
//         // A := r1 - 32*u8(r1 >= HI && r1 <= HI)
//         // B := r2 - 32*u8(r2 >= HI && r2 <= HI)
//         // if A != B do return false
//     }
//     return _eq_leftover(string(a[i:]), string(b[i:]))
// }
