
struct WrappedTensor{T,N} <: AbstractArray{T,N}
    tensor::ITensor
    WrappedTensor(x::ITensor) = new{eltype(x), order(x)}(x)
end

"""
    AbstractArray(x::ITensor, ijk::Index...)

Produces a wrapper around `x` which is an `AbstractArray`,
with indices in the order given.
Should be a lazy view of `x.store.data` but isn't yet.
"""
Base.AbstractArray(x::ITensor) = WrappedTensor(x)
Base.AbstractArray(x::ITensor, ijk::Index...) = WrappedTensor(permute(x, ijk...))

ITensor(x::WrappedTensor) = x.tensor

Base.size(x::WrappedTensor) = dims(x.tensor)
Base.getindex(x::WrappedTensor, i::Int...) = x.tensor[i...]
Base.getindex(x::WrappedTensor, i::CartesianIndex) = x.tensor[i.I...]
Base.setindex!(x::WrappedTensor, y, i...) = setindex!(x.tensor, y, i...)
Base.setindex!(x::WrappedTensor, y, i::CartesianIndex) = setindex!(x.tensor, y, i.I...)

