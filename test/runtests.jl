using Query
using Test
using QuerySQLite
using SQLite: DB, drop!, execute!, Stmt
using QueryTables

@testset "SQLite tutorial" begin

filename = joinpath(@__DIR__, "Chinook_Sqlite.sqlite")
database = Database(filename)
database2 = Database(DB(filename))

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

@testset "Systematic tests" begin

filename = joinpath(@__DIR__, "test.sqlite")
connection = DB(filename)

execute!(Stmt(connection, """
    CREATE TABLE test (
        a Int,
        b Int,
        c Int
    )"""))
execute!(Stmt(connection, """
    INSERT INTO test VALUES(0, 1, -1)
"""))
database = Database(connection)

result =
    database.test |>
    @map({
        c = _.a == _.b,
        d = _.a != _.b,
        e = !(_.a),
        f = _.a & _.b,
        g = _.a | _.b,
        h = _.a * _.b,
        i = _.a + _.b,
        j = _.a % _.b,
        k = abs(_.c)
    }) |>
    collect |>
    first

@test result.c == 0
@test result.d == 1
@test result.e == 1
@test result.f == 0
@test result.g == 1
@test result.h == 0
@test result.i == 1
@test result.j == 0
@test result.k == 1

drop!(connection, "test")

end
