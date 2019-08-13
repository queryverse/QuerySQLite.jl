# All code is attached to its underlying database source
struct SourceCode{Source}
    source::Source
    code::Expr
end

# Every time `SourceCode` objects are combined, check to see whether they all come from the same source
function pop_sources!(sources, something)
    something
end
function pop_sources!(sources, source_code::SourceCode)
    push!(sources, source_code.source)
    source_code.code
end

function combine_sources(a_function, source_codes...)
    sources = Set(Any[])
    codes = partial_map(pop_sources!, sources, source_codes)
    if length(sources) != 1
        error("Expected exactly one source; got ($(sources...))")
    else
        SourceCode(first(sources), Expr(:call, a_function, codes...))
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
    Expr(:function,
        Expr(:call, a_function, map_unrolled(assert_type, arguments, types)...),
        Expr(:block, location, Expr(:call,
            combine_sources,
            a_function,
            map_unrolled(maybe_splat, arguments, types)...
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

@code_instead coalesce SourceCode Vararg{Any}

@code_instead QueryOperators.drop SourceCode Integer

@code_instead QueryOperators.filter SourceCode Any Expr

@code_instead QueryOperators.groupby SourceCode Any Expr Any Expr

@code_instead if_else SourceCode Any Any
@code_instead if_else Any SourceCode Any
@code_instead if_else Any Any SourceCode
@code_instead if_else Any SourceCode SourceCode
@code_instead if_else SourceCode Any SourceCode
@code_instead if_else SourceCode SourceCode Any
@code_instead if_else SourceCode SourceCode SourceCode

@code_instead in SourceCode Any
@code_instead in Any SourceCode
@code_instead in SourceCode SourceCode

@code_instead isequal SourceCode Any
@code_instead isequal Any SourceCode
@code_instead isequal SourceCode SourceCode

@code_instead isless SourceCode Any
@code_instead isless Any SourceCode
@code_instead isless SourceCode SourceCode

@code_instead ismissing SourceCode

@code_instead QueryOperators.join SourceCode SourceCode Any Expr Any Expr Any Expr

@code_instead length SourceCode

@code_instead QueryOperators.map SourceCode Any Expr

@code_instead occursin AbstractString SourceCode
@code_instead occursin Regex SourceCode

@code_instead QueryOperators.orderby SourceCode Any Expr

@code_instead QueryOperators.orderby_descending SourceCode Any Expr

@code_instead secondary SourceCode

@code_instead startswith SourceCode Any
@code_instead startswith Any SourceCode
@code_instead startswith SourceCode SourceCode

@code_instead QueryOperators.take SourceCode Any

@code_instead QueryOperators.thenby SourceCode Any Expr

@code_instead QueryOperators.thenby_descending SourceCode Any Expr

@code_instead QueryOperators.unique SourceCode Any Expr
