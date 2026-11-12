local ADDON_NAME, RPGTF = ...

local UNIT_EVENTS = {
    "UNIT_HEALTH",
    "UNIT_MAXHEALTH",
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE",
    "UNIT_FACTION",
    "UNIT_LEVEL",
    "UNIT_CLASSIFICATION_CHANGED",
    "UNIT_FLAGS",
    "UNIT_AURA",
    "UNIT_TARGET",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
}

function RPGTF:ApplyBarSize()
    if not self.bar or not self.frame then
        return
    end
    local settings = self.db.frame
    self:ResizeUnitBar(self.bar, settings.width, settings.height)
    self.frame:SetSize(self.bar.frame:GetWidth(), self.bar.frame:GetHeight())
end

function RPGTF:LayoutStack()
    if not self.bar or not self.auras or not self.cast_bar or not self.tot then
        return
    end

    local health = self.bar.health_bar
    local y = -4
    if self.bar.power_bar and self.bar.power_bar:IsShown() then
        y = -(2 + 8 + 4)
    end

    local function PlaceRow(row)
        row:ClearAllPoints()
        if not row:IsShown() then
            return
        end
        row:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, y)
        y = y - row:GetHeight() - 2
    end

    PlaceRow(self.auras.buffs)
    PlaceRow(self.auras.debuffs)

    local cast = self.cast_bar
    cast:ClearAllPoints()
    if cast:IsShown() then
        cast:SetWidth(self.bar.width)
        cast:SetHeight(14)
        cast:SetPoint("TOP", health, "BOTTOM", 0, y)
        y = y - 14
    end

    self.tot.frame:ClearAllPoints()
    self.tot.frame:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, y - 6)
end

function RPGTF:RenderTargetOfTarget(unit)
    if not self.tot then
        return
    end

    if self.testing then
        self.tot.frame:Show()
        self:RenderUnitBar(self.tot, "targettarget", self:TestTargetOfTarget())
        return
    end

    if not UnitExists("targettarget") then
        self.tot.frame:Hide()
        return
    end

    self.tot.frame:Show()
    self:RenderUnitBar(self.tot, unit or "targettarget", nil)
end

function RPGTF:UpdateUnit()
    if self.testing then
        return
    end
    if not self.frame then
        return
    end
    if not UnitExists("target") then
        self.frame:Hide()
        return
    end

    self.frame:Show()
    self:RenderUnitBar(self.bar, "target", nil)
    self:RenderAuras("target")
    self:RenderCast("target")
    self:RenderTargetOfTarget("targettarget")
    self:LayoutStack()
end

function RPGTF:CreateMainFrame()
    local settings = self.db.frame
    local frame = CreateFrame("Frame", "RPGTargetFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    self.frame = frame

    self.bar = self:CreateUnitBar(frame, "RPGTargetFrameBar", {
        width = settings.width,
        height = settings.height,
    })
    self.bar.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame:SetSize(self.bar.frame:GetWidth(), self.bar.frame:GetHeight())

    self:CreateAuraRows(frame)
    self:CreateCastBar(frame)
    self.tot = self:CreateUnitBar(frame, "RPGTargetFrameToT", {
        width = 160,
        height = 18,
        name_size = 12,
        info_size = 10,
        show_power = false,
    })
    self.tot.frame:Hide()

    self:SetupDrag(frame)
    frame:Hide()
end

local driver = CreateFrame("Frame")

local function OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then
            return
        end

        RPGTF:InitDB()
        RPGTF:CreateMainFrame()
        RPGTF:ApplyFramePlacement()
        RPGTF:UpdateBlizzardTargetFrame()
        RPGTF:UpdateUnit()

        driver:UnregisterEvent("ADDON_LOADED")
        driver:RegisterEvent("PLAYER_TARGET_CHANGED")
        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
        for _, event_name in ipairs(UNIT_EVENTS) do
            driver:RegisterUnitEvent(event_name, "target")
        end

        RPGTF:Print("Loaded. Use /rpgtt for commands.")
        return
    end

    if RPGTF.testing then
        return
    end

    if event == "UNIT_SPELLCAST_INTERRUPTED" then
        RPGTF.cast_interrupted = true
    end

    RPGTF:UpdateUnit()
end

driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", OnEvent)
