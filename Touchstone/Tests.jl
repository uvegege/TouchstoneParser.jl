cd("C:\\Users\\Víctor\\Documents\\MiProyecto\\Touchstone")

# begin
#     ts, ps = readfile("./Ex_touch/test1.s2p")
#     println("Expected:")
#     println("MHZ, S, MA, [50], n_ports = 2, version = 1.x")
#     @show (ts.units, ts.type, ts.format, ts.resistance, ts.n_ports, ts.version)
# end

begin
ts, ps = readfile("./Ex_touch/test1a.s3p")
println("Expected:")
println("KHZ, Y, DB, [43.5, 41.5, 66.4], n_ports = 3, version = 1.1")
@show (ts.units, ts.type, ts.format, ts.resistance, ts.n_ports, ts.version)
end

begin
    ts, ps = readfile("./Ex_touch/test1b.s3p")
    println("Expected:")
    println("KHZ, Z, DB, [41.5, 66.4], n_ports = 2, version = 1.1")
    @show (ts.units, ts.type, ts.format, ts.resistance, ts.n_ports, ts.version)
end

begin
    ts, ps = readfile("./Ex_touch/test2.ts")
    println("Expected:")
    println("GHZ, Y, DB, [1], n_ports = 2, version = 2.0")
    @show (ts.units, ts.type, ts.format, ts.resistance, ts.n_ports, ts.version)

    println("Found [Version] = $(ps.found_version), value = $(ts.version)")
    println("Found [Number of Ports] = $(ps.found_nports), value = $(ts.n_ports)")
    println("Found [Two-Port Data Order] = $(ps.found_twoport_order), value = $(ts.twoport_order)")
    println("Found [Number of frequencies] = $(ps.found_nfreqs), value = $(ts.n_freqs)")
end

using BenchmarkTools
#ts, ps = readfile("./Ex_touch/test4.ts")
tsa, psa = readfile("./Examples/Example19.s2p")
tsb, psb = readfile("./Examples/Example20.ts")
tsa.noise_data
tsb.noise_data
tsa.v
tsb.v

@btime readfile("./Ex_touch/test4.ts")
tsb, psb = readfile("./Ex_touch/test4.ts");
sparams = tsb.v
s11 = getindex.(sparams, 1, 1)
s21 = getindex.(sparams, 2, 1)
f = tsb.frequency
using GLMakie
lines(f, 20log10.(abs.(s11)))
lines!(f, 20log10.(abs.(s21)))
