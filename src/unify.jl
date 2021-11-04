

"""
    unify(continuation, expression1, expression2, bindings=EmptyBindings())

Unify the two expressions, calling `continuation` with
bindings that satisfy the unification.
"""
function unify end

### Ignore

function unify(continuation, ::Ignore, other::Any, bindings::AbstractBindings)
  continuation(bindings)
end

function unify(continuation, ::Any, other::Ignore, bindings::AbstractBindings)
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

### Numbers

# Numbers of different types that might be equal:
function unify(continuation, thing1::Number, thing2::Number, bindings::AbstractBindings)
  if thing1 == thing2
    continuation(bindings)
  end
end


### Everything Else

# Does this shadow the Any, ANy method?
function unify(continuation, thing1::T, thing2::T, bindings::AbstractBindings) where T
    if thing1 == thing2
        return continuation(bindings)
    end
    fieldnames = fieldnames(T)
    function unify_fields(index, bindings)
        if index > length(fieldnames)
            return continuation(bindings)
        end
        field = fieldnames[index]
        unify(thing1.field, thing2.field, bindings) do bindings
            return unify_fields(index + 1, bindings)
        end
    end
    unify_fields(1, bindings)
end


#=
# I don't see a way to define a method for types that are implemented
# as structs, so we can at leasat make it easy for people to define
# their own standatd unify methods for their struicts.

macro unifystruct(T)
  :(function unify(thing1::$T, thing2::$T, b=EmptyBindings())::AbstractBindings
      for f in fieldnames($T)
        b = unify(getfield(thing1, f), getfield(thing2, f), b)
      end
      return b
    end)
end

@unifystruct Expr
=#
# TODO:  Vector and Tuple

#=

x = :(a, b...)

x.args[2].head
:...
x.args[2].args
1-element Vector{Any}:
 :b

=#
