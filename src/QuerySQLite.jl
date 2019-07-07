module QuerySQLite

import Base: !, &, |, ==, !=, coalesce, collect, eltype, getproperty, in,
isdone, isequal, isless, ismissing, iterate, IteratorSize, occursin, show,
startswith
using Base: Generator, NamedTuple, RefValue, SizeUnknown, tail
import Base.Iterators: drop, take
using Base.Meta: quot
import Base.Multimedia: showable
using DataValues: DataValue
import IteratorInterfaceExtensions: getiterator, isiterable
import MacroTools
using MacroTools: @capture
import QueryOperators
import QueryOperators: orderby, query
import SQLite
import SQLite: getvalue
using SQLite: columns, DB, execute!, generate_namedtuple, juliatype,
SQLITE_DONE, SQLITE_NULL, SQLITE_ROW, sqlite3_column_count, sqlite3_column_name,
sqlite3_column_type, sqlite3_step, sqlitevalue, Stmt, tables
using TableShowUtils: printdataresource, printHTMLtable, printtable
import TableTraits: isiterabletable

map_unrolled(call, variables::Tuple{}) = ()
map_unrolled(call, variables) =
    call(first(variables)), map_unrolled(call, tail(variables))...

map_unrolled(call, variables1::Tuple{}, variables2::Tuple{}) = ()
map_unrolled(call, variables1, variables2) =
    call(first(variables1), first(variables2)),
    map_unrolled(call, tail(variables1), tail(variables2))...

partial_map(call, fixed, variables::Tuple{}) = ()
partial_map(call, fixed, variables) =
    call(fixed, first(variables)), partial_map(call, fixed, tail(variables))...

partial_map(call, fixed, variables1::Tuple{}, variables2::Tuple{}) = ()
partial_map(call, fixed, variables1, variables2) =
    call(fixed, first(variables1), first(variables2)),
    partial_map(call, fixed, tail(variables1), tail(variables2))...

as_symbols(them) = map_unrolled(Symbol, (them...,))

struct OutsideCode{Outside}
    outside::Outside
    code::Expr
end

get_code(outside_code::OutsideCode) = outside_code.code

"""
    get_table_names(outside)::Tuple{Symbol}

Get the names of the tables in `outside`
"""
get_table_names(outside::DB) =
    as_symbols(tables(outside).name)
export get_table_names

"""
    get_column_names(outside, table_name)::Tuple{Symbol}

Get column names of `table_name` in `outside`
"""
get_column_names(outside::DB, table_name) =
    as_symbols(columns(outside, String(table_name)).name)
export get_column_names


struct OutsideTables{Outside}
    outside::Outside
end

get_table(outside, table_name::Symbol) =
    OutsideCode(
        outside,
        Expr(:call, getproperty, OutsideTables(outside), table_name)
    )

"""
    get_tables(outside)

`outside` must support [`get_table_names`](@ref).
"""
function get_tables(outside)
    table_names = get_table_names(outside)
    NamedTuple{table_names}(
        partial_map(get_table, outside, table_names)
    )
end
export get_tables

struct OutsideRow{Outside}
    outside::Outside
    table_name::Symbol
end

OutsideRow(outside_row::OutsideRow) =
    OutsideRow(outside_row.outside, outside_row.table_name)

function pop_outsides!(outsides, outside_code::OutsideCode)
    push!(outsides, outside_code.outside)
    outside_code.code
end
pop_outsides!(outsides, something) = something
function combine_outsides(a_function, outside_codes...)
    outsides = Set(Any[])
    codes = partial_map(pop_outsides!, outsides, outside_codes)
    OutsideCode(
        if length(outsides) == 0
            error("No outside")
        elseif length(outsides) > 1
            error("Too many outsides")
        else
            first(outsides)
        end, Expr(:call, a_function, codes...)
    )
end

numbered_argument(number) = Symbol(string("argument", number))
assert_argument(argument, type) = Expr(:(::), argument, type)
maybe_splat(argument, a_type) =
    if @capture a_type Vararg{AType_}
        Expr(:(...), argument)
    else
        argument
    end
function code_instead(location, a_function, types...)
    arguments = ntuple(numbered_argument, length(types))
    Expr(:function,
        Expr(:call,
            a_function,
            map_unrolled(assert_argument, arguments, types)...
        ),
        Expr(:block,
            location,
            Expr(:call,
                combine_outsides,
                a_function,
                map_unrolled(maybe_splat, arguments, types)...
            )
        )
    )
end

macro code_instead(a_function, types...)
    code_instead(__source__, a_function, types...) |> esc
end

# function library

@code_instead (==) OutsideCode Any
@code_instead (==) Any OutsideCode
@code_instead (==) OutsideCode OutsideCode
translate_node(::typeof(==), left, right) =
    string(translate(left), " = ", translate(right))

@code_instead (!=) OutsideCode Any
@code_instead (!=) Any OutsideCode
@code_instead (!=) OutsideCode OutsideCode
translate_node(::typeof(!=), left, right) =
    string(translate(left), " <> ", translate(right))

@code_instead (!) OutsideCode
translate_node(::typeof(!), wrong) = string("NOT ", translate(wrong))

@code_instead (&) OutsideCode Any
@code_instead (&) Any OutsideCode
@code_instead (&) OutsideCode OutsideCode
translate_node(::typeof(&), left, right) =
    string(translate(left), " AND ", translate(right))

@code_instead (|) OutsideCode Any
@code_instead (|) Any OutsideCode
@code_instead (|) OutsideCode OutsideCode
translate_node(::typeof(|), left, right) =
    string(translate(left), " OR ", translate(right))

@code_instead backwards OutsideCode
translate_node(::typeof(backwards), column) =
    string(translate(column), " DESC")

@code_instead coalesce OutsideCode Vararg{Any}

translate_node(::typeof(coalesce), arguments...) =
    string("COALESCE(", join(map_unrolled(translate, arguments...), ", "), ")")

@code_instead drop OutsideCode Integer
translate_node(::typeof(drop), iterator, number) =
    string(translate(iterator), " OFFSET ", number)

get_column(outside_row, column_name) =
    OutsideCode(
        outside_row.outside,
        Expr(:call, getproperty, outside_row, column_name)
    )
function make_model_row_node(::typeof(getproperty), outside_tables::OutsideTables, table_name)
    outside = outside_tables.outside
    column_names = get_column_names(outside, table_name)
    NamedTuple{column_names}(partial_map(
        get_column,
        OutsideRow(outside, table_name),
        column_names
    ))
end
translate_node(::typeof(getproperty), outside_tables::OutsideTables, table_name) =
    string("SELECT * FROM ", table_name)
translate_node(::typeof(getproperty), outside_row::OutsideRow, column_name) =
    column_name

"""
    if_else(switch, yes, no)

`ifelse` that you can add methods to.

```jldoctest
julia> using QuerySQLite

julia> if_else(true, 1, 0)
1

julia> if_else(false, 1, 0)
0
```
"""
if_else(switch, yes, no) = ifelse(switch, yes, no)
export if_else

@code_instead if_else OutsideCode Any Any
@code_instead if_else Any OutsideCode Any
@code_instead if_else Any Any OutsideCode
@code_instead if_else Any OutsideCode OutsideCode
@code_instead if_else OutsideCode Any OutsideCode
@code_instead if_else OutsideCode OutsideCode Any
@code_instead if_else OutsideCode OutsideCode OutsideCode
translate_node(::typeof(if_else), test, right, wrong) = string(
    "CASE WHEN ",
    translate(test),
    " THEN ",
    translate(right),
    " ELSE ",
    translate(wrong),
    " END"
)

@code_instead in OutsideCode Any
@code_instead in Any OutsideCode
@code_instead in OutsideCode OutsideCode
translate_node(::typeof(in), item, collection) =
    string(translate(item), " IN ", collection)

@code_instead isequal OutsideCode Any
@code_instead isequal Any OutsideCode
@code_instead isequal OutsideCode OutsideCode

translate_node(::typeof(isequal), left, right) =
    string(translate(left), " IS NOT DISTINCT FROM ", translate(right))

@code_instead isless OutsideCode Any
@code_instead isless Any OutsideCode
@code_instead isless OutsideCode OutsideCode

translate_node(::typeof(isless), left, right) =
    string(translate(left), " < ", translate(right))

@code_instead ismissing OutsideCode
translate_node(::typeof(ismissing), maybe) =
    string(translate(maybe), " IS NULL")

@code_instead QueryOperators.drop OutsideCode Integer
translate_node(::typeof(QueryOperators.drop), iterator, number) =
    string(translate(iterator), " OFFSET ", number)

@code_instead QueryOperators.filter OutsideCode Any Expr
translate_node(::typeof(QueryOperators.filter), iterator, call, call_expression) =
    string(
        translate(iterator),
        " WHERE ",
        translate(get_code(call(make_model_row(iterator)).code))
    )

@code_instead QueryOperators.orderby OutsideCode Any Expr
translate_node(::typeof(QueryOperators.orderby), unordered, key_function, key_function_expression) = string(
    translate(unordered),
    " ORDER BY ",
    translate(get_code(key_function(make_model_row(unordered))))
)
@code_instead QueryOperators.thenby OutsideCode Any Expr
translate_node(::typeof(QueryOperators.thenby), unordered, key_function, key_function_expression) = string(
    translate(unordered),
    ", ",
    translate(get_code(key_function(make_model_row(unordered))))
)
@code_instead QueryOperators.orderby_descending OutsideCode Any Expr
translate_node(::typeof(QueryOperators.orderby_descending), unordered, key_function, key_function_expression) = string(
    translate(unordered),
    " ORDER BY ",
    translate(get_code(key_function(make_model_row(unordered)))),
    " DESC"
)
@code_instead QueryOperators.thenby_descending OutsideCode Any Expr
translate_node(::typeof(QueryOperators.thenby_descending), unordered, key_function, key_function_expression) = string(
    translate(unordered),
    ", ",
    translate(get_code(key_function(make_model_row(unordered)))),
    "DESC"
)

@code_instead QueryOperators.map OutsideCode Any Expr
make_model_row_node(::typeof(QueryOperators.map), iterator, call, call_expression) =
    call(make_model_row(iterator))
select_as(new_name_make_model_row::Pair{Symbol, <: OutsideCode}) =
    string(translate(get_code(new_name_make_model_row.second)), " AS ", new_name_make_model_row.first)
function translate_node(::typeof(QueryOperators.map), select_table, call, call_expression)
    if @capture select_table $getproperty(outsidetables_OutsideTables, name_)
        string(
            "SELECT ",
            join(Generator(select_as, pairs(call(make_model_row(select_table)))), ", "),
            " FROM ",
            name
        )
    else
        error("over can only be called directly on SQL tables")
    end
end

@code_instead QueryOperators.take OutsideCode Any
translate_node(::typeof(QueryOperators.take), iterator, number) =
    if @capture iterator $(QueryOperators.drop)(inneriterator_, offset_)
        string(
            translate(inneriterator),
            " LIMIT ",
            number,
            " OFFSET ",
            offset
        )
    else
        string(translate(iterator), " LIMIT ", number)
    end

@code_instead QueryOperators.unique OutsideCode Any Expr
function translate_node(::typeof(QueryOperators.unique), repeated, key_function, key_function_expression)
    the_make_model_row = make_model_row(repeated)
    if key_function(the_make_model_row) !== the_make_model_row
        error("Key functions not supported for unique")
    else
        replace(translate(repeated), r"\bSELECT\b" => "SELECT DISTINCT")
    end
end

@code_instead occursin AbstractString OutsideCode
@code_instead occursin Regex OutsideCode
translate_node(::typeof(occursin), needle::AbstractString, haystack) = string(
    translate(haystack),
    " LIKE '%",
    needle,
    "%'"
)
translate_node(::typeof(occursin), needle::Regex, haystack) = string(
    translate(haystack),
    " LIKE ",
    replace(replace(needle.pattern, r"(?<!\\)\.\*" => "%"), r"(?<!\\)\." => "_")
)
translate_node(::typeof(occursin), needle, haystack) = string(
    translate(haystack),
    " LIKE ",
    translate(needle)
)

@code_instead startswith OutsideCode Any
@code_instead startswith Any OutsideCode
@code_instead startswith OutsideCode OutsideCode
translate_node(::typeof(startswith), full, prefix::AbstractString) = string(
    translate(full),
    " LIKE '",
    prefix,
    "%'"
)

@code_instead take OutsideCode Integer
translate_node(::typeof(take), iterator, number) =
    if @capture iterator $drop(inneriterator_, offset_)
        string(
            translate(inneriterator),
            " LIMIT ",
            number,
            " OFFSET ",
            offset
        )
    else
        string(translate(iterator), " LIMIT ", number)
    end

# dispatch
nodes(code::Expr) =
    if @capture code call_(arguments__)
        if call === ifelse
            if_else
        else
            call
        end, arguments...
    elseif @capture code left_ && right_
        &, left, right
    elseif @capture code left_ || right_
        |, left, right
    elseif @capture code if condition_ yes_ else no_ end
        if_else, condition, left, right
    else
        error("Cannot split call $code")
    end

make_model_row_node(arbitrary_function, iterator, arguments...) = make_model_row(iterator)
make_model_row(code::Expr) = make_model_row_node(nodes(code)...)

translate(something) = something
translate(outside_row::OutsideRow) = outside_row.table_name
translate(code::Expr) = translate_node(nodes(code)...)

# collect
query(outside_code::OutsideCode) = outside_code

struct SQLiteCursor{Row}
    statement::Stmt
    status::RefValue{Cint}
    cursor_make_model_row::RefValue{Int}
end

eltype(::SQLiteCursor{Row}) where {Row} = Row
IteratorSize(::Type{<:SQLiteCursor}) = SizeUnknown()

function isdone(cursor::SQLiteCursor)
    status = cursor.status[]
    if status == SQLITE_DONE
        true
    elseif status == SQLITE_ROW
        false
    elseif sqliteerror(cursor.statement.db)
        false
    else
        error("Unknown SQLite cursor status")
    end
end

function getvalue(cursor::SQLiteCursor, column_number::Int, ::Type{Value}) where {Value}
    handle = cursor.statement.handle
    column_type = sqlite3_column_type(handle, column_number)
    if column_type == SQLITE_NULL
        Value()
    else
        julia_type = juliatype(column_type) # native SQLite Int, Float, and Text types
        sqlitevalue(
            if julia_type === Any
                if !isbitstype(Value)
                    Value
                else
                    julia_type
                end
            else
                julia_type
            end, handle, column_number)
    end
end

iterate(cursor::SQLiteCursor{Row}) where {Row} =
    if isdone(cursor)
        nothing
    else
        named_tuple = generate_namedtuple(Row, cursor)
        cursor.cursor_make_model_row[] = 1
        named_tuple, 1
    end

iterate(cursor::SQLiteCursor{Row}, state) where {Row} =
    if state != cursor.cursor_make_model_row[]
        error("State does not match SQLiteCursor make_model_row")
    else
        cursor.status[] = sqlite3_step(cursor.statement.handle)
        if isdone(cursor)
            nothing
        else
            named_tuple = generate_namedtuple(Row, cursor)
            cursor.cursor_make_model_row[] = state + 1
            named_tuple, state + 1
        end
    end

isiterable(::OutsideCode) = true
isiterabletable(::OutsideCode) = true

collect(source::OutsideCode) = collect(getiterator(source))

second((value_1, value_2)) = value_2

name_and_type(handle, column_number, nullable = true, strict_types = true) =
    Symbol(unsafe_string(sqlite3_column_name(handle, column_number))),
    if strict_types
        julia_type = juliatype(handle, column_number)
        if nullable
            DataValue{julia_type}
        else
            julia_type
        end
    else
        Any
    end

function getiterator(outside_code::OutsideCode)
    # TODO REVIEW
    statement = Stmt(outside_code.outside, String(translate(outside_code.code)))
    # bind!(statement, values)
    status = execute!(statement)
    handle = statement.handle
    schema = ntuple(
        let handle = handle
            column_number -> name_and_type(handle, column_number)
        end,
        sqlite3_column_count(handle)
    )
    SQLiteCursor{NamedTuple{
        Tuple(map_unrolled(first, schema)),
        Tuple{map_unrolled(second, schema)...}
    }}(statement, Ref(status), Ref(0))
end

show(stream::IO, source::OutsideCode) =
    printtable(stream, getiterator(source), "SQLite query result")

showable(::MIME"text/html", source::OutsideCode) = true
show(stream::IO, ::MIME"text/html", source::OutsideCode) =
    printHTMLtable(stream, getiterator(source))

showable(::MIME"application/vnd.dataresource+json", source::OutsideCode) = true
show(stream::IO, ::MIME"application/vnd.dataresource+json", source::OutsideCode) =
    printdataresource(stream, getiterator(source))

end # module
