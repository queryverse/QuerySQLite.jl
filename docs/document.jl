using Documenter: deploydocs, makedocs
using Pkg: develop, instantiate, PackageSpec
using QuerySQLite

develop(PackageSpec(path=pwd()))
instantiate()
makedocs(sitename = "QuerySQLite.jl", modules = [QuerySQLite], doctest = false)
deploydocs(repo = "github.com/queryverse/QuerySQLite.jl.git")
