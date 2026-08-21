## Docstring Templates

import DocStringExtensions: @template, DOCSTRING, IMPORTS, TYPEDEF, TYPEDFIELDS, TYPEDSIGNATURES

@template (FUNCTIONS, METHODS, MACROS) = """
                                         $(DOCSTRING)

                                         ---
                                         # Signatures
                                         $(TYPEDSIGNATURES)
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
