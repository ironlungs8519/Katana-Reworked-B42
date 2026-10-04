require "ISUI/ISUIElement"

-- Visual only: world-space sparks projected to screen, falling from the player's hip/thigh.
KTSparks = { emitters = {}, parts = {} }

function KTSparks.add(player, ticks)
    table.insert(KTSparks.emitters, { p = player, left = ticks })
end

local function spawn(p)
    local dir = p:getForwardDirection()
    local dx, dy = dir:getX(), dir:getY()
    for _ = 1, 3 do
        table.insert(KTSparks.parts, {
            x = p:getX() + dx * 0.35, y = p:getY() + dy * 0.35, z = p:getZ() + 0.38,
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
        if e.left <= 0 or not e.p:getCurrentSquare() then table.remove(E, i) else spawn(e.p) end
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
    for _, s in ipairs(KTSparks.parts) do
        local sx = IsoUtils.XToScreenExact(s.x, s.y, s.z, pn)
        local sy = IsoUtils.YToScreenExact(s.x, s.y, s.z, pn)
        local f = s.age / s.life
        self:drawRect(sx, sy, 2, 2, 1 - f * 0.6, 1 - f * 0.6, 0.85 - f * 0.85, 1 - f)
    end
end
Events.OnGameStart.Add(function() ui:initialise(); ui:instantiate(); ui:addToUIManager() end)
