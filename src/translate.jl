# The translation pass turns Julia expressions into SQL expressions
# Frustratingly, primary tables are translated differently from secondary tables, so translate must propagate the `primary` keyword
struct SQLExpression
    call::Symbol
    arguments::Tuple
    SQLExpression(call, arguments...) = new(call, arguments)
end

function translate(something; primary = true)
    something
end
function translate(source_row::SourceRow; primary = true)
    source_row.table_name
end
function translate(call::Expr; primary = true)
    translate_call(split_call(call)...; primary = primary)
end

# A 1-1 mapping between Julia functions and SQL functions
function translate_default(location, a_function, SQL_call)
    result = :(
        function translate_call(::typeof($a_function), arguments...; primary = true)
            $SQLExpression($SQL_call, $map_unrolled(
                argument -> $translate(argument; primary = primary),
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

@translate_default (==) :(=)

@translate_default (!=) Symbol("<>")

@translate_default (!) :NOT

@translate_default (&) :AND

@translate_default (|) :OR

function as(pair; primary = true)
    SQLExpression(:AS,
        translate(pair.second.code; primary = primary),
        pair.first
    )
end

@translate_default coalesce :COALESCE

@translate_default QueryOperators.drop :OFFSET

function translate_call(::typeof(QueryOperators.filter), iterator, call, call_expression; primary = true)
    SQLExpression(:WHERE,
        translate(iterator; primary = primary),
        translate(call(model_row(iterator)).code; primary = primary)
    )
end

function translate_call(::typeof(getproperty), source_tables::Database, table_name; primary = true)
    translated = translate(table_name; primary = primary)
    if primary
        SQLExpression(:FROM, translated)
    else
        translated
    end
end
function translate_call(::typeof(getproperty), source_row::SourceRow, column_name; primary = true)
    translated = translate(column_name; primary = primary)
    if primary
        translated
    else
        SQLExpression(:., source_row.table_name, translated)
    end
end

function translate_call(::typeof(QueryOperators.groupby), ungrouped, group_function, group_function_expression, map_selector, map_function_expression; primary = true)
    # TODO: map_selector
    model = model_row(ungrouped)
    SQLExpression(Symbol("GROUP BY"),
        translate(ungrouped; primary = primary),
        translate(group_function(model).code; primary = primary)
    )
end

@translate_default if_else :CASE

@translate_default in :IN

@translate_default isequal Symbol("IS NOT DISTINCT FROM")

@translate_default isless :<

@translate_default ismissing Symbol("IS NULL")

function translate_call(::typeof(QueryOperators.join), source1, source2, key1, key1_expression, key2, key2_expression, combine, combine_expression; primary = true)
    model_row_1 = model_row(source1)
    model_row_2 = model_row(source2)
    SQLExpression(:SELECT,
        SQLExpression(:ON,
            SQLExpression(Symbol("INNER JOIN"),
                translate(source1),
                # mark as not primary to suppress FROM
                translate(source2; primary = false)
            ),
            # mark both as not primary to always be explicit about table
            SQLExpression(:(=),
                translate(key1(model_row_1).code; primary = false),
                translate(key2(model_row_2).code; primary = false)
            )
        ),
        # mark both as not primary to always be explicit about table
        Generator(
            pair -> as(pair; primary = false),
            pairs(combine(model_row_1, model_row_2))
        )...
    )
end

@translate_default length :COUNT

function translate_call(::typeof(QueryOperators.map), select_table, call, call_expression; primary = true)
    SQLExpression(
        Symbol("SELECT"), translate(select_table; primary = primary),
        Generator(
            pair -> as(pair; primary = primary),
            pairs(call(model_row(select_table)))
        )...
    )
end

translate_call(::typeof(occursin), needle::AbstractString, haystack; primary = true) =
    SQLExpression(
        :LIKE,
        translate(haystack; primary = primary),
        string('%', needle, '%')
    )
translate_call(::typeof(occursin), needle::Regex, haystack; primary = true) =
    SQLExpression(
        :LIKE,
        translate(haystack; primary = primary),
        # * => %, . => _
        replace(replace(needle.pattern, r"(?<!\\)\.\*" => "%"), r"(?<!\\)\." => "_")
    )
@translate_default occursin :LIKE

function translate_call(::typeof(QueryOperators.orderby), unordered, key_function, key_function_expression; primary = true)
    SQLExpression(Symbol("ORDER BY"),
        translate(unordered; primary = primary),
        translate(key_function(model_row(unordered)).code; primary = primary)
    )
end

function translate_call(::typeof(QueryOperators.orderby_descending), unordered, key_function, key_function_expression; primary = true)
    SQLExpression(Symbol("ORDER BY"),
        translate(unordered; primary = primary),
        SQLExpression(:DESC,
            translate(key_function(model_row(unordered)).code; primary = primary)
        )
    )
end

translate_call(::typeof(startswith), full, prefix::AbstractString; primary = primary) =
    SQLExpression(
        :LIKE,
        translate(full),
        string(prefix, '%')
    )

@translate_default QueryOperators.take :LIMIT

function translate_call(::typeof(QueryOperators.thenby), unordered, key_function, key_function_expression; primary = true)
    original = translate(unordered; primary = primary)
    SQLExpression(original.call, original.arguments...,
        translate(key_function(model_row(unordered)).code; primary = primary)
    )
end

function translate_call(::typeof(QueryOperators.thenby_descending), unordered, key_function, key_function_expression; primary = true)
    original = translate(unordered; primary = primary)
    SQLExpression(original.call, original.arguments...,
        SQLExpression(:DESC,
            translate(key_function(model_row(unordered)).code; primary = primary)
        )
    )
end

function translate_call(::typeof(QueryOperators.unique), repeated, key_function, key_function_expression; primary = true)
    result = translate(repeated; primary = primary)
    SQLExpression(Symbol(string(result.call, " DISTINCT")), result.arguments...)
end
