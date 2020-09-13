function as_symbols(them)
    map(Symbol, (them...,))
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
