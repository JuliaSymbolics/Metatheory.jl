failme = @theory begin
    p ≠ ¬p
    :foo == ¬:foo
    :foo => :bazoo
    :bazoo => :wazoo
end

g = EGraph(:foo)
report = saturate!(g, failme)
@test report.reason == :contradiction
@test !(@areequal failme foo wazoo)
