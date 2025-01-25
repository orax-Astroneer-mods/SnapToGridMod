--[[
# This file is a Lua file.

## Comments
Everything after -- (two hyphens/dashes) is ignored (it's a commentary),
so if you want to turn off any option, just put -- in the beginning of the line.
https://www.codecademy.com/resources/docs/lua/comments
]]

-- ALL TRACE DEBUG INFO WARN ERROR FATAL OFF
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = {
    --[[ Documentation for "Key" and "ModifierKey":
    https://github.com/UE4SS/UE4SS/wiki/Table:-Key
    https://github.com/UE4SS/UE4SS/wiki/Table:-ModifierKey ]]
    snapActorToGrid_Key = Key.F4,
    -- snapActorToGrid_ModifierKey = ModifierKey.CONTROL,

    setActorReferenceLocation_Key = Key.F5,
    -- setActorReferenceLocation_ModifierKey = ModifierKey.ALT,

    rotatePlayerToBlackLine_Key = Key.F4,
    rotatePlayerToBlackLine_ModifierKey = ModifierKey.SHIFT,

    rotatePlayerToOrangeLine_Key = Key.F5,
    rotatePlayerToOrangeLine_ModifierKey = ModifierKey.SHIFT,

    snap_on_drop = false,    -- true | false
    set_new_location = true, -- true | false
    set_new_rotation = true, -- true | false
}

return options
