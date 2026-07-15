function Convergence.ClampStability(value)
    value = tonumber(value) or Convergence.Config.DefaultStability

    return math.Clamp(
        math.floor(value),
        Convergence.Config.MinimumStability,
        Convergence.Config.MaximumStability
    )
end

function Convergence.NormalizeID(value)
    value = string.Trim(string.lower(tostring(value or "")))
    value = string.gsub(value, "%s+", "_")
    value = string.gsub(value, "[^%w_%-]", "")

    return value
end

function Convergence.GetStabilityState(value)
    value = Convergence.ClampStability(value)

    for _, state in ipairs(Convergence.Config.StabilityStates) do
        if value >= state.minimum and value <= state.maximum then
            return state
        end
    end

    return Convergence.Config.StabilityStates[#Convergence.Config.StabilityStates]
end
