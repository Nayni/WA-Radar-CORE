local WA_TRIGGER = function(event, ...)

      local core = WA_RADAR_CORE
      if not core then return false end

      return core._enabled
end
