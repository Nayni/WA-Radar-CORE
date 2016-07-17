--[[
## CUSTOM TRIGGER
Type: Custom
Event Type: Event
COMBAT_LOG_EVENT_UNFILTERED, ENCOUNTER_END
]]
local CUSTOM_TRIGGER = function(event, ...)
      local core = WA_RADAR_CORE
      if not core then return end

      local encounterId, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, extraSpellID, extraSpellName, extraSchool = ...

      aura_env.lines = aura_env.lines or {}
      aura_env.shackles = aura_env.shackles or {}
      aura_env.shackleCount = aura_env.shackleCount or 0

      local SHACKLE_RADIUS = 25.5

      if subevent == "SPELL_AURA_APPLIED" and spellId == 184964 then
            core:Enable()
            aura_env.shackleCount = aura_env.shackleCount + 1

            local key = "SHACKLE_" .. destGUID
            local text = "Shackle " .. aura_env.shackleCount
            -- convert the destGUIDs current position into a static point and place it on the radar
            -- we pass the shackle count as a number, it'll make the static point look like a raid marker on the radar
            -- 1 = star, 2 = circle, 3 = diamond
            core:Static(key, destGUID, aura_env.shackleCount)
            -- now we place a disk on the static point, indicates the shackle radius
            core:Disk(key, SHACKLE_RADIUS, text)
            -- save the disk ref, we need it for later
            aura_env.shackles[key] = disk
      end

      if subevent == "SPELL_AURA_REMOVED" and spellId == 184964 then
            core:Enable()
            aura_env.shackleCount = aura_env.shackleCount - 1

            local key = "SHACKLE_" .. destGUID
            -- look up the disk
            local disk = aura_env.shackles[key]

            if disk then
                  -- destroy it, shackle has been removed
                  disk:Destroy()
                  -- remove the static, don't need it anymore
                  core:RemoveStatic(key)
            end
      end

      if subevent == "SPELL_AURA_APPLIED" and spellId == 185014 then
            core:Enable()

            local EXTEND = core.constants.lines.extend.HALF
            local focused = destGUID
            -- to know who has the connected wrought, we just read it off the Focused Chaos debuff
            local wrought = select(8, UnitDebuff(destName, GetSpellInfo(185014) or "Focused Chaos"))

            if focused and wrought then
                  -- we can give WA_RADAR_CORE GUIDs and names, it will deal with it for you
                  -- a width of 4 is perfect for archimonde focused chaos beams
                  --
                  -- EXTEND will extend the line on the destination, we want the line to be extended on the focused target
                  -- so we pass wrought as the source, and focused as the destination and tell the radar to extend
                  local line = core:Connect(wrought, focused, 4, EXTEND)
                  -- keep the line ref, need it for later
                  aura_env.lines[focused] = line
            end
      end

      if subevent == "SPELL_AURA_REMOVED" and spellId == 185014 then
            core:Enable()

            local focused = destGUID
            -- look up the line that's linked with the focused playerGUID
            local line = aura_env.lines[focused]

            if line then
                  -- destroy the line
                  line:Destroy()
                  -- remove from local refs
                  aura_env.lines[focused] = nil
            end
      end

      -- going into last phase, disable radar in 5...
      if subevent == "SPELL_CAST_START" and spellId == 190313 then
            C_Timer.After(5, function()
                  aura_env.shackles = {}
                  aura_env.lines = {}
                  aura_env.shackleCount = 0
                  core:Disable()
            end)
      end

      -- encounter ended, disable radar
      if event == "ENCOUNTER_END" and encounterId == 1799 then
            aura_env.shackles = {}
            aura_env.lines = {}
            aura_env.shackleCount = 0
            core:Disable()
      end

      return true
end

local CUSTOM_UNTRIGGER = function()
      return true
end
