using TouchstoneParser
using Test
using LinearAlgebra


@testset "write_touchstone" begin

    F = [1,2]
    A = [[11, 12, 13, 14, 15, 16];;
         [21, 22, 23, 24, 25, 26];;
         [31, 32, 33, 34, 35, 36];; 
         [41, 42, 43, 44, 45, 46];; 
         [51, 52, 53, 54, 55, 56];; 
         [61, 62, 63, 64, 65, 66] 
         ] |> x -> Complex.(x)
    A = [A;;;A]
    
    TouchstoneParser.write_touchstone("testfile.ts", F, A, 50, default_comments = false, version = "2.0", default_date = false)
    ts = TouchstoneParser.read_touchstone("testfile.ts")
    @test ts.data == A
    
    TouchstoneParser.write_touchstone("testfile2.s6p", F, A, 50, default_comments = false, version = "1.0", default_date = false)
    s6p = TouchstoneParser.read_touchstone("testfile2.s6p")
    @test s6p.data == A

    ex18 = TouchstoneParser.read_touchstone("../Examples/Example18.ts")
    TouchstoneParser.write_touchstone("Example18_2.ts", ex18.frequency, ex18.data, ex18.references; version = "2.1", 
        noise_data = ex18.noise_data, noise_f = ex18.noise_frequency, twoportorder = "21_12")
    newex18 = TouchstoneParser.read_touchstone("./Example18_2.ts")
    
    ex19 = TouchstoneParser.read_touchstone("../Examples/Example19.s2p")
    TouchstoneParser.write_touchstone("Example19_2.s2p", ex18.frequency, ex18.data, ex18.references; version = "1.0", 
        noise_data = ex19.noise_data, noise_f = ex18.noise_frequency, twoportorder = "21_12")
    newex19 = TouchstoneParser.read_touchstone("./Example19_2.s2p")
    
    @test ex18.data == newex18.data
    @test ex19.data == newex19.data
    
    @test ex18.noise_data == newex18.noise_data
    @test ex19.noise_data == newex19.noise_data

end

# Z parameter
@testset "Example8.ts" begin
    ex8 = TouchstoneParser.read_touchstone("../Examples/Example8.ts")
    @test ex8.type === :Z
end


@testset "LOWER format" begin
    ex6 = TouchstoneParser.read_touchstone("../Examples/Example6.ts")
    ex7 = TouchstoneParser.read_touchstone("../Examples/Example7.ts")

    values_6 = ex6.data
    values_7 = ex7.data

    @test ex6.matrixformat == :FULL
    @test ex7.matrixformat == :LOWER
    @test values_6 == values_7

end

@testset "Example15.s4p" begin # Page 17 - Touchstone File Format Specification
    ex15 = TouchstoneParser.read_touchstone("../Examples/Example15.s4p")
    #ex15 = TouchstoneParser.read_touchstone("../Examples/Example15.s4p")

    optionline = "# " * string(ex15.units) * " " * string(ex15.type) * " " * string(ex15.format) * " R " *  join(Int.(ex15.resistance)," ")

    @test ex15.comments[1] == (1, "! 4-port S-parameter data, taken at three frequency points")
    @test ex15.comments[2] == (2, "! note that data points need not be aligned")
    @test optionline == uppercase("# GHz S MA R 50")
    @test ex15.frequency == [5.0, 6.0, 7.0]
    values = ex15.data
    @test (abs(values[1,3,1]), angle(values[1,3,1])*180/pi) == (0.42, -66.58) #S13 at 5.0 GHz
    @test (abs(values[4,2,3]), angle(values[4,2,3])*180/pi) == (0.37, -99.09) #S42 at 7.0 GHz
end


# Parse Mixed Mode Order and ignore second option line when there is more than one.
@testset "Example17.ts" begin # Page 17 - Touchstone File Format Specification
    ex17 = TouchstoneParser.read_touchstone("../Examples/Example17.ts")
    # ex17 = TouchstoneParser.read_touchstone("../Examples/Example17.ts")

    optionline = "# " * string(ex17.units) * " " * string(ex17.type) * " " * string(ex17.format) * " R " *  join(Int.(ex17.resistance)," ")

    @test ex17.comments[1] == (1, "! 6-port component shown; note that all six ports are used in some")
    @test ex17.comments[2] == (2, "! relationship")
    @test ex17.version == "2.1"
    @test ex17.n_ports == 6
    @test ex17.n_freqs == 1
    @test optionline == uppercase("# MHz Y RI R 50")
    @test ex17.references == Float64.([50, 150, 37.5, 50.0, 0.02, 0.005])
    @test ex17.frequency == [5.0]
    @test ex17.mixed_mode_order == "D2,3 D6,5 C2,3 C6,5 S4 S1"
end


# Noise Parameters v1.0 and 2.1

@testset "Example19.s2p" begin # Page 26 - Touchstone File Format Specification
    ex19 = TouchstoneParser.read_touchstone("../Examples/Example19.s2p")
    #ex19 = TouchstoneParser.read_touchstone("../Examples/Example19.s2p")

    optionline = "# " * string(ex19.units) * " " * string(ex19.type) * " " * string(ex19.format) * " R " *  join(Int.(ex19.resistance)," ")

    default_optionline = "# GHZ S MA R 50"

    @test ex19.comments[1] == (1, "! 2-port network, S-parameter and noise data")
    @test ex19.comments[2] == (2, "! Default MA format, GHz frequencies, 50-ohm reference, S-parameters")
    @test ex19.version == "1.0"
    @test optionline == default_optionline

    @test ex19.frequency == [2.0, 22.0]
    values = ex19.data
    @test (abs(values[2,2,2]), angle(values[2,2,2])*180/pi) == (0.56, -85.0) #S22 at 22.0 GHz

    @test ex19.noise_frequency == [4.0, 18.0]
    noise_values = ex19.noise_data
    @test ex19.noise_data[1].Reff/ex19.resistance[1] == 0.38
    @test ex19.noise_data[2].Reff/ex19.resistance[1] == 0.40

    source_reflection = ex19.noise_data[1].reflection
    @test abs(source_reflection) ≈ 0.64
    @test angle(source_reflection)*180/pi ≈ 69 

    noise_figure = ex19.noise_data[2].min_noise_figure
    @test noise_figure == 2.7

end

@testset "Example20.ts" begin # Page 26 - Touchstone File Format Specification
    ex20 = TouchstoneParser.read_touchstone("../Examples/Example20.ts")
    #ex20 = TouchstoneParser.read_touchstone("../Examples/Example20.ts")

    optionline = "# " * string(ex20.units) * " " * string(ex20.type) * " " * string(ex20.format) * " R " *  join(Int.(ex20.resistance)," ")

    default_optionline = "# GHZ S MA R 50"

    @test ex20.comments[1] == (1, "! 2-port network, S-parameter and noise data")
    @test ex20.comments[2] == (2, "! Default MA format, GHz frequencies, 50-ohm reference, S-parameters")
    @test ex20.version == "2.1"
    @test optionline == default_optionline

    @test ex20.n_ports == 2
    @test ex20.n_freqs == 2
    @test ex20.n_noisefreqs == 2

    @test ex20.frequency == [2.0, 22.0]
    values =ex20.data
    @test (abs(values[2,2,2]), angle(values[2,2,2])*180/pi) == (0.56, -85.0) #S22 at 22.0 GHz

    @test ex20.noise_frequency == [4.0, 18.0]
    noise_values = ex20.noise_data
    @test ex20.noise_data[1].Reff == 19
    @test ex20.noise_data[2].Reff == 20

    source_reflection = ex20.noise_data[1].reflection
    @test abs(source_reflection) ≈ 0.64
    @test angle(source_reflection)*180/pi ≈ 69 

    noise_figure = ex20.noise_data[2].min_noise_figure
    @test noise_figure == 2.7

end


# Round-Trip tests for Matrix transformations
using LinearAlgebra: norm
@testset "Transformations" begin

    N = 10;
    S = rand(ComplexF64, N, N);
    Z0 = rand(N, );
    
    threshold = 1.0e-10

    @test norm(S - TouchstoneParser.y_to_s_stable(TouchstoneParser.s_to_y_stable(S, Z0), Z0)) <= threshold
    @test norm(S - TouchstoneParser.TouchstoneParser.y_to_s_alternative(TouchstoneParser.s_to_y_stable(S, Z0), Z0)) <= threshold

    @test norm(S - TouchstoneParser.s_to_y_stable(TouchstoneParser.y_to_s_stable(S, Z0), Z0)) <= threshold
    @test norm(S - TouchstoneParser.s_to_y_stable(TouchstoneParser.y_to_s_alternative(S, Z0), Z0)) <= threshold

    @test norm(S - TouchstoneParser.z2s(TouchstoneParser.s2z(S, Z0), Z0)) <= threshold
    @test norm(S - TouchstoneParser.z2s(TouchstoneParser.s_to_z_stable(S, Z0), Z0)) <= threshold
    
    @test norm(S - TouchstoneParser.s2z(TouchstoneParser.z2s(S, Z0), Z0)) <= threshold
    @test norm(S - TouchstoneParser.s_to_z_stable(TouchstoneParser.z2s(S, Z0), Z0)) <= threshold

end

@testset "Transformations2" begin
    ex = TouchstoneParser.read_touchstone("../Examples/Spiral_Inductor_Microstrip_Spiral.s2p")
    m1 = map((s,z) -> TouchstoneParser.s2z(s,z), eachslice(ex.data, dims = 3), eachcol(ex.z0))
    m2 = similar(ex.data)
    for z in 1:length(ex.frequency)
        m2[:,:,z] .= @views TouchstoneParser.s2z(ex.data[:,:, z], ex.z0[:, z])
    end
    @test stack(m1) == m2
end
