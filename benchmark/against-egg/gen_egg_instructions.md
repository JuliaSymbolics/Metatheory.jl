This is a simple script to convert Metatheory.jl <https://github.com/0x0f0f0f/Metatheory.jl> theories into an Egg <https://egraphs-good.github.io/> query for comparison.

Get a rust toolchain <https://rustup.rs/>

Make a new project 

```
cargo new my_project
cd my_project
```

Add egg as a dependency to the Cargo.toml. Add the last line shown here.

```
[package]
name = "autoegg"
version = "0.1.0"
authors = ["Philip Zucker <philzook58@gmail.com>"]
edition = "2018"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]
egg = "0.6.0"
```

Copy and paste the Julia script in the project folder. Replace the example theory and query with yours in the script

Run it

```
julia gen_egg.jl
```

Now you can run it in Egg

```
cargo run --release
```

Profit.
