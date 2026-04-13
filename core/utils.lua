local addonName, CrestPlanner = ...

function CrestPlanner.GetCharacterKey(name, realm)
    local safeName = name or "Unknown"
    local safeRealm = realm or "UnknownRealm"
    return string.format("%s-%s", safeName, safeRealm)
end

function CrestPlanner.GetCurrentCharacterKey()
    return CrestPlanner.GetCharacterKey(UnitName("player"), GetRealmName())
end
