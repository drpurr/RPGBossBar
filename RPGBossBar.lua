local ADDON_NAME, RPGBB = ...

-------------------------------------------------------------------------------
--- Configuration Variables
-------------------------------------------------------------------------------

local addon_color = "ff46226a"

local testing = false
local test_frame_count = 2
local verbose = false

--- Strata levels
local POWER_BAR_LEVEL    = 3
local POWER_BORDER_LEVEL = 4
local HEALTH_BAR_LEVEL   = 5
local FRAME_BORDER_LEVEL = 10
local SPARK_LEVEL        = 11
local TEXT_LEVEL         = 12
local GRAPHICS_LEVEL     = 15


-------------------------------------------------------------------------------
--- Runtime State
-------------------------------------------------------------------------------

RPGBB.health_bars = {}
RPGBB.current_boss_frames = {}

function RPGBB:IsTrackingTarget()
    return RPGBB.db:Get("frame", "track_target") == true
end

function RPGBB:GetMaxBossFrames()
    if RPGBB:IsTrackingTarget() then
        return 1
    end

    local count = tonumber(RPGBB.db:Get("frame", "max_frames")) or RPGBB.db_defaults.frame.max_frames

    return math.max(1, math.min(5, math.floor(count)))
end

local function GetTargetUnit()
    -- Keep the concrete unit token so unit events match the displayed bar.
    if UnitExists("target") then
        return "target"
    elseif UnitExists("softenemy") then
        return "softenemy"
    end
end

local function IsShowingTestData()
    return testing and (not RPGBB:IsTrackingTarget() or not GetTargetUnit())
end

local function GetTrackedUnits()
    local boss_frames = {}

    if RPGBB:IsTrackingTarget() then
        local unit = GetTargetUnit()
        if unit then
            if not UnitIsDeadOrGhost(unit) and UnitCanAttack("player", unit) then
                boss_frames[1] = unit
            end
        elseif testing then
            boss_frames[1] = "target"
        end

        return boss_frames
    end

    local max_frames = RPGBB:GetMaxBossFrames()
    local frame_count = testing and test_frame_count or 5

    for i = 1, frame_count do
        local unit = "boss" .. i
        if testing then
            table.insert(boss_frames, unit)
        elseif UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            local classification = UnitClassification(unit)
            if classification == "elite" or classification == "worldboss" then
                table.insert(boss_frames, unit)
            end
        end

        if #boss_frames >= max_frames then
            break
        end
    end

    return boss_frames
end


-------------------------------------------------------------------------------
--- Border Rendering
-------------------------------------------------------------------------------

local NINE_SLICE_PIECES = {
    "TopLeftCorner",
    "TopRightCorner",
    "BottomLeftCorner",
    "BottomRightCorner",
    "TopEdge",
    "BottomEdge",
    "LeftEdge",
    "RightEdge",
    "Center",
}

local function HideNineSliceBorder(frame)
    if not frame then
        return
    end

    for _, pieceName in ipairs(NINE_SLICE_PIECES) do
        if frame[pieceName] then
            frame[pieceName]:Hide()
        end
    end

    if frame.FullAtlas then
        frame.FullAtlas:Hide()
    end

    if frame.FullAtlasTopTiles then
        for _, texture in ipairs(frame.FullAtlasTopTiles) do
            texture:Hide()
        end
    end

    if frame.FullAtlasBottomTiles then
        for _, texture in ipairs(frame.FullAtlasBottomTiles) do
            texture:Hide()
        end
    end

    if frame.HorizontalTopEdge then
        frame.HorizontalTopEdge:Hide()
    end

    if frame.HorizontalBottomEdge then
        frame.HorizontalBottomEdge:Hide()
    end

    frame:Hide()
end

local function SetFullAtlasTileTexture(texture, atlasInfo, crop, visibleFraction)
    local textureAsset = atlasInfo.file or atlasInfo.filename
    if not textureAsset then
        return false
    end

    local atlasWidth = atlasInfo.rightTexCoord - atlasInfo.leftTexCoord
    local atlasHeight = atlasInfo.bottomTexCoord - atlasInfo.topTexCoord
    local left = atlasInfo.leftTexCoord + crop.left * atlasWidth
    local right = atlasInfo.leftTexCoord + crop.right * atlasWidth
    local top = atlasInfo.topTexCoord + crop.top * atlasHeight
    local bottom = atlasInfo.topTexCoord + crop.bottom * atlasHeight

    texture:SetTexture(textureAsset)
    texture:SetTexCoord(left, left + (right - left) * visibleFraction, top, bottom)

    return true
end

local function ShowFullAtlasEdgeTiles(frame, style, borderSize, r, g, b, a)
    local fullAtlas = style.fullAtlas
    local atlasInfo = C_Texture.GetAtlasInfo(fullAtlas.atlas)
    if not atlasInfo then
        return false
    end

    local sampleLeft = fullAtlas.sampleLeft or 0.25
    local sampleRight = fullAtlas.sampleRight or 0.75
    local topBottom = fullAtlas.topBottom or 0.10
    local bottomTop = fullAtlas.bottomTop or 0.90
    local sourceWidth = atlasInfo.width * (sampleRight - sampleLeft)
    local sourceHeight = atlasInfo.height * topBottom
    if sourceWidth <= 0 or sourceHeight <= 0 then
        return false
    end

    local tileWidth = borderSize * sourceWidth / sourceHeight
    local frameWidth = frame:GetWidth()
    local tileCount = math.ceil(frameWidth / tileWidth)

    frame.FullAtlasTopTiles = frame.FullAtlasTopTiles or {}
    frame.FullAtlasBottomTiles = frame.FullAtlasBottomTiles or {}

    local topCrop = {
        left = sampleLeft,
        right = sampleRight,
        top = 0,
        bottom = topBottom,
    }
    local bottomCrop = {
        left = sampleLeft,
        right = sampleRight,
        top = bottomTop,
        bottom = 1,
    }

    for i = 1, tileCount do
        local x = (i - 1) * tileWidth
        local width = math.min(tileWidth, frameWidth - x)
        local visibleFraction = width / tileWidth

        local topTexture = frame.FullAtlasTopTiles[i]
        if not topTexture then
            topTexture = frame:CreateTexture(nil, "BORDER")
            frame.FullAtlasTopTiles[i] = topTexture
        end

        topTexture:ClearAllPoints()
        topTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
        topTexture:SetSize(width, borderSize)
        if not SetFullAtlasTileTexture(topTexture, atlasInfo, topCrop, visibleFraction) then
            return false
        end
        topTexture:SetVertexColor(r, g, b, a)
        topTexture:Show()

        local bottomTexture = frame.FullAtlasBottomTiles[i]
        if not bottomTexture then
            bottomTexture = frame:CreateTexture(nil, "BORDER")
            frame.FullAtlasBottomTiles[i] = bottomTexture
        end

        bottomTexture:ClearAllPoints()
        bottomTexture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 0)
        bottomTexture:SetSize(width, borderSize)
        if not SetFullAtlasTileTexture(bottomTexture, atlasInfo, bottomCrop, visibleFraction) then
            return false
        end
        bottomTexture:SetVertexColor(r, g, b, a)
        bottomTexture:Show()
    end

    frame:Show()

    return true
end

local function ShowModernBorder(frame, style, borderSize, r, g, b, a)
    HideNineSliceBorder(frame)

    if style.fullAtlas then
        ShowFullAtlasEdgeTiles(frame, style, borderSize, r, g, b, a)
        return
    end

    if not style.topAtlas then
        local layout = RPGBB:GetNineSliceStyleLayout(style)

        -- Some named layouts don't exist on every client (e.g. WoW Forever).
        if not layout then
            RPGBB:VPrint("Border layout unavailable on this client: " .. tostring(style.layoutName))
            return false
        end

        NineSliceUtil.ApplyLayout(frame, layout, style.textureKit)

        if not frame.TopEdge or not frame.BottomEdge then
            HideNineSliceBorder(frame)
            return false
        end

        for _, pieceName in ipairs(NINE_SLICE_PIECES) do
            if frame[pieceName] then
                frame[pieceName]:Hide()
            end
        end

        frame.TopEdge:ClearAllPoints()
        frame.TopEdge:SetPoint("TOPLEFT", frame, "TOPLEFT")
        frame.TopEdge:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
        frame.TopEdge:SetHeight(borderSize)
        frame.TopEdge:SetVertexColor(r, g, b, a)
        frame.TopEdge:Show()

        frame.BottomEdge:ClearAllPoints()
        frame.BottomEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        frame.BottomEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
        frame.BottomEdge:SetHeight(borderSize)
        frame.BottomEdge:SetVertexColor(r, g, b, a)
        frame.BottomEdge:Show()

        frame:Show()

        return
    end

    if not frame.HorizontalTopEdge then
        frame.HorizontalTopEdge = frame:CreateTexture(nil, "BORDER")
    end

    frame.HorizontalTopEdge:ClearAllPoints()
    frame.HorizontalTopEdge:SetPoint("TOPLEFT", frame, "TOPLEFT")
    frame.HorizontalTopEdge:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    frame.HorizontalTopEdge:SetHeight(borderSize)

    if not frame.HorizontalBottomEdge then
        frame.HorizontalBottomEdge = frame:CreateTexture(nil, "BORDER")
    end

    frame.HorizontalBottomEdge:ClearAllPoints()
    frame.HorizontalBottomEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    frame.HorizontalBottomEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    frame.HorizontalBottomEdge:SetHeight(borderSize)

    local topAtlas, bottomAtlas = RPGBB:GetHorizontalBorderAtlases(style)

    frame.HorizontalTopEdge:SetAtlas(topAtlas, false, nil, true)
    frame.HorizontalTopEdge:ClearTextureSlice()
    frame.HorizontalTopEdge:SetHorizTile(true)
    frame.HorizontalTopEdge:SetVertTile(false)

    frame.HorizontalBottomEdge:SetAtlas(bottomAtlas, false, nil, true)
    frame.HorizontalBottomEdge:ClearTextureSlice()
    frame.HorizontalBottomEdge:SetHorizTile(true)
    frame.HorizontalBottomEdge:SetVertTile(false)

    frame.HorizontalTopEdge:SetVertexColor(r, g, b, a)
    frame.HorizontalBottomEdge:SetVertexColor(r, g, b, a)
    frame.HorizontalTopEdge:Show()
    frame.HorizontalBottomEdge:Show()

    frame:Show()
end

local function UpdateBorderForFrame(target_frame, border_state, border_scale, border_name, nine_slice_name)
    border_state = border_state or {}
    border_scale = border_scale or 1

    local border_texture = RPGBB.db:Get("frame", "border", "texture")
    local border_r, border_g, border_b, border_a = RPGBB.db:GetColor("frame", "border", "color")
    local border_size = RPGBB.db:Get("frame", "border", "size") * border_scale
    local border_offset = RPGBB.db:Get("frame", "border", "offset") * border_scale
    local nine_slice_style = RPGBB:GetNineSliceBorderStyle(border_texture)

    -- Fall back cleanly if a profile references a style no longer in the
    -- curated list.
    if not nine_slice_style and type(border_texture) == "string"
        and border_texture:match("^nineslice:") then
        border_texture = RPGBB.db:GetDefault("frame", "border", "texture")
    end

    if not border_state.border then
        border_state.border = CreateFrame("Frame", border_name, target_frame, "BackdropTemplate")
    else
        border_state.border:SetParent(target_frame)
    end
    border_state.border:SetFrameLevel(target_frame:GetFrameLevel() + FRAME_BORDER_LEVEL)

    if not border_state.nineSliceBorder then
        border_state.nineSliceBorder = CreateFrame("Frame", nine_slice_name, target_frame)
    else
        border_state.nineSliceBorder:SetParent(target_frame)
    end
    border_state.nineSliceBorder:SetFrameLevel(target_frame:GetFrameLevel() + FRAME_BORDER_LEVEL)

    if nine_slice_style then
        border_state.border:Hide()

        border_state.nineSliceBorder:ClearAllPoints()
        border_state.nineSliceBorder:SetPoint("TOPLEFT", target_frame, "TOPLEFT", -border_offset, border_offset)
        border_state.nineSliceBorder:SetPoint("BOTTOMRIGHT", target_frame, "BOTTOMRIGHT", border_offset, -border_offset)
        ShowModernBorder(
            border_state.nineSliceBorder,
            nine_slice_style,
            border_size,
            border_r,
            border_g,
            border_b,
            border_a
        )
    else
        HideNineSliceBorder(border_state.nineSliceBorder)

        border_state.border:ClearAllPoints()
        border_state.border:SetPoint("TOPLEFT", target_frame, "TOPLEFT", -border_offset, border_offset)
        border_state.border:SetPoint("BOTTOMRIGHT", target_frame, "BOTTOMRIGHT", border_offset, -border_offset)
        border_state.border:SetBackdrop({
            edgeFile = border_texture or nil,
            edgeSize = border_size,
            insets = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
        })
        border_state.border:SetBackdropBorderColor(border_r, border_g, border_b, border_a)
        border_state.border:Show()
    end

    return border_state
end

local function UpdateFrameBorder()
    RPGBB.frameBorderState = UpdateBorderForFrame(
        RPGBB.frame,
        RPGBB.frameBorderState,
        1,
        "RPGBossBarBorder",
        "RPGBossBarNineSliceBorder"
    )

    RPGBB.border = RPGBB.frameBorderState.border
    RPGBB.nineSliceBorder = RPGBB.frameBorderState.nineSliceBorder
end

local function UpdateFrameBackground(frame)
    if not frame.bg then
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    end

    frame.bg:ClearAllPoints()
    frame.bg:SetAllPoints(frame)
    frame.bg:SetColorTexture(RPGBB.db:GetColor("frame", "background_color"))
end

local function MergeDefaults(defaults, overrides)
    local merged = {}

    for key, value in pairs(defaults) do
        merged[key] = value
    end

    for key, value in pairs(overrides) do
        if type(value) == "table" and type(merged[key]) == "table" then
            merged[key] = MergeDefaults(merged[key], value)
        else
            merged[key] = value
        end
    end

    return merged
end

-- db:Get returns the profile's raw table as soon as it stores any subkey, so a
-- profile that only changed an accent's color would lose `selected`, `scale`,
-- etc. Merge the slot over its defaults to always get a complete config.
local function GetAccentConfig(slot)
    local defaults = RPGBB.db:GetDefault("accents", slot)
    local raw = RPGBB.db:GetRaw("accents", slot)

    if type(defaults) ~= "table" then
        return type(raw) == "table" and raw or {}
    end

    if type(raw) ~= "table" then
        return defaults
    end

    return MergeDefaults(defaults, raw)
end

local function GetAccentColor(slot)
    local r, g, b, a = RPGBB.db:GetColor("accents", slot, "color")

    return {
        r = r,
        g = g,
        b = b,
        a = a,
    }
end

local function GetVerticalLayoutEnabled()
    return RPGBB.db:Get("frame", "vertical") == true
end

local function GetVerticalOffset()
    local offset = tonumber(RPGBB.db:Get("frame", "vertical_offset")) or 0

    return math.max(0, offset)
end

local function GetVerticalSecondaryScale()
    local scale = tonumber(RPGBB.db:Get("frame", "vertical_secondary_scale")) or 1

    return math.max(0.1, math.min(1, scale))
end

local function GetVerticalSecondaryWidth()
    local width = tonumber(RPGBB.db:Get("frame", "vertical_secondary_width")) or 1

    return math.max(0.1, math.min(1, width))
end

local function GetBossBarScale(index, is_vertical)
    if is_vertical and index > 1 then
        return GetVerticalSecondaryScale()
    end

    return 1
end

local function GetBossBarWidthScale(index, is_vertical)
    if is_vertical and index > 1 then
        return GetVerticalSecondaryWidth()
    end

    return 1
end

local function GetPowerBarFootprint(boss_frame_count, scale)
    local power_bar_enabled = RPGBB.db:Get("power", "enabled")
    local power_bar_hide_above = RPGBB.db:Get("power", "hide_above")

    if not power_bar_enabled or boss_frame_count > power_bar_hide_above then
        return 0
    end

    local power_bar_height = RPGBB.db:Get("power", "height") or 0
    local power_bar_offset_y = RPGBB.db:Get("power", "offset_y") or 0
    local power_border_offset = RPGBB.db:Get("power", "border", "offset") or 0

    return math.max(0, (power_bar_height - power_bar_offset_y + power_border_offset) * scale)
end

local function UpdateMainFrameSize(frame_width, frame_height)
    RPGBB.frame:SetSize(frame_width, frame_height)
end

local function HideVerticalRowFrame(health_bar)
    if not health_bar or not health_bar.row_frame then
        return
    end

    health_bar.row_frame:Hide()
    health_bar.row_frame:ClearAllPoints()
end

local function GetBossRowContainer(health_bar, index, is_vertical, width, height, y_offset, scale)
    if not is_vertical or index == 1 then
        HideVerticalRowFrame(health_bar)

        return RPGBB.frame
    end

    if not health_bar.row_frame then
        health_bar.row_frame = CreateFrame("Frame", nil, RPGBB.frame)
    end

    health_bar.row_frame:SetFrameLevel(RPGBB.frame:GetFrameLevel())
    health_bar.row_frame:ClearAllPoints()
    health_bar.row_frame:SetPoint("TOP", RPGBB.frame, "TOP", 0, -y_offset)
    health_bar.row_frame:SetSize(width, height)
    UpdateFrameBackground(health_bar.row_frame)
    health_bar.rowBorderState = UpdateBorderForFrame(
        health_bar.row_frame,
        health_bar.rowBorderState,
        scale
    )
    health_bar.row_frame:Show()

    return health_bar.row_frame
end


---------------------------------------------------------------------------
--- Main Frame / Container
---------------------------------------------------------------------------

RPGBB.frame = CreateFrame("Frame", "RPGBossBarFrame", UIParent)
RPGBB.frame:SetPoint("TOP", UIParent, "TOP", 0, -80)
RPGBB.frame:SetClampedToScreen(true)
RPGBB.frame:Hide()

local tracked_unit_events = {
    "UNIT_HEALTH",
    "UNIT_MAXHEALTH",
    "UNIT_FLAGS",
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER",
}
local registered_target_tracking

local function UpdateTrackingEvents()
    local track_target = RPGBB:IsTrackingTarget()
    if registered_target_tracking == track_target then
        return
    end

    for _, event in ipairs(tracked_unit_events) do
        RPGBB.frame:UnregisterEvent(event)
        if track_target then
            RPGBB.frame:RegisterUnitEvent(event, "target", "softenemy")
        else
            RPGBB.frame:RegisterUnitEvent(event, "boss1", "boss2", "boss3", "boss4", "boss5")
        end
    end

    if track_target then
        RPGBB.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        RPGBB.frame:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
        RPGBB.frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "target", "softenemy")
        RPGBB.frame:RegisterUnitEvent("UNIT_FACTION", "player", "target", "softenemy")
        RPGBB.frame:UnregisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    else
        RPGBB.frame:UnregisterEvent("PLAYER_TARGET_CHANGED")
        RPGBB.frame:UnregisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
        RPGBB.frame:UnregisterEvent("UNIT_NAME_UPDATE")
        RPGBB.frame:UnregisterEvent("UNIT_FACTION")
        RPGBB.frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    end

    registered_target_tracking = track_target
end


-------------------------------------------------------------------------------
--- Frame Lifecycle
-------------------------------------------------------------------------------

-- Reuse font objects across updates and fall back to the default game font if
-- the configured file can't be loaded (e.g. an LSM font from a removed addon);
-- a font object with no font errors with "Font not set" on SetText.
local function SetFontSafe(font_object, path, size, outline)
    local ok = pcall(font_object.SetFont, font_object, path, size, outline)

    if not ok or not font_object:GetFont() then
        font_object:SetFont(STANDARD_TEXT_FONT, size, outline)
    end
end

function RPGBB:InitOrUpdateFrame()
    RPGBB:VPrint("InitOrUpdateFrame fired")
    UpdateTrackingEvents()
    RPGBB:UpdateBlizzardBossFrameVisibility()

    local frame_height = RPGBB.db:Get("frame", "height")
    local frame_width  = RPGBB.db:Get("frame", "width")

    RPGBB.frame:ClearAllPoints()
    RPGBB.frame:SetPoint(RPGBB.db:Get("frame", "position", "point"),
                         UIParent,
                         RPGBB.db:Get("frame", "position", "relative_point"),
                         RPGBB.db:Get("frame", "position", "x"),
                         RPGBB.db:Get("frame", "position", "y"))
    UpdateMainFrameSize(frame_width, frame_height)

    -- Create container's background
    UpdateFrameBackground(RPGBB.frame)

    UpdateFrameBorder()


    ---------------------------------------------------------------------------
    --- Accent Groups
    ---------------------------------------------------------------------------

    local left_accent = GetAccentConfig("left")
    local right_accent = GetAccentConfig("right")
    local accent_context = {
        parent = RPGBB.frame,
        anchor = RPGBB.frame,
        frame_height = frame_height,
        frame_level = RPGBB.frame:GetFrameLevel() + GRAPHICS_LEVEL,
    }

    accent_context.side = "left"
    accent_context.config = left_accent
    accent_context.color = GetAccentColor("left")
    accent_context.offset_x = RPGBB.db:Get("accents", "left", "offset", "x")
    accent_context.offset_y = RPGBB.db:Get("accents", "left", "offset", "y")
    RPGBB.leftAccentGroup = RPGBB:RenderAccentSelection(
        left_accent.selected,
        RPGBB.leftAccentGroup,
        accent_context
    )

    accent_context.side = "right"
    accent_context.config = right_accent
    accent_context.color = GetAccentColor("right")
    accent_context.offset_x = RPGBB.db:Get("accents", "right", "offset", "x")
    accent_context.offset_y = RPGBB.db:Get("accents", "right", "offset", "y")
    RPGBB.rightAccentGroup = RPGBB:RenderAccentSelection(
        right_accent.selected,
        RPGBB.rightAccentGroup,
        accent_context
    )


    ---------------------------------------------------------------------------
    --- Font
    ---------------------------------------------------------------------------

    local health_font = RPGBB.db:Get("health", "font", "font")
    local health_font_size = RPGBB.db:Get("health", "font", "size")
    local health_font_outline = RPGBB.db:Get("health", "font", "outline") or ""
    local health_font_r, health_font_g, health_font_b, health_font_a =
        RPGBB.db:GetColor("health", "font", "color")

    RPGBB.health_font = RPGBB.health_font or CreateFont("RPGBossBarHealthFont")
    SetFontSafe(RPGBB.health_font, health_font, health_font_size, health_font_outline)
    RPGBB.health_font:SetTextColor(health_font_r, health_font_g, health_font_b, health_font_a)

    local health_percent_font_outline = RPGBB.db:Get("health", "percent_font", "outline") or ""

    RPGBB.health_percent_font = RPGBB.health_percent_font or CreateFont("RPGBossBarHealthPercentFont")
    SetFontSafe(RPGBB.health_percent_font, health_font, health_font_size, health_percent_font_outline)
    RPGBB.health_percent_font:SetTextColor(health_font_r, health_font_g, health_font_b, health_font_a)


    local name_font = RPGBB.db:Get("name", "font", "font")
    local name_font_size = RPGBB.db:Get("name", "font", "size")
    local name_font_outline = RPGBB.db:Get("name", "font", "outline") or ""

    RPGBB.name_font = RPGBB.name_font or CreateFont("RPGBossBarNameFont")
    SetFontSafe(RPGBB.name_font, name_font, name_font_size, name_font_outline)
    RPGBB.name_font:SetTextColor(RPGBB.db:GetColor("name", "font", "color"))


    local power_font = RPGBB.db:Get("power", "font", "font")
    local power_font_size = RPGBB.db:Get("power", "font", "size")
    local power_font_outline = RPGBB.db:Get("power", "font", "outline") or ""

    RPGBB.power_font = RPGBB.power_font or CreateFont("RPGBossBarPowerFont")
    SetFontSafe(RPGBB.power_font, power_font, power_font_size, power_font_outline)
    RPGBB.power_font:SetTextColor(RPGBB.db:GetColor("power", "font", "color"))

    --- Update Frames after changing Init Frame settings
    RPGBB:UpdateFrames()
    RPGBB.RefreshGeneralSettings()
end


-------------------------------------------------------------------------------
--- Debug and Test Mode
-------------------------------------------------------------------------------

function RPGBB:Print(msg)
    print("|c" .. addon_color .. ADDON_NAME .. ":|r " .. msg)
end

function RPGBB:VPrint(msg)
    if not verbose then return end

    print("|c" .. addon_color .. "RPGBB" .. ":|r " .. msg)
end

function RPGBB:Lock(locked)
    RPGBB:VPrint("Lock: " .. (locked and "true" or "false"))
    if locked then
        -- Leaving Edit Mode: drop the preview, but keep showing live bosses.
        if testing then
            RPGBB:ToggleTest()
        else
            RPGBB:UpdateFrames()
        end
    else -- unlocked
        RPGBB.frame:Show()

        if not testing then
            RPGBB:ToggleTest(2)
        elseif RPGBB:IsTrackingTarget() then
            RPGBB:UpdateFrames()
        end
    end
end

function RPGBB:ToggleDebug()
    verbose = not verbose
    RPGBB:Print("debug turned " .. (verbose and "on" or "off"))
end

function RPGBB:IsTesting()
    return testing
end

function RPGBB:GetTestFrameCount()
    if RPGBB:IsTrackingTarget() then
        return 1
    end

    return test_frame_count
end

function RPGBB:ToggleTest(frame_count)
    local received_frame_count_arg = ((frame_count and true) or false)
    frame_count = tonumber(frame_count) or 2
    frame_count = math.max(1, math.min(5, math.floor(frame_count))) -- Clamp between 1 and 5

    RPGBB:VPrint("ToggleTest: received_frame_count_arg " .. ((frame_count and "true") or "false"))
    RPGBB:VPrint("ToggleTest: frame_count: " .. frame_count .. " current_boss_frames_count " .. #RPGBB.current_boss_frames)

    -- Toggle test if:
    --   We are not testing: Show
    --   We are testing: if no frame_count passed
    --                   or frame_count is the same as current test: Hide
    if not testing or (not received_frame_count_arg
                        or test_frame_count == frame_count) then
        testing = not testing

        RPGBB:Print("testing turned " .. (testing and "on" or "off"))
    end

    if testing then
        test_frame_count = frame_count
    end

    RPGBB:UpdateFrames()
    RPGBB.RefreshGeneralSettings()
end


-------------------------------------------------------------------------------
--- Boss Frame Updates
-------------------------------------------------------------------------------

function RPGBB:UpdateHealth()
    if IsShowingTestData() then
        return
    end

    for _, boss_frame in ipairs(RPGBB.current_boss_frames) do
        RPGBB:RenderHealthChanges(boss_frame)
    end
end

function RPGBB:UpdatePower()
    if IsShowingTestData() then
        return
    end

    for _, boss_frame in ipairs(RPGBB.current_boss_frames) do
        RPGBB:RenderPowerChanges(boss_frame)
    end
end

function RPGBB:BossFrameHasPower(boss_frame)
    if IsShowingTestData() then
        return true
    end

    if not UnitExists(boss_frame) then
        return false
    end

    local max_power = UnitPowerMax(boss_frame)
    if issecretvalue and issecretvalue(max_power) then
        return true
    end

    return type(max_power) == "number" and max_power > 0
end

-- UnitHealthPercent/UnitPowerPercent and CurveConstants exist on Retail 12.x
-- (where raw values may be secret and can't be used in arithmetic). Older
-- clients such as WoW Forever fall back to computing the percentage directly.
local function GetScaleTo100()
    return CurveConstants and CurveConstants.ScaleTo100
end

local function GetUnitHealthPercent(unit, health, max_health)
    local scale = GetScaleTo100()

    if UnitHealthPercent and scale then
        return UnitHealthPercent(unit, true, scale) or 0
    end

    if type(health) == "number" and type(max_health) == "number" and max_health > 0 then
        return health / max_health * 100
    end

    return 0
end

local function GetUnitPowerPercent(unit)
    local scale = GetScaleTo100()

    if UnitPowerPercent and scale then
        return UnitPowerPercent(unit, nil, false, scale) or 0
    end

    local power = UnitPower(unit)
    local max_power = UnitPowerMax(unit)

    if type(power) == "number" and type(max_power) == "number" and max_power > 0 then
        return power / max_power * 100
    end

    return 0
end

function RPGBB:RenderHealthChanges(boss_frame, abs_health, max_health, per_health)
    local health_bar = RPGBB.health_bars[boss_frame]

    local abs_health = abs_health or UnitHealth(boss_frame)
    local max_health = max_health or UnitHealthMax(boss_frame)
    local per_health = per_health or GetUnitHealthPercent(boss_frame, abs_health, max_health)

    if health_bar and health_bar.frame then
        -- Render frame values
        health_bar.frame:SetMinMaxValues(0, max_health)
        health_bar.frame:SetValue(abs_health)

        -- Render absolute health
        health_bar.health_text:SetText(BreakUpLargeNumbers(abs_health))

        -- Render percent health
        health_bar.percent_text:SetText(string.format("%.1f%%", per_health))

        -- make sure health frame is showing? shouldn't need.
        -- health_bar.frame:Show()
    end
end

function RPGBB:RenderPowerChanges(boss_frame, power_percent)
    local health_bar = RPGBB.health_bars[boss_frame]
    if not health_bar or not health_bar.power_bar then
        return
    end

    local has_power = power_percent ~= nil or RPGBB:BossFrameHasPower(boss_frame)
    health_bar.has_power = has_power

    if not has_power then
        health_bar.power_bar:SetValue(0)
        health_bar.power_bar:Hide()

        if health_bar.power_border then
            health_bar.power_border:Hide()
        end

        if health_bar.power_text then
            health_bar.power_text:SetText("")
            health_bar.power_text:Hide()
        end

        return
    end

    local per_power = power_percent or GetUnitPowerPercent(boss_frame)

    health_bar.power_bar:SetMinMaxValues(0, 100)
    health_bar.power_bar:SetValue(per_power)

    local power_text_format = RPGBB.db:Get("power", "font", "show_percent")
        and "%.0f%%"
        or "%.0f"
    health_bar.power_text:SetText(string.format(power_text_format, per_power))

    local boss_frame_count = #RPGBB.current_boss_frames
    local power_bar_enabled = RPGBB.db:Get("power", "enabled")
    local power_bar_hide_above = RPGBB.db:Get("power", "hide_above")
    local power_text_enabled = RPGBB.db:Get("power", "font", "enabled")
    local power_text_hide_above = RPGBB.db:Get("power", "font", "hide_above")
    local power_border_texture = RPGBB.db:Get("power", "border", "texture")
    local power_border_enabled = type(power_border_texture) == "string" and power_border_texture ~= ""
    local show_power_bar = power_bar_enabled and boss_frame_count <= power_bar_hide_above

    health_bar.power_bar:SetShown(show_power_bar)

    if health_bar.power_border then
        health_bar.power_border:SetShown(show_power_bar and power_border_enabled)
    end

    if health_bar.power_text then
        health_bar.power_text:SetShown(
            show_power_bar and power_text_enabled and boss_frame_count <= power_text_hide_above
        )
    end
end

function RPGBB:HaveBossFramesChanged(new_frames)
    local current = RPGBB.current_boss_frames

    if #current ~= #new_frames then
        return true
    end

    for i, frame in ipairs(new_frames) do
        if current[i] ~= frame then
            return true
        end
    end

    return false
end

-- Returns:
--   true if we have any boss frames we should be tracking and BossBar should be visible
--  false if we are not tracking boss frames and BossBar should be hidden
function RPGBB:IsBossFramesToUpdate()
    local boss_frames = GetTrackedUnits()

    -- Only rebuild frames if boss frames have changed
    if RPGBB:HaveBossFramesChanged(boss_frames) then
        RPGBB:UpdateFrames()
    else
        RPGBB.frame:SetShown(#boss_frames > 0)
    end

    return #boss_frames > 0
end

function RPGBB:UpdateFrames()
    RPGBB.current_boss_frames = GetTrackedUnits()
    local show_test_data = IsShowingTestData()

    local frame_height = RPGBB.db:Get("frame", "height")
    local frame_width  = RPGBB.db:Get("frame", "width")

    local boss_frame_count = #RPGBB.current_boss_frames
    local is_vertical = GetVerticalLayoutEnabled()
    local vertical_offset = GetVerticalOffset()

    UpdateMainFrameSize(frame_width, frame_height)

    -- Hide all visible elements for updating
    for _, bf in pairs(RPGBB.health_bars) do
        bf.frame:Hide()
        HideVerticalRowFrame(bf)
        if bf.spark_frame then bf.spark_frame:Hide() end
        if bf.text_frame then bf.text_frame:Hide() end
        if bf.power_bar then bf.power_bar:Hide() end
        if bf.power_border then bf.power_border:Hide() end
        if bf.centerAccentGroup then RPGBB:HideAccentGroup(bf.centerAccentGroup) end
        if bf.leftCenterAccentGroup then RPGBB:HideAccentGroup(bf.leftCenterAccentGroup) end
        if bf.rightCenterAccentGroup then RPGBB:HideAccentGroup(bf.rightCenterAccentGroup) end
    end

    RPGBB.frame:SetShown(boss_frame_count > 0)
    if boss_frame_count == 0 then
        return
    end

    local horizontal_bar_width = frame_width / boss_frame_count
    local vertical_y_offset = 0

    -- Get all db values before looping so we only get them once
    local health_bar_texture_is_atlas = RPGBB.db:Get("health", "texture", "atlas")
    local health_bar_texture          = RPGBB.db:Get("health", "texture", "texture")
    local health_bar_atlas_texture    = RPGBB.db:Get("health", "texture", "atlas_texture")
    local health_bar_desaturated      = RPGBB.db:Get("health", "texture", "desaturated")
    local hb_r, hb_g, hb_b, hb_a      = RPGBB.db:GetColor("health", "texture", "color")

    local health_font_offset_y = RPGBB.db:Get("health", "font", "offset", "y")
    local health_text_enabled  = RPGBB.db:Get("health", "font", "enabled")

    local spark_atlas            = RPGBB.db:Get("health", "spark", "atlas")
    local sp_r, sp_g, sp_b, sp_a = RPGBB.db:GetColor("health", "spark", "color")
    local spark_blend_mode       = RPGBB.db:Get("health", "spark", "blend_mode")
    local spark_width            = RPGBB.db:Get("health", "spark", "width")
    local spark_height_multi     = RPGBB.db:Get("health", "spark", "height_multi")

    local name_y_offset = RPGBB.db:Get("name", "offset", "y")
    local name_text_enabled = RPGBB.db:Get("name", "enabled")

    local health_percent_offset_x = RPGBB.db:Get("health", "percent_font", "offset", "x")
    local disable_per_above       = RPGBB.db:Get("health", "percent_font", "disable_above")
    local health_percent_enabled  = RPGBB.db:Get("health", "percent_font", "enabled")

    local power_bar_enabled       = RPGBB.db:Get("power", "enabled")
    local power_bar_percent_width = RPGBB.db:Get("power", "percent_width")
    local power_bar_height        = RPGBB.db:Get("power", "height")
    local power_bar_offset_y      = RPGBB.db:Get("power", "offset_y")
    local power_bar_texture       = RPGBB.db:Get("power", "texture")
    local power_bar_hide_above    = RPGBB.db:Get("power", "hide_above")
    local power_text_hide_above   = RPGBB.db:Get("power", "font", "hide_above")
    local power_text_enabled      = RPGBB.db:Get("power", "font", "enabled")
    local power_r, power_g, power_b, power_a = RPGBB.db:GetColor("power", "color")

    local power_border_texture = RPGBB.db:Get("power", "border", "texture")
    local power_border_enabled = type(power_border_texture) == "string" and power_border_texture ~= ""
    local power_border_size    = RPGBB.db:Get("power", "border", "size")
    local power_border_offset  = RPGBB.db:Get("power", "border", "offset")
    local power_border_r, power_border_g, power_border_b, power_border_a =
        RPGBB.db:GetColor("power", "border", "color")

    local power_text_point          = RPGBB.db:Get("power", "font", "position", "point")
    local power_text_relative_point =
        RPGBB.db:Get("power", "font", "position", "relative_point")
    local power_text_x              = RPGBB.db:Get("power", "font", "position", "x")
    local power_text_y              = RPGBB.db:Get("power", "font", "position", "y")

    local center_accent = GetAccentConfig("center")
    local center_accent_color = GetAccentColor("center")
    local center_accent_offset_x = RPGBB.db:Get("accents", "center", "offset", "x")
    local center_accent_offset_y = RPGBB.db:Get("accents", "center", "offset", "y")

    for i, boss_frame in ipairs(RPGBB.current_boss_frames) do
        RPGBB:VPrint("RPGBB: " .. boss_frame .. " i: " .. i)

        RPGBB.health_bars[boss_frame] = RPGBB.health_bars[boss_frame] or {}

        local bar_scale = GetBossBarScale(i, is_vertical)
        local bar_width_scale = GetBossBarWidthScale(i, is_vertical)
        local bar_width = is_vertical and (frame_width * bar_scale * bar_width_scale) or horizontal_bar_width
        local bar_height = frame_height * bar_scale
        local x_left_offset = horizontal_bar_width * (i - 1)
        local row_container = GetBossRowContainer(
            RPGBB.health_bars[boss_frame],
            i,
            is_vertical,
            bar_width,
            bar_height,
            vertical_y_offset,
            bar_scale
        )

        -- Healthbar Frame
        if not RPGBB.health_bars[boss_frame].frame then
            RPGBB:VPrint(boss_frame .. " did not exist, creating.")
            RPGBB.health_bars[boss_frame].frame = CreateFrame("StatusBar", "RPG".. boss_frame .."BarHealthBar", row_container)
        else
            RPGBB:VPrint(boss_frame .. " Already Existed.")
            RPGBB.health_bars[boss_frame].frame:SetParent(row_container)
        end
        RPGBB.health_bars[boss_frame].frame:SetFrameLevel(row_container:GetFrameLevel() + HEALTH_BAR_LEVEL)
        -- Update each time for setting changes
        if health_bar_texture_is_atlas then
            RPGBB.health_bars[boss_frame].frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            RPGBB.health_bars[boss_frame].frame:GetStatusBarTexture():SetAtlas(health_bar_atlas_texture)
        else
            RPGBB.health_bars[boss_frame].frame:SetStatusBarTexture(health_bar_texture)
        end
        RPGBB.health_bars[boss_frame].frame:GetStatusBarTexture():SetDesaturated(health_bar_desaturated)
        RPGBB.health_bars[boss_frame].frame:SetStatusBarColor(hb_r, hb_g, hb_b, hb_a)
        -- Update each time for frame count changes
        RPGBB.health_bars[boss_frame].frame:ClearAllPoints()
        if is_vertical then
            RPGBB.health_bars[boss_frame].frame:SetAllPoints(row_container)
        else
            RPGBB.health_bars[boss_frame].frame:SetPoint("LEFT", row_container, "LEFT", x_left_offset, 0)
            RPGBB.health_bars[boss_frame].frame:SetSize(bar_width, bar_height)
        end
        RPGBB.health_bars[boss_frame].frame:Show()

        -- Healthbar Spark
        if not RPGBB.health_bars[boss_frame].spark_frame then
            RPGBB.health_bars[boss_frame].spark_frame = CreateFrame("Frame", nil, row_container)
        else
            RPGBB.health_bars[boss_frame].spark_frame:SetParent(row_container)
        end
        RPGBB.health_bars[boss_frame].spark_frame:SetFrameLevel(row_container:GetFrameLevel() + SPARK_LEVEL)
        RPGBB.health_bars[boss_frame].spark_frame:ClearAllPoints()
        RPGBB.health_bars[boss_frame].spark_frame:SetAllPoints(RPGBB.health_bars[boss_frame].frame)
        RPGBB.health_bars[boss_frame].spark_frame:Show()

        if not RPGBB.health_bars[boss_frame].spark then
            RPGBB.health_bars[boss_frame].spark = RPGBB.health_bars[boss_frame].spark_frame:CreateTexture(nil, "OVERLAY")
            RPGBB.health_bars[boss_frame].spark:SetPoint("CENTER", RPGBB.health_bars[boss_frame].frame:GetStatusBarTexture(), "RIGHT", 0, 0)
        end
        -- Update each time for setting changes
        RPGBB.health_bars[boss_frame].spark:SetAtlas(spark_atlas)
        RPGBB.health_bars[boss_frame].spark:SetVertexColor(sp_r, sp_g, sp_b, sp_a)
        RPGBB.health_bars[boss_frame].spark:SetBlendMode(spark_blend_mode)
        RPGBB.health_bars[boss_frame].spark:SetSize(spark_width * bar_scale, bar_height * spark_height_multi)

        -- Boss text renders above the frame border.
        if not RPGBB.health_bars[boss_frame].text_frame then
            RPGBB.health_bars[boss_frame].text_frame = CreateFrame("Frame", nil, row_container)
        else
            RPGBB.health_bars[boss_frame].text_frame:SetParent(row_container)
        end
        RPGBB.health_bars[boss_frame].text_frame:SetFrameLevel(row_container:GetFrameLevel() + TEXT_LEVEL)
        RPGBB.health_bars[boss_frame].text_frame:ClearAllPoints()
        RPGBB.health_bars[boss_frame].text_frame:SetAllPoints(row_container)
        RPGBB.health_bars[boss_frame].text_frame:Show()

        -- Healthbar absolute value health text
        if not RPGBB.health_bars[boss_frame].health_text then
            RPGBB.health_bars[boss_frame].health_text = RPGBB.health_bars[boss_frame].text_frame:CreateFontString(nil, "OVERLAY")
        end
        -- Update each time for setting changes
        RPGBB.health_bars[boss_frame].health_text:ClearAllPoints()
        RPGBB.health_bars[boss_frame].health_text:SetPoint(
            "CENTER",
            RPGBB.health_bars[boss_frame].frame,
            "CENTER",
            0,
            health_font_offset_y * bar_scale
        )
        RPGBB.health_bars[boss_frame].health_text:SetFontObject(RPGBB.health_font)
        RPGBB.health_bars[boss_frame].health_text:SetScale(bar_scale)
        RPGBB.health_bars[boss_frame].health_text:SetShown(health_text_enabled)

        -- Healthbar percentage text (right side of bar)
        if not RPGBB.health_bars[boss_frame].percent_text then
            RPGBB.health_bars[boss_frame].percent_text = RPGBB.health_bars[boss_frame].text_frame:CreateFontString(nil, "OVERLAY")
        end
        RPGBB.health_bars[boss_frame].percent_text:ClearAllPoints()
        RPGBB.health_bars[boss_frame].percent_text:SetPoint(
            "RIGHT",
            RPGBB.health_bars[boss_frame].frame,
            "RIGHT",
            health_percent_offset_x * bar_scale,
            health_font_offset_y * bar_scale
        )
        RPGBB.health_bars[boss_frame].percent_text:SetFontObject(RPGBB.health_percent_font)
        RPGBB.health_bars[boss_frame].percent_text:SetScale(bar_scale)

        -- Healthbar name text (above frame)
        if not RPGBB.health_bars[boss_frame].name_text then
            RPGBB.health_bars[boss_frame].name_text = RPGBB.health_bars[boss_frame].text_frame:CreateFontString(nil, "OVERLAY")
            RPGBB.health_bars[boss_frame].name_text:SetWordWrap(false)
        end
        RPGBB.health_bars[boss_frame].name_text:ClearAllPoints()
        RPGBB.health_bars[boss_frame].name_text:SetPoint("BOTTOM", RPGBB.health_bars[boss_frame].frame, "TOP", 0, name_y_offset * bar_scale)
        RPGBB.health_bars[boss_frame].name_text:SetFontObject(RPGBB.name_font)
        RPGBB.health_bars[boss_frame].name_text:SetScale(bar_scale)
        RPGBB.health_bars[boss_frame].name_text:SetWidth(bar_width / bar_scale)
        if show_test_data then
            local preview_name = boss_frame == "target" and "Test Target" or "Test Boss " .. i
            RPGBB.health_bars[boss_frame].name_text:SetText(preview_name)
        else
            local unit_name = UnitName(boss_frame)
            RPGBB.health_bars[boss_frame].name_text:SetText(unit_name)
        end
        RPGBB.health_bars[boss_frame].name_text:SetShown(name_text_enabled)

        -- Hide percentage if more than 2 bosses exist
        if not health_percent_enabled or boss_frame_count > disable_per_above then
            RPGBB.health_bars[boss_frame].percent_text:Hide()
        else
            RPGBB.health_bars[boss_frame].percent_text:Show()
        end

        -- Power bar centered beneath its health bar.
        if not RPGBB.health_bars[boss_frame].power_bar then
            local power_bar = CreateFrame(
                "StatusBar",
                "RPG" .. boss_frame .. "BarPowerBar",
                row_container
            )

            local background = power_bar:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints(power_bar)

            local power_text = power_bar:CreateFontString(nil, "OVERLAY")
            power_text:SetPoint("CENTER", power_bar, "CENTER")

            RPGBB.health_bars[boss_frame].power_bar = power_bar
            RPGBB.health_bars[boss_frame].power_background = background
            RPGBB.health_bars[boss_frame].power_text = power_text
        else
            RPGBB.health_bars[boss_frame].power_bar:SetParent(row_container)
        end

        if not RPGBB.health_bars[boss_frame].power_border then
            local power_border = CreateFrame(
                "Frame",
                "RPG" .. boss_frame .. "BarPowerBorder",
                row_container,
                "BackdropTemplate"
            )
            RPGBB.health_bars[boss_frame].power_border = power_border
        else
            RPGBB.health_bars[boss_frame].power_border:SetParent(row_container)
        end

        local power_bar = RPGBB.health_bars[boss_frame].power_bar
        local power_background = RPGBB.health_bars[boss_frame].power_background
        local power_border = RPGBB.health_bars[boss_frame].power_border
        local power_text = RPGBB.health_bars[boss_frame].power_text
        local has_power = RPGBB:BossFrameHasPower(boss_frame)
        RPGBB.health_bars[boss_frame].has_power = has_power

        power_bar:SetFrameLevel(row_container:GetFrameLevel() + POWER_BAR_LEVEL)
        power_border:SetFrameLevel(row_container:GetFrameLevel() + POWER_BORDER_LEVEL)

        power_bar:ClearAllPoints()
        power_bar:SetPoint(
            "TOP",
            RPGBB.health_bars[boss_frame].frame,
            "BOTTOM",
            0,
            power_bar_offset_y * bar_scale
        )
        power_bar:SetSize(bar_width * (power_bar_percent_width / 100), power_bar_height * bar_scale)
        power_bar:SetStatusBarTexture(power_bar_texture)
        power_bar:SetStatusBarColor(power_r, power_g, power_b, power_a)

        power_background:SetTexture(power_bar_texture)
        power_background:SetVertexColor(0.08, 0.08, 0.08, 0.9)

        power_border:ClearAllPoints()
        power_border:SetPoint(
            "TOPLEFT",
            power_bar,
            "TOPLEFT",
            -power_border_offset * bar_scale,
            power_border_offset * bar_scale
        )
        power_border:SetPoint(
            "BOTTOMRIGHT",
            power_bar,
            "BOTTOMRIGHT",
            power_border_offset * bar_scale,
            -power_border_offset * bar_scale
        )
        power_border:SetBackdrop({
            edgeFile = power_border_enabled and power_border_texture or nil,
            edgeSize = power_border_size * bar_scale,
            insets = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
        })
        power_border:SetBackdropBorderColor(
            power_border_r,
            power_border_g,
            power_border_b,
            power_border_a
        )

        power_text:ClearAllPoints()
        power_text:SetPoint(
            power_text_point,
            power_bar,
            power_text_relative_point,
            power_text_x * bar_scale,
            power_text_y * bar_scale
        )
        power_text:SetFontObject(RPGBB.power_font)
        power_text:SetScale(bar_scale)
        power_text:SetShown(has_power and power_text_enabled and boss_frame_count <= power_text_hide_above)

        if power_bar_enabled and has_power and boss_frame_count <= power_bar_hide_above then
            power_bar:Show()
            power_border:SetShown(power_border_enabled)
            RPGBB:RenderPowerChanges(boss_frame, show_test_data and 65 or nil)
        else
            power_bar:SetValue(0)
            power_bar:Hide()
            power_border:Hide()
            power_text:SetText("")
            power_text:Hide()
        end

        if not is_vertical and i < boss_frame_count then
            RPGBB.health_bars[boss_frame].centerAccentGroup = RPGBB:RenderAccentSelection(
                center_accent.selected,
                RPGBB.health_bars[boss_frame].centerAccentGroup,
                {
                    parent = RPGBB.health_bars[boss_frame].frame,
                    anchor = RPGBB.health_bars[boss_frame].frame,
                    side = "center",
                    config = center_accent,
                    offset_x = center_accent_offset_x,
                    offset_y = center_accent_offset_y,
                    frame_height = bar_height,
                    frame_level = RPGBB.health_bars[boss_frame].frame:GetFrameLevel() + GRAPHICS_LEVEL,
                    color = center_accent_color,
                    width_multiplier = 0.7,
                }
            )
        elseif is_vertical and i > 1 then
            RPGBB.health_bars[boss_frame].leftCenterAccentGroup = RPGBB:RenderAccentSelection(
                center_accent.selected,
                RPGBB.health_bars[boss_frame].leftCenterAccentGroup,
                {
                    parent = row_container,
                    anchor = row_container,
                    side = "left",
                    config = center_accent,
                    offset_x = -center_accent_offset_x,
                    offset_y = center_accent_offset_y,
                    frame_height = bar_height,
                    frame_level = row_container:GetFrameLevel() + GRAPHICS_LEVEL,
                    color = center_accent_color,
                    width_multiplier = 0.7,
                }
            )

            RPGBB.health_bars[boss_frame].rightCenterAccentGroup = RPGBB:RenderAccentSelection(
                center_accent.selected,
                RPGBB.health_bars[boss_frame].rightCenterAccentGroup,
                {
                    parent = row_container,
                    anchor = row_container,
                    side = "right",
                    config = center_accent,
                    offset_x = center_accent_offset_x,
                    offset_y = center_accent_offset_y,
                    frame_height = bar_height,
                    frame_level = row_container:GetFrameLevel() + GRAPHICS_LEVEL,
                    color = center_accent_color,
                    width_multiplier = 0.7,
                }
            )
        end

        if is_vertical then
            vertical_y_offset = vertical_y_offset
                + bar_height
                + GetPowerBarFootprint(boss_frame_count, bar_scale)
                + vertical_offset
        end
    end

    if show_test_data then
        for _, boss_frame in ipairs(RPGBB.current_boss_frames) do
            local test_max_health = 214748364
            local test_health = math.random(1, test_max_health)
            local test_percent = (test_health / test_max_health) * 100
            local test_power_percent = math.random(0, 100)

            RPGBB:RenderHealthChanges(boss_frame, test_health, test_max_health, test_percent)
            RPGBB:RenderPowerChanges(boss_frame, test_power_percent)
        end
    else
        RPGBB:UpdateHealth()
    end
end

-------------------------------------------------------------------------------
--- Event Handling
-------------------------------------------------------------------------------

local function EventHandler(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            RPGBB.InitializeDB()
            RPGBB:InitOrUpdateFrame()
            RPGBB.RegisterProfileSettings()

            RPGBB.frame:UnregisterEvent("ADDON_LOADED")

            RPGBB.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
            RPGBB.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

            RPGBB:Print("Loaded. Use " .. SLASH_RPGBOSSBAR1 .. " for commands.")
        end

    elseif event == "PLAYER_SOFT_ENEMY_CHANGED" then
        if not UnitExists("target") then
            RPGBB:UpdateFrames()
        end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD"
        or event == "UNIT_NAME_UPDATE" or event == "UNIT_FACTION" then
        RPGBB:UpdateFrames()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        -- If we are currently tracking a boss frame
        if RPGBB:IsBossFramesToUpdate() then
            -- Update health if this boss is being tracked
            if RPGBB.health_bars[arg1] then
                RPGBB:UpdateHealth()
            end
        end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        if RPGBB:IsBossFramesToUpdate() and not IsShowingTestData() then
            for _, boss_frame in ipairs(RPGBB.current_boss_frames) do
                if boss_frame == arg1 then
                    RPGBB:RenderPowerChanges(boss_frame)
                    break
                end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Recompute visibility from the tracked units instead of hiding:
        -- living bosses, test previews and targets stay shown after combat,
        -- and the bar still hides once no tracked unit remains.
        RPGBB:UpdateFrames()
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" or event == "UNIT_FLAGS" then
        if RPGBB:IsBossFramesToUpdate() then
            RPGBB:UpdateHealth()
            RPGBB:UpdatePower()
        end
    end
end

-- Register events
RPGBB.frame:RegisterEvent("ADDON_LOADED")

RPGBB.frame:SetScript("OnEvent", EventHandler)
