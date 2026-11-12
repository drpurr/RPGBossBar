local ADDON_NAME, RPGTF = ...

local ACCENT_R = 70 / 255
local ACCENT_G = 34 / 255
local ACCENT_B = 106 / 255
local ACCENT_A = 1

local BORDER_OFFSET = 4
local BORDER_SIZE = 32

local function CreateSideAccent(parent)
    local group = CreateFrame("Frame", nil, parent)
    group:SetFrameLevel(parent:GetFrameLevel() + 15)

    group.background = group:CreateTexture(nil, "ARTWORK", nil, 1)
    group.foreground = group:CreateTexture(nil, "ARTWORK", nil, 2)
    group.accent = group:CreateTexture(nil, "ARTWORK", nil, 3)

    group.background:SetAtlas("dragonriding_sgvigor_fillfull")
    group.background:SetDesaturated(true)
    group.foreground:SetAtlas("dragonriding_sgvigor_frame_dark")
    group.accent:SetAtlas("dragonriding_sgvigor_decor_dark")

    return group
end

local function LayoutSide(group, anchor, side, bar_height)
    local is_right_side = side == "right"
    local vigor_frame_height = bar_height * 1.8
    local vigor_frame_width = vigor_frame_height * (44.5 / 62.5)

    local tint_fill_height = vigor_frame_height * (50 / 62.5)
    local tint_fill_width = tint_fill_height * (36 / 50)

    local decor_height = vigor_frame_height * (75.5 / 62.5)
    local decor_width = decor_height * (58.5 / 75.5)

    local decor_frame_overlap_x = vigor_frame_width / 2.25
    local decor_bottom_alignment_y = -(vigor_frame_height * 0.015)

    local frame_anchor_point = is_right_side and "RIGHT" or "LEFT"
    local frame_anchor_offset_x = is_right_side and 2 or -2
    local mirrored = not is_right_side

    group.foreground:ClearAllPoints()
    group.foreground:SetPoint("CENTER", anchor, frame_anchor_point, frame_anchor_offset_x, 0)
    group.foreground:SetSize(vigor_frame_width, vigor_frame_height)

    group.background:ClearAllPoints()
    group.background:SetPoint("CENTER", group.foreground, "CENTER", 0, 0)
    group.background:SetSize(tint_fill_width, tint_fill_height)
    group.background:SetVertexColor(ACCENT_R, ACCENT_G, ACCENT_B, ACCENT_A)

    group.accent:ClearAllPoints()
    group.accent:SetTexCoord(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)

    local decor_anchor_point = is_right_side and "BOTTOMLEFT" or "BOTTOMRIGHT"
    local decor_frame_anchor_point = is_right_side and "BOTTOMRIGHT" or "BOTTOMLEFT"
    local decor_anchor_offset_x = is_right_side and -decor_frame_overlap_x or decor_frame_overlap_x
    group.accent:SetPoint(
        decor_anchor_point,
        group.foreground,
        decor_frame_anchor_point,
        decor_anchor_offset_x,
        decor_bottom_alignment_y
    )
    group.accent:SetSize(decor_width, decor_height)
    group:Show()
end

local function ApplyBorder(border, parent)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", parent, "TOPLEFT", -BORDER_OFFSET, BORDER_OFFSET)
    border:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", BORDER_OFFSET, -BORDER_OFFSET)
    border:SetBackdrop({
        edgeFile = RPGTF.MEDIA.border,
        edgeSize = BORDER_SIZE,
        insets = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0,
        },
    })
    border:SetBackdropBorderColor(1, 1, 1, 1)
    border:Show()
end

function RPGTF:ApplyArt(parent, width, height)
    parent:SetSize(width, height)

    if not parent.rpgtf_art then
        local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        border:SetFrameLevel(parent:GetFrameLevel() + 10)
        parent.rpgtf_art = {
            border = border,
            left = CreateSideAccent(parent),
            right = CreateSideAccent(parent),
        }
    end

    local art = parent.rpgtf_art
    ApplyBorder(art.border, parent)
    LayoutSide(art.left, parent, "left", height)
    LayoutSide(art.right, parent, "right", height)
    return art
end

function RPGTF:ApplyHealthFill(health_bar)
    if health_bar.SetStatusBarAtlas then
        health_bar:SetStatusBarAtlas("Unit_Priest_Insanity_Fill")
    else
        health_bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        local texture = health_bar:GetStatusBarTexture()
        if texture and texture.SetAtlas then
            texture:SetAtlas("Unit_Priest_Insanity_Fill")
        end
    end
    health_bar:SetStatusBarColor(1, 1, 1, 1)
end

function RPGTF:ApplySpark(health_bar, bar_height)
    if not health_bar.spark then
        health_bar.spark = health_bar:CreateTexture(nil, "OVERLAY", nil, 7)
        health_bar.spark:SetAtlas("GarrMission_EncounterBar-Spark")
        health_bar.spark:SetBlendMode("ADD")
        health_bar.spark:SetVertexColor(229 / 255, 167 / 255, 255 / 255, 1)
    end

    local texture = health_bar:GetStatusBarTexture()
    health_bar.spark:ClearAllPoints()
    if texture then
        health_bar.spark:SetPoint("CENTER", texture, "RIGHT", 0, 0)
    else
        health_bar.spark:SetPoint("LEFT", health_bar, "LEFT", 0, 0)
    end
    health_bar.spark:SetSize(10, bar_height * 2.3)
    health_bar.spark:Show()
end
