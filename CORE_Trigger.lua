--[[
## CUSTOM TRIGGER
Type: Custom
Event Type: Status
Check On...: Every Frame
]]
local CUSTOM_TRIGGER = function()

      local core = WA_RADAR_CORE
      if not core then return false end

      return core:IsEnabled()
end

--[[
## CUSTOM UNTRIGGER
]]
local CUSTOM_UNTRIGGER = function()
      return true
end
