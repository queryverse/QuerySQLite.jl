# All code is attached to its underlying database source
struct SourceCode{Source}
    source::Source
    code::Union{Expr, Nothing}
end

"""
    struct BySQL{Source}

If you would like a statement to be evaluated by SQL, not Julia, and
none of the arguments are SQL code, you can use BySQL to hack dispatch.

```jldoctest
julia> using QuerySQLite

julia> using Query: @map

julia> using DataValues: DataValue

julia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, "test", "Chinook_Sqlite.sqlite"));

julia> result = database.Track |> @map({a = rand(BySQL(_), Int)});

julia> collect(result)[1].a isa DataValue{Int}
true
```
"""
struct BySQL{Source}
    source::Source
end

export BySQL

# Every time `SourceCode` objects are combined, check to see whether they all come from the same source
function pop_source!(sources, something)
    something
end
function pop_source!(sources, source_code::SourceCode)
    push!(sources, source_code.source)
    source_code.code
end
function pop_source!(sources, by_sql::BySQL)
    push!(sources, by_sql.source)
    by_sql
end
function key_pop_source!(sources, (key, source_code))
    code = pop_source!(sources, source_code)
    Expr(:kw, key, code)
end

function combine_sources(a_function, source_codes...; key_source_codes...)
    sources = Set(Any[])
    codes = [
        pop_source!(sources, source_code)
        for source_code in source_codes
    ]
    filter!(codes) do code
        !(code isa BySQL)
    end
    key_codes = [
        key_pop_source!(sources, key_source_code)
        for key_source_code in key_source_codes
    ]
    if length(sources) != 1
        error("Expected exactly one source; got ($(sources...))")
    else
        SourceCode(
            first(sources),
            Expr(:call, a_function, Expr(:parameters, key_codes...), codes...)
        )
    end
end

# `@code_instead` hijacks call to create Julia expressions instead of evaluating functions
function numbered_argument(number)
    Symbol(string("argument", number))
end

function assert_type(argument, type)
    Expr(:(::), argument, type)
end

# Splat Varargs
function maybe_splat(argument, a_type)
    if @capture a_type Vararg{AType_}
        Expr(:(...), argument)
    else
        argument
    end
end

function code_instead(location, a_function, types...)
    arguments = ntuple(numbered_argument, length(types))
    keywords = Expr(:parameters, Expr(:..., :keywords))
    Expr(:function,
        Expr(:call, a_function, keywords, map(assert_type, arguments, types)...),
        Expr(:block, location, Expr(:call,
            combine_sources,
            keywords,
            a_function,
            map(maybe_splat, arguments, types)...
        ))
    )
end

macro code_instead(a_function, types...)
    code_instead(__source__, a_function, types...) |> esc
end

# Currently, query doesn't do anything
function QueryOperators.query(source_code::SourceCode)
    source_code
end

@code_instead (==) SourceCode Any
@code_instead (==) Any SourceCode
@code_instead (==) SourceCode SourceCode

@code_instead (!=) SourceCode Any
@code_instead (!=) Any SourceCode
@code_instead (!=) SourceCode SourceCode

@code_instead (!) SourceCode

@code_instead (&) SourceCode Any
@code_instead (&) Any SourceCode
@code_instead (&) SourceCode SourceCode

@code_instead (|) SourceCode Any
@code_instead (|) Any SourceCode
@code_instead (|) SourceCode SourceCode

@code_instead (*) SourceCode Any
@code_instead (*) Any SourceCode
@code_instead (*) SourceCode SourceCode

@code_instead (-) SourceCode Any
@code_instead (-) Any SourceCode
@code_instead (-) SourceCode SourceCode

@code_instead (+) SourceCode Any
@code_instead (+) Any SourceCode
@code_instead (+) SourceCode SourceCode

@code_instead (/) SourceCode Any
@code_instead (/) Any SourceCode
@code_instead (/) SourceCode SourceCode

@code_instead (%) SourceCode Any
@code_instead (%) Any SourceCode
@code_instead (%) SourceCode SourceCode

@code_instead abs SourceCode

@code_instead char SourceCode Vararg{Any}

@code_instead coalesce SourceCode Vararg{Any}

@code_instead convert Type{Int} SourceCode

# TODO: support dateformat
@code_instead Date SourceCode

# TODO: support dateformat
@code_instead DateTime SourceCode

@code_instead QueryOperators.drop SourceCode Integer

@code_instead QueryOperators.filter SourceCode Any Expr

@code_instead QueryOperators.groupby SourceCode Any Expr Any Expr

@code_instead hex SourceCode

@code_instead if_else SourceCode Any Any
@code_instead if_else Any SourceCode Any
@code_instead if_else Any Any SourceCode
@code_instead if_else Any SourceCode SourceCode
@code_instead if_else SourceCode Any SourceCode
@code_instead if_else SourceCode SourceCode Any
@code_instead if_else SourceCode SourceCode SourceCode

# TODO: add more methods
@code_instead in SourceCode Any

@code_instead instr SourceCode Any
@code_instead instr Any SourceCode
@code_instead instr SourceCode SourceCode

@code_instead isequal SourceCode Any
@code_instead isequal Any SourceCode
@code_instead isequal SourceCode SourceCode

@code_instead isless SourceCode Any
@code_instead isless Any SourceCode
@code_instead isless SourceCode SourceCode

@code_instead ismissing SourceCode

@code_instead QueryOperators.join SourceCode SourceCode Any Expr Any Expr Any Expr

@code_instead max SourceCode Vararg{Any}

@code_instead mean SourceCode

@code_instead min SourceCode Vararg{Any}

@code_instead length SourceCode

@code_instead lowercase SourceCode

@code_instead QueryOperators.map SourceCode Any Expr

@code_instead occursin Regex SourceCode

@code_instead QueryOperators.orderby SourceCode Any Expr

@code_instead QueryOperators.orderby_descending SourceCode Any Expr

@code_instead rand BySQL Type{Int}

# TODO: add more methods
@code_instead replace SourceCode Pair

@code_instead repr SourceCode

@code_instead round SourceCode

@code_instead secondary SourceCode

@code_instead strip SourceCode
@code_instead strip SourceCode Char

@code_instead SubString SourceCode Number Number
@code_instead SubString SourceCode Number

@code_instead sum SourceCode

@code_instead QueryOperators.take SourceCode Any

@code_instead QueryOperators.thenby SourceCode Any Expr

@code_instead QueryOperators.thenby_descending SourceCode Any Expr

# TODO: support dateformat
@code_instead Time SourceCode

@code_instead type_of SourceCode

# TODO: add more methods
@code_instead QueryOperators.unique SourceCode Any Expr

@code_instead uppercase SourceCode

# TODO: add
# printf
# randomblob
# zeroblob
# group_concat
# total
# julianday
# strftime

# TODO: regex start and end
