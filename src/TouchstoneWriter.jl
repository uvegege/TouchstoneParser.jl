using Printf
using Dates

function write_touchstone(filename, F, A, z0; version = "", default_comments = true, default_date = true,
    matrixformat = :FULL, twoportorder = "12_21", noise_data = nothing, noise_f = nothing, 
    funit = :GHz, ptype = :S, format = :RI, mixed_mode_order = "")

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
        write(io, "[Number of Ports] ", string(nports), "\n")
        nports == 2 && write(io, "[Two-Port Data Order] ", string(twoportorder), "\n")
        write(io, "[Number of Frequencies] ", string(length(F)), "\n")
        if length(z0) != nports
            z0 = repeat(z0, nports)
            write(io, "[Reference] \n", join(z0, " "), "\n")
        end
        write(io, "# ", funit, " ", ptype, " ", format, "  R ", join(z0," "), "\n")
        if !isempty(mixed_mode_order)
            write(io, "[Mixed-Mode Order]", mixed_mode_order)
        end
        write(io, "[Network Data] \n")
    else
        write(io, "# ", funit, " ", ptype, " ", format, "  R ", join(z0," "), "\n")
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
                p2 = angle(p)
            elseif format === :DB
                p1 = 20*log10(abs(p))
                p2 = angle(p)
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

    # Write noise data: Need Tests
    if !isnothing(noise_f) & !isnothing(noise_data)
        for (f, p) in zip(noise_f, noise_data)
            write(io, @sprintf("%.5f      %.5f      %.5f      %.5f      %.5f      \n", f, p...))
        end
    end

    close(io)
    return nothing
end