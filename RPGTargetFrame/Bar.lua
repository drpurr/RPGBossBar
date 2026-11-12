local ADDON_NAME, RPGTF = ...

local CLASS_TEXT = {
    worldboss = "Boss",
    rareelite = "Rare Elite",
    elite = "Elite",
    rare = "Rare",
}

local CLASS_COLOR = {
    worldboss = { 1.0, 0.1, 0.1 },
    rareelite = { 1.0, 0.5, 0.0 },
    elite = { 1.0, 0.6, 0.1 },
    rare = { 0.6, 0.7, 1.0 },
    trivial = { 0.6, 0.6, 0.6 },
    normal = { 1, 1, 1 },
    minus = { 0.6, 0.6, 0.6 },
}

local POWER_COLORS = {
    [0] = { 0.20, 0.40, 1.00 },
    [1] = { 1.00, 0.10, 0.10 },
    [2] = { 1.00, 0.50, 0.10 },
    [3] = { 1.00, 1.00, 0.20 },
    [6] = { 0.20, 0.80, 1.00 },
}

local function ApplyFont(font_string, size, outline)
    local applied = font_string:SetFont(RPGTF.MEDIA.font, size, outline)
    if applied == false then
        font_string:SetFont("Fonts\\FRIZQT__.TTF", size, outline)
    end
end

local function ReactionColor(reaction)
    if not RPGTF.IsPlain(reaction) then
        return 1, 1, 1
    end
    if reaction <= 4 then
        return 0.9, 0.1, 0.1
    end
    if reaction == 5 then
        return 1, 0.9, 0.2
    end
    return 0.1, 0.9, 0.1
end

local function PowerKey(power_type)
    local power = Enum and Enum.PowerType
    if not power then
        return power_type
    end
    if power_type == power.Mana then
        return 0
    end
    if power_type == power.Rage then
        return 1
    end
    if power_type == power.Focus then
        return 2
    end
    if power_type == power.Energy then
        return 3
    end
    if power_type == power.RunicPower then
        return 6
    end
    return power_type
end

local function PowerColor(power_type)
    if not RPGTF.IsPlain(power_type) then
        return 1, 1, 1
    end
    local color = POWER_COLORS[PowerKey(power_type)]
    if not color then
        return 1, 1, 1
    end
    return color[1], color[2], color[3]
end

local function FormatHealth(value)
    if not RPGTF.IsPlain(value) then
        return ""
    end
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end
    return tostring(value)
end

local function UnitSnapshot(unit)
    local health_percent
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        health_percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    end

    return {
        name = UnitName(unit),
        reaction = UnitReaction(unit, "player"),
        health = UnitHealth(unit),
        max_health = UnitHealthMax(unit),
        health_percent = health_percent,
        power = UnitPower(unit),
        max_power = UnitPowerMax(unit),
        power_type = UnitPowerType(unit),
        level = UnitLevel(unit),
        player_level = UnitLevel("player"),
        classification = UnitClassification(unit),
        dead = UnitIsDeadOrGhost(unit),
    }
end

function RPGTF:CreateUnitBar(parent, name, opts)
    opts = opts or {}
    local width = opts.width or self.db.frame.width
    local height = opts.height or self.db.frame.height
    local name_size = opts.name_size or 16
    local info_size = opts.info_size or 12
    local show_power = opts.show_power ~= false
    local name_gap = name_size + 4
    local power_block = show_power and 12 or 0

    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(width, name_gap + height + power_block)

    local health_bar = CreateFrame("StatusBar", name .. "Health", frame)
    health_bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -name_gap)
    health_bar:SetSize(width, height)
    health_bar:SetMinMaxValues(0, 1)
    health_bar:SetValue(0)

    local background = health_bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.8)

    self:ApplyHealthFill(health_bar)
    self:ApplyArt(health_bar, width, height)

    local power_bar
    if show_power then
        power_bar = CreateFrame("StatusBar", name .. "Power", frame)
        power_bar:SetHeight(8)
        power_bar:SetWidth(width * 0.8)
        power_bar:SetPoint("TOP", health_bar, "BOTTOM", 0, -2)
        power_bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        power_bar:SetStatusBarColor(1, 1, 1, 1)
        power_bar:SetMinMaxValues(0, 1)
        power_bar:SetValue(0)

        local power_background = power_bar:CreateTexture(nil, "BACKGROUND")
        power_background:SetAllPoints()
        power_background:SetColorTexture(0, 0, 0, 0.8)
    end

    local text_frame = CreateFrame("Frame", nil, health_bar)
    text_frame:SetAllPoints(health_bar)
    text_frame:SetFrameLevel(health_bar:GetFrameLevel() + 20)

    local name_text = frame:CreateFontString(nil, "OVERLAY")
    ApplyFont(name_text, name_size, "THICKOUTLINE")
    name_text:SetPoint("BOTTOMLEFT", health_bar, "TOPLEFT", 0, 2)
    name_text:SetWidth(math.floor(width * 0.62))
    name_text:SetJustifyH("LEFT")
    name_text:SetWordWrap(false)

    local level_text = frame:CreateFontString(nil, "OVERLAY")
    ApplyFont(level_text, info_size, "THICKOUTLINE")
    level_text:SetPoint("BOTTOMRIGHT", health_bar, "TOPRIGHT", 0, 2)
    level_text:SetJustifyH("RIGHT")

    local class_text = frame:CreateFontString(nil, "OVERLAY")
    ApplyFont(class_text, info_size, "THICKOUTLINE")
    class_text:SetPoint("RIGHT", level_text, "LEFT", -4, 0)
    class_text:SetJustifyH("RIGHT")

    local health_text = text_frame:CreateFontString(nil, "OVERLAY")
    ApplyFont(health_text, info_size, "OUTLINE")
    health_text:SetPoint("LEFT", health_bar, "LEFT", 8, 0)
    health_text:SetJustifyH("LEFT")

    local percent_text = text_frame:CreateFontString(nil, "OVERLAY")
    ApplyFont(percent_text, info_size, "OUTLINE")
    percent_text:SetPoint("RIGHT", health_bar, "RIGHT", -8, 0)
    percent_text:SetJustifyH("RIGHT")

    local dead_text = text_frame:CreateFontString(nil, "OVERLAY")
    ApplyFont(dead_text, info_size, "THICKOUTLINE")
    dead_text:SetPoint("CENTER", health_bar, "CENTER", 0, 0)
    dead_text:SetText("")
    dead_text:Hide()

    return {
        frame = frame,
        health_bar = health_bar,
        power_bar = power_bar,
        name_text = name_text,
        health_text = health_text,
        percent_text = percent_text,
        level_text = level_text,
        class_text = class_text,
        dead_text = dead_text,
        width = width,
        height = height,
        name_size = name_size,
        show_power = show_power,
    }
end

function RPGTF:ResizeUnitBar(bar, width, height)
    local name_gap = (bar.name_size or 16) + 4
    local power_block = bar.show_power and 12 or 0
    bar.width = width
    bar.height = height
    bar.frame:SetSize(width, name_gap + height + power_block)
    bar.health_bar:SetSize(width, height)
    self:ApplyArt(bar.health_bar, width, height)
    if bar.power_bar then
        bar.power_bar:SetWidth(width * 0.8)
    end
    if bar.name_text then
        bar.name_text:SetWidth(math.floor(width * 0.62))
    end
    self:ApplySpark(bar.health_bar, height)
end

function RPGTF:RenderUnitBar(bar, unit, test_data)
    if not bar then
        return
    end

    local snapshot = test_data or UnitSnapshot(unit)
    local health = snapshot.health
    local max_health = snapshot.max_health
    local dead = snapshot.dead
    if RPGTF.IsPlain(dead) and dead == true and RPGTF.IsPlain(health) and RPGTF.IsPlain(max_health) then
        health = 0
    end

    if RPGTF.IsPlain(max_health) and max_health <= 0 then
        bar.health_bar:SetMinMaxValues(0, 1)
        bar.health_bar:SetValue(0)
    else
        bar.health_bar:SetMinMaxValues(0, max_health or 1)
        bar.health_bar:SetValue(health or 0)
    end
    self:ApplySpark(bar.health_bar, bar.height)

    if RPGTF.IsPresent(snapshot.name) then
        bar.name_text:SetText(snapshot.name)
    else
        bar.name_text:SetText("")
    end
    local name_r, name_g, name_b = ReactionColor(snapshot.reaction)
    bar.name_text:SetTextColor(name_r, name_g, name_b)

    bar.health_text:SetText(FormatHealth(health))
    if RPGTF.IsPlain(snapshot.health_percent) then
        bar.percent_text:SetText(string.format("%.1f%%", snapshot.health_percent))
    else
        bar.percent_text:SetText("")
    end

    if bar.show_power and bar.power_bar then
        local max_power = snapshot.max_power
        if RPGTF.IsPlain(max_power) and max_power <= 0 then
            bar.power_bar:Hide()
        else
            bar.power_bar:Show()
            bar.power_bar:SetMinMaxValues(0, max_power or 1)
            bar.power_bar:SetValue(snapshot.power or 0)
            local power_r, power_g, power_b = PowerColor(snapshot.power_type)
            bar.power_bar:SetStatusBarColor(power_r, power_g, power_b, 1)
        end
    end

    local classification = snapshot.classification
    if RPGTF.IsPlain(classification) then
        bar.class_text:SetText(CLASS_TEXT[classification] or "")
    else
        bar.class_text:SetText("")
    end

    local level = snapshot.level
    if not RPGTF.IsPlain(level) then
        bar.level_text:SetText("")
    else
        if level < 0 then
            bar.level_text:SetText("??")
        else
            bar.level_text:SetText(tostring(level))
        end
        if RPGTF.IsPlain(snapshot.player_level) and RPGTF.IsPlain(classification) then
            local color = CLASS_COLOR[classification] or { 1, 1, 1 }
            bar.level_text:SetTextColor(color[1], color[2], color[3])
        else
            bar.level_text:SetTextColor(1, 1, 1)
        end
    end

    if RPGTF.IsPlain(dead) and dead == true then
        bar.dead_text:SetText("Dead")
        bar.dead_text:Show()
    else
        bar.dead_text:SetText("")
        bar.dead_text:Hide()
    end

    bar.frame:Show()
end
