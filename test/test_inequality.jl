using Metatheory

failme = @theory begin
    p ≠ ¬p
    :foo == ¬:foo
    :foo => :bazoo
    :bazoo => :wazoo
end

g = EGraph(:foo)
report = saturate!(g, failme)
println(report)
@test report.reason isa ReportReasons.Contradiction
# @test !(@areequal failme foo wazoo)
