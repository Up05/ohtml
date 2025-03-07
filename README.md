# A loosey-goosey HTML parser for odin-lang

Still don't know if this is spec compliant...

There are probably bugs, but I tried to allow for:
1. utf-8 & case-insensitive tags
2. tag omitting  (with void elements, inline -> block & self-closing)
4. dom querrying (by\_id, by\_tag, ...)

As a great man once said:  
> Once the rockets are up, who cares where they come down? That's not my department!  
So getting the html is not provided here, although I can recommend [Laytan's http 1.1 implementation](https://github.com/laytan/odin-http) or just running curl through a system command (there is a command library).


# Example usage

```
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
```
Element :: struct {
    type:       string,                 // This is just the tag name
    text:       [dynamic] string,       // All text from all direct children (TODO maybe not how it works?)
    attrs:      map [string] string,    // Attribute map, key = value, attrs[key] == value
    parent:     ^Element,               // The parent element (can be nil, obviously)
    children:   [dynamic] ^Element,     // All children elements...
    ordering:   bits.Bit_Array,         // 0 is for Element, 1 is for Text
}
```

It's common to have lists of elements:
```
Elements :: [dynamic] ^Element
```

And when iterating over ALL children of an element:
```
TextOrElement :: union { ^Element, string }
```

# Functions

```
// parses the html string, in theory, cannot fail
parse :: proc(html: string, intermediate_allocator := context.temp_allocator) -> ^Element

inner_text :: proc(elem: ^Element) -> string    // Gets the inner text of an element and all its children (only the text)
inner_html :: proc(elem: ^Element) -> string    // Gets all of the html between <E...> and </E> of the element (slices original string)
get_next_sibling :: proc(elem: ^Element, offset := 1) -> ^Element // You can guess (might not work with negative numbers, dunno)   
by_id :: proc(start: ^Element, id: string) -> ^Element // Gets a single(first) element by it's id attribute (case-sensitive)
by_attr :: proc(start: ^Element, key: string, value: string) -> Elements // boolean attributes are "true" btw, so <!DOCTYPE html> == <!DOCTYPE html=true> (case-sensitive)
by_class :: proc(start: ^Element, class: string) -> Elements -> All elements by class (case-sensitive)
by_tag :: proc(start: ^Element, tag: string) -> Elements All elements by tag name (case-sensitive)
has_attr :: proc(elem: ^Element, name: string) -> bool (equivalent to: `attribute in element.attrs`)
get_attr :: proc(elem: ^Element, name: string) -> string (equivalent to: `element.attrs[attribute]`)
for_all_children :: proc(elem: ^Element, callback: proc(item: TextOrElement, respective_index: int))
```

# TODO (will never get done)

decode html '&...;' character syntax


# Licensing stuff

I got the lists for tag types from [JSoup source code](https://github.com/jhy/jsoup/blob/master/src/main/java/org/jsoup/parser/Tag.java),  
Which is under MIT license, so thanks to Jonathan Hedley.  
JSoup website: [jsoup.org](https://jsoup.org)

