# Dummy row
struct SourceRow{Source}
    source::Source
    table_name::Symbol
end

# The model row pass will build and modify a model of a row
function model_row(call)
    arguments, keywords = split_call(call)
    model_row_call(arguments...; keywords...)
end

# Very few functions modify the row model, so leave the row unchanged by default
function model_row_call(arbitrary_function, iterator, arguments...)
    model_row(iterator)
end

# Create a model row when getproperty is called on a Database
function get_column(source_row, column_name)
    SourceCode(source_row.source,
        Expr(:call, getproperty, source_row, column_name)
    )
end

function model_row_call(::typeof(getproperty), source_tables::Database, table_name)
    source = get_source(source_tables)
    column_names = get_column_names(source, table_name)
    NamedTuple{column_names}(partial_map(
        get_column,
        SourceRow(source, table_name),
        column_names
    ))
end

# Map is the only function which directly modifies the model row
function model_row_call(::typeof(QueryOperators.map), iterator, call, call_expression)
    call(model_row(iterator))
end

# Grouped rows have their own dedicated model type
struct GroupRow{Group, Row}
    group::Group
    row::Row
end

function QueryOperators.key(group_of_rows::GroupRow)
    getfield(group_of_rows, :group)
end

function getproperty(group_of_rows::GroupRow, column_name::Symbol)
    getproperty(getfield(group_of_rows, :row), column_name)
end

function length(group_of_rows::GroupRow)
    length(first(getfield(group_of_rows, :row)))
end

function model_row_call(::typeof(QueryOperators.groupby), ungrouped, group_function, group_function_expression, map_selector, map_function_expression)
    model = model_row(ungrouped)
    GroupRow(group_function(model), model)
end
