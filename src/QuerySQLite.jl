module QuerySQLite

import Base: !, &, |, ==, !=, *, /, +, -, %, abs, Char, coalesce, collect, convert, eltype, getproperty, length,
lowercase, in, isdone, isequal, isless, ismissing, iterate, IteratorSize, join, max, min,
occursin, rand, replace, repr, round, show, showerror, startswith, string, strip, SubString, uppercase
using Base: Generator, NamedTuple, RefValue, SizeUnknown, tail
using Base.Meta: quot
import Base.Multimedia: showable
using DataValues: DataValue
import Dates: Date, DateTime, format, Time
import IteratorInterfaceExtensions: getiterator, isiterable
import MacroTools
using MacroTools: @capture
import QueryOperators
import Random: randstring
import SQLite
import SQLite: getvalue
using SQLite: columns, DB, execute!, generate_namedtuple, juliatype,
SQLITE_DONE, SQLITE_NULL, SQLITE_ROW, sqlite3_column_count, sqlite3_column_name,
sqlite3_column_type, sqlite3_step, sqlitevalue, Stmt, tables
import Statistics: mean, sum
using TableShowUtils: printdataresource, printHTMLtable, printtable
import TableTraits: isiterabletable

export Database

include("functions.jl")
include("utilities.jl")
include("database.jl")
include("code_instead.jl")
include("iterate.jl")
include("model_row.jl")
include("translate.jl")
include("show.jl")

end # module
