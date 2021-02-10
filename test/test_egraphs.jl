
# ENV["JULIA_DEBUG"] = Metatheory

@testset "e-node validation" begin
    @test Metatheory.isenode(2) == true
    @test Metatheory.isenode( :(2 + 3)  ) == false
    @test Metatheory.isenode( EClass(2) ) == false
    @test Metatheory.isenode( Expr(:call, :foo, EClass(2)) ) == true
    @test Metatheory.isenode( Expr(:call, :foo, 3, EClass(2)) ) == false
end

## SPAZZATURA

@testset "Merging" begin
    testexpr = :((a * 2)/2)
    testmatch = :(a << 1)
    G = EGraph(testexpr)
    t2 = addexpr!(G, testmatch)
    merge!(G, t2.id, 3)
    @test in_same_set(G.U, t2.id, 3) == true
    # DOES NOT UPWARD MERGE
end

#testexpr = :(42a + b * (foo($(Dict(:x => 2)), 42)))

@testset "Simple congruence - rebuilding" begin
    testexpr = :(f(a,b) + f(a,c))
    G = EGraph(testexpr)
    t2 = addexpr!(G, :c)
    # display(G.M); println()

    c_id = merge!(G, t2.id, 2)
    in_same_set(G.U, c_id, 2)
    in_same_set(G.U, t2.id, 2)
    @test find_root!(G.U, t2.id) == 4
    # display(G.parents); println()
    rebuild!(G)
    # f(a,b) = f(a,c)
    # display(G.M); println()
    # display(G.H); println()
    # display(G.parents); println()


    @test in_same_set(G.U, 5, 3)
end


@testset "Simple nested congruence" begin
    apply(n, f, x) = n == 0 ? x : apply(n-1,f,f(x))
    f(x) = Expr(:call, :f, x)

    G = EGraph(:a)

    t1 = addexpr!(G, apply(6, f, :a))
    t2 = addexpr!(G, apply(9, f, :a))

    c_id = merge!(G, t1.id, 1) # a == apply(6,f,a)
    c2_id = merge!(G, t2.id, 1) # a == apply(9,f,a)

    # display(G.M); println()

    rebuild!(G)

    # display(G.M); println()

    t3 = addexpr!(G, apply(3, f, :a))
    t4 = addexpr!(G, apply(7, f, :a))

    # f^m(a) = a = f^n(a) ⟹ f^(gcd(m,n))(a) = a
    @test in_same_set(G.U, t1.id, 1) == true
    @test in_same_set(G.U, t2.id, 1) == true
    @test in_same_set(G.U, t3.id, 1) == true
    @test in_same_set(G.U, t4.id, 1) == false

    # if m or n is prime, f(a) = a
    t5 = addexpr!(G, apply(11, f, :a))
    t6 = addexpr!(G, apply(1, f, :a))
    c5_id = merge!(G, t5.id, 1) # a == apply(11,f,a)

    Metatheory.rebuild!(G)

    @test in_same_set(G.U, t5.id, 1) == true
    @test in_same_set(G.U, t6.id, 1) == true
end
