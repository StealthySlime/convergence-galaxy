Convergence.Services = Convergence.Services or {}

local Services = Convergence.Services
Services.Registry = Services.Registry or {}

function Services.Register(id, service)
    id = Convergence.NormalizeID(id)

    if id == "" then
        return false, "Service ID is invalid."
    end

    if not istable(service) then
        return false, "Service must be a table."
    end

    if Services.Registry[id] and Services.Registry[id] ~= service then
        return false, "Service already registered: " .. id
    end

    Services.Registry[id] = service
    return true, service
end

function Services.Get(id)
    return Services.Registry[Convergence.NormalizeID(id)]
end

function Services.Exists(id)
    return Services.Get(id) ~= nil
end

function Services.GetAll()
    return Services.Registry
end
