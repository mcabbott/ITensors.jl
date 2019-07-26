export @Index, @IT, @IT!

using MacroTools

"""
    @Index i 3
    @Index i j k 3

Convenience macro to define one index `i = Index(3, "i")`, or several of the same dimension.

    @Index a,three,z  3
    @Index (b,+)  (c,-)  5
    @Index (d,n=1)  (e,n=1)  7

When attaching more than one tag to an index like `b = Index(5, "a,+")`,
brackets are only sometimes needed, here to avoid `(b, +c, -5)`.

And the first tag will be used as the variable name, unless it's not a symbol,
in which case you may use the returned value or tuple: `f,g = @Index (n=2,f) (n=2,g) 11`.
"""
macro Index(exs...)
  _Index(exs...)
end

function _Index(exs...)
  length(exs) >= 2 || error("@Index needs at least two arguments, an index name and a dimension")
  qnames, escnames = [], []
  out = quote end

  dim = exs[end]
  for (n,i) in enumerate(exs[1:end-1])
    indexex = :( Index($(esc(dim)), $(makestring(i))) )

    iname = getname(i)
    if iname !== nothing
      push!(out.args, :($(esc(iname)) = $indexex ))
      push!(qnames, QuoteNode(iname))
      push!(escnames, esc(iname))

    # a bit of a hack, for (n=2,f) tags
    elseif length(exs) < 3
      push!(out.args, indexex)
    else
      push!(qnames, QuoteNode(Symbol(:index,n)))
      push!(escnames, indexex)
    end
  end

  if length(exs) >= 3
    push!(out.args, :( NamedTuple{($(qnames...),)}(($(escnames...),)) ))
  end
  return out
end

getname(i::Symbol) = i
getname(ex) = @capture(ex, (i_,j__) ) ? getname(i) : nothing # gensym(string(ex))
makestring(i::Symbol) = string(i)
makestring(ex) = @capture(ex, (ij__,) ) ? join(makestring.(ij), ",") : string(ex)


"""
    A′ = @IT  A[i,j]
    B′, C′ = @IT  B[i,j]  C[j,k]

Given ordinary arrays `B, C`, this first defines indices `i,j,k` using the sizes of the arrays,
unless they already exist and are `::Index`, and then creates ITensors `A′, B′`.
For more than one array, it returns a NamedTuple with `ans.B = B′` etc.

    A′ = @IT!  A[i,j]

Version which always overwrites `i,j`.
```
julia> A = rand(2,3);

julia> @Index i 2
(2|id=378|i)

julia> @IT!  A[i,j]
ITensor ord=2 (2|id=97|i) (3|id=351|j)
Dense{Float64}

julia> i
(2|id=97|i)
```
"""
macro IT(exs...)
  _IT(exs...; mod=__module__)
end

macro IT!(exs...)
  _IT(exs...; mod=__module__, force=true)
end

function _IT(exs...; mod=Main, force=false)
  tensors, qnames, icode, seen = [], [], [], []
  for ex in exs

    @capture(ex, A_[ijk__]) && A isa Symbol || error("each expression must be like A[i,j]")
    escA = esc(A)

    for (d,i) in enumerate(ijk)
      i isa Symbol || error("each index must be a Symbol")
      esci = esc(i)
      str = "range of index $i must agree" # ITensor constructor checks only length

      if i in seen
        push!(icode, :( @assert size($escA,$d) == $esci.dim $str ))
      elseif force
        push!(icode, :( $esci = Index(size($escA,$d), $(string(i))) ))
      else
        push!(icode, quote
            if isdefined($mod, $(QuoteNode(i))) && isa($i, Index)
              @assert size($escA,$d) == $esci.dim $str
            else
              $esci = Index(size($escA,$d), $(string(i)))
            end
          end)
        push!(seen, i)
      end
    end

    push!(tensors, :( ITensor($escA, IndexSet($(esc.(ijk)...))) ))
    push!(qnames, QuoteNode(A))
  end

  if length(exs) >= 2
    return :( $(icode...); NamedTuple{($(qnames...),)}(($(tensors...),)) )
  else
    return :( $(icode...); $(tensors[1]) )
  end
end
