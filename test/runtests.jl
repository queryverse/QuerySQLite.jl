using TestItemRunner
using Documenter
using QuerySQLite

include("test_querysqlite.jl")

@run_package_tests

# Only run doctests on 64 bit and on Julia 1.12 and newer, because a lot of
# output printing was changed and doctests now can't be written to work on
# multiple Julia versions.
Int==Int64 && VERSION>=v"1.12" && doctest(QuerySQLite)
