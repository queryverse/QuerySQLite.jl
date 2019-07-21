@code_instead QueryOperators.drop SourceCode Integer
@simple_translate ::typeof(QueryOperators.drop) :OFFSET

@code_instead QueryOperators.filter SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.filter), iterator, call, call_expression)
    SQLExpression(:WHERE,
        translate(iterator),
        translate(call(model_row(iterator)).code)
    )
end

@code_instead QueryOperators.join SourceCode SourceCode Any Expr Any Expr Any Expr
function translate_dispatch(::typeof(QueryOperators.join), source1, source2,
    key1, key1_expression,
    key2, key2_expression,
    combine, combine_expression
)
    SQLExpression(:on,
        SQLExpression(:INNER_JOIN, translate(source1), translate(source2)),
        SQLExpression(:(=), translate(key1), translate(key2))
    )
end

@code_instead QueryOperators.orderby SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.orderby), unordered, key_function, key_function_expression)
    SQLExpression(Symbol("ORDER BY"),
        translate(unordered),
        translate(key_function(model_row(unordered)).code)
    )
end
@code_instead QueryOperators.thenby SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.thenby), unordered, key_function, key_function_expression)
    original = translate(unordered)
    SQLExpression(original.call, original.arguments...,
        translate(key_function(model_row(unordered)).code)
    )
end

@code_instead QueryOperators.orderby_descending SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.orderby_descending), unordered, key_function, key_function_expression)
    SQLExpression(Symbol("ORDER BY"),
        translate(unordered),
        SQLExpression(:DESC,
            translate(key_function(model_row(unordered)).code)
        )
    )
end
@code_instead QueryOperators.thenby_descending SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.thenby_descending), unordered, key_function, key_function_expression)
    original = translate(unordered)
    SQLExpression(original.call, original.arguments...,
        SQLExpression(:DESC,
            translate(key_function(model_row(unordered)).code)
        )
    )
end

@code_instead QueryOperators.map SourceCode Any Expr
function model_row_dispatch(::typeof(QueryOperators.map), iterator, call, call_expression)
    call(model_row(iterator))
end
function select_as(new_name_model_row::Pair{Symbol, <: SourceCode})
    SQLExpression(:AS,
        new_name_model_row.first,
        translate(new_name_model_row.second.code),
    )
end
function translate_dispatch(::typeof(QueryOperators.map), select_table, call, call_expression)
    SQLExpression(
        Symbol("SELECT"), translate(select_table),
        Generator(select_as, pairs(call(model_row(select_table))))...
    )
end

@code_instead QueryOperators.take SourceCode Any
@simple_translate ::typeof(QueryOperators.take) :LIMIT

@code_instead QueryOperators.unique SourceCode Any Expr
function translate_dispatch(::typeof(QueryOperators.unique), repeated, key_function, key_function_expression)
    result = translate(repeated)
    SQLExpression(Symbol(string(result.call, " DISTINCT")), result.arguments...)
end
