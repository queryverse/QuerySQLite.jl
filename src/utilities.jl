# Recursion will be more performant than iteration for small tuples. My own recursive map makes sure that there is no iteration for performance
function map_unrolled(call, variables::Tuple{})
    ()
end
function map_unrolled(call, variables)
    (call(first(variables)), map_unrolled(call, tail(variables))...)
end

function map_unrolled(call, variables1::Tuple{}, variables2::Tuple{})
    ()
end
function map_unrolled(call, variables1, variables2)
    (
        call(first(variables1), first(variables2)),
        map_unrolled(call, tail(variables1), tail(variables2))...
    )
end

# In partial map, fixed is passed each time. This avoids captures, which have performace issues
function partial_map(call, fixed, variables::Tuple{})
    ()
end
function partial_map(call, fixed, variables)
    (
        call(fixed, first(variables)),
        partial_map(call, fixed, tail(variables))...
    )
end
function partial_map(call, fixed, variables1::Tuple{}, variables2::Tuple{})
    ()
end
function partial_map(call, fixed, variables1, variables2)
    (
        call(fixed, first(variables1), first(variables2)),
        partial_map(call, fixed, tail(variables1), tail(variables2))...
    )
end

function as_symbols(them)
    map_unrolled(Symbol, (them...,))
end

split_keyword(keyword::Expr) =
    if keyword.head === :kw
        Pair(keyword.args[1], keyword.args[2])
    else
        error("Cannot split keyword $keyword")
    end

# Split a function call into its pieces
# Normalize non-function-like patterns into function calls
function split_call(call_expression::Expr)
    if @capture call_expression call_(arguments__; keywords__)
        (call, arguments...), (; map(split_keyword, keywords)...)
    elseif @capture call_expression call_(arguments__)
        (call, arguments...), ()
    else
        error("$call_expression is not a function call")
    end
end

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
function if_else(switch, yes, no)
    ifelse(switch, yes, no)
end
export if_else

"""
    type_of(it)

`typeof` that you can add methods to.

```jldoctest
julia> using QuerySQLite

julia> type_of('a')
Char
```
"""
function type_of(it)
    typeof(it)
end
export type_of
