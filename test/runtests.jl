using QuerySQLite
using Query
using QueryTables
using Test

@testset "QuerySQLite" begin

filename = joinpath(@__DIR__, "Chinook_Sqlite.sqlite")

c = SQLiteConnection(filename)

dt = c.Album |> @filter(_.a > 3) |> DataTable

@test length(dt)==347

end
