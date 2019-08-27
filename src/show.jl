# Syntax patterns
function prefix(io, call, argument1)
    print(io, call)
    print(io, ' ')
    print(io, argument1)
end

function postfix(io, call, argument1)
    print(io, argument1)
    print(io, ' ')
    print(io, call)
end

function tight_infix(io, call, argument1, argument2)
    print(io, argument1)
    print(io, call)
    print(io, argument2)
end

function infix(io, call, argument1, argument2, arguments...)
    print(io, argument1)
    print(io, ' ')
    print(io, call)
    print(io, ' ')
    infix(io, call, argument2, arguments...)
end

function infix(io, call, argument1)
    print(io, argument1)
end

function head_call_tail(io, call, argument1, arguments...)
    print(io, argument1)
    print(io, ' ')
    print(io, call)
    print(io, ' ')
    join(io, arguments, ", ")
end

function call_tail_head(io, call, argument1, arguments...)
    print(io, call)
    print(io, ' ')
    join(io, arguments, ", ")
    print(io, ' ')
    print(io, argument1)
end

function when_then_else(io, condition, action, arguments...)
    print(io, "WHEN ")
    print(io, condition)
    print(io, " THEN ")
    print(io, action)
    print(io, ' ')
    when_then_else(io, arguments...)
end

function when_then_else(io, action)
    print(io, "ELSE ")
    print(io, action)
end

function case(io, call, arguments...)
    print(io, call)
    print(io, ' ')
    when_then_else(io, arguments...)
end

# Use the call to determine the syntax pattern
function show(io::IO, sql_expression::SQLExpression)
    call = sql_expression.call
    arguments = sql_expression.arguments

    if call === :.
        tight_infix(io, call, arguments...)
    elseif call === :(=)
        infix(io, call, arguments...)
    elseif call === :<
        infix(io, call, arguments...)
    elseif call === Symbol("<>")
        infix(io, call, arguments...)
    elseif call === Symbol("||")
        infix(io, call, arguments...)
    elseif call === :*
        infix(io, call, arguments...)
    elseif call === :+
        infix(io, call, arguments...)
    elseif call === :%
        infix(io, call, arguments...)
    elseif call === :AND
        infix(io, call, arguments...)
    elseif call === :AS
        infix(io, call, arguments...)
    elseif call === :CASE
        case(io, call, arguments...)
    elseif call === :DESC
        postfix(io, call, arguments...)
    elseif call === :FROM
        prefix(io, call, arguments...)
    elseif call === Symbol("GROUP BY")
        head_call_tail(io, call, arguments...)
    elseif call === :IN
        infix(io, call, arguments...)
    elseif call === Symbol("INNER JOIN")
        infix(io, call, arguments...)
    elseif call === Symbol("IS NOT DISTINCT FROM")
        infix(io, call, arguments...)
    elseif call === Symbol("IS NULL")
        postfix(io, call, arguments...)
    elseif call === :LIKE
        infix(io, call, arguments...)
    elseif call === :LIMIT
        infix(io, call, arguments...)
    elseif call === :OFFSET
        infix(io, call, arguments...)
    elseif call === :ON
        infix(io, call, arguments...)
    elseif call === :OR
        infix(io, call, arguments...)
    elseif call === Symbol("ORDER BY")
        head_call_tail(io, call, arguments...)
    elseif call === :NOT
        prefix(io, call, arguments...)
    elseif call === :SELECT
        call_tail_head(io, call, arguments...)
    elseif call === Symbol("SELECT DISTINCT")
        call_tail_head(io, call, arguments...)
    elseif call === :WHERE
        infix(io, call, arguments...)
    else
        print(io, call)
        print(io, '(')
        join(io, arguments, ", ")
        print(io, ')')
    end
end

# Default to * if no columns are specifcied
function finalize(sql_expression::SQLExpression)
    if sql_expression.call in (:FROM, Symbol("GROUP BY"), Symbol("INNER JOIN"))
        SQLExpression(:SELECT, sql_expression, :*)
    else
        sql_expression
    end
end

function finalize(something)
    something
end
