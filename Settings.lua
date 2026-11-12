local ADDON_NAME, RPGBB = ...

-------------------------------------------------------------------------------
--- Initiailze
-------------------------------------------------------------------------------
-- local RPGBBSettings = CreateFrame('frame')
local LibSharedMedia = LibStub('LibSharedMedia-3.0')

local LEM = LibStub('LibEditMode-RPGBossBar-1.0')

local defaults = RPGBB.db_defaults

local function DefaultColor(...)
    local color = defaults
    for i = 1, select("#", ...) do
        color = color[select(i, ...)]
    end

    return CreateColor(color.r, color.g, color.b, color.a)
end

local font_outline_options = {
    {
        name = "None",
        value = "",
    },
    {
        name = "Outline",
        value = "OUTLINE",
    },
    {
        name = "Thick Outline",
        value = "THICKOUTLINE",
    },
    {
        name = "Slug",
        value = "OUTLINESLUG",
    },
    {
        name = "Monochrome",
        value = "MONOCHROMEOUTLINE",
    },
    {
        name = "Monochrome Thick",
        value = "MONOCHROMETHICKOUTLINE",
    },
}

local function CreateFontOutlineSetting(label, defaultValue, get, setSelected, setDefault)
    return {
        name = label or "Outline",
        kind = LEM.SettingType.Dropdown,
        default = defaultValue,
        set = setDefault,
        generator = function(owner, rootDescription)
            for _, option in ipairs(font_outline_options) do
                rootDescription:CreateCheckbox(option.name, get, setSelected, option.value)
            end
        end,
    }
end

-------------------------------------------------------------------------------
--- Listeners
-------------------------------------------------------------------------------

local function OnPositionChanged(frame, layoutName, point, x, y)
    local point, _, relative_point, x, y = frame:GetPoint()
    local uiScale = UIParent:GetScale()

    x = PixelUtil.GetNearestPixelSize(x, uiScale)
    y = PixelUtil.GetNearestPixelSize(y, uiScale)

    RPGBB.db:Set("frame", "position", "point", point)
    RPGBB.db:Set("frame", "position", "relative_point", relative_point)
    RPGBB.db:Set("frame", "position", "x", x)
    RPGBB.db:Set("frame", "position", "y", y)
end


-------------------------------------------------------------------------------
--- Settings Frame
-------------------------------------------------------------------------------
--- Profile selector
local function profile_selector_get(value)
    return RPGBB.GetActiveProfileKey() == value
end

local function profile_selector_set(value)
    RPGBB.SetActiveProfile(value)
    LEM:RefreshFrameSettings(RPGBB.frame)
    RPGBB:InitOrUpdateFrame()
    RPGBB:Print("Switched to profile: " .. value)
end

local function profile_selector_default(layoutName, value, fromReset)
    if fromReset then return end
end

profile_selector_setting = {
    name = 'Profile',
    kind = LEM.SettingType.Dropdown,
    default = "Default",
    set = profile_selector_default,
    generator = function(owner, rootDescription)
        for _, name in ipairs(RPGBB.GetProfileList()) do
            rootDescription:CreateCheckbox(name, profile_selector_get, profile_selector_set, name)
        end
    end,
}

--- Reset Current Profile
local function ConfirmResetCurrentProfile()
    StaticPopup_Show("RPGBB_RESET_SETTINGS")
end

local profile_reset_setting = {
    name = 'Reset Current Profile',
    kind = LEM.SettingType.Button,
    text = 'Reset Current Profile',
    click = ConfirmResetCurrentProfile,
    desc = 'Reset the current profile to its selected profile skin.',
}

--- Profile Skin selector
local selected_profile_skin_id
local selected_profile_skin_profile

local function GetActiveProfileSkinID()
    return RPGBB:GetActiveProfileDefaultSkinID()
end

local function SyncSelectedProfileSkin()
    if not RPGBossBarProfiles then
        return
    end

    local active_profile = RPGBB.GetActiveProfileKey()
    if selected_profile_skin_profile == active_profile then
        return
    end

    selected_profile_skin_profile = active_profile
    selected_profile_skin_id = GetActiveProfileSkinID()
end

local function GetSelectedProfileSkinID()
    SyncSelectedProfileSkin()

    if selected_profile_skin_id and RPGBB:GetDefaultSkin(selected_profile_skin_id) then
        return selected_profile_skin_id
    end

    selected_profile_skin_id = RPGBB:GetDefaultProfileSkinID()

    return selected_profile_skin_id
end

local function profile_skin_selector_get(value)
    return GetSelectedProfileSkinID() == value
end

local function profile_skin_selector_set(value)
    selected_profile_skin_profile = RPGBossBarProfiles and RPGBB.GetActiveProfileKey()
    selected_profile_skin_id = value
end

local function profile_skin_selector_default(layoutName, value, fromReset)
    if fromReset then return end
end

local profile_skin_selector_setting = {
    name = 'Skin',
    kind = LEM.SettingType.Dropdown,
    default = RPGBB:GetDefaultProfileSkinID() or "",
    set = profile_skin_selector_default,
    generator = function(owner, rootDescription)
        for _, skin in ipairs(RPGBB:GetDefaultSkinList()) do
            rootDescription:CreateCheckbox(
                skin.name,
                profile_skin_selector_get,
                profile_skin_selector_set,
                skin.id
            )
        end
    end,
}

local function ConfirmApplySelectedProfileSkin()
    local skin_id = GetSelectedProfileSkinID()
    local skin = RPGBB:GetDefaultSkin(skin_id)

    if not skin then
        RPGBB:Print("No profile skin selected.")

        return
    end

    local active_profile = RPGBB.GetActiveProfileKey()
    StaticPopup_Show(
        "RPGBB_APPLY_DEFAULT_SKIN",
        skin.name,
        active_profile,
        {
            skinID = skin_id,
            refreshProfileSettings = false,
        }
    )
end

local profile_skin_apply_setting = {
    name = 'Apply Skin',
    kind = LEM.SettingType.Button,
    text = 'Apply To Current Profile',
    click = ConfirmApplySelectedProfileSkin,
    desc = 'Choose how to apply the selected profile skin to the active profile.',
}

--- Track Target
local function frame_track_target_get()
    return RPGBB:IsTrackingTarget()
end

local function frame_track_target_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "track_target")
    else
        RPGBB.db:Set("frame", "track_target", value)
    end

    RPGBB:InitOrUpdateFrame()
end

local frame_track_target_setting = {
    name = 'Track Target',
    kind = LEM.SettingType.Checkbox,
    default = defaults.frame.track_target,
    get = frame_track_target_get,
    set = frame_track_target_set,
}

--- Test Frames
local function test_frame_count_get()
    return RPGBB:GetTestFrameCount()
end

local function test_frame_count_set(layoutName, value, fromReset)
    local frame_count = 0

    if fromReset then
        frame_count = 2
    else
        frame_count = math.max(1, math.min(5, math.floor(value)))
    end

    -- Start a preview even when the stored count already matches; only skip
    -- when the same count is already being previewed.
    if not RPGBB:IsTesting() or frame_count ~= RPGBB:GetTestFrameCount() then
        RPGBB:ToggleTest(frame_count)
    end
end

test_frame_count_setting = {
    name = 'Test Frames',
    kind = LEM.SettingType.Slider,
    default = 2,
    get = test_frame_count_get,
    set = test_frame_count_set,
    minValue = 1,
    maxValue = 5,
    valueStep = 1,
    formatter = function(value) return value end,
    disabled = frame_track_target_get,
}

--- Maximum Frames
local function frame_max_frames_get()
    return RPGBB:GetMaxBossFrames()
end

local function frame_max_frames_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "max_frames")
    else
        RPGBB.db:Set("frame", "max_frames", math.max(1, math.min(5, math.floor(value))))
    end

    RPGBB:UpdateFrames()
    RPGBB.RefreshGeneralSettings()
end

local frame_max_frames_setting = {
    name = 'Maximum Frames',
    kind = LEM.SettingType.Slider,
    default = defaults.frame.max_frames,
    get = frame_max_frames_get,
    set = frame_max_frames_set,
    minValue = 1,
    maxValue = 5,
    valueStep = 1,
    snapToStep = true,
    formatter = function(value) return value end,
    disabled = frame_track_target_get,
}

RPGBB.sharedSettings = {
    testFrames = test_frame_count_setting,
    trackTarget = frame_track_target_setting,
    maxFrames = frame_max_frames_setting,
}

--- Frame Width
local function frame_width_get()
    return RPGBB.db:Get("frame", "width")
end

local function frame_width_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "width")
    else
        RPGBB.db:Set("frame", "width", value)
    end

    RPGBB:InitOrUpdateFrame()
end

frame_width_setting = {
    name = 'Width',
    kind = LEM.SettingType.Slider,
    default = defaults.frame.width,
    get = frame_width_get,
    set = frame_width_set,
    minValue = 200,
    maxValue = 3000,
    valueStep = 10,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Frame Height
local function frame_height_get()
    return RPGBB.db:Get("frame", "height")
end

local function frame_height_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "height")
    else
        RPGBB.db:Set("frame", "height", value)
    end

    RPGBB:InitOrUpdateFrame()
end

frame_height_setting = {
    name = 'Height',
    kind = LEM.SettingType.Slider,
    default = defaults.frame.height,
    get = frame_height_get,
    set = frame_height_set,
    minValue = 1,
    maxValue = 100,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Frame Background Color
local function frame_background_color_get()
    return CreateColor(RPGBB.db:GetColor("frame", "background_color"))
end

local function frame_background_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "background_color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor("frame", "background_color", { r = r, g = g, b = b, a = a } )
    end

    RPGBB:InitOrUpdateFrame()
end

frame_background_color_setting = {
    name = 'Background Color',
    kind = LEM.SettingType.ColorPicker,
    default = DefaultColor("frame", "background_color"),
    hasOpacity = true,
    get = frame_background_color_get,
    set = frame_background_color_set,
}

-------------------------------------------------------------------------------
--- Frame Vertical Layout
local VERTICAL_LAYOUT_WARNING_KEY = "verticalLayoutWarningShown"

local function ShowVerticalLayoutWarningOnce()
    RPGBossBarProfiles = RPGBossBarProfiles or {}
    RPGBossBarProfiles.accountMeta = RPGBossBarProfiles.accountMeta or {}

    if RPGBossBarProfiles.accountMeta[VERTICAL_LAYOUT_WARNING_KEY] then
        return
    end

    RPGBossBarProfiles.accountMeta[VERTICAL_LAYOUT_WARNING_KEY] = true
    StaticPopup_Show("RPGBB_VERTICAL_LAYOUT_WARNING")
end

local function frame_vertical_get()
    return RPGBB.db:Get("frame", "vertical")
end

local function frame_vertical_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "vertical")
    else
        RPGBB.db:Set("frame", "vertical", value)
        if value then
            ShowVerticalLayoutWarningOnce()
        end
    end

    RPGBB:InitOrUpdateFrame()
end

frame_vertical_setting = {
    name = 'Vertical Bars',
    kind = LEM.SettingType.Checkbox,
    default = defaults.frame.vertical,
    get = frame_vertical_get,
    set = frame_vertical_set,
    desc = 'Stack boss bars vertically instead of dividing the frame horizontally.',
}

local function frame_vertical_setting_disabled()
    return not RPGBB.db:Get("frame", "vertical")
end

-------------------------------------------------------------------------------
--- Frame Vertical Offset
local function frame_vertical_offset_get()
    return RPGBB.db:Get("frame", "vertical_offset")
end

local function frame_vertical_offset_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "vertical_offset")
    else
        RPGBB.db:Set("frame", "vertical_offset", value)
    end

    RPGBB:InitOrUpdateFrame()
end

frame_vertical_offset_setting = {
    name = 'Vertical Offset',
    kind = LEM.SettingType.Slider,
    default = defaults.frame.vertical_offset,
    get = frame_vertical_offset_get,
    set = frame_vertical_offset_set,
    minValue = 0,
    maxValue = 120,
    valueStep = 1,
    formatter = function(value) return value end,
    disabled = frame_vertical_setting_disabled,
}

-------------------------------------------------------------------------------
--- Frame Vertical Secondary Scale
local function frame_vertical_secondary_scale_get()
    return RPGBB.db:Get("frame", "vertical_secondary_scale")
end

local function frame_vertical_secondary_scale_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "vertical_secondary_scale")
    else
        RPGBB.db:Set("frame", "vertical_secondary_scale", value)
    end

    RPGBB:InitOrUpdateFrame()
end

frame_vertical_secondary_scale_setting = {
    name = 'Secondary Scale',
    kind = LEM.SettingType.Slider,
    default = defaults.frame.vertical_secondary_scale,
    get = frame_vertical_secondary_scale_get,
    set = frame_vertical_secondary_scale_set,
    minValue = 0.25,
    maxValue = 1,
    valueStep = 0.05,
    snapToStep = true,
    formatter = function(value) return string.format("%.0f%%", value * 100) end,
    disabled = frame_vertical_setting_disabled,
}

-------------------------------------------------------------------------------
--- Frame Vertical Secondary Width
local function frame_vertical_secondary_width_get()
    return RPGBB.db:Get("frame", "vertical_secondary_width")
end

local function frame_vertical_secondary_width_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "vertical_secondary_width")
    else
        RPGBB.db:Set("frame", "vertical_secondary_width", value)
    end

    RPGBB:InitOrUpdateFrame()
end

frame_vertical_secondary_width_setting = {
    name = 'Secondary Width',
    kind = LEM.SettingType.Slider,
    default = defaults.frame.vertical_secondary_width,
    get = frame_vertical_secondary_width_get,
    set = frame_vertical_secondary_width_set,
    minValue = 0.1,
    maxValue = 1,
    valueStep = 0.05,
    snapToStep = true,
    formatter = function(value) return string.format("%.0f%%", value * 100) end,
    disabled = frame_vertical_setting_disabled,
}

-------------------------------------------------------------------------------
--- Frame Border Texture
local function frame_border_texture_get(value)
    local nine_slice_style = RPGBB:GetNineSliceBorderStyle(value)
    if nine_slice_style then
        return RPGBB.db:Get("frame", "border", "texture") == value
    end

    local texture = LibSharedMedia:Fetch('border', value)
    local selected_texture = RPGBB.db:Get("frame", "border", "texture")

    if texture then
        return selected_texture == texture
    end

    return selected_texture == false
end

local function frame_border_texture_set(value)
    local nine_slice_style = RPGBB:GetNineSliceBorderStyle(value)
    if nine_slice_style then
        RPGBB.db:Set("frame", "border", "texture", value)
        RPGBB:InitOrUpdateFrame()

        return
    end

    local texture = LibSharedMedia:Fetch('border', value)
    RPGBB.db:Set("frame", "border", "texture", texture or false)
    RPGBB:InitOrUpdateFrame()
end

local function frame_border_texture_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "border", "texture")
        RPGBB:InitOrUpdateFrame()
    end
end

frame_border_texture_setting = {
    name = 'Texture',
    kind = LEM.SettingType.Dropdown,
    default = defaults.frame.border.texture,
    set = frame_border_texture_default,
    generator = function(owner, rootDescription)
        rootDescription:SetScrollMode(400)

        local nine_slice_styles = RPGBB:GetAvailableNineSliceBorderStyles()
        if #nine_slice_styles > 0 then
            rootDescription:CreateTitle('Modern Blizzard Frames')
            for _, style in ipairs(nine_slice_styles) do
                rootDescription:CreateCheckbox(
                    style.name,
                    frame_border_texture_get,
                    frame_border_texture_set,
                    style.value
                )
            end

            rootDescription:CreateSpacer()
        end

        rootDescription:CreateTitle('Backdrop Textures')
        for _, name in ipairs(LibSharedMedia:List('border')) do
            rootDescription:CreateCheckbox(name, frame_border_texture_get, frame_border_texture_set, name)
        end
    end,
}

-------------------------------------------------------------------------------
--- Frame Border Color
local function frame_border_color_get()
    return CreateColor(RPGBB.db:GetColor("frame", "border", "color"))
end

local function frame_border_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "border", "color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor("frame", "border", "color", { r = r, g = g, b = b, a = a })
    end

    RPGBB:InitOrUpdateFrame()
end

frame_border_color_setting = {
    name = 'Color',
    kind = LEM.SettingType.ColorPicker,
    default = DefaultColor("frame", "border", "color"),
    hasOpacity = true,
    get = frame_border_color_get,
    set = frame_border_color_set,
}

-------------------------------------------------------------------------------
--- Frame Border Size
local function frame_border_size_get()
    return RPGBB.db:Get("frame", "border", "size")
end

local function frame_border_size_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "border", "size")
    else
        RPGBB.db:Set("frame", "border", "size", value)
    end

    RPGBB:InitOrUpdateFrame()
end

frame_border_size_setting = {
    name = 'Size',
    kind = LEM.SettingType.Slider,
    default = defaults.frame.border.size,
    get = frame_border_size_get,
    set = frame_border_size_set,
    minValue = 1,
    maxValue = 64,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Frame Border Offset
local function frame_border_offset_get()
    return RPGBB.db:Get("frame", "border", "offset")
end

local function frame_border_offset_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("frame", "border", "offset")
    else
        RPGBB.db:Set("frame", "border", "offset", value)
    end

    RPGBB:InitOrUpdateFrame()
end

frame_border_offset_setting = {
    name = 'Offset',
    kind = LEM.SettingType.Slider,
    default = defaults.frame.border.offset,
    get = frame_border_offset_get,
    set = frame_border_offset_set,
    minValue = 0,
    maxValue = 50,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Frame Center X
local function frame_center_x_get()
    return RPGBB.db:Get("frame", "position", "x") == 0
end

local function frame_center_x_set(layoutName, value, fromReset)
    RPGBB.db:Set("frame", "position", "x", 0)
    RPGBB:InitOrUpdateFrame()
end

frame_center_x_setting = {
    name = 'Center Horizontally',
    kind = LEM.SettingType.Checkbox,
    default = true,
    get = frame_center_x_get,
    set = frame_center_x_set,
}

-------------------------------------------------------------------------------
--- Health Bar Texture
local function health_bar_texture_get(value)
    if RPGBB.atlas_textures[value] then
        return RPGBB.db:Get("health", "texture", "atlas_texture") == RPGBB.atlas_textures[value]
    else
        local texture = LibSharedMedia:Fetch('statusbar', value)
        return RPGBB.db:Get("health", "texture", "texture") == texture
    end
end

local function health_bar_texture_set(value)
    if RPGBB.atlas_textures[value] then
        RPGBB.db:Set("health", "texture", "atlas", true)
        RPGBB.db:SetDefault("health", "texture", "texture")
        RPGBB.db:Set("health", "texture", "atlas_texture", RPGBB.atlas_textures[value])
    else
        local texture = LibSharedMedia:Fetch('statusbar', value)
        RPGBB.db:Set("health", "texture", "atlas", false)
        RPGBB.db:Set("health", "texture", "texture", texture)
        RPGBB.db:Set("health", "texture", "atlas_texture", false)
    end

    RPGBB.UpdateFrames()
end

local function health_bar_texture_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "texture", "atlas")
        RPGBB.db:SetDefault("health", "texture", "atlas_texture")
        RPGBB.db:SetDefault("health", "texture", "texture")

        RPGBB.UpdateFrames()
    end
end

health_bar_texture_setting = {
  name = 'Texture',
  kind = LEM.SettingType.Dropdown,
  default = defaults.health.texture.texture,
  set = health_bar_texture_default,
  generator = function(owner, rootDescription)
    rootDescription:SetScrollMode(400)

    rootDescription:CreateTitle('Atlas Textures')
    for name, texture in pairs(RPGBB.atlas_textures) do
        rootDescription:CreateCheckbox(name, health_bar_texture_get, health_bar_texture_set, name)
    end

    rootDescription:CreateSpacer();

    rootDescription:CreateTitle('Shared Media')
    for _, name in ipairs(LibSharedMedia:List('statusbar')) do
        rootDescription:CreateCheckbox(name, health_bar_texture_get, health_bar_texture_set, name)
    end
  end,
}

-------------------------------------------------------------------------------
--- Health Bar Desaturated
local function health_bar_desaturated_get()
    return RPGBB.db:Get("health", "texture", "desaturated")
end

local function health_bar_desaturated_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "texture", "desaturated")
    else
        RPGBB.db:Set("health", "texture", "desaturated", value)
    end

    RPGBB:UpdateFrames()
end

health_bar_desaturated_setting = {
    name = 'Desaturated',
    kind = LEM.SettingType.Checkbox,
    default = defaults.health.texture.desaturated,
    get = health_bar_desaturated_get,
    set = health_bar_desaturated_set,
}

-------------------------------------------------------------------------------
--- Health Bar Texture Color
local function health_bar_texture_color_get(layoutName)
    return CreateColor(RPGBB.db:GetColor("health", "texture", "color"))
end

local function health_bar_texture_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "texture", "color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor("health", "texture", "color", { r = r, g = g, b = b, a = a } )
    end

    RPGBB.UpdateFrames()
end

health_bar_texture_color_setting = {
  name = 'Color',
  kind = LEM.SettingType.ColorPicker,
  default = DefaultColor("health", "texture", "color"),
  hasOpacity = true,
  get = health_bar_texture_color_get,
  set = health_bar_texture_color_set,
}

-------------------------------------------------------------------------------
--- Health Text Enabled
local function health_text_enabled_get()
    return RPGBB.db:Get("health", "font", "enabled")
end

local function health_text_enabled_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "font", "enabled")
    else
        RPGBB.db:Set("health", "font", "enabled", value)
    end

    RPGBB:UpdateFrames()
end

health_text_enabled_setting = {
    name = 'Enable Health Text',
    kind = LEM.SettingType.Checkbox,
    default = defaults.health.font.enabled,
    get = health_text_enabled_get,
    set = health_text_enabled_set,
}

-------------------------------------------------------------------------------
--- Health Font Offset Y
local function health_font_offset_y_get()
    return RPGBB.db:Get("health", "font", "offset", "y")
end

local function health_font_offset_y_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "font", "offset", "y")
    else
        RPGBB.db:Set("health", "font", "offset", "y", value)
    end

    RPGBB:UpdateFrames()
end

health_font_offset_y_setting = {
    name = 'Offset Y',
    kind = LEM.SettingType.Slider,
    default = defaults.health.font.offset.y,
    get = health_font_offset_y_get,
    set = health_font_offset_y_set,
    minValue = -100,
    maxValue = 100,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Health Font
local function health_font_get(value)
    local font = LibSharedMedia:Fetch('font', value)
    return RPGBB.db:Get("health", "font", "font") == font
end

local function health_font_set(value)
    local font = LibSharedMedia:Fetch('font', value)
    RPGBB.db:Set("health", "font", "font", font)
    RPGBB:InitOrUpdateFrame()
end

local function health_font_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "font", "font")

        RPGBB:InitOrUpdateFrame()
    end
end

health_font_setting = {
    name = 'Font',
    kind = LEM.SettingType.Dropdown,
    default = defaults.health.font.font,
    set = health_font_default,
    generator = function(owner, rootDescription)
        rootDescription:SetScrollMode(400)

        for _, name in ipairs(LibSharedMedia:List('font')) do
            rootDescription:CreateCheckbox(name, health_font_get, health_font_set, name)
        end
    end,
}

-------------------------------------------------------------------------------
--- Health Font Outline
local function health_font_outline_get(value)
    return RPGBB.db:Get("health", "font", "outline") == value
end

local function health_font_outline_set(value)
    RPGBB.db:Set("health", "font", "outline", value)
    RPGBB:InitOrUpdateFrame()
end

local function health_font_outline_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "font", "outline")
        RPGBB:InitOrUpdateFrame()
    end
end

local health_font_outline_setting = CreateFontOutlineSetting(
    "Outline",
    defaults.health.font.outline,
    health_font_outline_get,
    health_font_outline_set,
    health_font_outline_default
)

-------------------------------------------------------------------------------
--- Health Font Size
local function health_font_size_get(layoutName)
    return RPGBB.db:Get("health", "font", "size")
end

local function health_font_size_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "font", "size")
    else
        RPGBB.db:Set("health", "font", "size", value)
    end

    RPGBB:InitOrUpdateFrame()
end

health_font_size_setting = {
  name = 'Size',
  kind = LEM.SettingType.Slider,
  default = defaults.health.font.size,
  get = health_font_size_get,
  set = health_font_size_set,
  minValue = 6,
  maxValue = 64,
  valueStep = 1,
  formatter = function(value)
    return value
  end,
}

-------------------------------------------------------------------------------
--- Health Font Color
local function health_font_color_get(layoutName)
    return CreateColor(RPGBB.db:GetColor("health", "font", "color"))
end

local function health_font_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "font", "color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor("health", "font", "color", { r = r, g = g, b = b, a = a } )
    end

    RPGBB:InitOrUpdateFrame()
end

health_font_color_setting = {
  name = 'Color',
  kind = LEM.SettingType.ColorPicker,
  default = DefaultColor("health", "font", "color"),
  hasOpacity = true,
  get = health_font_color_get,
  set = health_font_color_set,
}

-------------------------------------------------------------------------------
--- Health Percentage Text Enabled
local function health_percentage_enabled_get()
    return RPGBB.db:Get("health", "percent_font", "enabled")
end

local function health_percentage_enabled_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "percent_font", "enabled")
    else
        RPGBB.db:Set("health", "percent_font", "enabled", value)
    end

    RPGBB:UpdateFrames()
end

health_percentage_enabled_setting = {
    name = 'Enable Health % Text',
    kind = LEM.SettingType.Checkbox,
    default = defaults.health.percent_font.enabled,
    get = health_percentage_enabled_get,
    set = health_percentage_enabled_set,
}

-------------------------------------------------------------------------------
--- Health Bar Percentage Disable At
local function health_percentage_disable_above_get()
    return RPGBB.db:Get("health", "percent_font", "disable_above")
end

local function health_percentage_disable_above_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "percent_font", "disable_above")
    else
        RPGBB.db:Set("health", "percent_font", "disable_above", value)
    end

    RPGBB:UpdateFrames()
end

health_percentage_disable_above_setting = {
    name = 'Hide above # Frames',
    kind = LEM.SettingType.Slider,
    default = defaults.health.percent_font.disable_above,
    get = health_percentage_disable_above_get,
    set = health_percentage_disable_above_set,
    minValue = 1,
    maxValue = 5,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Health Bar Percent Font Offset X
local function health_percentage_font_offset_x_get()
    return RPGBB.db:Get("health", "percent_font", "offset", "x")
end

local function health_percentage_font_offset_x_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "percent_font", "offset", "x")
    else
        RPGBB.db:Set("health", "percent_font", "offset", "x", value)
    end

    RPGBB:UpdateFrames()
end

health_percentage_font_offset_x_setting = {
    name = 'Offset X',
    kind = LEM.SettingType.Slider,
    default = defaults.health.percent_font.offset.x,
    get = health_percentage_font_offset_x_get,
    set = health_percentage_font_offset_x_set,
    minValue = -200,
    maxValue = 200,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Health Percentage Font Outline
local function health_percentage_font_outline_get(value)
    return RPGBB.db:Get("health", "percent_font", "outline") == value
end

local function health_percentage_font_outline_set(value)
    RPGBB.db:Set("health", "percent_font", "outline", value)
    RPGBB:InitOrUpdateFrame()
end

local function health_percentage_font_outline_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "percent_font", "outline")
        RPGBB:InitOrUpdateFrame()
    end
end

local health_percentage_font_outline_setting = CreateFontOutlineSetting(
    "Outline",
    defaults.health.percent_font.outline,
    health_percentage_font_outline_get,
    health_percentage_font_outline_set,
    health_percentage_font_outline_default
)

-------------------------------------------------------------------------------
--- Health Bar Spark Texture
local function health_bar_spark_texture_get(value)
    return RPGBB.db:Get("health", "spark", "atlas") == value
end

local function health_bar_spark_texture_set(value)
    RPGBB.db:Set("health", "spark", "atlas", value)
    RPGBB:UpdateFrames()
end

local function health_bar_spark_texture_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "spark", "atlas")
        RPGBB:UpdateFrames()
    end
end

health_bar_spark_texture_setting = {
    name = 'Texture',
    kind = LEM.SettingType.Dropdown,
    default = defaults.health.spark.atlas,
    set = health_bar_spark_texture_default,
    generator = function(owner, rootDescription)
        rootDescription:SetScrollMode(400)
        for name, texture in pairs(RPGBB.spark_textures) do
            rootDescription:CreateCheckbox(name, health_bar_spark_texture_get, health_bar_spark_texture_set, texture)
        end
    end,
}


-------------------------------------------------------------------------------
--- Health Bar Spark Color
local function health_bar_spark_color_get()
    return CreateColor(RPGBB.db:GetColor("health", "spark", "color"))
end

local function health_bar_spark_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "spark", "color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor("health", "spark", "color", { r = r, g = g, b = b, a = a })
    end

    RPGBB:UpdateFrames()
end

health_bar_spark_color_setting = {
    name = 'Color',
    kind = LEM.SettingType.ColorPicker,
    default = DefaultColor("health", "spark", "color"),
    hasOpacity = true,
    get = health_bar_spark_color_get,
    set = health_bar_spark_color_set,
}

-------------------------------------------------------------------------------
--- Health Bar Spark Blend Mode
local blend_modes = { "DISABLE", "BLEND", "ALPHAKEY", "ADD", "MOD" }

local function health_bar_spark_blend_mode_get(value)
    return RPGBB.db:Get("health", "spark", "blend_mode") == value
end

local function health_bar_spark_blend_mode_set(value)
    RPGBB.db:Set("health", "spark", "blend_mode", value)
    RPGBB:UpdateFrames()
end

local function health_bar_spark_blend_mode_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "spark", "blend_mode")
        RPGBB:UpdateFrames()
    end
end

health_bar_spark_blend_mode_setting = {
    name = 'Blend Mode',
    kind = LEM.SettingType.Dropdown,
    default = defaults.health.spark.blend_mode,
    set = health_bar_spark_blend_mode_default,
    generator = function(owner, rootDescription)
        for _, mode in ipairs(blend_modes) do
            rootDescription:CreateCheckbox(mode, health_bar_spark_blend_mode_get, health_bar_spark_blend_mode_set, mode)
        end
    end,
}

-------------------------------------------------------------------------------
--- Health Bar Spark Width
local function health_bar_spark_width_get()
    return RPGBB.db:Get("health", "spark", "width")
end

local function health_bar_spark_width_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "spark", "width")
    else
        RPGBB.db:Set("health", "spark", "width", value)
    end

    RPGBB:UpdateFrames()
end

health_bar_spark_width_setting = {
    name = 'Width',
    kind = LEM.SettingType.Slider,
    default = defaults.health.spark.width,
    get = health_bar_spark_width_get,
    set = health_bar_spark_width_set,
    minValue = 1,
    maxValue = 40,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Health Bar Spark Height Mulit
local function health_bar_spark_height_multi_get()
    return RPGBB.db:Get("health", "spark", "height_multi")
end

local function health_bar_spark_height_multi_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("health", "spark", "height_multi")
    else
        RPGBB.db:Set("health", "spark", "height_multi", value)
    end

    RPGBB:UpdateFrames()
end

health_bar_spark_height_multi_setting = {
    name = 'Height Multiplier',
    kind = LEM.SettingType.Slider,
    default = defaults.health.spark.height_multi,
    get = health_bar_spark_height_multi_get,
    set = health_bar_spark_height_multi_set,
    minValue = 0.1,
    maxValue = 4,
    valueStep = 0.1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Global Font
local function global_font_get(value)
    local font = LibSharedMedia:Fetch('font', value)

    return RPGBB.db:Get("name", "font", "font") == font
        and RPGBB.db:Get("health", "font", "font") == font
        and RPGBB.db:Get("power", "font", "font") == font
end

local global_font_refresh_pending = false

local function RefreshGlobalFontSettings()
    if global_font_refresh_pending then
        return
    end

    global_font_refresh_pending = true
    C_Timer.After(0, function()
        global_font_refresh_pending = false

        if RPGBB.frame then
            LEM:RefreshFrameSettings(RPGBB.frame)
        end
    end)
end

local function global_font_set(value)
    local font = LibSharedMedia:Fetch('font', value)

    RPGBB.db:Set("name", "font", "font", font)
    RPGBB.db:Set("health", "font", "font", font)
    RPGBB.db:Set("power", "font", "font", font)
    RPGBB:InitOrUpdateFrame()
    RefreshGlobalFontSettings()
end

local function global_font_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("name", "font", "font")
        RPGBB.db:SetDefault("health", "font", "font")
        RPGBB.db:SetDefault("power", "font", "font")
        RPGBB:InitOrUpdateFrame()
        RefreshGlobalFontSettings()
    end
end

global_font_setting = {
    name = 'Font',
    kind = LEM.SettingType.Dropdown,
    default = defaults.name.font.font,
    set = global_font_default,
    generator = function(owner, rootDescription)
        rootDescription:SetScrollMode(400)
        for _, name in ipairs(LibSharedMedia:List('font')) do
            rootDescription:CreateCheckbox(name, global_font_get, global_font_set, name)
        end
    end,
}

-------------------------------------------------------------------------------
--- Global Font Outline
local function global_font_outline_get(value)
    return RPGBB.db:Get("name", "font", "outline") == value
        and RPGBB.db:Get("health", "font", "outline") == value
        and RPGBB.db:Get("health", "percent_font", "outline") == value
        and RPGBB.db:Get("power", "font", "outline") == value
end

local function global_font_outline_set(value)
    RPGBB.db:Set("name", "font", "outline", value)
    RPGBB.db:Set("health", "font", "outline", value)
    RPGBB.db:Set("health", "percent_font", "outline", value)
    RPGBB.db:Set("power", "font", "outline", value)
    RPGBB:InitOrUpdateFrame()
    RefreshGlobalFontSettings()
end

local function global_font_outline_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("name", "font", "outline")
        RPGBB.db:SetDefault("health", "font", "outline")
        RPGBB.db:SetDefault("health", "percent_font", "outline")
        RPGBB.db:SetDefault("power", "font", "outline")
        RPGBB:InitOrUpdateFrame()
        RefreshGlobalFontSettings()
    end
end

local global_font_outline_setting = CreateFontOutlineSetting(
    "Outline",
    defaults.name.font.outline,
    global_font_outline_get,
    global_font_outline_set,
    global_font_outline_default
)

-- -------------------------------------------------------------------------------
-- --- Accent Copy Healthbar Texture Color
-- local function accent_copy_healthbar_texture_color_get()
--     return RPGBB.db:Get("accents", "copy_healthbar_texture_color")
-- end

-- local function accent_copy_healthbar_texture_color_set(layoutName, value, fromReset)
--     if fromReset then
--         RPGBB.db:SetDefault("accents", "copy_healthbar_texture_color")
--     else
--         RPGBB.db:Set("accents", "copy_healthbar_texture_color", value)
--     end

--     RPGBB:InitOrUpdateFrame()
-- end

-- accent_copy_healthbar_texture_color_setting = {
--     name = 'Copy Health Bar Color',
--     kind = LEM.SettingType.Checkbox,
--     default = defaults.accents.copy_healthbar_texture_color,
--     get = accent_copy_healthbar_texture_color_get,
--     set = accent_copy_healthbar_texture_color_set,
-- }

-------------------------------------------------------------------------------
--- Accent Color
local function CreateAccentColorSetting(slot)
    local function get()
        return CreateColor(RPGBB.db:GetColor("accents", slot, "color"))
    end

    local function set(layoutName, value, fromReset)
        if fromReset then
            RPGBB.db:SetDefault("accents", slot, "color")
        else
            local r, g, b, a = value:GetRGBA()
            RPGBB.db:SetColor("accents", slot, "color", { r = r, g = g, b = b, a = a })
        end

        RPGBB:InitOrUpdateFrame()
    end

    return {
        name = 'Color',
        kind = LEM.SettingType.ColorPicker,
        default = DefaultColor("accents", slot, "color"),
        hasOpacity = true,
        get = get,
        set = set,
    }
end

local function RefreshAccentSettings()
    RPGBB:InitOrUpdateFrame()

    if RPGBB.frame then
        LEM:RefreshFrameSettings(RPGBB.frame)
    end
end

local function AccentHasCustomAtlas(slot)
    local custom_atlas = RPGBB.db:Get("accents", slot, "custom_atlas")

    return type(custom_atlas) == "string" and custom_atlas ~= ""
end

local function AccentAdvancedSettingDisabled(slot, capability)
    if AccentHasCustomAtlas(slot) then
        return false
    end

    local selected = RPGBB.db:Get("accents", slot, "selected")
    local option = RPGBB:GetAccentOption(selected)

    return not RPGBB:AccentOptionSupportsAdvanced(option, capability)
end

-------------------------------------------------------------------------------
--- Accent Selection
local function CreateAccentSelectionSetting(slot, name)
    local function get(value)
        return RPGBB.db:Get("accents", slot, "selected") == value
    end

    local function set(value)
        RPGBB.db:Set("accents", slot, "selected", value)
        RefreshAccentSettings()
    end

    local function reset(layoutName, value, fromReset)
        if fromReset then
            RPGBB.db:SetDefault("accents", slot, "selected")
            RefreshAccentSettings()
        end
    end

    return {
        name = name,
        kind = LEM.SettingType.Dropdown,
        default = defaults.accents[slot].selected,
        set = reset,
        generator = function(owner, rootDescription)
            rootDescription:SetScrollMode(400)

            for _, option in ipairs(RPGBB:GetAccentOptionsForSlot(slot)) do
                rootDescription:CreateCheckbox(
                    option.name or option.id,
                    get,
                    set,
                    option.id
                )
            end
        end,
    }
end

local function CreateAccentCustomAtlasSetting(slot)
    local function get()
        return RPGBB.db:Get("accents", slot, "custom_atlas") or ""
    end

    local function set(layoutName, value, fromReset)
        if fromReset then
            RPGBB.db:SetDefault("accents", slot, "custom_atlas")
        else
            RPGBB.db:Set("accents", slot, "custom_atlas", value or "")
        end

        RefreshAccentSettings()
    end

    return {
        name = "Custom Atlas",
        kind = LEM.SettingType.TextInput,
        default = defaults.accents[slot].custom_atlas,
        get = get,
        set = set,
        desc = "Optional atlas name. When set, this overrides the selected accent texture.",
    }
end

local function CreateAccentDesaturatedSetting(slot)
    local function get()
        return RPGBB.db:Get("accents", slot, "desaturated")
    end

    local function set(layoutName, value, fromReset)
        if fromReset then
            RPGBB.db:SetDefault("accents", slot, "desaturated")
        else
            RPGBB.db:Set("accents", slot, "desaturated", value)
        end

        RPGBB:InitOrUpdateFrame()
    end

    return {
        name = "Desaturate",
        kind = LEM.SettingType.Checkbox,
        default = defaults.accents[slot].desaturated,
        get = get,
        set = set,
        disabled = function()
            return not AccentHasCustomAtlas(slot)
        end,
    }
end

local function CreateAccentOffsetSetting(slot, axis, name)
    local function get()
        return RPGBB.db:Get("accents", slot, "offset", axis)
    end

    local function set(layoutName, value, fromReset)
        if fromReset then
            RPGBB.db:SetDefault("accents", slot, "offset", axis)
        else
            RPGBB.db:Set("accents", slot, "offset", axis, value)
        end

        RPGBB:InitOrUpdateFrame()
    end

    return {
        name = name,
        kind = LEM.SettingType.Slider,
        default = defaults.accents[slot].offset[axis],
        get = get,
        set = set,
        minValue = -200,
        maxValue = 200,
        valueStep = 1,
        formatter = function(value) return value end,
    }
end

local function CreateAccentScaleSetting(slot, key, name)
    local function formatScaleValue(value)
        return string.format("%.2f", tonumber(value) or 0)
    end

    local function get()
        return RPGBB.db:Get("accents", slot, key)
    end

    local function set(layoutName, value, fromReset)
        if fromReset then
            RPGBB.db:SetDefault("accents", slot, key)
        else
            RPGBB.db:Set("accents", slot, key, value)
        end

        RPGBB:InitOrUpdateFrame()
    end

    return {
        name = name,
        kind = LEM.SettingType.Slider,
        default = defaults.accents[slot][key],
        get = get,
        set = set,
        minValue = 0.1,
        maxValue = 5,
        valueStep = 0.1,
        snapToStep = true,
        formatter = formatScaleValue,
        editFormatter = formatScaleValue,
        disabled = function()
            return AccentAdvancedSettingDisabled(slot, "scale")
        end,
    }
end

local function CreateAccentRotationSetting(slot)
    local function get()
        return RPGBB.db:Get("accents", slot, "rotation")
    end

    local function set(layoutName, value, fromReset)
        if fromReset then
            RPGBB.db:SetDefault("accents", slot, "rotation")
        else
            RPGBB.db:Set("accents", slot, "rotation", value)
        end

        RPGBB:InitOrUpdateFrame()
    end

    return {
        name = "Rotation",
        kind = LEM.SettingType.Slider,
        default = defaults.accents[slot].rotation,
        get = get,
        set = set,
        minValue = -180,
        maxValue = 180,
        valueStep = 1,
        formatter = function(value) return value end,
        disabled = function()
            return AccentAdvancedSettingDisabled(slot, "rotation")
        end,
    }
end

local function CreateAccentMirrorSetting(slot, key, name)
    local function get()
        return RPGBB.db:Get("accents", slot, key)
    end

    local function set(layoutName, value, fromReset)
        if fromReset then
            RPGBB.db:SetDefault("accents", slot, key)
        else
            RPGBB.db:Set("accents", slot, key, value)
        end

        RPGBB:InitOrUpdateFrame()
    end

    return {
        name = name,
        kind = LEM.SettingType.Checkbox,
        default = defaults.accents[slot][key],
        get = get,
        set = set,
        disabled = function()
            return AccentAdvancedSettingDisabled(slot, "mirror")
        end,
    }
end

accent_left_selection_setting = CreateAccentSelectionSetting("left", "Texture")
accent_left_color_setting = CreateAccentColorSetting("left")
accent_left_offset_x_setting = CreateAccentOffsetSetting("left", "x", "Offset X")
accent_left_offset_y_setting = CreateAccentOffsetSetting("left", "y", "Offset Y")
accent_left_custom_atlas_setting = CreateAccentCustomAtlasSetting("left")
accent_left_desaturated_setting = CreateAccentDesaturatedSetting("left")
accent_left_scale_setting = CreateAccentScaleSetting("left", "scale", "Scale")
accent_left_width_scale_setting = CreateAccentScaleSetting("left", "width_scale", "Width Scale")
accent_left_height_scale_setting = CreateAccentScaleSetting("left", "height_scale", "Height Scale")
accent_left_rotation_setting = CreateAccentRotationSetting("left")
accent_left_mirror_x_setting = CreateAccentMirrorSetting("left", "mirror_x", "Mirror Horizontally")
accent_left_mirror_y_setting = CreateAccentMirrorSetting("left", "mirror_y", "Mirror Vertically")

accent_center_selection_setting = CreateAccentSelectionSetting("center", "Texture")
accent_center_color_setting = CreateAccentColorSetting("center")
accent_center_offset_x_setting = CreateAccentOffsetSetting("center", "x", "Offset X")
accent_center_offset_y_setting = CreateAccentOffsetSetting("center", "y", "Offset Y")
accent_center_custom_atlas_setting = CreateAccentCustomAtlasSetting("center")
accent_center_desaturated_setting = CreateAccentDesaturatedSetting("center")
accent_center_scale_setting = CreateAccentScaleSetting("center", "scale", "Scale")
accent_center_width_scale_setting = CreateAccentScaleSetting("center", "width_scale", "Width Scale")
accent_center_height_scale_setting = CreateAccentScaleSetting("center", "height_scale", "Height Scale")
accent_center_rotation_setting = CreateAccentRotationSetting("center")
accent_center_mirror_x_setting = CreateAccentMirrorSetting("center", "mirror_x", "Mirror Horizontally")
accent_center_mirror_y_setting = CreateAccentMirrorSetting("center", "mirror_y", "Mirror Vertically")

accent_right_selection_setting = CreateAccentSelectionSetting("right", "Texture")
accent_right_color_setting = CreateAccentColorSetting("right")
accent_right_offset_x_setting = CreateAccentOffsetSetting("right", "x", "Offset X")
accent_right_offset_y_setting = CreateAccentOffsetSetting("right", "y", "Offset Y")
accent_right_custom_atlas_setting = CreateAccentCustomAtlasSetting("right")
accent_right_desaturated_setting = CreateAccentDesaturatedSetting("right")
accent_right_scale_setting = CreateAccentScaleSetting("right", "scale", "Scale")
accent_right_width_scale_setting = CreateAccentScaleSetting("right", "width_scale", "Width Scale")
accent_right_height_scale_setting = CreateAccentScaleSetting("right", "height_scale", "Height Scale")
accent_right_rotation_setting = CreateAccentRotationSetting("right")
accent_right_mirror_x_setting = CreateAccentMirrorSetting("right", "mirror_x", "Mirror Horizontally")
accent_right_mirror_y_setting = CreateAccentMirrorSetting("right", "mirror_y", "Mirror Vertically")

-------------------------------------------------------------------------------
--- Boss Name Text Enabled
local function name_text_enabled_get()
    return RPGBB.db:Get("name", "enabled")
end

local function name_text_enabled_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("name", "enabled")
    else
        RPGBB.db:Set("name", "enabled", value)
    end

    RPGBB:UpdateFrames()
end

name_text_enabled_setting = {
    name = 'Enable Boss Name Text',
    kind = LEM.SettingType.Checkbox,
    default = defaults.name.enabled,
    get = name_text_enabled_get,
    set = name_text_enabled_set,
}

-------------------------------------------------------------------------------
--- Name Offset Y
local function name_offset_y_get()
    return RPGBB.db:Get("name", "offset", "y")
end

local function name_offset_y_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("name", "offset", "y")
    else
        RPGBB.db:Set("name", "offset", "y", value)
    end

    RPGBB:UpdateFrames()
end

name_offset_y_setting = {
    name = 'Offset Y',
    kind = LEM.SettingType.Slider,
    default = defaults.name.offset.y,
    get = name_offset_y_get,
    set = name_offset_y_set,
    minValue = -200,
    maxValue = 200,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Name Font
local function name_font_get(value)
    local font = LibSharedMedia:Fetch('font', value)
    return RPGBB.db:Get("name", "font", "font") == font
end

local function name_font_set(value)
    local font = LibSharedMedia:Fetch('font', value)
    RPGBB.db:Set("name", "font", "font", font)
    RPGBB:InitOrUpdateFrame()
end

local function name_font_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("name", "font", "font")
        RPGBB:InitOrUpdateFrame()
    end
end

name_font_setting = {
    name = 'Font',
    kind = LEM.SettingType.Dropdown,
    default = defaults.name.font.font,
    set = name_font_default,
    generator = function(owner, rootDescription)
        rootDescription:SetScrollMode(400)
        for _, name in ipairs(LibSharedMedia:List('font')) do
            rootDescription:CreateCheckbox(name, name_font_get, name_font_set, name)
        end
    end,
}

-------------------------------------------------------------------------------
--- Name Font Outline
local function name_font_outline_get(value)
    return RPGBB.db:Get("name", "font", "outline") == value
end

local function name_font_outline_set(value)
    RPGBB.db:Set("name", "font", "outline", value)
    RPGBB:InitOrUpdateFrame()
end

local function name_font_outline_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("name", "font", "outline")
        RPGBB:InitOrUpdateFrame()
    end
end

local name_font_outline_setting = CreateFontOutlineSetting(
    "Outline",
    defaults.name.font.outline,
    name_font_outline_get,
    name_font_outline_set,
    name_font_outline_default
)

-------------------------------------------------------------------------------
--- Name Font Size
local function name_font_size_get()
    return RPGBB.db:Get("name", "font", "size")
end

local function name_font_size_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("name", "font", "size")
    else
        RPGBB.db:Set("name", "font", "size", value)
    end

    RPGBB:InitOrUpdateFrame()
end

name_font_size_setting = {
    name = 'Size',
    kind = LEM.SettingType.Slider,
    default = defaults.name.font.size,
    get = name_font_size_get,
    set = name_font_size_set,
    minValue = 6,
    maxValue = 48,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Name Font Color
local function name_font_color_get()
    return CreateColor(RPGBB.db:GetColor("name", "font", "color"))
end

local function name_font_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("name", "font", "color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor("name", "font", "color", { r = r, g = g, b = b, a = a })
    end

    RPGBB:InitOrUpdateFrame()
end

name_font_color_setting = {
    name = 'Color',
    kind = LEM.SettingType.ColorPicker,
    default = DefaultColor("name", "font", "color"),
    hasOpacity = true,
    get = name_font_color_get,
    set = name_font_color_set,
}

-------------------------------------------------------------------------------
--- Power Bar Enabled
local function power_bar_enabled_get()
    return RPGBB.db:Get("power", "enabled")
end

local function power_bar_enabled_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "enabled")
    else
        RPGBB.db:Set("power", "enabled", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_enabled_setting = {
    name = 'Enable Power Bar',
    kind = LEM.SettingType.Checkbox,
    default = defaults.power.enabled,
    get = power_bar_enabled_get,
    set = power_bar_enabled_set,
}

-------------------------------------------------------------------------------
--- Power Bar Width
local function power_bar_percent_width_get()
    return RPGBB.db:Get("power", "percent_width")
end

local function power_bar_percent_width_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "percent_width")
    else
        RPGBB.db:Set("power", "percent_width", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_percent_width_setting = {
    name = 'Width (%)',
    kind = LEM.SettingType.Slider,
    default = defaults.power.percent_width,
    get = power_bar_percent_width_get,
    set = power_bar_percent_width_set,
    minValue = 1,
    maxValue = 100,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Height
local function power_bar_height_get()
    return RPGBB.db:Get("power", "height")
end

local function power_bar_height_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "height")
    else
        RPGBB.db:Set("power", "height", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_height_setting = {
    name = 'Height',
    kind = LEM.SettingType.Slider,
    default = defaults.power.height,
    get = power_bar_height_get,
    set = power_bar_height_set,
    minValue = 1,
    maxValue = 100,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Offset Y
local function power_bar_offset_y_get()
    return RPGBB.db:Get("power", "offset_y")
end

local function power_bar_offset_y_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "offset_y")
    else
        RPGBB.db:Set("power", "offset_y", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_offset_y_setting = {
    name = 'Offset Y',
    kind = LEM.SettingType.Slider,
    default = defaults.power.offset_y,
    get = power_bar_offset_y_get,
    set = power_bar_offset_y_set,
    minValue = -100,
    maxValue = 100,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Texture
local function power_bar_texture_get(value)
    local texture = LibSharedMedia:Fetch('statusbar', value)

    return RPGBB.db:Get("power", "texture") == texture
end

local function power_bar_texture_set(value)
    local texture = LibSharedMedia:Fetch('statusbar', value)
    RPGBB.db:Set("power", "texture", texture)
    RPGBB:UpdateFrames()
end

local function power_bar_texture_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "texture")
        RPGBB:UpdateFrames()
    end
end

power_bar_texture_setting = {
    name = 'Texture',
    kind = LEM.SettingType.Dropdown,
    default = defaults.power.texture,
    set = power_bar_texture_default,
    generator = function(owner, rootDescription)
        rootDescription:SetScrollMode(400)

        for _, name in ipairs(LibSharedMedia:List('statusbar')) do
            rootDescription:CreateCheckbox(name, power_bar_texture_get, power_bar_texture_set, name)
        end
    end,
}

-------------------------------------------------------------------------------
--- Power Bar Color
local function power_bar_color_get()
    return CreateColor(RPGBB.db:GetColor("power", "color"))
end

local function power_bar_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor("power", "color", { r = r, g = g, b = b, a = a })
    end

    RPGBB:UpdateFrames()
end

power_bar_color_setting = {
    name = 'Color',
    kind = LEM.SettingType.ColorPicker,
    default = DefaultColor("power", "color"),
    hasOpacity = true,
    get = power_bar_color_get,
    set = power_bar_color_set,
}

-------------------------------------------------------------------------------
--- Power Bar Border Texture
local POWER_BAR_BORDER_NONE = "__none"

local function power_bar_border_texture_get(value)
    local selected_texture = RPGBB.db:Get("power", "border", "texture")

    if value == POWER_BAR_BORDER_NONE then
        return selected_texture == false or selected_texture == ""
    end

    local texture = LibSharedMedia:Fetch('border', value, true)

    return selected_texture == texture
end

local function power_bar_border_texture_set(value)
    if value == POWER_BAR_BORDER_NONE then
        RPGBB.db:Set("power", "border", "texture", false)
        RPGBB:UpdateFrames()

        return
    end

    local texture = LibSharedMedia:Fetch('border', value, true)
    RPGBB.db:Set("power", "border", "texture", texture or false)
    RPGBB:UpdateFrames()
end

local function power_bar_border_texture_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "border", "texture")
        RPGBB:UpdateFrames()
    end
end

power_bar_border_texture_setting = {
    name = 'Texture',
    kind = LEM.SettingType.Dropdown,
    default = defaults.power.border.texture,
    set = power_bar_border_texture_default,
    generator = function(owner, rootDescription)
        rootDescription:SetScrollMode(400)
        rootDescription:CreateCheckbox(
            "None",
            power_bar_border_texture_get,
            power_bar_border_texture_set,
            POWER_BAR_BORDER_NONE
        )

        for _, name in ipairs(LibSharedMedia:List('border')) do
            if name ~= "None" then
                rootDescription:CreateCheckbox(
                    name,
                    power_bar_border_texture_get,
                    power_bar_border_texture_set,
                    name
                )
            end
        end
    end,
}

-------------------------------------------------------------------------------
--- Power Bar Border Color
local function power_bar_border_color_get()
    return CreateColor(RPGBB.db:GetColor("power", "border", "color"))
end

local function power_bar_border_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "border", "color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor(
            "power",
            "border",
            "color",
            { r = r, g = g, b = b, a = a }
        )
    end

    RPGBB:UpdateFrames()
end

power_bar_border_color_setting = {
    name = 'Color',
    kind = LEM.SettingType.ColorPicker,
    default = DefaultColor("power", "border", "color"),
    hasOpacity = true,
    get = power_bar_border_color_get,
    set = power_bar_border_color_set,
}

-------------------------------------------------------------------------------
--- Power Bar Border Size
local function power_bar_border_size_get()
    return RPGBB.db:Get("power", "border", "size")
end

local function power_bar_border_size_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "border", "size")
    else
        RPGBB.db:Set("power", "border", "size", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_border_size_setting = {
    name = 'Size',
    kind = LEM.SettingType.Slider,
    default = defaults.power.border.size,
    get = power_bar_border_size_get,
    set = power_bar_border_size_set,
    minValue = 1,
    maxValue = 32,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Border Offset
local function power_bar_border_offset_get()
    return RPGBB.db:Get("power", "border", "offset")
end

local function power_bar_border_offset_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "border", "offset")
    else
        RPGBB.db:Set("power", "border", "offset", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_border_offset_setting = {
    name = 'Offset',
    kind = LEM.SettingType.Slider,
    default = defaults.power.border.offset,
    get = power_bar_border_offset_get,
    set = power_bar_border_offset_set,
    minValue = 0,
    maxValue = 20,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Frame Limit
local function power_bar_hide_above_get()
    return RPGBB.db:Get("power", "hide_above")
end

local function power_bar_hide_above_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "hide_above")
    else
        RPGBB.db:Set("power", "hide_above", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_hide_above_setting = {
    name = 'Hide above # Frames',
    kind = LEM.SettingType.Slider,
    default = defaults.power.hide_above,
    get = power_bar_hide_above_get,
    set = power_bar_hide_above_set,
    minValue = 1,
    maxValue = 5,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Text Enabled
local function power_bar_text_enabled_get()
    return RPGBB.db:Get("power", "font", "enabled")
end

local function power_bar_text_enabled_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "enabled")
    else
        RPGBB.db:Set("power", "font", "enabled", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_text_enabled_setting = {
    name = 'Enable Power Bar Text',
    kind = LEM.SettingType.Checkbox,
    default = defaults.power.font.enabled,
    get = power_bar_text_enabled_get,
    set = power_bar_text_enabled_set,
}

-------------------------------------------------------------------------------
--- Power Bar Text Percentage Symbol
local function power_bar_text_show_percent_get()
    return RPGBB.db:Get("power", "font", "show_percent")
end

local function power_bar_text_show_percent_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "show_percent")
    else
        RPGBB.db:Set("power", "font", "show_percent", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_text_show_percent_setting = {
    name = 'Show % Symbol',
    kind = LEM.SettingType.Checkbox,
    default = defaults.power.font.show_percent,
    get = power_bar_text_show_percent_get,
    set = power_bar_text_show_percent_set,
}

-------------------------------------------------------------------------------
--- Power Bar Text Frame Limit
local function power_bar_text_hide_above_get()
    return RPGBB.db:Get("power", "font", "hide_above")
end

local function power_bar_text_hide_above_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "hide_above")
    else
        RPGBB.db:Set("power", "font", "hide_above", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_text_hide_above_setting = {
    name = 'Hide above # Frames',
    kind = LEM.SettingType.Slider,
    default = defaults.power.font.hide_above,
    get = power_bar_text_hide_above_get,
    set = power_bar_text_hide_above_set,
    minValue = 1,
    maxValue = 5,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Text Font
local function power_bar_font_get(value)
    local font = LibSharedMedia:Fetch('font', value)
    return RPGBB.db:Get("power", "font", "font") == font
end

local function power_bar_font_set(value)
    local font = LibSharedMedia:Fetch('font', value)
    RPGBB.db:Set("power", "font", "font", font)
    RPGBB:InitOrUpdateFrame()
end

local function power_bar_font_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "font")
        RPGBB:InitOrUpdateFrame()
    end
end

power_bar_font_setting = {
    name = 'Font',
    kind = LEM.SettingType.Dropdown,
    default = defaults.power.font.font,
    set = power_bar_font_default,
    generator = function(owner, rootDescription)
        rootDescription:SetScrollMode(400)
        for _, name in ipairs(LibSharedMedia:List('font')) do
            rootDescription:CreateCheckbox(name, power_bar_font_get, power_bar_font_set, name)
        end
    end,
}

-------------------------------------------------------------------------------
--- Power Bar Text Outline
local function power_bar_font_outline_get(value)
    return RPGBB.db:Get("power", "font", "outline") == value
end

local function power_bar_font_outline_set(value)
    RPGBB.db:Set("power", "font", "outline", value)
    RPGBB:InitOrUpdateFrame()
end

local function power_bar_font_outline_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "outline")
        RPGBB:InitOrUpdateFrame()
    end
end

local power_bar_font_outline_setting = CreateFontOutlineSetting(
    "Outline",
    defaults.power.font.outline,
    power_bar_font_outline_get,
    power_bar_font_outline_set,
    power_bar_font_outline_default
)

-------------------------------------------------------------------------------
--- Power Bar Text Size
local function power_bar_font_size_get()
    return RPGBB.db:Get("power", "font", "size")
end

local function power_bar_font_size_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "size")
    else
        RPGBB.db:Set("power", "font", "size", value)
    end

    RPGBB:InitOrUpdateFrame()
end

power_bar_font_size_setting = {
    name = 'Size',
    kind = LEM.SettingType.Slider,
    default = defaults.power.font.size,
    get = power_bar_font_size_get,
    set = power_bar_font_size_set,
    minValue = 6,
    maxValue = 48,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Text Color
local function power_bar_font_color_get()
    return CreateColor(RPGBB.db:GetColor("power", "font", "color"))
end

local function power_bar_font_color_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "color")
    else
        local r, g, b, a = value:GetRGBA()
        RPGBB.db:SetColor("power", "font", "color", { r = r, g = g, b = b, a = a })
    end

    RPGBB:InitOrUpdateFrame()
end

power_bar_font_color_setting = {
    name = 'Color',
    kind = LEM.SettingType.ColorPicker,
    default = DefaultColor("power", "font", "color"),
    hasOpacity = true,
    get = power_bar_font_color_get,
    set = power_bar_font_color_set,
}

-------------------------------------------------------------------------------
--- Power Bar Text Anchor
local power_text_anchors = {
    {
        name = "Top Left",
        value = "TOPLEFT",
    },
    {
        name = "Top",
        value = "TOP",
    },
    {
        name = "Top Right",
        value = "TOPRIGHT",
    },
    {
        name = "Left",
        value = "LEFT",
    },
    {
        name = "Center",
        value = "CENTER",
    },
    {
        name = "Right",
        value = "RIGHT",
    },
    {
        name = "Bottom Left",
        value = "BOTTOMLEFT",
    },
    {
        name = "Bottom",
        value = "BOTTOM",
    },
    {
        name = "Bottom Right",
        value = "BOTTOMRIGHT",
    },
}

local function power_bar_text_anchor_get(value)
    return RPGBB.db:Get("power", "font", "position", "point") == value
end

local function power_bar_text_anchor_set(value)
    RPGBB.db:Set("power", "font", "position", "point", value)
    RPGBB:UpdateFrames()
end

local function power_bar_text_anchor_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "position", "point")
        RPGBB:UpdateFrames()
    end
end

power_bar_text_anchor_setting = {
    name = 'Anchor to Text',
    kind = LEM.SettingType.Dropdown,
    default = defaults.power.font.position.point,
    set = power_bar_text_anchor_default,
    generator = function(owner, rootDescription)
        for _, anchor in ipairs(power_text_anchors) do
            rootDescription:CreateCheckbox(
                anchor.name,
                power_bar_text_anchor_get,
                power_bar_text_anchor_set,
                anchor.value
            )
        end
    end,
}

-------------------------------------------------------------------------------
--- Power Bar Text Frame Anchor
local function power_bar_text_frame_anchor_get(value)
    return RPGBB.db:Get("power", "font", "position", "relative_point") == value
end

local function power_bar_text_frame_anchor_set(value)
    RPGBB.db:Set("power", "font", "position", "relative_point", value)
    RPGBB:UpdateFrames()
end

local function power_bar_text_frame_anchor_default(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "position", "relative_point")
        RPGBB:UpdateFrames()
    end
end

power_bar_text_frame_anchor_setting = {
    name = 'Anchor to Frame',
    kind = LEM.SettingType.Dropdown,
    default = defaults.power.font.position.relative_point,
    set = power_bar_text_frame_anchor_default,
    generator = function(owner, rootDescription)
        for _, anchor in ipairs(power_text_anchors) do
            rootDescription:CreateCheckbox(
                anchor.name,
                power_bar_text_frame_anchor_get,
                power_bar_text_frame_anchor_set,
                anchor.value
            )
        end
    end,
}

-------------------------------------------------------------------------------
--- Power Bar Text Offset X
local function power_bar_text_offset_x_get()
    return RPGBB.db:Get("power", "font", "position", "x")
end

local function power_bar_text_offset_x_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "position", "x")
    else
        RPGBB.db:Set("power", "font", "position", "x", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_text_offset_x_setting = {
    name = 'Offset X',
    kind = LEM.SettingType.Slider,
    default = defaults.power.font.position.x,
    get = power_bar_text_offset_x_get,
    set = power_bar_text_offset_x_set,
    minValue = -100,
    maxValue = 100,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Power Bar Text Offset Y
local function power_bar_text_offset_y_get()
    return RPGBB.db:Get("power", "font", "position", "y")
end

local function power_bar_text_offset_y_set(layoutName, value, fromReset)
    if fromReset then
        RPGBB.db:SetDefault("power", "font", "position", "y")
    else
        RPGBB.db:Set("power", "font", "position", "y", value)
    end

    RPGBB:UpdateFrames()
end

power_bar_text_offset_y_setting = {
    name = 'Offset Y',
    kind = LEM.SettingType.Slider,
    default = defaults.power.font.position.y,
    get = power_bar_text_offset_y_get,
    set = power_bar_text_offset_y_set,
    minValue = -100,
    maxValue = 100,
    valueStep = 1,
    formatter = function(value) return value end,
}

-------------------------------------------------------------------------------
--- Construct the settings frame

local default_position = CopyTable(defaults.frame.position)

RPGBB.frame.editModeName = 'RPG Boss Bar'
RPGBB.frame.hideDefaultSettingsResetButton = true
LEM:AddFrame(RPGBB.frame, OnPositionChanged, default_position)
LEM:AddFrameSettings(RPGBB.frame, {
    test_frame_count_setting,
    frame_track_target_setting,
    frame_max_frames_setting,
    { name = 'Profile Skin', kind = LEM.SettingType.Divider, collapsed = false, },
    profile_skin_selector_setting,
    profile_skin_apply_setting,
    { name = 'Frame', kind = LEM.SettingType.Divider, collapsed = true, },
    frame_center_x_setting,
    frame_width_setting,
    frame_height_setting,
    frame_background_color_setting,
    frame_vertical_setting,
    frame_vertical_offset_setting,
    frame_vertical_secondary_scale_setting,
    frame_vertical_secondary_width_setting,
    { name = 'Frame Border', kind = LEM.SettingType.Divider, collapsed = true, },
    frame_border_texture_setting,
    frame_border_color_setting,
    frame_border_size_setting,
    frame_border_offset_setting,
    { name = 'Global Font', kind = LEM.SettingType.Divider, collapsed = true, },
    global_font_setting,
    global_font_outline_setting,
    { name = 'Boss Name Text', kind = LEM.SettingType.Divider, collapsed = true, },
    name_text_enabled_setting,
    name_offset_y_setting,
    name_font_setting,
    name_font_outline_setting,
    name_font_size_setting,
    name_font_color_setting,
    { name = 'Health Bar Texture', kind = LEM.SettingType.Divider, collapsed = true, },
    health_bar_desaturated_setting,
    health_bar_texture_setting,
    health_bar_texture_color_setting,
    { name = 'Health Text', kind = LEM.SettingType.Divider, collapsed = true, },
    health_text_enabled_setting,
    health_font_offset_y_setting,
    health_font_setting,
    health_font_outline_setting,
    health_font_size_setting,
    health_font_color_setting,
    { name = 'Health % Text', kind = LEM.SettingType.Divider, collapsed = true, },
    health_percentage_enabled_setting,
    health_percentage_disable_above_setting,
    health_percentage_font_offset_x_setting,
    health_percentage_font_outline_setting,
    { name = 'Health Bar Spark', kind = LEM.SettingType.Divider, collapsed = true, },
    health_bar_spark_width_setting,
    health_bar_spark_height_multi_setting,
    health_bar_spark_texture_setting,
    health_bar_spark_blend_mode_setting,
    health_bar_spark_color_setting,
    { name = 'Power Bar', kind = LEM.SettingType.Divider, collapsed = true, },
    power_bar_enabled_setting,
    power_bar_hide_above_setting,
    power_bar_percent_width_setting,
    power_bar_height_setting,
    power_bar_offset_y_setting,
    { name = 'Power Bar Border', kind = LEM.SettingType.Divider, collapsed = true, },
    power_bar_border_texture_setting,
    power_bar_border_color_setting,
    power_bar_border_size_setting,
    power_bar_border_offset_setting,
    { name = 'Power Bar Texture', kind = LEM.SettingType.Divider, collapsed = true, },
    power_bar_texture_setting,
    power_bar_color_setting,
    { name = 'Power Bar Text', kind = LEM.SettingType.Divider, collapsed = true, },
    power_bar_text_enabled_setting,
    power_bar_text_show_percent_setting,
    power_bar_text_hide_above_setting,
    power_bar_font_setting,
    power_bar_font_outline_setting,
    power_bar_font_size_setting,
    power_bar_font_color_setting,
    power_bar_text_frame_anchor_setting,
    power_bar_text_anchor_setting,
    power_bar_text_offset_x_setting,
    power_bar_text_offset_y_setting,
    { name = 'Left Accent', kind = LEM.SettingType.Divider, collapsed = true, },
    accent_left_selection_setting,
    accent_left_color_setting,
    accent_left_offset_x_setting,
    accent_left_offset_y_setting,
    { name = 'Left Accent Advanced', kind = LEM.SettingType.Divider, collapsed = true, },
    accent_left_custom_atlas_setting,
    accent_left_desaturated_setting,
    accent_left_scale_setting,
    accent_left_width_scale_setting,
    accent_left_height_scale_setting,
    accent_left_rotation_setting,
    accent_left_mirror_x_setting,
    accent_left_mirror_y_setting,
    { name = 'Center Accent', kind = LEM.SettingType.Divider, collapsed = true, },
    accent_center_selection_setting,
    accent_center_color_setting,
    accent_center_offset_x_setting,
    accent_center_offset_y_setting,
    { name = 'Center Accent Advanced', kind = LEM.SettingType.Divider, collapsed = true, },
    accent_center_custom_atlas_setting,
    accent_center_desaturated_setting,
    accent_center_scale_setting,
    accent_center_width_scale_setting,
    accent_center_height_scale_setting,
    accent_center_rotation_setting,
    accent_center_mirror_x_setting,
    accent_center_mirror_y_setting,
    { name = 'Right Accent', kind = LEM.SettingType.Divider, collapsed = true, },
    accent_right_selection_setting,
    accent_right_color_setting,
    accent_right_offset_x_setting,
    accent_right_offset_y_setting,
    { name = 'Right Accent Advanced', kind = LEM.SettingType.Divider, collapsed = true, },
    accent_right_custom_atlas_setting,
    accent_right_desaturated_setting,
    accent_right_scale_setting,
    accent_right_width_scale_setting,
    accent_right_height_scale_setting,
    accent_right_rotation_setting,
    accent_right_mirror_x_setting,
    accent_right_mirror_y_setting,
})

LEM:AddFrameSettingsButtons(RPGBB.frame, {
    profile_selector_setting,
    profile_reset_setting,
    {
        text = "Manage Profiles",
        click = function()
            if RPGBB.settingsCategory then
                Settings.OpenToCategory(RPGBB.settingsCategory:GetID())
            end
        end,
    },
})


-------------------------------------------------------------------------------
--- Hide the Edit Mode selection visuals
-------------------------------------------------------------------------------

-- Keep the selection frame interactive while hiding its tint, border, and label
-- when RPG Boss Bar is selected.
-- LibEditMode keeps the selection frame in LEM.frameSelections; the Blizzard
-- template may or may not also expose it as frame.Selection.
local editModeSelection = RPGBB.frame.Selection
    or (LEM.frameSelections and LEM.frameSelections[RPGBB.frame])

local function SetEditModeSelectionState(alpha, isLabelVisible)
  if not editModeSelection then
    return
  end

  editModeSelection:SetAlpha(alpha)
  if editModeSelection.Label then
    editModeSelection.Label:SetShown(isLabelVisible and true or false)
  end
end

if editModeSelection then
  editModeSelection:HookScript('OnMouseDown', function(self)
    if self.isSelected then
      SetEditModeSelectionState(0, false)
    end
  end)

  editModeSelection:HookScript('OnLeave', function(self)
    if self.isSelected then
      SetEditModeSelectionState(0, false)
    else
      SetEditModeSelectionState(1, false)
    end
  end)
end

if LEM.internal and LEM.internal.dialog then
  LEM.internal.dialog:HookScript('OnHide', function(self)
    if editModeSelection and not editModeSelection.isSelected then
      SetEditModeSelectionState(1, false)
    end
  end)
end

-------------------------------------------------------------------------------
--- Vertical Layout warning dialog
-------------------------------------------------------------------------------

StaticPopupDialogs["RPGBB_VERTICAL_LAYOUT_WARNING"] = {
    text = "Skins are designed primarily for horizontal layouts. Using the vertical layout may require manual adjustments.\n\nUse the Center Accent settings to adjust accents for secondary bars.",
    button1 = "Okay",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-------------------------------------------------------------------------------
--- Reset Current Profile confirmation dialog
-------------------------------------------------------------------------------

StaticPopupDialogs["RPGBB_RESET_SETTINGS"] = {
    text = "Reset the current profile's settings to its defaults?\n\nProfiles reset to their selected profile skin. This cannot be undone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        local dialog = LEM.internal.dialog
        if RPGBB:ResetActiveProfile() then
            RPGBB:InitOrUpdateFrame()
            LEM:RefreshFrameSettings(RPGBB.frame)
            dialog:Update(dialog.selection)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

LEM:RegisterCallback('enter', function()
    RPGBB:Lock(false)
end)

LEM:RegisterCallback('exit', function()
    RPGBB:Lock(true)
end)
