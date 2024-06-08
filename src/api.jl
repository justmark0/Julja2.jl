"""
    Julja2ParsedTemplate

Represents a parsed template with executable generator code.

## Fields:
- `generator_code::Expr`: The expression that generates the code for the template.
"""
struct Julja2ParsedTemplate
generator_code::Expr
end

"""
    BlockBorders

This structure contains borders of block.

## Fields:
- `left::String`: The left border string.
- `left_length::Int`: The length of the left border.
- `right::String`: The right border string.
- `right_length::Int`: The length of the right border.
"""
mutable struct BlockBorders
    left::String
    left_length::Int
    right::String
    right_length::Int

    function BlockBorders(left::String, right::String)
        # Get UInt8 string length because unicode characters may be more than one byte.
        new(
            left,
            length(transcode(UInt8, left)),
            right,
            length(transcode(UInt8, right))
        )
    end
end

"""
    Julja2Template(template::String; var_borders::BlockBorders=BlockBorders("{{", "}}"), 
    operator_borders::BlockBorders=BlockBorders("{%", "%}"), templates_dir::String="./", 
    ignore_missing_vars=true, allow_filename_change_dir=false) -> Julja2ParsedTemplate

Creates an executable template to create result string.

## Required parameters:
- `template::String`: The template string to parse.

## Optional parameters:
- `var_borders::BlockBorders`: Borders for variable blocks (default: `BlockBorders("{{", "}}")`).
- `operator_borders::BlockBorders`: Borders for operator blocks (default: `BlockBorders("{%", "%}")`).
- `templates_dir::String`: Path (relative or absolute) to files that will be included with `{% include %}` operator (default: `"./"`).
- `ignore_missing_vars::Bool`: If true, raises an error if a variable in `{{ variable_block }}` is missing (default: `true`).
- `allow_filename_change_dir::Bool`: Recommended to set to true as it could be a potential vulnerability. It forbids "/" in file names to prevent directory changes in Unix systems (default: `false`).

## Returns:
- `Julja2ParsedTemplate`: The parsed template object.
"""
function Julja2Template(template::String;
                var_borders::BlockBorders=BlockBorders("{{", "}}"),
                operator_borders::BlockBorders=BlockBorders("{%", "%}"),
                templates_dir::String="./",
                ignore_missing_vars=true,
                allow_filename_change_dir=false)::Julja2ParsedTemplate

    template_dir_path = _format_template_dir_path(templates_dir)
    template_options = TemplateOptions(
        var_borders, operator_borders, template_dir_path,
        ignore_missing_vars, allow_filename_change_dir)
    _validate_options(template_options)

    root = Node("""function build_result_string()\n_result=IOBuffer()\n""", [])
    build_tree!(template, 1, root, Vector{Julja2.TokenType}(), template_options)
    generator_code = build_code(root)
    generator_code *= "\nreturn String(take!(_result))\nend"
    generator = Meta.parse(generator_code)

    return Julja2ParsedTemplate(generator)        
end

function Julja2Template(template::Vector{UInt8};
                    var_borders::BlockBorders=BlockBorders("{{", "}}"),
                    operator_borders::BlockBorders=BlockBorders("{%", "%}"),
                    templates_dir::String="./",
                    ignore_missing_vars=true,
                    allow_filename_change_dir=false)::Julja2ParsedTemplate

    return Julja2Template(String(template),
    var_borders=var_borders,
    operator_borders=operator_borders,
    templates_dir=templates_dir,
    ignore_missing_vars=ignore_missing_vars,   
    allow_filename_change_dir=allow_filename_change_dir)
end

macro julja2_template_str(content)
    return :(Julja2Template($content))
end

"""
    julja2_render(template::Julja2ParsedTemplate, obj) -> String

Renders template from given precompiled template with obj values.

## Arguments:
- `template::String`: Parsed template.
- `obj`: Is an object or Dict of arguments.

## Returns:
- `Julja2ParsedTemplate`: The parsed template object.

## Usage:
```julia
using Julja2

struct Book
    title::String
    authors::Vector{String}
    year
end

template = Julja2.Julja2Template(\"\"\"
###  {{ title}}
{% if year != nothing %}Published in {{ year }}{% endif %}
Authors:{% for author in authors %}
- {{ author }}{% endfor %}\"\"\")
print(julja2_render(template, Book("Coding 101", ["Mark", "Alice", "Bob"], 2024)))

# Result: 
\"\"\"
### Coding 101
Published in 2024
Authors:
- Mark
- Alice
- Bob
\"\"\"
```
"""
function julja2_render(template::Julja2ParsedTemplate, obj)::String
    if typeof(obj) == Dict{String, Any}
        fields = collect(keys(obj))
        obj_values = collect(values(obj))
    else 
        fields = fieldnames(typeof(obj))
        obj_values = [getfield(obj, field) for field in fields]
    end

    
    let_block = Expr(:block)
    
    for (field, value) in zip(fields, obj_values)
        push!(let_block.args, :(local $(Symbol(field)) = $value))
    end
    
    push!(let_block.args, template.generator_code)
    push!(let_block.args, Meta.parse("build_result_string()")) 

    return eval(let_block)
end

function _validate_options(options)
    if typeof(options.var.left) != String || options.var.right == ""
        error("left border of variable block must be a non empty string")
    end
    if typeof(options.var.right) != String || options.var.right == ""
        error("right border of variable block must be a non empty string")
    end
    if typeof(options.operator.left) != String || options.operator.left == ""
        error("left border of operators block must be a non empty string")
    end
    if typeof(options.operator.right) != String || options.operator.right == ""
        error("right border of operators block must be a non empty string")
    end
end

function _format_template_dir_path(templates_dir::String)::String
    if templates_dir == ""
        error("templates_dir must be a non empty string witn \"/\" in the end.")
    end 
    if templates_dir[end] != '/'
        @warn "templates_dir not have \"/\" in the end, added \"/\" to the end"
        return templates_dir * "/"
    end
    return templates_dir
end
