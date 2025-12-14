using Printf
using Dates


"""
    write_touchstone(filename, F, A, z0; kwargs...)

Write a Touchstone file named “filename” using the format specified in the name or in the keyword `version`.

## Arguments

- filename: name of the file.
- F: Vector of frequencies.
- A: Data to write on the Touchstone. Can be a Vector{Matrix{ComplexF64}} or a Array{ComplexF64, 3}
- z0: Number of Vector of numbers of length equal to the number of ports.


## Keywords

- version: Default to `""`. Must be a string like `"1.0"`, `"1.1"`, `"2.0"` or `"2.1"`.
- default_comments: Default to `true`. Write the comment `! Touchstone file created with TouchstoneParser.jl`
- default_date: Default to `true`. Add the Date to the file as a comment.
- funit: Default to `:GHz`. Must be a Symbol.
- ptype: Default to `:S`. Must be a Symbol.
- matrixformat: Default to `:FULL`. Can also be `:UPPER` or `:LOWER`.
- twoportorder: Default to `"12_21`. The other option is "21_12".
- noise_f: Default to `nothing`. Should be a Vector for each noise data.
- noise_data: Default to `nothing`. Should be the noise data.
- mixed_mode_order: Default to `""`.
"""
function write_touchstone(filename, F, A, z0; version = "", default_comments = true, default_date = true,
    matrixformat = :FULL, twoportorder = "12_21", noise_data = nothing, noise_f = nothing, 
    funit = :GHz, ptype = :S, format = :MA, mixed_mode_order = "")

    if !isa(z0, AbstractArray)
        z0 = [z0]
    end

    nports = size(A,1)

    # Check filename extension
    extension = split(filename, ".")[end]
    name = filename
    if lowercase(extension) == "ts"
        version = version == "" ? "2.1" : version
    else
        regex = r"^(s|y|z)(\d{1,2})p$|^(g|h)2p$"
        match_extension = match(regex, extension)
        if match_extension === nothing
            if version > "2"
                name = filename * ".ts"
            else
                name = filename * "." * lowercase(string(ptype)) * string(nports) * "p"
            end
        else
            ptype = Symbol(uppercase(string(extension[1])))
        end
    end
 
    io = open(name, "w")
    default_comments && write(io, "! Touchstone file created with TouchstoneParser.jl\n")
    default_date && write(io, "! Created on $(Dates.format(now(), "EEEE d U yyyy, HH:MM:SS")) \n")
    default_date && write(io, "! ", string(nports), "-port ", string(ptype),"-parameter data\n")

    if version > "2"
        write(io, "[Version] ", version, "\n")
    end

    

    if version > "2"
        write(io, "# ", funit, " ", ptype, " ", format, "  R ", string(z0[1]), "\n")
        write(io, "[Number of Ports] ", string(nports), "\n")
        nports == 2 && write(io, "[Two-Port Data Order] ", string(twoportorder), "\n")
        write(io, "[Number of Frequencies] ", string(length(F)), "\n")
        if !isnothing(noise_f)
            write(io, "[Number of Noise Frequencies] ", string(length(noise_f)), "\n")
        end
        if length(z0) != nports
            z0 = repeat(z0, nports)
        end
            write(io, "[Reference] ", join(z0, " "), "\n")

        if !isempty(mixed_mode_order)
            write(io, "[Mixed-Mode Order]", mixed_mode_order, "\n")
        end
        write(io, "[Network Data] \n")
    else
        if version == "1.0"
            write(io, "# ", funit, " ", ptype, " ", format, "  R ", string(z0[1]), "\n")
        else
            write(io, "# ", funit, " ", ptype, " ", format, "  R ", join(z0, " "), "\n")
        end
        write(io, "! NETWORK data \n")
    end

    lenF = length(F)
    sA = size(A)
    lenA = length(sA) == 3 ? sA[3] : sA[1]
    M = length(sA) == 3 ? eachslice(A, dims = 3) : A
    sA = length(sA) == 3 ?  sA : size(A[1])
    @assert lenF == lenA "Missmatch dimensions of frequency and data"

    for (frequency, parameters) in zip(F, M)
        write(io, @sprintf("%.5f              ", frequency))
        parameters = transpose(parameters)
        for idp_ in CartesianIndices(parameters)
            idp = CartesianIndex(idp_.I[2], idp_.I[1])
            p = parameters[idp]
            if format === :MA
                p1 = abs(p)
                p2 = angle(p) * 180 / pi
            elseif format === :DB
                p1 = 20*log10(abs(p))
                p2 = angle(p) * 180 / pi
            else
                p1 = real(p)
                p2 = imag(p)
            end

            if (matrixformat === :UPPER)
                if (idp.I[1] <= idp.I[2])
                    write(io, @sprintf("%.9f      ", p1))
                    write(io, @sprintf("%.9f              ", p2))    
                end
            elseif (matrixformat === :LOWER)
                if (idp.I[1] >= idp.I[2])
                    write(io, @sprintf("%.9f      ", p1))
                    write(io, @sprintf("%.9f              ", p2))    
                end
            else    
                write(io, @sprintf("%.9f      ", p1))
                write(io, @sprintf("%.9f              ", p2))    
            end

            if (idp.I[2] == 4) & (idp.I[1] <= sA[1])
                if !((matrixformat === :UPPER) & (idp.I[1] >= idp.I[2]))
                    write(io, "\n                     ")
                end
            elseif (idp.I[2] == sA[2]) & (idp.I[1] < sA[1])
                if !((matrixformat === :LOWER) & (idp.I[1] < idp.I[2]))
                    write(io, "\n                     ")
                else
                    if idp.I[2] - 1 == idp.I[1]
                        write(io, "\n                     ")
                    end
                end
            elseif (idp.I[2] == sA[2]) & (idp.I[1] == sA[1])
                write(io, "\n")
            else
                (idp.I[2]) % 4 == 0 && write(io, "\n")
            end
    
        end
    end

    if !isnothing(noise_f) & !isnothing(noise_data)
        if typeof(noise_data) == Vector{NoiseData}
            version >= "2" ? write(io, "[Noise Data] \n") : write(io, "! NOISE DATA \n")
            for (f, n) in zip(noise_f, noise_data)
                if format === :MA
                    p1 = abs(n.reflection)
                    p2 = angle(n.reflection) * 180 / pi
                elseif format === :DB
                    p1 = 20*log10(abs(n.reflection))
                    p2 = angle(n.reflection) * 180 / pi
                else
                    p1 = real(n.reflection)
                    p2 = imag(n.reflection)
                end
                
                Reff = version < "2" ? n.Reff/z0[1] : n.Reff
                p = (n.min_noise_figure, p1, p2, Reff)
                write(io, @sprintf("%.5f      %.5f      %.5f      %.5f      %.5f      \n", f, p...))
            end
        end
    end
    version >= "2" && write(io, "[End]\n")
    close(io)
    return nothing
end