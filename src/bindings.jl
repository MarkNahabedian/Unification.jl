
export AbstractVar, Var, SubseqVar, Ignore
export @V_str
export AbstractBindings, EmptyBindings, Bindings
export lookup, ubind, toDict


abstract type AbstractVar end


"""
A Unification vatiable.
"""
struct Var <: AbstractVar
    name::Symbol
end

# Do we need to include some notion of scope?
function same(var1::Var, var2::Var)::Bool
    var1.name == var2.name
end


"""
A Unification variable for subsequences.
"""
struct SubseqVar <: AbstractVar
    name::Symbol
end

function same(var1::SubseqVar, var2::Var)::Bool
    var1.name == var2.name
end


"""
Ignore match3es anything but captures nothing.
"""
struct Ignore end


macro V_str(name)
    quote
        n = $name
        if length(n) == 0
            Ignore()
        elseif endswith(n, "...")
            SubseqVar(Symbol(n))
        else
            Var(Symbol(n))
        end
    end
end


abstract type AbstractBindings end

"""
The endmost tail of a bindings chain.
"""
struct EmptyBindings <: AbstractBindings
end

struct Bindings <: AbstractBindings
    var::Var
    val::Any
    tail::AbstractBindings
end

"""Issues:

What if a variable is bound more than once, eg V"a" = V"B",
 V"A" = V"c"?

Lookup muct consider the Var bound to Var case and treat is
symetrically,or ubind needs to bind in both directions.

"""


function lookup(bindings::EmptyBindings, var::Var)::Any
    return nothing, false
end

function lookup(bindings::Bindings, var::Var)::Any
    if same(bindings.var, var)
        return bindings.val, true
    elseif isa(bindings.val, Var) && same(var, bindings.val)
        #Var bound to Var is symetric:
        return bindings.var, true
    end
    lookup(bindings.tail, var)
end

#=
function lookup(bindings::Bindings, var::Var)::Any
    # Guard against circular variable bindings:
    vars = []
    while !(var in vars)
        push!(vars, var)
        val, found = lookup1(bindings.tail, var)
        if !found
            return nothing, false, :not_found
        end
        if !isa(val, AbstractVar)
            return val, found
        end
        if val in vars  # circular
            return nothing, false, :circular
        end
        var = val
    end
    return nothing, false, :exhausted
end
=#

function ubind(continuation, var::Var, value::Any,
               bindings::AbstractBindings = EmptyBindings())
    continuation(Bindings(var, value, bindings))
end

#=
function ubind(continuation, var1::Var, var2::Var,
               bindings::AbstractBindings = EmptyBindings())
    if same(var1, var2)
        return continuation(bindings)
    end
    v1 = lookup(bindings, var1)
    v2 = lookup(bindings, var2)
    if !isa(v1, Var) && !isa(v2, Var)
        if v1 != v2
            return
        else
            return continuation(bindings)
        end
    end
    if v1 isa Var
        ErrorException("???")
    end
end

function ubind(continuation, var::Var, value::Any,
               bindings::AbstractBindings = EmptyBindings())
    # ??? What about variables unified with variables and circularity?
    v, found = lookup(bindings, var)
    while found && v isa Var && v != var
        v, found == lookup(bindings, v)
    end
    if !found
        continuation(Bindings(var, value, bindings))
    elseif v == value
        continuation(bindings)
    end
end
=#

function toDict(bindings::AbstractBindings)::Dict{AbstractVar, Any}
    d = Dict{AbstractVar, Any}()
    b = bindings
    while true
        if haskey(d, b.var)
            if d[b.var] != b.val
                throw(ErrorException(
                    "More than one distinct value for $(b.var): $(d[b.var]), $(b.val)"))
            end
        else
            d[b.var] = b.val
        end
    end
    return d
end

