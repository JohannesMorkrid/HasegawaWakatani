using FFTW
export TransformPlans, FFTPlans, rFFTPlans, multi_fft, multi_ifft

# Collection of plans for a transform and its inverse

abstract type TransformPlans end

struct FFTPlans <: TransformPlans
    FT::FFTW.Plan
    iFT::FFTW.Plan
end

struct rFFTPlans <: TransformPlans
    FT::FFTW.Plan
    iFT::FFTW.Plan
end

# Fourier transform applied to "stacked" fields
function multi_fft(U::AbstractArray, plans::TransformPlans)
    mapslices(u -> plans.FT * u, U, dims=(1, 2))
end

function multi_fft(U::Union{Tuple,Vector}, plans::TransformPlans)
    map(u -> plans.FT * u, U)
end

# TODO understand why plans::TransformPlans does not work
# Inverse Fourier transform
function multi_ifft(U::AbstractArray, plans)
    mapslices(u -> plans.iFT * u, U, dims=(1, 2))
end

function multi_ifft(U::Union{Tuple,Vector}, plans::TransformPlans)
    map(u -> plans.iFT * u, U)
end

# TODO possibly rename to spectral_transform
# General transform plan
function transform(U::AbstractArray, p::FFTW.Plan)
    mapslices(u -> p * u, U, dims=(1, 2))
end

function transform(U::Union{Tuple,Vector}, p::FFTW.Plan)
    map(u -> p * u, U)
end
