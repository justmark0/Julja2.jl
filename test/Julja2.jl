using Julja2
using UUIDs
using Test

struct Book
    title::String
    year::Int32
    price::Float64
    map_data
end

my_book = Book(
    "Advanced Julia Programming",
    2024,
    49.99,
    Dict("author" => "Julia team", "code_link" => "https://github.com/JuliaLang/julia"),
)

@testset "Variable Insert Test" begin
    template = Julja2.Julja2Template(
        """
        {{ no_such_variable }}<book>
        <title>{{ title }}</title>
        <authors>
            <author lang="en">John Doe</author>
            <author lang="es">Juan Peréz</author>
        </authors>
        <year>{{ year }}</year>
        <price>{{ price }}</price>
        <p>Author is {{ map_data["author"] }}. Link to source code: {{ map_data["code_link"] }}</p>
        </book>""",
    )

    @test Julja2.julja2_render(template, my_book) === """
    <book>
    <title>Advanced Julia Programming</title>
    <authors>
        <author lang=\"en\">John Doe</author>
        <author lang=\"es\">Juan Peréz</author>
    </authors>
    <year>2024</year>
    <price>49.99</price>
    <p>Author is Julia team. Link to source code: https://github.com/JuliaLang/julia</p>
    </book>"""
end

@testset "Dict as variable source" begin
    template = Julja2.Julja2Template(
        """
        name: cloud_server
        {% if status == 0 %}
        status: offline
        {% elseif status == 1 %}status: online
        {% else %}
        status: NA
        {% endif %}
        {{ a }} + {{ b }} = {{ result }}{{ missing_variable }}"""
    )

    @test Julja2.julja2_render(template, 
        Dict{String,Any}("b" => 0,"status" => 1, "result" => 5, "a" => 2, "b" => 3)) === """
    name: cloud_server
    status: online

    2 + 3 = 5"""
end

struct Project
    name::String
    uuid::UUID
    version::VersionNumber
    deps::Vector{Pair{String, UUID}}
    compat::Vector{Pair{String, VersionNumber}}
end

cryptoapis = Project(
    "CryptoAPIs",
    UUID("5e3d4798-c815-4641-85e1-deed530626d3"),
    v"0.13.0",
    [
        "Base64" => UUID("2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"),
        "Dates" => UUID("ade2ca70-3891-5945-98fb-dc099432e06a"),
        "JSONWebTokens" => UUID("9b8beb19-0777-58c6-920b-28f749fee4d3"),
        "NanoDates" => UUID("46f1a544-deae-4307-8689-c12aa3c955c6"),
    ],
    [
        "JSONWebTokens" => v"1.1.1",
        "NanoDates" => v"0.3.0",
    ],
)

@testset "For Statement Test" begin
    template = Julja2.Julja2Template(
        """
        [compat]
        {% for (name, version) in compat %}
        {{ name }} = {{ version }}{% endfor %}"""
    )

    @test Julja2.julja2_render(template, cryptoapis) === """
    [compat]

    JSONWebTokens = 1.1.1
    NanoDates = 0.3.0"""
end

@testset "Various Borders and Unicode Borders Test" begin
    template = Julja2.Julja2Template(
        """
        [compat]
        ֎֎ for (name, version) in compat @
        [[[ name >>>> = [[[ version >>>>֎֎endfor@""",
        var_borders=BlockBorders("[[[", ">>>>"),
        operator_borders=BlockBorders("֎֎", "@"),
    )

    @test Julja2.julja2_render(template, cryptoapis) === """
    [compat]

    JSONWebTokens = 1.1.1
    NanoDates = 0.3.0"""
end

@testset "Template from File Test" begin
    template = Julja2.Julja2Template(
        read("./templates/Compat.toml")
    )

    @test Julja2.julja2_render(template, cryptoapis) === """
    [compat]
    JSONWebTokens = 1.1.1
    NanoDates = 0.3.0"""
end

@testset "Template from Macro Test" begin
    template = julja2_template"""
    [compat]
    {% for (name, version) in compat %}
    {{ name }} = {{ version }}{% endfor %}
    """

    @test Julja2.julja2_render(template, cryptoapis) === """
    [compat]

    JSONWebTokens = 1.1.1
    NanoDates = 0.3.0
    """
end

@testset "Complex Test of Include, if, for Iterating Two Variables and File Read" begin
    template = Julja2.Julja2Template(
        read("./templates/Project.toml"),
        templates_dir="./templates",
    )

    @test Julja2.julja2_render(template, cryptoapis) === """
    name = CryptoAPIs
    uuid = 5e3d4798-c815-4641-85e1-deed530626d3
    version = 0.13.0

    [deps]
    Base64 = 2a0f44e3-6c83-55bd-87e4-b1978d98bd5f
    Dates = ade2ca70-3891-5945-98fb-dc099432e06a
    JSONWebTokens = 9b8beb19-0777-58c6-920b-28f749fee4d3
    NanoDates = 46f1a544-deae-4307-8689-c12aa3c955c6

    [compat]
    JSONWebTokens = 1.1.1
    NanoDates = 0.3.0"""
end

@testset "XSS Protection Test" begin
    struct JustText
        text::String
    end

    template = Julja2.Julja2Template("""
        error("trying to check if this executes")
        {{ text }}
        """)

    @test Julja2.julja2_render(template, 
    JustText("""print("test")\nerror("will that exexute?")""")) === """
        error("trying to check if this executes")
        print("test")
        error("will that exexute?")
        """
end

@testset "XSS Protection Test" begin
    template = Julja2.Julja2Template("""
    error("trying to check if this executes")
    {{ text }}
    """)

    @test Julja2.julja2_render(template, 
    JustText("""print("test")\nerror("will that exexute?")""")) === """
        error("trying to check if this executes")
        print("test")
        error("will that exexute?")
        """
end

@testset "Missing variable test" begin
    let err = nothing
        try
            template = Julja2.Julja2Template("""{{ text }}""", ignore_missing_vars=false)
            Julja2.julja2_render(template, Dict{String, Int}())
        catch e
            err = e
        end

        @test err isa Exception
        @test replace(sprint(showerror, err), "`" => "") in [
            "UndefVarError: text not defined", 
            "UndefVarError: text not defined in Julja2",
        ]
    end
end
