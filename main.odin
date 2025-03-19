package ohtml

import bits "core:container/bit_array"

Elements :: [dynamic] ^Element
TextOrElement :: union { ^Element, string }

inner_text :: proc(elem: ^Element) -> string {
    result: [dynamic] u8

    child, text: int
    iter := bits.make_iterator(&elem.ordering)
    for {
        is_text, index, ok := bits.iterate_by_all(&iter)
        if !ok do break

        if is_text {
            append_elems(&result, .. transmute([]u8)elem.text[text])
            text += 1
        } else if child < len(elem.children) {
            the_text := inner_text(elem.children[child]) 
            append_elems(&result, .. transmute([]u8)the_text)
            child += 1
        }
    }
    return string(result[:])
}

// This works because the input from tokenizer are just slices of the same string
// I've become a C programmer, I'm sorry!
inner_html :: proc(elem: ^Element) -> string {

    addr :: proc(ptr: [^]u8) -> u64 {
        return transmute(u64) ptr
    }

    // yeah, should have left this as is, cba by now
    get_last_text :: proc(elem: ^Element) -> string {
        is_last_text := bits.get(&elem.ordering, len(elem.ordering.bits) - 1)
             if is_last_text do             return last(elem.text)^
        else if len(elem.children) > 0 do   return get_last_text(last(elem.children)^)
        if len(elem.text) > 0 do            return elem.text[0]
                                            return last(elem.parent.text)^
    }

    if len(elem.text) == 0 do return ""
    from := raw_data(elem.text[0])
    l: u64

    to := get_last_text(elem)
    l = addr(raw_data(to)) + u64(len(to)) - addr(from)

    return string( (transmute([^]u8) from)[:l] )
}



get_next_sibling :: proc(elem: ^Element, offset := 1) -> ^Element {
    if elem.parent == nil do return nil

    for siblings, i in elem.parent.children {
        if elem != siblings do continue
        if !( i + offset < len(elem.parent.children) ) do continue
        return elem.parent.children[i + offset]
    }

    return nil
}


by_id :: proc(start: ^Element, id: string) -> ^Element {
    for child in start.children {
        if child.attrs["id"] == id do return child
        e := by_id(child, id)
        if e != nil do return e
    }
    return nil
}

by_attr :: proc(start: ^Element, key: string, value: string) -> Elements {
    buffer: Elements
    for child in start.children {
        if child.attrs[key] == value do append_elem(&buffer, child) 
        cb := by_attr(child, key, value) // child buffer
        append_elems(&buffer, ..cb[:])
        delete(cb)
    }
    return buffer
}

by_class :: proc(start: ^Element, class: string) -> Elements {
    return by_attr(start, "class", class)
}

by_tag :: proc(start: ^Element, tag: string) -> Elements {
    buffer: Elements
    for child in start.children {
        if eq(child.type, tag) do append_elem(&buffer, child) 
        cb := by_tag(child, tag) // child buffer
        append_elems(&buffer, ..cb[:])
        delete(cb)
    }
    return buffer
}

has_attr :: proc(elem: ^Element, name: string) -> bool {
    return name in elem.attrs
}

get_attr :: proc(elem: ^Element, name: string) -> string {
    return elem.attrs[name]
}

for_all_children :: proc(elem: ^Element, callback: proc(item: TextOrElement, respective_index: int)) {
    child, text: int
    iter := bits.make_iterator(&elem.ordering)
    for {
        is_text, index, ok := bits.iterate_by_all(&iter)
        if !ok do break

        if is_text do callback(elem.text[text], text)
        else do       callback(elem.children[child], child)
    }
}

