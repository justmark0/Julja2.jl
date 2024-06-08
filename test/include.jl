using Julja2
using Test

struct Compat
    compat::Vector{Pair{String, VersionNumber}}
end

dependencies = Compat(
    [
        "JSONWebTokens" => v"1.1.1",
        "NanoDates" => v"0.3.0",
    ],
)

@testset "Nested Include Files" begin
    template = Julja2.Julja2Template(
        """
        first file
        {% include "ImportCompat.toml" %}
        end first file""",
        templates_dir="./templates",
    )
    result = Julja2.julja2_render(template, dependencies)
    @test result === """
    first file
    import compat
    [compat]
    JSONWebTokens = 1.1.1
    NanoDates = 0.3.0
    end import compat
    end first file"""
end

@testset "Include with Allowed Path Change in Filename" begin
    template = Julja2.Julja2Template(
        """
        yet another file
        {% include "templates/Compat.toml" %}
        """,
        allow_filename_change_dir=true,
    )
    result = Julja2.julja2_render(template, dependencies)
    @test result === """
    yet another file
    [compat]
    JSONWebTokens = 1.1.1
    NanoDates = 0.3.0
    """
end

@testset "Include with Forbidden Path Change in Filename" begin
    let err = nothing
        try
            template = Julja2.Julja2Template(
                """
                yet another file
                {% include "../src/api.jl" %}
                """) # by default changing directory_path is not allowed
        catch e
            err = e
        end

        @test err isa Exception
        @test sprint(showerror, err) == "Got filename \"../src/api.jl\" which changes " *
        "directory_path, it is forbidden in this template."
    end
end
