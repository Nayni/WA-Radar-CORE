local CUSTOM_DISPLAY = function()

      local core = WA_RADAR_CORE
      if not core then return end

      local frame = WeakAuras["regions"][aura_env.id]["region"]
      core._frame = frame

      local width = max(frame:GetWidth(), frame:GetHeight())
      frame:SetWidth(width)
      frame:SetHeight(width)

      core:_updateScale(width)

      -- frame.border = frame.border or frame:CreateTexture(nil, "BACKGROUND")
      -- frame.border:SetTexture("Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_White_Border")
      -- frame.border:SetPoint("TOPLEFT", -10, 10)
      -- frame.border:SetPoint("BOTTOMRIGHT", 10, -10)
      -- frame.border:SetVertexColor(0, 0, 0, 0.3)

      frame.border = frame.border or frame:CreateTexture(nil, "BACKGROUND")
      frame.border:SetTexture("Interface\\Minimap\\UI-MINIMAP-BORDER")
      frame.border:SetPoint("TOPLEFT", -10, 10)
      frame.border:SetPoint("BOTTOMRIGHT", 10, -10)
      frame.border:SetTexCoord(.5, 0, 0, 0.5)
      --frame.border:SetVertexColor(0, 0, 0, 1)

      frame.background = frame.background or frame:CreateTexture(nil, "BACKGROUND")
      frame.background:SetTexture("Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Smooth_Border")
      frame.background:SetAllPoints(frame)

      if core._inDangerLine or core._inDangerDisk then
            frame.background:SetVertexColor(.6, .3, .3, 0.7)
      else
            frame.background:SetVertexColor(.3, .3, .3, 0.7)
      end

      frame.arrow = frame.arrow or CreateFrame("Frame", nil, frame)
      frame.arrow:SetFrameStrata("HIGH")
      frame.arrow:SetPoint("CENTER")
      frame.arrow:SetSize(24, 24)
      frame.arrow.t = frame.arrow.t or frame.arrow:CreateTexture(nil, "BORDER")
      frame.arrow.t:SetAllPoints()
      frame.arrow.t:SetTexture([[Interface\MINIMAP\MiniMap-DeadArrow]])

      core._updater()
end
