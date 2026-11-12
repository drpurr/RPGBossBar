local ADDON_NAME, RPGTF = ...

local TEST_AURAS = {
    buffs = {
        { icon = "Interface\\Icons\\Spell_Holy_Heal", applications = 1 },
        { icon = "Interface\\Icons\\INV_Misc_QuestionMark", applications = 3 },
    },
    debuffs = {
        { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", applications = 1 },
    },
}

local function Trim(msg)
    return (msg or ""):match("^%s*(.-)%s*$") or ""
end

function RPGTF:ApplyFramePlacement()
    local frame = self.frame
    if not frame or not self.db then
        return
    end

    local settings = self.db.frame
    frame:ClearAllPoints()
    frame:SetPoint(settings.point, UIParent, settings.relative_point, settings.x, settings.y)
    frame:SetScale(settings.scale)
end

function RPGTF:SaveFramePlacement()
    local point, _, relative_point, x, y = self.frame:GetPoint(1)
    self.db.frame.point = point
    self.db.frame.relative_point = relative_point
    self.db.frame.x = x
    self.db.frame.y = y
end

function RPGTF:SetupDrag(frame)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(drag_frame)
        if RPGTF.db.frame.locked then
            return
        end
        drag_frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(drag_frame)
        drag_frame:StopMovingOrSizing()
        RPGTF:SaveFramePlacement()
    end)
end

function RPGTF:TestSnapshot()
    return {
        name = "Preview Elite",
        reaction = 2,
        health = 65,
        max_health = 100,
        health_percent = 65,
        power = 80,
        max_power = 100,
        power_type = 0,
        level = 20,
        player_level = 60,
        classification = "elite",
        dead = false,
    }
end

function RPGTF:TestTargetOfTarget()
    return {
        name = "Training Dummy",
        reaction = 4,
        health = 40,
        max_health = 100,
        health_percent = 40,
        power = 0,
        max_power = 0,
        power_type = 0,
        level = 18,
        player_level = 60,
        classification = "normal",
        dead = false,
    }
end

function RPGTF:TestCastInfo()
    local now = 0
    if GetTime then
        now = GetTime() * 1000
    end
    return {
        name = "Preview Cast",
        start_ms = now,
        end_ms = now + 4000,
        not_interruptible = true,
        channel = false,
    }
end

function RPGTF:ShowTest()
    self.testing = true
    self.frame:Show()
    self:RenderUnitBar(self.bar, "target", self:TestSnapshot())
    self:RenderAuras(nil, TEST_AURAS)
    self:RenderCast(nil, self:TestCastInfo())
    self:RenderTargetOfTarget("targettarget")
    self:LayoutStack()
end

function RPGTF:HideTest()
    self.testing = false
    self:UpdateUnit()
end

function RPGTF:ToggleTest()
    if self.testing then
        self:HideTest()
        self:Print("Test mode off.")
    else
        self:ShowTest()
        self:Print("Test mode on.")
    end
end

local function PrintHelp()
    RPGTF:Print("Commands: /rpgtt lock, /rpgtt scale N, /rpgtt blizzard, /rpgtt test, /rpgtt reset")
end

local function Handle(msg)
    if not RPGTF.db or not RPGTF.frame then
        RPGTF:Print("Still loading.")
        return
    end

    local text = Trim(msg):lower()
    local cmd, rest = text:match("^(%S+)%s*(.*)$")
    if not cmd or cmd == "" or cmd == "help" then
        PrintHelp()
        return
    end

    if cmd == "lock" then
        RPGTF.db.frame.locked = not RPGTF.db.frame.locked
        if RPGTF.db.frame.locked then
            RPGTF:Print("Locked.")
        else
            RPGTF:Print("Unlocked. Drag the frame to move it.")
        end
        return
    end

    if cmd == "scale" then
        local scale = tonumber(rest)
        if not scale or scale < 0.5 or scale > 2 then
            RPGTF:Print("Scale must be between 0.5 and 2.")
            return
        end
        RPGTF.db.frame.scale = scale
        RPGTF:ApplyFramePlacement()
        RPGTF:Print("Scale set to " .. scale .. ".")
        return
    end

    if cmd == "blizzard" then
        RPGTF.db.frame.hide_blizzard = not RPGTF.db.frame.hide_blizzard
        RPGTF:UpdateBlizzardTargetFrame()
        if RPGTF.db.frame.hide_blizzard then
            RPGTF:Print("Default target frame hidden.")
        else
            RPGTF:Print("Default target frame restored.")
        end
        return
    end

    if cmd == "test" then
        RPGTF:ToggleTest()
        return
    end

    if cmd == "reset" then
        RPGTF.testing = false
        RPGTF:ResetDB()
        RPGTF:ApplyFramePlacement()
        RPGTF:ApplyBarSize()
        RPGTF:UpdateBlizzardTargetFrame()
        RPGTF:UpdateUnit()
        RPGTF:Print("Settings reset.")
        return
    end

    PrintHelp()
end

SLASH_RPGTARGETFRAME1 = "/rpgtt"
SLASH_RPGTARGETFRAME2 = "/rpgtargetframe"
SlashCmdList["RPGTARGETFRAME"] = Handle
