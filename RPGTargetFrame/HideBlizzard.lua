local ADDON_NAME, RPGTF = ...

local events = CreateFrame("Frame")
local hidden_frame

local function FindTargetFrame()
    if TargetFrame then
        return TargetFrame
    end
    if TargetFrameContainer then
        return TargetFrameContainer
    end
end

function RPGTF:UpdateBlizzardTargetFrame()
    local hide = self.db and self.db.frame.hide_blizzard == true
    if not hide and not hidden_frame then
        events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    events:UnregisterEvent("PLAYER_REGEN_ENABLED")

    local frame = hidden_frame or FindTargetFrame()
    if hide and not frame then
        if not self.warned_missing_target_frame then
            self.warned_missing_target_frame = true
            self:Print("Could not find TargetFrame or TargetFrameContainer. Use /fstack and report the frame name.")
        end
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        return
    end

    events:UnregisterEvent("PLAYER_ENTERING_WORLD")

    if hide then
        if hidden_frame ~= frame then
            RegisterAttributeDriver(frame, "state-visibility", "hide")
            hidden_frame = frame
        end
    elseif hidden_frame then
        UnregisterAttributeDriver(hidden_frame, "state-visibility")
        hidden_frame:SetAttribute("statehidden", nil)
        if hidden_frame.UpdateShownState then
            hidden_frame:UpdateShownState()
        end
        hidden_frame = nil
    end
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        RPGTF:UpdateBlizzardTargetFrame()
    end
end)
