Convergence.Navigation = Convergence.Navigation or {}

local Navigation = Convergence.Navigation

Navigation.Adapters = Navigation.Adapters or {}
Navigation.ActiveAdapterID = Navigation.ActiveAdapterID or nil

function Navigation.RegisterAdapter(id, adapter)
    id = Convergence.NormalizeID(id)

    if id == "" or not istable(adapter) then
        return false, "Invalid navigation adapter."
    end

    Navigation.Adapters[id] = adapter

    if not Navigation.ActiveAdapterID
        or (adapter.IsAvailable and adapter:IsAvailable()) then
        Navigation.ActiveAdapterID = id
    end

    return true, adapter
end

function Navigation.GetAdapter(id)
    return Navigation.Adapters[
        Convergence.NormalizeID(id or Navigation.ActiveAdapterID)
    ]
end

function Navigation.GetActiveAdapter()
    local active = Navigation.GetAdapter()

    if active and active.IsAvailable and active:IsAvailable() then
        return active
    end

    for id, adapter in pairs(Navigation.Adapters) do
        if not adapter.IsAvailable or adapter:IsAvailable() then
            Navigation.ActiveAdapterID = id
            return adapter
        end
    end

    return nil
end

function Navigation.GetCurrentPosition()
    local adapter = Navigation.GetActiveAdapter()
    return adapter and adapter.GetShipPosition
        and adapter:GetShipPosition() or nil
end

function Navigation.GetDestination()
    local adapter = Navigation.GetActiveAdapter()
    return adapter and adapter.GetDestination
        and adapter:GetDestination() or nil
end

function Navigation.IsInHyperspace()
    local adapter = Navigation.GetActiveAdapter()
    return adapter and adapter.IsInHyperspace
        and adapter:IsInHyperspace() or false
end

function Navigation.SyncPlanets()
    local adapter = Navigation.GetActiveAdapter()

    if not adapter or not adapter.SyncPlanets then
        return false, "No navigation adapter is available."
    end

    return adapter:SyncPlanets()
end
