KT = KT or {}
KT.MODULE = "KatanaTempering"
KT.TORCH = "Base.BlowTorch"

function KT.opt(name, default)
    local sv = SandboxVars and SandboxVars.KatanaTempering
    if sv and sv[name] ~= nil then return sv[name] end
    return default
end

function KT.now() return getGameTime():getWorldAgeHours() end

-- Items = "Base.Katana;Mod.OtherKatana=45" : optional "=minutes" overrides the duration for that type
local cacheKey, cacheSet
local function targets()
    local raw = KT.opt("Items", "Base.Katana")
    if raw ~= cacheKey then
        cacheKey, cacheSet = raw, {}
        for entry in string.gmatch(raw, "[^;,%s]+") do
            local t, m = string.match(entry, "^([^=]+)=(%d+)$")
            cacheSet[t or entry] = tonumber(m) or true
        end
    end
    return cacheSet
end

function KT.isTarget(item)
    if not item or not instanceof(item, "HandWeapon") then return false end
    return targets()[item:getFullType()] ~= nil
end

function KT.duration(item)
    local v = item and targets()[item:getFullType()]
    return type(v) == "number" and v or KT.opt("DurationMinutes", 30)
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

function KT.skills(player)
    local function lvl(perk) local ok, v = pcall(function() return player:getPerkLevel(perk) end) return ok and v or 0 end
    return lvl(Perks.Mechanics), lvl(Perks.Maintenance), lvl(Perks.MetalWelding)
end

-- returns ok, mechReq, maintReq, weldReq
function KT.meetsSkills(player)
    local m, t, w = KT.skills(player)
    local rm, rt, rw = KT.opt("MechanicsRequired", 2), KT.opt("MaintenanceRequired", 5), KT.opt("WeldingSkillRequired", 1)
    return (m >= rm and t >= rt and w >= rw), rm, rt, rw
end

-- crack chance (%), reduced 3% per combined Mechanics+Maintenance+Welding level (max -75%)
function KT.breakChance(stress, player)
    local m, t, w = KT.skills(player)
    local c = stress * KT.opt("EarlyReheatBreakChance", 25) * (1 - math.min(0.75, 0.03 * (m + t + w)))
    return math.max(0, math.min(100, c))
end

function KT.hasMask(player)
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local it = worn:getItemByIndex(i)
        if it and it:getType() == "WeldingMask" then return true end
    end
    return false
end
