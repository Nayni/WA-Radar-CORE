--[[
The following file contains two functions:
      - A custom trigger function
      - A custom untrigger function

If you are somewhat familiar with WeakAuras, you should know where this goes,
else I suggest you take an easier tutorial then this ;)

(The reason I place the two functions on a local variable, is because I personally use a lua-linter)

CUSTOM TRIGGER
      Type: Custom
      Event Type: Event
      COMBAT_LOG_EVENT_UNFILTERED, ENCOUNTER_END, CORE_ARCHI_TEARDOWN
]]
local CUSTOM_TRIGGER = function(event, ...)
      local core = WA_RADAR_CORE
      if not core then
            -- no CORE, bail out early
            return false
      end

      local encounterId, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, extraSpellID, extraSpellName, extraSchool = ...

      local SHACKLED_TORMENT_SPELL_ID = 184964
      local FOCUSED_CHAOS_SPELL_ID = 185014
      local NETHER_ASCENSION_SPELL_ID = 190313
      local ARCHIMONDE_ENCOUNTER_ID = 1799

      -- For this radar we will keep track of a few things ourselves
      -- the first being all the lines that we setup because of Focused Chaos and Wrought
      -- the second are the 3 Shackled Torments
      -- the third is a trivial counter, we'll use it to give the shackled torments a nice raid marker and a name.
      aura_env.lines = aura_env.lines or {}
      aura_env.shackles = aura_env.shackles or {}
      aura_env.shackleCount = aura_env.shackleCount or 0

      -- The shackle radius for Mythic is limited to 25 yards, by adding .5 we add a safety net.
      local SHACKLE_RADIUS = 25.5

      -- If you don't fully understand it yet, don't worry.
      -- Every part is explained below ;-)

      if subevent == "SPELL_AURA_APPLIED" and spellId == SHACKLED_TORMENT_SPELL_ID then
            core:Enable()
            -- A shackle has been applied, so let's increment the counter
            aura_env.shackleCount = aura_env.shackleCount + 1

            -- Shackled Torment is a debuff that basically locks down the position of the player when it is applied.
            -- The area to remove the shackle is 25 yards, anyone standing in this area when the shackle breaks, will die.
            -- To capture all this on the radar we will do the following:
            --    - Capture the position of the player who received the shackled Torment
            --    - Turn that position into a static not-moving point
            --    - Create a disk with a radius of 25.5 yads on that static point
            --    - Store the disk in our predefined list, so that we can destroy it on removal.

            -- First of all, we need an easy unique key to keep the disk reference,
            -- an easy choice is the UnitGUID of the player who received the shackled torment, destGUID
            -- just to avoid confusion we'll add a prefix "SHACKLE_" to it as well.
            local key = "SHACKLE_" .. destGUID

            -- Just "fo'show" we'll add some text to our disk, saying "Shackle X" where X is the number of the shackle (3 total)
            local text = "Shackle " .. aura_env.shackleCount

            -- Now it's time to capture the position of the player, and turn it into a static not-moving point.
            -- This is very easy with CORE, all CORE needs is:
            --    -A unique key for the static point, so that you can easely reference it just like players,
            --     we'll use our shackle key we made earlier.
            --    -The reference to a member of the group so CORE can capture the position,
            --     CORE doesn't care what you pass, a unitID, GUID or name
            --    -As little extra we'll also give this static point a raid marker icon that indicates the number of the shackle
            --     just to refresh your memory: 1 = star, 2 = circle, 3 = diamond
            core:Static(key, destGUID, aura_env.shackleCount)
            -- Once the static point is created, CORE will paint it on the radar display and we can now reference it for other use
            -- So let's place our shackled torment disk on it
            local disk = core:Disk(key, SHACKLE_RADIUS, text)
            -- We have to destroy the disk later.
            -- To be able to do this we have 2 options:
            --    -We just remember the key of the static point and ask core to destroy the disk
            --    -We keep the disk reference ourself, and destroy it ourselves
            -- We'll go with the last option for now.
            aura_env.shackles[key] = disk
      end

      if subevent == "SPELL_AURA_REMOVED" and spellId == SHACKLED_TORMENT_SPELL_ID then
            core:Enable()
            -- A shackle has been removed, so let's decrement the counter
            aura_env.shackleCount = aura_env.shackleCount - 1

            -- Remmeber our key? We need it again here because we're going to look up our disk.
            local key = "SHACKLE_" .. destGUID
            local disk = aura_env.shackles[key]

            if disk then
                  -- We have indeed earlier made a disk for this player, let's destroy it now, it's been removed.
                  disk:Destroy()
                  -- The disk is removed, so now we can also safely remove the static point, it has served its purpose.
                  core:RemoveStatic(key)
            end
      end

      if subevent == "SPELL_AURA_APPLIED" and spellId == FOCUSED_CHAOS_SPELL_ID then
            core:Enable()
            -- A Focused Chaos has been applied to someone. This means that Archimonde has connected two people together.
            -- In 5 seconds a beam of energy will be created between these two, dealing damage to anyone standing in this beam.
            -- To make this visible on the CORE radar we'll use the Connect method to draw a visible line between the two.

            -- A Focused Chaos beam is a beam that starts from the second person and goes in the direction of the one with Focused Chaos.
            -- The beam doesn't end there, it is extended on the player with Focused Chaos.
            -- CORE allows you to draw connections with different 'extend modes', for Archimonde we'll go with the HALF option
            -- This implies that the line that will be drawn will be extended at the destination.
            local HALF = core.constants.lines.extend.HALF

            -- All we have todo now is find a valid player reference for the 2 connected people. The first one we know, it's destGUID again.
            local focused = destGUID
            -- To know the connected person, we can look it up via UnitDebuff, the return value 'caster' will hold a unitID of the connected person.
            -- We'll call the connected person wrought, because that's the name of the debuff he is holding.
            -- I like to make WeakAuras language independant. So instead of passing "Focused Chaos" as a name directly into UnitDebuff,
            -- I will get the real spellbook name using GetSpellInfo, it'll return the correctly translated name for every client.
            local wrought = select(8, UnitDebuff(destName, GetSpellInfo(FOCUSED_CHAOS_SPELL_ID) or "Focused Chaos"))

            if focused and wrought then
                  -- Once we have a reference to both players, we can connect them.
                  -- Just to show that CORE can deal with any player reference, wrought is actualy a unitID ('raid1', 'raid2', ...)
                  -- while focused is a GUID. CORE doesn't mind what you pass, as long as it's a known member of the group.
                  -- (and trust me, if it doesn't, you'll get a nice warning in chat ;-))
                  --
                  -- Focused Chaos beam works nicely with a witdh of 4,
                  -- there is no easy way of finding the number for this, apart from trying, but I did it for you!
                  --
                  -- And remember that we want to have the line extended on the person with Focused Chaos itself.
                  -- This means, wrought is our source, focused is our destination and we tell CORE to HALF-extend.
                  local line = core:Connect(wrought, focused, 4, HALF)

                  -- Just like with our Shackled Torment disk we have 2 options:
                  --    -We can just keep the 2 player references and disconnect the line by using CORE
                  --    -Or we keep the line object ourselves, and call Disconnect on it later ourselves.
                  -- Because it's more annoying to keep the 2 player references, i'll just store the line object.
                  aura_env.lines[focused] = line
            end
      end

      if subevent == "SPELL_AURA_REMOVED" and spellId == FOCUSED_CHAOS_SPELL_ID then
            core:Enable()

            -- The Focused Chaos beam has gone. So let's look up our line, and disconnect it.
            local focused = destGUID
            local line = aura_env.lines[focused]

            if line then
                  -- Because we have the line object, we can disconnect it directly.
                  line:Disconnect()
                  -- And we can throw away our reference to it.
                  aura_env.lines[focused] = nil
            end
      end

      -- Archimonde has started casting Nether Ascension, this means he's going into last phase, or the encounter has ended.
      -- Let's get the rader off the screen, we don't really need it anymore.
      -- I add delay because I want any pending Focused Chaos beams or Shackles to be gone before disabling the radar.
      -- Because we cannot clean up aura_env in a C_Timer function we'll just broadcast our own custom even to "tear down".
      if (subevent == "SPELL_CAST_START" and spellId == NETHER_ASCENSION_SPELL_ID) or (event == "ENCOUNTER_END" and encounterId == ARCHIMONDE_ENCOUNTER_ID) then
            C_Timer.After(10, function()
                  WeakAuras.ScanEvents("CORE_ARCHI_TEARDOWN")
            end)
      end

      -- We called to tear down, so let's do so.
      -- Clean up all vars and disable CORE.
      if event == "CORE_ARCHI_TEARDOWN" then
            aura_env.shackles = {}
            aura_env.lines = {}
            aura_env.shackleCount = 0
            core:Disable()
      end

      -- Just return true, the radar display is done by CORE anyway.
      -- This WA is just an empty text WeakAura.
      return true
end

--[[
CUSTOM UNTRIGGER:
      Hide: Custom
]]
local CUSTOM_UNTRIGGER = function()
      return true
end
