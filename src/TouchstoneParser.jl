module TouchstoneParser

export Touchstone
export readfile, writefile
export to_S, to_Z, to_Y, to_H, to_G
export tsData, tsFreq
export simparameters

include("./TouchstoneTypes.jl")
include("./utils.jl")
include("./ParserFunctions.jl")
include("./TouchstoneReader.jl")
include("./TouchstoneWriter.jl")

end

#using .TouchstoneParser: readfile
#cd("C://MisProyecto//Upload//TouchstoneParser")
#algo = readfile("./Examples/example_conn.s2p")