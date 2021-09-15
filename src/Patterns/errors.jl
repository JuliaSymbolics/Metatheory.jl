struct UnsupportedPatternException <: Exception
    p::AbstractPat
end

Base.showerror(io::IO, e::UnsupportedPatternException) = 
    print(io, "Pattern ", e.p, " is unsupported in this context")

