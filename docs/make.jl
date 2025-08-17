1+1
using Documenter
using TouchstoneParser

DocMeta.setdocmeta!(TouchstoneParser, :DocTestSetup, :(using TouchstoneParser); recursive=true)

makedocs(modules = [TouchstoneParser], clean = true,  format = Documenter.HTML(; size_threshold=100_000_000), sitename = "TouchstoneParser.jl", 
    pages = Any[
    "index.md",
    "api_reference.md"], doctest = true, checkdocs=:none)
     
deploydocs(
    repo = "github.com/uvegege/TouchstoneParser.jl.git",
    push_preview = true,
)

