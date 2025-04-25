## Run all (alt+enter)
include(relpath(pwd(), @__DIR__) * "/src/HasegawaWakatini.jl")

## Run scheme test for Burgers equation
domain = Domain(128, 128, 100, 100, anti_aliased=true)
ic = initial_condition_linear_stability(domain, 1e-3)

plot(ic[:,:,1])

# Linear operator
function L(u, d, p, t)
    D_n = p["D_n"] .* diffusion(u, d)
    D_Ω = p["D_Ω"] .* diffusion(u, d)
    [D_n;;; D_Ω]
end

# Non-linear operator, linearized
function N(u, d, p, t)
    n = @view u[:, :, 1]
    Ω = @view u[:, :, 2]
    ϕ = solvePhi(Ω, d)

    dn = -poissonBracket(ϕ, n, d)
    dn .-= (p["kappa"] - p["g"]) * diffY(ϕ, d)
    dn .-= p["g"] * diffY(n, d)
    dn .-= p["sigma_n"] * n

    dΩ = -poissonBracket(ϕ, Ω, d)
    dΩ .-= p["g"] * diffY(n, d)
    dΩ .+= p["sigma_Ω"] * ϕ
    return [dn;;; dΩ]
end

# # Non-linear operator, fully non-linear
# function N(u, d, p, t)
#     n = u[:, :, 1]
#     W = u[:, :, 2]
#     phi = solvePhi(W, d)
#     dn = -poissonBracket(phi, n, d)
#     dn += p["g"] * quadraticTerm(n, diffY(n, d), d)
#     dn += -p["g"] * diffY(n, d)
#     dn += -p["sigma"] * n
#     dW = -poissonBracket(phi, W, d)
#     #dW += -p["g"] * diffY(spectral_log(n, d), d)
#     dW += -p["g"] * quadraticTerm(reciprocal(n, d), diffY(n, d), d)
#     dW += n
#     dW += -quadraticTerm(n, spectral_exp(phi, d), d)
#     [dn;;; dW]
# end

# Parameters
parameters = Dict(
    "D_Ω" => 1e-2,
    "D_n" => 1e-2,
    "g" => 1e-3,
    "sigma_Ω" => 1e-3,
    "sigma_n" => 1e-3,
    "kappa" => sqrt(1e-1)
)

t_span = [0, 5000000]

prob = SpectralODEProblem(L, N, domain, ic, t_span, p=parameters, dt=1e-1)

# Diagnostics
diagnostics = [
    ProgressDiagnostic(1000),
    ProbeDensityDiagnostic((0, 0), N=100),
    #PlotDensityDiagnostic(50),
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
output = Output(prob, 1001, diagnostics, "output/sheath-interchange long time series.h5",
    simulation_name=:parameters, store_locally=false)

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