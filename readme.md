# Julja2

Julja2 is a slow library written in Julia that renders templates similar to [Jinja2](https://jinja.palletsprojects.com/en/3.1.x/).

[Initial requirements.](https://github.com/bhftbootcamp/.github/issues/1)

## Usage Example
```julia
using Julja2

struct Book
    title::String
    authors::Vector{String}
    year
end

template = Julja2.Julja2Template("""
###  {{ title }}
{% if year != nothing %}Published in {{ year }}{% endif %}
Authors:{% for author in authors %}
- {{ author }}{% endfor %}""")
print(Julja2.julja2_render(template, Book("Coding 101", ["Mark", "Alice", "Bob"], 2024)))
# Result: 
"""
###  Coding 101
Published in 2024
Authors:
- Mark
- Alice
- Bob
"""
```

## Performance

TL;DR:
This library is 100-200 times slower than Jinja2 or Mustache.

I chose the code generation approach because it was simpler to implement. My goal was to create the library with minimal time investment. This small library, written in a few days with limited features, cannot compete on functionality and speed with libraries that have been developed over longer periods to achieve their current capabilities.

The template generation itself (`parse.jl` file) operates relatively quickly, even faster than Jinja2. In Mustache, template parsing and rendering are not separated, making it difficult to measure directly.

For a detailed comparison, you can check [docs/performance_tests.md](/docs/performance_tests.md).

## How Does It Work?

The library parses templates into executable Julia code that is stored as a result of template parsing. When needed, it executes the code with given parameters to produce the result string.

Overall, the template parsing process tries to construct an AST tree from the template and then create executable code from this. Parsing can be broken down into these four steps:
1. Parsing blocks in the template like {{ variable blocks }}, {% operator blocks %}, and strings.
2. Identifying block types, updating the stack, validating bracket sequences, creating new depth levels, etc.
3. Filling AST tree nodes with code generation that writes node contents to an IOBuffer.
4. Finally, combining the AST tree into code, which is parsed into Julia tokens using Meta.Parse.

For more details, you can check [src/parse.jl](/src/parse.jl). There are many docstrings for better understanding.

## Contributions

This was an interview task, and I do not intend to further develop this library. Therefore, I recommend using other libraries like [Mustache](https://github.com/jverzani/Mustache.jl) or other alternatives.
