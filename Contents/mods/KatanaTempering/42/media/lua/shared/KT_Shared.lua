KT = KT or {}
KT.MODULE = "KatanaTempering"
KT.TORCH = "Base.BlowTorch"

function KT.opt(name, default)
    local sv = SandboxVars and SandboxVars.KatanaTempering
    if sv and sv[name] ~= nil then return sv[name] end
    return default
end

function KT.now() return getGameTime():getWorldAgeHours() end

local cacheKey, cacheSet
function KT.isTarget(item)
    if not item or not instanceof(item, "HandWeapon") then return false end
    local raw = KT.opt("Items", "Base.Katana")
    if raw ~= cacheKey then
        cacheKey, cacheSet = raw, {}
        for t in string.gmatch(raw, "[^;,%s]+") do cacheSet[t] = true end
    end
    return cacheSet[item:getFullType()] == true
end

function KT.key(item) return tostring(item:getID()) end

-- heat stress decays linearly to 0 over CooldownMinutes
function KT.stress(e, now)
    if not e or not e.stress then return 0 end
    local cd = KT.opt("CooldownMinutes", 120) / 60
    if cd <= 0 then return 0 end
    return math.max(0, e.stress - (now - e.stressT) / cd)
end

function KT.remainingMinutes(e, now)
    if not e or not e.untilT then return 0 end
    return math.max(0, (e.untilT - now) * 60)
end

function KT.breakChance(stress, weldLevel)
    local c = stress * KT.opt("EarlyReheatBreakChance", 25) * (1 - 0.05 * (weldLevel or 0))
    return math.max(0, math.min(100, c))
end

function KT.weldLevel(player)
    local ok, v = pcall(function() return player:getPerkLevel(Perks.MetalWelding) end)
    return ok and v or 0
end

function KT.hasMask(player)
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local it = worn:getItemByIndex(i)
        if it and it:getType() == "WeldingMask" then return true end
    end
    return false
end
