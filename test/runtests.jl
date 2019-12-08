using QuerySQLite

using DataValues: DataValue
using Dates: Date, DateTime, Time
using Documenter: doctest
using Query
using QueryTables
using SQLite: DB, drop!, execute!, Stmt
using Statistics: mean
using Test

doctest(QuerySQLite)

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
    @map({_.Name, _.Milliseconds, _.Bytes, _.AlbumId}) |>
    @filter(_.AlbumId == 1) |>
    collect |>
    first).Name == "For Those About To Rock (We Salute You)"

group_by_row =
    database.Track |>
    @groupby(_.AlbumId) |>
    @map({
        AlbumId = key(_),
        length = length(_.AlbumId),
        sum = sum(_.Milliseconds),
        min = min(_.Milliseconds),
        max = max(_.Milliseconds),
        mean = mean(_.Milliseconds)
    }) |>
    collect |>
    first

@test group_by_row.AlbumId == 1
@test group_by_row.length == 10
@test group_by_row.sum == 2400415
@test group_by_row.min == 199836
@test group_by_row.mean == 240041.5

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
        e Int,
        f Int,
        g Text,
        h Text,
        i Text,
        j Real,
        k Text,
        l Text,
        m Text
    )"""))
execute!(Stmt(connection, """
    INSERT INTO test VALUES(0, 1, -1, "ab", NULL, 65, "b", " a ", "_a_", 1.11, "2019-12-08", "2019-12-08T11:09:00", "11:09:00")
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
        lowercase_test = lowercase(_.d),
        max_test = max(_.b, 0),
        min_test = min(_.a, 1),
        occursin_test = occursin(r"A.*", _.d),
        uppercase_test = uppercase(_.d),
        char_test = char(_.f),
        instr_test_1 = instr(_.d, "b"),
        instr_test_2 = instr("ab", _.g),
        instr_test_3 = instr(_.d, _.g),
        hex_test = hex(_.d),
        strip_test = strip(_.h),
        strip_test_2 = strip(_.i, '_'),
        repr_test = repr(_.d),
        replace_test = replace(_.d, "b" => "a"),
        round_test_1 = round(_.j, digits = 1),
        round_test_2 = round(_.j),
        SubString_test_1 = SubString(_.d, 2, 2),
        SubString_test_2 = SubString(_.d, 2),
        random_test = rand(BySQL(_), Int),
        date_test = Date(_.k),
        datetime_test = DateTime(_.l),
        time_test= Time(_.m),
        type_of_test = type_of(_.a),
        convert_test = convert(Int, _.g)
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
@test result.lowercase_test == "ab"
@test result.char_test == "A"
# TODO: fix broken tests
@test_broken result.instr_test_1 == 2
@test result.instr_test_2 == 2
@test result.instr_test_3 == 2
@test result.hex_test == "6162"
@test result.strip_test == "a"
@test result.strip_test_2 == "a"
@test result.repr_test == "\'ab\'"
@test_broken result.replace_test == "aa"
@test result.round_test_1 == 1.1
@test result.round_test_2 == 1.0
@test result.SubString_test_1 == "b"
@test result.SubString_test_2 == "b"
@test result.random_test isa DataValue{Int}
@test result.date_test == "2019-12-08"
@test result.datetime_test == "2019-12-08 11:09:00"
@test result.time_test == "11:09:00"
@test result.type_of_test == "integer"

drop!(connection, "test")

@test_throws ArgumentError Database("file.not_sqlite")

end

# TODO: add doctests as tests
