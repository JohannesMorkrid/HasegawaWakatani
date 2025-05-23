## Run all (alt+enter)
include(relpath(pwd(), @__DIR__) * "/src/HasegawaWakatini.jl")

## Run scheme test for Burgers equation
domain = Domain(128, 128, 160, 160, anti_aliased=true)
ic = initial_condition_linear_stability(domain, 1e-3)
ic[:,:,1] .+= 0.5

heatmap(ic[:,:,1])

# Linear operator
function L(u, d, p, t)
    D_n = p["D_n"] .* diffusion(u, d)
    D_Ω = p["D_Ω"] .* diffusion(u, d)
    [D_n;;; D_Ω]
end

function source(x, y, S_0, λ_s)
    @. S_0*exp(-(x/λ_s)^2) + 0*y
end

S = domain.transform.FT*source(domain.x', domain.y, 5e-4, 5)

# Non-linear operator, fully non-linear
function N(u, d, p, t)
    n = @view u[:, :, 1]
    Ω = @view u[:, :, 2]
    ϕ = solvePhi(Ω, d)

    dn = -poissonBracket(ϕ, n, d)
    dn .-= p["g"] * diffY(n, d)
    dn += p["g"] * quadraticTerm(n, diffY(ϕ, d), d)
    dn .-= p["σ_0"] * quadraticTerm(n, spectral_exp(-ϕ, d), d)
    # Plus the const source
    dn .+= S

    dΩ = -poissonBracket(ϕ, Ω, d)
    dΩ .-= p["g"] * diffY(spectral_log(n, d), d)
    dΩ .-= p["σ_0"] * spectral_expm1(-ϕ,d)
    return [dn;;; dΩ]
end

# Parameters
parameters = Dict(
    "D_Ω" => 1e-2,
    "D_n" => 1e-2,
    "g" => 8e-4,
    "σ_0" => 2e-4,
    "S_0" => 5e-4,
    "λ_s" => 5.0,
)

t_span = [0, 10000]

prob = SpectralODEProblem(L, N, domain, ic, t_span, p=parameters, dt=1)#1e-1)

# Diagnostics
diagnostics = [
    ProgressDiagnostic(1000),
    ProbeAllDiagnostic([(x,0) for x in LinRange(-40,50, 10)], N=10),
    PlotDensityDiagnostic(50),
    RadialFluxDiagnostic(50),
    KineticEnergyDiagnostic(50),
    PotentialEnergyDiagnostic(50),
    EnstropyEnergyDiagnostic(50),
    GetLogModeDiagnostic(50, :ky),
    CFLDiagnostic(50),
    #RadialPotentialEnergySpectraDiagnostic(50),
    #PoloidalPotentialEnergySpectraDiagnostic(50),
    #RadialKineticEnergySpectraDiagnostic(50),
    #PoloidalKineticEnergySpectraDiagnostic(50),
]

# Output
cd(relpath(@__DIR__, pwd()))
output = Output(prob, 1001, diagnostics, "output/Bisai debug.h5",
    simulation_name=:parameters, store_locally=true)

FFTW.set_num_threads(16)

## Solve and plot
sol = spectral_solve(prob, MSS3(), output)

data = sol.simulation["fields"][:, :, :, :]
t = sol.simulation["t"][:]
default(legend=false)
anim = @animate for i in axes(data, 4)
    heatmap(data[:, :, 1, i], aspect_ratio=:equal, xaxis=L"x", yaxis=L"y", title=L"n(t=" * "$(round(t[i], digits=0)))")
end
gif(anim, "long timeseries.gif", fps=20)

send_mail("Long time series simulation finnished!", attachment="benkadda.gif")
close(output.file)