# IS FUNCTIONS

is_line(line) = occursin(r"^[#!\[]", line)
is_comment(line) = startswith(line, "!") 
is_optionline(line) = startswith(line, "#") 
is_version(line) = startswith(line, "[Version]")
is_nports(line) = startswith(line, "[Number of Ports]")
is_matrixformat(line) = startswith(line, "[Matrix Format]")
is_twoport_order(line) = startswith(line, "[Two-Port Data Order]")
is_n_freqs(line) = startswith(line, "[Number of Frequencies]")
is_noise_freqs(line) = startswith(line, "[Number of Noise Frequencies]")
is_reference(line) = startswith(line, "[Reference]")
is_mixedmode_order(line) = startswith(line, "[Mixed-Mode Order]")
is_begininfo(line) = startswith(line, "[Begin Information]")
is_endininfo(line) = startswith(line, "[End Information]")
is_networkdata(line) = startswith(line, "[Network Data]")
is_noisedata(line) = startswith(line, "[Noise Data]")
is_endfile(line) = startswith(line, "[End]")
# https://github.com/scikit-rf/scikit-rf/blob/master/skrf/io/ts.py
is_hfss_gamma(line) = startswith(lowercase(line), "! gamma") 
is_hfss_portimpedance(line) = startswith(lowercase(line), "! port impedance") 
is_hfss_port(line) = startswith(lowercase(line), "! port") 
is_hfss_terminaldata(line) = startswith(lowercase(line), "! terminal data exported") 
is_hfss_modaldata(line) = startswith(lowercase(line), "! modal data exported") 

# GET FUNCTIONS
function get_comment(ps, ts, line, f)

    is_hfss_gamma(line) && return  
    is_hfss_portimpedance(line) && return
    
    f_hfss_port(ps, ts, line, f) 
    f_hfss_modaldata(ps, ts, line, f) 
    f_hfss_terminaldata(ps, ts, line, f)

    push!(ts.comments, (ps.count_line, line))
    return nothing
end

function get_version(ps, ts, line, f)
    ps.found_version = (ps.count_line, true)
    ts.version = split(line)[end]
    return nothing
end

function get_optionline(ps, ts, line, f)
    # Page 6. Each Touchstone data file shall contain an option line 
    # (additional option lines after the first one shall be ignored)
    if ps.found_optionline[2] == true
        return
    end
    line = uppercase(line)
    ps.found_optionline = (ps.count_line, true)
    units = find_units(line)
    format = find_format(line)
    type = find_type(line)
    R = find_Ri(line)
    if length(R) > 1 # Version 1.1
        ts.n_ports = length(R)
        ts.version = "1.1"
        ps.found_version = (ps.count_line, true) 
        ps.found_nports = (ps.count_line, true) 
    end
    #ts.optionline = (frequency = units, type = type, format = format, R = R)
    ts.format = format
    ts.resistance = R
    ts.type = type
    ts.units = units
    return 
end

function get_nports(ps, ts, line, f)
    ps.found_nports = (ps.count_line, true)
    ts.n_ports = parse(Int, split(line)[end])
    return 
end

function get_twoport_order(ps, ts, line, f)
    ps.found_twoport_order = (ps.count_line, true)
    ts.n_ports == 2 || @warn "Keyword [Two-Port Data Order] is only permitted when [Number of Ports] keyword is 2."
    value = split(split(line, "!")[1])[end]
    ts.twoport_order = value in ("12_21", "21_12") ? value : "12_21"
    return nothing
end

function get_n_freqs(ps, ts, line, f)
    ps.found_nfreqs = (ps.count_line, true)
    ts.n_freqs = parse(Int, split(split(line, "!")[1])[end])
    sizehint!(ts.frequency, ts.n_freqs)
    return nothing
end

function get_noise_freqs(ps, ts, line, f)
    ps.found_n_noisefreq = (ps.count_line, true)
    ts.n_noisefreqs = parse(Int, split(split(line, "!")[1])[end])
    sizehint!(ts.noise_frequency, ts.n_noisefreqs)
    sizehint!(ts.noise_data, ts.n_noisefreqs)
    return nothing
end

function get_reference(ps, ts, line, f)
    ps.found_reference = (ps.count_line, true)
    n_ports = ts.n_ports
    references = zeros(Float64, n_ports, )
    read_keyword_line = split(split(line, "!")[1])
    id_ref = 0
    for v in Iterators.drop(read_keyword_line,1)
        id_ref += 1
        references[id_ref] = parse(Float64, v)
    end
    while !eof(f) & (id_ref != n_ports) # Reference can split in multiple lines.
        #if id_ref != n_ports 
        new_line = readline(f); newline!(ps)
        new_line_ref = split(split(new_line, "!")[1])
        for v in new_line_ref
            id_ref += 1
            references[id_ref] = parse(Float64, v)
        end
    end
    ts.references = references
    return nothing
end

function get_matrixformat(ps, ts, line, f)
    ps.found_matrixformat = (ps.count_line, true)
    value = Symbol(split(uppercase(split(line, "!")[1]))[end])
    if value in (:FULL, :LOWER, :UPPER)
        ts.matrixformat = value
    else
        @warn "The value read from [Matrix Format] does not match Full, Upper or Lower. Default to Full"
        ts.matrixformat = :FULL
    end
    return nothing
end

function get_mixedmode_order(ps, ts, line, f)
    ps.found_mixedmode_order = (ps.count_line, true)
    mixed_mode_orders = split(line)[3:end]
    dict_vals = Dict(:C => Set{Tuple{Int, Int}}(), :D => Set{Tuple{Int, Int}}(), :S => Set{Int}())
    if length(mixed_mode_orders) == ts.n_ports
        for mmo in mixed_mode_orders
            key = Symbol(uppercase(mmo[1]))
            if key === :C
                push!(dict_vals[key], tuple(parse.(Int, split(mmo[2:end],","))...))
            elseif key === :D
                push!(dict_vals[key], tuple(parse.(Int, split(mmo[2:end],","))...))
            elseif key === :S
                push!(dict_vals[key], parse(Int, mmo[2]))
            else 
                @warn "Descriptor of [Mixed-Mode Order] different to :C, :D or :S"
                return nothing
            end
        end
        #Check that Di,j and Ci,j exists and check that ids in S dont appear in C or D
        valsD = collect(dict_vals[:D])
        valsC = collect(dict_vals[:C])
        valsS = collect(dict_vals[:S])
        if !all(in.(valsC, Ref(valsD)))
            @warn "If a common-mode descriptor is present between ports, a differential-mode descriptor must also be present between those same ports, and vice-versa."
        end
        if any(in.(valsS, valsC))
            @warn "Each port number must appear in either one single-ended or two mixed-mode descriptors." 
        end
        ts.mixed_mode_order = join(mixed_mode_orders," ")
    else
        @warn "Number of values of [Mixed-Mode Order] shall match [Number of Ports]"
    end
    return nothing
end

function get_info(ps, ts, line, f)
    ps.found_info = (ps.count_line, true)
    while !eof(f) & (lowercase(line) != ["end information"])
        line = readline(f); newline!(ps)
        push!(ts.info, line)
    end
    return nothing
end

function get_networkdata(ps, ts, line, f)
    if ts.version >= "2.0"
        line = readline(f); newline!(ps)
        ps.found_networkdata = (ps.count_line, true)
    end
    n_ports = ts.n_ports
    last_freq , freq = 0.0, 0.0
    num_values = num_vals(ts)
    line_buffer = zeros(Float64, num_values - 1, ) 
    stored_lengths = Int[]; sizehint!(stored_lengths, 99)
    data = Matrix{ComplexF64}[]
    if ts.n_freqs > 0
        sizehint!(data, ts.n_freqs)
    end
    is_newline = true
    count_elements = 0
    pos = position(f)
    firstit = true
    while !eof(f) & !is_noisedata(line)

        if !firstit | f_comment(ps, ts, line, f)
            pos = position(f) #  #!isempty(line) && (pos = position(f))
            line = readline(f); newline!(ps)
        end

        f_hfss_gamma(ps, ts, line, f)
        f_hfss_portimpedance(ps, ts, line, f)
            
        if !f_comment(ps, ts, line, f) && !isempty(line) && !is_endfile(line) && !is_noisedata(line) # Check if is a comment
            firstit = false
            act_line = split(line, "!") # In case there is a comment at the end of the line
            values_line = split(act_line[1])
            length_line = length(values_line)
            values_float = parse.(Float64, values_line)

            # In some rare cases maybe you don't know the number of ports. Imagine a snp without extension.
            if n_ports == 0
                n_ports = infere_n_ports(stored_lengths, length_line, ts, line_buffer)
                num_values = num_vals(ts)
            end

            # If we count more elements than num_values it has to be a new line
            # I think i can delete this part
            if (count_elements + length_line) > num_values
                is_newline = true
                count_elements = 0
            end

            # Start a new line
            if is_newline
                is_newline = false
                freq = values_float[1]
                # If freq < last_freq it means that we are now in noise data section
                freq <= last_freq && break 
                push!(ts.frequency, freq)
                values_float = Iterators.drop(values_float, 1)
            end

            for (i, v) in enumerate(values_float)
                line_buffer[i+count_elements] = v
            end
            count_elements += (length(values_float))
            
            # If Buffer is Full: add values and prepare for reading new line
            if (count_elements >= num_values-2) 
                is_newline = true
                count_elements = 0
                push!(data, line_to_matrix(line_buffer, ts))
                line_buffer .= 0.0
            end
            last_freq = freq
        end
    end
    !eof(f) && (seek(f, pos); seekline!(ps))
    ts.data = stack(data)
    return nothing
end

function get_noisedata(ps, ts, line, f)
    version = ts.version
    vf = version <= "1.x"
    while !eof(f)
        line = readline(f); newline!(ps)
        if !f_comment(ps, ts, line, f) & !is_endfile(line) & !isempty(line)# Check if is a comment
            act_line = split(line, "!") # In case there is a comment at the end of the line
            values_line = split(act_line[1])
            float_line = parse.(Float64, values_line)
            push!(ts.noise_frequency, float_line[1])
            push!(ts.noise_data, NoiseData(float_line[2],  
                  Complex(float_line[3] * cos(pi/180 * float_line[4]),
                  float_line[3] * sin(pi/180 * float_line[4])),
                  ts.version < "2.0" ? float_line[5]*ts.resistance[1] : float_line[5]))
        end
    end
    return nothing
end

function get_hfss_gamma(ps, ts, line, f)
    nline = split(lowercase(line), "! gamma")[2]
    act_line = split(nline, "!") 
    values_line = split(act_line[1])
    values_float = parse.(Float64, values_line)
    b = reshape(values_float, 2, div(length(values_float),2))
    values_complex = [Complex(p1, p2) for (p1, p2) in eachcol(b)]
    append!(ts.hfss_gamma, values_complex)
    return
end

function get_hfss_portimpedance(ps, ts, line, f)
    nline = split(lowercase(line), "! port impedance")[2]
    act_line = split(nline, "!") 
    values_line = split(act_line[1])
    values_float = parse.(Float64, values_line)
    b = reshape(values_float, 2, div(length(values_float),2))
    values_complex = [Complex(p1, p2) for (p1, p2) in eachcol(b)]
    append!(ts.hfss_impedance, values_complex)
    return
end

function get_hfss_port(ps, ts, line, f) 
    push!(ts.port_names , split(line, "=")[end])
    return nothing
end

function get_hfss_modaldata(ps, ts, line, f) 
    ts.hfss_data_type = :modal
    return
end

function get_hfss_terminaldata(ps, ts, line, f) 
    ts.hfss_data_type = :terminal
    return
end


# CHECK FUNCTIONS

function checkpart!(isfunc::IF, getfun::GF, ps, ts, line, f) where {IF, GF}
    sw = isfunc(line)
    if sw
        getfun(ps, ts, line, f)
    end
    return sw
end

f_comment(ps, ts, line, f) = checkpart!(is_comment, get_comment, ps, ts, line, f)
f_optionline(ps, ts, line, f) = checkpart!(is_optionline, get_optionline, ps, ts, line, f)
f_version(ps, ts, line, f) = checkpart!(is_version, get_version, ps, ts, line, f)
f_n_ports(ps, ts, line, f) = checkpart!(is_nports, get_nports, ps, ts, line, f)
f_matrixformat(ps, ts, line, f) = checkpart!(is_matrixformat, get_matrixformat, ps, ts, line, f)
f_twoport_order(ps, ts, line, f) = checkpart!(is_twoport_order, get_twoport_order, ps, ts, line, f)
f_n_freqs(ps, ts, line, f) = checkpart!(is_n_freqs, get_n_freqs, ps, ts, line, f)
f_noise_freqs(ps, ts, line, f) = checkpart!(is_noise_freqs, get_noise_freqs, ps, ts, line, f)
f_reference(ps, ts, line, f) = checkpart!(is_reference, get_reference, ps, ts, line, f)
f_mixedmode_order(ps, ts, line, f) = checkpart!(is_mixedmode_order, get_mixedmode_order, ps, ts, line, f)
f_info(ps, ts, line, f) = checkpart!(is_begininfo, get_info, ps, ts, line, f)
f_networkdata(ps, ts, line, f) = checkpart!(is_networkdata, get_networkdata, ps, ts, line, f)
f_noisedata(ps, ts, line, f) = checkpart!(is_noisedata, get_noisedata, ps, ts, line, f)
f_endfile(ps, ts, line, f) = checkpart!(is_endfile, get_endfile, ps, ts, line, f)
f_hfss_gamma(ps, ts, line, f) = checkpart!(is_hfss_gamma, get_hfss_gamma, ps, ts, line, f)
f_hfss_portimpedance(ps, ts, line, f) = checkpart!(is_hfss_portimpedance, get_hfss_portimpedance, ps, ts, line, f)
f_hfss_port(ps, ts, line, f) = checkpart!(is_hfss_port, get_hfss_port, ps, ts, line, f)
f_hfss_modaldata(ps, ts, line, f) = checkpart!(is_hfss_modaldata, get_hfss_modaldata, ps, ts, line, f)
f_hfss_terminaldata(ps, ts, line, f) = checkpart!(is_hfss_terminaldata, get_hfss_terminaldata, ps, ts, line, f)
