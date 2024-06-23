using Julja2
using Test

struct MissingDataObj
    title
    description
    amount
end

missing_obj = MissingDataObj(
    "🌳🐿",
    nothing,
    10,
)

@testset "Various If Statements Test and Unicode Text" begin
    template = Julja2.Julja2Template(
        """
        {% if description != nothing %}
            should not print it 👎
        {% elseif amount > 5 %}
            should print it 1 ✅
        {% else %}
            should not print it 💔
        {% endif %}{% if description != nothing %}
            should not print it 🩹
        {% elseif amount > 15 %}
            should not print it 🚫
        {% else %}
            should print it 2 ✅
        {% endif %}{% if title != "" %}
            should print it 2 {{ title }}
        {% elseif amount > 5 %}
            should not print it 😭
        {% else %}
            should not print it 💢
        {% endif %}
        """
    )
    @test Julja2.julja2_render(template, missing_obj) === """

        should print it 1 ✅

        should print it 2 ✅

        should print it 2 🌳🐿

    """
end

@testset "Nested If Statements Test" begin
    template = Julja2.Julja2Template(
        """
        {% if true %}
        level1
            {% if amount > 5 %}
            level2
                {% if false %}should not print this{%endif%}
            {%endif%}
        {%endif%}
        """
    )
    @test Julja2.julja2_render(template, missing_obj) === 
    """\nlevel1\n    \n    level2\n        \n    \n\n"""
end

struct Student
    id::Int
    name::String
    grade::Float64
end

struct School
    students::Vector{Student}
end

school = School([
    Student(1, "Fred", 78.2),
    Student(2, "Benny", 82.0),
])

@testset "For Statement with Quotes in Text" begin
    template = Julja2.Julja2Template(
        """
        "id","name","grade"{% for student in students %}
        {{ student.id }},{{ student.name }},{{ student.grade }}{% endfor %}
        """
    )
    result = Julja2.julja2_render(template, school)
    @test result === """
        "id","name","grade"
        1,Fred,78.2
        2,Benny,82.0
        """
end

@testset "Nested For and If Statements" begin
    template = Julja2.Julja2Template(
        """
        {% for student in students %}
        {{ student.id }},{{ student.name }}
        {% if student.name == "Fred" %}
        string_Fred has grade {{ student.grade }}. His study group:{% for inner_loop_student in students %}
        - {{ inner_loop_student.name }}{% endfor %}
        {% else %}
        Hi {{ student.name }}
        {% endif %}
        {% endfor %}
        """
    )
    
    result = Julja2.julja2_render(template, school)
    @test result === """

        1,Fred

        string_Fred has grade 78.2. His study group:
        - Fred
        - Benny


        2,Benny

        Hi Benny

        
        """
end

@testset "Unclosed Token Error" begin
    let err = nothing
        try
            template = Julja2.Julja2Template("""{% if true %} some string no endif """)
        catch e
            err = e
        end
    
        @test err isa Exception
        @test sprint(showerror, err) == "Template is parsed but not all operator blocks " *
        "is closed. Expected \"%}\", stack: Julja2.TokenType[Julja2.if_token]"
    end
end

@testset "Error in Token Block" begin
    let err = nothing
        try
            template = Julja2.Julja2Template("""{%  {% if true %} some string no {% endif %}""")
        catch e
            err = e
        end
    
        @test err isa Exception
        @test sprint(showerror, err) == "Could not parse template no closing bracket for " *
        "'{'. {} - operators, [] - variables"
    end
end
