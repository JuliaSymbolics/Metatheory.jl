## Docstring Templates

import DocStringExtensions: @template, DOCSTRING, IMPORTS, TYPEDEF, TYPEDFIELDS

@template (FUNCTIONS, METHODS, MACROS) = """
                                         $(DOCSTRING)
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
