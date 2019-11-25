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

@test first((
    @from i in database.Track begin
        @orderby i.Bytes, descending(i.Name)
        @select {i.TrackId, i.Name, i.Bytes}
        @collect DataTable
    end
    ).Bytes) == 38747

@test database.Artist |>
    @join(database.Album, _.ArtistId, _.ArtistId, {_.ArtistId, __.AlbumId}) |>
    DataTable |>
    length == 347

@test (database.Track |>
    @groupby(_.AlbumId) |>
    @map({AlbumId = key(_), Count = length(_.AlbumId)}) |>
    collect |>
    first).Count == 10

@test (database.Track |>
    @map({_.Name, _.Milliseconds, _.Bytes, _.AlbumId}) |>
    @filter(_.AlbumId == 1) |>
    collect |>
    first).Name == "For Those About To Rock (We Salute You)"

end

@testset "Systematic tests" begin

filename = joinpath(@__DIR__, "test.sqlite")
connection = DB(filename)
execute!(Stmt(connection, """DROP TABLE IF EXISTS test"""))
execute!(Stmt(connection, """
    CREATE TABLE test (
        a Int,
        b Int,
        c Int,
        d Text,
        e Int
    )"""))
execute!(Stmt(connection, """
    INSERT INTO test VALUES(0, 1, -1, "ab", NULL)
"""))
database = Database(connection)
result =
    database.test |>
    @map({
        equals_test = _.a == _.b,
        not_equals_test = _.a != _.b,
        not_test = !(_.a),
        and_test = _.a & _.b,
        or_test = _.a | _.b,
        times_test = _.a * _.b,
        plus_test = _.a + _.b,
        mod_test = _.a % _.b,
        abs_test = abs(_.c),
        in_test = _.a in (0, 1),
        coalesce_test = coalesce(_.e, _.a),
        if_else_test_1 = if_else(_.b, 1, 0),
        if_else_test_2 = if_else(1, _.b, 0),
        if_else_test_3 = if_else(0, 1, _.a),
        if_else_test_4 = if_else(0, _.b, _.a),
        if_else_test_5 = if_else(_.a, 1, _.a),
        if_else_test_6 = if_else(_.b, _.b, 0),
        if_else_test_7 = if_else(_.b, _.b, _.a),
        ismissing_test = ismissing(_.e),
        max_test = max(_.b, 0),
        min_test = min(_.a, 1),
        occursin_test = occursin(r"a.*", _.d),
        uppercase_test = uppercase(_.d)
    }) |>
    collect |>
    first

@test result.equals_test == 0
@test result.not_equals_test == 1
@test result.not_test == 1
@test result.and_test == 0
@test result.or_test == 1
@test result.times_test == 0
@test result.plus_test == 1
@test result.mod_test == 0
@test result.abs_test == 1
@test result.in_test == 1
@test result.coalesce_test == 0
@test result.if_else_test_1 == 1
@test result.if_else_test_2 == 1
@test result.if_else_test_3 == 0
@test result.if_else_test_4 == 0
@test result.if_else_test_5 == 0
@test result.if_else_test_6 == 1
@test result.if_else_test_7 == 1
@test result.ismissing_test == 1
@test result.max_test == 1
@test result.min_test == 0
@test result.occursin_test == 1
@test result.uppercase_test == "AB"

drop!(connection, "test")

@test_throws ArgumentError Database("file.not_sqlite")

end
