## Docstring Templates

using DocStringExtensions

@template (FUNCTIONS, METHODS, MACROS) =
"""
$(DOCSTRING)

---
# Signatures
$(TYPEDSIGNATURES)
---
## Methods
$(METHODLIST)
"""

@template (TYPES) =
"""
$(TYPEDEF)
$(DOCSTRING)

---
## Fields
$(TYPEDFIELDS)
"""

@template MODULES =
"""
$(DOCSTRING)

---
## Imports
$(IMPORTS)
"""
