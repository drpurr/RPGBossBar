local ADDON_NAME, RPGTF = ...

local ICON_SIZE = 22
local ICON_GAP = 2
local MAX_AURAS = 8

local function ApplyFont(font_string, size, outline)
    local applied = font_string:SetFont(RPGTF.MEDIA.font, size, outline)
    if applied == false then
        font_string:SetFont("Fonts\\FRIZQT__.TTF", size, outline)
    end
end

local function HideButton(button)
    button.stack:SetText("")
    button:Hide()
end

local function FillButton(button, icon, applications)
    if not RPGTF.IsPlain(icon) then
        HideButton(button)
        return false
    end

    button.icon:SetTexture(icon)
    if RPGTF.IsPlain(applications) and applications > 1 then
        button.stack:SetText(tostring(applications))
    else
        button.stack:SetText("")
    end
    button:Show()
    return true
end

local function HideRow(row)
    for index = 1, MAX_AURAS do
        HideButton(row.buttons[index])
    end
    row:Hide()
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize((ICON_SIZE * MAX_AURAS) + (ICON_GAP * (MAX_AURAS - 1)), ICON_SIZE)
    row.buttons = {}

    for index = 1, MAX_AURAS do
        local button = CreateFrame("Button", nil, row)
        button:SetSize(ICON_SIZE, ICON_SIZE)
        if index == 1 then
            button:SetPoint("LEFT", row, "LEFT", 0, 0)
        else
            button:SetPoint("LEFT", row.buttons[index - 1], "RIGHT", ICON_GAP, 0)
        end

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()

        button.stack = button:CreateFontString(nil, "OVERLAY")
        ApplyFont(button.stack, 10, "OUTLINE")
        button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.stack:SetJustifyH("RIGHT")
        button.stack:SetText("")
        button:Hide()

        row.buttons[index] = button
    end

    row:Hide()
    return row
end

function RPGTF:CreateAuraRows(parent)
    self.auras = {
        buffs = CreateRow(parent),
        debuffs = CreateRow(parent),
    }
end

function RPGTF:ApplyAuraList(row, list)
    list = list or {}
    local shown = 0
    for index = 1, MAX_AURAS do
        local entry = list[index]
        if entry and FillButton(row.buttons[index], entry.icon, entry.applications) then
            shown = shown + 1
        else
            HideButton(row.buttons[index])
        end
    end
    row:SetShown(shown > 0)
end

function RPGTF:ReadAuraFilter(row, unit, filter)
    local shown = 0
    for index = 1, MAX_AURAS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        local button = row.buttons[index]
        local secret = (issecretvalue and issecretvalue(aura)) or (issecrettable and issecrettable(aura))
        if secret then
            HideButton(button)
        elseif aura == nil then
            HideButton(button)
            for rest = index + 1, MAX_AURAS do
                HideButton(row.buttons[rest])
            end
            break
        elseif canaccessvalue and not canaccessvalue(aura) then
            HideButton(button)
        else
            local icon = aura.icon
            local applications = aura.applications
            if FillButton(button, icon, applications) then
                shown = shown + 1
            end
        end
    end
    row:SetShown(shown > 0)
end

function RPGTF:RenderAuras(unit, test_auras)
    if not self.auras then
        return
    end

    if test_auras then
        self:ApplyAuraList(self.auras.buffs, test_auras.buffs)
        self:ApplyAuraList(self.auras.debuffs, test_auras.debuffs)
        return
    end

    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        HideRow(self.auras.buffs)
        HideRow(self.auras.debuffs)
        return
    end

    if not unit or not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        HideRow(self.auras.buffs)
        HideRow(self.auras.debuffs)
        return
    end

    self:ReadAuraFilter(self.auras.buffs, unit, "HELPFUL")
    self:ReadAuraFilter(self.auras.debuffs, unit, "HARMFUL")
end
