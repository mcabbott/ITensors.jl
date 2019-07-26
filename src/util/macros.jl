
"""
    @index i 3
    @index i j k 3

Convenience macro to define one index `i = Index(3, "i")`, or several of the same dimension. 
"""
macro index(exs...)
  _index(exs...)
end

function _index(exs...)
  length(exs) >= 2 || error("@index needs at least two arguments, an index name and a dimension")
  out = quote end

  dim = exs[end]
  for i in exs[1:end-1]
    push!(out.args, :($(esc(i)) = Index($(esc(dim)), $(string(i))) ))
  end

  if length(exs) >= 3
    names = QuoteNode.(exs[1:end-1])
    push!(out.args, :( NamedTuple{($(names...),)}(($(esc.(exs[1:end-1])...),)) ))
  end
  return out
end

using MacroTools

"""
    A′, B′ = @IT  A[i,j]  B[j,k]

Given ordinary arrays `A, B`, this first defines indices `i,j,k` using the sizes of the arrays, 
and then creates ITensors `A′, B′`. Returns a NamedTuple with `ans.A = A′` etc. 

Does not check whether `i,j,k` are already defined, that would be better.
"""
macro IT(exs...)
  _IT(exs...; mod=__module__)
end

function _IT(exs...; mod=Main)
  # if @capture(ex[1], (stuff__,))
  #     length(exs) > 1 && @warn "ignoring some arguments: $(exs[2:end])"
  #     return(_IT(exs[1]...))
  # end

  tensors, names, icode, seen = [], [], [], []
  for ex in exs

    @capture(ex, A_[ijk__]) && A isa Symbol || error("each expression must be like A[i,j]")
    escA = esc(A)

    for (d,i) in enumerate(ijk)
      i isa Symbol || error("each index must be a Symbol")
      esci = esc(i)
      if i in seen
        str = "range of index $i must agree"
        push!(icode, :( @assert size($escA,$d) == $esci.dim $str ))
      else
        push!(icode, :( $esci = Index(size($escA,$d), $(string(i))) ))
        push!(seen, i)
      end
    end

    push!(tensors, :( ITensor($escA, IndexSet($(esc.(ijk)...))) ))
    push!(names, QuoteNode(A))
  end

  return :( $(icode...); NamedTuple{($(names...),)}(($(tensors...),)) )
end
