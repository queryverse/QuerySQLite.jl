using Documenter: deploydocs, makedocs
using QuerySQLite

makedocs(sitename="QuerySQLite.jl", modules=[QuerySQLite], doctest=false, warnonly=[:missing_docs])
deploydocs(repo="github.com/queryverse/QuerySQLite.jl.git")
