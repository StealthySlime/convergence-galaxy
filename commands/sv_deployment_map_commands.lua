concommand.Add("convergence_deployment_maps", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local planetID = Convergence.NormalizeID(args[1] or "")
    local planet = Convergence.PlanetService.Get(planetID)

    if not planet then
        print("Usage: convergence_deployment_maps <planet>")
        return
    end

    print(
        "========== Deployment Maps: "
        .. planet:GetName()
        .. " =========="
    )

    local regions = Convergence.World.GetRegions(planetID)

    for _, region in ipairs(regions) do
        print(string.format(
            "%-16s %-28s map=%s",
            tostring(region.id),
            tostring(region.name),
            tostring(region.map)
        ))
    end

    print("Regions: " .. tostring(#regions))

    if #regions == 0 then
        local maps = file.Find("maps/*.bsp", "GAME") or {}
        print(
            "Fallback: all mounted maps are selectable ("
            .. tostring(#maps)
            .. " maps)."
        )
    end

    print("==============================================")
end)


concommand.Add("convergence_server_map_count", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local maps = file.Find("maps/*.bsp", "GAME") or {}

    print("========== Server Map Catalog ==========")
    print("Mounted BSP maps: " .. tostring(#maps))

    for index = 1, math.min(#maps, 20) do
        print(" - " .. tostring(maps[index]))
    end

    if #maps > 20 then
        print(" ... and " .. tostring(#maps - 20) .. " more")
    end

    print("========================================")
end)
