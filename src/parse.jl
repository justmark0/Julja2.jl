@enum TokenBlockType string_block = 1 variable_block = 2 operators_block = 3
@enum TokenType string_token = 1 variable_token = 2 for_token = 3 if_token = 4 endfor_token = 5 endif_token = 6 include_token = 7 elseif_token = 8 else_token = 9

# may add all possible spaces of unicode, but there are too many of them in unicode 😮‍💨 (and why to bother anyway...)
const WHITESPACES = [' ', '\t', '\U0020'] 

"""
    Node

It is a node of AST tree of a template.

## Required fields
- `template_string::String`: template string that will be added to generated code.
- `children::Vector{Node}`: in-order children nodes. Tokens should end with depth level.
"""
mutable struct Node
    template_string::String
    children::Vector{Node}
end

function RootNode()
    Node(
        "function build_result_string()\n_result=IOBuffer()\n", 
        [],
    )
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
    TemplateOptions

This is options for template parsing and rendering.

## Fields:
- `var::BlockBorders` variable border strings.
- `operator::BlockBorders` operator border strings.
- `templates_dir::String` directory from which templates will be included.
- `ignore_missing::Bool` if variable is not passed to template it will be ignored.
- `allow_filename_change_dir::Bool` if disabled and variable will conrain "/" 
template creation will raise error.
"""
mutable struct TemplateOptions
    var::BlockBorders
    operator::BlockBorders
    templates_dir::String
    ignore_missing::Bool
    allow_filename_change_dir::Bool
end

function _check_substring_at_offset(template::String, i::Int, substr::String)
    # Count length of bytes in string because unicode characters may be bigger than one byte.
    # For the same reason using nextind.
    n = length(transcode(UInt8, template))
    m = length(transcode(UInt8, substr))

    if i <= n - m + 1
        current_index = i
        j = 1
        while j <= m
            if substr[j] != template[current_index]
                return false
            end
            j = nextind(substr, j)
            current_index = nextind(template, current_index)
        end
        return true
    end

    return false
end

"""
    get_next_token(template::String, index::Integer, options::TemplateOptions) -> (String, TokenBlockType, Integer)

Returns next token in template, its type and next index.
Next index points to the start of next token in template.

## Parameters:
- `template::String`: The template string to parse.
- `index::Integer`: The current index in the template string.
- `options::TemplateOptions`: Options for template parsing and rendering.

## Returns:
- `String`: The next token in the template.
- `TokenBlockType`: The type of the token block.
- `Integer`: The next index in the template string.

## Examples:
```julia
template =       "{{ variable_block }}   string_block {% if block == true %} {% endif %}"
# result_borders: ^                   ^               ^                     ^^          ^
# result_tokens: [" variable_block ", "   string_block ", " if block == true ", " ", " endif "]
```
"""
function get_next_token(template::String, index::Integer, options::TemplateOptions)
    previous_bracket = ""  # buffer that contains one border token. { - operator, [ - var
    i = index  # i is iterator and index is initial parsing offset.
    n = length(transcode(UInt8, template))
    start_token_idx = i
    end_token_idx = i

    while i <= n
        if _check_substring_at_offset(template, i, options.var.left)
            if i != index
                break  # if token block starting not with var border then it's string block
            end
            if previous_bracket != ""
                error(
                    "Unexpected '" * options.var.left * "' at index $i." *
                    "There are open block with: $previous_bracket already."
                )
            end
            previous_bracket = "["
            i += options.var.left_length  # no need to parse each border character.
            start_token_idx = i  # do not include border part to token.
        elseif _check_substring_at_offset(template, i, options.var.right)
            if previous_bracket != "["
                error(
                    "Mismatched '" * options.var.right * "' braces at index $i. " *
                    "Stack: $previous_bracket"
                )
            end
            previous_bracket = ""
            end_token_idx = i - 1  # i is currently at the start of border string.
            i += options.var.right_length
            break
        elseif _check_substring_at_offset(template, i, options.operator.left)
            if i != index
                break
            end
            if previous_bracket != ""
                error(
                    "Unexpected '" * options.operator.left * "' at index $i. " *
                    "There are open block with: $previous_bracket already."
                )
            end
            previous_bracket = "{"
            i += options.operator.left_length
            start_token_idx = i
        elseif _check_substring_at_offset(template, i, options.operator.right)
            if previous_bracket != "{"
                error(
                    "Mismatched '" * options.operator.right * "' braces at index $i. " *
                    "Stack: $previous_bracket"
                )
            end
            previous_bracket = ""
            end_token_idx = i - 1
            i += options.operator.right_length
            break
        else
            end_token_idx = i
            # using method because unicode can be more than one byte long
            i = nextind(template, i)
        end
    end

    if previous_bracket != ""
        error(
            "Could not parse template no closing bracket for '$previous_bracket'. {} - operators, [] - variables"
        )
    end

    token_type = string_block
    if _check_substring_at_offset(template, index, options.var.left)
        token_type = variable_block
    elseif _check_substring_at_offset(template, index, options.operator.left)
        token_type = operators_block
    end

    token_string = template[start_token_idx:end_token_idx]
    if token_type == string_block
        # To avoid unexpected code execution, we should escape strings.
        token_string = replace(token_string, "\"" => "\\\"")
    end

    return token_string, token_type, i
end

function _is_token_of_type(token::String, token_type::String)::Bool
    token_length = length(token)
    token_type_length = length(token_type)

    for i in 1:(token_length - token_type_length + 1)
        # skip leading whitespaces
        if token[i] in WHITESPACES
            continue
        end

        if token[i:i + token_type_length - 1] == token_type
            return true
        end

        return false
    end

    return false
end

"""
    identify_token_type(token::String, token_block_type::TokenBlockType) -> TokenType

Returns type of token. Raises error if token is not recognized.

## Parameters:
- `token::String`: The token string to identify.
- `token_block_type::TokenBlockType`: The type of token block.

## Returns:
- `TokenType`: The identified token type.
"""
function identify_token_type(token::String, token_block_type::TokenBlockType)::TokenType
    if token_block_type == string_block
        return string_token
    elseif token_block_type == variable_block
        return variable_token
    elseif _is_token_of_type(token, "for")
        return for_token
    elseif _is_token_of_type(token, "if")
        return if_token
    elseif _is_token_of_type(token, "endfor")
        return endfor_token
    elseif _is_token_of_type(token, "endif")
        return endif_token
    elseif _is_token_of_type(token, "include")
        return include_token
    elseif _is_token_of_type(token, "elseif")
        return elseif_token
    elseif _is_token_of_type(token, "else")
        return else_token
    else
        error("Unknown token type: \"$token\"")
    end
end

"""
    update_stack!(token_type::TokenType, stack::Vector{TokenType}, current_index::Integer)

Validates that current token could be inserted into AST-tree of templates. 
Also it updates it if there is a block that adds a depth level (like "for" or "if" operators). 

## Parameters:
- `token_type::TokenType`: The type of the current token.
- `stack::Vector{TokenType}`: The stack of token types.
- `current_index::Integer`: The current index in the template string.
"""
function update_stack!(token_type::TokenType, stack::Vector{TokenType}, current_index::Integer)
    if token_type == endfor_token
        if isempty(stack) || pop!(stack) !== for_token
            error("Unexpected endfor token in template, index: $current_index. Stack: $stack")
        end
    elseif token_type == endif_token
        if isempty(stack) || pop!(stack) !== if_token
            error("Unexpected endif token in template, index: $current_index. Stack: $stack")
        end
    elseif token_type in [for_token, if_token]
        push!(stack, token_type)
    end
end

"""
    fill_node_template_string!(node::Node, token::String, token_type::TokenType, options::TemplateOptions)

Fills node.template_string with corresponding template based on token type.

## Parameters:
- `node::Node`: The current node in the AST.
- `token::String`: The token string.
- `token_type::TokenType`: The type of the token.
- `options::TemplateOptions`: Options for template parsing and rendering.
"""
function fill_node_template_string!(node::Node, token::String, token_type::TokenType, options::TemplateOptions)
    if token_type == string_token
        node.template_string = "\nwrite(_result, \"" * token * "\")"
    elseif token_type == variable_token
        if options.ignore_missing
            node.template_string = "\ntry write(_result, string(" * token * ")) catch end"
        else
            node.template_string = "\nwrite(_result, string(" * token * "))"
        end
    elseif token_type == for_token
        node.template_string = "\n" * token
    elseif token_type == if_token
        node.template_string = "\n" * token
    elseif token_type == endfor_token || token_type == endif_token
        node.template_string = "\nend"
    elseif token_type == elseif_token
        node.template_string = "\n" * token
    elseif token_type == else_token
        node.template_string = "\n" * token
    elseif token_type == include_token
        token_parts = split(token, '"')
        if length(token_parts) != 3
            error("Expected include syntax 'include \"filename.txt\"', got " * token)
        end
        
        if !options.allow_filename_change_dir && '/' in token_parts[2]
            error(
                "Got filename \"" * token_parts[2] * "\" which changes directory_path, " *
                "it is forbidden in this template."
            )
        end

        file_name = replace(token_parts[2], "\\" => "")
        file_contents = read(options.templates_dir * file_name)
        build_tree!(String(file_contents), 1, node, Vector{Julja2.TokenType}(), options)
    end
end

"""
    build_tree!(template::String, current_index::Int, node::Node, stack::Vector{Julja2.TokenType}, options::TemplateOptions)

build_tree is a recursive function that builds a tree from template.
When new control flow operator appears (if, for) it calls build_tree on this block 
and adds new level in tree.

## Parameters:
- `template::String`: The template string to parse.
- `current_index::Int`: The current index in the template string.
- `node::Node`: The current node in the AST.
- `stack::Vector{Julja2.TokenType}`: The stack of token types.
- `options::TemplateOptions`: Options for template parsing and rendering.

## Example:
template is " root_string {% for <body> %} for_string{% if true %} " *
           "if_string {% endif %}{% endfor %} {{ variable }}"
result tree will look like this:
```
root
|
|------ " root_string "
|
|------ for statement
|     |
|     |------ " for_string"
|     |
|     |------ if true
|     |     |
|     |     |---- " if_string "
|
|------ " "
|
|------ variable value
```
"""
function build_tree!(
    template::String,
    current_index::Int,
    node::Node,
    stack::Vector{Julja2.TokenType},
    options::TemplateOptions,
)
    template_length = length(transcode(UInt8, template))
    if current_index > template_length
        if !isempty(stack)
            error(
                "Template is parsed but not all operator blocks is closed. " *
                "Expected: endfor/endif. Stack: ", stack
            )
        end
        return current_index
    end

    while current_index <= template_length
        token, token_block_type, current_index = get_next_token(template, current_index, options)
        token_type = identify_token_type(token, token_block_type)
        update_stack!(token_type, stack, current_index)

        child_node = Node("", [])
        fill_node_template_string!(child_node, token, token_type, options)

        if token_type in [if_token, for_token]
            # when we find if or for we create new level in depth.
            current_index = build_tree!(template, current_index, child_node, stack, options)
        end

        push!(node.children, child_node)

        if token_type in [endfor_token, endif_token]
            # when block is ends we return one level back in AST-tree.
            return current_index
        end
    end

    if current_index > template_length && !isempty(stack)
        error(
            "Template is parsed but not all operator blocks is closed. " *
            "Expected \"" * options.operator.right * "\", stack: $stack",
        )
    end
    return current_index
end

function _build_code(node::Node)::String
    if isempty(node.children)
        return node.template_string
    else
        child_codes = map(_build_code, node.children)
        return node.template_string * join(child_codes)
    end
end

"""
    build_code(node::Node) -> Meta.Parse

Returns a code of nodes that generates given template.

## Parameters:
- `node::Node`: The root node of the AST.

## Returns:
- `Expr`: The generated code from the AST nodes.
"""
function build_code(node::Node)::Expr
    generator_code = _build_code(node)
    generator_code *= "\nreturn String(take!(_result))\nend"
    return Meta.parse(generator_code)
end
