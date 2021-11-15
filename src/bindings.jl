
export AbstractVar, Var, SubseqVar, Ignore
export @V_str
export AbstractBindings, EmptyBindings, Bindings
export lookup, lookupall, lookupequiv, ubind, toDict


abstract type AbstractVar end


"""
A Unification vatiable.
"""
struct Var <: AbstractVar
    name::Symbol
end

# Do we need to include some notion of scope?
function same(var1::AbstractVar, var2::AbstractVar)::Bool
    typeof(var1) == typeof(var2) &&
        var1.name == var2.name
end

same(var1::AbstractVar, ::Any) = false
same(::Any, Var1::AbstractVar) = false


"""
A Unification variable for subsequences.
"""
struct SubseqVar <: AbstractVar
    name::Symbol
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
    var::AbstractVar
    val::Any
    tail::AbstractBindings

    Bindings(var::AbstractVar, val::Any, tail::AbstractBindings) =
        new(var, val, tail)
end


"""
    lookup(::Bindings, ::AbstractVar)
returnb the `val` of the first entry in the `Bindings` about the`AbstractVar`.
"""
function lookup end

function lookup(bindings::EmptyBindings, var::AbstractVar)::Any
    return nothing, false
end

function lookup(bindings::AbstractBindings, var::Any)
    return nothing, false
end

function lookup(bindings::Bindings, var::AbstractVar)::Any
    if same(bindings.var, var)
        return bindings.val, true
    elseif isa(bindings.val, Var) && same(var, bindings.val)
        #Var bound to Var is symetric:
        return bindings.var, true
    end
    lookup(bindings.tail, var)
end


"""
    lookupall(::Bindings, ::AbstractVar)::Set{Any}
Return a `Vector` of all of the `val`s in the `Bindings` which
correspond with the specified `AbstractVar`.
"""
function lookupall(bindings::Bindings, var::AbstractVar)::Set{Any}
    found = Set{Any}()
    function la(bindings::EmptyBindings) end
    function la(bindings::Bindings)
        if same(bindings.var, var)
            push!(found, bindings.val)
        elseif same(bindings.val, var)
            # Binding a variable to a variable is symetric:
            push!(found, bindings.var)
        end
        la(bindings.tail)
    end
    la(bindings)
    return found
end


"""
    lookupequiv(::bBindings, ::AbstractVar)
Return a `Set` of all of the values associated with the `AbstractVar`
and another Set of all equivalent (transitively bound) `AbstractVar`s.
"""
function lookupequiv(bindings::AbstractBindings, var::AbstractVar)
    found = Set{Any}()
    queue = Vector{AbstractVar}()
    push!(queue, var)
    done = Set{AbstractVar}()
    while !isempty(queue)
        var = pop!(queue)
        if var in done    ##### Probably using == rather than same
            continue
        end
        push!(done, var)
        vals = lookupall(bindings, var)
        # With Set I don't think we can skip over the ones already returned.
        for val in vals
            if val isa AbstractVar
                push!(queue, val)
            else
                push!(found, val)
            end
        end
    end
    return found, done
end

"""
    ubind(continuation, var::AbstractVar, val::Any, [::AbstractBindings])
Call `continuation` with the binding of `var` to `val` added
to `bindings`.
"""
function ubind(continuation, var::AbstractVar, value::Any,
               bindings::AbstractBindings = EmptyBindings())
    continuation(Bindings(var, value, bindings))
end

"""
    ubind(continuation, pairs::Vector{Pair{<:AbstractVar, <:Any}}, ::AbstractBindings=EmptyBindings())
Call `continuation` on a chain of `Bindings` where the `Pair`s are added to
the head of the chain such that the first pair is at the
head of the chain.
"""
function ubind(continuation, pairs::Vector{<:Pair{<:AbstractVar, <:Any}},
               bindings::AbstractBindings=EmptyBindings())
    for i = lastindex(pairs) : -1 :firstindex(pairs)
        p = pairs[i]
        bindings = Bindings(p.first, p.second, bindings)
    end
    continuation(bindings)
end

#=
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
=#
