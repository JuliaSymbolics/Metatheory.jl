#!/usr/bin/env julia

# Root of the repository
const repo_root = dirname(@__DIR__)

# Make sure docs environment is active
import Pkg
Pkg.activate(@__DIR__)
using Metatheory

# Communicate with docs/make.jl that we are running in live mode
push!(ARGS, "liveserver")

# Run LiveServer.servedocs(...)
import LiveServer
LiveServer.servedocs(;
    # Documentation root where make.jl and src/ are located
    foldername = joinpath(repo_root, "docs"),
    skip_dirs = [
        # exclude assets folder because it is modified by docs/make.jl
        joinpath(repo_root, "docs", "src", "assets"),
        # exclude tutorial .md files (auto-generated via Literate.jl)
        abspath(joinpath(@__DIR__, "src", "tutorials"))
    ],
    # include tutorial .jl files (generate .md files)
    include_dirs=[joinpath(dirname(pathof(Metatheory)), "..", "test", "tutorials")]
)
