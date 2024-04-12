
function merge_expr_tuples(given::Tuple{Vararg{Expr}},
                           default::Tuple{Vararg{Expr}})
    @assert all(map(e -> e.head == :(=), given))
    @assert all(map(e -> e.head == :(=), default))
    merged = Vector{Expr}()
    function put(e)
        name = e.args[1]
        if nothing == findfirst(e -> e.args[1] == name, merged)
            push!(merged, e)
        end
    end
    for e in given; put(e); end
    for e in default; put(e); end
    merged
end

# The splatted argument of a macro is a Tuple of Expr.  Fetch a value
# from it.
function splatted_exprs_lookup(splatted, name)
    for e in splatted
        if isexpr(e, :(=))
            if e.args[1] == name
                return e.args[2]
            end
        end
    end
    return missing
end
