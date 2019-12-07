"""
    char(numbers...)

Convert a list of numbers to a string with the corresponding characters

```jldoctest
julia> using QuerySQLite

julia> char(65, 90)
"AZ"
```
"""
char(numbers...) = string(map(Char, numbers)...)
export char

"""
    if_else(switch, yes, no)

`ifelse` that you can add methods to.

```jldoctest
julia> using QuerySQLite

julia> if_else(true, 1, 0)
1

julia> if_else(false, 1, 0)
0
```
"""
function if_else(switch, yes, no)
    ifelse(switch, yes, no)
end
export if_else

"""
    instr(haystack, needle)

Find the first index of `needle` in `haystack`.

```jldoctest
julia> using QuerySQLite

julia> instr("QuerySQLite", "SQL")
6
```
"""
function instr(haystack, needle)
    first(findfirst(needle, haystack))
end
export instr

"""
    type_of(it)

`typeof` that you can add methods to.

```jldoctest
julia> using QuerySQLite

julia> type_of('a')
Char
```
"""
function type_of(it)
    typeof(it)
end
export type_of

"""
    hex(it)

Uppercase heximal representation

```jldoctest
julia> using QuerySQLite

julia> hex("hello")
"68656C6C6F"
```
"""
function hex(it::Number)
    uppercase(string(it, base = 16))
end
function hex(it::AbstractString)
    join(hex(byte) for byte in codeunits(it))
end
export hex
