
function write_touchstone(freqs, M, parameters, z0; version = "2.1", default_comments = true)

    io = IOBuffer()
    dayname(fecha_hora_actual) 
    monthname(fecha_hora_actual) 
    day(fecha_hora_actual) 
    hour(fecha_hora_actual) 
    minute(fecha_hora_actual) 
    second(fecha_hora_actual) 
    year(fecha_hora_actual)
    write(io, "Touchstone file created with Touchstone.jl\n")
    write(io, "! Date and Time...\n")

    return nothing
end