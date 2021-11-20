# Unification

A utility for performing logical unification of generqal data
structures.

This package can unify over Vectores, Tuples and structs -- pretty
much anything that has fields.

The unifier can be extended by defining additional methods on
`Unification.unify` or defining a new subtype of
`UnificationStrategy`.

It is not heavily tested.

## Logic Variables

Alogic variable is introduced with the `V_str` macro.

```
V"foo"
Var(:foo)
```

## Unification

The function `unify` attempts to unify two data structures.  A
continuation function is called for each successful unification.  The
continuation function is passed a `Bindings` object as its only
argument.

## Bindings

If you wanted to create a Bindings object (like for testing or
pllaying around), you could call the constructor directly or call
`ubind`.  Ubindcallsacontinuation function with the resulting
bindings:

```
ubind(V"a", 7) do bindings
    println(bindings)
end
Bindings(Var(:a), 7, EmptyBindings())
```

To establish multiple bindings, rather than nesting `ubind`, `ubind`
also accepts a `Vector` of `Pair`s of a variabletoa value:

```
ubind([V"a" => 1, V"b" => 2]) do bindings
    println(bindings)
end
Bindings(Var(:a), 1, Bindings(Var(:b), 2, EmptyBindings()))
```

Note that the bindings frames are ordered in the same order as the
`Pair`s in the `Vector`, so the first element of the `Vector` is the
outermost and most recently added frapme pf the bindings chain.


## Lookup

Some functions are provided for looking up values in bindings.

`lookupfirst(bindings::AbstractBindings, variable::AbstractVariable)`
finds the first value of  `variable` in `bindings`.

`lookupall(::Bindings, ::AbstractVar)` returns a set of all values
that are associatwed with the variable in the bindings.  See the
examples below for why there might be more than ove value associated
with a variable.  Unification should fail if there is more than one
non-variable value associated with a variable.

`lookupequiv(::Bindings, ::AbstractVar)` finds all values associated
with variable and all variables that are equivalent to the subject
variable.  It returns two values: a `Set` of non-variable values, and
a `Set` of equivalent variables.


## Examples

```
struct Struct1
    a
    b
end

unify([Struct1(3, V"foo"), 12],
      [Struct1(V"bar", V"c"), V"c"]) do bindings
    lookup(bindings, V"bar")
end
unify([Struct1(3, V"foo"), 12],
      [Struct1(V"bar", V"c"), V"c"]) do bindings
    println(lookup(bindings, V"bar"))
end
(3, true)
```

## Some links about unification:

[blog post](https://www.juliabloggers.com/unification-in-julia/)

[Russel and Norvig](https://github.com/aimacode/aima-python/blob/9ea91c1d3a644fdb007e8dd0870202dcd9d078b6/logic4e.py#L1307)

