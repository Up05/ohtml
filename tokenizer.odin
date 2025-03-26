package ohtml


tokenize :: proc(html: string, alloc := context.temp_allocator) -> [] string {
    tokens := make_dynamic_array_len_cap([dynamic] string, 0, len(html) / 16, alloc)
    in_tag: bool
    skip_embedded_script: bool
    skip: int
    for r, i in html {
        if skip > 0 {
            skip -= 1
            continue
        }

        token := html[i:]

        if r == '<' { in_tag = true }
        if !in_tag {
            c: int
            for r2, j in token {
                defer c += 1
                is_last := j + rune_size(r2) == len(token)
                if r2 == '<' || is_last {
                    append(&tokens, token[:j + int(is_last)])
                    skip = c - 1 + int(is_last)
                    in_tag = true
                    break
                }
            }
            continue
        }

        switch r {
        case '"':
            j, c := index(token, '"', 1)
            if j == -1 { j = len(token) - 1 }
            append(&tokens, token[:j + 1])
            skip = j if c == -1 else c

        case '\'':
            j, c := index(token, '\'', 1)
            if j == -1 { j = len(token) - 1 }
            append(&tokens, token[:j + 1])
            skip = j if c == -1 else c

        case '<':
            if is_start_of_comment(token) {
                j, c := index(token, "-->")
                if j == -1 { j, c = len(token), len(token) }
                skip = c + len("<!---->")-1
                break
            }
            if is_start_of_script(token[1:]) { skip_embedded_script = true }
            append(&tokens, token[:1])

        case '>':
            in_tag = false
            append(&tokens, token[:1])
            if skip_embedded_script {
                j, c := find_end_of_script(token[1:])
                if j > 0 { append(&tokens, token[1:j+1]) }
                skip = len(token) if c == -1 else c
                skip_embedded_script = false
            }

        case '=':
            append(&tokens, token[:1])

        case ' ', '\t', '\n', '\r':
            c: int
            for r2, j in token {
                defer c += 1
                if is_ws_rune(r2) { continue }
                skip = c - 1
                // (  optimization  )
                if j != 1 || r != ' ' { append(&tokens, token[:j])     }
                break
            }

        case:
            c: int
            for r2, j in token {
                defer c += 1
                if !is_ws_rune(r2) && !is_special_rune(r2) { continue }
                append(&tokens, token[:j])
                skip = c - 1
                break
            }
        }
    }

    return tokens[:]
}

is_start_of_comment :: proc(token: string) -> bool {
    return starts_with(token, "<!--")
}

is_start_of_script :: proc(token: string) -> bool {
    offset := 0
    for r, i in token {
        if !is_ws_rune(r) { offset = i; break }
    }
    return starts_with(token[offset:], "script") || starts_with(token[offset:], "style")
}

// for <script> ... </script> and <style> ... </style>
find_end_of_script :: proc(text: string) -> (int, int) {
    find_unescaped :: proc(a: string, b: rune, skip := 0) -> int {
        escaped: bool; c: int
        for r in a[skip:] {
            defer c += 1
                 if escaped   { escaped = false }
            else if r == '\\' { escaped = true }
            else if r == b    { return c + skip  }
        }
        return len(a) - 1 + skip
    }

    c: int
    skip: int
    for r, i in text {
        defer c += 1
        t := text[i:]
        switch {
		case skip > 0:  skip -= 1
		case r == '\\': skip += 1

		case r == '"': skip += find_unescaped(t, '"', 1)
		case r == '`': skip += find_unescaped(t, '`', 1)
		case r ==  39: skip += find_unescaped(t, '\'', 1)

		case starts_with(t, "//"):
			_, c2 := index(t, '\n')
			if skip == -1 { break  }
			skip += c2

		case starts_with(t, "/*"):
			_, c2 := index(t, "*/")
			if c2 == -1 { break  }
			skip += c2 + 1

		case starts_with(t, "</s"): return i, c // should be enough... for </script> and </style>
        }
    }
    return len(text), len(text)
}
