using Query
using Test: @test, @testset

@testset "QuerySQLite" begin

filename = joinpath(@__DIR__, "Chinook_Sqlite.sqlite")

database = NamedTuple(OutsideTables(DB(filename)))

database.Album |> @rename(:AlbumId => :AlbumId2) |> @filter(_.AlbumId2 > 3) |> DataFrame

@test names(database.Track |>
    @map({_.TrackId, _.Name, _.Composer, _.UnitPrice}) |>
    DataFrame) == [:TrackId, :Name, :Composer, :UnitPrice]

@test (database.Customer |>
    @map({_.City, _.Country}) |>
    @orderby(_.Country) |>
    DataFrame).Country[1] == "Argentina"

@test length((database.Customer |>
    @map({_.City}) |>
    @unique() |>
    DataFrame).City)  == 53

@test length((database.Track |>
    @map({_.TrackId, _.Name}) |>
    @take(10) |>
    DataFrame).Name) == 10

@test first((database.Track |>
    @map({_.TrackId, _.Name}) |>
    @drop(10) |>
    @take(10) |>
    DataFrame).Name) == "C.O.D."

@test first((database.Track |>
    @map({_.TrackId, _.Name, _.Bytes}) |>
    @orderby_descending(_.Bytes) |>
    @thenby(_.Name) |>
    DataFrame).Bytes) == 1059546140

end
