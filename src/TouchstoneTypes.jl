
"""
    NoiseData

## Fields

    min_noise_figure::Float64 in dB
    reflection::Complex{Float64}
    Reff::Float64
"""
struct NoiseData
    min_noise_figure::Float64 #dB
    reflection::Complex{Float64}
    Reff::Float64
end

mutable struct ParserState
    count_line::Int
    found_version::Tuple{Int,Bool}
    found_optionline::Tuple{Int,Bool}
    found_nports::Tuple{Int,Bool}
    found_twoport_order::Tuple{Int,Bool}
    found_nfreqs::Tuple{Int,Bool}
    found_n_noisefreq::Tuple{Int,Bool}
    found_mixedmode_order::Tuple{Int,Bool}
    found_matrixformat::Tuple{Int,Bool}
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

ParserState() = ParserState(0, ntuple(i -> (0, false), fieldcount(ParserState) - 1)...)
newline!(x::ParserState) = (x.count_line += 1)
seekline!(x::ParserState) = (x.count_line -= 1)
function Base.show(io::IO, ::MIME"text/plain", ps::ParserState)
    for v in fieldnames(ParserState)
        valor = (getfield(ps, v))
        println("$v : $valor")
    end
    return nothing
end

"""
    TSParser

Struct containing the data of the parsed Touchstone file.

### File name

    filename::String

### Settings

    version::String
    n_ports::Int

### Option line field

    type::Symbol
    format::Symbol
    resistance::Vector{Float64}
    units::Symbol

### Keyword Options

    n_freqs::Int
    n_noisefreqs::Int
    references::Vector{Float64}
    twoport_order::String
    mixed_mode_order::String
    matrixformat::Symbol
    info::Vector{String}

### Data

    frequency::Vector{Float64}
    data::Array{ComplexF64, 3}
    noise_frequency::Vector{Float64}
    noise_data::Vector{NoiseData}
    z0::Matrix{ComplexF64}

### HFSS version: This section uses # https://github.com/scikit-rf/scikit-rf/blob/master/skrf/io/ts.py as reference.

    hfss_data_type::Symbol
    hfss_gamma::Vector{ComplexF64}
    hfss_impedance::Vector{ComplexF64}
    gamma::Matrix{ComplexF64}

### Comments

    comments::Vector{Tuple{Int,String}}

### debug and utils
    port_names::Vector{String}
    pstate::TouchstoneParser.ParserState

"""
mutable struct TSParser

    # File name
    filename::String

    # Settings
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
    data::Array{ComplexF64, 3}
    noise_frequency::Vector{Float64}
    noise_data::Vector{NoiseData}
    z0::Matrix{ComplexF64}

    # HFSS version
    hfss_data_type::Symbol
    hfss_gamma::Vector{ComplexF64}
    hfss_impedance::Vector{ComplexF64}
    gamma::Matrix{ComplexF64}

    # Comments
    comments::Vector{Tuple{Int,String}}

    # debug and utils
    port_names::Vector{String}
    pstate::ParserState

end

#TODO: Revisar si el orden por defecto es "12_21" o "21_12" 
TSParser() = TSParser("", "1.0", 0, :S, :MA, [50], :GHZ, 0, 0, Float64[],
    "12_21", "", :FULL, String[], Float64[], [;;;],
    Float64[], NoiseData[], ComplexF64[;;],
    :unknown, ComplexF64[], ComplexF64[], ComplexF64[;;], # HFSS
    String[], String[], ParserState())
TSParser(file) = TSParser(file, "1.0", 0, :S, :MA, [50], :GHZ, 0, 0, Float64[],
    "12_21", "", :FULL, String[], Float64[], [;;;],
    Float64[], NoiseData[], ComplexF64[;;],
    :unknown, ComplexF64[], ComplexF64[], ComplexF64[;;], # HFSS
    String[], String[], ParserState())


function Base.show(io::IO, ::MIME"text/plain", ts::TSParser)

    println("-- Filename: ", ts.filename)
    println(" -- Version: ", ts.version)
    println(" -- ", ts.type, "-parameters")
    println(" -- Number of ports: ", ts.n_ports)
    if isempty(ts.frequency)
        println(" -- 0 frequency points")
    else
        println(" -- ", minimum(ts.frequency), " - ", maximum(ts.frequency), " ", ts.units, " with ", ts.n_freqs > 0 ? ts.n_freqs : length(ts.frequency), " frequency points")
    end

    #optionline = "# " * string(ts.units) * " " * string(ts.type) * " " * string(ts.format) * " R " *  join(Int.(ts.resistance)," ")
    #println(" -- Option line: ", optionline)
    if !isempty(ts.references)
        println(" -- Reference Impedance: ", ts.references)
    end

    if !isempty(ts.mixed_mode_order)
        println(" -- Mixed Mode Order: ", ts.mixed_mode_order)
    end

    if ts.hfss_data_type != :unknown
        println(" -- HFSS Style Touchstone")
    end

    println("")
    println(" -- Network Data:")
    display(ts.data)

    if !isempty(ts.noise_data)
        println("")
        println(" -- Network Noise Data with ", ts.n_noisefreqs, "frequency points: ")
        display(ts.noise_data)
    end

    return nothing
end

