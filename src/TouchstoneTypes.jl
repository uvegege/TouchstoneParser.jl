
struct NoiseData
    min_noise_figure::Float64 #dB
    reflection::Complex{Float64}
    Reff::Float64
end

mutable struct TSParser
    version::String
    n_ports::Int

    # Option line
    type::Symbol
    format::Symbol
    resistance::Vector{Float64}
    units::Symbol

    # Keyword Options
    n_freqs::Int
    n_noisefreqs::Int
    references::Vector{Float64}
    twoport_order::String
    mixed_mode_order::String 
    matrixformat::Symbol
    info::Vector{String}

    #Data
    frequency::Vector{Float64}
    v::Vector{Matrix{Complex{Float64}}}
    noise_frequency::Vector{Float64}
    noise_data::Vector{NoiseData}
    # HFSS version?
    # Does CST Studio does something similar?
    # Other softwares?
    comments::Vector{Tuple{Int, String}}
end
#TODO: Revisar si el orden por defecto es "12_21" o "21_12" 
TSParser() = TSParser("1.0", 0, :S, :MA, [50], :GHZ, 0, 0, Float64[], 
                          "12_21", "", :FULL, String[],  Float64[], Matrix{Complex{Float64}}[], 
                          Float64[], NoiseData[], String[])



mutable struct ParserState
    count_line::Int
    found_version::Tuple{Int,Bool}
    found_optionline::Tuple{Int,Bool}
    found_nports::Tuple{Int,Bool}
    found_twoport_order::Tuple{Int,Bool}
    found_nfreqs::Tuple{Int,Bool}
    found_n_noisefreq::Tuple{Int,Bool}
    found_mixedmode_order::Tuple{Int,Bool}
    found_reference::Tuple{Int,Bool}
    found_info::Tuple{Int,Bool}
    found_networkdata::Tuple{Int,Bool}
    found_noisedata::Tuple{Int,Bool}
    found_hfss_gamma::Tuple{Int,Bool}
    found_hfss_portimpedance::Tuple{Int,Bool}
    found_hfss_port::Tuple{Int,Bool}
    found_hfss_terminaldata::Tuple{Int,Bool}
    found_hfss_modaldata::Tuple{Int,Bool}
end
ParserState() = ParserState(0, ntuple(i->(0, false), fieldcount(ParserState)-1)...)
newline!(x::ParserState) = (x.count_line += 1)

function Base.show(io::IO, ::MIME"text/plain", ps::ParserState)
    for v in fieldnames(ParserState)
        valor = (getfield(ps, v))
        println("$v : $valor")
    end
    return nothing
end


struct Touchstone{T} 
    f::Vector{Float64}
    data::Array{ComplexF64, 3}
    noise_f::Vector{Float64}
    noise_data::Vector{NoiseData}
end

#TODO: add mixedmode doing something like Touchstone{:S}, Touchstone{:Smm} for mixed mode

