
export unify

"""
    unify(continuation, expression1, expression2, bindings=EmptyBindings())

Unify the two expressions, calling `continuation` with
bindings that satisfy the unification.
"""
function unify end

function unify(continuation, thing1, thing2)
    unify(continuation, thing1, thing2, EmptyBindings())
end

### Ignore

function unify(continuation, ::Ignore, other::Any, bindings::AbstractBindings)
  continuation(bindings)
end

function unify(continuation, ::Any, ::Ignore, bindings::AbstractBindings)
  continuation(bindings)
end

### Var

function unify(continuation, var::Var, other::Any, bindings::AbstractBindings)
    ubind(continuation, bindings, var, other)
end

function unify(continuation, other::Any, var::Var, bindings::AbstractBindings)
    ubind(continuation, bindings, var, other)
end

### SubseqVar

### default

# Is this method shadowed by the one on T, T where T?
function unify(continuation, thing1::Any, thing2::Any, bindings::AbstractBindings)
  if thing1 == thing2
    continuation(bindings)
  end
end

### Things that need to be == to unify

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

    
### Types with fields

# Pair has fields

# Hacky predicate dispatch mechanism.
abstract type UnificationStrategy end

function unify(continuation, thing1::T, thing2::T, bindings::AbstractBindings) where T
    # Short circuit for objects that are equal and structs with no fields
    if thing1 == thing2
        return continuation(bindings)
    end
    # Tryeach unification strategy
    for strategy in subtypes(UnificationStrategy)
        unify(continuation, strategy(),
              thing1, thing2, bindings::AbstractBindings)
    end
end


# I don't know how to tell if an object is implemented as a struct
# except to see if it has any fields.  Of courcse, a struct could have
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


# TODO:  Vector and Tuple
