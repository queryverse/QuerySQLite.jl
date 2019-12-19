var documenterSearchIndex = {"docs":
[{"location":"#QuerySQLite-1","page":"QuerySQLite","title":"QuerySQLite","text":"","category":"section"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"Modules = [QuerySQLite]","category":"page"},{"location":"#User-documentation-1","page":"QuerySQLite","title":"User documentation","text":"","category":"section"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"QuerySQLite is an experimental package sponsored by Google Summer of Code. It's finally ready for public use. Although QuerySQLite is only tested using SQLite, it's been purposefully designed to easily incorporate other database software.","category":"page"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"Use Database to wrap an external database. Then, you can access its tables using ., and conduct most Query operations on them. In theory, most operations should \"just work\". There are a couple of exceptions.","category":"page"},{"location":"#Non-overloadable-syntax-and-functions-1","page":"QuerySQLite","title":"Non-overloadable syntax and functions","text":"","category":"section"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"Patterns like if and functions like ifelse and typeof can't be overloaded. Instead, QuerySQLite exports the if_else and type_of functions and overloads them instead.","category":"page"},{"location":"#No-SQL-arguments-1","page":"QuerySQLite","title":"No SQL arguments","text":"","category":"section"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"If you would like to translate code to SQL, but you do not pass any SQL arguments, you will need to use BySQL to pass a dummy SQL object instead. See the BySQL docstring for more information.","category":"page"},{"location":"#Pattern-matching-1","page":"QuerySQLite","title":"Pattern matching","text":"","category":"section"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"Use SQLite syntax, not Julia syntax, for pattern matching for regular expressions and date formats.","category":"page"},{"location":"#Developer-documentation-1","page":"QuerySQLite","title":"Developer documentation","text":"","category":"section"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"QuerySQLite hijacks Julia's multiple dispatch to translate external database commands to SQL instead of evaluating them. To do this, it constructs a \"model_row\" that represents the structure of a row of data. If you would like to add support for a new function, there are only a few steps:","category":"page"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"Use the @code_instead macro to specify the argument types for diversion into SQL translation.\nIf your function will modify the row structure of the table, define a model_row_call method.\nUse the @translate_default macro to name the matching SQL function. If more involved processing is required, define a translate_call method instead.\nIf you would like to show your SQL expression in a non-standard way, edit the show method for SQLExpressions.","category":"page"},{"location":"#","page":"QuerySQLite","title":"QuerySQLite","text":"Modules = [QuerySQLite]","category":"page"},{"location":"#QuerySQLite.BySQL","page":"QuerySQLite","title":"QuerySQLite.BySQL","text":"struct BySQL{Source}\n\nIf you would like a statement to be evaluated by SQL, not Julia, and none of the arguments are SQL code, you can use BySQL to hack dispatch.\n\njulia> using QuerySQLite\n\njulia> using Query: @map\n\njulia> using DataValues: DataValue\n\njulia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, \"test\", \"Chinook_Sqlite.sqlite\"));\n\njulia> result = database.Track |> @map({a = rand(BySQL(_), Int)});\n\njulia> collect(result)[1].a isa DataValue{Int}\ntrue\n\n\n\n\n\n","category":"type"},{"location":"#QuerySQLite.Database","page":"QuerySQLite","title":"QuerySQLite.Database","text":"struct Database{Source}\n\nA wrapper for an external database. source need only support get_table_names and get_column_names.\n\n\n\n\n\n","category":"type"},{"location":"#QuerySQLite.Database-Tuple{AbstractString}","page":"QuerySQLite","title":"QuerySQLite.Database","text":"Database(filename::AbstractString)\n\nGuess the database software from the filename.\n\njulia> using QuerySQLite\n\njulia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, \"test\", \"Chinook_Sqlite.sqlite\"));\n\njulia> database.Track\n?x9 SQLite query result\nTrackId │ Name                                      │ AlbumId │ MediaTypeId\n────────┼───────────────────────────────────────────┼─────────┼────────────\n1       │ \"For Those About To Rock (We Salute You)\" │ 1       │ 1\n2       │ \"Balls to the Wall\"                       │ 2       │ 2\n3       │ \"Fast As a Shark\"                         │ 3       │ 2\n4       │ \"Restless and Wild\"                       │ 3       │ 2\n5       │ \"Princess of the Dawn\"                    │ 3       │ 2\n6       │ \"Put The Finger On You\"                   │ 1       │ 1\n7       │ \"Let's Get It Up\"                         │ 1       │ 1\n8       │ \"Inject The Venom\"                        │ 1       │ 1\n9       │ \"Snowballed\"                              │ 1       │ 1\n10      │ \"Evil Walks\"                              │ 1       │ 1\n... with more rows, and 5 more columns: GenreId, Composer, Milliseconds, Bytes, UnitPrice\n\n\n\n\n\n","category":"method"},{"location":"#QuerySQLite.char-Tuple","page":"QuerySQLite","title":"QuerySQLite.char","text":"char(numbers...)\n\nConvert a list of numbers to a string with the corresponding characters\n\njulia> using QuerySQLite\n\njulia> char(65, 90)\n\"AZ\"\n\n\n\n\n\n","category":"method"},{"location":"#QuerySQLite.get_column_names-Tuple{SQLite.DB,Any}","page":"QuerySQLite","title":"QuerySQLite.get_column_names","text":"get_column_names(source, table_name)::Tuple{Symbol}\n\nGet the names of the columns in table_name in source.\n\njulia> using QuerySQLite\n\njulia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, \"test\", \"Chinook_Sqlite.sqlite\"));\n\njulia> get_column_names(getfield(database, :source), :Album)\n(:AlbumId, :Title, :ArtistId)\n\n\n\n\n\n","category":"method"},{"location":"#QuerySQLite.get_sql-Tuple{Any}","page":"QuerySQLite","title":"QuerySQLite.get_sql","text":"get_sql(it)\n\nUse get_sql if you would like to see the SQL code generated by an SQLite query.\n\njulia> using QuerySQLite\n\njulia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, \"test\", \"Chinook_Sqlite.sqlite\"));\n\njulia> get_sql(database.Track)\nFROM (Track)\n\n\n\n\n\n","category":"method"},{"location":"#QuerySQLite.get_table_names-Tuple{SQLite.DB}","page":"QuerySQLite","title":"QuerySQLite.get_table_names","text":"get_table_names(source)::Tuple{Symbol}\n\nGet the names of the tables in source.\n\njulia> using QuerySQLite\n\njulia> database = Database(joinpath(pathof(QuerySQLite) |> dirname |> dirname, \"test\", \"Chinook_Sqlite.sqlite\"));\n\njulia> get_table_names(getfield(database, :source))\n(:Album, :Artist, :Customer, :Employee, :Genre, :Invoice, :InvoiceLine, :MediaType, :Playlist, :PlaylistTrack, :Track)\n\n\n\n\n\n","category":"method"},{"location":"#QuerySQLite.hex-Tuple{Number}","page":"QuerySQLite","title":"QuerySQLite.hex","text":"hex(it)\n\nUppercase hexadecimal representation\n\njulia> using QuerySQLite\n\njulia> hex(\"hello\")\n\"68656C6C6F\"\n\n\n\n\n\n","category":"method"},{"location":"#QuerySQLite.if_else-Tuple{Any,Any,Any}","page":"QuerySQLite","title":"QuerySQLite.if_else","text":"if_else(switch, yes, no)\n\nifelse that you can add methods to.\n\njulia> using QuerySQLite\n\njulia> if_else(true, 1, 0)\n1\n\njulia> if_else(false, 1, 0)\n0\n\n\n\n\n\n","category":"method"},{"location":"#QuerySQLite.instr-Tuple{Any,Any}","page":"QuerySQLite","title":"QuerySQLite.instr","text":"instr(haystack, needle)\n\nFind the first index of needle in haystack.\n\njulia> using QuerySQLite\n\njulia> instr(\"QuerySQLite\", \"SQL\")\n6\n\n\n\n\n\n","category":"method"},{"location":"#QuerySQLite.type_of-Tuple{Any}","page":"QuerySQLite","title":"QuerySQLite.type_of","text":"type_of(it)\n\ntypeof that you can add methods to.\n\njulia> using QuerySQLite\n\njulia> type_of('a')\nChar\n\n\n\n\n\n","category":"method"}]
}