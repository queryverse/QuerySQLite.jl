```@index
Modules = [QuerySQLite]
```

QuerySQLite is an experimental package sponsored by Google Summer of Code. It's
finally ready for public use. Although QuerySQLite is only tested on SQLite,
it's been purposefully designed to easily incorporate other database software.

Use [`Database`](@ref) to wrap an external database. Then, you can access its
tables using `.`, and conduct most `Query` operations on them. In theory, most
operations should "just work". There are a couple of exceptions.

### Non-overloadable methods

Functions like `ifelse` and `typeof` can't be overloaded. Instead, QuerySQLite
exports the [`if_else`](@ref) and [`type_of`](@ref) functions and overloads them
instead.

### No SQL arguments

If you would like to translate code to SQL, but you do not pass any SQL
arguments, you will need use [`BySQL`](@ref) to pass a dummy SQL object instead.
See the `BySQL` docstring for more information.

## Developer notes

QuerySQLite hijacks Julia's multiple dispatch to translate external database
commands to SQL instead of evaluating them. To do this, it construct a
"model_row" that represents the structure of a row of data. If you would like to
support for a new function, there are only a few steps:

- Use the `@code_instead` macro to specify the argument types for diversion
into SQL translation.
- If your function will modify the row structure of the
table, define a `model_row_call` method.
- Use the `@translate_default` macro to name the matching SQL function. If more
involved processing is required, define a `translate_call` method instead.
- If you would like to show your SQL expression in a non-standard way, edit the
`show` method for `SQLExpression`s.

```@autodocs
Modules = [QuerySQLite]
```
