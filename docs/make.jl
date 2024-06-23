using Julja2
using Documenter

DocMeta.setdocmeta!(Julja2, :DocTestSetup, :(using Julja2); recursive = true)

makedocs(;
    modules = [Julja2],
    sitename = "Julja2.jl",
    format = Documenter.HTML(;
        repolink = "https://github.com/justmark0/Julja2.jl",
        canonical = "https://justmark0.github.io/Julja2.jl",
        edit_link = "master",
        assets = ["assets/favicon.ico"],
        sidebar_sitename = true,  # Set to 'false' if the package logo already contain its name
    ),
    pages = [
        "Home"    => "index.md",
        "Perftest" => "pages/performance_tests.md",
        # Add your pages here ...
    ],
    warnonly = [:doctest, :missing_docs],
)

deploydocs(;
    repo = "github.com/justmark0/Julja2.jl",
    devbranch = "master",
    push_preview = true,
)
