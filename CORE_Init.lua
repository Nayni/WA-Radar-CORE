--[[
#######################################################################################################################
      WeakAuras Radar CORE module

      All variables in this file, either local or part of the core module starting with an underscore (_)
      are supposed to be private variables,
      editing these variables without internal knownledge might cause the radar to malfunction!

      Just like variables, all functions starting with an underscore (_) are ment as private functions
      They're used by the internal API and display only,
      Do not change or invoke these functions without having internal knownledge!

      Scroll down to the public api section (bottom) to see what's ment as api for external use.
#######################################################################################################################
]]
local core = WA_RADAR_CORE or CreateFrame("Frame", "WA_RADAR_CORE", UIParent)
core:Hide()

--[[
#######################################################################################################################
      CONFIG
#######################################################################################################################
]]
core.config = {
      -- The maximum range you will see on the radar, anything further then this won't be visible.
      -- This can be seen as "zoom", measured in in-game yards.
      -- Edit this value to see either more or less on the radar.
      -- MUST BE GREATER THEN 0, ELSE BAD THINGS WILL HAPPEN!
      maxRange = 60,

      _lines = {
            _defaultWidth = 4
      },

      _disks = {
            _defaultRadius = 20
      }
}

--[[
#######################################################################################################################
      CONSTANTS
#######################################################################################################################
]]
core.constants = {
      lines = {
            -- Lines have 3 different what we call "extend-modes"
            --    -SEGMENT : the line is drawn between the source and destination only,
            --    -HALF    : the line is drawn between the source and destination and extended beyond the destination,
            --    -EXTEND  : the lins is drawn between the source and destination and extended both ways
            extend = {
                  SEGMENT = 0,
                  HALF = 1,
                  EXTEND = 2
            },
            -- Lines have 3 different what we call "danger-modes"
            --    -DANGER   : the line indicates danger, standing on it is bad,
            --    -NEUTRAL  : the line is neutral, standing on it or not doesn't matter,
            --    -FRIENDLY : the line is friendly, you must stand on it
            danger = {
                  DANGER = 0,
                  NEUTRAL = 1,
                  FRIENDLY = 2
            }
      },
      disks = {
            -- Disks have 3 different what we call "danger-modes"
            --    -DANGER   : the disk indicates danger, standing in it is bad,
            --    -NEUTRAL  : the disk is neutral, standing in it or not doesn't matter,
            --    -FRIENDLY : the disk is friendly, you must stand in it
            danger = {
                  DANGER = 0,
                  NEUTRAL = 1,
                  FRIENDLY = 2
            }
      }
}

--[[
#######################################################################################################################
      BLIZZARD FIXES
#######################################################################################################################
]]
local function GetUnitPosition(unitID)
      local posY, posX, _, instanceID = UnitPosition(unitID)

      return posX, posY, instanceID
end

--[[
#######################################################################################################################
      DEBUGGING
#######################################################################################################################
]]
local function warn(message, ...)
      local msg = string.format(message, ...)
      print("|cFF9999FF" .. "RADAR-CORE: " .. "|r" ..  "|cFFFF3333" .. msg .. "|r")
end


--[[
#######################################################################################################################
      INITIAL SETUP
#######################################################################################################################
]]
core._defaultWidth = 480
core._range = core._defaultWidth / 2
core._range2 = core._range * core._range
core._scale = core._range / core.config.maxRange

core._tCoeff = 256/254
core._lineCoeff = core._tCoeff/2

core._facing = 0
core._sin = math.sin(core._facing)
core._cos = math.cos(core._facing)

core._playerName = GetUnitName("player", true)
core._inDangerLine = false
core._inDangerDisk = false

core._positions = {}
core._positions.player = GetUnitPosition("player")

core._radarPositions = {}
core._radarPositions.player = { 0, 0, true }

core._displayedUnits = {}

core._roster = {}
core._nameRoster = {}
core._unitRoster = {}

core._staticPoints = {}
core._blips = {}
core._lines = {}
core._disks = {}
core._enabled = false
core._frame = CreateFrame("Frame", nil, UIParent)

--[[
#######################################################################################################################
      SCALING
#######################################################################################################################
]]
function core:_updateScale(width)
      core._range = width / 2
      core._range2 = core._range * core._range
      core._scale = core._range / core.config.maxRange
end

--[[
#######################################################################################################################
      BLIPS
#######################################################################################################################
]]
local MARKER_TEXTURES = {
      [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_1.blp]], --star
      [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_2.blp]], --circle
      [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_3.blp]], --diamond
      [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_4.blp]], --triangle
      [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_5.blp]], --moon
      [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_6.blp]], --square
      [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_7.blp]], --cross
      [[Interface\TARGETINGFRAME\UI-RaidTargetingIcon_8.blp]], --skull
}

local BLIP_TEX_COORDS = {
      ["WARRIOR"] = { 0, 0.125, 0, 0.25 },
      ["PALADIN"] = { 0.125, 0.25, 0, 0.25 },
      ["HUNTER"] = { 0.25, 0.375, 0, 0.25 },
      ["ROGUE"] = { 0.375, 0.5, 0, 0.25 },
      ["PRIEST"] = { 0.5, 0.625, 0, 0.25 },
      ["DEATHKNIGHT"] = { 0.625, 0.75, 0, 0.25 },
      ["SHAMAN"] = { 0.75, 0.875, 0, 0.25 },
      ["MAGE"] = { 0.875, 1, 0, 0.25 },
      ["WARLOCK"] = { 0, 0.125, 0.25, 0.5 },
      ["DRUID"] = { 0.25, 0.375, 0.25, 0.5 },
      ["MONK"] = { 0.125, 0.25, 0.25, 0.5 },
      ["DEMONHUNTER"] = { 0.375, 0.5, 0.25, 0.5 }
}

function core:_initBlip(unit, raidTargetIndex)
      if UnitIsUnit(unit, "player") then return end

      local blip

      if core._blips[unit] then
            blip = core._blips[unit]
      else
            blip = CreateFrame("Frame", "WA_RADAR_BLIP" .. unit, core._frame)

            blip:SetPoint("CENTER")
            blip:SetFrameStrata("HIGH")
            blip:SetFrameLevel(1)
            blip:SetSize(22,22)
            blip.t = blip.t or blip:CreateTexture(nil, "BORDER", nil, 4)
            blip.t:SetAllPoints()

            core._blips[unit] = blip
      end

      if raidTargetIndex and MARKER_TEXTURES[raidTargetIndex] then
            blip:SetSize(28,28)
            blip.t:SetTexture(MARKER_TEXTURES[raidTargetIndex])
      else
            blip.t:SetTexture([[Interface\MINIMAP\PartyRaidBlips]])

            local _, class = UnitClass(unit)

            if BLIP_TEX_COORDS[class] then
                  blip.t:SetTexCoord(unpack(BLIP_TEX_COORDS[class]))
            else
                  blip.t:SetTexCoord(.5, .625, .5, .75)
            end
      end


      return blip
end

function core:_updateBlip(unit)
      local blip = core._blips[unit]
      if not blip then return end

      local p = core._positions[unit]

      local x, y, inRange = core:GetRadarPosition(p[1], p[2], p[3])

      core._radarPositions[unit] = core._radarPositions[unit] or {}
      core._radarPositions[unit][1] = x
      core._radarPositions[unit][2] = y
      core._radarPositions[unit][3] = inRange

      if inRange then
            core._displayedUnits[unit] = true
            blip:SetPoint("CENTER", x, y)
            blip:Show()
      else
            core._displayedUnits[unit] = false
            blip:Hide()
      end
end

function core:_hideAllBlips()
      for _, blip in pairs(core._blips) do
            blip:Hide()
      end
      core._displayedUnits = {}
end

--[[
#######################################################################################################################
      ROSTER AND POSITIONS
#######################################################################################################################
]]
function core:GetRadarPosition(x, y, instanceID)
      local posX, posY, instanceID = x, y, instanceID

      local playerX = core._positions.player[1]
      local playerY = core._positions.player[2]
      local playerInstanceID = core._positions.player[3]

      if playerInstanceID == instanceID then
            local offx, offy = (playerX - posX) * core._scale, (posY - playerY) * core._scale
            local x = core._cos * offx + core._sin * offy
            local y = -core._sin * offx + core._cos * offy
            local inRange = offx*offx + offy*offy <= core._range2

            return x, y, inRange
      end
end

function core:_getRadarPosition(src)
      if not src then return end
      local unitID = core:FindUnitID(src)
      if not unitID then return end

      local p = core._radarPositions[unitID]

      if p then
            return unitID, p[1], p[2], p[3]
      else
            return nil
      end
end

function core:_getPosition(src)
      if not src then return end
      local unitID = core:FindUnitID(src)
      if not unitID then return end

      local p = core._positions[unitID]

      if p then
            return unitID, p[1], p[2], p[3]
      else
            local x, y, instanceID = GetUnitPosition(unitID)
            return unitID, x, y, instanceID
      end
end

function core:FindGUID(src)
      if core._roster[src] then
            return src
      elseif core._unitRoster[src] then
            return core._unitRoster[src]
      end

      -- before looking by name, remove any realm name
      local name = string.gsub(src, "%-[^|]+", "")
      if core._nameRoster[name] then
            return core._nameRoster[name]
      else
            return nil
      end
end

function core:FindUnitID(src)
      local guid = core:FindGUID(src)

      if guid then
            return core._roster[guid]
      else
            return nil
      end
end

function core:_updatePositions()
      core._positions.player = core._positions.player or {}
      core._positions.player[1], core._positions.player[2], core._positions.player[3] = GetUnitPosition("player")

      for unit in pairs(core._roster) do
            core._positions[unit] = core._positions[unit] or {}

            local x, y, instanceID = GetUnitPosition(unit)

            if (not x) and core._staticPoints[unit] then
                  x, y, instanceID = core._staticPoints[unit][1], core._staticPoints[unit][2], core._positions.player[3]
            end

            core._positions[unit][1] = x
            core._positions[unit][2] = y
            core._positions[unit][3] = instanceID
      end
end

function core:_isStatic(unit)
      if core._staticPoints[unit] then
            return true
      else
            return false
      end
end

function core:_addToRoster(unit, isStatic)
      local guid, name;

      if isStatic then
            guid = unit
            name = unit
      else
            guid = UnitGUID(unit)
            name = UnitName(unit)
      end

      core._roster[guid] = unit
      core._nameRoster[name] = guid
      core._unitRoster[unit] = guid
end

function core:_updateRoster()
      wipe(core._roster)
      wipe(core._positions)
      wipe(core._displayedUnits)
      wipe(core._nameRoster)
      wipe(core._unitRoster)

      -- Load player into the roster
      core:_addToRoster("player")

      -- Load party/raid into the roster
      if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                  local unit = WeakAuras.raidUnits[i]

                  if UnitIsUnit(unit, "player") then
                        unit = "player"
                  elseif ( UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) ) then
                        core._displayedUnits[unit] = false
                        core:_initBlip(unit)
                  end

                  core:_addToRoster(unit)
            end
      elseif IsInGroup() then
            for i = 1, GetNumGroupMembers() do
                  local unit = WeakAuras.partyUnits[i]

                  if ( UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) ) then
                        core._displayedUnits[unit] = false
                        core:_initBlip(unit)
                  end

                  core:_addToRoster(unit)
            end
      end

      -- Load static points into the roster
      for name, point in pairs(core._staticPoints) do
            core._displayedUnits[name] = false
            core:_initBlip(name, point[3])
            core:_addToRoster(name, true)
      end

      -- Hide all blips if they shouldn't be displayed
      for unit, blip in pairs(core._blips) do
            if core._displayedUnits[unit] == nil then
                  blip:Hide()
            end
      end
end

--[[
#######################################################################################################################
      LINES
#######################################################################################################################
]]
local linePrototypeDummyFrame = CreateFrame("Frame")
local lineMT = { __index = linePrototypeDummyFrame }

local linePrototype = {
      Draw = function(this, width, extend, danger)
            this:_initialize(width, extend, danger)
            this:Show()
      end,

      Disconnect = function(this)
            this:Hide()
      end,

      Color = function(this, r, g, b, a)
            this.texture:SetVertexColor(r, g, b, a)
      end,

      BelongsTo = function(this, sourceX, sourceY, targetX, targetY)
            local _, pX, pY = core:_getPosition("player")

            if not pX then return false end

            local VECTOR_LENGTH = 300
            local VECTOR_DEPTH = (4/core._scale) * 0.125 * this.width + 1

            local dX = (sourceX - targetX)
            local dY = (sourceY - targetY)
            local dist = math.sqrt(dX * dX + dY * dY)

            local t_cos = (targetX-sourceX) / dist
            local newX = VECTOR_LENGTH * t_cos  +  targetX

            local t_sin = (targetY-sourceY) / dist
            local newY = VECTOR_LENGTH * t_sin  +  targetY

            local radiusX,radiusY = VECTOR_DEPTH * t_sin, VECTOR_DEPTH * t_cos

            local point1x = sourceX + radiusX
            local point1y = sourceY - radiusY

            local point2x = sourceX - radiusX
            local point2y = sourceY + radiusY

            local point3x = newX + radiusX
            local point3y = newY - radiusY

            local point4x = newX - radiusX
            local point4y = newY + radiusY

            return this._belongsTo(pX,pY,point1x,point2x,point4x,point3x,point1y,point2y,point4y,point3y)
      end,

      _belongsTo = function(pX,pY,point1x,point2x,point3x,point4x,point1y,point2y,point3y,point4y)
		local D1 = (pX - point1x) * (point2y - point1y) - (pY - point1y) * (point2x - point1x)
		local D2 = (pX - point2x) * (point3y - point2y) - (pY - point2y) * (point3x - point2x)
		local D3 = (pX - point3x) * (point4y - point3y) - (pY - point3y) * (point4x - point3x)
		local D4 = (pX - point4x) * (point1y - point4y) - (pY - point4y) * (point1x - point4x)

		return (D1 < 0 and D2 < 0 and D3 < 0 and D4 < 0) or (D1 > 0 and D2 > 0 and D3 > 0 and D4 > 0)
      end,

      _getDangerColor = function(this, danger)
            danger = danger or core.constants.lines.danger.danger
            if danger == core.constants.lines.danger.DANGER then
                  return 1, 0, 0, 1
            elseif danger == core.constants.lines.danger.NEUTRAL then
                  return 0, 0, 1, 1
            else
                  return 0, 1, 0, 1
            end
      end,

      _indicateDanger = function(this, inDanger)
            local neutral = false
            local shouldReverse = false

            if this.danger == core.constants.lines.danger.FRIENDLY then
                  shouldReverse = true
            elseif this.danger == core.constants.lines.danger.NEUTRAL then
                  neutral = true
            end

            if neutral then
                  inDanger = false
            elseif shouldReverse then
                  inDanger = not inDanger
            end

            core._inDangerLine = inDanger
      end,

      _updateColor = function(this)
            local srcUnit, srcX, srcY = core:_getPosition(this.source)
            local destUnit, destX, destY = core:_getPosition(this.destination)

            core._inDangerLine = false

            if srcUnit == "player" or destUnit == "player" then return end
            if (not srcX) or (not destX) then return end

            local belongsToOne = this:BelongsTo(srcX, srcY, destX, destY)
            local belongsToTwo = this:BelongsTo(destX, destY, srcX, srcY)

            local danger = this.danger
            local danger2 = core.constants.lines.danger.FRIENDLY

            if this.danger == core.constants.lines.danger.FRIENDLY then
                  danger2 = core.constants.lines.danger.DANGER
            end

            local r1, g1, b1, a1 = this:_getDangerColor(danger)
            local r2, g2, b2, a2 = this:_getDangerColor(danger2)

            if this.extend == core.constants.lines.extend.SEGMENT then
                  if belongsToOne and belongsToTwo then
                        this:Color(r1,g1,b1,a1)
                        this:_indicateDanger(true)
                  else
                        this:Color(r2,g2,b2,a2)
                        this:_indicateDanger(false)
                  end
            elseif this.extend == core.constants.lines.extend.HALF then
                  if belongsToOne then
                        this:Color(r1,g1,b1,a1)
                        this:_indicateDanger(true)
                  else
                        this:Color(r2,g2,b2,a2)
                        this:_indicateDanger(false)
                  end
            else
                  if belongsToOne or belongsToTwo then
                        this:Color(r1,g1,b1,a1)
                        this:_indicateDanger(true)
                  else
                        this:Color(r2,g2,b2,a2)
                        this:_indicateDanger(false)
                  end
            end
      end,

      _initialize = function(this, width, extend, danger)
            extend = extend or core.constants.lines.extend.SEGMENT
            danger = danger or core.constants.lines.danger.DANGER

            this.width = width
            this.extend = extend
            this.danger = danger

            this:SetScript("OnUpdate", this._draw)
      end,

      _destroy = function(this)
            this:SetScript("OnUpdate", nil)
            this:ClearAllPoints()
            this:SetParent(core._frame)
            this:SetPoint("CENTER")
            this:Hide()

            core._lines = core._lines or {}
            core._lines[this.key] = nil
      end,

      _draw = function(this)
            local srcUnit, sx, sy, _ = core:_getRadarPosition(this.source)
            local destUnit, ex, ey, _ = core:_getRadarPosition(this.destination)

            if not srcUnit then return end
            if not destUnit then return end
            if not sx then return end
            if not ex then return end

            local inRange1, inRange2 = sx * sx + sy * sy <= core._range2, ex * ex + ey * ey <= core._range2
            local w = this.width
            local extend = this.extend

            if (not inRange1) or (not inRange2) or (extend ~= 0) then
                  local x3, y3, x4, y4 = core:_intersection(sx, sy, ex, ey, core._range2)

                  if x3 then
                        local dx, dy = ex - sx, ey - sy
                        local p3Same = dx * (x3 - sx) + dy * (y3 - sy) > 0

                        if extend == core.constants.lines.extend.SEGMENT then -- line segment
                              if inRange1 then
                                    if p3Same then
                                          ex, ey = x3, y3
                                    else
                                          ex, ey = x4, y4
                                    end
                              elseif inRange2 then
                                    if -dx*(x3-ex)-dy*(y3-ey) > 0 then
                                          sx, sy = x3, y3
                                    else
                                          sx, sy = x4, y4
                                    end
                              else
                                    ex, ey = sx, sy
                              end
                        elseif extend == core.constants.lines.extend.HALF then -- half-line
                              if inRange1 then
                                    if p3Same then
                                          ex, ey = x3, y3
                                    else
                                          ex, ey = x4, y4
                                    end
                              else
                                    if p3Same then
                                          sx, sy, ex, ey = x3, y3, x4, y4
                                    else
                                          ex, ey = sx, sy
                                    end
                              end
                        else -- line
                              sx, sy, ex, ey = x3, y3, x4, y4
                        end
                  else
                        ex, ey = sx, sy
                  end
            end

            local dx, dy, cx, cy = ex - sx, ey - sy, (sx + ex) / 2, (sy + ey) / 2

            core._dx = dx
            core._dy = dy

            core._cx = cx
            core._cy = cy

            if dx < 0 then
                  dx, dy = -dx, -dy
            end

            local l = math.sqrt((dx * dx) + (dy * dy))
            if l == 0 then
                  this.texture:SetTexCoord(0,0,0,0,0,0,0,0)
                  this:ClearAllPoints()
                  this:SetPoint("BOTTOMLEFT", core._frame, "CENTER", cx, cy)
                  this:SetPoint("TOPRIGHT", core._frame, "CENTER", cx, cy)
            else
                  local s, c = -dy / l, dx / l
                  local sc = s * c

                  local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy;

                  if (dy >= 0) then
                        Bwid = ((l * c) - (w * s)) * core._lineCoeff
                        Bhgt = ((w * c) - (l * s)) * core._lineCoeff
                        BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc;
                        BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx;
                        TRy = BRx;
                  else
                        Bwid = ((l * c) + (w * s)) * core._lineCoeff
                        Bhgt = ((w * c) + (l * s)) * core._lineCoeff
                        BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc;
                        BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy;
                        TRx = TLy;
                  end

                  this.texture:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
                  this:ClearAllPoints()

                  this:SetPoint("BOTTOMLEFT", core._frame, "CENTER", cx - Bwid, cy - Bhgt)
                  this:SetPoint("TOPRIGHT", core._frame, "CENTER", cx + Bwid, cy + Bhgt)
            end

            this:_updateColor()
      end,
}

function core:_genKey(srcGUID, destGUID)
      if not destGUID then
            return srcGUID
      else
            return srcGUID .. "-".. destGUID
      end
end

setmetatable(linePrototype, lineMT)
local linePrototypeMT = { __index = linePrototype }

function core:_createLine(src, dest)
      if not src then
            warn("unable to create line without source")
            return
      end
      if not dest then
            warn("unable to create line without destination")
            return
      end

      local srcGUID = core:FindGUID(src)
      local destGUID = core:FindGUID(dest)

      if not srcGUID then
            warn("guid lookup failed for %s", src)
            return
      end

      if not destGUID then
            warn("guid lookup failed for %s", dest)
            return
      end

      local key = core:_genKey(srcGUID, destGUID)

      core._lines = core._lines or {}
      local line

      if core._lines[key] then
            line = core._lines[key]
      else
            line = CreateFrame("Frame", "WA_RADAR_LINE" .. key, core._frame)
            setmetatable(line, linePrototypeMT)

            line.key = key
            line:SetFrameStrata("MEDIUM")
            line.texture = line.texture or line:CreateTexture(nil, "BACKGROUND", nil, 1)
            line.texture:SetAllPoints()
            line.texture:SetTexture("Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_White")
            line:SetSize(20, 20)

            core._lines[key] = line
      end

      line.source = srcGUID
      line.destination = destGUID

      line.texture:SetVertexColor(0,1,0,1)
      line.texture:SetBlendMode("BLEND")
      line:Hide()

      return line
end

function core:_intersection(x1, y1, x2, y2, r2)
      local dx, dy = x2 - x1, y2 - y1
      local dr2 = dx * dx + dy * dy
      local D = x1 * y2 - x2 * y1
      local Det = r2 * dr2 - D * D

      if Det > 0 then
            local det = dy < 0 and -math.sqrt(Det) or math.sqrt(Det)
            return (D * dy + dx * det)/dr2, (-D * dx + dy * det)/dr2, (D * dy - dx * det)/dr2, (-D * dx - dy * det)/dr2
      end
end

function core:_connect(src, dest, width, extend, danger)
      local line = core:_createLine(src, dest)
      line:Draw(width, extend, danger)
      return line
end

--[[
#######################################################################################################################
      DISKS
#######################################################################################################################
]]
function core:_diskUpdater(disk)
      if not disk then return end
      if not disk.shown then
            disk:Hide()
            return
      end

      local srcUnit, sx, sy, inRange = core:_getRadarPosition(disk.source)

      if not srcUnit then return end
      if not sx then return end

      disk:SetPoint("CENTER", core._frame, "CENTER", sx, sy)

      if inRange then
            disk:Show()
      else
            disk:Hide()
      end
end

local diskDummyFrame = CreateFrame("Frame")
local diskMT = { __index = diskDummyFrame }

local diskPrototype = {

      Draw = function(this, radius, danger)
            danger = danger or core.constants.disks.danger.DANGER

            this:_initialize(radius, danger)
            this.shown = true
            this:Show()
      end,

      Color = function(this, r, g, b, a)
            this.texture:SetVertexColor(r, g, b, a)
      end,

      Destroy = function(this)
            this.shown = false
            this:Hide()
      end,

      _initialize = function(this, radius, danger)
            this.radius = radius
            this.danger = danger
            this:SetScript("OnUpdate", this._draw)
      end,

      _getDangerColor = function(this, danger)
            if danger == core.constants.lines.danger.DANGER then
                  return 1, 0, 0, 0.3
            elseif danger == core.constants.lines.danger.NEUTRAL then
                  return 0, 0, 1, 0.3
            else
                  return 0, 1, 0, 0.3
            end
      end,

      _draw = function(this)
            local radiusScaled = core._scale * this.radius
            local R2 = radiusScaled * core._tCoeff * 2

            this.radiusScaled = radiusScaled
            this:SetSize(R2, R2)

            this:_updateColor()
      end,

      _indicateDanger = function(this, inDanger)
            local neutral = false
            local shouldReverse = false

            if this.danger == core.constants.disks.danger.FRIENDLY then
                  shouldReverse = true
            elseif this.danger == core.constants.disks.danger.NEUTRAL then
                  neutral = true
            end

            if neutral then
                  inDanger = false
            elseif shouldReverse then
                  inDanger = not inDanger
            end

            core._inDangerDisk = inDanger
      end,

      _updateColor = function(this)
            core._inDangerDisk = false

            local danger = this.danger
            local danger2 = core.constants.disks.danger.FRIENDLY

            if this.danger == core.constants.disks.danger.FRIENDLY then
                  danger2 = core.constants.disks.danger.DANGER
            end

            local r1, g1, b1, a1 = this:_getDangerColor(danger)
            local r2, g2, b2, a2 = this:_getDangerColor(danger2)

            local _, pX, pY = core:_getPosition("player")

            if not pX then return end

            local srcUnit, srcX, srcY = core:_getPosition(this.source)

            if not srcUnit then return end
            if not srcX then return end

            local distance = ((pY-srcY)^2+(pX-srcX)^2)^(1/2)

            if distance < this.radius then
                  this:Color(r1,g1,b1,a1)
                  this:_indicateDanger(true)
            else
                  this:Color(r2,g2,b2,a2)
                  this:_indicateDanger(false)
            end
      end,
}

setmetatable(diskPrototype, diskMT)
local diskPrototypeMT = { __index = diskPrototype }

function core:_createDisk(src, text)
      if not src then
            warn("unable to create disk without source")
            return
      end

      local srcGUID = core:FindGUID(src)

      if not srcGUID then
            warn("guid lookup failed for %s", src)
            return
      end

      local key = core:_genKey(srcGUID)

      core._disks = core._disks or {}

      local disk

      if core._disks[key] then
            disk = core._disks[key]
      else
            disk = CreateFrame("Frame", "WA_RADAR_DISK" .. key, core._frame)
            disk.key = key
            setmetatable(disk, diskPrototypeMT)

            disk:SetPoint("CENTER")
            disk:SetFrameStrata("MEDIUM")

            disk.texture = disk.texture or disk:CreateTexture(nil, "BACKGROUND", nil, 1)
            disk.texture:SetAllPoints()
            disk.texture:SetTexture("Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_White")
            disk.texture:SetVertexColor(1, 0, 0, 0.5)

            core._disks[key] = disk
      end

      disk.txt = disk.txt or disk:CreateFontString("WA_RADAR_RISK_TXT_" .. key, "ARTWORK", "GameFontNormalLarge")
      disk.txt:SetPoint("CENTER", disk, "CENTER", 0, 22)
      disk.txt:SetText(text or "")

      disk.source = srcGUID

      disk:Hide()
      return disk
end

--[[
#######################################################################################################################
      DISPLAY UPDATING
#######################################################################################################################
]]
function core:_updater()
      core._facing = GetPlayerFacing()
      core._sin = math.sin(core._facing)
      core._cos = math.cos(core._facing)

      core:_updateRoster()
      core:_updatePositions()

      for unit in pairs(core._displayedUnits) do
            core:_updateBlip(unit)
      end

      for key, disk in pairs(core._disks) do
            core:_diskUpdater(disk)
      end
end

--[[
#######################################################################################################################
      PUBLIC API
#######################################################################################################################
]]

-----------------------------------------------------------------------------------------------------------------------
-- Enables the core module.
-- @return : void
-----------------------------------------------------------------------------------------------------------------------
function core:Enable()
      if core._enabled then return end

      -- before we enable, run the updater once,
      -- make sure everything has an initial value
      core:_updater()

      core._enabled = true
      warn("Radar enabled successfully!")
end

-----------------------------------------------------------------------------------------------------------------------
-- Disables the core module.
-- @return : void
-----------------------------------------------------------------------------------------------------------------------
function core:Disable()
      if core._enabled then
            core:DisconnectAllLines()
            core:DestroyAllDisks()
            core:RemoveAllStatic()
            core:_hideAllBlips()
            core._enabled = false
            warn("Radar disabled successfully!")
      end
end

-----------------------------------------------------------------------------------------------------------------------
-- Indicates wether the core module is enabled.
-- @returns : true if core module is enabled, false otherwise
-----------------------------------------------------------------------------------------------------------------------
function core:IsEnabled()
      if core._enabled then
            return true
      else
            return false
      end
end

-----------------------------------------------------------------------------------------------------------------------
-- Creates a static point on the radar.
-- @param name            : name of the static point, must be unique
-- @param x               : x-coordinate of the static point, or the reference of a known unit to use as position
-- @param y               : y-coordiante of the static point, or the raidTargetIndex if parameter x is a reference
-- @param raidTargetIndex : optional raidTargetIndex to use for the static point
-- @return                : void
-----------------------------------------------------------------------------------------------------------------------
function core:Static(name, x, y, raidTargetIndex)
      if not name then
            warn("unable to create static without a name")
            return
      end

      core._staticPoints = core._staticPoints or {}
      core._roster = core._roster or {}
      core._nameRoster = core._nameRoster or {}
      core._unitRoster = core._unitRoster or {}

      local unit, posX, posY, instanceID = core:_getPosition(x)

      if not unit and not y then
            warn("unable to create static for %s, specifiy a y-coordinate.", name)
            return
      end

      core._roster[name] = name
      core._nameRoster[name] = name
      core._unitRoster[name] = name
      core._staticPoints[name] = core._staticPoints[name] or {}

      if not posX then
            core._staticPoints[name][1] = x
            core._staticPoints[name][2] = y
            core._staticPoints[name][3] = raidTargetIndex
      else
            core._staticPoints[name][1] = posX
            core._staticPoints[name][2] = posY
            core._staticPoints[name][3] = y
      end
end

-----------------------------------------------------------------------------------------------------------------------
-- Removes a static point on the radar.
-- @param name : name of the static point
-- @return     : void
-----------------------------------------------------------------------------------------------------------------------
function core:RemoveStatic(name)
      if not name then
            warn("unable to remove static without a name")
            return
      end

      core._staticPoints = core._staticPoints or {}
      core._roster = core._roster or {}
      core._nameRoster = core._nameRoster or {}
      core._unitRoster = core._unitRoster or {}

      core._roster[name] = nil
      core._nameRoster[name] = nil
      core._unitRoster[name] = nil
      core._staticPoints[name] = nil
end

-----------------------------------------------------------------------------------------------------------------------
-- Removes all static points on the radar.
-- @return : void
-----------------------------------------------------------------------------------------------------------------------
function core:RemoveAllStatic()
      core._staticPoints = core._staticPoints or {}

      for name, _ in pairs(core._staticPoints) do
            core:RemoveStatic(name)
      end
end

-----------------------------------------------------------------------------------------------------------------------
-- Connects a given source and destination on the radar.
-- @param src               : unit reference of the source, can be unitID, guid, name
-- @param dest              : unit reference of the destination, can be unitID, guid, name
-- @param width (optional)  : width of the line
-- @param extend (optional) : extend mode of the line, see constants for explanation
-- @param danger (optional) : danger mode of the line, see constants for explanation
-- @return                  : An instance of the line
-----------------------------------------------------------------------------------------------------------------------
function core:Connect(src, dest, width, extend, danger)
      if not src then
            warn("unable to connect without a source")
            return
      end

      if not dest then
            warn("unable to connect without a destination")
            return
      end

      width = width or core.config._lines._defaultWidth
      extend = extend or core.constants.lines.extend.SEGMENT
      danger = danger or core.constants.lines.danger.DANGER

      return core:_connect(src, dest, width, extend, danger)
end

-----------------------------------------------------------------------------------------------------------------------
-- Disconnects the line for a given source and destination.
-- @param src : unit reference of the source, can be unitID, guid, name
-- @param des : unit reference of the destination, can be unitID, guid, name
-- @return    : void
-----------------------------------------------------------------------------------------------------------------------
function core:Disconnect(src, dest)
      if not src then
            warn("unable to disconnect without a source")
            return
      end

      if not dest then
            warn("unable to disconnect without a destination")
            return
      end

      local line = core:_createLine(src, dest)
      if not line then return end
      line:Disconnect()
end

-----------------------------------------------------------------------------------------------------------------------
-- Disconnects all active lines on the radar.
-- @return : void
-----------------------------------------------------------------------------------------------------------------------
function core:DisconnectAllLines()
      for _, line in pairs(core._lines) do
            line:Disconnect()
      end
end

-----------------------------------------------------------------------------------------------------------------------
-- Places a disk on the radar at the source.
-- @param src               : unit reference of the source, can be unitID, guid, name
-- @param radius            : radius of the disk, in in-game yards
-- @param text (optional)   : text to place on the disk
-- @param danger (optional) : danger mode of the disk, see constants for explanation
-- @return                  : An instance of the disk
-----------------------------------------------------------------------------------------------------------------------
function core:Disk(src, radius, text, danger)
      if not src then
            warn("unable to create a disk without a source")
            return
      end

      radius = radius or core.config._disks._defaultRadius
      danger = danger or core.constants.disks.danger.DANGER

      local disk = core:_createDisk(src, text)
      disk:Draw(radius, danger)
      return disk
end

-----------------------------------------------------------------------------------------------------------------------
-- Removes the disk on the radar at the source.
-- @param src : unit reference of the source, can be unitID, guid, name
-- @return    : void
-----------------------------------------------------------------------------------------------------------------------
function core:RemoveDisk(src)
      if not src then
            warn("unable to remove a disk without a source")
            return
      end

      local disk = core:_createDisk(src)
      disk:Destroy()
end

-----------------------------------------------------------------------------------------------------------------------
-- Destroys all the active disks on the radar.
-- @return : void
-----------------------------------------------------------------------------------------------------------------------
function core:DestroyAllDisks()
      for key, disk in pairs(core._disks) do
            disk:Destroy()
      end
end

-----------------------------------------------------------------------------------------------------------------------
-- Calculates the distance between two unit references
-- @param unit1 : unit reference of the first unit, can be unitID, guid, name
-- @param unit2 : unit reference of the second unit, can be unitID, guid, name
-- @return      : the distance between the two units
-----------------------------------------------------------------------------------------------------------------------
function core:Distance(unit1, unit2)
      local u1, x1, y1, map1 = core:_getPosition(unit1)
      local u2, x2, y2, map2 = core:_getPosition(unit2)

      if (not u1) or (not u2) or (map1 ~= map2) then
            return 0
      else
            local dx, dy = x2 - x1, y2 - y1
            return math.sqrt(dx * dx + dy * dy)
      end
end

-----------------------------------------------------------------------------------------------------------------------
-- Determines if a unit is in range of "me", where "me" is the current player.
-- @param unit  : unit reference of the unit, can be unitID, guid, name
-- @param range : the range to check for, in yards
-- @return      : true if the unit is in range of "me", false otherwise
-----------------------------------------------------------------------------------------------------------------------
function core:IsInRange(unit, range)
      local d = core:Distance("player", unit)

      if d and d <= range then
            return true
      else
            return false
      end
end

-----------------------------------------------------------------------------------------------------------------------
-- Returns an array of unitIDs with all party/raid members who are in range of the specified unit
-- @param unit  : unit reference of the unit, can be unitID, guid, name
-- @param range : the range to check for, in yards
-- @return      : an array of unitIDs
-----------------------------------------------------------------------------------------------------------------------
function core:GetInRangeMembers(unit, range)
      if not unitRef then return end
      if not range then return end

      local members = {}
      for u, _ in pairs(core._roster) do
            local unitIsStatic = core:_isStatic(u)
            if not unitIsStatic then
                  local d = core:Distance(unit, u)
                  if d and d <= range then
                        table.insert(u, members)
                  end
            end
      end

      return members
end

-----------------------------------------------------------------------------------------------------------------------
-- Returns the total count of party/raid members who are in range of the specified unit
-- @param unit  : unit reference of the unit, can be unitID, guid, name
-- @param range : the range to check for, in yards
-- @return      : total count of party/raid members in range of the specified unit
-----------------------------------------------------------------------------------------------------------------------
function core:GetInRangeCount(unit, range)
      local members = core:GetInRangeMembers(unit, range)
      return table.getn(members)
end
