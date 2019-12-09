"""
    get_table_names(source)::Tuple{Symbol}

Get the names of the tables in `source`.

```jldoctest
julia> using QuerySQLite

julia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, "test", "Chinook_Sqlite.sqlite"));

julia> get_table_names(getfield(database, :source))
(:Album, :Artist, :Customer, :Employee, :Genre, :Invoice, :InvoiceLine, :MediaType, :Playlist, :PlaylistTrack, :Track)
```
"""
function get_table_names(source::DB)
    as_symbols(tables(source).name)
end
export get_table_names

"""
    get_column_names(source, table_name)::Tuple{Symbol}

Get the names of the columns in `table_name` in `source`.

```jldoctest example
julia> using QuerySQLite

julia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, "test", "Chinook_Sqlite.sqlite"));

julia> get_column_names(getfield(database, :source), :Album)
(:AlbumId, :Title, :ArtistId)
```
"""
function get_column_names(source::DB, table_name)
    as_symbols(columns(source, String(table_name)).name)
end
export get_column_names

"""
    struct Database{Source}

A wrapper for an external database. `source` need only support
[`get_table_names`](@ref) and [`get_column_names`](@ref).

```jldoctest
julia> using QuerySQLite

julia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, "test", "Chinook_Sqlite.sqlite"));

julia> database.Track
?x9 SQLite query result
TrackId │ Name                                      │ AlbumId │ MediaTypeId
────────┼───────────────────────────────────────────┼─────────┼────────────
1       │ "For Those About To Rock (We Salute You)" │ 1       │ 1
2       │ "Balls to the Wall"                       │ 2       │ 2
3       │ "Fast As a Shark"                         │ 3       │ 2
4       │ "Restless and Wild"                       │ 3       │ 2
5       │ "Princess of the Dawn"                    │ 3       │ 2
6       │ "Put The Finger On You"                   │ 1       │ 1
7       │ "Let's Get It Up"                         │ 1       │ 1
8       │ "Inject The Venom"                        │ 1       │ 1
9       │ "Snowballed"                              │ 1       │ 1
10      │ "Evil Walks"                              │ 1       │ 1
... with more rows, and 5 more columns: GenreId, Composer, Milliseconds, Bytes, UnitPrice
```
"""
struct Database{Source}
    source::Source
end

"""
    Database(filename::AbstractString)

Guess the database software from the filename.
"""
function Database(filename::AbstractString)
    if endswith(filename, ".sqlite")
        Database(SQLite.DB(filename))
    else
        throw(ArgumentError("Unsupported database type for $filename"))
    end
end
export Database

get_source(source_tables::Database) = getfield(source_tables, :source)

# getproperty overloading allows direct access to each table in the database
function getproperty(source_tables::Database, table_name::Symbol)
    SourceCode(get_source(source_tables),
        Expr(:call, getproperty, source_tables, table_name)
    )
end
