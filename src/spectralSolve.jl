include("fftutilities.jl")

export spectralSolve

# Assuming for now that dt is fixed
# If custom outputter is not provided, then resort to default
# First step is stored during initilization of output
function spectral_solve(prob::SpectralODEProblem, scheme=MSS3(), output=Output(prob, 100))
    # Initialize cache
    cache = get_cache(prob, scheme)

    # Auxilary variables
    dt = prob.dt
    t = first(prob.tspan)
    step = 0

    # Calculate number of steps
    total_steps = floor(Int, (last(prob.tspan) - first(prob.tspan)) / dt)

    try
        # This method assumes step number does not overflow!
        while step < total_steps
            perform_step!(cache, prob, t)

            # Increment step and time 
            step += 1
            # TODO add time tracking to perform_step?
            t += dt

            handle_output!(output, step, cache.u, prob, t)
            sleep(1e-10000000000000) #To be able to interupt simulation
        end
    catch error
        # Here store the last 3 steps to be able to resume simulations after interupt
        println(error.msg)
        #rethrow(error)
    end
    # TODO catch edge case and close file

    # Returns output struct
    return output
end