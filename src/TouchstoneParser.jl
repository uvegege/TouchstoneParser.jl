module TouchstoneParser

export read_touchstone, write_touchstone
export s2h, s2g, h2s, g2s, h2g, g2h, s2y, y2s, y2s_alternative, s2z, s2z_alternative, z2s
export TSParser, NoiseData
export simvariables, comments_after_option_line

include("./TouchstoneTypes.jl")
include("./Utils.jl")
include("./Transformations.jl")
include("./ParserFunctions.jl")
include("./TouchstoneReader.jl")
include("./TouchstoneWriter.jl")


using PrecompileTools

@setup_workload begin
    f = [2.0, 22.0]
    S = [
        [[0.95 * cis(deg2rad(-26)), 3.57 * cis(deg2rad(157))];;
        [0.04 * cis(deg2rad(76 )), 0.66 *cis(deg2rad(-14))]], 
        [[0.60 * cis(deg2rad(-144 )), 1.30 * cis(deg2rad(40))];;
        [0.14 * cis(deg2rad(40)), 0.56 * cis(deg2rad(-85))]]
    ]

    z0 = [50, 25.0]
    noise_f = [4.0, 18.0]
    noise_data = [NoiseData(0.7, 0.64 * cis(deg2rad(69)), 19), NoiseData(0.7, 0.46 * cis(deg2rad(-33)), 20)]

    @compile_workload begin
        TouchstoneParser.write_touchstone("Example.s2p", f, S, z0; 
        version = "1.0", noise_data = noise_data, noise_f = noise_f, twoportorder = "21_12")
        TouchstoneParser.write_touchstone("Example.ts", f, S, z0; 
        version = "2.1", noise_data = noise_data, noise_f = noise_f, twoportorder = "21_12")
    end
end

end


