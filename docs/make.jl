insert!(LOAD_PATH, 1, joinpath(@__DIR__, ".."))

using Unification
using Documenter

DocMeta.setdocmeta!(Unification, :DocTestSetup, :(using Unification); recursive=true)

makedocs(;
    modules=[Unification],
    authors="MarkNahabedian <naha@mit.edu> and contributors",
    repo="https://github.com/MarkNahabedian/Unification.jl/blob/{commit}{path}#{line}",
    sitename="Unification.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://MarkNahabedian.github.io/Unification.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/MarkNahabedian/Unification.jl",
    devbranch="main",
)
