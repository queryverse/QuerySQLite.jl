module QuerySQLite

import IteratorInterfaceExtensions, QueryOperators, QueryableBackend,
    TableTraits, SQLite

export SQLiteConnection

struct SQLiteConnection
    db::SQLite.DB
end

function SQLiteConnection(file::AbstractString)
    db = SQLite.DB(file)
    return SQLiteConnection(db)
end

struct SQLiteTable
    conn::SQLiteConnection
    table::String
end

IteratorInterfaceExtensions.isiterable(x::SQLiteTable) = true
TableTraits.isiterabletable(x::SQLiteTable) = true
IteratorInterfaceExtensions.getiterator(x::SQLiteTable) = SQLite.Query(getfield(x.conn, :db), "SELECT * FROM '$(x.table)';")

Base.getindex(conn::SQLiteConnection, name::AbstractString) = SQLiteTable(conn, name)
Base.getproperty(conn::SQLiteConnection, name::Symbol) = SQLiteTable(conn, string(name))

function QueryOperators.query(source::SQLiteTable)
    return QueryableBackend.QueryableSource() do querytree

        # TODO construct the SQL string here by analyzing querytree
        sql_cmd = "SELECT * FROM '$(source.table)';"

        return SQLite.Query(getfield(source.conn, :db), sql_cmd)
    end
end

end # module
