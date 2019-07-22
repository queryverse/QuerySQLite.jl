@code_instead (==) SourceCode Any
@code_instead (==) Any SourceCode
@code_instead (==) SourceCode SourceCode
@simple_translate ::typeof(==) :(=)

@code_instead (!=) SourceCode Any
@code_instead (!=) Any SourceCode
@code_instead (!=) SourceCode SourceCode
@simple_translate ::typeof(!=) Symbol("<>")

@code_instead (!) SourceCode
@simple_translate ::typeof(!) :NOT

@code_instead (&) SourceCode Any
@code_instead (&) Any SourceCode
@code_instead (&) SourceCode SourceCode
@simple_translate ::typeof(&) :AND

@code_instead (|) SourceCode Any
@code_instead (|) Any SourceCode
@code_instead (|) SourceCode SourceCode
@simple_translate ::typeof(|) :OR

@code_instead coalesce SourceCode Vararg{Any}
@simple_translate ::typeof(coalesce) :COALESCE

function get_column(source_row, column_name)
    SourceCode(source_row.source, Expr(:call, getproperty, source_row, column_name))
end
function model_row_dispatch(::typeof(getproperty), source_tables::SourceTables, table_name)
    source = get_source(source_tables)
    column_names = get_column_names(source, table_name)
    NamedTuple{column_names}(partial_map(
        get_column,
        SourceRow(source, table_name),
        column_names
    ))
end
function translate_dispatch(::typeof(getproperty), source_tables::SourceTables, table_name)
    SQLExpression(:FROM, translate(table_name))
end
function translate_dispatch(::typeof(getproperty), source_row::SourceRow, column_name)
    SQLExpression(:., source_row.table_name, translate(column_name))
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

@code_instead if_else SourceCode Any Any
@code_instead if_else Any SourceCode Any
@code_instead if_else Any Any SourceCode
@code_instead if_else Any SourceCode SourceCode
@code_instead if_else SourceCode Any SourceCode
@code_instead if_else SourceCode SourceCode Any
@code_instead if_else SourceCode SourceCode SourceCode
@simple_translate ::typeof(if_else) :IF

@code_instead in SourceCode Any
@code_instead in Any SourceCode
@code_instead in SourceCode SourceCode
@simple_translate ::typeof(in) :IN

@code_instead isequal SourceCode Any
@code_instead isequal Any SourceCode
@code_instead isequal SourceCode SourceCode
@simple_translate ::typeof(isequal) Symbol("IS NOT DISTINCT FROM")

@code_instead isless SourceCode Any
@code_instead isless Any SourceCode
@code_instead isless SourceCode SourceCode
@simple_translate ::typeof(isless) :<

@code_instead ismissing SourceCode
@simple_translate ::typeof(ismissing) Symbol("IS NULL")

@code_instead occursin AbstractString SourceCode
@code_instead occursin Regex SourceCode
translate_dispatch(::typeof(occursin), needle::AbstractString, haystack) =
    SQLExpression(
        :LIKE,
        translate(haystack),
        string('%', needle, '%')
    )
translate_dispatch(::typeof(occursin), needle::Regex, haystack) =
    SQLExpression(
        :LIKE,
        translate(haystack),
        replace(replace(needle.pattern, r"(?<!\\)\.\*" => "%"), r"(?<!\\)\." => "_")
    )
@simple_translate ::typeof(occursin) :LIKE

@code_instead startswith SourceCode Any
@code_instead startswith Any SourceCode
@code_instead startswith SourceCode SourceCode

translate_dispatch(::typeof(startswith), full, prefix::AbstractString) =
    SQLExpression(
        :LIKE,
        translate(full),
        string(prefix, '%')
    )
