local ADDON_NAME, RPGTF = ...

function RPGTF.IsPlain(value)
    if issecretvalue and issecretvalue(value) then
        return false
    end
    return value ~= nil
end

-- True for both real values and secret values. Nil is absent.
-- Checks the secret bit first so a secret is never compared with nil.
function RPGTF.IsPresent(value)
    if issecretvalue and issecretvalue(value) then
        return true
    end
    return value ~= nil
end

function RPGTF:Print(msg)
    print("|cff46226aRPG Target Frame|r " .. tostring(msg))
end

RPGTF.MEDIA = {
    border = "Interface\\AddOns\\RPGTargetFrame\\media\\art\\dragonriding_sgvigor_border_dark.tga",
    font = "Interface\\AddOns\\RPGTargetFrame\\media\\fonts\\Metamorphous-Regular.ttf",
}

RPGTF.defaults = {
    frame = {
        point = "CENTER",
        relative_point = "CENTER",
        x = 250,
        y = -180,
        width = 320,
        height = 28,
        scale = 1,
        locked = false,
        hide_blizzard = true,
    },
}

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = CopyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function RPGTF:InitDB()
    if type(RPGTargetFrameDB) ~= "table" then
        RPGTargetFrameDB = CopyTable(self.defaults)
    end

    local db = RPGTargetFrameDB
    for key, value in pairs(self.defaults) do
        if type(value) == "table" then
            if type(db[key]) ~= "table" then
                db[key] = CopyTable(value)
            else
                for child_key, child_value in pairs(value) do
                    if db[key][child_key] == nil then
                        if type(child_value) == "table" then
                            db[key][child_key] = CopyTable(child_value)
                        else
                            db[key][child_key] = child_value
                        end
                    end
                end
            end
        elseif db[key] == nil then
            db[key] = value
        end
    end

    self.db = db
end

function RPGTF:ResetDB()
    RPGTargetFrameDB = CopyTable(self.defaults)
    self.db = RPGTargetFrameDB
end
