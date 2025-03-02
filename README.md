# A loosey-goosey HTML parser for odin-lang

I couldn't find an HTML spec, so I don't know if this is spec compliant or not ¯\\\_(ツ)\_/¯

There are probably bugs, but I tried to allow for:
1. utf-8
2. tag omitting
3. self-closing
4. dom querrying

Although this library does not provide a way to fetch html.
You can use the cmd library with curl, or laytan's http 1.1 implementation, or whatever else.
As a great man once said:  
> Once the rockets are up, who cares where they come down? That's not my department!

# How to get
```sh
git clone "https://github.com/Up05/ohtml" ohtml
```

# Example usage

```odin
import ohtml
import "core:fmt"

main :: proc() {
    using ohtml        

    // btw, the root element is a fictional <root> maybe: <!DOCTYPE html>, ... </root>
    root_element: ^Element = parse(#load(index.html, string), intermediate_allocator = context.temp_allocator) 
    
    main := by_id(root_element, "main")
    buttons := by_tag(root_element, "button")
    centered := by_class(root_element, "centered")
    cors_is_fun := by_attr(main, "crossorigin", "true")

    for img in cors_is_fun do assert(has_attr(img, "crossorigin"))
    for img in cors_is_fun do fmt.println(get_attr(img, "alt"))
    
    format(main)
}

format :: proc(element: ^Element) {

    for_all_children(root_element, proc(item: TextOrElement, respective_index: int) { 
        switch v in item {
            case string: fmt.println("[...]")
            case ^Element: 
                fmt.printf("<%s>", v.type)
                format(element)
                fmt.printf("</%s>", v.type)
        } // I can never remember union + switch case syntax, but you get the point
    })
}

```

# Types

The main type:
```odin
Element :: struct {
    type:       string,                 // This is just the tag name
    text:       [dynamic] string,       // All text from all direct children (TODO maybe not how it works?)
    attrs:      map [string] string,    // Attribute map, key = value, attrs[key] == value
    parent:     ^Element,               // The parent element (can be nil, obviously)
    children:   [dynamic] ^Element,     // All children elements...
    ordering:   bits.Bit_Array,         // 0 is for Element, 1 is for Text
}
```

There are often lists of elements:
```odin
Elements :: [dynamic] ^Element
```

And when iterating over ALL children of an element:
```odin
TextOrElement :: union { ^Element, string }
```

# Functions

```odin
// parses the html string, in theory, cannot fail
parse :: proc(html: string, intermediate_allocator := context.temp_allocator) -> ^Element

inner_text :: proc(elem: ^Element) -> string    // Gets the inner text of an element and all its children (only the text)
inner_html :: proc(elem: ^Element) -> string    // Gets all of the html between <E...> and </E> of the element (slices original string)
get_next_sibling :: proc(elem: ^Element, offset := 1) -> ^Element // You can guess (might not work with negative numbers, dunno)   
by_id :: proc(start: ^Element, id: string) -> ^Element // Gets a single(first) element by it's id attribute (case-sensitive)
by_attr :: proc(start: ^Element, key: string, value: string) -> Elements // boolean attributes are "true" btw, so <!DOCTYPE html> == <!DOCTYPE html=true> (case-sensitive)
by_class :: proc(start: ^Element, class: string) -> Elements // All elements by class (case-sensitive)
by_tag :: proc(start: ^Element, tag: string) -> Elements // All elements by tag name (case-sensitive)
has_attr :: proc(elem: ^Element, name: string) -> bool // (equivalent to: `attribute in element.attrs`)
get_attr :: proc(elem: ^Element, name: string) -> string // (equivalent to: `element.attrs[attribute]`)
for_all_children :: proc(elem: ^Element, callback: proc(item: TextOrElement, respective_index: int))
```

# TODO

decode html '&...;' character syntax
