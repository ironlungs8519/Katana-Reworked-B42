require "TimedActions/ISBaseTimedAction"
require "KT_Shared"

KTTemperAction = ISBaseTimedAction:derive("KTTemperAction")

function KTTemperAction:isValid()
    local inv = self.character:getInventory()
    return inv:contains(self.weapon) and inv:contains(self.torch)
end

function KTTemperAction:start()
    -- custom animation lives in the optional KatanaTemperingAnim mod; never reference it unless it is enabled
    local ok, active = pcall(function() return getActivatedMods():contains("KatanaTemperingAnim") end)
    if ok and active then self:setActionAnim("KTTemper") end
    self:setOverrideHandModels(self.torch, nil)
    self.sound = KT.playTorch(self.character)
    KTSparks.add(self.character, self.maxTime)
    sendClientCommand(self.character, KT.MODULE, "fx", {})
end

function KTTemperAction:stop()
    KT.stopTorch(self.character)
    ISBaseTimedAction.stop(self)
end

function KTTemperAction:perform()
    sendClientCommand(self.character, KT.MODULE, "temper", { weaponId = self.weapon:getID(), torchId = self.torch:getID() })
    ISBaseTimedAction.perform(self)
end

function KTTemperAction:new(character, weapon, torch)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon, o.torch = weapon, torch
    o.stopOnWalk, o.stopOnRun = true, true
    o.maxTime = character:isTimedActionInstant() and 1 or 300
    return o
end
