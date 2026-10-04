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

-- weapons that never lose sharpness (condition still follows the normal rules)
local immKey, immSet
function KT.isSharpImmune(item)
    if not item or not instanceof(item, "HandWeapon") then return false end
    if KT.isHattori(item) and KT.opt("HattoriSharpnessImmune", true) then return true end
    local raw = KT.opt("SharpnessImmuneItems", "")
    if raw ~= immKey then
        immKey, immSet = raw, {}
        for t in string.gmatch(raw, "[^;,%s]+") do immSet[t] = true end
    end
    return immSet[item:getFullType()] == true
end

-- "Hattori Hanzo's Blade": a normal Base.Katana instance flagged in item modData (no custom item script needed,
-- so it can't break on game updates and stays compatible with katana mods).
function KT.isHattori(item)
    if not item then return false end
    local ok, md = pcall(function() return item:getModData() end)
    return ok and md and md.KT_Hattori == true or false
end

function KT.duration(item)
    local v = item and targets()[item:getFullType()]
    local m = type(v) == "number" and v or KT.opt("DurationMinutes", 30)
    if KT.isHattori(item) then m = m * KT.opt("HattoriDurationPercent", 200) / 100 end
    return m
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
function KT.breakChance(stress, player, weapon)
    local m, t, w = KT.skills(player)
    local c = stress * KT.opt("EarlyReheatBreakChance", 25) * (1 - math.min(0.75, 0.03 * (m + t + w)))
    if KT.isHattori(weapon) then c = c / 2 end
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

function KT.applyHattoriStats(item)
    local si = item:getScriptItem()
    local dp, cp = KT.opt("HattoriDamagePercent", 150) / 100, KT.opt("HattoriConditionPercent", 200) / 100
    pcall(function()
        item:setMinDamage(si:getMinDamage() * dp)
        item:setMaxDamage(si:getMaxDamage() * dp)
    end)
    local newMax = math.floor(si:getConditionMax() * cp)
    local oldMax = item:getConditionMax()
    if oldMax ~= newMax and oldMax > 0 then
        item:setCondition(math.max(1, math.floor(item:getCondition() * newMax / oldMax + 0.5)))
        item:setConditionMax(newMax)
    end
end
