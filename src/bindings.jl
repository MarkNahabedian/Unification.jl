
export AbstractVar, Var, SubseqVar, Ignore
export @V_str
export AbstractBindings, EmptyBindings, Bindings
export lookupfirst, lookupall, lookupequiv, lookup
export ubind, toDict


abstract type AbstractVar end


"""
A Unification vatiable.
"""
struct Var <: AbstractVar
    name::Symbol

    Var(name::AbstractString) = Var(Symbol(name))
    Var(name::Symbol) = new(name)
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
The associated value will be a SubArray.
The presence of more than one SubseqVar in
the same sequence allows for multiple
unifications, and combiniatorial explosion
in finding them.
"""
struct SubseqVar <: AbstractVar
    name::Symbol

    SubseqVar(name::AbstractString) = SubseqVar(Symbol(name))
    SubseqVar(name::Symbol) = new(name)
end


"""
Ignore match3es anything but captures nothing.
"""
struct Ignore end


macro V_str(name)
    @assert name isa AbstractString
    if length(name) == 0
        :(Ignore())
    elseif endswith(name, "...")
        :(SubseqVar($name))
    else
        :(Var($name))
    end
end 


abstract type AbstractBindings end

"""
The endmost tail of a bindings chain.
"""
struct EmptyBindings <: AbstractBindings
end

Base.iterate(::EmptyBindings) = nothing
Base.iterate(::AbstractBindings, ::EmptyBindings) = nothing

Base.IteratorSize(::Type{<:AbstractBindings}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{<:AbstractBindings}) = Tuple{AbstractVar, Any}


struct Bindings <: AbstractBindings
    var::AbstractVar
    val::Any
    tail::AbstractBindings

    Bindings(var::AbstractVar, val::Any, tail::AbstractBindings) =
        new(var, val, tail)
end

Base.iterate(b::Bindings, state::Bindings=b) = (state.var, state.val), state.tail


"""
    lookupfirst(::AbstractBindings, ::AbstractVar)
Return the `val` of the first entry in the `Bindings` about the`AbstractVar`.
"""
function lookupfirst(bindings::AbstractBindings, var::AbstractVar)
    for (v, val) in bindings
        @debug "$v, $val"
        if same(v, var)
            return val, true
        end
        # Binding a var to another var is symetric:
        if same(val, var)
            return v, true
        end
    end
    return nothing, false
end


"""
    lookupall(::Bindings, ::AbstractVar)::Set{Any}
Return a `Vector` of all of the `val`s in the `Bindings` which
correspond with the specified `AbstractVar`.
"""
function lookupall(bindings::AbstractBindings, var::AbstractVar)::Set{Any}
    found = Set{Any}()
    for (v, val) in bindings
        if same(v, var)
            push!(found, val)
        elseif same(val, var)
            # Binding a variable to a variable is symetric:
            push!(found, v)
        end
    end
    return found
end


"""
    lookupequiv(::Bindings, ::AbstractVar)
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
    lookup(bindings::AbstractBindings, var::AbstractVar)
Return the value assoiciated with `var` in `bindings`.
The second return value is `true` if a unique value is found
and `false` otherwise.
"""
function lookup(bindings::AbstractBindings, var::AbstractVar)
    values, _ = lookupequiv(bindings, var)
    if length(values) == 1
        return first(values), true
    end
    return nothing, false
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
