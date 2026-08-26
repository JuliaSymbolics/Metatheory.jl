## Docstring Templates

import DocStringExtensions: @template, DOCSTRING, IMPORTS, METHODLIST, TYPEDEF, TYPEDFIELDS, TYPEDSIGNATURES

@template (FUNCTIONS, METHODS, MACROS) = """
                                         $(DOCSTRING)
                                         ---
                                         # Signatures
                                         $(TYPEDSIGNATURES)
                                         ---
                                         ## Methods
                                         $(METHODLIST)
                                         """

@template (TYPES) = """
                    $(TYPEDEF)
                    $(DOCSTRING)

                    ---
                    ## Fields
                    $(TYPEDFIELDS)
                    """

@template MODULES = """
                    $(DOCSTRING)

                    ---
                    ## Imports
                    $(IMPORTS)
                    """
