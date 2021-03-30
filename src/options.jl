using Parameters

"""
Global configurable options for Metatheory.
"""
@with_kw mutable struct Options 
    """
    Print or not information such as saturation reports 
    """
    verbose::Bool = false
    """
    Print iteration numbers in equality saturation
    """
    printiter::Bool = false
    """
    Allow for multi-threading 
    """
    multithreading::Bool = false
end


options = Options()