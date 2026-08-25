package ohtml

// import "ohtml"
import "core:fmt"

main :: proc() {
    // root element is a fictional <root>
    root_element: ^Element = parse(HTML_TEXT, intermediate_allocator = context.temp_allocator)

    main        := by_id(   root_element, "main")
    buttons     := by_tag(  root_element, "button")
    centered    := by_class(root_element, "centered")
    cors_is_fun := by_attr(main, "crossorigin", "true")

    for img in cors_is_fun { if has_attr(img, "crossorigin") { fmt.println("image has cors!") } }
    for img in cors_is_fun { fmt.println(get_attr(img, "alt")) }

    format(main)

    for button in buttons {
        format(button)
    }
}

format :: proc(element: ^Element) {
    for_all_children(element, proc(item: TextOrElement, respective_index: int) {
        switch v in item {
            case string: fmt.print(v)
            case ^Element:
                fmt.println()
                fmt.printf("<%s>", v.type)
                format(v)
                fmt.printf("</%s>", v.type)
                fmt.println()
        }
    })
    fmt.println()
}


HTML_TEXT :: `
    <root>
    <!DOCTYPE html>
    
    <div id=main >
        <button> click me </button>

        <div id=content class="centered">
            <button> click me </button>
            <img crossorigin src='cat1.png' alt = "insane cat image" >
            <img crossorigin src='cat2.png' alt = "insane cat image" >
            <img crossorigin src='cat3.png' alt = "insane cat image" >
        </div>

    </div>

    <button> click me </button>
    <button> click me </button>
    <button> click me </button>
    </root>
`
