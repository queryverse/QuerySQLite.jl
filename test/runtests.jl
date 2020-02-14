using QuerySQLite

using DataValues: DataValue
using Dates: Date, DateTime, format, Time
using Documenter: doctest
using Query
using QueryTables
using SQLite: DB, drop!, execute, Stmt
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

@test collect(
    database.Track |>
    @select(:AlbumId, :Composer) |>
    @mutate(bar = _.AlbumId * 2)
)[1].AlbumId == 1

end

@testset "Systematic tests" begin

filename = joinpath(@__DIR__, "tmp", "test.sqlite")
isfile(filename) && rm(filename)
cp(joinpath(@__DIR__, "test.sqlite"), filename)

connection = DB(filename)
execute(Stmt(connection, """DROP TABLE IF EXISTS test"""))
execute(Stmt(connection, """
    CREATE TABLE test (
        zero Int,
        one Int,
        negative_one Int,
        ab Text,
        null_column Int,
        A_code Int,
        a Text,
        b Text,
        a_space Text,
        a_underscore Text,
        a_wild Text,
        one_point_one_one Real,
        datetime_text Text,
        format Text
    )"""))
execute(Stmt(connection, """
    INSERT INTO test VALUES(0, 1, -1, "ab", NULL, 65, "a", "b", " a ", "_a_", "a%", 1.11, "2019-12-08T11:09:00", "%Y-%m-%d %H:%M:%S")
"""))
small = Database(connection)

@test (small.test |>
    @groupby(_.zero) |>
    @map({
        join_test = join(_.ab)
    }) |>
    collect |>
    first).join_test == "ab"

result =
    small.test |>
    @map({
        equals_test = _.zero == _.one,
        not_equals_test = _.zero != _.one,
        not_test = !(_.zero),
        and_test = _.zero & _.one,
        or_test = _.zero | _.one,
        times_test = _.zero * _.one,
        divide_test = _.zero / _.one,
        plus_test = _.zero + _.one,
        minus_test = _.one - _.zero,
        mod_test = _.zero % _.one,
        abs_test = abs(_.negative_one),
        in_test = _.zero in (0, 1),
        coalesce_test = coalesce(_.null_column, _.zero),
        if_else_test_1 = if_else(_.one, 1, 0),
        if_else_test_2 = if_else(1, _.one, 0),
        if_else_test_3 = if_else(0, 1, _.zero),
        if_else_test_4 = if_else(0, _.one, _.zero),
        if_else_test_5 = if_else(_.zero, 1, _.zero),
        if_else_test_6 = if_else(_.one, _.one, 0),
        if_else_test_7 = if_else(_.one, _.one, _.zero),
        ismissing_test = ismissing(_.null_column),
        lowercase_test = lowercase(_.ab),
        max_test = max(_.one, 0),
        min_test = min(_.zero, 1),
        occursin_test = occursin("a%", _.ab),
        occursin_test_2 = occursin(_.a_wild, "ab"),
        occursin_test_3 = occursin(_.a_wild, _.ab),
        uppercase_test = uppercase(_.ab),
        char_test = char(_.A_code),
        instr_test_1 = instr(_.ab, "b"),
        instr_test_2 = instr("ab", _.b),
        instr_test_3 = instr(_.ab, _.b),
        hex_test = hex(_.ab),
        strip_test = strip(_.a_space),
        strip_test_2 = strip(_.a_underscore, '_'),
        repr_test = repr(_.ab),
        replace_test = replace(_.ab, "b" => "a"),
        round_test_1 = round(_.one_point_one_one, digits = 1),
        round_test_2 = round(_.one_point_one_one),
        SubString_test_1 = SubString(_.ab, 2, 2),
        SubString_test_2 = SubString(_.ab, 2),
        random_test = rand(BySQL(_), Int),
        # TODO: fix
        # randstring_test = randstring(BySQL(_), 4),
        # randstring_test2 = randstring(_.one),
        format_test = format(_.datetime_text, "%Y-%m-%d %H:%M:%S"),
        format_test_2 = format("2019-12-08T11:09:00", _.format),
        format_test_3 = format(_.datetime_text, _.format),
        type_of_test = type_of(_.zero),
        convert_test = convert(Int, _.b),
        string_test = string(_.a, _.b)
    }) |>
    collect |>
    first

@test result.equals_test == 0
@test result.not_equals_test == 1
@test result.not_test == 1
@test result.and_test == 0
@test result.or_test == 1
@test result.times_test == 0
@test result.divide_test == 0
@test result.plus_test == 1
@test result.minus_test == 1
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
@test result.occursin_test_2 == 1
@test result.occursin_test_3 == 1
@test result.uppercase_test == "AB"
@test result.lowercase_test == "ab"
@test result.char_test == "A"
@test result.instr_test_1 == 2
@test result.instr_test_2 == 2
@test result.instr_test_3 == 2
@test result.hex_test == "6162"
@test result.strip_test == "a"
@test result.strip_test_2 == "a"
@test result.repr_test == "\'ab\'"
@test result.replace_test == "aa"
@test result.round_test_1 == 1.1
@test result.round_test_2 == 1.0
@test result.SubString_test_1 == "b"
@test result.SubString_test_2 == "b"
@test result.random_test isa DataValue{Int}
@test_broken length(result.randomstring_test) == 4
@test_broken length(result.randomstring_test2) == 1
@test result.format_test == "2019-12-08 11:09:00"
@test result.format_test_2 == "2019-12-08 11:09:00"
@test result.format_test_3 == "2019-12-08 11:09:00"
@test result.type_of_test == "integer"
@test result.string_test == "ab"

drop!(connection, "test")

@test_throws ArgumentError Database("file.not_sqlite")

end
