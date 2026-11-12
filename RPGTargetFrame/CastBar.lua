local ADDON_NAME, RPGTF = ...

local function ApplyFont(font_string, size, outline)
    local applied = font_string:SetFont(RPGTF.MEDIA.font, size, outline)
    if applied == false then
        font_string:SetFont("Fonts\\FRIZQT__.TTF", size, outline)
    end
end

local function ShownName(display_name, name)
    if RPGTF.IsPresent(display_name) then
        return display_name
    end
    return name
end

local function ReadCast(unit)
    if UnitCastingInfo then
        local name, display_name, _, start_ms, end_ms, _, _, not_interruptible = UnitCastingInfo(unit)
        if RPGTF.IsPresent(name) or RPGTF.IsPresent(display_name) or RPGTF.IsPresent(start_ms) then
            return {
                name = ShownName(display_name, name),
                start_ms = start_ms,
                end_ms = end_ms,
                not_interruptible = not_interruptible,
                channel = false,
            }
        end
    end

    if UnitChannelInfo then
        local name, display_name, _, start_ms, end_ms, _, not_interruptible = UnitChannelInfo(unit)
        if RPGTF.IsPresent(name) or RPGTF.IsPresent(display_name) or RPGTF.IsPresent(start_ms) then
            return {
                name = ShownName(display_name, name),
                start_ms = start_ms,
                end_ms = end_ms,
                not_interruptible = not_interruptible,
                channel = true,
            }
        end
    end
end

function RPGTF:CreateCastBar(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(14)

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetAllPoints(holder)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(0.9, 0.7, 0.2, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.8)

    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetFrameLevel(bar:GetFrameLevel() + 4)
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    border:SetBackdrop({
        edgeFile = RPGTF.MEDIA.border,
        edgeSize = 10,
        insets = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0,
        },
    })
    border:SetBackdropBorderColor(1, 1, 1, 1)

    local name_text = bar:CreateFontString(nil, "OVERLAY")
    ApplyFont(name_text, 11, "OUTLINE")
    name_text:SetPoint("LEFT", bar, "LEFT", 8, 0)
    name_text:SetJustifyH("LEFT")
    name_text:SetWordWrap(false)

    local time_text = bar:CreateFontString(nil, "OVERLAY")
    ApplyFont(time_text, 11, "OUTLINE")
    time_text:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    time_text:SetJustifyH("RIGHT")

    local shield = bar:CreateTexture(nil, "OVERLAY")
    shield:SetSize(14, 14)
    shield:SetPoint("RIGHT", time_text, "LEFT", -4, 0)
    shield:SetAtlas("nameplates-InterruptShield")
    shield:Hide()

    name_text:SetPoint("RIGHT", shield, "LEFT", -4, 0)

    holder.bar = bar
    holder.name_text = name_text
    holder.time_text = time_text
    holder.shield = shield
    holder:Hide()
    self.cast_bar = holder
end

function RPGTF:HideCastBar()
    local holder = self.cast_bar
    if not holder then
        return
    end
    if self.cast_flash_until and GetTime and GetTime() < self.cast_flash_until then
        return
    end
    holder.bar:SetScript("OnUpdate", nil)
    holder.shield:Hide()
    holder.time_text:SetText("")
    holder:Hide()
    self.cast_active = false
end

function RPGTF:ShowCast(info)
    local holder = self.cast_bar
    if not holder or not info then
        return
    end

    self.cast_flash_until = nil
    holder:Show()
    holder:SetHeight(14)
    self.cast_active = true

    if RPGTF.IsPresent(info.name) then
        holder.name_text:SetText(info.name)
    else
        holder.name_text:SetText("")
    end

    if RPGTF.IsPlain(info.not_interruptible) and info.not_interruptible == true then
        holder.shield:Show()
    else
        holder.shield:Hide()
    end

    holder.bar:SetStatusBarColor(0.9, 0.7, 0.2, 1)
    if holder.bar.SetReverseFill then
        holder.bar:SetReverseFill(info.channel and true or false)
    end

    local start_ms = info.start_ms
    local end_ms = info.end_ms
    if RPGTF.IsPresent(start_ms) and RPGTF.IsPresent(end_ms) then
        holder.bar:SetMinMaxValues(start_ms, end_ms)
    end

    holder.bar:SetScript("OnUpdate", function(bar)
        if not (RPGTF.IsPlain(start_ms) and RPGTF.IsPlain(end_ms)) then
            holder.time_text:SetText("")
            return
        end

        local now = GetTime() * 1000
        bar:SetValue(now)
        local remaining = (end_ms - now) / 1000
        if remaining < 0 then
            remaining = 0
        end
        holder.time_text:SetText(string.format("%.1f", remaining))
    end)
end

function RPGTF:FlashInterruptedCast()
    local holder = self.cast_bar
    if not holder then
        return
    end

    holder:Show()
    holder:SetHeight(14)
    holder.bar:SetStatusBarColor(1, 0.1, 0.1, 1)
    holder.bar:SetScript("OnUpdate", nil)
    self.cast_generation = (self.cast_generation or 0) + 1
    local generation = self.cast_generation
    self.cast_flash_until = GetTime and (GetTime() + 0.2) or nil

    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
            if RPGTF.cast_generation ~= generation then
                return
            end
            RPGTF.cast_flash_until = nil
            RPGTF:HideCastBar()
            if RPGTF.LayoutStack then
                RPGTF:LayoutStack()
            end
        end)
    else
        self.cast_flash_until = nil
        self:HideCastBar()
    end
end

function RPGTF:RenderCast(unit, test_cast)
    if not self.cast_bar then
        return
    end

    if test_cast then
        self:ShowCast(test_cast)
        return
    end

    if self.cast_interrupted then
        self.cast_interrupted = false
        self:FlashInterruptedCast()
        return
    end

    if not unit then
        self:HideCastBar()
        return
    end

    local info = ReadCast(unit)
    if not info then
        self:HideCastBar()
        return
    end

    self:ShowCast(info)
end
