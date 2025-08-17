to_values(a, b, ::Val{:MA}) = a * cis(deg2rad(b)) #Complex(a * cos(deg2rad(b)), -a * sin(deg2rad(b)))
to_values(a, b, ::Val{:DB}) = 10.0^(a/20.0) * cis(deg2rad(b)) #Complex(10.0^(a/20.0) * cos(deg2rad(b)), 10.0^(a/20.0) * sin(deg2rad(b)))
to_values(a, b, ::Val{:RI}) = Complex(a, b)

function find_units(line) 
    a = match(r"(?<A>KHZ|MHZ|GHZ|THZ)", line)
    #!isnothing(a) ? (return Symbol(something(a)[:A])) : (return :GHZ)
    return !isnothing(a) ? Symbol(something(a)[:A]) : :GHZ
end

function find_Ri(line) 
    a = match(r"(?<Ri>(?:\d+(?:\.\d+)?\s*)+)", line)
    #!isnothing(a) ? (return parse.(Float64,split(something(a)[:Ri]))) : (return [50.0])
    return !isnothing(a) ? parse.(Float64,split(something(a)[:Ri])) : [50.0]
end

function find_type(line) 
    a = match(r"\b(?<B>S|Z|Y|H|G)\b", line)
    #!isnothing(a) ? (return Symbol(something(a)[:B])) : (return :S)
    return !isnothing(a) ? Symbol(something(a)[:B]) : :S
end

function find_format(line) 
    a = match(r"\b(?<C>MA|DB|RI)\b", line)
    #!isnothing(a) ? (return Symbol(something(a)[:C])) : (return :MA)
    return !isnothing(a) ? Symbol(something(a)[:C]) : :MA
end

function line_to_matrix(line_buffer, ts)
    b = reshape(line_buffer, 2, div(length(line_buffer),2))
    #values = [to_values(p1, p2, Val(ts.format)) for (p1, p2) in eachcol(b) if (p1, p2) != (0.0, 0.0)]
    values = [to_values(p1, p2, Val(ts.format)) for (p1, p2) in eachcol(b)]
    n = length(values)
    if ts.matrixformat != :FULL
        s = round(Int,(sqrt(8*n+1)-1)/2)
        s*(s+1)/2 == n || error("length of vector is not triangular")

        mvals = zeros(ComplexF64, s,s)
        idx = 1
        if ts.matrixformat == :LOWER
            for row in 1:s
                for column in 1:row
                    mvals[row, column] = values[idx]
                    mvals[column, row] = values[idx]
                    idx += 1
                end
            end
        else        
            for row in 1:s
                for column in row:s
                    mvals[row, column] = values[idx]
                    mvals[column, row] = values[idx]
                    idx += 1
                end
            end
        end

    else # Full
        s =  Int(sqrt(n)) 
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
        num_values = ts.matrixformat != :FULL ? ts.n_ports^2+ts.n_ports+1 : 2*ts.n_ports^2 + 1
    end
    return num_values
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


using LinearAlgebra: diag

function verify_touchstone(ts, ps, file, f)

    ts.pstate = ps

    if ts.version >= "2.0"

        if ps.found_reference[2] == true
            z0 = ts.references
        end

        if ps.found_mixedmode_order[2] == true
            modeports = split(ts.mixed_mode_order)
            idvector = map(eachindex(modeports)) do row
                mp = modeports[row]
                firstletter = mp[1]
                if firstletter == 'S'
                    id = parse(Int, mp[2])
                else
                    p, q = sort(parse.(Int, split(mp[2:end], ",")))
                    id = firstletter == 'D' ? p : q
                    z0[id] = firstletter == 'D' ? (2.0*z0[id]) : (0.5*z0[id])
                end
                id
            end
            
            for Smm in eachslice(ts.data, dims = 3)
                smm = copy(Smm)
                smm[idvector, :] .= smm[eachindex(idvector), :]
                smm[:, idvector] .= smm[:, eachindex(idvector)]
                Smm .= smm
            end
        end

        required = (:found_version, :found_optionline, :found_nports, :found_nfreqs, :found_networkdata)
        conditional_required = (:found_twoport_order, :found_n_noisefreq, :found_noisedata)
        optional = (:found_optionline, :found_mixedmode_order, :found_reference, :found_info)
        hfss_style = (:found_hfss_gamma, :found_hfss_portimpedance, :found_hfss_port, :found_hfss_terminaldata, :found_hfss_modaldata)
        
        # H and G only with 2 ports
        # All optional should appear after optionline
        # twoport order only with 2 ports
        # No Number of noise frequencies if no [noise data]
        # Frequency must be ordered -> x == sort(x) ?
        # Check mixedmode tags
        # length(reference) == n_ports
        ts.z0 = reshape(repeat(z0, length(ts.frequency)), ts.n_ports, length(ts.frequency))
    else

        if isempty(ts.hfss_impedance)
            if length(ts.resistance,) != ts.n_ports
                z0 = repeat(ts.resistance, ts.n_ports)
            else
                z0 = copy(ts.resistance)
            end
            ts.z0 = reshape(repeat(copy(z0), length(ts.frequency)), ts.n_ports, length(ts.frequency))
        end

    end


    if ts.hfss_data_type !== :unknown
        if !isempty(ts.hfss_gamma)
            if ts.hfss_data_type === :terminal
                gm = reshape(ts.hfss_gamma, ts.n_ports, ts.n_ports, length(ts.frequency))
                ts.gamma = reshape(mapslices(diag, gm, dims = (1,2)), ts.n_ports, length(ts.frequency)) # shape = N_ports x N_freqs
            else # :modal
                ts.gamma = reshape(ts.hfss_gamma, ts.n_ports, length(ts.frequency))
            end
        end

        if !isempty(ts.hfss_impedance)
            if ts.hfss_data_type === :terminal
                hfssimp = reshape(ts.hfss_impedance, ts.n_ports, ts.n_ports, length(ts.frequency))
                ts.z0 = reshape(mapslices(diag, hfssimp, dims = (1,2)), ts.n_ports, length(ts.frequency)) # shape = N_ports x N_freqs
            else # :modal
                ts.z0 = reshape(ts.hfss_impedance, ts.n_ports, length(ts.frequency)) 
            end
        end
    end

end


# skrf stores this info so i think it's maybe useful.
function comments_after_option_line(ts)
    ps = ts.pstate
    optline = ps.found_optionline[1]
    return filter(ts.comments) do c
        c[1] > optline
    end
end

"""
    simvariables(ts::TSParser) -> Dict{String,String}

Parse simulation variables from the comment section of a Touchstone file.

This function is able to extract parameter definitions from the
comment styles used by softwares:

- **Sonnet style**:
```
\"\"\"
!< p1 = 1.00
!< p2 = 2.00
!< p3 = 3
!< p4 = 4.0 um
!< ...
\"\"\"
```
- **HFSS style**:

```
\"\"\"
! p1 = 1units
! p2 = 2.0units
! p3 = 3.0units
! ...
\"\"\"
```
- **CST style**:
```
\"\"\"
! Parameters = {p1 = 1.0; p2 = 2.0, p3 = 3.0, ...}
\"\"\"
```


##  Arguments
- `ts::TSParser`

##  Notes

- For HFSS and Sonnet variables with units. Because of this, the function returns a Dict{String, String}.

## Examples

```
using TouchstoneParser: readfile

ts = TouchstoneParser.readfile(path)
v = simvariables(ts)
```

"""
function simvariables(ts)
    parameters = filter(ts.comments) do comment
        startswith(comment[2], "! Parameters") # CST
    end
    if !isempty(parameters)
        line = parameters[1][2]
        line = replace(line, "}" => "")
        ps = split(line, "{")[2]
        return Dict(map(split(replace(join(ps), " " => ""), ";")) do str
            key, value_string = split(str, "=")
            value = String(value_string)
            #value = parse(Float64, value_string)
            return String(key) => value
        end)
    else
        # HFSS or Sonnet 
        parameters = filter(ts.comments) do comment
            startswith(comment[2], "! Variables: ") | startswith(comment[2], "!< PARAMS")
        end
        if !isempty(parameters)
            nline = parameters[1][1]
            noptionline = ts.pstate.found_optionline[1]

            comments_filtered = filter(ts.comments) do comment
                (comment[1] > nline) & (comment[1] < noptionline)
            end

            lines = map(x->getindex(x, 2), comments_filtered)
            vars = Dict{String,String}()
            for line in lines
                if occursin("=", line)
                    var, value = split(line, "=", limit=2)
                    var = strip(var, ['!', '<', ' '])  
                    vars[strip(var)] = strip(value)
                end
            end
            return vars
        end

        return nothing
    end
end