Convergence.Permissions = Convergence.Permissions or {}

local Permissions = Convergence.Permissions

Permissions.Director = "convergence_director"
Permissions.Campaign = "convergence_campaign"

function Permissions.Has(ply, permission)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false
    end

    if sam and sam.player and isfunction(sam.player.has_permission) then
        local ok, allowed = pcall(
            sam.player.has_permission,
            ply,
            permission
        )

        if ok then
            return allowed == true
        end
    end

    if isfunction(ply.HasPermission) then
        local ok, allowed = pcall(ply.HasPermission, ply, permission)

        if ok then
            return allowed == true
        end
    end

    return ply:IsAdmin()
end

function Permissions.CanOpenDirector(ply)
    return Permissions.Has(ply, Permissions.Director)
end

function Permissions.CanManageCampaign(ply)
    return Permissions.Has(ply, Permissions.Campaign)
        or Permissions.CanOpenDirector(ply)
end
