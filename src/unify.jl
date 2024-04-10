
export unify
export UNIFICATION_FAILURE_LOGGING_LEVEL, logging_unification_failures
export @unification_failure, @unify_equal

"""
    UNIFICATION_FAILURE_LOGGING_LEVEL
See `@unification_failure`.
"""
UNIFICATION_FAILURE_LOGGING_LEVEL = false

function logging_unification_failures(f, level)
    global UNIFICATION_FAILURE_LOGGING_LEVEL
    was = UNIFICATION_FAILURE_LOGGING_LEVEL
    try
        UNIFICATION_FAILURE_LOGGING_LEVEL = level
        f()
    finally
        UNIFICATION_FAILURE_LOGGING_LEVEL = was
    end
end

"""
   @unification_failure(thing1, thing2)

Logs that `unify` failed for `thing1` and `thing2`.
If the value of `UNIFICATION_FAILURE_LOGGING_LEVEL` is a
Logging.LogLevel` then it is the log level for this message,
otherwise no log entry is made.
"""
macro unification_failure(thing1, thing2, more...)
    args = [ :_file => __source__.file,
             :_line => __source__.line,
             :_module => __module__,
             more...]
    :(
        if UNIFICATION_FAILURE_LOGGING_LEVEL isa LogLevel
            #=
            # Using @logmsg gets the line number wrong.  I want the line
            # where @unification_failure appears, not the line in the
            # macro that logs the message.
            Logging.handle_message(
                Base.CoreLogging.current_logger_for_env(
                    UNIFICATION_FAILURE_LOGGING_LEVEL, :none, $m),
                UNIFICATION_FAILURE_LOGGING_LEVEL,
                "Unification failure",
                $m, :none, gensym("id"), $(source.line), "$(source.file)";
                thing1=$(esc(thing1)), thing2=$(esc(thing2)),
                more=$(esc(more)))
            =#
            @logmsg(UNIFICATION_FAILURE_LOGGING_LEVEL,
                    "Unification failure",
                    thing1=$(esc(thing1)), thing2=$(esc(thing2)),
                    $args...)
        end)
end


"""
    unify(continuation, expression1, expression2)::Nothing
    unify(continuation, expression1, expression2, bindings=EmptyBindings())::Nothing

Unifies the two expressions, calling `continuation` with each set of
bindings which satisfy the unification.  `continuation` should return
nothing.

`continuation` is a function with the same signature as
`show_bindings`.

There is no return value.
"""
function unify end

function unify(continuation, thing1, thing2)::Nothing
    unify(continuation, thing1, thing2, EmptyBindings())
    return nothing
end

### Ignore

function unify(continuation, ::Ignore, ::Any,
               bindings::AbstractBindings)::Nothing
    continuation(bindings)
    return nothing
end

function unify(continuation, ::Any, ::Ignore,
               bindings::AbstractBindings)::Nothing
    continuation(bindings)
    return nothing
end

### Var

function unify(continuation, var::Var, other::Any,
               bindings::AbstractBindings)::Nothing
    unify_var(continuation, var, other, bindings)
    return nothing
end

function unify(continuation, other::Any, var::Var,
               bindings::AbstractBindings)::Nothing
    unify_var(continuation, var, other, bindings)
    return nothing
end

function unify(continuation, var1::Var, var2::Var,
               bindings::AbstractBindings)::Nothing
    ##### Is this enough
    unify_var(continuation, var1, var2, bindings)
    return nothing
end

"""
`unify` with a `NoCirc` always succeeds unless the NoCirc is being unified
against its subject `var`.
"""
struct NoCirc <: AbstractVar
    var::AbstractVar
end

function unify(continuation, nc::NoCirc, ::Any,
               bindings::AbstractBindings)::Nothing
    continuation(bindings)
    return nothing
end

function unify(continuation, nc::NoCirc, var::Var,
               bindings::AbstractBindings)::Nothing
    if same(nc.var, var)
        continuation(bindings)
    end
    continuation(bindings)
    return nothing
end

function unify(continuation, ::Any, nc::NoCirc, bindings)::Nothing
    throw(ErrorException("$nc appeared in right hand side of unify."))
end

function unify_var(continuation, var::Var, other::Any,
                   bindings::AbstractBindings)::Nothing
    values, _ = lookupequiv(bindings, var)
    if length(values) > 1
        # Variable's value is already ambiguous.
        @unification_failure(var, other,
                             values=values)
        return
    end
    if length(values) == 1
        return unify(continuation, first(values), other, bindings)
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
    ubind(continuation, var, other, bindings)
    nothing
end


### SubseqVar

### default

##### Is this method shadowed by the one on T, T where T?
function unify(continuation, thing1::Any, thing2::Any,
               bindings::AbstractBindings)::Nothing
    if thing1 == thing2
        return continuation(bindings)
    end
    @unification_failure(thing1, thing2)
end


### Things that need to be == to unify

"""
    @unify_equal(typ, op)

Define a method on `unify` for type `typ` that only succeeds if the
two instances of `typ` satisfy `op`.
"""
macro unify_equal(typ, op)
    r = 
        quote
            function Unification.unify(continuation,
                                       thing1::$typ, thing2::$typ,
                                       bindings::AbstractBindings)::Nothing
                if $op(thing1, thing2)
                    return continuation(bindings)
                end
                #=
                @unification_failure(thing1, thing2,
                                     _file = $(__source__.file),
                                     _line = $(__source__.line),
                                     _module = $__module__)
                =#
            end
        end
    # A bunch of insane hoops to jump through in order to get the
    # right source location recorded:
    r = MacroTools.postwalk(MacroTools.rmlines, r)
    if isexpr(r, :block)
        if isexpr(r.args[1], :function)
            if isexpr(r.args[1].args[2], :block)
                insert!(r.args[1].args[2].args, 1, __source__)
            end
        end
        insert!(r.args, 1, __source__)
    end
    esc(r)
end

# Numbers of different types that might be equal:
@unify_equal(Number, ==)

@unify_equal(Symbol, ==)
@unify_equal(AbstractChar, ==)
@unify_equal(AbstractString, ==)

    
### Things that are finitely indexable:

struct UnifyIndexableElement
    thing
    index::Int

    UnifyIndexableElement(thing) = new(thing, firstindex(thing))
    UnifyIndexableElement(thing, index::Int) = new(thing, index)
end

function next(e::UnifyIndexableElement)
    UnifyIndexableElement(e.thing, e.index + 1)
end

function exhausted(e::UnifyIndexableElement)
    e.index > lastindex(e.thing)
end

function elt(e::UnifyIndexableElement)
    e.thing[e.index]
end

function unify_indexable(continuation, thing1, thing2,
                         bindings::AbstractBindings)::Nothing
    unify_indexable(continuation,
                    UnifyIndexableElement(thing1),
                    UnifyIndexableElement(thing2),
                    bindings)
    nothing
end

function unify_indexable(continuation,
                         e1::UnifyIndexableElement,
                         e2::UnifyIndexableElement,
                         bindings::AbstractBindings)::Nothing
    if exhausted(e1) && exhausted(e2)
        continuation(bindings)
        return
    end
    if exhausted(e1) || exhausted(e2)
        @unification_failure(e1, e2)
        return
    end
    if isa(elt(e1), SubseqVar) && isa(elt(e2), SubseqVar)
        ubind(elt(e1), elt(e2), bindings) do bindings
            unify_indexable(continuation, next(e1), next(e2), bindings)
        end
        return
    end
    if isa(elt(e1), SubseqVar)
        unify_indexable(continuation, elt(e1), e1, e2, bindings)
        return
    end
    if isa(elt(e2), SubseqVar)
        unify_indexable(continuation, elt(e2), e2, e1, bindings)
        return
    end
    unify(elt(e1), elt(e2), bindings) do bindings
        unify_indexable(continuation, next(e1), next(e2), bindings)
        return
    end
end

function unify_indexable(continuation,
                         var::SubseqVar, varUIE::UnifyIndexableElement,
                         e::UnifyIndexableElement,
                         bindings::AbstractBindings)::Nothing
    # Try each length of remaining subsequences of thing2
    for endindex in (e.index - 1):(lastindex(e.thing))
        ubind(var, view(e.thing, (e.index):endindex), bindings) do bindings
            unify_indexable(continuation,
                            next(varUIE),
                            UnifyIndexableElement(e.thing, endindex + 1),
                            bindings)
        end
    end
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

##### Maybe these types can be computed from methods(IndexStyle) that return IndexLinear.
@generate_unify_indexable_methods(AbstractVector, Tuple)


### Types with fields

# Hacky predicate dispatch mechanism.
abstract type UnificationStrategy end

function unify(continuation, thing1::T, thing2::T,
               bindings::AbstractBindings)::Nothing where {T}
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
        @unification_failure(thing1, thing2)
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

