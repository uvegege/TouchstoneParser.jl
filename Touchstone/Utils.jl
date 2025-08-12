to_values(a, b, ::Val{:MA}) = a * cis(deg2rad(b)) #Complex(a * cos(deg2rad(b)), -a * sin(deg2rad(b)))
to_values(a, b, ::Val{:DB}) = 10.0^(a/20.0) * cis(deg2rad(b)) #Complex(10.0^(a/20.0) * cos(deg2rad(b)), 10.0^(a/20.0) * sin(deg2rad(b)))
to_values(a, b, ::Val{:RI}) = Complex(a, b)

function find_units(line) 
    a = match(r"(?<A>KHZ|MHZ|GHZ|THZ)", line)
    !isnothing(a) ? (return Symbol(something(a)[:A])) : (return :GHZ)
end

function find_Ri(line) 
    a = match(r"(?<Ri>(?:\d+(?:\.\d+)?\s*)+)", line)
    !isnothing(a) ? (return parse.(Float64,split(something(a)[:Ri]))) : (return [50.0])
end

function find_type(line) 
    a = match(r"\b(?<B>S|Z|Y|H|G)\b", line)
    !isnothing(a) ? (return Symbol(something(a)[:B])) : (return :S)
end

function find_format(line) 
    a = match(r"\b(?<C>MA|DB|RI)\b", line)
    !isnothing(a) ? (return Symbol(something(a)[:C])) : (return :MA)
end

function line_to_matrix(line_buffer, ts)
    b = reshape(line_buffer, 2, div(length(line_buffer),2))
    #values = [to_values(p1, p2, Val(ts.format)) for (p1, p2) in eachcol(b) if (p1, p2) != (0.0, 0.0)]
    values = [to_values(p1, p2, Val(ts.format)) for (p1, p2) in eachcol(b)]
    n = length(values)
    if ts.matrixformat != :FULL
        s = round(Int,(sqrt(8*n+1)-1)/2)
        s*(s+1)/2 == n || error("length of vector is not triangular")
        idx = 1
        mvals = zeros(s,s)
        for i in 1:s
            for j in i:s
                mvals[i, j] = values[idx]
                mvals[j, i] = values[idx]
                idx += 1
            end
        end
    else # Full
        s = Int(sqrt(n))
        mvals = reshape(values, s, s)
    end
    if (ts.twoport_order == "12_21") & (ts.n_ports == 2)
        mvals = permutedims(mvals)
    end
    return mvals
end

function num_vals(ts)
    if ts.version < "1.x"
        num_values = ts.n_ports != 0 ? 2*ts.n_ports^2+1 : 0
    else
        num_values = uppercase(ts.matrixformat) != :FULL ? ts.n_ports^2+ts.n_ports+1 : 2*ts.n_ports^2 + 1
    end
end

function infere_n_ports(stored_lengths, length_line, ts, line_buffer)
    push!(stored_lengths, length_line)
    isempty(line_buffer) && resize!(line_buffer, length(line_buffer)-1)
    if length(stored_lengths) > 1
        num_values = stored_lengths[1]
        for v in Iterators.drop(stored_lengths,1)
            if v == stored_lengths[1]
                break
            else
                num_values += v
            end
        end
        resize!(line_buffer, num_values-1)
    end
    n_ports = uppercase(ts.matrixformat) != :FULL ? (-1 + Int(sqrt(1+4*(num_values-1))))/2 : Int(sqrt((num_values-1)/2))
    ts.n_ports = n_ports
    return n_ports
end


function process_extension!(ts, ps, file)
    # Use the file extension to identify the version and port number?
    extension = split(file, ".")[end]
    if lowercase(extension) == "ts"
        ts.version = "2.x"
    else
        regex = r"^(s|y|z)(\d{1,2})p$|^(g|h)2p$"
        match_extension = match(regex, extension)
        if match_extension !== nothing
            match_number = match(r"(?<=[a-zA-Z])(\d{1,2})(?=p)", extension)
            ts.n_ports = parse(Int, match_number.match)
            ps.found_nports = (0, true)
            ts.version = "1.0"
            ts.type = Symbol(uppercase(string(extension[1])))
        else
            #ps.unknown_extension = true
            @warn "Extension not found or not usual. Will try to parse the file."
        end
    end
    return 
end

function verify_touchstone(ts, ps, file, f)

    if ts.version >= "2.0"
        required = (:found_version, :found_optionline, :found_nports, :found_nfreqs, :found_networkdata)
        conditional_required = (:found_twoport_order, :found_n_noisefreq, :found_noisedata)
        optional = (:found_optionline, :found_mixedmode_order, :found_reference, :found_info)
        hfss_style = (:found_hfss_gamma, :found_hfss_portimpedance, :found_hfss_port, :found_hfss_terminaldata, :found_hfss_modaldata)
        
        # H and G only with 2 ports
        # All optional should appear after optionline
        # twoport order solo aparece si es un dispositivo de 2 puertos
        # Number of noise frequencies no puede aparecer si no hay [noise data]
        # Las frecuencias deben aparecer en order
        # Comprobar mixedmode tags
        # length(reference) == n_ports

    end

end