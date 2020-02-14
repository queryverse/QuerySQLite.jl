# The translation pass turns Julia expressions into SQL expressions
# Frustratingly, _primary tables are translated differently from secondary tables, so translate must propagate the `_primary` keyword
struct SQLExpression
    call::Symbol
    arguments::Vector{Any}
    SQLExpression(call, arguments...) = new(call, Any[arguments...])
end

function nest(sql_expression)
    SQLExpression(:AS, SQLExpression(:FROM, sql_expression), :__TABLE__)
end

function translate(something::Union{Char, AbstractString}; _primary = true)
    repr(something)
end

function translate(something; _primary = true)
    something
end
function translate(source_row::SourceRow; _primary = true)
    source_row.table_name
end
function translate(call::Expr; _primary = true)
    arguments, keywords = split_call(call)
    translate_call(arguments...; _primary = _primary, keywords...)
end

# A 1-1 mapping between Julia functions and SQL functions
function translate_default(location, function_type, SQL_call)
    result = :(
        function translate_call($function_type, arguments...; _primary = true)
            $SQLExpression($SQL_call, $map(
                argument -> $translate(argument; _primary = _primary),
                arguments
            )...)
        end
    )
    result.args[2].args[1] = location
    result
end

macro translate_default(a_function, SQL_call)
    translate_default(__source__, a_function, SQL_call) |> esc
end

@translate_default ::typeof(==) :(=)

@translate_default ::typeof(!=) Symbol("<>")

@translate_default ::typeof(!) :NOT

@translate_default ::typeof(&) :AND

@translate_default ::typeof(|) :OR

@translate_default ::typeof(*) :*

@translate_default ::typeof(/) :/

@translate_default ::typeof(+) :+

@translate_default ::typeof(-) :-

@translate_default ::typeof(%) :%

@translate_default ::typeof(abs) :ABS

function as(pair; _primary = true)
    SQLExpression(:AS,
        translate(pair.second.code; _primary = _primary),
        pair.first
    )
end

@translate_default ::typeof(coalesce) :COALESCE

@translate_default ::typeof(char) :CHAR

function translate_call(::typeof(convert), ::Type{Int}, it; _primary = true)
    SQLExpression(:UNICODE, translate(it))
end

@translate_default ::typeof(hex) :HEX

@translate_default ::typeof(QueryOperators.drop) :OFFSET

function translate_call(::typeof(QueryOperators.filter), iterator, call, call_expression; _primary = true)
    SQLExpression(:WHERE,
        translate(iterator; _primary = _primary),
        translate(call(model_row(iterator)).code; _primary = _primary)
    )
end

function translate_call(::typeof(format), time_type, format_string; _primary = true)
    SQLExpression(
        :STRFTIME,
        translate(format_string; _primary = _primary),
        translate(time_type; _primary = _primary)
    )
end

function translate_call(::typeof(getproperty), source_tables::Database, table_name; _primary = true)
    translated = translate(table_name; _primary = _primary)
    if _primary
        SQLExpression(:FROM, translated)
    else
        translated
    end
end
function translate_call(::typeof(getproperty), source_row::SourceRow, column_name; _primary = true)
    translated = translate(column_name; _primary = _primary)
    if _primary
        translated
    else
        SQLExpression(:., source_row.table_name, translated)
    end
end

function translate_call(::typeof(QueryOperators.groupby), ungrouped, group_function, group_function_expression, map_selector, map_function_expression; _primary = true)
    model = model_row(ungrouped)
    SQLExpression(Symbol("GROUP BY"),
        nest(translate_call(
            QueryOperators.map,
            ungrouped,
            map_selector, map_function_expression,
            _primary = _primary
        )),
        translate(group_function(model).code; _primary = _primary)
    )
end

@translate_default ::typeof(if_else) :CASE

@translate_default ::typeof(in) :IN

@translate_default ::typeof(instr) :INSTR

@translate_default ::typeof(isequal) Symbol("IS NOT DISTINCT FROM")

@translate_default ::typeof(isless) :<

@translate_default ::typeof(ismissing) Symbol("IS NULL")

@translate_default ::typeof(join) :GROUP_CONCAT

function translate_call(::typeof(QueryOperators.join), source1, source2, key1, key1_expression, key2, key2_expression, combine, combine_expression; _primary = true)
    model_row_1 = model_row(source1)
    model_row_2 = model_row(source2)
    SQLExpression(:SELECT,
        SQLExpression(:ON,
            SQLExpression(Symbol("INNER JOIN"),
                translate(source1),
                # mark as not _primary to suppress FROM
                translate(source2; _primary = false)
            ),
            # mark both as not _primary to always be explicit about table
            SQLExpression(:(=),
                translate(key1(model_row_1).code; _primary = false),
                translate(key2(model_row_2).code; _primary = false)
            )
        ),
        # mark both as not _primary to always be explicit about table
        Generator(
            pair -> as(pair; _primary = false),
            pairs(combine(model_row_1, model_row_2))
        )...
    )
end

@translate_default ::typeof(length) :COUNT

@translate_default ::typeof(lowercase) :LOWER

function translate_call(::typeof(QueryOperators.map), select_table, call, call_expression; _primary = true)
    inner = translate(select_table; _primary = _primary)
    if inner.call == :SELECT
        inner = nest(inner)
    end
    SQLExpression(
        :SELECT, inner,
        Generator(
            pair -> as(pair; _primary = _primary),
            pairs(call(model_row(select_table)))
        )...
    )
end

@translate_default ::typeof(max) :max

@translate_default ::typeof(mean) :AVG

@translate_default ::typeof(min) :min

translate_call(::typeof(occursin), needle, haystack; _primary = true) =
    SQLExpression(
        :LIKE,
        translate(haystack; _primary = _primary),
        translate(needle; _primary = _primary)
    )

function translate_call(::typeof(QueryOperators.orderby), unordered, key_function, key_function_expression; _primary = true)
    SQLExpression(Symbol("ORDER BY"),
        translate(unordered; _primary = _primary),
        translate(key_function(model_row(unordered)).code; _primary = _primary)
    )
end

function translate_call(::typeof(QueryOperators.orderby_descending), unordered, key_function, key_function_expression; _primary = true)
    SQLExpression(Symbol("ORDER BY"),
        translate(unordered; _primary = _primary),
        SQLExpression(:DESC,
            translate(key_function(model_row(unordered)).code; _primary = _primary)
        )
    )
end

@translate_default ::typeof(repr) :QUOTE

function translate_call(::typeof(rand), ::Type{Int}; _primary = true)
    SQLExpression(:RANDOM)
end

@translate_default ::typeof(randstring) :RANDOMBLOB

function translate_call(::typeof(replace), it, pair; _primary = true)
    SQLExpression(:REPLACE,
        translate(it; _primary = _primary),
        translate(pair.first; _primary = _primary),
        translate(pair.second; _primary = _primary)
    )
end

function translate_call(::typeof(round), it; _primary = true, digits = 0)
    SQLExpression(:ROUND,
        translate(it; _primary = _primary),
        translate(digits; _primary = _primary)
    )
end

@translate_default ::typeof(string) :||

@translate_default ::typeof(strip) :TRIM

@translate_default ::Type{SubString} :SUBSTR

@translate_default ::typeof(sum) :SUM

@translate_default ::typeof(QueryOperators.take) :LIMIT

function translate_call(::typeof(QueryOperators.thenby), unordered, key_function, key_function_expression; _primary = true)
    original = translate(unordered; _primary = _primary)
    SQLExpression(original.call, original.arguments...,
        translate(key_function(model_row(unordered)).code; _primary = _primary)
    )
end

function translate_call(::typeof(QueryOperators.thenby_descending), unordered, key_function, key_function_expression; _primary = true)
    original = translate(unordered; _primary = _primary)
    SQLExpression(original.call, original.arguments...,
        SQLExpression(:DESC,
            translate(key_function(model_row(unordered)).code; _primary = _primary)
        )
    )
end

@translate_default ::typeof(type_of) :TYPEOF

function translate_call(::typeof(QueryOperators.unique), repeated, key_function, key_function_expression; _primary = true)
    result = translate(repeated; _primary = _primary)
    SQLExpression(Symbol(string(result.call, " DISTINCT")), result.arguments...)
end

@translate_default ::typeof(uppercase) :UPPER
