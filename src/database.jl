"""
    get_table_names(source)::Tuple{Symbol}

Get the names of the tables in `source`
"""
function get_table_names(source::DB)
    as_symbols(tables(source).name)
end
export get_table_names

"""
    get_column_names(source, table_name)::Tuple{Symbol}

Get the names of the columns in `table_name` in `source`
"""
function get_column_names(source::DB, table_name)
    as_symbols(columns(source, String(table_name)).name)
end
export get_column_names

"""
    struct Database{Source}

`source` need only support [`get_table_names`](@ref) and [`get_column_names`](@ref).
"""
struct Database{Source}
    source::Source
end

function Database(filename::AbstractString)
    if endswith(filename, ".sqlite")
        Database(SQLite.DB(filename))
    else
        throw(ArgumentError("Unsupported database type for $filename"))
    end
end

get_source(source_tables::Database) = getfield(source_tables, :source)

# getproperty overloading allows direct access to each table in the database
function getproperty(source_tables::Database, table_name::Symbol)
    SourceCode(get_source(source_tables),
        Expr(:call, getproperty, source_tables, table_name)
    )
end
