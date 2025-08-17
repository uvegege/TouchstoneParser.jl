function process_section!(parserstate, touchstone, line, f, section_tags)
    isempty(line) && return true
    !is_line(line) && return false 
    some = false
    for check! in section_tags
        if check!(parserstate, touchstone, line, f)
            some = true
            break
        end
    end
    return some
end


function readfile(file)

    ps = ParserState()
    ts = TSParser()
    section = :Start

    process_extension!(ts, ps, file)
    
    process = Dict(
        :Start      => (f_version, f_optionline, f_n_ports, f_comment),
        :KeyOptions => (f_twoport_order, f_n_freqs, f_noise_freqs, f_reference, f_matrixformat, 
                        f_mixedmode_order, f_info, f_comment, f_optionline),
        :Data       => (f_networkdata, f_noisedata, f_comment)
    )

    f = open(file, "r+")
    while !eof(f)
        pos = position(f)
        line = readline(f); newline!(ps)
        in_section = process_section!(ps, ts, line, f, process[section])
        if section === :Start
            section = in_section ? :Start : 
                      ts.version >= "2.0" ? :KeyOptions : :Data
            section !== :Start && (seek(f, pos); seekline!(ps))
        elseif section === :KeyOptions
            section = in_section ? :KeyOptions : :Data 
            section === :Data && (seek(f, pos); seekline!(ps))
        else # === :Data 
            if !in_section
                get_networkdata(ps, ts, line, f)
                get_noisedata(ps, ts, line, f)
            end
        end
    end
    close(f)
    
    verify_touchstone(ts, ps, file, f)
    return ts
end