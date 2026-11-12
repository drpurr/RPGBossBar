local ADDON_NAME, RPGBB = ...

RPGBB.default_skins = RPGBB.default_skins or {}
RPGBB.default_skin_order = RPGBB.default_skin_order or {}
RPGBB.default_skin_id = RPGBB.default_skin_id or "vigor_dark"

local color_channels = {
    a = true,
    b = true,
    g = true,
    r = true,
}

local db_validation = RPGBB.db_validation or {}
local accent_selection_paths = db_validation.accent_selection_paths or {}
local anchor_points = db_validation.anchor_points or {}
local anchor_point_paths = db_validation.anchor_point_paths or {}
local blend_modes = db_validation.blend_modes or {}
local blend_mode_paths = db_validation.blend_mode_paths or {}
local font_outlines = db_validation.font_outlines or {}
local font_outline_paths = db_validation.font_outline_paths or {}
local string_or_false_paths = db_validation.string_or_false_paths or {}

local function DeepMerge(dest, src)
    for key, value in pairs(src) do
        if type(value) == "table" and type(dest[key]) == "table" then
            DeepMerge(dest[key], value)
        else
            dest[key] = type(value) == "table" and CopyTable(value) or value
        end
    end
end

local function ReplaceTable(dest, src)
    wipe(dest)

    for key, value in pairs(src) do
        dest[key] = type(value) == "table" and CopyTable(value) or value
    end
end

local function PathToString(path)
    return table.concat(path, ".")
end

local function PathWithKey(path, key)
    local new_path = {}

    for index, value in ipairs(path) do
        new_path[index] = value
    end

    new_path[#new_path + 1] = key

    return new_path
end

local function IsDefaultColor(value)
    return type(value) == "table"
        and type(value.a) == "number"
        and type(value.b) == "number"
        and type(value.g) == "number"
        and type(value.r) == "number"
end

local function AddValidationError(errors, path, message)
    local path_string = PathToString(path)

    if path_string == "" then
        errors[#errors + 1] = message
    else
        errors[#errors + 1] = path_string .. " " .. message
    end
end

local function ValidateColor(path, value, errors)
    if type(value) ~= "table" then
        AddValidationError(errors, path, "must be a color table")

        return
    end

    for key in pairs(value) do
        if not color_channels[key] then
            AddValidationError(errors, PathWithKey(path, key), "is not a valid color channel")
        end
    end

    for key in pairs(color_channels) do
        local channel = value[key]
        local channel_path = PathWithKey(path, key)

        if type(channel) ~= "number" then
            AddValidationError(errors, channel_path, "must be a number")
        elseif channel < 0 or channel > 1 then
            AddValidationError(errors, channel_path, "must be between 0 and 1")
        end
    end
end

local function ValidateAccentSelection(path, value, errors)
    local path_string = PathToString(path)
    local slot = accent_selection_paths[path_string]

    if not slot then
        return
    end

    local option = RPGBB:GetAccentOption(value)

    if not option then
        AddValidationError(errors, path, "references an unknown accent")

        return
    end

    if not RPGBB:AccentOptionSupportsSlot(option, slot) then
        AddValidationError(errors, path, "references an accent that does not support this slot")
    end
end

local function ValidateStringValue(path, value, errors)
    local path_string = PathToString(path)

    if anchor_point_paths[path_string] and not anchor_points[value] then
        AddValidationError(errors, path, "must be a valid anchor point")
    elseif blend_mode_paths[path_string] and not blend_modes[value] then
        AddValidationError(errors, path, "must be a valid blend mode")
    elseif font_outline_paths[path_string] and not font_outlines[value] then
        AddValidationError(errors, path, "must be a valid font outline")
    else
        ValidateAccentSelection(path, value, errors)
    end
end

local function ValidateScalar(path, default_value, value, errors)
    local path_string = PathToString(path)

    if string_or_false_paths[path_string] then
        if value == false or type(value) == "string" then
            return
        end

        AddValidationError(errors, path, "must be a string or false")

        return
    end

    if type(value) ~= type(default_value) then
        AddValidationError(errors, path, "must be a " .. type(default_value))

        return
    end

    if type(value) == "string" then
        ValidateStringValue(path, value, errors)
    end
end

local function ValidateTable(path, default_value, value, errors)
    if IsDefaultColor(default_value) then
        ValidateColor(path, value, errors)

        return
    end

    if type(value) ~= "table" then
        AddValidationError(errors, path, "must be a table")

        return
    end

    for key, child_value in pairs(value) do
        local child_path = PathWithKey(path, key)

        if type(key) ~= "string" then
            AddValidationError(errors, path, "has a non-string key")
        elseif default_value[key] == nil then
            AddValidationError(errors, child_path, "is not a known setting")
        elseif type(default_value[key]) == "table" then
            ValidateTable(child_path, default_value[key], child_value, errors)
        else
            ValidateScalar(child_path, default_value[key], child_value, errors)
        end
    end
end

-- Copy only values that pass the same checks as skin overrides. Unknown keys
-- and invalid values are dropped (so defaults apply) instead of failing the
-- whole import, which keeps older exports usable.
local function SanitizeTable(path, default_value, value, dropped)
    local clean = {}

    for key, child_value in pairs(value) do
        local child_path = PathWithKey(path, tostring(key))
        local default_child = nil

        -- Not `and/or`: many defaults are `false`.
        if type(key) == "string" then
            default_child = default_value[key]
        end

        if default_child == nil then
            dropped[#dropped + 1] = PathToString(child_path) .. ": not a known setting"
        elseif type(default_child) == "table" and not IsDefaultColor(default_child) then
            if type(child_value) == "table" then
                clean[key] = SanitizeTable(child_path, default_child, child_value, dropped)
            else
                dropped[#dropped + 1] = PathToString(child_path) .. ": must be a table"
            end
        else
            local errors = {}

            if IsDefaultColor(default_child) then
                ValidateColor(child_path, child_value, errors)
            else
                ValidateScalar(child_path, default_child, child_value, errors)
            end

            if #errors == 0 then
                clean[key] = type(child_value) == "table" and CopyTable(child_value) or child_value
            else
                for _, message in ipairs(errors) do
                    dropped[#dropped + 1] = message
                end
            end
        end
    end

    return clean
end

function RPGBB:SanitizeProfileData(data)
    local dropped = {}

    if type(data) ~= "table" then
        return {}, { "profile data must be a table" }
    end

    return SanitizeTable({}, RPGBB.db_defaults, data, dropped), dropped
end

local function ValidateMergedSkinProfile(profile, errors)
    if profile.health.texture.atlas and type(profile.health.texture.atlas_texture) ~= "string" then
        AddValidationError(errors, { "health", "texture", "atlas_texture" }, "must be a string when atlas textures are enabled")
    end

    if not profile.health.texture.atlas and type(profile.health.texture.texture) ~= "string" then
        AddValidationError(errors, { "health", "texture", "texture" }, "must be a string when atlas textures are disabled")
    end
end

local function ValidateDefaultSkin(skin)
    local errors = {}

    if type(skin) ~= "table" then
        return false, { "skin must be a table" }
    end

    if type(skin.id) ~= "string" or skin.id == "" then
        errors[#errors + 1] = "id must be a non-empty string"
    elseif RPGBB.default_skins[skin.id] then
        errors[#errors + 1] = "id \"" .. skin.id .. "\" is already registered"
    end

    if type(skin.name) ~= "string" or skin.name == "" then
        errors[#errors + 1] = "name must be a non-empty string"
    end

    if type(skin.overrides) ~= "table" then
        errors[#errors + 1] = "overrides must be a table"
    else
        ValidateTable({}, RPGBB.db_defaults, skin.overrides, errors)

        if #errors == 0 then
            local profile = CopyTable(RPGBB.db_defaults)
            DeepMerge(profile, skin.overrides)
            ValidateMergedSkinProfile(profile, errors)
        end
    end

    return #errors == 0, errors
end

local function ReportInvalidSkin(skin, errors)
    local id = "<invalid>"

    if type(skin) == "table" and skin.id then
        id = tostring(skin.id)
    end

    local message = "RPGBossBar skipped profile skin \"" .. id .. "\": " .. table.concat(errors, "; ")

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    elseif type(print) == "function" then
        print(message)
    end
end

function RPGBB:RegisterDefaultSkin(skin)
    local valid, errors = ValidateDefaultSkin(skin)

    if not valid then
        ReportInvalidSkin(skin, errors)

        return false
    end

    RPGBB.default_skin_order[#RPGBB.default_skin_order + 1] = skin.id
    RPGBB.default_skins[skin.id] = skin

    return true
end

function RPGBB:GetDefaultSkin(id)
    return RPGBB.default_skins[id]
end

function RPGBB:GetDefaultSkinList()
    local skins = {}

    for _, id in ipairs(RPGBB.default_skin_order) do
        local skin = RPGBB.default_skins[id]
        if skin then
            skins[#skins + 1] = skin
        end
    end

    return skins
end

function RPGBB:GetFirstDefaultSkinID()
    for _, id in ipairs(RPGBB.default_skin_order) do
        if RPGBB.default_skins[id] then
            return id
        end
    end
end

function RPGBB:GetDefaultProfileSkinID()
    if RPGBB:GetDefaultSkin(RPGBB.default_skin_id) then
        return RPGBB.default_skin_id
    end

    return RPGBB:GetFirstDefaultSkinID()
end

local function GetProfileSkinMetadata(profileName)
    if not RPGBossBarProfiles or not RPGBossBarProfiles.profileMeta then
        return
    end

    local profileMeta = RPGBossBarProfiles.profileMeta[profileName]

    return profileMeta and profileMeta.defaultSkin
end

function RPGBB:GetProfileDefaultSkinID(profileName)
    local skinID = GetProfileSkinMetadata(profileName)

    if skinID and RPGBB:GetDefaultSkin(skinID) then
        return skinID
    end

    return RPGBB:GetDefaultProfileSkinID()
end

function RPGBB:GetActiveProfileDefaultSkinID()
    return RPGBB:GetProfileDefaultSkinID(RPGBB.GetActiveProfileKey())
end

function RPGBB:BuildProfileFromDefaultSkin(skinID)
    local profile = CopyTable(RPGBB.db_defaults)
    local skin = RPGBB:GetDefaultSkin(skinID or RPGBB:GetDefaultProfileSkinID())

    if skin then
        DeepMerge(profile, skin.overrides)
    end

    return profile
end

function RPGBB:ApplyDefaultSkinToProfile(profileName, skinID)
    local profile = RPGBossBarProfiles.profiles[profileName]
    local skin = RPGBB:GetDefaultSkin(skinID)

    if not profile or not skin then
        return false
    end

    DeepMerge(profile, skin.overrides)

    RPGBossBarProfiles.profileMeta = RPGBossBarProfiles.profileMeta or {}
    RPGBossBarProfiles.profileMeta[profileName] = RPGBossBarProfiles.profileMeta[profileName] or {}
    RPGBossBarProfiles.profileMeta[profileName].defaultSkin = skinID

    return true
end

function RPGBB:CreateProfileFromDefaultSkin(skinID, profileName)
    if not profileName or profileName == "" then
        return false
    end

    if RPGBossBarProfiles.profiles[profileName] then
        return false
    end

    local skin = RPGBB:GetDefaultSkin(skinID)
    if not skin then
        return false
    end

    RPGBossBarProfiles.profiles[profileName] = RPGBB:BuildProfileFromDefaultSkin(skinID)

    RPGBossBarProfiles.profileMeta = RPGBossBarProfiles.profileMeta or {}
    RPGBossBarProfiles.profileMeta[profileName] = {
        defaultSkin = skinID,
    }

    return true
end

function RPGBB:ResetProfileToDefaults(profileName)
    local profile = RPGBossBarProfiles.profiles[profileName]
    if not profile then
        return false
    end

    local skinID = RPGBB:GetProfileDefaultSkinID(profileName)
    local resetProfile = RPGBB:BuildProfileFromDefaultSkin(skinID)

    ReplaceTable(profile, resetProfile)

    if profileName == RPGBB.GetActiveProfileKey() then
        RPGBB.db:SetData(profile)
    end

    return true
end

function RPGBB:ResetProfileToDefaultSkin(profileName, skinID)
    local profile = RPGBossBarProfiles.profiles[profileName]
    local skin = RPGBB:GetDefaultSkin(skinID)

    if not profile or not skin then
        return false
    end

    ReplaceTable(profile, RPGBB:BuildProfileFromDefaultSkin(skinID))

    RPGBossBarProfiles.profileMeta = RPGBossBarProfiles.profileMeta or {}
    RPGBossBarProfiles.profileMeta[profileName] = RPGBossBarProfiles.profileMeta[profileName] or {}
    RPGBossBarProfiles.profileMeta[profileName].defaultSkin = skinID

    if profileName == RPGBB.GetActiveProfileKey() then
        RPGBB.db:SetData(profile)
    end

    return true
end

function RPGBB:ResetActiveProfile()
    return RPGBB:ResetProfileToDefaults(RPGBB.GetActiveProfileKey())
end
