
export unify

"""
    unify(continuation, expression1, expression2, bindings=EmptyBindings())

Unify the two expressions, calling `continuation` with each set of
bindings which satisfy the unification.
"""
function unify end

function unify(continuation, thing1, thing2)
    unify(continuation, thing1, thing2, EmptyBindings())
end

### Ignore

function unify(continuation, ::Ignore, ::Any, bindings::AbstractBindings)
  continuation(bindings)
end

function unify(continuation, ::Any, ::Ignore, bindings::AbstractBindings)
  continuation(bindings)
end

### Var

function unify(continuation, var::Var, other::Any, bindings::AbstractBindings)
    unify_var(continuation, var, other, bindings)
end

function unify(continuation, other::Any, var::Var, bindings::AbstractBindings)
    unify_var(continuation, var, other, bindings)
end

function unify(continuation, var1::Var, var2::Var, bindings::AbstractBindings)
    ##### Is this enough
    unify_var(continuation, var1, var2, bindings)
end

"""
`unify` with a `NoCirc` always succeeds unless the NoCirc is being unified
against its subject `var`.
"""
struct NoCirc <: AbstractVar
    var::AbstractVar
end

function unify(continuation, nc::NoCirc, ::Any, bindings::AbstractBindings)
    continuation(bindings)
end

function unify(continuation, nc::NoCirc, var::Var, bindings::AbstractBindings)
    @debug("unify #nc, $var, $bindings")
    if same(nc.var, var)
        return
    end
    continuation(bindings)
end

function unify(continuation, ::Any, nc::NoCirc, bindings)
    throw(ErrorException("$nc appeared in right hand side of unify."))
end

function unify_var(continuation, var::Var, other::Any, bindings::AbstractBindings)
    @debug("unify_var $var $other $bindings")
    values, _ = lookupequiv(bindings, var)
    if length(values) > 1
        # Variable's value is already ambiguous.
        return
    end
    if length(values) == 1
        return unify(continuation, val, other, bindings)
    end
    # To avoid a reference cycle, we must make sure `var` does not
    # appear anywhere in `other`.  It would be nice if there were only
    # one generic function that needed to code how to walk non-atomic
    # data.  We use `unify` for that.  We unify `other` against a NoCirc
    # that matches anything but the variable we are looking for.
    #=
    unify(NoCirc(var), other, bindings) do bindings
        ubind(continuation, var, other, bindings)
    end
    =#
end


### SubseqVar

### default

##### Is this method shadowed by the one on T, T where T?
function unify(continuation, thing1::Any, thing2::Any, bindings::AbstractBindings)
  if thing1 == thing2
    continuation(bindings)
  end
end


### Things that need to be == to unify

"""
    @unify_equal(typ, op)
Define a method on `unify` for type `typ` that only succeeds if the
two instances of `typ` satisfy `op`.
"""
macro unify_equal(typ, op)
    :(function unify(continuation, thing1::$typ, thing2::$typ, bindings::AbstractBindings)
          if $op(thing1, thing2)
              continuation(bindings)
          end
      end)
end

# Numbers of different types that might be equal:
@unify_equal(Number, ==)

@unify_equal(Symbol, ==)
@unify_equal(AbstractChar, ==)
@unify_equal(AbstractString, ==)

    
### Things that are finitely indexable:

function unify_indexable(continuation, index1, thing1, index2, thing2,
                         bindings::AbstractBindings)
    exhausted1 = index1 > lastindex(thing1)
    exhausted2 = index2 > lastindex(thing2)
    if exhausted1 && exhausted2
        return continuation(bindings)
    end
    if exhausted1 || exhausted2
        return
    end
    unify(thing1[index1], thing2[index2], bindings) do bindings
        unify_indexable(continuation,
                        index1 + 1, thing1,
                        index2 + 1, thing2,
                        bindings)
    end
end

function unify_indexable(continuation, thing1, thing2,
                         bindings::AbstractBindings)
    unify_indexable(continuation,
                    firstindex(thing1), thing1,
                    firstindex(thing2), thing2,
                    bindings)
end

macro generate_unify_indexable_methods(types...)
    defs = []
    for t1 = types, t2 = types
        push!(defs,
              esc(:(function unify(continuation, thing1::$t1, thing2::$t2, bindings::AbstractBindings)
                        unify_indexable(continuation, thing1, thing2, bindings)
                    end)))
    end
    return :(begin $(defs...) end)
end

@generate_unify_indexable_methods(AbstractVector, Tuple)


### Types with fields

# Hacky predicate dispatch mechanism.
abstract type UnificationStrategy end

function unify(continuation, thing1::T, thing2::T, bindings::AbstractBindings) where T
    # Short circuit for objects that are equal and structs with no fields
    if thing1 == thing2
        return continuation(bindings)
    end
    # Try each unification strategy
    for strategy in subtypes(UnificationStrategy)
        unify(continuation, strategy(),
              thing1, thing2, bindings::AbstractBindings)
    end
end


# I don't know how to tell if an object is implemented as a struct
# except to see if it has any fields.  Of course, a struct could have
# no fields, which would make it a singleton type.
struct UnifyFields <: UnificationStrategy end

function unify(continuation, strategy::UnifyFields, thing1, thing2, bindings::AbstractBindings)
    fields = fieldnames(typeof(thing1))
    if length(fields) == 0
        return
    end
    function unify_fields(index, bindings)
        if index > length(fields)
            return continuation(bindings)
        end
        field = fields[index]
        unify(getfield(thing1, field),
              getfield(thing2, field),
              bindings) do bindings
                  return unify_fields(index + 1, bindings)
              end
    end
    unify_fields(1, bindings)
end

