require "ISUI/ISUIElement"

-- Visual only: world-space sparks projected to screen, falling from the player's hip/thigh.
KTSparks = { emitters = {}, parts = {} }

-- torch tip, approximated from facing to match the KT_Temper pose (right hip, forward). Tune here.
local TIP_FWD, TIP_SIDE, TIP_Z = 0.55, 0.22, 0.42
local function tip(p)
    local d = p:getForwardDirection()
    local dx, dy = d:getX(), d:getY()
    return p:getX() + dx * TIP_FWD + dy * TIP_SIDE, p:getY() + dy * TIP_FWD - dx * TIP_SIDE, p:getZ() + TIP_Z
end

function KTSparks.add(player, ticks)
    local e = { p = player, left = ticks }
    local x, y, z = tip(player)
    pcall(function() -- warm flickering light while welding
        e.light = IsoLightSource.new(math.floor(x), math.floor(y), math.floor(player:getZ()), 0.9, 0.6, 0.35, 5)
        getCell():addLamppost(e.light)
    end)
    table.insert(KTSparks.emitters, e)
end

local function dropLight(e)
    if e.light then pcall(function() getCell():removeLamppost(e.light) end) e.light = nil end
end

local function spawn(p)
    local dir = p:getForwardDirection()
    local dx, dy = dir:getX(), dir:getY()
    local tx, ty, tz = tip(p)
    for _ = 1, 3 do
        table.insert(KTSparks.parts, {
            x = tx, y = ty, z = tz,
            vx = (ZombRandFloat(0, 1) - 0.5) * 0.03 + dx * 0.01, vy = (ZombRandFloat(0, 1) - 0.5) * 0.03 + dy * 0.01,
            vz = ZombRandFloat(0, 1) * 0.02, life = 20 + ZombRand(25), age = 0, bounced = false,
        })
    end
end

Events.OnTick.Add(function()
    local E = KTSparks.emitters
    for i = #E, 1, -1 do
        local e = E[i]
        e.left = e.left - 1
        if e.left <= 0 or not e.p:getCurrentSquare() then dropLight(e) table.remove(E, i) else spawn(e.p) end
    end
    local P = KTSparks.parts
    for i = #P, 1, -1 do
        local s = P[i]
        s.age = s.age + 1
        s.vz = s.vz - 0.0035
        s.x, s.y, s.z = s.x + s.vx, s.y + s.vy, s.z + s.vz
        if s.z <= 0 then
            if s.bounced then s.life = 0 else s.bounced, s.z, s.vz = true, 0, -s.vz * 0.3 end
        end
        if s.age >= s.life then table.remove(P, i) end
    end
end)

local ui = ISUIElement:new(0, 0, 1, 1)
function ui:render()
    local pl = getPlayer()
    if not pl then return end
    local pn = pl:getPlayerNum()
    for _, e in ipairs(KTSparks.emitters) do -- flickering flame at the tip
        local x, y, z = tip(e.p)
        local fx, fy = IsoUtils.XToScreenExact(x, y, z, pn), IsoUtils.YToScreenExact(x, y, z, pn)
        local h = 7 + ZombRand(5)
        self:drawRect(fx - 3, fy - h, 6, h, 0.8, 1, 0.55, 0.1)       -- orange outer
        self:drawRect(fx - 1.5, fy - h * 0.6, 3, h * 0.6, 0.95, 0.5, 0.75, 1) -- blue core
    end
    for _, s in ipairs(KTSparks.parts) do
        local sx = IsoUtils.XToScreenExact(s.x, s.y, s.z, pn)
        local sy = IsoUtils.YToScreenExact(s.x, s.y, s.z, pn)
        local f = s.age / s.life
        self:drawRect(sx, sy, 2, 2, 1 - f * 0.6, 1 - f * 0.6, 0.85 - f * 0.85, 1 - f)
    end
end
Events.OnGameStart.Add(function() ui:initialise(); ui:instantiate(); ui:addToUIManager() end)
