# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
Methods for working with Iterators.
"""
baremodule Iterators

# small dance to make this work from Base or Intrinsics
import Base: @__MODULE__, parentmodule
const Base = parentmodule(@__MODULE__)
using .Base:
    @inline, Pair, Pairs, AbstractDict, IndexLinear, IndexStyle, AbstractVector, Vector,
    SizeUnknown, HasLength, HasShape, IsInfinite, EltypeUnknown, HasEltype, OneTo,
    @propagate_inbounds, @isdefined, @boundscheck, @inbounds, Generator, IdDict,
    AbstractRange, AbstractUnitRange, UnitRange, LinearIndices, TupleOrBottom,
    (:), |, +, -, *, !==, !, ==, !=, <=, <, >, >=, =>, missing,
    any, _counttuple, eachindex, ntuple, zero, prod, reduce, in, firstindex, lastindex,
    tail, fieldtypes, min, max, minimum, zero, oneunit, promote, promote_shape, LazyString,
    afoldl, mod1
using .Core
using Core: @doc

using Base:
    cld, fld, resize!, IndexCartesian, Checked
using .Checked: checked_mul

import Base:
    first, last,
    isempty, length, size, axes, ndims,
    eltype, IteratorSize, IteratorEltype, promote_typejoin,
    haskey, keys, values, pairs,
    getindex, setindex!, get, iterate,
    popfirst!, isdone, peek, intersect

export enumerate, zip, rest, countfrom, take, drop, takewhile, dropwhile, cycle, repeated, product, flatten, flatmap, partition, nth
public accumulate, filter, map, peel, reverse, Stateful

"""
    Iterators.map(f, iterators...)

Create a lazy mapping.  This is another syntax for writing
`(f(args...) for args in zip(iterators...))`.

!!! compat "Julia 1.6"
    This function requires at least Julia 1.6.

# Examples
```jldoctest
julia> collect(Iterators.map(x -> x^2, 1:3))
3-element Vector{Int64}:
 1
 4
 9
```
"""
map(f, arg, args...) = Base.Generator(f, arg, args...)

_min_length(a, b, ::IsInfinite, ::IsInfinite) = min(length(a),length(b)) # inherit behaviour, error
_min_length(a, b, A, ::IsInfinite) = length(a)
_min_length(a, b, ::IsInfinite, B) = length(b)
_min_length(a, b, A, B) = min(length(a),length(b))

_diff_length(a, b, A, ::IsInfinite) = 0
_diff_length(a, b, ::IsInfinite, ::IsInfinite) = 0
_diff_length(a, b, ::IsInfinite, B) = length(a) # inherit behaviour, error
function _diff_length(a, b, A, B)
    m, n = length(a), length(b)
    return m > n ? m - n : zero(n - m)
end

and_iteratorsize(isz::T, ::T) where {T} = isz
and_iteratorsize(::HasLength, ::HasShape) = HasLength()
and_iteratorsize(::HasShape, ::HasLength) = HasLength()
and_iteratorsize(a, b) = SizeUnknown()

and_iteratoreltype(iel::T, ::T) where {T} = iel
and_iteratoreltype(a, b) = EltypeUnknown()

## Reverse-order iteration for arrays and other collections.  Collections
## should implement iterate etcetera if possible/practical.
"""
    Iterators.reverse(itr)

Given an iterator `itr`, then `reverse(itr)` is an iterator over the
same collection but in the reverse order.
This iterator is "lazy" in that it does not make a copy of the collection in
order to reverse it; see [`Base.reverse`](@ref) for an eager implementation.

(By default, this returns
an `Iterators.Reverse` object wrapping `itr`, which is iterable
if the corresponding [`iterate`](@ref) methods are defined, but some `itr` types
may implement more specialized `Iterators.reverse` behaviors.)

Not all iterator types `T` support reverse-order iteration.  If `T`
doesn't, then iterating over `Iterators.reverse(itr::T)` will throw a [`MethodError`](@ref)
because of the missing `iterate` methods for `Iterators.Reverse{T}`.
(To implement these methods, the original iterator
`itr::T` can be obtained from an `r::Iterators.Reverse{T}` object by `r.itr`;
more generally, one can use `Iterators.reverse(r)`.)

# Examples
```jldoctest
julia> foreach(println, Iterators.reverse(1:5))
5
4
3
2
1
```
"""
reverse(itr) = Reverse(itr)

struct Reverse{T}
    itr::T
end
eltype(::Type{Reverse{T}}) where {T} = eltype(T)
length(r::Reverse) = length(r.itr)
size(r::Reverse) = size(r.itr)
IteratorSize(::Type{Reverse{T}}) where {T} = IteratorSize(T)
IteratorEltype(::Type{Reverse{T}}) where {T} = IteratorEltype(T)
last(r::Reverse) = first(r.itr) # the first shall be last

# reverse-order array iterators: assumes more-specialized Reverse for eachindex
@propagate_inbounds function iterate(A::Reverse{<:AbstractArray}, state=(reverse(eachindex(A.itr)),))
    y = iterate(state...)
    y === nothing && return y
    idx, itrs = y
    (A.itr[idx], (state[1], itrs))
end

# Fallback method of `iterate(::Reverse{T})` which assumes the collection has `getindex(::T) and `reverse(eachindex(::T))`
# don't propagate inbounds for this just in case
function iterate(A::Reverse, state=(reverse(eachindex(A.itr)),))
    y = iterate(state...)
    y === nothing && return y
    idx, itrs = y
    (A.itr[idx], (state[1], itrs))
end

reverse(R::AbstractRange) = Base.reverse(R) # copying ranges is cheap
reverse(G::Generator) = Generator(G.f, reverse(G.iter))
reverse(r::Reverse) = r.itr
reverse(x::Union{Number,AbstractChar}) = x
reverse(p::Pair) = Base.reverse(p) # copying pairs is cheap

iterate(r::Reverse{<:Union{Tuple, NamedTuple}}, i::Int = length(r.itr)) = i < 1 ? nothing : (r.itr[i], i-1)

# enumerate

struct Enumerate{I}
    itr::I
end

"""
    enumerate(iter)

An iterator that yields `(i, x)` where `i` is a counter starting at 1,
and `x` is the `i`th value from the given iterator. It's useful when
you need not only the values `x` over which you are iterating, but
also the number of iterations so far.

Note that `i` may not be valid for indexing `iter`, or may index a
different element. This will happen if `iter` has indices that do not
start at 1, and may happen for strings, dictionaries, etc.
See the `pairs(IndexLinear(), iter)` method if you want to ensure that `i` is an index.

# Examples
```jldoctest
julia> a = ["a", "b", "c"];

julia> for (index, value) in enumerate(a)
           println("\$index \$value")
       end
1 a
2 b
3 c

julia> str = "naïve";

julia> for (i, val) in enumerate(str)
           print("i = ", i, ", val = ", val, ", ")
           try @show(str[i]) catch e println(e) end
       end
i = 1, val = n, str[i] = 'n'
i = 2, val = a, str[i] = 'a'
i = 3, val = ï, str[i] = 'ï'
i = 4, val = v, StringIndexError("naïve", 4)
i = 5, val = e, str[i] = 'v'
```
"""
enumerate(iter) = Enumerate(iter)

length(e::Enumerate) = length(e.itr)
size(e::Enumerate) = size(e.itr)
@propagate_inbounds function iterate(e::Enumerate, state=(1,))
    i, rest = state[1], tail(state)
    n = iterate(e.itr, rest...)
    n === nothing && return n
    (i, n[1]), (i+1, n[2])
end
last(e::Enumerate) = (length(e.itr), e.itr[end])

eltype(::Type{Enumerate{I}}) where {I} = TupleOrBottom(Int, eltype(I))

IteratorSize(::Type{Enumerate{I}}) where {I} = IteratorSize(I)
IteratorEltype(::Type{Enumerate{I}}) where {I} = IteratorEltype(I)

@inline function iterate(r::Reverse{<:Enumerate})
    ri = reverse(r.itr.itr)
    iterate(r, (length(ri), ri))
end
@inline function iterate(r::Reverse{<:Enumerate}, state)
    i, ri, rest = state[1], state[2], tail(tail(state))
    n = iterate(ri, rest...)
    n === nothing && return n
    (i, n[1]), (i-1, ri, n[2])
end

"""
    pairs(IndexLinear(), A)
    pairs(IndexCartesian(), A)
    pairs(IndexStyle(A), A)

An iterator that accesses each element of the array `A`, returning
`i => x`, where `i` is the index for the element and `x = A[i]`.
Identical to `pairs(A)`, except that the style of index can be selected.
Also similar to `enumerate(A)`, except `i` will be a valid index
for `A`, while `enumerate` always counts from 1 regardless of the indices
of `A`.

Specifying [`IndexLinear()`](@ref) ensures that `i` will be an integer;
specifying [`IndexCartesian()`](@ref) ensures that `i` will be a
[`Base.CartesianIndex`](@ref); specifying `IndexStyle(A)` chooses whichever has
been defined as the native indexing style for array `A`.

Mutation of the bounds of the underlying array will invalidate this iterator.

# Examples
```jldoctest
julia> A = ["a" "d"; "b" "e"; "c" "f"];

julia> for (index, value) in pairs(IndexStyle(A), A)
           println("\$index \$value")
       end
1 a
2 b
3 c
4 d
5 e
6 f

julia> S = view(A, 1:2, :);

julia> for (index, value) in pairs(IndexStyle(S), S)
           println("\$index \$value")
       end
CartesianIndex(1, 1) a
CartesianIndex(2, 1) b
CartesianIndex(1, 2) d
CartesianIndex(2, 2) e
```

See also [`IndexStyle`](@ref), [`axes`](@ref).
"""
pairs(::IndexLinear,    A::AbstractArray) = Pairs(A, LinearIndices(A))

# preserve indexing capabilities for known indexable types
# faster than zip(keys(a), values(a)) for arrays
pairs(tuple::Tuple) = Pairs{Int}(tuple, keys(tuple))
pairs(nt::NamedTuple) = Pairs{Symbol}(nt, keys(nt))
pairs(v::Core.SimpleVector) = Pairs(v, LinearIndices(v))
pairs(A::AbstractVector) = pairs(IndexLinear(), A)
# pairs(v::Pairs) = v # listed for reference, but already defined from being an AbstractDict

pairs(::IndexCartesian, A::AbstractArray) = Pairs(A, Base.CartesianIndices(axes(A)))
pairs(A::AbstractArray)  = pairs(IndexCartesian(), A)

length(v::Pairs) = length(getfield(v, :itr))
axes(v::Pairs) = axes(getfield(v, :itr))
size(v::Pairs) = size(getfield(v, :itr))

Base.@eval @propagate_inbounds function _pairs_elt(p::Pairs{K, V}, idx) where {K, V}
    return $(Expr(:new, :(Pair{K, V}), :idx, :(getfield(p, :data)[idx])))
end

@propagate_inbounds function iterate(p::Pairs{K, V}, state...) where {K, V}
    x = iterate(getfield(p, :itr), state...)
    x === nothing && return x
    idx, next = x
    return (_pairs_elt(p, idx), next)
end

@propagate_inbounds function iterate(r::Reverse{<:Pairs}, state=(reverse(getfield(r.itr, :itr)),))
    x = iterate(state...)
    x === nothing && return x
    idx, next = x
    return (_pairs_elt(r.itr, idx), (state[1], next))
end

@inline isdone(v::Pairs, state...) = isdone(getfield(v, :itr), state...)

IteratorSize(::Type{<:Pairs{<:Any, <:Any, I}}) where {I} = IteratorSize(I)
IteratorSize(::Type{<:Pairs{<:Any, <:Any, <:AbstractUnitRange, <:Tuple}}) = HasLength()

function last(v::Pairs{K, V}) where {K, V}
    idx = last(getfield(v, :itr))
    return Pair{K, V}(idx, v[idx])
end

haskey(v::Pairs, key) = (key in getfield(v, :itr))
keys(v::Pairs) = getfield(v, :itr)
values(v::Pairs) = getfield(v, :data) # TODO: this should be a view of data subset by itr
getindex(v::Pairs, key) = getfield(v, :data)[key]
setindex!(v::Pairs, value, key) = (getfield(v, :data)[key] = value; v)
get(v::Pairs, key, default) = get(getfield(v, :data), key, default)
get(f::Base.Callable, v::Pairs, key) = get(f, getfield(v, :data), key)

# zip

struct Zip{Is<:Tuple}
    is::Is
end

"""
    zip(iters...)

Run multiple iterators at the same time, until any of them is exhausted. The value type of
the `zip` iterator is a tuple of values of its subiterators.

!!! note
    `zip` orders the calls to its subiterators in such a way that stateful iterators will
    not advance when another iterator finishes in the current iteration.

!!! note

    `zip()` with no arguments yields an infinite iterator of empty tuples.

See also: [`enumerate`](@ref), [`Base.splat`](@ref).

# Examples
```jldoctest
julia> a = 1:5
1:5

julia> b = ["e","d","b","c","a"]
5-element Vector{String}:
 "e"
 "d"
 "b"
 "c"
 "a"

julia> c = zip(a,b)
zip(1:5, ["e", "d", "b", "c", "a"])

julia> length(c)
5

julia> first(c)
(1, "e")
```
"""
zip(a...) = Zip(a)
function length(z::Zip)
    n = _zip_min_length(z.is)
    n === nothing && throw(ArgumentError("iterator is of undefined length"))
    return n
end
function _zip_min_length(is)
    i = is[1]
    n = _zip_min_length(tail(is))
    if IteratorSize(i) isa IsInfinite
        return n
    else
        return n === nothing ? length(i) : min(n, length(i))
    end
end
_zip_min_length(is::Tuple{}) = nothing

# For a collection of iterators `is`, returns a tuple (b, n), where
# `b` is true when every component of `is` has a statically-known finite
# length and all such lengths are equal. Otherwise, `b` is false.
# `n` is an implementation detail, and will be the `length` of the first
# iterator if it is statically-known and finite. Otherwise, `n` is `nothing`.
function _zip_lengths_finite_equal(is)
    i = is[1]
    if IteratorSize(i) isa Union{IsInfinite, SizeUnknown}
        return (false, nothing)
    else
        b, n = _zip_lengths_finite_equal(tail(is))
        return (b && (n === nothing || n == length(i)), length(i))
    end
end
_zip_lengths_finite_equal(is::Tuple{}) = (true, nothing)
size(z::Zip) = _promote_tuple_shape(Base.map(size, z.is)...)
axes(z::Zip) = _promote_tuple_shape(Base.map(axes, z.is)...)
_promote_tuple_shape((a,)::Tuple{OneTo}, (b,)::Tuple{OneTo}) = (intersect(a, b),)
_promote_tuple_shape((m,)::Tuple{Integer}, (n,)::Tuple{Integer}) = (min(m, n),)
_promote_tuple_shape(a, b) = promote_shape(a, b)
_promote_tuple_shape(a, b...) = _promote_tuple_shape(a, _promote_tuple_shape(b...))
_promote_tuple_shape(a) = a
eltype(::Type{Zip{Is}}) where {Is<:Tuple} = TupleOrBottom(map(eltype, fieldtypes(Is))...)
#eltype(::Type{Zip{Tuple{}}}) = Tuple{}
#eltype(::Type{Zip{Tuple{A}}}) where {A} = Tuple{eltype(A)}
#eltype(::Type{Zip{Tuple{A, B}}}) where {A, B} = Tuple{eltype(A), eltype(B)}
@inline isdone(z::Zip) = _zip_any_isdone(z.is, Base.map(_ -> (), z.is))
@inline isdone(z::Zip, ss) = _zip_any_isdone(z.is, Base.map(tuple, ss))
@inline function _zip_any_isdone(is, ss)
    d1 = isdone(is[1], ss[1]...)
    d1 === true && return true
    return d1 | _zip_any_isdone(tail(is), tail(ss))
end
@inline _zip_any_isdone(::Tuple{}, ::Tuple{}) = false

@propagate_inbounds iterate(z::Zip) = _zip_iterate_all(z.is, Base.map(_ -> (), z.is))
@propagate_inbounds iterate(z::Zip, ss) = _zip_iterate_all(z.is, Base.map(tuple, ss))

# This first queries isdone from every iterator. If any gives true, it immediately returns
# nothing. It then iterates all those where isdone returned missing, afterwards all those
# it returned false, again terminating immediately if any iterator is exhausted. Finally,
# the results are interleaved appropriately.
@propagate_inbounds function _zip_iterate_all(is, ss)
    d, ds = _zip_isdone(is, ss)
    d && return nothing
    xs1 = _zip_iterate_some(is, ss, ds, missing)
    xs1 === nothing && return nothing
    xs2 = _zip_iterate_some(is, ss, ds, false)
    xs2 === nothing && return nothing
    return _zip_iterate_interleave(xs1, xs2, ds)
end

@propagate_inbounds function _zip_iterate_some(is, ss, ds::Tuple{T,Vararg{Any}}, f::T) where T
    x = iterate(is[1], ss[1]...)
    x === nothing && return nothing
    y = _zip_iterate_some(tail(is), tail(ss), tail(ds), f)
    y === nothing && return nothing
    return (x, y...)
end
@propagate_inbounds _zip_iterate_some(is, ss, ds::Tuple{Any,Vararg{Any}}, f) =
    _zip_iterate_some(tail(is), tail(ss), tail(ds), f)
_zip_iterate_some(::Tuple{}, ::Tuple{}, ::Tuple{}, ::Any) = ()

function _zip_iterate_interleave(xs1, xs2, ds)
    t = _zip_iterate_interleave(tail(xs1), xs2, tail(ds))
    ((xs1[1][1], t[1]...), (xs1[1][2], t[2]...))
end
function _zip_iterate_interleave(xs1, xs2, ds::Tuple{Bool,Vararg{Any}})
    t = _zip_iterate_interleave(xs1, tail(xs2), tail(ds))
    ((xs2[1][1], t[1]...), (xs2[1][2], t[2]...))
end
_zip_iterate_interleave(::Tuple{}, ::Tuple{}, ::Tuple{}) = ((), ())

function _zip_isdone(is, ss)
    d = isdone(is[1], ss[1]...)
    d´, ds = _zip_isdone(tail(is), tail(ss))
    return (d === true || d´, (d, ds...))
end
_zip_isdone(::Tuple{}, ::Tuple{}) = (false, ())

IteratorSize(::Type{Zip{Is}}) where {Is<:Tuple} = zip_iteratorsize(ntuple(n -> IteratorSize(fieldtype(Is, n)), _counttuple(Is)::Int)...)
IteratorEltype(::Type{Zip{Is}}) where {Is<:Tuple} = zip_iteratoreltype(ntuple(n -> IteratorEltype(fieldtype(Is, n)), _counttuple(Is)::Int)...)

zip_iteratorsize() = IsInfinite()
zip_iteratorsize(I) = I
zip_iteratorsize(a, b) = and_iteratorsize(a,b) # as `and_iteratorsize` but inherit `Union{HasLength,IsInfinite}` of the shorter iterator
zip_iteratorsize(::HasLength, ::IsInfinite) = HasLength()
zip_iteratorsize(::HasShape, ::IsInfinite) = HasLength()
zip_iteratorsize(a::IsInfinite, b) = zip_iteratorsize(b,a)
zip_iteratorsize(a::IsInfinite, b::IsInfinite) = IsInfinite()
zip_iteratorsize(a, b, tail...) = zip_iteratorsize(a, zip_iteratorsize(b, tail...))

zip_iteratoreltype() = HasEltype()
zip_iteratoreltype(a) = a
zip_iteratoreltype(a, tail...) = and_iteratoreltype(a, zip_iteratoreltype(tail...))

last(z::Zip) = getindex.(z.is, minimum(Base.map(lastindex, z.is)))
function reverse(z::Zip)
    if !first(_zip_lengths_finite_equal(z.is))
        throw(ArgumentError("Cannot reverse zipped iterators of unknown, infinite, or unequal lengths"))
    end
    Zip(Base.map(reverse, z.is))
end

# filter

struct Filter{F,I}
    flt::F
    itr::I
end

"""
    Iterators.filter(flt, itr)

Given a predicate function `flt` and an iterable object `itr`, return an
iterable object which upon iteration yields the elements `x` of `itr` that
satisfy `flt(x)`. The order of the original iterator is preserved.

This function is *lazy*; that is, it is guaranteed to return in ``Θ(1)`` time
and use ``Θ(1)`` additional space, and `flt` will not be called by an
invocation of `filter`. Calls to `flt` will be made when iterating over the
returned iterable object. These calls are not cached and repeated calls will be
made when reiterating.

!!! warning
    Subsequent *lazy* transformations on the iterator returned from `filter`, such
    as those performed by `Iterators.reverse` or `cycle`, will also delay calls to `flt`
    until collecting or iterating over the returned iterable object. If the filter
    predicate is nondeterministic or its return values depend on the order of iteration
    over the elements of `itr`, composition with lazy transformations may result in
    surprising behavior. If this is undesirable, either ensure that `flt` is a pure
    function or collect intermediate `filter` iterators before further transformations.

See [`Base.filter`](@ref) for an eager implementation of filtering for arrays.

# Examples
```jldoctest
julia> f = Iterators.filter(isodd, [1, 2, 3, 4, 5])
Base.Iterators.Filter{typeof(isodd), Vector{Int64}}(isodd, [1, 2, 3, 4, 5])

julia> foreach(println, f)
1
3
5

julia> [x for x in [1, 2, 3, 4, 5] if isodd(x)]  # collects a generator over Iterators.filter
3-element Vector{Int64}:
 1
 3
 5
```
"""
filter(flt, itr) = Filter(flt, itr)

function iterate(f::Filter, state...)
    y = iterate(f.itr, state...)
    while y !== nothing
        v, s = y
        if f.flt(v)
            if y isa Tuple{Any,Any}
                return (v, s) # incorporate type information that may be improved by user-provided `f.flt`
            else
                return y
            end
        end
        y = iterate(f.itr, s)
    end
    nothing
end

eltype(::Type{Filter{F,I}}) where {F,I} = eltype(I)
IteratorEltype(::Type{Filter{F,I}}) where {F,I} = IteratorEltype(I)
IteratorSize(::Type{<:Filter}) = SizeUnknown()

reverse(f::Filter) = Filter(f.flt, reverse(f.itr))
last(f::Filter) = first(reverse(f))

# Accumulate -- partial reductions of a function over an iterator

struct Accumulate{F,I,T}
    f::F
    itr::I
    init::T
end

"""
    Iterators.accumulate(f, itr; [init])

Given a 2-argument function `f` and an iterator `itr`, return a new
iterator that successively applies `f` to the previous value and the
next element of `itr`.

This is effectively a lazy version of [`Base.accumulate`](@ref).

!!! compat "Julia 1.5"
    Keyword argument `init` is added in Julia 1.5.

# Examples
```jldoctest
julia> a = Iterators.accumulate(+, [1,2,3,4]);

julia> foreach(println, a)
1
3
6
10

julia> b = Iterators.accumulate(/, (2, 5, 2, 5); init = 100);

julia> collect(b)
4-element Vector{Float64}:
 50.0
 10.0
  5.0
  1.0
```
"""
accumulate(f, itr; init = Base._InitialValue()) = Accumulate(f, itr, init)

function iterate(itr::Accumulate)
    state = iterate(itr.itr)
    if state === nothing
        return nothing
    end
    val = Base.BottomRF(itr.f)(itr.init, state[1])
    return (val, (val, state[2]))
end

function iterate(itr::Accumulate, state)
    nxt = iterate(itr.itr, state[2])
    if nxt === nothing
        return nothing
    end
    val = itr.f(state[1], nxt[1])
    return (val, (val, nxt[2]))
end

length(itr::Accumulate) = length(itr.itr)
size(itr::Accumulate) = size(itr.itr)

IteratorSize(::Type{<:Accumulate{<:Any,I}}) where {I} = IteratorSize(I)
IteratorEltype(::Type{<:Accumulate}) = EltypeUnknown()

# Rest -- iterate starting at the given state

struct Rest{I,S}
    itr::I
    st::S
end

"""
    rest(iter, state)

An iterator that yields the same elements as `iter`, but starting at the given `state`, which
must be a state obtainable via a sequence of one or more calls to `iterate(iter[, state])`

See also: [`Iterators.drop`](@ref), [`Iterators.peel`](@ref), [`Base.rest`](@ref).

# Examples
```jldoctest
julia> iter = [1,2,3,4];

julia> val, state = iterate(iter)
(1, 2)

julia> collect(Iterators.rest(iter, state))
3-element Vector{Int64}:
 2
 3
 4
```
"""
rest(itr,state) = Rest(itr,state)
rest(itr::Rest,state) = Rest(itr.itr,state)
rest(itr) = itr

"""
    peel(iter)

Returns the first element and an iterator over the remaining elements.

If the iterator is empty return `nothing` (like `iterate`).

!!! compat "Julia 1.7"
    Prior versions throw a BoundsError if the iterator is empty.

See also: [`Iterators.drop`](@ref), [`Iterators.take`](@ref).

# Examples
```jldoctest
julia> (a, rest) = Iterators.peel("abc");

julia> a
'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)

julia> collect(rest)
2-element Vector{Char}:
 'b': ASCII/Unicode U+0062 (category Ll: Letter, lowercase)
 'c': ASCII/Unicode U+0063 (category Ll: Letter, lowercase)
```
"""
function peel(itr)
    y = iterate(itr)
    y === nothing && return y
    val, s = y
    val, rest(itr, s)
end

@propagate_inbounds iterate(i::Rest, st=i.st) = iterate(i.itr, st)
isdone(i::Rest, st...) = isdone(i.itr, st...)

eltype(::Type{<:Rest{I}}) where {I} = eltype(I)
IteratorEltype(::Type{<:Rest{I}}) where {I} = IteratorEltype(I)
rest_iteratorsize(a) = SizeUnknown()
rest_iteratorsize(::IsInfinite) = IsInfinite()
IteratorSize(::Type{<:Rest{I}}) where {I} = rest_iteratorsize(IteratorSize(I))

# Count -- infinite counting

struct Count{T,S}
    start::T
    step::S
end

"""
    countfrom(start=1, step=1)

An iterator that counts forever, starting at `start` and incrementing by `step`.

# Examples
```jldoctest
julia> for v in Iterators.countfrom(5, 2)
           v > 10 && break
           println(v)
       end
5
7
9
```
"""
countfrom(start::T, step::S) where {T,S} = Count{typeof(start+step),S}(start, step)
countfrom(start::Number, step::Number)   = Count(promote(start, step)...)
countfrom(start)                         = Count(start, oneunit(start))
countfrom()                              = Count(1, 1)


eltype(::Type{<:Count{T}}) where {T} = T

iterate(it::Count, state=it.start) = (state, state + it.step)

IteratorSize(::Type{<:Count}) = IsInfinite()

# Take -- iterate through the first n elements

struct Take{I}
    xs::I
    n::Int
    function Take(xs::I, n::Integer) where {I}
        n < 0 && throw(ArgumentError("Take length must be non-negative"))
        return new{I}(xs, n)
    end
end

"""
    take(iter, n)

An iterator that generates at most the first `n` elements of `iter`.

See also: [`drop`](@ref Iterators.drop), [`peel`](@ref Iterators.peel), [`first`](@ref), [`Base.take!`](@ref).

# Examples
```jldoctest
julia> a = 1:2:11
1:2:11

julia> collect(a)
6-element Vector{Int64}:
  1
  3
  5
  7
  9
 11

julia> collect(Iterators.take(a,3))
3-element Vector{Int64}:
 1
 3
 5
```
"""
take(xs, n::Integer) = Take(xs, Int(n))
take(xs::Take, n::Integer) = Take(xs.xs, min(Int(n), xs.n))

eltype(::Type{Take{I}}) where {I} = eltype(I)
IteratorEltype(::Type{Take{I}}) where {I} = IteratorEltype(I)
take_iteratorsize(a) = HasLength()
take_iteratorsize(::SizeUnknown) = SizeUnknown()
IteratorSize(::Type{Take{I}}) where {I} = take_iteratorsize(IteratorSize(I))
length(t::Take) = _min_length(t.xs, 1:t.n, IteratorSize(t.xs), HasLength())
isdone(t::Take) = isdone(t.xs)
isdone(t::Take, state) = (state[1] <= 0) | isdone(t.xs, tail(state))

@propagate_inbounds function iterate(it::Take, state=(it.n,))
    n, rest = state[1], tail(state)
    n <= 0 && return nothing
    y = iterate(it.xs, rest...)
    y === nothing && return nothing
    return y[1], (n - 1, y[2])
end

# Drop -- iterator through all but the first n elements

struct Drop{I}
    xs::I
    n::Int
    function Drop(xs::I, n::Integer) where {I}
        n < 0 && throw(ArgumentError("Drop length must be non-negative"))
        return new{I}(xs, n)
    end
end

"""
    drop(iter, n)

An iterator that generates all but the first `n` elements of `iter`.

# Examples
```jldoctest
julia> a = 1:2:11
1:2:11

julia> collect(a)
6-element Vector{Int64}:
  1
  3
  5
  7
  9
 11

julia> collect(Iterators.drop(a,4))
2-element Vector{Int64}:
  9
 11
```
"""
drop(xs, n::Integer) = Drop(xs, Int(n))
drop(xs::Take, n::Integer) = Take(drop(xs.xs, Int(n)), max(0, xs.n - Int(n)))
drop(xs::Drop, n::Integer) = Drop(xs.xs, Int(n) + xs.n)

eltype(::Type{Drop{I}}) where {I} = eltype(I)
IteratorEltype(::Type{Drop{I}}) where {I} = IteratorEltype(I)
drop_iteratorsize(::SizeUnknown) = SizeUnknown()
drop_iteratorsize(::Union{HasShape, HasLength}) = HasLength()
drop_iteratorsize(::IsInfinite) = IsInfinite()
IteratorSize(::Type{Drop{I}}) where {I} = drop_iteratorsize(IteratorSize(I))
length(d::Drop) = _diff_length(d.xs, 1:d.n, IteratorSize(d.xs), HasLength())

function iterate(it::Drop)
    y = iterate(it.xs)
    for i in 1:it.n
        y === nothing && return y
        y = iterate(it.xs, y[2])
    end
    y
end
iterate(it::Drop, state) = iterate(it.xs, state)
isdone(it::Drop, state) = isdone(it.xs, state)


# takewhile

struct TakeWhile{I,P<:Function}
    pred::P
    xs::I
end

"""
    takewhile(pred, iter)

An iterator that generates element from `iter` as long as predicate `pred` is true,
afterwards, drops every element.

!!! compat "Julia 1.4"
    This function requires at least Julia 1.4.

# Examples

```jldoctest
julia> s = collect(1:5)
5-element Vector{Int64}:
 1
 2
 3
 4
 5

julia> collect(Iterators.takewhile(<(3),s))
2-element Vector{Int64}:
 1
 2
```
"""
takewhile(pred,xs) = TakeWhile(pred,xs)

function iterate(ibl::TakeWhile, itr...)
    y = iterate(ibl.xs,itr...)
    y === nothing && return nothing
    ibl.pred(y[1]) || return nothing
    y
end

IteratorSize(::Type{<:TakeWhile}) = SizeUnknown()
eltype(::Type{TakeWhile{I,P}} where P) where {I} = eltype(I)
IteratorEltype(::Type{TakeWhile{I, P}} where P) where {I} = IteratorEltype(I)


# dropwhile

struct DropWhile{I,P<:Function}
    pred::P
    xs::I
end

"""
    dropwhile(pred, iter)

An iterator that drops element from `iter` as long as predicate `pred` is true,
afterwards, returns every element.

!!! compat "Julia 1.4"
    This function requires at least Julia 1.4.

# Examples

```jldoctest
julia> s = collect(1:5)
5-element Vector{Int64}:
 1
 2
 3
 4
 5

julia> collect(Iterators.dropwhile(<(3),s))
3-element Vector{Int64}:
 3
 4
 5
```
"""
dropwhile(pred,itr) = DropWhile(pred,itr)

iterate(ibl::DropWhile,itr) = iterate(ibl.xs, itr)
function iterate(ibl::DropWhile)
    y = iterate(ibl.xs)
    while y !== nothing
        ibl.pred(y[1]) || break
        y = iterate(ibl.xs,y[2])
    end
    y
end

IteratorSize(::Type{<:DropWhile}) = SizeUnknown()
eltype(::Type{DropWhile{I,P}}) where {I,P} = eltype(I)
IteratorEltype(::Type{DropWhile{I,P}}) where {I,P} = IteratorEltype(I)


# Cycle an iterator forever

struct Cycle{I}
    xs::I
end

"""
    cycle(iter[, n::Int])

An iterator that cycles through `iter` forever.
If `n` is specified, then it cycles through `iter` that many times.
When `iter` is empty, so are `cycle(iter)` and `cycle(iter, n)`.

`Iterators.cycle(iter, n)` is the lazy equivalent of [`Base.repeat`](@ref)`(vector, n)`,
while [`Iterators.repeated`](@ref)`(iter, n)` is the lazy [`Base.fill`](@ref)`(item, n)`.

!!! compat "Julia 1.11"
    The method `cycle(iter, n)` was added in Julia 1.11.

# Examples
```jldoctest
julia> for (i, v) in enumerate(Iterators.cycle("hello"))
           print(v)
           i > 10 && break
       end
hellohelloh

julia> foreach(print, Iterators.cycle(['j', 'u', 'l', 'i', 'a'], 3))
juliajuliajulia

julia> repeat([1,2,3], 4) == collect(Iterators.cycle([1,2,3], 4))
true

julia> fill([1,2,3], 4) == collect(Iterators.repeated([1,2,3], 4))
true
```
"""
cycle(xs) = Cycle(xs)
cycle(xs, n::Integer) = flatten(repeated(xs, n))

eltype(::Type{Cycle{I}}) where {I} = eltype(I)
IteratorEltype(::Type{Cycle{I}}) where {I} = IteratorEltype(I)
IteratorSize(::Type{Cycle{I}}) where {I} = IsInfinite() # XXX: this is false if iterator ever becomes empty

iterate(it::Cycle) = iterate(it.xs)
isdone(it::Cycle) = isdone(it.xs)
isdone(it::Cycle, state) = false
function iterate(it::Cycle, state)
    y = iterate(it.xs, state)
    y === nothing && return iterate(it)
    y
end

reverse(it::Cycle) = Cycle(reverse(it.xs))
last(it::Cycle) = last(it.xs)


# Repeated - repeat an object infinitely many times

struct Repeated{O}
    x::O
end
repeated(x) = Repeated(x)

"""
    repeated(x[, n::Int])

An iterator that generates the value `x` forever. If `n` is specified, generates `x` that
many times (equivalent to `take(repeated(x), n)`).

See also [`fill`](@ref Base.fill), and compare [`Iterators.cycle`](@ref).

# Examples
```jldoctest
julia> a = Iterators.repeated([1 2], 4);

julia> collect(a)
4-element Vector{Matrix{Int64}}:
 [1 2]
 [1 2]
 [1 2]
 [1 2]

julia> ans == fill([1 2], 4)
true

julia> Iterators.cycle([1 2], 4) |> collect |> println
[1, 2, 1, 2, 1, 2, 1, 2]
```
"""
repeated(x, n::Integer) = take(repeated(x), Int(n))

eltype(::Type{Repeated{O}}) where {O} = O

iterate(it::Repeated, state...) = (it.x, nothing)

IteratorSize(::Type{<:Repeated}) = IsInfinite()
IteratorEltype(::Type{<:Repeated}) = HasEltype()

reverse(it::Union{Repeated,Take{<:Repeated}}) = it
last(it::Union{Repeated,Take{<:Repeated}}) = first(it)

# Product -- cartesian product of iterators
struct ProductIterator{T<:Tuple}
    iterators::T
end

"""
    product(iters...)

Return an iterator over the product of several iterators. Each generated element is
a tuple whose `i`th element comes from the `i`th argument iterator. The first iterator
changes the fastest.

See also: [`zip`](@ref), [`Iterators.flatten`](@ref).

# Examples
```jldoctest
julia> collect(Iterators.product(1:2, 3:5))
2×3 Matrix{Tuple{Int64, Int64}}:
 (1, 3)  (1, 4)  (1, 5)
 (2, 3)  (2, 4)  (2, 5)

julia> ans == [(x,y) for x in 1:2, y in 3:5]  # collects a generator involving Iterators.product
true
```
"""
product(iters...) = ProductIterator(iters)

IteratorSize(::Type{ProductIterator{Tuple{}}}) = HasShape{0}()
IteratorSize(::Type{ProductIterator{T}}) where {T<:Tuple} =
    prod_iteratorsize(ntuple(n -> IteratorSize(fieldtype(T, n)), _counttuple(T)::Int)..., HasShape{0}())

prod_iteratorsize() = HasShape{0}()
prod_iteratorsize(I) = I

prod_iteratorsize(::HasLength, ::HasLength) = HasShape{2}()
prod_iteratorsize(::HasLength, ::HasShape{N}) where {N} = HasShape{N+1}()
prod_iteratorsize(::HasShape{N}, ::HasLength) where {N} = HasShape{N+1}()
prod_iteratorsize(::HasShape{M}, ::HasShape{N}) where {M,N} = HasShape{M+N}()

# products can have an infinite iterator
prod_iteratorsize(::IsInfinite, ::IsInfinite) = IsInfinite()
prod_iteratorsize(a, ::IsInfinite) = IsInfinite()
prod_iteratorsize(::IsInfinite, b) = IsInfinite()
prod_iteratorsize(a, b) = SizeUnknown()
prod_iteratorsize(a, b, tail...) = prod_iteratorsize(a, prod_iteratorsize(b, tail...))

size(P::ProductIterator) = _prod_size(P.iterators)
_prod_size(::Tuple{}) = ()
_prod_size(t::Tuple) = (_prod_size1(t[1], IteratorSize(t[1]))..., _prod_size(tail(t))...)
_prod_size1(a, ::HasShape)  = size(a)
_prod_size1(a, ::HasLength) = (length(a),)
_prod_size1(a, A) =
    throw(ArgumentError(LazyString("Cannot compute size for object of type ", typeof(a))))

axes(P::ProductIterator) = _prod_indices(P.iterators)
_prod_indices(::Tuple{}) = ()
_prod_indices(t::Tuple) = (_prod_axes1(t[1], IteratorSize(t[1]))..., _prod_indices(tail(t))...)
_prod_axes1(a, ::HasShape)  = axes(a)
_prod_axes1(a, ::HasLength) = (OneTo(length(a)),)
_prod_axes1(a, A) =
    throw(ArgumentError(LazyString("Cannot compute indices for object of type ", typeof(a))))

ndims(p::ProductIterator) = length(axes(p))
length(P::ProductIterator) = reduce(checked_mul, size(P); init=1)

IteratorEltype(::Type{ProductIterator{Tuple{}}}) = HasEltype()
IteratorEltype(::Type{ProductIterator{Tuple{I}}}) where {I} = IteratorEltype(I)

function IteratorEltype(::Type{ProductIterator{T}}) where {T<:Tuple}
    E = ntuple(n -> IteratorEltype(fieldtype(T, n)), _counttuple(T)::Int)
    any(I -> I == EltypeUnknown(), E) && return EltypeUnknown()
    return E[end]
end

eltype(::Type{ProductIterator{I}}) where {I} = _prod_eltype(I)
_prod_eltype(::Type{Tuple{}}) = Tuple{}
_prod_eltype(::Type{I}) where {I<:Tuple} = TupleOrBottom(ntuple(n -> eltype(fieldtype(I, n)), _counttuple(I)::Int)...)

iterate(::ProductIterator{Tuple{}}) = (), true
iterate(::ProductIterator{Tuple{}}, state) = nothing

@inline isdone(P::ProductIterator) = any(isdone, P.iterators)
@inline function _pisdone(iters, states)
    iter1 = first(iters)
    done1 = isdone(iter1, first(states)[2]) # check step
    done1 === true || return done1 # false or missing
    done1 = isdone(iter1) # check restart
    done1 === true || return done1 # false or missing
    return _pisdone(tail(iters), tail(states)) # check tail
end
@inline isdone(::ProductIterator{Tuple{}}, states) = true
@inline isdone(P::ProductIterator, states) = _pisdone(P.iterators, states)

@inline _piterate() = ()
@inline function _piterate(iter1, rest...)
    next = iterate(iter1)
    next === nothing && return nothing
    restnext = _piterate(rest...)
    restnext === nothing && return nothing
    return (next, restnext...)
end
@inline function iterate(P::ProductIterator)
    isdone(P) === true && return nothing
    next = _piterate(P.iterators...)
    next === nothing && return nothing
    return (Base.map(x -> x[1], next), next)
end

@inline _piterate1(::Tuple{}, ::Tuple{}) = nothing
@inline function _piterate1(iters, states)
    iter1 = first(iters)
    next = iterate(iter1, first(states)[2])
    restnext = tail(states)
    if next === nothing
        isdone(iter1) === true && return nothing
        restnext = _piterate1(tail(iters), restnext)
        restnext === nothing && return nothing
        next = iterate(iter1)
        next === nothing && return nothing
    end
    return (next, restnext...)
end
@inline function iterate(P::ProductIterator, states)
    isdone(P, states) === true && return nothing
    next = _piterate1(P.iterators, states)
    next === nothing && return nothing
    return (Base.map(x -> x[1], next), next)
end

reverse(p::ProductIterator) = ProductIterator(Base.map(reverse, p.iterators))
last(p::ProductIterator) = Base.map(last, p.iterators)
intersect(a::ProductIterator, b::ProductIterator) = ProductIterator(intersect.(a.iterators, b.iterators))

# flatten an iterator of iterators

struct Flatten{I}
    it::I
end

"""
    flatten(iter)

Given an iterator that yields iterators, return an iterator that yields the
elements of those iterators.
Put differently, the elements of the argument iterator are concatenated.

# Examples
```jldoctest
julia> collect(Iterators.flatten((1:2, 8:9)))
4-element Vector{Int64}:
 1
 2
 8
 9

julia> [(x,y) for x in 0:1 for y in 'a':'c']  # collects generators involving Iterators.flatten
6-element Vector{Tuple{Int64, Char}}:
 (0, 'a')
 (0, 'b')
 (0, 'c')
 (1, 'a')
 (1, 'b')
 (1, 'c')
```
"""
flatten(itr) = Flatten(itr)

eltype(::Type{Flatten{I}}) where {I} = eltype(eltype(I))

# For tuples, we statically know the element type of each index, so we can compute
# this at compile time.
function eltype(::Type{Flatten{I}}) where {I<:Union{Tuple,NamedTuple}}
    afoldl((T, i) -> promote_typejoin(T, eltype(i)), Union{}, fieldtypes(I)...)
end

IteratorEltype(::Type{Flatten{I}}) where {I} = _flatteneltype(I, IteratorEltype(I))
IteratorEltype(::Type{Flatten{Tuple{}}}) = IteratorEltype(Tuple{})
_flatteneltype(I, ::HasEltype) = IteratorEltype(eltype(I))
_flatteneltype(I, et) = EltypeUnknown()

flatten_iteratorsize(::Union{HasShape, HasLength}, ::Type{Union{}}, slurp...) = HasLength() # length==0
flatten_iteratorsize(::Union{HasShape, HasLength}, ::Type{<:NTuple{N,Any}}) where {N} = HasLength()
flatten_iteratorsize(::Union{HasShape, HasLength}, ::Type{<:Tuple}) = SizeUnknown()
flatten_iteratorsize(::Union{HasShape, HasLength}, ::Type{<:Number}) = HasLength()
flatten_iteratorsize(a, b) = SizeUnknown()

_flatten_iteratorsize(sz, ::EltypeUnknown, I) = SizeUnknown()
_flatten_iteratorsize(sz, ::HasEltype, I) = flatten_iteratorsize(sz, eltype(I))
_flatten_iteratorsize(sz, ::HasEltype, ::Type{Tuple{}}) = HasLength()

IteratorSize(::Type{Flatten{I}}) where {I} = _flatten_iteratorsize(IteratorSize(I), IteratorEltype(I), I)

flatten_length(f, T::Type{Union{}}, slurp...) = 0
function flatten_length(f, T::Type{<:NTuple{N,Any}}) where {N}
    return N * length(f.it)
end
flatten_length(f, ::Type{<:Number}) = length(f.it)
flatten_length(f, T) = throw(ArgumentError(
    "Iterates of the argument to Flatten are not known to have constant length"))
length(f::Flatten{I}) where {I} = flatten_length(f, eltype(I))
length(f::Flatten{Tuple{}}) = 0

@propagate_inbounds function iterate(fl::Flatten)
    it_result = iterate(fl.it)
    it_result === nothing && return nothing

    inner_iterator, next_outer_state = it_result
    inner_it_result = iterate(inner_iterator)

    while inner_it_result === nothing
        it_result = iterate(fl.it, next_outer_state)
        it_result === nothing && return nothing

        inner_iterator, next_outer_state = it_result
        inner_it_result = iterate(inner_iterator)
    end

    item, next_inner_state = inner_it_result
    return item, (next_outer_state, inner_iterator, next_inner_state)
end

@propagate_inbounds function iterate(fl::Flatten, state)
    next_outer_state, inner_iterator, next_inner_state = state

    # try to advance the inner iterator
    inner_it_result = iterate(inner_iterator, next_inner_state)
    if inner_it_result !== nothing
        item, next_inner_state = inner_it_result
        return item, (next_outer_state, inner_iterator, next_inner_state)
    end

    # advance the outer iterator
    while true
        outer_it_result = iterate(fl.it, next_outer_state)
        outer_it_result === nothing && return nothing

        inner_iterator, next_outer_state = outer_it_result
        inner_it_result = iterate(inner_iterator)

        if inner_it_result !== nothing
            item, next_inner_state = inner_it_result
            return item, (next_outer_state, inner_iterator, next_inner_state)
        end
    end
end

reverse(f::Flatten) = Flatten(reverse(itr) for itr in reverse(f.it))
last(f::Flatten) = last(last(f.it))

"""
    Iterators.flatmap(f, iterators...)

Equivalent to `flatten(map(f, iterators...))`.

See also [`Iterators.flatten`](@ref), [`Iterators.map`](@ref).

!!! compat "Julia 1.9"
    This function was added in Julia 1.9.

# Examples
```jldoctest
julia> Iterators.flatmap(n -> -n:2:n, 1:3) |> collect
9-element Vector{Int64}:
 -1
  1
 -2
  0
  2
 -3
 -1
  1
  3

julia> stack(n -> -n:2:n, 1:3)
ERROR: DimensionMismatch: stack expects uniform slices, got axes(x) == (1:3,) while first had (1:2,)
[...]

julia> Iterators.flatmap(n -> (-n, 10n), 1:2) |> collect
4-element Vector{Int64}:
 -1
 10
 -2
 20

julia> ans == vec(stack(n -> (-n, 10n), 1:2))
true
```
"""
flatmap(f, c...) = flatten(map(f, c...))

@doc """
    partition(collection, n)

Iterate over a collection `n` elements at a time.

# Examples
```jldoctest
julia> collect(Iterators.partition([1,2,3,4,5], 2))
3-element Vector{SubArray{Int64, 1, Vector{Int64}, Tuple{UnitRange{Int64}}, true}}:
 [1, 2]
 [3, 4]
 [5]
```
""" function partition(c, n::Integer)
    n < 1 && throw(ArgumentError("cannot create partitions of length $n"))
    return PartitionIterator(c, Int(n))
end

struct PartitionIterator{T}
    c::T
    n::Int
end
# Partitions are explicitly a linear indexing operation, so reshape to 1-d immediately
PartitionIterator(A::AbstractArray, n::Int) = PartitionIterator(Base.vec(A), n)
PartitionIterator(v::AbstractVector, n::Int) = PartitionIterator{typeof(v)}(v, n)

eltype(::Type{PartitionIterator{T}}) where {T} = Vector{eltype(T)}
# Arrays use a generic `view`-of-a-`vec`, so we cannot exactly predict what we'll get back
eltype(::Type{PartitionIterator{T}}) where {T<:AbstractArray} = AbstractVector{eltype(T)}
# But for some common implementations in Base we know the answer exactly
eltype(::Type{PartitionIterator{T}}) where {T<:Vector} = Base.SubArray{eltype(T), 1, T, Tuple{UnitRange{Int}}, true}

IteratorEltype(::Type{PartitionIterator{T}}) where {T} = IteratorEltype(T)
IteratorEltype(::Type{PartitionIterator{T}}) where {T<:AbstractArray} = EltypeUnknown()
IteratorEltype(::Type{PartitionIterator{T}}) where {T<:Vector} = IteratorEltype(T)

partition_iteratorsize(::HasShape) = HasLength()
partition_iteratorsize(isz) = isz
function IteratorSize(::Type{PartitionIterator{T}}) where {T}
    partition_iteratorsize(IteratorSize(T))
end

function length(itr::PartitionIterator)
    l = length(itr.c)
    return cld(l, itr.n)
end

function iterate(itr::PartitionIterator{<:AbstractRange}, state = firstindex(itr.c))
    state > lastindex(itr.c) && return nothing
    r = min(state + itr.n - 1, lastindex(itr.c))
    return @inbounds itr.c[state:r], r + 1
end

function iterate(itr::PartitionIterator{<:AbstractArray}, state = firstindex(itr.c))
    state > lastindex(itr.c) && return nothing
    r = min(state + itr.n - 1, lastindex(itr.c))
    return @inbounds Base.view(itr.c, state:r), r + 1
end

struct IterationCutShort; end

function iterate(itr::PartitionIterator, state...)
    # This is necessary to remember whether we cut the
    # last element short. In such cases, we do return that
    # element, but not the next one
    state === (IterationCutShort(),) && return nothing
    v = Vector{eltype(itr.c)}(undef, itr.n)
    i = 0
    y = iterate(itr.c, state...)
    while y !== nothing
        i += 1
        v[i] = y[1]
        if i >= itr.n
            break
        end
        y = iterate(itr.c, y[2])
    end
    i === 0 && return nothing
    return resize!(v, i), y === nothing ? IterationCutShort() : y[2]
end

@doc """
    Stateful(itr)

There are several different ways to think about this iterator wrapper:

1. It provides a mutable wrapper around an iterator and
   its iteration state.
2. It turns an iterator-like abstraction into a `Channel`-like
   abstraction.
3. It's an iterator that mutates to become its own rest iterator
   whenever an item is produced.

`Stateful` provides the regular iterator interface. Like other mutable iterators
(e.g. [`Base.Channel`](@ref)), if iteration is stopped early (e.g. by a [`break`](@ref) in a [`for`](@ref) loop),
iteration can be resumed from the same spot by continuing to iterate over the
same iterator object (in contrast, an immutable iterator would restart from the
beginning).

# Examples
```jldoctest
julia> a = Iterators.Stateful("abcdef");

julia> isempty(a)
false

julia> popfirst!(a)
'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)

julia> collect(Iterators.take(a, 3))
3-element Vector{Char}:
 'b': ASCII/Unicode U+0062 (category Ll: Letter, lowercase)
 'c': ASCII/Unicode U+0063 (category Ll: Letter, lowercase)
 'd': ASCII/Unicode U+0064 (category Ll: Letter, lowercase)

julia> collect(a)
2-element Vector{Char}:
 'e': ASCII/Unicode U+0065 (category Ll: Letter, lowercase)
 'f': ASCII/Unicode U+0066 (category Ll: Letter, lowercase)

julia> Iterators.reset!(a); popfirst!(a)
'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)

julia> Iterators.reset!(a, "hello"); popfirst!(a)
'h': ASCII/Unicode U+0068 (category Ll: Letter, lowercase)
```

```jldoctest
julia> a = Iterators.Stateful([1,1,1,2,3,4]);

julia> for x in a; x == 1 || break; end

julia> peek(a)
3

julia> sum(a) # Sum the remaining elements
7
```
"""
mutable struct Stateful{T, VS}
    itr::T
    # A bit awkward right now, but adapted to the new iteration protocol
    nextvalstate::Union{VS, Nothing}
    @inline function Stateful{<:Any, Any}(itr::T) where {T}
        return new{T, Any}(itr, iterate(itr))
    end
    @inline function Stateful(itr::T) where {T}
        VS = approx_iter_type(T)
        return new{T, VS}(itr, iterate(itr)::VS)
    end
end

function reset!(s::Stateful)
    setfield!(s, :nextvalstate, iterate(s.itr)) # bypass convert call of setproperty!
    return s
end
function reset!(s::Stateful{T}, itr::T) where {T}
    s.itr = itr
    reset!(s)
    return s
end


# Try to find an appropriate type for the (value, state tuple),
# by doing a recursive unrolling of the iteration protocol up to
# fixpoint.
approx_iter_type(itrT::Type) = _approx_iter_type(itrT, Base._return_type(iterate, Tuple{itrT}))
# Not actually called, just passed to return type to avoid
# having to typesplit on Nothing
function doiterate(itr, valstate::Union{Nothing, Tuple{Any, Any}})
    valstate === nothing && return nothing
    val, st = valstate
    return iterate(itr, st)
end
function _approx_iter_type(itrT::Type, vstate::Type)
    vstate <: Union{Nothing, Tuple{Any, Any}} || return Any
    vstate <: Union{} && return Union{}
    itrT <: Union{} && return Union{}
    nextvstate = Base._return_type(doiterate, Tuple{itrT, vstate})
    return (nextvstate <: vstate ? vstate : Any)
end

Stateful(x::Stateful) = x
convert(::Type{Stateful}, itr) = Stateful(itr)
@inline isdone(s::Stateful, st=nothing) = s.nextvalstate === nothing

@inline function popfirst!(s::Stateful)
    vs = s.nextvalstate
    if vs === nothing
        throw(Base.EOFError())
    else
        val, state = vs
        Core.setfield!(s, :nextvalstate, iterate(s.itr, state))
        return val
    end
end

@inline function peek(s::Stateful, sentinel=nothing)
    ns = s.nextvalstate
    return ns !== nothing ? ns[1] : sentinel
end
@inline iterate(s::Stateful, state=nothing) = s.nextvalstate === nothing ? nothing : (popfirst!(s), nothing)
IteratorSize(::Type{<:Stateful{T}}) where {T} = IteratorSize(T) isa IsInfinite ? IsInfinite() : SizeUnknown()
eltype(::Type{<:Stateful{T}}) where {T} = eltype(T)
IteratorEltype(::Type{<:Stateful{T}}) where {T} = IteratorEltype(T)

"""
    only(x)

Return the one and only element of collection `x`, or throw an [`ArgumentError`](@ref) if the
collection has zero or multiple elements.

See also [`first`](@ref), [`last`](@ref).

!!! compat "Julia 1.4"
    This method requires at least Julia 1.4.

# Examples
```jldoctest
julia> only(["a"])
"a"

julia> only("a")
'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)

julia> only(())
ERROR: ArgumentError: Tuple contains 0 elements, must contain exactly 1 element
Stacktrace:
[...]

julia> only(('a', 'b'))
ERROR: ArgumentError: Tuple contains 2 elements, must contain exactly 1 element
Stacktrace:
[...]
```
"""
@propagate_inbounds only(x) = _only(x, iterate)

@propagate_inbounds function _only(x, ::typeof(iterate))
    i = iterate(x)
    @boundscheck if i === nothing
        throw(ArgumentError("Collection is empty, must contain exactly 1 element"))
    end
    (ret, state) = i::NTuple{2,Any}
    @boundscheck if iterate(x, state) !== nothing
        throw(ArgumentError("Collection has multiple elements, must contain exactly 1 element"))
    end
    return ret
end

@inline function _only(x, ::typeof(first))
    @boundscheck if length(x) != 1
        throw(ArgumentError("Collection must contain exactly 1 element"))
    end
    @inbounds first(x)
end

@propagate_inbounds only(x::IdDict) = _only(x, first)

# Specific error messages for tuples and named tuples
only(x::Tuple{Any}) = x[1]
only(x::Tuple) = throw(
    ArgumentError("Tuple contains $(length(x)) elements, must contain exactly 1 element")
)
only(x::NamedTuple{<:Any, <:Tuple{Any}}) = first(x)
only(x::NamedTuple) = throw(
    ArgumentError("NamedTuple contains $(length(x)) elements, must contain exactly 1 element")
)

"""
    IterableStatePairs(x)

This internal type is returned by [`pairs`](@ref), when the key is the same as
the state of `iterate`. This allows the iterator to determine the key => value
pairs by only calling iterate on the values.

"""
struct IterableStatePairs{T}
    x::T
end

IteratorSize(::Type{<:IterableStatePairs{T}}) where T = IteratorSize(T)
length(x::IterableStatePairs) = length(x.x)
Base.eltype(::Type{IterableStatePairs{T}}) where T = Pair{<:Any, eltype(T)}

function iterate(x::IterableStatePairs, state=first(keys(x.x)))
    it = iterate(x.x, state)
    it === nothing && return nothing
    (state => first(it), last(it))
end

reverse(x::IterableStatePairs) = IterableStatePairs(Iterators.reverse(x.x))
reverse(x::IterableStatePairs{<:Iterators.Reverse}) = IterableStatePairs(x.x.itr)

function iterate(x::IterableStatePairs{<:Iterators.Reverse}, state=last(keys(x.x.itr)))
    it = iterate(x.x, state)
    it === nothing && return nothing
    (state => first(it), last(it))
end

# According to the docs of iterate(::AbstractString), the iteration state must
# be the same as the keys, so this is a valid optimization (see #51631)
pairs(s::AbstractString) = IterableStatePairs(s)

"""
    nth(itr, n::Integer)

Get the `n`th element of an iterable collection. Throw a `BoundsError`[@ref] if not existing.
Will advance any `Stateful`[@ref] iterator.

See also: [`first`](@ref), [`last`](@ref)

# Examples
```jldoctest
julia> Iterators.nth(2:2:10, 4)
8

julia> Iterators.nth(reshape(1:30, (5,6)), 6)
6

julia> stateful = Iterators.Stateful(1:10); Iterators.nth(stateful, 7)
7

julia> first(stateful)
8
```
"""
nth(itr, n::Integer) = _nth(IteratorSize(itr), itr, n)
nth(itr::Cycle{I}, n::Integer) where I = _nth(IteratorSize(I), itr, n)
nth(itr::Flatten{Take{Repeated{O}}}, n::Integer) where O = _nth(IteratorSize(O), itr, n)
@propagate_inbounds nth(itr::AbstractArray, n::Integer) = itr[begin + n - 1]

function _nth(::Union{HasShape, HasLength}, itr::Cycle{I}, n::Integer) where {I}
    N = length(itr.xs)
    N == 0 && throw(BoundsError(itr, n))

    # prevents wrap around behaviour and inherit the error handling
    return nth(itr.xs, n > 0 ? mod1(n, N) : n)
end

# Flatten{Take{Repeated{O}}} is the actual type of an Iterators.cycle(iterable::O, m) iterator
function _nth(::Union{HasShape, HasLength}, itr::Flatten{Take{Repeated{O}}}, n::Integer) where {O}
    cycles = itr.it.n
    torepeat = itr.it.xs.x
    k = length(torepeat)
    (n > k*cycles || k == 0) && throw(BoundsError(itr, n))

    # prevent wrap around behaviour and inherit the error handling
    return nth(torepeat, n > 0 ? mod1(n, k) : n)
end

function _nth(::IteratorSize, itr, n::Integer)
    # unrolled version of `first(drop)`
    n > 0 || throw(BoundsError(itr, n))
    y = iterate(itr)
    for _ in 1:n-1
        y === nothing && break
        y = iterate(itr, y[2])
    end
    y === nothing && throw(BoundsError(itr, n))
    y[1]
end
"""
    nth(n::Integer)

Return a function that gets the `n`-th element from any iterator passed to it.
Equivalent to `Base.Fix2(nth, n)` or `itr -> nth(itr, n)`.

See also: [`nth`](@ref), [`Base.Fix2`](@ref)
# Examples
```jldoctest
julia> fifth_element = Iterators.nth(5)
(::Base.Fix2{typeof(Base.Iterators.nth), Int64}) (generic function with 2 methods)

julia> fifth_element(reshape(1:30, (5,6)))
5

julia> map(fifth_element, ("Willis", "Jovovich", "Oldman"))
('i', 'v', 'a')
```
"""
nth(n::Integer) = Base.Fix2(nth, n)

end
