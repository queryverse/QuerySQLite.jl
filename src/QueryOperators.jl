function as(new_name_model_row::Pair{Symbol, <: SourceCode}; options...)
    SQLExpression(:AS,
        translate(new_name_model_row.second.code; options...),
        new_name_model_row.first
    )
end

@code_instead QueryOperators.drop SourceCode Integer
@translate_default ::typeof(QueryOperators.drop) :OFFSET

@code_instead QueryOperators.filter SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.filter), iterator, call, call_expression; options...)
    SQLExpression(:WHERE,
        translate(iterator; options...),
        translate(call(model_row(iterator)).code; options...)
    )
end

@code_instead QueryOperators.groupby SourceCode Any Expr Any Expr

struct GroupOfRows{Group, Row}
    group::Group
    row::Row
end

function key(group_of_rows::GroupOfRows)
    translate(getfield(group_of_rows, :group))
end

function getproperty(group_of_rows::GroupOfRows, column_name::Symbol)
    getproperty(getfield(group_of_rows, :row), column_name)
end

function length(group_of_rows::GroupOfRows)
    length(first(getfield(group_of_rows, :row)))
end

function model_row_dispatch(::typeof(QueryOperators.groupby), ungrouped, group_function, group_function_expression, map_selector, map_function_expression; options...)
    model = model_row(ungrouped; options...)
    GroupOfRows(group_function(model), model)
end

function translate_dispatch(::typeof(QueryOperators.groupby), ungrouped, group_function, group_function_expression, map_selector, map_function_expression; options...)
    # TODO: map_selector
    model = model_row(ungrouped; options...)
    SQLExpression(Symbol("GROUP BY"),
        translate(ungrouped; options...),
        translate(group_function(model).code; options...)
    )
end

@code_instead QueryOperators.join SourceCode SourceCode Any Expr Any Expr Any Expr
function translate_dispatch(::typeof(QueryOperators.join), source1, source2, key1, key1_expression, key2, key2_expression, combine, combine_expression; options...)
    model_row_1 = model_row(source1; other = true, options...)
    model_row_2 = model_row(source2; other = true, options...)
    SQLExpression(:SELECT,
        SQLExpression(:ON,
            SQLExpression(Symbol("INNER JOIN"),
                translate(source1; options...),
                translate(source2; other = true, options...)
            ),
            SQLExpression(:(=),
                translate(key1(model_row_1).code; options...),
                translate(key2(model_row_2).code; other = true, options...)
            )
        ),
        Generator(
            pair -> as(pair; options...),
            pairs(combine(model_row_1, model_row_2))
        )...
    )
end

@code_instead QueryOperators.map SourceCode Any Expr
function model_row_dispatch(::typeof(QueryOperators.map), iterator, call, call_expression; options...)
    call(model_row(iterator; options...))
end

function translate_dispatch(::typeof(QueryOperators.map), select_table, call, call_expression; options...)
    SQLExpression(
        Symbol("SELECT"), translate(select_table; options...),
        Generator(
            pair -> as(pair; options...),
            pairs(call(model_row(select_table; options...)))
        )...
    )
end

@code_instead QueryOperators.orderby SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.orderby), unordered, key_function, key_function_expression; options...)
    SQLExpression(Symbol("ORDER BY"),
        translate(unordered; options...),
        translate(key_function(model_row(unordered)).code; options...)
    )
end
@code_instead QueryOperators.thenby SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.thenby), unordered, key_function, key_function_expression; options...)
    original = translate(unordered; options...)
    SQLExpression(original.call, original.arguments...,
        translate(key_function(model_row(unordered)).code; options...)
    )
end

@code_instead QueryOperators.orderby_descending SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.orderby_descending), unordered, key_function, key_function_expression; options...)
    SQLExpression(Symbol("ORDER BY"),
        translate(unordered; options...),
        SQLExpression(:DESC,
            translate(key_function(model_row(unordered)).code; options...)
        )
    )
end
@code_instead QueryOperators.thenby_descending SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.thenby_descending), unordered, key_function, key_function_expression; options...)
    original = translate(unordered; options...)
    SQLExpression(original.call, original.arguments...,
        SQLExpression(:DESC,
            translate(key_function(model_row(unordered)).code; options...)
        )
    )
end

@code_instead QueryOperators.take SourceCode Any
@translate_default ::typeof(QueryOperators.take) :LIMIT

@code_instead QueryOperators.unique SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.unique), repeated, key_function, key_function_expression; options...)
    result = translate(repeated; options...)
    SQLExpression(Symbol(string(result.call, " DISTINCT")), result.arguments...)
end
