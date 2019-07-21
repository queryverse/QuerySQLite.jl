function QueryOperators.query(source_code::SourceCode)
    source_code
end

function numbered_argument(number)
    Symbol(string("argument", number))
end
function assert_type(argument, type)
    Expr(:(::), argument, type)
end
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

struct SQLExpression
    call::Symbol
    arguments::Tuple
    SQLExpression(call, arguments...) = new(call, arguments)
end

function split_node(node::Expr)
    if @capture node call_(arguments__)
        if call == ifelse
            if_else
        else
            call
        end, arguments...
    elseif @capture node left_ && right_
        &, left, right
    elseif @capture node left_ || right_
        |, left, right
    elseif @capture node if condition_ yes_ else no_ end
        if_else, condition, yes, no
    else
        error("Cannot split node $node")
    end
end

function model_row_dispatch(arbitrary_function, iterator, arguments...)
    model_row(iterator)
end
function model_row(node::Expr)
    model_row_dispatch(split_node(node)...)
end

function translate(something)
    something
end
function translate(source_row::SourceRow)
    source_row.table_name
end
function translate(node::Expr)
    translate_dispatch(split_node(node)...)
end

function simple_translate(location, function_type, SQL_call)
    arguments = gensym()
    Expr(:function,
        Expr(:call, :translate_dispatch, function_type, Expr(:..., arguments)),
        Expr(:block, location, Expr(:call,
            SQLExpression,
            SQL_call,
            Expr(:..., Expr(:call, map_unrolled, translate, arguments))
        ))
    )
end

macro simple_translate(a_function, SQL_call)
    simple_translate(__source__, a_function, SQL_call) |> esc
end
