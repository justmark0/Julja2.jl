"""
    Julja2ParsedTemplate

Represents a parsed template with executable generator code.

## Fields:
- `generator_code::Expr`: The expression that generates the code for the template.
"""
struct Julja2ParsedTemplate
    generator_code::Expr
end

function _validate_options(options::TemplateOptions)
    if !isa(options.var.left, String) || options.var.left == ""
        error("left border of variable block must be a non empty string")
    end
    if !isa(options.var.right, String) || options.var.right == ""
        error("right border of variable block must be a non empty string")
    end
    if !isa(options.operator.left, String) || options.operator.left == ""
        error("left border of operators block must be a non empty string")
    end
    if !isa(options.operator.right, String) || options.operator.right == ""
        error("right border of operators block must be a non empty string")
    end
end

function _format_template_dir_path(templates_dir::String)::String
    if templates_dir == ""
        error("templates_dir must be a non empty string witn \"/\" in the end.")
    end 
    if templates_dir[end] != '/'
        @warn "templates_dir does not have \"/\" in the end, added \"/\" to the end."
        return templates_dir * "/"
    end
    return templates_dir
end

"""
    Julja2Template(template::String; kw...) -> Julja2ParsedTemplate

Creates an executable template to create result string.

## Required parameters:
- `template::String`: The template string to parse.

## Optional parameters:
- `var::BlockBorders`: Borders for variable blocks (default: `BlockBorders("{{", "}}")`).
- `operator::BlockBorders`: Borders for operator blocks (default: `BlockBorders("{%", "%}")`).
- `templates_dir::String`: Path (relative or absolute) to files that will be included with `{% include %}` operator (default: `"./"`).
- `ignore_missing::Bool`: If true, raises an error if a variable in `{{ variable_block }}` is missing (default: `true`).
- `allow_filename_change_dir::Bool`: Recommended to set to true as it could be a potential vulnerability. 
It forbids "/" in file names to prevent directory changes in Unix systems (default: `false`).

## Returns:
- `Julja2ParsedTemplate`: The parsed template object.
"""
function Julja2Template(
    template::String;
    variable::BlockBorders=BlockBorders("{{", "}}"),
    operator::BlockBorders=BlockBorders("{%", "%}"),
    templates_dir::String="./",
    ignore_missing=true,
    allow_filename_change_dir=false,
)::Julja2ParsedTemplate

    template_dir_path = _format_template_dir_path(templates_dir)
    options = TemplateOptions(
        variable, 
        operator, 
        template_dir_path,
        ignore_missing,
        allow_filename_change_dir
    )
    _validate_options(options)

    root = RootNode()
    build_tree!(template, 1, root, Vector{Julja2.TokenType}(), options)
    return Julja2ParsedTemplate(build_code(root))        
end

function Julja2Template(
    template::Vector{UInt8};
    variable::BlockBorders=BlockBorders("{{", "}}"),
    operator::BlockBorders=BlockBorders("{%", "%}"),
    templates_dir::String="./",
    ignore_missing=true,
    allow_filename_change_dir=false,
)::Julja2ParsedTemplate

    return Julja2Template(
        String(template),
        variable = variable,
        operator = operator,
        templates_dir = templates_dir,
        ignore_missing = ignore_missing,
        allow_filename_change_dir = allow_filename_change_dir,
    )
end

macro julja2_template_str(content)
    return :(Julja2Template($content))
end

"""
    julja2_render(template::Julja2ParsedTemplate, obj) -> String

Renders template from given precompiled template with obj values.

## Arguments:
- `template::String`: Parsed template.
- `obj`: Is an object or Dict of arguments to fill template with.

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
    if isa(obj, Dict{String, Any})
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
