using Query
using Test
using QuerySQLite
import SQLite
using QueryTables

filename = joinpath(@__DIR__, "Chinook_Sqlite.sqlite")
database = Database(filename)
database2 = Database(SQLite.DB(filename))

@testset "QuerySQLite" begin

@test database.Track |>
    @map({_.TrackId, _.Name, _.Composer, _.UnitPrice}) |>
    collect |>
    first |>
    propertynames == (:TrackId, :Name, :Composer, :UnitPrice)

@test (database2.Customer |>
    @map({_.City, _.Country}) |>
    @orderby(_.Country) |>
    DataTable).Country[1] == "Argentina"

@test database.Customer |>
    @map({_.City}) |>
    @unique() |>
    collect |>
    length == 53

@test database.Track |>
    @map({_.TrackId, _.Name}) |>
    @take(10) |>
    collect |>
    length == 10

@test first((database.Track |>
    @map({_.TrackId, _.Name}) |>
    @take(10) |>
    @drop(10) |>
    DataTable).Name)  == "C.O.D."

@test first((
    @from i in database.Track begin
        @orderby descending(i.Bytes), i.Name
        @select {i.TrackId, i.Name, i.Bytes}
        @collect DataTable
    end
    ).Bytes) == 1059546140

@test database.Artist |>
    @join(database.Album, _.ArtistId, _.ArtistId, {_.ArtistId, __.AlbumId}) |>
    DataTable |>
    length == 347

@test (database.Track |>
    @groupby(_.AlbumId) |>
    @map({AlbumId = key(_), Count = length(_.AlbumId)}) |>
    collect |>
    first).Count == 10

end
