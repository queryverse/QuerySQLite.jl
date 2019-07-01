module QuerySQLite

import Base: !, &, |, ==, !=, coalesce, getproperty, in, isequal, isless, ismissing, occursin, startswith
using Base: NamedTuple, tail
import Base.Iterators: drop, take
using Base.Meta: quot
import DataFrames: DataFrame
import MacroTools
using MacroTools: @capture
import QueryOperators
import QueryOperators: query
import SQLite
using SQLite: columns, DB, tables

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

"""
    get_column_names(outside, table_name)::Tuple{Symbol}

Get column names of `table_name` in `outside`
"""
get_column_names(outside::DB, table_name) =
    as_symbols(columns(outside, String(table_name)).name)

"""
    submit_to(outside, text)

Send `text` to `outside`
"""
submit_to(outside::DB, text) = DataFrame(Query(outside, text))

"""
    abstract type OutsideTables{Outside} end

`Outside` must support [`get_table_names`](@ref), [`get_column_names`](@ref), and [`evaluate`](@ref).
"""
struct OutsideTables{Outside}
    outside::Outside
end

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
translate_call(::typeof(&), left, right) =
    string(translate(left), " OR ", translate(right))

@code_instead backwards OutsideCode
translate_call(::typeof(backwards), column) =
    string(translate(column), " DESC")

@code_instead coalesce OutsideCode Vararg{Any}

translate_call(::typeof(coalesce), arguments...) =
    string("COALESCE(", join(map_unrolled(translate, arguments...), ", "), ")")

@code_instead distinct OutsideCode
translate_call(::typeof(distinct), repeated) =
    replace(translate(repeated), r"\bSELECT\b" => "SELECT DISTINCT")

@code_instead drop OutsideCode Integer
translate_call(::typeof(drop), iterator, number) =
    string(translate(iterator), " OFFSET ", number)

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

@code_instead QueryOperators.filter OutsideCode Any
translate_call(::typeof(QueryOperators.filter), iterator, call) =
    string(
        translate(iterator),
        " WHERE ",
        translate(call(model_row(iterator)).code)
    )

@code_instead QueryOperators.map OutsideCode Any
change_row(::typeof(QueryOperators.map), iterator, call) = call(model_row(iterator))
select_as((name, model)::Tuple{Symbol, OutsideCode}) =
    string(translate(model.code), " AS ", name)
function translate_call(::typeof(QueryOperators.map), select_table, call)
    if @capture select_table $getproperty(outsidetables_OutsideTables, name_)
        string(
            "SELECT ",
            join(map_unrolled(select_as, pairs(call(model_row(select_table)))), ", "),
            " FROM ",
            name
        )
    else
        error("over can only be called directly on SQL tables")
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

translate(outside_table::OutsideTable) =
    string("SELECT * FROM ", check_table)

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

# utilities

change_row(arbitrary_function, iterator, arguments...) = model_row(iterator)

ignore_name((new_name, model)::Tuple{Symbol, OutsideCode}) =
    translate(model.code)

column_or_columns(row::NamedTuple) = map_unrolled(ignore_name, pairs(row))
column_or_columns(outside_code::OutsideCode) = (translate(outside_code.code),)

# SQLite interface

using DataFrames: DataFrame

to_symbols(them) = map_unrolled(Symbol, (them...,))

get_table_names(database::DB) = to_symbols(tables(database).name)
get_column_names(database::DB, table_name) =
    to_symbols(SQLite.columns(database, String(table_name)).name)
submit_to(database::DB, text) = DataFrame(SQLite.Query(database, text))

# dispatch

model_row(code::Expr) =
    if @capture code call_(arguments__)
        change_row(call, arguments...)
    else
        error("Cannot build a model_row row for $code")
    end

translate(something) = something

translate(code::Expr) =
    if @capture code call_(arguments__)
        translate_call(call, arguments...)
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

DataFrame(outside_code::OutsideCode) =
    submit_to(
        outside_code.outside,
        translate(outside_code.code)
    )

end # module
