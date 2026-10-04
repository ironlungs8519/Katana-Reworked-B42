require "TimedActions/ISBaseTimedAction"
require "KT_Shared"

KTTemperAction = ISBaseTimedAction:derive("KTTemperAction")

function KTTemperAction:isValid()
    local inv = self.character:getInventory()
    return inv:contains(self.weapon) and inv:contains(self.torch)
end

function KTTemperAction:start()
    self:setActionAnim("BlowTorch")
    self:setOverrideHandModels(self.torch, nil)
    self.sound = self.character:getEmitter():playSound("KT_TorchTemper")
    KTSparks.add(self.character, self.maxTime)
    sendClientCommand(self.character, KT.MODULE, "fx", {})
end

function KTTemperAction:stop()
    if self.sound then self.character:getEmitter():stopSound(self.sound) end
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
