module QuerySQLite

import Base: !, &, |, ==, !=, coalesce, getproperty, in, isequal, isless, ismissing, occursin, startswith
using Base: Generator, NamedTuple, tail
import Base.Iterators: drop, take
using Base.Meta: quot
import MacroTools
using MacroTools: @capture
import QueryOperators
import QueryOperators: orderby, query
import SQLite
using SQLite: columns, DB, tables
import IteratorInterfaceExtensions, TableTraits
using DataValues
import TableShowUtils

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

"""
    abstract type OutsideTables{Outside} end

`Outside` must support [`get_table_names`](@ref), [`get_column_names`](@ref), and [`submit_to`](@ref).
"""
struct OutsideTables{Outside}
    outside::Outside
end
export OutsideTables

struct OutsideTable{Outside}
    outside::Outside
    table_name::Symbol
end

struct OutsideRow{Outside}
    outside::Outside
    table_name::Symbol
end

OutsideRow(outside_table::OutsideTable) =
    OutsideRow(outside_table.outside, outside_table.table_name)

make_outside_table(outside_tables, table_name) =
    OutsideCode(
        outside_tables.outside,
        Expr(:call, getproperty, outside_tables, table_name)
    )

function NamedTuple(outside_tables::OutsideTables)
    table_names = get_table_names(outside_tables.outside)
    NamedTuple{table_names}(partial_map(
        make_outside_table,
        outside_tables,
        table_names
    ))
end

function unwrap!(outsides, outside_code::OutsideCode)
    push!(outsides, outside_code.outside)
    outside_code.code
end
unwrap!(outsides, something) = something
function one_outside(a_function, arguments...)
    outsides = Set(Any[])
    unwrapped_arguments = partial_map(unwrap!, outsides, arguments)
    OutsideCode(
        if length(outsides) == 0
            error("No outside")
        elseif length(outsides) > 1
            error("Too many outsides")
        else
            first(outsides)
        end, Expr(:call, a_function, unwrapped_arguments...)
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
                one_outside,
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
translate_call(::typeof(==), left, right) =
    string(translate(left), " = ", translate(right))

@code_instead (!=) OutsideCode Any
@code_instead (!=) Any OutsideCode
@code_instead (!=) OutsideCode OutsideCode
translate_call(::typeof(!=), left, right) =
    string(translate(left), " <> ", translate(right))

@code_instead (!) OutsideCode
translate_call(::typeof(!), wrong) = string("NOT ", translate(wrong))

@code_instead (&) OutsideCode Any
@code_instead (&) Any OutsideCode
@code_instead (&) OutsideCode OutsideCode
translate_call(::typeof(&), left, right) =
    string(translate(left), " AND ", translate(right))

@code_instead (|) OutsideCode Any
@code_instead (|) Any OutsideCode
@code_instead (|) OutsideCode OutsideCode
translate_call(::typeof(|), left, right) =
    string(translate(left), " OR ", translate(right))

@code_instead backwards OutsideCode
translate_call(::typeof(backwards), column) =
    string(translate(column), " DESC")

@code_instead coalesce OutsideCode Vararg{Any}

translate_call(::typeof(coalesce), arguments...) =
    string("COALESCE(", join(map_unrolled(translate, arguments...), ", "), ")")

@code_instead drop OutsideCode Integer
translate_call(::typeof(drop), iterator, number) =
    string(translate(iterator), " OFFSET ", number)

change_row(::typeof(getproperty), outside_tables::OutsideTables, table_name) =
    model_row(OutsideTable(outside_tables.outside, table_name))
translate_call(::typeof(getproperty), outside_row::OutsideRow, column_name) =
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
translate_call(::typeof(if_else), test, right, wrong) = string(
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
translate_call(::typeof(in), item, collection) =
    string(translate(item), " IN ", collection)

@code_instead isequal OutsideCode Any
@code_instead isequal Any OutsideCode
@code_instead isequal OutsideCode OutsideCode

translate_call(::typeof(isequal), left, right) =
    string(translate(left), " IS NOT DISTINCT FROM ", translate(right))

@code_instead isless OutsideCode Any
@code_instead isless Any OutsideCode
@code_instead isless OutsideCode OutsideCode

translate_call(::typeof(isless), left, right) =
    string(translate(left), " < ", translate(right))

@code_instead ismissing OutsideCode
translate_call(::typeof(ismissing), maybe) =
    string(translate(maybe), " IS NULL")

@code_instead QueryOperators.drop OutsideCode Integer
translate_call(::typeof(QueryOperators.drop), iterator, number) =
    string(translate(iterator), " OFFSET ", number)

@code_instead QueryOperators.filter OutsideCode Any Expr
translate_call(::typeof(QueryOperators.filter), iterator, call, call_expression) =
    string(
        translate(iterator),
        " WHERE ",
        translate(call(model_row(iterator)).code)
    )

@code_instead QueryOperators.orderby OutsideCode Any Expr
translate_call(::typeof(QueryOperators.orderby), unordered, key_function, key_function_expression) = string(
    translate(unordered),
    " ORDER BY ",
    translate(key_function(model_row(unordered)).code)
)
@code_instead QueryOperators.thenby OutsideCode Any Expr
translate_call(::typeof(QueryOperators.thenby), unordered, key_function, key_function_expression) = string(
    translate(unordered),
    ", ",
    translate(key_function(model_row(unordered)).code)
)
@code_instead QueryOperators.orderby_descending OutsideCode Any Expr
translate_call(::typeof(QueryOperators.orderby_descending), unordered, key_function, key_function_expression) = string(
    translate(unordered),
    " ORDER BY ",
    translate(key_function(model_row(unordered)).code),
    " DESC"
)
@code_instead QueryOperators.thenby_descending OutsideCode Any Expr
translate_call(::typeof(QueryOperators.thenby_descending), unordered, key_function, key_function_expression) = string(
    translate(unordered),
    ", ",
    translate(key_function(model_row(unordered)).code),
    "DESC"
)

@code_instead QueryOperators.map OutsideCode Any Expr
change_row(::typeof(QueryOperators.map), iterator, call, call_expression) = call(model_row(iterator))
select_as(new_name_model::Pair{Symbol, <: OutsideCode}) =
    string(translate(new_name_model.second.code), " AS ", new_name_model.first)
function translate_call(::typeof(QueryOperators.map), select_table, call, call_expression)
    if @capture select_table $getproperty(outsidetables_OutsideTables, name_)
        string(
            "SELECT ",
            join(Generator(select_as, pairs(call(model_row(select_table)))), ", "),
            " FROM ",
            name
        )
    else
        error("over can only be called directly on SQL tables")
    end
end

@code_instead QueryOperators.take OutsideCode Any
translate_call(::typeof(QueryOperators.take), iterator, number) =
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
function translate_call(::typeof(QueryOperators.unique), repeated, key_function, key_function_expression)
    model = model_row(repeated)
    if key_function(model) !== model
        error("Key functions not supported for unique")
    else
        replace(translate(repeated), r"\bSELECT\b" => "SELECT DISTINCT")
    end
end

@code_instead occursin AbstractString OutsideCode
@code_instead occursin Regex OutsideCode
translate_call(::typeof(occursin), needle::AbstractString, haystack) = string(
    translate(haystack),
    " LIKE '%",
    needle,
    "%'"
)
translate_call(::typeof(occursin), needle::Regex, haystack) = string(
    translate(haystack),
    " LIKE ",
    replace(replace(needle.pattern, r"(?<!\\)\.\*" => "%"), r"(?<!\\)\." => "_")
)
translate_call(::typeof(occursin), needle, haystack) = string(
    translate(haystack),
    " LIKE ",
    translate(needle)
)

make_outside_column(outside_table, column_name) =
    OutsideCode(
        outside_table.outside,
        Expr(:call, getproperty, OutsideRow(outside_table), column_name)
    )
function model_row(outside_table::OutsideTable)
    column_names = get_column_names(outside_table.outside, outside_table.table_name)
    NamedTuple{column_names}(partial_map(
        make_outside_column,
        outside_table,
        column_names
    ))
end
translate(outside_table::OutsideTable) =
    string("SELECT * FROM ", outside_table.table_name)

@code_instead startswith OutsideCode Any
@code_instead startswith Any OutsideCode
@code_instead startswith OutsideCode OutsideCode
translate_call(::typeof(startswith), full, prefix::AbstractString) = string(
    translate(full),
    " LIKE '",
    prefix,
    "%'"
)

@code_instead take OutsideCode Integer
translate_call(::typeof(take), iterator, number) =
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

change_row(arbitrary_function, iterator, arguments...) = model_row(iterator)

model_row(code::Expr) =
    if @capture code call_(arguments__)
        change_row(call, arguments...)
    else
        error("Cannot build a model_row row for $code")
    end

translate(something) = something

translate(code::Expr) =
    if @capture code call_(arguments__)
        translate_call(if call === ifelse
            if_else
        else
            call
        end, arguments...)
    elseif @capture code left_ && right_
        translate_call(&, left, right)
    elseif @capture code left_ | right_
        translate_call(|, left, right)
    elseif @capture code if condition_ yes_ else no_ end
        translate_call(if_else, condition, left, right)
    else
        error("Cannot translate code $code")
    end

# collect
query(outside_code::OutsideCode) = outside_code

struct SQLiteCursor{T}
    stmt::SQLite.Stmt
    status::Base.RefValue{Cint}
    cur_row::Base.RefValue{Int}
end

Base.eltype(q::SQLiteCursor{T}) where {T} = T
Base.IteratorSize(::Type{<:SQLiteCursor}) = Base.SizeUnknown()

function isdone(q::SQLiteCursor)
    st = q.status[]
    st == SQLite.SQLITE_DONE && return true
    st == SQLite.SQLITE_ROW || SQLite.sqliteerror(q.stmt.db)
    return false
end

function SQLite.getvalue(q::SQLiteCursor, col::Int, ::Type{T}) where {T}
    handle = q.stmt.handle
    t = SQLite.sqlite3_column_type(handle, col)
    if t == SQLite.SQLITE_NULL
        return T()
    else
        TT = SQLite.juliatype(t) # native SQLite Int, Float, and Text types
        return SQLite.sqlitevalue(ifelse(TT === Any && !isbitstype(T), T, TT), handle, col)
    end
end

function Base.iterate(q::SQLiteCursor{NT}) where {NT}
    isdone(q) && return nothing
    nt = SQLite.generate_namedtuple(NT, q)
    q.cur_row[] = 1
    return nt, 1
end

function Base.iterate(q::SQLiteCursor{NT}, state) where {NT}
    state != q.cur_row[] && error("FOO")
    q.status[] = SQLite.sqlite3_step(q.stmt.handle)
    isdone(q) && return nothing
    nt = SQLite.generate_namedtuple(NT, q)
    q.cur_row[] = state + 1
    return nt, state + 1
end

IteratorInterfaceExtensions.isiterable(::OutsideCode) = true
TableTraits.isiterabletable(::OutsideCode) = true

Base.collect(source::OutsideCode) = collect(IteratorInterfaceExtensions.getiterator(source))

function IteratorInterfaceExtensions.getiterator(outside_code::OutsideCode)
    # TODO REVIEW
    stricttypes = true
    nullable = true

    stmt = SQLite.Stmt(outside_code.outside, translate(outside_code.code))
    # bind!(stmt, values)
    status = SQLite.execute!(stmt)
    cols = SQLite.sqlite3_column_count(stmt.handle)
    header = Vector{Symbol}(undef, cols)
    types = Vector{Type}(undef, cols)
    for i = 1:cols
        header[i] = Symbol(unsafe_string(SQLite.sqlite3_column_name(stmt.handle, i)))
        if nullable
            types[i] = stricttypes ? DataValue{SQLite.juliatype(stmt.handle, i)} : Any
        else
            types[i] = stricttypes ? SQLite.juliatype(stmt.handle, i) : Any
        end
    end
    return SQLiteCursor{NamedTuple{Tuple(header), Tuple{types...}}}(stmt, Ref(status), Ref(0))
end

function Base.show(io::IO, source::OutsideCode)
    TableShowUtils.printtable(io, IteratorInterfaceExtensions.getiterator(source), "SQLite query result")
end

function Base.show(io::IO, ::MIME"text/html", source::OutsideCode)
    TableShowUtils.printHTMLtable(io, IteratorInterfaceExtensions.getiterator(source))
end

Base.Multimedia.showable(::MIME"text/html", source::OutsideCode) = true

function Base.show(io::IO, ::MIME"application/vnd.dataresource+json", source::OutsideCode)
    TableShowUtils.printdataresource(io, IteratorInterfaceExtensions.getiterator(source))
end

Base.Multimedia.showable(::MIME"application/vnd.dataresource+json", source::OutsideCode) = true

end # module
