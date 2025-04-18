# This file is a part of Julia. License is MIT: https://julialang.org/license

### truncation
Base.trunc(dt::Date, p::Type{Year}) = Date(UTD(totaldays(year(dt), 1, 1)))
Base.trunc(dt::Date, p::Type{Quarter}) = firstdayofquarter(dt)
Base.trunc(dt::Date, p::Type{Month}) = firstdayofmonth(dt)
Base.trunc(dt::Date, p::Type{Day}) = dt

Base.trunc(dt::DateTime, p::Type{Year}) = DateTime(trunc(Date(dt), Year))
Base.trunc(dt::DateTime, p::Type{Quarter}) = DateTime(trunc(Date(dt), Quarter))
Base.trunc(dt::DateTime, p::Type{Month}) = DateTime(trunc(Date(dt), Month))
Base.trunc(dt::DateTime, p::Type{Day}) = DateTime(Date(dt))
Base.trunc(dt::DateTime, p::Type{Hour}) = dt - Minute(dt) - Second(dt) - Millisecond(dt)
Base.trunc(dt::DateTime, p::Type{Minute}) = dt - Second(dt) - Millisecond(dt)
Base.trunc(dt::DateTime, p::Type{Second}) = dt - Millisecond(dt)
Base.trunc(dt::DateTime, p::Type{Millisecond}) = dt

Base.trunc(t::Time, p::Type{Hour}) = Time(Hour(t))
Base.trunc(t::Time, p::Type{Minute}) = Time(Hour(t), Minute(t))
Base.trunc(t::Time, p::Type{Second}) = Time(Hour(t), Minute(t), Second(t))
Base.trunc(t::Time, p::Type{Millisecond}) = t - Microsecond(t) - Nanosecond(t)
Base.trunc(t::Time, p::Type{Microsecond}) = t - Nanosecond(t)
Base.trunc(t::Time, p::Type{Nanosecond})  = t

"""
    trunc(dt::TimeType, ::Type{Period})::TimeType

Truncates the value of `dt` according to the provided `Period` type.

# Examples
```jldoctest
julia> trunc(DateTime("1996-01-01T12:30:00"), Day)
1996-01-01T00:00:00
```
"""
Dates.trunc(::Dates.TimeType, ::Type{Dates.Period})

# Adjusters
"""
    firstdayofweek(dt::TimeType)::TimeType

Adjusts `dt` to the Monday of its week.

# Examples
```jldoctest
julia> firstdayofweek(DateTime("1996-01-05T12:30:00"))
1996-01-01T00:00:00
```
"""
function firstdayofweek end

firstdayofweek(dt::Date) = Date(UTD(value(dt) - dayofweek(dt) + 1))
firstdayofweek(dt::DateTime) = DateTime(firstdayofweek(Date(dt)))

"""
    lastdayofweek(dt::TimeType)::TimeType

Adjusts `dt` to the Sunday of its week.

# Examples
```jldoctest
julia> lastdayofweek(DateTime("1996-01-05T12:30:00"))
1996-01-07T00:00:00
```
"""
function lastdayofweek end

lastdayofweek(dt::Date) = Date(UTD(value(dt) + (7 - dayofweek(dt))))
lastdayofweek(dt::DateTime) = DateTime(lastdayofweek(Date(dt)))

"""
    firstdayofmonth(dt::TimeType)::TimeType

Adjusts `dt` to the first day of its month.

# Examples
```jldoctest
julia> firstdayofmonth(DateTime("1996-05-20"))
1996-05-01T00:00:00
```
"""
function firstdayofmonth end

firstdayofmonth(dt::Date) = Date(UTD(value(dt) - day(dt) + 1))
firstdayofmonth(dt::DateTime) = DateTime(firstdayofmonth(Date(dt)))

"""
    lastdayofmonth(dt::TimeType)::TimeType

Adjusts `dt` to the last day of its month.

# Examples
```jldoctest
julia> lastdayofmonth(DateTime("1996-05-20"))
1996-05-31T00:00:00
```
"""
function lastdayofmonth end

function lastdayofmonth(dt::Date)
    y, m, d = yearmonthday(dt)
    return Date(UTD(value(dt) + daysinmonth(y, m) - d))
end
lastdayofmonth(dt::DateTime) = DateTime(lastdayofmonth(Date(dt)))

"""
    firstdayofyear(dt::TimeType)::TimeType

Adjusts `dt` to the first day of its year.

# Examples
```jldoctest
julia> firstdayofyear(DateTime("1996-05-20"))
1996-01-01T00:00:00
```
"""
function firstdayofyear end

firstdayofyear(dt::Date) = Date(UTD(value(dt) - dayofyear(dt) + 1))
firstdayofyear(dt::DateTime) = DateTime(firstdayofyear(Date(dt)))

"""
    lastdayofyear(dt::TimeType)::TimeType

Adjusts `dt` to the last day of its year.

# Examples
```jldoctest
julia> lastdayofyear(DateTime("1996-05-20"))
1996-12-31T00:00:00
```
"""
function lastdayofyear end

function lastdayofyear(dt::Date)
    y, m, d = yearmonthday(dt)
    return Date(UTD(value(dt) + daysinyear(y) - dayofyear(y, m, d)))
end
lastdayofyear(dt::DateTime) = DateTime(lastdayofyear(Date(dt)))

"""
    firstdayofquarter(dt::TimeType)::TimeType

Adjusts `dt` to the first day of its quarter.

# Examples
```jldoctest
julia> firstdayofquarter(DateTime("1996-05-20"))
1996-04-01T00:00:00

julia> firstdayofquarter(DateTime("1996-08-20"))
1996-07-01T00:00:00
```
"""
function firstdayofquarter end

function firstdayofquarter(dt::Date)
    y,m = yearmonth(dt)
    mm = m < 4 ? 1 : m < 7 ? 4 : m < 10 ? 7 : 10
    return Date(y, mm, 1)
end
firstdayofquarter(dt::DateTime) = DateTime(firstdayofquarter(Date(dt)))

"""
    lastdayofquarter(dt::TimeType)::TimeType

Adjusts `dt` to the last day of its quarter.

# Examples
```jldoctest
julia> lastdayofquarter(DateTime("1996-05-20"))
1996-06-30T00:00:00

julia> lastdayofquarter(DateTime("1996-08-20"))
1996-09-30T00:00:00
```
"""
function lastdayofquarter end

function lastdayofquarter(dt::Date)
    y,m = yearmonth(dt)
    mm, d = m < 4 ? (3, 31) : m < 7 ? (6, 30) : m < 10 ? (9, 30) : (12, 31)
    return Date(y, mm, d)
end
lastdayofquarter(dt::DateTime) = DateTime(lastdayofquarter(Date(dt)))

# Temporal Adjusters
struct DateFunction
    f::Function
    # validate boolean, single-arg inner constructor
    function DateFunction(@nospecialize(f), dt::TimeType)
        isa(f(dt), Bool) || throw(ArgumentError("Provided function must take a single TimeType argument and return true or false"))
        return new(f)
    end
end
Base.show(io::IO, df::DateFunction) = println(io, df.f)

# Core adjuster
function adjust(df::DateFunction, start, step, limit)
    for i = 1:limit
        df.f(start) && return start
        start += step
    end
    throw(ArgumentError("Adjustment limit reached: $limit iterations"))
end

"""
    adjust(df, start[, step, limit])::TimeType
    adjust(df, start)::TimeType

Adjusts the date in `start` until the `f::Function` passed using `df` returns `true`.
The optional `step` parameter dictates the change in `start` on every iteration.
If `limit` iterations occur, then an [`ArgumentError`](@ref) is thrown.

The default values for parameters `start` and `limit` are 1 Day and 10,000 respectively.

# Examples
```jldoctest
julia> Dates.adjust(date -> month(date) == 10, Date(2022, 1, 1), step=Month(3), limit=10)
2022-10-01

julia> Dates.adjust(date -> year(date) == 2025, Date(2022, 1, 1), step=Year(1), limit=4)
2025-01-01

julia> Dates.adjust(date -> day(date) == 15, Date(2022, 1, 1), step=Year(1), limit=3)
ERROR: ArgumentError: Adjustment limit reached: 3 iterations
Stacktrace:
[...]

julia> Dates.adjust(date -> month(date) == 10, Date(2022, 1, 1))
2022-10-01

julia> Dates.adjust(date -> year(date) == 2025, Date(2022, 1, 1))
2025-01-01

julia> Dates.adjust(date -> year(date) == 2224, Date(2022, 1, 1))
ERROR: ArgumentError: Adjustment limit reached: 10000 iterations
Stacktrace:
[...]
```
"""
function adjust(func::Function, start; step::Period=Day(1), limit::Int=10000)
    return adjust(DateFunction(func, start), start, step, limit)
end

# Constructors using DateFunctions

"""
    Date(f::Function, y[, m, d]; step=Day(1), limit=10000)::Date

Create a `Date` through the adjuster API. The starting point will be constructed from the
provided `y, m, d` arguments, and will be adjusted until `f::Function` returns `true`.
The step size in adjusting can be provided manually through the `step` keyword.
`limit` provides a limit to the max number of iterations the adjustment API will
pursue before throwing an error (given that `f::Function` is never satisfied).

# Examples
```jldoctest
julia> Date(date -> week(date) == 20, 2010, 01, 01)
2010-05-17

julia> Date(date -> year(date) == 2010, 2000, 01, 01)
2010-01-01

julia> Date(date -> month(date) == 10, 2000, 01, 01; limit = 5)
ERROR: ArgumentError: Adjustment limit reached: 5 iterations
Stacktrace:
[...]
```
"""
function Date(func::Function, y, m=1, d=1; step::Period=Day(1), limit::Int=10000)
    return adjust(DateFunction(func, Date(y, m, d)), Date(y, m, d), step, limit)
end

"""
    DateTime(f::Function, y[, m, d, h, mi, s]; step=Day(1), limit=10000)::DateTime

Create a `DateTime` through the adjuster API. The starting point will be constructed from
the provided `y, m, d...` arguments, and will be adjusted until `f::Function` returns
`true`. The step size in adjusting can be provided manually through the `step` keyword.
`limit` provides a limit to the max number of iterations the adjustment API will
pursue before throwing an error (in the case that `f::Function` is never satisfied).

# Examples
```jldoctest
julia> DateTime(dt -> second(dt) == 40, 2010, 10, 20, 10; step = Second(1))
2010-10-20T10:00:40

julia> DateTime(dt -> hour(dt) == 20, 2010, 10, 20, 10; step = Hour(1), limit = 5)
ERROR: ArgumentError: Adjustment limit reached: 5 iterations
Stacktrace:
[...]
```
"""
DateTime(::Function, args...)

function DateTime(func::Function, y, m=1; step::Period=Day(1), limit::Int=10000)
    return adjust(DateFunction(func, DateTime(y, m)), DateTime(y, m), step, limit)
end
function DateTime(func::Function, y, m, d; step::Period=Hour(1), limit::Int=10000)
    return adjust(DateFunction(func, DateTime(y)), DateTime(y, m, d), step, limit)
end
function DateTime(func::Function, y, m, d, h; step::Period=Minute(1), limit::Int=10000)
    return adjust(DateFunction(func, DateTime(y)), DateTime(y, m, d, h), step, limit)
end
function DateTime(func::Function, y, m, d, h, mi; step::Period=Second(1), limit::Int=10000)
    return adjust(DateFunction(func, DateTime(y)), DateTime(y, m, d, h, mi), step, limit)
end
function DateTime(func::Function, y, m, d, h, mi, s; step::Period=Millisecond(1), limit::Int=10000)
    return adjust(DateFunction(func, DateTime(y)), DateTime(y, m, d, h, mi, s), step, limit)
end

"""
    Time(f::Function, h, mi=0; step::Period=Second(1), limit::Int=10000)
    Time(f::Function, h, mi, s; step::Period=Millisecond(1), limit::Int=10000)
    Time(f::Function, h, mi, s, ms; step::Period=Microsecond(1), limit::Int=10000)
    Time(f::Function, h, mi, s, ms, us; step::Period=Nanosecond(1), limit::Int=10000)

Create a `Time` through the adjuster API. The starting point will be constructed from the
provided `h, mi, s, ms, us` arguments, and will be adjusted until `f::Function` returns `true`.
The step size in adjusting can be provided manually through the `step` keyword. `limit`
provides a limit to the max number of iterations the adjustment API will pursue before
throwing an error (in the case that `f::Function` is never satisfied). Note that the default step
will adjust to allow for greater precision for the given arguments; i.e. if hour, minute, and second
arguments are provided, the default step will be `Millisecond(1)` instead of `Second(1)`.

# Examples
```jldoctest
julia> Time(t -> minute(t) == 30, 20)
20:30:00

julia> Time(t -> minute(t) == 0, 20)
20:00:00

julia> Time(t -> hour(t) == 10, 3; limit = 5)
ERROR: ArgumentError: Adjustment limit reached: 5 iterations
Stacktrace:
[...]
```
"""
Time(::Function, args...)

function Time(func::Function, h, mi=0; step::Period=Second(1), limit::Int=10000)
    return adjust(DateFunction(func, Time(h, mi)), Time(h, mi), step, limit)
end
function Time(func::Function, h, mi, s; step::Period=Millisecond(1), limit::Int=10000)
    return adjust(DateFunction(func, Time(h, mi, s)), Time(h, mi, s), step, limit)
end
function Time(func::Function, h, mi, s, ms; step::Period=Microsecond(1), limit::Int=10000)
    return adjust(DateFunction(func, Time(h, mi, s, ms)), Time(h, mi, s, ms), step, limit)
end
function Time(func::Function, h, mi, s, ms, us; step::Period=Nanosecond(1), limit::Int=10000)
    return adjust(DateFunction(func, Time(h, mi, s, ms, us)), Time(h, mi, s, ms, us), step, limit)
end

# Return the next TimeType that falls on dow
ISDAYOFWEEK = Dict(Mon => DateFunction(ismonday, Date(0)),
                   Tue => DateFunction(istuesday, Date(0)),
                   Wed => DateFunction(iswednesday, Date(0)),
                   Thu => DateFunction(isthursday, Date(0)),
                   Fri => DateFunction(isfriday, Date(0)),
                   Sat => DateFunction(issaturday, Date(0)),
                   Sun => DateFunction(issunday, Date(0)))

# "same" indicates whether the current date can be considered or not
"""
    tonext(dt::TimeType, dow::Int; same::Bool=false)::TimeType

Adjusts `dt` to the next day of week corresponding to `dow` with `1 = Monday, 2 = Tuesday,
etc`. Setting `same=true` allows the current `dt` to be considered as the next `dow`,
allowing for no adjustment to occur.
"""
tonext(dt::TimeType, dow::Int; same::Bool=false) = adjust(ISDAYOFWEEK[dow], same ? dt : dt + Day(1), Day(1), 7)

# Return the next TimeType where func evals true using step in incrementing
"""
    tonext(func::Function, dt::TimeType; step=Day(1), limit=10000, same=false)::TimeType

Adjusts `dt` by iterating at most `limit` iterations by `step` increments until `func`
returns `true`. `func` must take a single `TimeType` argument and return a [`Bool`](@ref).
`same` allows `dt` to be considered in satisfying `func`.
"""
function tonext(func::Function, dt::TimeType; step::Period=Day(1), limit::Int=10000, same::Bool=false)
    return adjust(DateFunction(func, dt), same ? dt : dt + step, step, limit)
end

"""
    toprev(dt::TimeType, dow::Int; same::Bool=false)::TimeType

Adjusts `dt` to the previous day of week corresponding to `dow` with `1 = Monday, 2 =
Tuesday, etc`. Setting `same=true` allows the current `dt` to be considered as the previous
`dow`, allowing for no adjustment to occur.
"""
toprev(dt::TimeType, dow::Int; same::Bool=false) = adjust(ISDAYOFWEEK[dow], same ? dt : dt + Day(-1), Day(-1), 7)

"""
    toprev(func::Function, dt::TimeType; step=Day(-1), limit=10000, same=false)::TimeType

Adjusts `dt` by iterating at most `limit` iterations by `step` increments until `func`
returns `true`. `func` must take a single `TimeType` argument and return a [`Bool`](@ref).
`same` allows `dt` to be considered in satisfying `func`.
"""
function toprev(func::Function, dt::TimeType; step::Period=Day(-1), limit::Int=10000, same::Bool=false)
    return adjust(DateFunction(func, dt), same ? dt : dt + step, step, limit)
end

# Return the first TimeType that falls on dow in the Month or Year
"""
    tofirst(dt::TimeType, dow::Int; of=Month)::TimeType

Adjusts `dt` to the first `dow` of its month. Alternatively, `of=Year` will adjust to the
first `dow` of the year.
"""
function tofirst(dt::TimeType, dow::Int; of::Union{Type{Year}, Type{Month}}=Month)
    dt = of <: Month ? firstdayofmonth(dt) : firstdayofyear(dt)
    return adjust(ISDAYOFWEEK[dow], dt, Day(1), 366)
end

# Return the last TimeType that falls on dow in the Month or Year
"""
    tolast(dt::TimeType, dow::Int; of=Month)::TimeType

Adjusts `dt` to the last `dow` of its month. Alternatively, `of=Year` will adjust to the
last `dow` of the year.
"""
function tolast(dt::TimeType, dow::Int; of::Union{Type{Year}, Type{Month}}=Month)
    dt = of <: Month ? lastdayofmonth(dt) : lastdayofyear(dt)
    return adjust(ISDAYOFWEEK[dow], dt, Day(-1), 366)
end
