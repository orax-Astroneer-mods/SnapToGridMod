--[[
# This file is a Lua file.
Lua (programming language): https://en.wikipedia.org/wiki/Lua_(programming_language)

## Comments
Everything after -- (two hyphens/dashes) is ignored (it's a commentary),
so if you want to turn off any option, just put -- in the beginning of the line.
https://www.codecademy.com/resources/docs/lua/comments

## Key and ModifierKey tables
https://docs.ue4ss.com/lua-api/table-definitions/key.html
https://docs.ue4ss.com/lua-api/table-definitions/modifierkey.html
--]]

-- ALL TRACE DEBUG INFO WARN ERROR FATAL OFF
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = {
    -- The method (grid or circular) determines how objects will be "snapped".
    method = "grid", -- grid | circular

    -- Should the object automatically snap to the grid when dropped?
    snap_on_drop = false, -- true | false (default)

    -- Keybind to snap and rotate the object to the grid.
    snapActorToGrid_Key = Key.F4,
    snapActorToGrid_ModifierKeys = {},

    -- "set_new_location" changes the behavior when you press the "snapActorToGrid_Key" key (F4 by default).
    -- If "true", the object will be snapped to the grid; the location of the object will be changed.
    set_new_location = true, -- true (default) | false

    -- "set_new_rotation" changes the behavior when you press the "snapActorToGrid_Key" key (F4 by default).
    -- If "true", the rotation of the object will be corrected to be tangent to the planet; the rotation of the object will be changed.
    set_new_rotation = true, -- true (default, recommended) | false

    -- Keybind to select an object to use as a reference for the location.
    -- This object will be in the center of the grid.
    setActorReferenceLocation_Key = Key.F5,
    setActorReferenceLocation_ModifierKeys = {},

    -- Keybinds to rotate the player to the black and orange lines (arc circles).
    -- See the GeoGebra simulation.
    rotatePlayerToBlackLine_Key = Key.F4,
    rotatePlayerToBlackLine_ModifierKeys = { ModifierKey.SHIFT },
    rotatePlayerToOrangeLine_Key = Key.F5,
    rotatePlayerToOrangeLine_ModifierKeys = { ModifierKey.SHIFT },

    -- Keybind to reset the local offset and rotation of the object.
    resetLocalOffsetAndRotation_Key = Key.NUM_ZERO,
    resetLocalOffsetAndRotation_ModifierKeys = {},
}

local move = {
    -- Move the object a number of points on the grid.
    -- Change the arc length if you want a smaller grid.
    -- The arc length can be changed in params.lua or with the "arc" command.
    -- The value must be an integer (minimum: 1).
    -- Value: integer.
    -- Range: >= 1.
    normal = 1,
    big = 5,
    very_big = 20,
}

-- How much to move the object up/down.
-- Value: number (integer or float).
move.up_down_normal = 5
move.up_down_big = move.up_down_normal * 5
move.up_down_very_big = 150

-- Keybind to select the object to move/rotate.
move.selectActor_Key = Key.NUM_FIVE
move.selectActor_ModifierKeys = {}

-- Select object to move/rotate and apply the offset
-- and rotation of the last selected object.
move.selectActorAndApplyLast_Key = Key.NUM_FIVE
move.selectActorAndApplyLast_ModifierKeys = { ModifierKey.CONTROL }

-- Keybind to move selected object to the actor reference location.
move.selectedActorToRefActorLoc_Key = Key.NUM_FIVE
move.selectedActorToRefActorLoc_ModifierKeys = { ModifierKey.ALT }

-- Keybinds for NORMAL movements. 🠉 🠋 🠈 🠊
move.forward_Key = Key.NUM_EIGHT
move.forward_ModifierKeys = {}
move.backward_Key = Key.NUM_TWO
move.backward_ModifierKeys = {}
move.right_Key = Key.NUM_SIX
move.right_ModifierKeys = {}
move.left_Key = Key.NUM_FOUR
move.left_ModifierKeys = {}
-- Up and down movements. 🞁 🞃
move.up_Key = Key.ADD
move.up_ModifierKeys = {}
move.down_Key = Key.SUBTRACT
move.down_ModifierKeys = {}

-- Keybinds for BIG movements. 🠉 🠋 🠈 🠊
move.forward_big_Key = move.forward_Key
move.forward_big_ModifierKeys = { ModifierKey.CONTROL }
move.backward_big_Key = move.backward_Key
move.backward_big_ModifierKeys = move.forward_big_ModifierKeys
move.right_big_Key = move.right_Key
move.right_big_ModifierKeys = move.forward_big_ModifierKeys
move.left_big_Key = move.left_Key
move.left_big_ModifierKeys = move.forward_big_ModifierKeys
-- Up and down movements. 🞁 🞃
move.up_big_Key = move.up_Key
move.up_big_ModifierKeys = move.forward_big_ModifierKeys
move.down_big_Key = move.down_Key
move.down_big_ModifierKeys = move.forward_big_ModifierKeys

-- Keybinds for VERY BIG movements. 🠉 🠋 🠈 🠊
move.forward_very_big_Key = move.forward_Key
move.forward_very_big_ModifierKeys = { ModifierKey.ALT }
move.backward_very_big_Key = move.backward_Key
move.backward_very_big_ModifierKeys = move.forward_very_big_ModifierKeys
move.right_very_big_Key = move.right_Key
move.right_very_big_ModifierKeys = move.forward_very_big_ModifierKeys
move.left_very_big_Key = move.left_Key
move.left_very_big_ModifierKeys = move.forward_very_big_ModifierKeys
-- Up and down movements. 🞁 🞃
move.up_very_big_Key = move.up_Key
move.up_very_big_ModifierKeys = move.forward_very_big_ModifierKeys
move.down_very_big_Key = move.down_Key
move.down_very_big_ModifierKeys = move.forward_very_big_ModifierKeys


local rotate = {
    -- How much to rotate the object.
    -- Value: number (integer or float).
    -- Range: 0 to 360.
    normal = 10,
    big = 45,
    very_big = 90,
}

-- Keybind for NORMAL rotations.
-- Clockwise. ⟳
rotate.clockwise_Key = Key.MULTIPLY
rotate.clockwise_ModifierKeys = {}
-- counterclockwise. ⟲
rotate.counterclockwise_Key = Key.DIVIDE
rotate.counterclockwise_ModifierKeys = {}

-- Keybind for BIG rotations.
-- Clockwise. ⟳
rotate.clockwise_big_Key = rotate.clockwise_Key
rotate.clockwise_big_ModifierKeys = { ModifierKey.CONTROL }
-- counterclockwise. ⟲
rotate.counterclockwise_big_Key = rotate.counterclockwise_Key
rotate.counterclockwise_big_ModifierKeys = { ModifierKey.CONTROL }

-- Keybind for VERY BIG rotations.
-- Clockwise. ⟳
rotate.clockwise_very_big_Key = rotate.clockwise_Key
rotate.clockwise_very_big_ModifierKeys = { ModifierKey.ALT }
-- counterclockwise. ⟲
rotate.counterclockwise_very_big_Key = rotate.counterclockwise_Key
rotate.counterclockwise_very_big_ModifierKeys = { ModifierKey.ALT }


----------------------------------------
options.move = move
options.rotate = rotate

return options
