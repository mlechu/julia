# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
    showerror(io, e)

Show a descriptive representation of an exception object `e`.
This method is used to display the exception after a call to [`throw`](@ref).

# Examples
```jldoctest
julia> struct MyException <: Exception
           msg::String
       end

julia> function Base.showerror(io::IO, err::MyException)
           print(io, "MyException: ")
           print(io, err.msg)
       end

julia> err = MyException("test exception")
MyException("test exception")

julia> sprint(showerror, err)
"MyException: test exception"

julia> throw(MyException("test exception"))
ERROR: MyException: test exception
```
"""
showerror(io::IO, ex) = show(io, ex)

show_index(io::IO, x::Any) = show(io, x)
show_index(io::IO, x::Slice) = show_index(io, x.indices)
show_index(io::IO, x::LogicalIndex) = summary(io, x.mask)
show_index(io::IO, x::OneTo) = print(io, "1:", x.stop)
show_index(io::IO, x::Colon) = print(io, ':')

function showerror(io::IO, ex::Meta.ParseError)
    if isnothing(ex.detail)
        print(io, "ParseError(", repr(ex.msg), ")")
    else
        showerror(io, ex.detail)
    end
end

function showerror(io::IO, ex::Core.TypeNameError)
    print(io, "TypeNameError: ")
    if isa(ex.a, Union)
        print(io, "typename does not apply to unions whose components have different typenames")
    else
        print(io, "typename does not apply to this type")
    end
end

function showerror(io::IO, ex::BoundsError)
    print(io, "BoundsError")
    if isdefined(ex, :a)
        print(io, ": attempt to access ")
        summary(io, ex.a)
        if isdefined(ex, :i)
            print(io, " at index [")
            if ex.i isa AbstractRange
                print(io, ex.i)
            elseif ex.i isa AbstractString
                show(io, ex.i)
            else
                for (i, x) in enumerate(ex.i)
                    i > 1 && print(io, ", ")
                    show_index(io, x)
                end
            end
            print(io, ']')
        end
    end
    Experimental.show_error_hints(io, ex)
end

function showerror(io::IO, ex::TypeError)
    print(io, "TypeError: ")
    if ex.expected === Bool
        print(io, "non-boolean (", typeof(ex.got), ") used in boolean context")
    elseif ex.func === :var"dict key"
        print(io, "$(limitrepr(ex.got)) is not a valid key for type $(ex.expected)")
    else
        if isvarargtype(ex.got)
            targs = (ex.got,)
        elseif isa(ex.got, Type)
            targs = ("Type{", ex.got, "}")
        else
            targs = ("a value of type $(typeof(ex.got))",)
        end
        if ex.context == ""
            ctx = "in $(ex.func)"
        elseif ex.func === :var"keyword argument"
            ctx = "in keyword argument $(ex.context)"
        else
            ctx = "in $(ex.func), in $(ex.context)"
        end
        print(io, ctx, ", expected ", ex.expected, ", got ", targs...)
    end
    Experimental.show_error_hints(io, ex)
end

function showerror(io::IO, ex, bt; backtrace=true)
    try
        showerror(io, ex)
    finally
        backtrace && show_backtrace(io, bt)
    end
end

function showerror(io::IO, ex::LoadError, bt; backtrace=true)
    !isa(ex.error, LoadError) && print(io, "LoadError: ")
    showerror(io, ex.error, bt, backtrace=backtrace)
    print(io, "\nin expression starting at $(ex.file):$(ex.line)")
end
showerror(io::IO, ex::LoadError) = showerror(io, ex, [])

function showerror(io::IO, ex::InitError, bt; backtrace=true)
    print(io, "InitError: ")
    showerror(io, ex.error, bt, backtrace=backtrace)
    print(io, "\nduring initialization of module ", ex.mod)
end
showerror(io::IO, ex::InitError) = showerror(io, ex, [])

function showerror(io::IO, ex::DomainError)
    if isa(ex.val, AbstractArray)
        compact = get(io, :compact, true)::Bool
        limit = get(io, :limit, true)::Bool
        print(IOContext(io, :compact => compact, :limit => limit),
              "DomainError with ", ex.val)
    else
        print(io, "DomainError with ", ex.val)
    end
    if isdefined(ex, :msg)
        print(io, ":\n", ex.msg)
    end
    Experimental.show_error_hints(io, ex)
    nothing
end

function showerror(io::IO, ex::SystemError)
    if @static(Sys.iswindows() ? ex.extrainfo isa WindowsErrorInfo : false)
        errstring = Libc.FormatMessage(ex.extrainfo.errnum)
        extrainfo = ex.extrainfo.extrainfo
    else
        errstring = Libc.strerror(ex.errnum)
        extrainfo = ex.extrainfo
    end
    if extrainfo === nothing
        print(io, "SystemError: $(ex.prefix): ", errstring)
    else
        print(io, "SystemError (with $extrainfo): $(ex.prefix): ", errstring)
    end
end

showerror(io::IO, ::DivideError) = print(io, "DivideError: integer division error")
showerror(io::IO, ::StackOverflowError) = print(io, "StackOverflowError:")
showerror(io::IO, ::UndefRefError) = print(io, "UndefRefError: access to undefined reference")
showerror(io::IO, ::EOFError) = print(io, "EOFError: read end of file")
showerror(io::IO, ex::ErrorException) = print(io, ex.msg)
showerror(io::IO, ex::KeyError) = (print(io, "KeyError: key ");
                                   show(io, ex.key);
                                   print(io, " not found"))
showerror(io::IO, ex::InterruptException) = print(io, "InterruptException:")
showerror(io::IO, ex::ArgumentError) = print(io, "ArgumentError: ", ex.msg)
showerror(io::IO, ex::DimensionMismatch) = print(io, "DimensionMismatch: ", ex.msg)
showerror(io::IO, ex::AssertionError) = print(io, "AssertionError: ", ex.msg)
showerror(io::IO, ex::OverflowError) = print(io, "OverflowError: ", ex.msg)

showerror(io::IO, ex::UndefKeywordError) =
    print(io, "UndefKeywordError: keyword argument `$(ex.var)` not assigned")

function showerror(io::IO, ex::UndefVarError)
    print(io, "UndefVarError: `$(ex.var)` not defined")
    if isdefined(ex, :scope)
        scope = ex.scope
        if scope isa Module
            print(io, " in `$scope`")
        elseif scope === :static_parameter
            print(io, " in static parameter matching")
        else
            print(io, " in $scope scope")
        end
    end
    Experimental.show_error_hints(io, ex)
end

function showerror(io::IO, ex::InexactError)
    print(io, "InexactError: ", ex.func, '(')
    T = first(ex.args)
    nameof(T) === ex.func || print(io, T, ", ")
    # `join` calls `string` on its arguments, which shadows the size of e.g. Inf16
    # as `string(Inf16) == "Inf"` instead of "Inf16". Thus we cannot use `join` here.
    for arg in ex.args[2:end-1]
        show(io, arg)
        print(io, ", ")
    end
    show(io, ex.args[end])
    print(io, ")")
    Experimental.show_error_hints(io, ex)
end

function showerror(io::IO, ex::CanonicalIndexError)
    print(io, "CanonicalIndexError: ", ex.func, " not defined for ", ex.type)
end

typesof(@nospecialize args...) = Tuple{Any[Core.Typeof(arg) for arg in args]...}

function print_with_compare(io::IO, @nospecialize(a::DataType), @nospecialize(b::DataType), color::Symbol)
    if a.name === b.name
        Base.show_type_name(io, a.name)
        n = length(a.parameters)
        n > 0 || return
        print(io, '{')
        for i = 1:n
            if i > length(b.parameters)
                printstyled(io, a.parameters[i], color=color)
            else
                print_with_compare(io::IO, a.parameters[i], b.parameters[i], color)
            end
            i < n && print(io, ',')
        end
        print(io, '}')
    else
        printstyled(io, a; color=color)
    end
end

function print_with_compare(io::IO, @nospecialize(a), @nospecialize(b), color::Symbol)
    if a === b
        print(io, a)
    else
        printstyled(io, a; color=color)
    end
end

function show_convert_error(io::IO, ex::MethodError, arg_types_param)
    # See #13033
    T = striptype(ex.args[1])
    if T === nothing
        print(io, "First argument to `convert` must be a Type, got ", ex.args[1])
    else
        p2 = arg_types_param[2]
        print_one_line = isa(T, DataType) && isa(p2, DataType) && T.name != p2.name
        printstyled(io, "Cannot `convert` an object of type ")
        print_one_line || printstyled(io, "\n  ")
        print_with_compare(io, p2, T, :light_green)
        printstyled(io, " to an object of type ")
        print_one_line || printstyled(io, "\n  ")
        print_with_compare(io, T, p2, :light_red)
    end
end

function showerror(io::IO, ex::MethodError)
    @nospecialize io
    # ex.args is a tuple type if it was thrown from `invoke` and is
    # a tuple of the arguments otherwise.
    is_arg_types = !isa(ex.args, Tuple)
    arg_types = is_arg_types ? ex.args : typesof(ex.args...)
    arg_types_param::SimpleVector = (unwrap_unionall(arg_types)::DataType).parameters
    san_arg_types_param = Any[rewrap_unionall(a, arg_types) for a in arg_types_param]
    f = ex.f
    meth = methods_including_ambiguous(f, arg_types)
    if isa(meth, MethodList) && length(meth) > 1
        return showerror_ambiguous(io, meth, f, arg_types)
    end
    print(io, "MethodError: ")
    ft = typeof(f)
    f_is_function = false
    kwargs = []
    if f === Core.kwcall && length(arg_types_param) >= 2 && arg_types_param[1] <: NamedTuple && !is_arg_types
        # if this is a kwcall, reformat it as a call with kwargs
        # TODO: handle !is_arg_types here (aka invoke with kwargs), which needs a value for `f`
        local kwt
        let args = ex.args::Tuple
            f = args[2]
            ft = typeof(f)
            kwt = typeof(args[1])
            ex = MethodError(f, args[3:end], ex.world)
        end
        arg_types_param = arg_types_param[3:end]
        san_arg_types_param = san_arg_types_param[3:end]
        keys = kwt.parameters[1]::Tuple
        kwargs = Any[(keys[i], fieldtype(kwt, i)) for i in eachindex(keys)]
        arg_types = rewrap_unionall(Tuple{arg_types_param...}, arg_types)
    end
    if f === Base.convert && length(arg_types_param) == 2 && !is_arg_types
        f_is_function = true
        show_convert_error(io, ex, arg_types_param)
    elseif isempty(methods(f)) && isa(f, DataType) && isabstracttype(f)
        print(io, "no constructors have been defined for ", f)
    elseif isempty(methods(f)) && !isa(f, Function) && !isa(f, Type)
        println(io, "objects of type ", ft, " are not callable.")
        print(io, "In case you did not try calling it explicitly, check if a ", ft,
            " has been passed as an argument to a method that expects a callable instead.")
    else
        if ft <: Function && isempty(ft.parameters) && _isself(ft)
            f_is_function = true
        end
        if is_arg_types
            print(io, "no method matching invoke ")
        else
            print(io, "no method matching ")
        end
        buf = IOBuffer()
        iob = IOContext(buf, io)     # for type abbreviation as in #49795; some, like `convert(T, x)`, should not abbreviate
        show_signature_function(iob, Core.Typeof(f))
        show_tuple_as_call(iob, :function, arg_types; hasfirst=false, kwargs = isempty(kwargs) ? nothing : kwargs)
        str = takestring!(buf)
        str = type_limited_string_from_context(io, str)
        print(io, str)
    end
    # catch the two common cases of element-wise addition and subtraction
    if (f === Base.:+ || f === Base.:-) && length(san_arg_types_param) == 2
        # we need one array of numbers and one number, in any order
        if any(x -> x <: AbstractArray{<:Number}, san_arg_types_param) &&
            any(x -> x <: Number, san_arg_types_param)

            nounf = f === Base.:+ ? "addition" : "subtraction"
            varnames = ("scalar", "array")
            first, second = san_arg_types_param[1] <: Number ? varnames : reverse(varnames)
            fstring = f === Base.:+ ? "+" : "-"  # avoid depending on show_default for functions (invalidation)
            print(io, "\nFor element-wise $nounf, use broadcasting with dot syntax: $first .$fstring $second")
        end
    end
    if ft <: AbstractArray
        print(io, "\nIn case you're trying to index into the array, use square brackets [] instead of parentheses ().")
    end
    # Check for functions with the same name in other modules
    if f_is_function && ex.world != typemax(UInt)
        let name = ft.name.singletonname
            modules_to_check = Set{Module}()
            push!(modules_to_check, Base)
            for T in san_arg_types_param
                modulesof!(modules_to_check, T)
            end

            # Check all modules (sorted for consistency)
            sorted_modules = sort!(collect(modules_to_check), by=nameof)
            for mod in sorted_modules
                if isdefinedglobal(mod, name)
                    candidate = getglobal(mod, name)
                    if candidate !== f && hasmethod(candidate, arg_types; world=ex.world)
                        if mod === Base
                            print(io, "\nYou may have intended to import ")
                            show_unquoted(io, Expr(:., :Base, QuoteNode(name)))
                        else
                            print(io, "\nThe definition in ")
                            show_unquoted(io, mod)
                            print(io, " may have intended to extend ")
                            f_module = parentmodule(ft)
                            show_unquoted(io, Expr(:., f_module, QuoteNode(name)))
                        end
                    end
                end
            end
        end
    end
    if ex.world == typemax(UInt) || hasmethod(f, arg_types, world=ex.world)
        if !isempty(kwargs)
            print(io, "\nThis method does not support all of the given keyword arguments (and may not support any).")
        end
        if ex.world == typemax(UInt) || isempty(kwargs)
            print(io, "\nThis error has been manually thrown, explicitly, so the method may exist but be intentionally marked as unimplemented.")
        end
    elseif hasmethod(f, arg_types) && !hasmethod(f, arg_types, world=ex.world)
        curworld = get_world_counter()
        print(io, "\nThe applicable method may be too new: running in world age $(ex.world), while current world is $(curworld).")
    elseif f isa Function
        print(io, "\nThe ")
        isgensym(nameof(f)) && print(io, "anonymous ")
        print(io, "function `$f` exists, but no method is defined for this combination of argument types.")
    elseif f isa Type
        print(io, "\nThe type `$f` exists, but no method is defined for this combination of argument types when trying to construct it.")
    else
        print(io, "\nThe object of type `$(typeof(f))` exists, but no method is defined for this combination of argument types when trying to treat it as a callable object.")
    end
    if !is_arg_types
        # Check for row vectors used where a column vector is intended.
        vec_args = []
        hasrows = false
        for arg in ex.args
            isrow = isa(arg,Array) && ndims(arg)::Int==2 && size(arg,1)::Int==1
            hasrows |= isrow
            push!(vec_args, isrow ? vec(arg) : arg)
        end
        if hasrows && applicable(f, vec_args...) && isempty(kwargs)
            print(io, "\n\nYou might have used a 2d row vector where a 1d column vector was required.",
                      "\nNote the difference between 1d column vector [1,2,3] and 2d row vector [1 2 3].",
                      "\nYou can convert to a column vector with the vec() function.")
        end
    end
    Experimental.show_error_hints(io, ex, san_arg_types_param, kwargs)
    try
        show_method_candidates(io, ex, kwargs)
    catch ex
        @error "Error showing method candidates, aborted" exception=ex,catch_backtrace()
    end
    nothing
end

function showerror(io::IO, exc::FieldError)
    @nospecialize
    print(io, "FieldError: type $(exc.type.name.wrapper) has no field `$(exc.field)`")
    Base.Experimental.show_error_hints(io, exc)
end

striptype(::Type{T}) where {T} = T
striptype(::Any) = nothing

function showerror_ambiguous(io::IO, meths, f, args::Type)
    @nospecialize f args
    print(io, "MethodError: ")
    show_signature_function(io, isa(f, Type) ? Type{f} : typeof(f))
    show_tuple_as_call(io, :var"", args, hasfirst=false)
    println(io, " is ambiguous.\n\nCandidates:")
    sigfix = Any
    for m in meths
        print(io, "  ")
        show_method(io, m; digit_align_width=0)
        println(io)
        sigfix = typeintersect(m.sig, sigfix)
    end
    if isa(unwrap_unionall(sigfix), DataType) && sigfix <: Tuple
        let sigfix=sigfix
            if all(m->morespecific(sigfix, m.sig), meths)
                print(io, "\nPossible fix, define\n  ")
                show_tuple_as_call(io, :function,  sigfix)
            else
                print(io, "To resolve the ambiguity, try making one of the methods more specific, or ")
                print(io, "adding a new method more specific than any of the existing applicable methods.")
            end
        end
        println(io)
    end
    nothing
end

#Show an error by directly calling jl_printf.
#Useful in Base submodule __init__ functions where stderr isn't defined yet.
function showerror_nostdio(@nospecialize(err), msg::AbstractString)
    stderr_stream = ccall(:jl_stderr_stream, Ptr{Cvoid}, ())
    ccall(:jl_printf, Cint, (Ptr{Cvoid},Cstring), stderr_stream, msg)
    ccall(:jl_printf, Cint, (Ptr{Cvoid},Cstring), stderr_stream, ":\n")
    ccall(:jl_static_show, Csize_t, (Ptr{Cvoid},Any), stderr_stream, err)
    ccall(:jl_printf, Cint, (Ptr{Cvoid},Cstring), stderr_stream, "\n")
end

stacktrace_expand_basepaths()::Bool = Base.get_bool_env("JULIA_STACKTRACE_EXPAND_BASEPATHS", false) === true
stacktrace_contract_userdir()::Bool = Base.get_bool_env("JULIA_STACKTRACE_CONTRACT_HOMEDIR", true) === true
stacktrace_linebreaks()::Bool = Base.get_bool_env("JULIA_STACKTRACE_LINEBREAKS", false) === true

function show_method_candidates(io::IO, ex::MethodError, kwargs=[])
    @nospecialize io
    is_arg_types = !isa(ex.args, Tuple)
    arg_types = is_arg_types ? ex.args : typesof(ex.args...)
    arg_types_param = Any[(unwrap_unionall(arg_types)::DataType).parameters...]
    arg_types_param = Any[rewrap_unionall(a, arg_types) for a in arg_types_param]
    # Displays the closest candidates of the given function by looping over the
    # functions methods and counting the number of matching arguments.
    f = ex.f
    ft = typeof(f)
    lines = String[]
    line_score = Int[]
    # These functions are special cased to only show if first argument is matched.
    special = f === convert || f === getindex || f === setindex!
    f isa Core.Builtin && return # `methods` isn't very useful for a builtin
    funcs = Tuple{Any,Vector{Any}}[(f, arg_types_param)]

    # An incorrect call method produces a MethodError for convert.
    # It also happens that users type convert when they mean call. So
    # pool MethodErrors for these two functions.
    if f === convert && !isempty(arg_types_param)
        at1 = arg_types_param[1]
        if isType(at1) && !has_free_typevars(at1) && at1.parameters[1] isa Type
            push!(funcs, (at1.parameters[1], arg_types_param[2:end]))
        end
    end

    for (func, arg_types_param) in funcs
        for method in methods(func)
            buf = IOBuffer()
            iob0 = iob = IOContext(buf, io)
            tv = Any[]
            if func isa Core.OpaqueClosure
                sig0 = signature_type(func, typeof(func).parameters[1])
            else
                sig0 = method.sig
            end
            while isa(sig0, UnionAll)
                push!(tv, sig0.var)
                iob = IOContext(iob, :unionall_env => sig0.var)
                sig0 = sig0.body
            end
            sig0 = sig0::DataType
            s1 = sig0.parameters[1]
            if !isa(func, rewrap_unionall(s1, method.sig))
                # function itself doesn't match
                continue
            else
                print(iob, "  ")
                show_signature_function(iob, s1)
            end
            print(iob, "(")
            t_i = copy(arg_types_param)
            right_matches = 0
            sig = sig0.parameters[2:end]
            for i = 1 : min(length(t_i), length(sig))
                i > 1 && print(iob, ", ")
                # If isvarargtype then it checks whether the rest of the input arguments matches
                # the varargtype
                if Base.isvarargtype(sig[i])
                    sigstr = (unwrapva(unwrap_unionall(sig[i])), "...")
                    j = length(t_i)
                else
                    sigstr = (sig[i],)
                    j = i
                end
                # Checks if the type of arg 1:i of the input intersects with the current method
                t_in = typeintersect(rewrap_unionall(Tuple{sig[1:i]...}, method.sig),
                                     rewrap_unionall(Tuple{t_i[1:j]...}, method.sig))
                # If the function is one of the special cased then it should break the loop if
                # the type of the first argument is not matched.
                t_in === Union{} && special && i == 1 && break
                if t_in === Union{}
                    if get(io, :color, false)::Bool
                        let sigstr=sigstr
                            Base.with_output_color(Base.error_color(), iob) do iob
                                print(iob, "::", sigstr...)
                            end
                        end
                    else
                        print(iob, "!Matched::", sigstr...)
                    end
                    # If there is no typeintersect then the type signature from the method is
                    # inserted in t_i this ensures if the type at the next i matches the type
                    # signature then there will be a type intersect
                    t_i[i] = sig[i]
                else
                    right_matches += j==i ? 1 : 0
                    print(iob, "::", sigstr...)
                end
            end
            special && right_matches == 0 && continue

            if length(t_i) > length(sig) && !isempty(sig) && Base.isvarargtype(sig[end])
                # It ensures that methods like f(a::AbstractString...) gets the correct
                # number of right_matches
                for t in arg_types_param[length(sig):end]
                    if t <: rewrap_unionall(unwrapva(unwrap_unionall(sig[end])), method.sig)
                        right_matches += 1
                    end
                end
            end

            if length(t_i) < length(sig)
                # If the methods args is longer than input then the method
                # arguments is printed as not a match
                for (k, sigtype) in enumerate(sig[length(t_i)+1:end])
                    sigtype = isvarargtype(sigtype) ? unwrap_unionall(sigtype) : sigtype
                    if Base.isvarargtype(sigtype)
                        sigstr = (unwrapva(sigtype::Core.TypeofVararg), "...")
                    else
                        sigstr = (sigtype,)
                    end
                    if !((min(length(t_i), length(sig)) == 0) && k==1)
                        print(iob, ", ")
                    end
                    if k == 1 && Base.isvarargtype(sigtype)
                        # There wasn't actually a mismatch - the method match failed for
                        # some other reason, e.g. world age. Just print the sigstr.
                        print(iob, sigstr...)
                    elseif get(io, :color, false)::Bool
                        let sigstr=sigstr
                            Base.with_output_color(Base.error_color(), iob) do iob
                                print(iob, "::", sigstr...)
                            end
                        end
                    else
                        print(iob, "!Matched::", sigstr...)
                    end
                end
            end
            kwords = kwarg_decl(method)
            if !isempty(kwords)
                print(iob, "; ")
                join(iob, kwords, ", ")
            end
            print(iob, ")")
            show_method_params(iob0, tv)
            file, line = updated_methodloc(method)
            if file === nothing
                file = string(method.file)
            end
            stacktrace_contract_userdir() && (file = contractuser(file))

            if !isempty(kwargs)::Bool
                unexpected = Symbol[]
                if isempty(kwords) || !(any(endswith(string(kword), "...") for kword in kwords))
                    for (k, v) in kwargs
                        if !(k::Symbol in kwords)
                            push!(unexpected, k::Symbol)
                        end
                    end
                end
                if !isempty(unexpected)
                    Base.with_output_color(Base.error_color(), iob) do iob
                        plur = length(unexpected) > 1 ? "s" : ""
                        print(iob, " got unsupported keyword argument$plur \"", join(unexpected, "\", \""), "\"")
                    end
                end
            end
            if ex.world < reinterpret(UInt, method.primary_world)
                print(iob, " (method too new to be called from this world context.)")
            end
            println(iob)

            m = parentmodule_before_main(method)
            modulecolor = get!(() -> popfirst!(STACKTRACE_MODULECOLORS), STACKTRACE_FIXEDCOLORS, m)
            print_module_path_file(iob, m, string(file), line; modulecolor, digit_align_width = 3)
            push!(lines, takestring!(buf))
            push!(line_score, -(right_matches * 2 + (length(arg_types_param) < 2 ? 1 : 0)))
        end
    end

    if !isempty(lines) # Display up to three closest candidates
        Base.with_output_color(:normal, io) do io
            print(io, "\n\nClosest candidates are:")
            permute!(lines, sortperm(line_score))
            i = 0
            for line in lines
                println(io)
                if i >= 3
                    print(io, "  ...")
                    break
                end
                i += 1
                print(io, line)
            end
            println(io) # extra newline for spacing to stacktrace
        end
    end
    nothing
end

# In case the line numbers in the source code have changed since the code was compiled,
# allow packages to set a callback function that corrects them.
# (Used by Revise and perhaps other packages.)
#
# Set this with
#     Base.update_stackframes_callback[] = my_updater!
# where my_updater! takes a single argument and works in-place. The argument will be a
# Vector{Any} storing tuples (sf::StackFrame, nrepetitions::Int), and the updater should
# replace `sf` as needed.
const update_stackframes_callback = Ref{Function}(identity)

const STACKTRACE_MODULECOLORS = Iterators.Stateful(Iterators.cycle([:magenta, :cyan, :green, :yellow]))
const STACKTRACE_FIXEDCOLORS = IdDict(Base => :light_black, Core => :light_black)

const BIG_STACKTRACE_SIZE = 50 # Arbitrary constant chosen here

function _backtrace_find_and_remove_cycles(t)
    recorded_positions = IdDict{UInt, Vector{Int}}()
    #= For each frame of hash h, recorded_positions[h] is the list of indices i
    such that hash(t[i-1]) == h, ie the list of positions in which the
    frame appears just before. =#

    max_nested_cycles = 0
    displayed_stackframes = []
    repeated_cycles = Tuple{Int,Int,Int}[]
    # First:  index into `display_stackframes` to introuce the cycle bracket on
    # Second: length of the cycle as a count in the trace
    # Third:  number of cycle repetitions

    t_curr = 1
    frame_counter = 1

    while t_curr ≤ length(t)
        (last_frame, n) = t[t_curr]
        current_hash = hash(t[t_curr])
        positions = get(recorded_positions, current_hash,  Int[])

        t_curr += 1
        recorded_positions[current_hash] = push!(positions, t_curr)

        # Check previous positions for cycles
        ncycles = 0
        nnested_cycles = n > 0
        for k ∈ reverse(eachindex(positions))[2:end] # More recent is more likely
            t_prev = positions[k]
            t_cycle_length = t_curr - t_prev

            # walk trace at current and previous matching positions until matching stops
            t_curr_end = t_curr
            t_prev_end = t_prev
            while t_curr_end < length(t) && t[t_curr_end] == t[t_prev_end]
                t_curr_end += 1
                t_prev_end += 1
            end

            if t_prev_end ≥ t_curr - 1
                #= At least one cycle repeated =#
                ncycles = div(t_curr_end - t_prev + 1, t_cycle_length)
                push!(repeated_cycles, (length(displayed_stackframes) - 1, t_cycle_length, ncycles))
                t_curr += t_cycle_length * (ncycles - 1) - 1
                nnested_cycles += 1
            end
        end

        # ensure an outer cycle comes before a contained inner cycle
        sort!(repeated_cycles, by = x -> (x[1], -x[2]))
        max_nested_cycles = max(max_nested_cycles, nnested_cycles)

        if ncycles == 0
            push!(displayed_stackframes, (last_frame, n))
        end
    end
    return displayed_stackframes, repeated_cycles, max_nested_cycles
end

function _backtrace_print_repetition_closings!(io::IO, i, current_cycles, frame_counter, max_nested_cycles, nactive_cycles, ndigits_max; prefix = nothing)
    while !isempty(current_cycles)
        start_line = current_cycles[end][1]
        cycle_length = current_cycles[end][2]
        end_line = start_line + cycle_length - 1
        repetitions = current_cycles[end][3]
        frame_counter_advance = current_cycles[end][4]

        i != end_line && break

        println(io)
        prefix === nothing || print(io, prefix)
        line_length = (max_nested_cycles - nactive_cycles) + ndigits_max + 2
        nactive_cycles -= 1
        printstyled(io, " ", "│" ^ nactive_cycles, "╰", "─" ^ (line_length); color = :light_black)
        printstyled(io, " repeated $repetitions times"; color = :light_black, italic = true)

        pop!(current_cycles)

        if cycle_length > 1
            # adjust cycle_length in outer cycles to reflect displayed frames consumed by this inner cycle
            for j ∈ eachindex(current_cycles)
                current_cycles[j] = (current_cycles[j][1], current_cycles[j][2] - cycle_length * (repetitions - 1), current_cycles[j][3:4]...)
            end
        else
            # adjust frame_counter_advance in outer cycles to reflect frames consumed by a single repeated frame
            for j ∈ eachindex(current_cycles)
                current_cycles[j] = (current_cycles[j][1:3]..., current_cycles[j][4] + (frame_counter_advance * (current_cycles[j][3] - 1)))
            end
        end

        frame_counter += frame_counter_advance
    end
    return frame_counter, nactive_cycles
end

function show_processed_backtrace(io::IO, trace::Vector, num_frames::Int, repeated_cycles::Vector{NTuple{3, Int}}, max_nested_cycles::Int; print_linebreaks::Bool, prefix = nothing)
    println(io)
    prefix === nothing || print(io, prefix)
    println(io, "Stacktrace:")

    ndigits_max = ndigits(num_frames)

    push!(repeated_cycles, (0,0,0)) # repeated_cycles is never empty

    frame_counter = 1
    current_cycles = NTuple{4, Int}[] # adding a value to track amount to advance frame_counter when cycle is closed

    for i in eachindex(trace)
        (frame, n) = trace[i]

        ncycle_starts = 0
        while repeated_cycles[1][1] == i
            cycle = popfirst!(repeated_cycles)
            push!(current_cycles, (cycle..., cycle[2] * (cycle[3] - 1)))
            ncycle_starts += 1
        end
        if n > 1
            push!(current_cycles, (i, 1, n, n - 1))
            ncycle_starts += 1
        end
        nactive_cycles = length(current_cycles)

        print_stackframe(io, frame_counter, frame, ndigits_max, max_nested_cycles, nactive_cycles, ncycle_starts, STACKTRACE_FIXEDCOLORS, STACKTRACE_MODULECOLORS; prefix)

        frame_counter, nactive_cycles = _backtrace_print_repetition_closings!(io, i, current_cycles, frame_counter, max_nested_cycles, nactive_cycles, ndigits_max; prefix)
        frame_counter += 1

        if i < length(trace)
            println(io)
            print_linebreaks && println(io)
        end
    end
end

# Print a stack frame where the module color is determined by looking up the parent module in
# `modulecolordict`. If the module does not have a color, yet, a new one can be drawn
# from `modulecolorcycler`.
function print_stackframe(io, i, frame::StackFrame, ndigits_max::Int, max_nested_cycles::Int, nactive_cycles::Int, ncycle_starts::Int, modulecolordict, modulecolorcycler; prefix = nothing)
    m = Base.parentmodule(frame)
    modulecolor = if m !== nothing
        m = parentmodule_before_main(m)
        get!(() -> popfirst!(modulecolorcycler), modulecolordict, m)
    else
        :default
    end
    print_stackframe(io, i, frame, ndigits_max, max_nested_cycles, nactive_cycles, ncycle_starts, modulecolor; prefix)
end

# Gets the topmost parent module that isn't Main
function parentmodule_before_main(m::Module)
    while parentmodule(m) !== m
        pm = parentmodule(m)
        pm == Main && break
        m = pm
    end
    m
end
parentmodule_before_main(x) = parentmodule_before_main(parentmodule(x))

# Print a stack frame where the module color is set manually with `modulecolor`.
function print_stackframe(io, i, frame::StackFrame, ndigits_max::Int, max_nested_cycles::Int, nactive_cycles::Int, ncycle_starts::Int, modulecolor; prefix = nothing)
    file, line = string(frame.file), frame.line

    # Used by the REPL to make it possible to open
    # the location of a stackframe/method in the editor.
    if haskey(io, :last_shown_line_infos)
        push!(io[:last_shown_line_infos], (string(frame.file), frame.line))
    end

    inlined = getfield(frame, :inlined)
    modul = parentmodule(frame)

    digit_align_width = ndigits_max + 2 + max_nested_cycles - nactive_cycles

    # repeated section bracket line 1
    prefix === nothing || print(io, prefix)
    print(io, " ")
    printstyled(io, "├" ^ (nactive_cycles - ncycle_starts); color = :light_black)
    printstyled(io, "┌" ^ ncycle_starts; color = :light_black)

    # frame number
    print(io, lpad("[" * string(i) * "]", digit_align_width))
    print(io, " ")

    # func name and arguments
    StackTraces.show_spec_linfo(IOContext(io, :backtrace=>true), frame)
    println(io)

    # repeated section bracket line 2
    prefix === nothing || print(io, prefix)
    print(io, " ")
    printstyled(io, "│" ^ nactive_cycles; color = :light_black)

    # @ Module path / file : line
    print_module_path_file(io, modul, file, line; modulecolor, digit_align_width = digit_align_width - 1)

    # inlined
    printstyled(io, inlined ? " [inlined]" : "", color = :light_black)
end

function print_module_path_file(io, modul, file, line; modulecolor = :light_black, digit_align_width = 0)
    printstyled(io, " " ^ digit_align_width * "@", color = :light_black)

    # module
    if modul !== nothing && modulecolor !== nothing
        print(io, " ")
        printstyled(io, modul, color = modulecolor)
    end

    # filepath
    file = fixup_stdlib_path(file)
    stacktrace_expand_basepaths() && (file = something(find_source_file(file), file))
    stacktrace_contract_userdir() && (file = contractuser(file))
    print(io, " ")
    dir = dirname(file)
    !isempty(dir) && printstyled(io, dir, Filesystem.path_separator, color = :light_black)

    # filename, separator, line
    printstyled(io, basename(file), ":", line; color = :light_black, underline = true)
end

#=

Stacktrace processing pipeline:
1. Raw traces extracted with `backtrace` or `catch_backtrace` as vector of instruction pointers.
2. IP traces converted to frames with `stacktrace`, which may or may not include C frames.
3. Originator trims frames related to itself (e.g. REPL removes REPL-specific frames)
   - CapturedException only keeps a limit of 100 frames by processing before display
4. `process_backtrace` filters a trace for internal implementation or redundant frames and summarizes repeated single frames:
    - `kwcall` frames removed
    - `include`-related stack frames removed
    - Some frames that have the same location info are merged
    - Repeated frames are removed and summarized with a count
    - Output is an Any[] containing (StackFrame, count) tuple elements and this form is exposed to e.g. Revise
5. If a trace is too long, cycles are identified and summarized
6. `update_stackframes_callback[]` provides e.g. Revise an opportunity to edit line info

=#

function show_backtrace(io::IO, t::Vector; prefix = nothing)
    if haskey(io, :last_shown_line_infos)
        empty!(io[:last_shown_line_infos])
    end

    # Process backtrace if it has not yet been. A processed backtrace is a Vector{Any}
    # with elements of type Tuple{StackFrame, Int}. (ref #12856)
    if t isa Vector{Any} && (length(t) == 0 || t[1] isa Tuple{StackFrame,Int})
        filtered = t
    else
        # t is a raw trace requiring lookup
        if t isa Vector{<:Union{Base.InterpreterIP,Ptr{Cvoid}}}
            frametrace = stacktrace(t)
        else
            frametrace = t
        end
        filtered = process_backtrace(frametrace)
    end
    isempty(filtered) && return

    nframes = sum(last(x) for x ∈ filtered)

    # don't show a single top-level frame with no location info
    if nframes == 1 && StackTraces.is_top_level_frame(filtered[1][1])
        f = filtered[1][1]::StackFrame
        if f.line == 0 && f.file === :var""
            return
        end
    end

    # Find repeated cycles if trace is too long
    if length(filtered) > BIG_STACKTRACE_SIZE
        filtered, repeated_cycles, max_nested_cycles = _backtrace_find_and_remove_cycles(filtered)
    else
        repeated_cycles = NTuple{3, Int}[]
        max_nested_cycles = any(x -> last(x) > 1, filtered) ? 1 : 0
    end

    # Allow external code to edit information in the frames (e.g. line numbers with Revise)
    try invokelatest(update_stackframes_callback[], filtered) catch end

    show_processed_backtrace(IOContext(io, :backtrace => true), filtered, nframes, repeated_cycles, max_nested_cycles; print_linebreaks = stacktrace_linebreaks(), prefix)
    nothing
end

function _backtrace_collapse_and_count_repeated_frames(frames::Vector{StackFrame})
    n = 0
    last_frame = StackTraces.UNKNOWN
    tracecount = Any[]
    for frame in frames
        if frame.file != last_frame.file || frame.line != last_frame.line || frame.func != last_frame.func || frame.linfo !== last_frame.linfo
            if n > 0
                push!(tracecount, (last_frame, n))
            end
            n = 1
            last_frame = frame
        else
            n += 1
        end
    end
    if n > 0
        push!(tracecount, (last_frame, n))
    end
    return tracecount
end

function _backtrace_remove_kwcall_frames!(trace)
    todelete = findall(trace) do (frame, _)
        code = frame.linfo
        if code isa MethodInstance
            def = code.def
            if def isa Method && def.name !== :kwcall && def.sig <: Tuple{typeof(Core.kwcall),NamedTuple,Any,Vararg}
                # hide kwcall() methods, which are probably internal keyword sorter methods
                # (we print the internal method instead, after demangling
                # the argument list, since it has the right line number info)
                return true
            end
        else
            frame.func === :kwcall && return true
        end
        return false
    end
    deleteat!(trace, todelete)
end

# For improved user experience, filter out frames for include() implementation
# - see #33065. See also #35371 for extended discussion of internal frames.
function _backtrace_simplify_include_frames!(trace)
    kept_frames = trues(length(trace))
    first_ignored = nothing
    for i in length(trace):-1:1
        frame::StackFrame, _ = trace[i]
        mod = parentmodule(frame)
        if mod === Base && frame.func === :IncludeInto ||
           mod === Core && frame.func === :EvalInto
            kept_frames[i] = false
        elseif first_ignored === nothing
            if mod === Base && frame.func === :_include
                # Hide include() machinery by default
                first_ignored = i
            end
        else
            first_ignored = first_ignored::Int
            # Hack: allow `mod==nothing` as a workaround for inlined functions.
            # TODO: Fix this by improving debug info.
            if mod in (Base,Core,nothing) && 1+first_ignored-i <= 5
                if frame.func === :eval
                    kept_frames[i:first_ignored] .= false
                    first_ignored = nothing
                end
            else
                # Bail out to avoid hiding frames in unexpected circumstances
                first_ignored = nothing
            end
        end
    end
    if first_ignored !== nothing
        kept_frames[1:first_ignored] .= false
    end
    keepat!(trace, kept_frames)
end

# Collapse frames that have the same location (in some cases)
function _backtrace_collapse_repeated_locations!(trace)
    kept_frames = trues(length(trace))
    last_frame = nothing
    for i in eachindex(trace)
        frame::StackFrame, _ = trace[i]
        if last_frame !== nothing && frame.file == last_frame.file && frame.line == last_frame.line
            #=
            Handles this case:

            f(g, a; kw...) = error();
            @inline f(a; kw...) = f(identity, a; kw...);
            f(1)

            which otherwise ends up as:

            [4] #f#4 <-- useless
            @ ./REPL[2]:1 [inlined]
            [5] f(a::Int64)
            @ Main ./REPL[2]:1
            =#
            if startswith(sprint(show, last_frame), "#")
                kept_frames[i-1] = false
            end

            #= Handles this case
            g(x, y=1, z=2) = error();
            g(1)

            which otherwise ends up as:

            [2] g(x::Int64, y::Int64, z::Int64)
            @ Main ./REPL[1]:1
            [3] g(x::Int64) <-- useless
            @ Main ./REPL[1]:1
            =#
            m, last_m = StackTraces.frame_method_or_module(frame),
                        StackTraces.frame_method_or_module(last_frame)
            if m isa Method && last_m isa Method
                params, last_params = Base.unwrap_unionall(m.sig).parameters::SimpleVector, Base.unwrap_unionall(last_m.sig).parameters::SimpleVector
                if last_m.nkw != 0
                    pos_sig_params = last_params[(last_m.nkw+2):end]
                    issame = true
                    if pos_sig_params == params
                        kept_frames[i] = false
                    end
                end
                if length(last_params) > length(params)
                    issame = true
                    for i = eachindex(params)
                        issame &= params[i] == last_params[i]
                    end
                    if issame
                        kept_frames[i] = false
                    end
                end
            end

            # TODO: Detect more cases that can be collapsed
        end
        last_frame = frame
    end
    keepat!(trace, kept_frames)
end

function process_backtrace(t::Vector{StackFrame})
    tracecount = _backtrace_collapse_and_count_repeated_frames(t)
    process_backtrace(tracecount)
end

function process_backtrace(tracecount::Vector{Any})
    _backtrace_remove_kwcall_frames!(tracecount)
    _backtrace_simplify_include_frames!(tracecount)
    _backtrace_collapse_repeated_locations!(tracecount)
    return tracecount
end

function show_exception_stack(io::IO, stack)
    # Display exception stack with the top of the stack first.  This ordering
    # means that the user doesn't have to scroll up in the REPL to discover the
    # root cause.
    nexc = length(stack)
    for i = nexc:-1:1
        if nexc != i
            printstyled(io, "\ncaused by: ", color=error_color())
        end
        exc, bt = stack[i]
        showerror(io, exc, bt, backtrace = bt!==nothing)
        i == 1 || println(io)
    end
end

# Defined here rather than error.jl for bootstrap ordering
function show(io::IO, ip::InterpreterIP)
    print(io, typeof(ip))
    if ip.code isa Core.CodeInfo
        print(io, " in top-level CodeInfo for $(ip.mod) at statement $(Int(ip.stmt))")
    else
        print(io, " in $(ip.code) at statement $(Int(ip.stmt))")
    end
end

# handler for displaying a hint in case the user tries to call
# the instance of a number (probably missing the operator)
# eg: (1 + 2)(3 + 4)
function noncallable_number_hint_handler(io, ex, arg_types, kwargs)
    @nospecialize
    if ex.f isa Number
        print(io, "\nMaybe you forgot to use an operator such as ")
        printstyled(io, "*, ^, %, / etc. ", color=:cyan)
        print(io, "?")
    end
end

Experimental.register_error_hint(noncallable_number_hint_handler, MethodError)

# handler for displaying a hint in case the user tries to call setindex! on
# something that doesn't support it:
#  - a number (probably attempting to use wrong indexing)
#    eg: a = [1 2; 3 4]; a[1][2] = 5
#  - a type (probably tried to initialize without parentheses)
#    eg: d = Dict; d["key"] = 2
function nonsetable_type_hint_handler(io, ex, arg_types, kwargs)
    @nospecialize
    if ex.f === setindex!
        T = arg_types[1]
        if T <: Number
            print(io, "\nAre you trying to index into an array? For multi-dimensional arrays, separate the indices with commas: ")
            printstyled(io, "a[1, 2]", color=:cyan)
            print(io, " rather than a[1][2]")
        elseif isType(T)
            Tx = T.parameters[1]
            print(io, "\nYou attempted to index the type $Tx, rather than an instance of the type. Make sure you create the type using its constructor: ")
            printstyled(io, "d = $Tx([...])", color=:cyan)
            print(io, " rather than d = $Tx")
        end
    end
end

Experimental.register_error_hint(nonsetable_type_hint_handler, MethodError)

# Display a hint in case the user tries to use the + operator on strings
# (probably attempting concatenation)
function string_concatenation_hint_handler(@nospecialize(io::IO), ex::MethodError, arg_types::Vector{Any}, kwargs::Vector{Any})
    if (ex.f === +) && !isempty(arg_types) && all(@nospecialize(a) -> unwrapva(a) <: AbstractString, arg_types)
        print(io, "\nString concatenation is performed with ")
        printstyled(io, "*", color=:cyan)
        print(io, " (See also: https://docs.julialang.org/en/v1/manual/strings/#man-concatenation).")
    end
end

Experimental.register_error_hint(string_concatenation_hint_handler, MethodError)

# Display a hint in case the user tries to use the min or max function on an iterable
# or tries to use something like `collect` on an iterator without defining either IteratorSize or length
function methods_on_iterable(io, ex, arg_types, kwargs)
    @nospecialize
    f = ex.f
    if (f === max || f === min) && length(arg_types) == 1 && Base.isiterable(only(arg_types))
        f_correct = f === max ? "maximum" : "minimum"
        print(io, "\nFinding the $f_correct of an iterable is performed with `$f_correct`.")
    end
    if (f === Base.length || f === Base.size) && length(arg_types) >= 1
        arg_type_tuple = Tuple{arg_types...}
        if hasmethod(iterate, arg_type_tuple)
            iterkind = IteratorSize(arg_types[1])
            if iterkind isa HasLength
                print(io, "\nYou may need to implement the `length` method or define `IteratorSize` for this type to be `SizeUnknown`.")
            elseif iterkind isa HasShape
                print(io, "\nYou may need to implement the `length` and `size` methods for `IteratorSize` `HasShape`.")
            end
        end
    end
    nothing
end

Experimental.register_error_hint(methods_on_iterable, MethodError)

# Display a hint in case the user tries to access non-member fields of container type datastructures
function fielderror_dict_hint_handler(io, exc)
    @nospecialize
    field = exc.field
    type = exc.type
    if type <: AbstractDict
        print(io, "\nDid you mean to access dict values using key: `:$field` ? Consider using indexing syntax ")
        printstyled(io, "dict[:$(field)]", color=:cyan)
        println(io)
    end
end

Experimental.register_error_hint(fielderror_dict_hint_handler, FieldError)

function fielderror_listfields_hint_handler(io, exc)
    fields = fieldnames(exc.type)
    if isempty(fields)
        print(io, "; $(exc.type.name.wrapper) has no fields at all.")
    else
        print(io, ", available fields: $(join(map(k -> "`$k`", fields), ", "))")
    end
    props = _propertynames_bytype(exc.type)
    isnothing(props) && return
    props = setdiff(props, fields)
    isempty(props) && return
    print(io, "\nAvailable properties: $(join(map(k -> "`$k`", props), ", "))")
end

function _propertynames_bytype(T::Type)
    which(propertynames, (T,)) === which(propertynames, (Any,)) && return nothing
    inferred_names = promote_op(Val∘propertynames, T)
    inferred_names isa DataType && inferred_names <: Val || return nothing
    inferred_names = inferred_names.parameters[1]
    inferred_names isa NTuple{<:Any, Symbol} || return nothing
    return Symbol[inferred_names[i] for i in 1:length(inferred_names)]
end

Experimental.register_error_hint(fielderror_listfields_hint_handler, FieldError)

function UndefVarError_hint(io::IO, ex::UndefVarError)
    var = ex.var
    if isdefined(ex, :scope)
        scope = ex.scope
        if scope isa Module
            bpart = lookup_binding_partition(ex.world, GlobalRef(scope, var))
            kind = binding_kind(bpart)

            # Get the current world's binding partition for comparison
            curworld = tls_world_age()
            cur_bpart = lookup_binding_partition(curworld, GlobalRef(scope, var))
            cur_kind = binding_kind(cur_bpart)

            # Track if we printed the "too new" message
            printed_too_new = false

            # Check if the binding exists in the current world but was undefined in the error's world
            if kind === PARTITION_KIND_GUARD
                if isdefinedglobal(scope, var)
                    print(io, "\nThe binding may be too new: running in world age $(ex.world), while current world is $(curworld).")
                    printed_too_new = true
                else
                    print(io, "\nSuggestion: check for spelling errors or missing imports.")
                end
            elseif kind === PARTITION_KIND_GLOBAL || kind === PARTITION_KIND_UNDEF_CONST || kind == PARTITION_KIND_DECLARED
                print(io, "\nSuggestion: add an appropriate import or assignment. This global was declared but not assigned.")
            elseif kind === PARTITION_KIND_FAILED
                print(io, "\nHint: It looks like two or more modules export different ",
                "bindings with this name, resulting in ambiguity. Try explicitly ",
                "importing it from a particular module, or qualifying the name ",
                "with the module it should come from.")
            elseif is_some_explicit_imported(kind)
                print(io, "\nSuggestion: this global was defined as `$(partition_restriction(bpart).globalref)` but not assigned a value.")
            elseif kind === PARTITION_KIND_BACKDATED_CONST
                print(io, "\nSuggestion: define the const at top-level before running function that uses it (stricter Julia v1.12+ rule).")
            end

            # Check if binding kind changed between the error's world and current world
            if !printed_too_new && kind !== cur_kind
                print(io, "\nNote: the binding state changed since the error occurred (was: $(kind), now: $(cur_kind)).")
            end
        elseif scope === :static_parameter
            print(io, "\nSuggestion: run Test.detect_unbound_args to detect method arguments that do not fully constrain a type parameter.")
        elseif scope === :local
            print(io, "\nSuggestion: check for an assignment to a local variable that shadows a global of the same name.")
        end
    else
        scope = undef
    end
    if scope !== Base
        warned = _UndefVarError_warnfor(io, [Base], var)

        if !warned
            modules_to_check = (m for m in Base.loaded_modules_order
                                if m !== Core && m !== Base && m !== Main && m !== scope)
            warned |= _UndefVarError_warnfor(io, modules_to_check, var)
        end

        warned || _UndefVarError_warnfor(io, [Core, Main], var)
    end
    return nothing
end

function _UndefVarError_warnfor(io::IO, modules, var::Symbol)
    active_mod = Base.active_module()

    warned = false
    # collect modules which export or make public the variable by
    # the module in which the variable is defined
    to_warn_about = Dict{Module, Vector{Module}}()
    for m in modules
        # only include in info if binding has a value and is exported or public
        if !Base.isdefined(m, var) || (!Base.isexported(m, var) && !Base.ispublic(m, var))
            continue
        end
        warned = true

        # handle case where the undefined variable is the name of a loaded module
        if Symbol(m) == var && !isdefined(active_mod, var)
            print(io, "\nHint: $m is loaded but not imported in the active module $active_mod.")
            continue
        end

        binding_m = Base.binding_module(m, var)
        if !haskey(to_warn_about, binding_m)
            to_warn_about[binding_m] = [m]
        else
            push!(to_warn_about[binding_m], m)
        end
    end

    for (binding_m, modules) in pairs(to_warn_about)
        print(io, "\nHint: a global variable of this name also exists in ", binding_m, ".")
        for m in modules
            m == binding_m && continue
            how_available = if Base.isexported(m, var)
                "exported by"
            elseif Base.ispublic(m, var)
                "declared public in"
            end
            print(io, "\n    - Also $how_available $m")
            if !isdefined(active_mod, nameof(m)) || (getproperty(active_mod, nameof(m)) !== m)
                print(io, " (loaded but not imported in $active_mod)")
            end
            print(io, ".")
        end
    end
    return warned
end

Base.Experimental.register_error_hint(UndefVarError_hint, UndefVarError)

# ExceptionStack implementation
size(s::ExceptionStack) = size(s.stack)
getindex(s::ExceptionStack, i::Int) = s.stack[i]

function show(io::IO, ::MIME"text/plain", stack::ExceptionStack)
    nexc = length(stack)
    printstyled(io, nexc, "-element ExceptionStack", nexc == 0 ? "" : ":\n")
    show_exception_stack(io, stack)
end
show(io::IO, stack::ExceptionStack) = show(io, MIME("text/plain"), stack)
