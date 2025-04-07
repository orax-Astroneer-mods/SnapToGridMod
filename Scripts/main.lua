---@class FOutputDevice
---@field Log function

local UEHelpers = require("UEHelpers")
local logging = require("lib.lua-mods-libs.logging")
require("func")

--#region Initialization

local currentModDirectory = debug.getinfo(1, "S").source:match("@?(.+\\Mods\\[^\\]+)")

-- functions implemented in the method file
local snapToGrid, writeParamsFile, onSetActorReference, getDirection1, getDirection2

local function loadOptions()
   local file = string.format([[%s\options.lua]], currentModDirectory)

   if not isFileExists(file) then
      local cmd = string.format([[copy "%s\options.example.lua" "%s\options.lua"]],
         currentModDirectory,
         currentModDirectory)

      print("Copy example options to options.lua. Execute command: " .. cmd .. "\n")

      os.execute(cmd)
   end

   return dofile(file)
end

---Retrieve functions from the method file.
---snapToGrid(): Set the new location of the actor.
---writeParamsFile(): Write parameters to the params.lua file.
---onSetActorReference(): Function executed on setting actor reference location.
---@param method string
local function loadMethod(method)
   local t = dofile(currentModDirectory ..
      "\\Scripts\\methods\\" .. method .. "\\main.lua")

   snapToGrid = t.snapToGrid
   writeParamsFile = t.writeParamsFile
   onSetActorReference = t.onSetActorReference
   getDirection1 = t.getDirection1
   getDirection2 = t.getDirection2
end

-- Default logging levels. They can be overwritten in the options file.
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = loadOptions()
OPTIONS = options

Log = logging.new(LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR)
local log = Log
LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR = nil, nil

PARAMS = nil
modules = "lib.LEEF-math.modules." ---@diagnostic disable-line: lowercase-global
Vec3 = require("lib.LEEF-math.modules.vec3")
local vec3 = Vec3

U_UNIT = vec3.new(0, 0, 0)
V_UNIT = vec3.new(0, 0, 0)

local Selected = { actor = CreateInvalidObject(), angle = 0, upOffset = 0 } -- selected actor

loadMethod(options.method)

--#endregion Initialization

local function setActorReferenceLocation()
   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {}
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, false, hitResult)

   local hitActor = UEHelpers.GetActorFromHitResult(hitResult)
   if not hitActor:IsValid() or hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end ---@cast hitActor AActor

   log.info(string.format("HitActor: %s\n", hitActor:GetFullName()))

   local u = hitActor:K2_GetActorLocation()
   local actorLoc = vec3.new(u.X, u.Y, u.Z)

   local planetCenter = getPlanetCenter()
   actorLoc = actorLoc - planetCenter

   log.info(string.format("ACTOR_REF_LOC { X = %.16g, Y = %.16g, Z = %.16g }",
      actorLoc.x,
      actorLoc.y,
      actorLoc.z))

   PARAMS.ACTOR_REF_LOC = actorLoc

   if type(onSetActorReference) == "function" then
      onSetActorReference(hitActor, hitResult)
   end

   writeParamsFile()
end

local function snapActorToGrid()
   -- Note: X axis is the altitude in Astroneer.

   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {}      --- @type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local sweepHitResult = {} --- @type FHitResult
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, false, hitResult) -- bTraceComplex false: less crashes?

   local hitActor = UEHelpers.GetActorFromHitResult(hitResult)
   if not hitActor:IsValid() or hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end ---@cast hitActor AActor

   log.debug(string.format("HitActor: %s\n", hitActor:GetFullName()))

   local actorLoc = hitActor:K2_GetActorLocation()
   local p_actor = vec3.new(actorLoc.X, actorLoc.Y, actorLoc.Z)

   local newLoc = snapToGrid(PARAMS.ACTOR_REF_LOC, p_actor, hitActor, nil, nil)

   if options.set_new_location then
      hitActor:K2_SetActorLocation({ X = newLoc.x, Y = newLoc.y, Z = newLoc.z }, false, sweepHitResult, false)
   end
end

local function rotatePlayerToDirection1()
   if type(getDirection1) ~= "function" then
      log.info("Direction 1 is not implemented with this method.")
      return
   end

   local direction = getDirection1()
   rotatePlayerTo(direction)
end

local function rotatePlayerToDirection2()
   if type(getDirection2) ~= "function" then
      log.info("Direction 2 is not implemented with this method.")
      return
   end

   local direction = getDirection2()
   rotatePlayerTo(direction)
end

if options.snap_on_drop then
   -- See also: RegisterHook("/Script/Astro.PhysicalItem:PlacementTransform", function(Self, Hit) end)
   RegisterHook("/Script/Astro.PhysicalItem:MulticastDroppedInWorld",
      function(self, Component, TerrainComponent, Point, Normal)
         local physicalItem = self:get() ---@diagnostic disable-line: undefined-field

         ---@cast physicalItem APhysicalItem

         local actorLoc = physicalItem:K2_GetActorLocation()
         local p_actor = vec3.new(actorLoc.X, actorLoc.Y, actorLoc.Z)

         local newLoc = snapToGrid(PARAMS.ACTOR_REF_LOC, p_actor, physicalItem, nil, nil)

         if options.set_new_location then
            Point:set(newLoc)
         end
      end)
end

local function selectActor()
   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {} --- @type FHitResult
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, false, hitResult)

   local hitActor = UEHelpers.GetActorFromHitResult(hitResult)
   if not hitActor:IsValid() or hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end ---@cast hitActor AActor

   log.info(string.format("Select actor: %s\n",
      hitActor:GetFullName()))

   Selected.actor = hitActor

   Selected.angle = 0
   Selected.upOffset = 0
end

local function selectActorAndApplyLastOffsetAndRotation()
   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {} --- @type FHitResult
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, false, hitResult)

   local hitActor = UEHelpers.GetActorFromHitResult(hitResult)
   if not hitActor:IsValid() or hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end ---@cast hitActor AActor

   log.info(string.format("Select actor: %s\n",
      hitActor:GetFullName()))

   Selected.actor = hitActor

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = Selected.angle }, false, {}, false)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalOffset({ X = 0, Y = 0, Z = Selected.upOffset }, false, {}, false)

   log.info("Add rotation     %.16g°", Selected.angle)
   log.info("Add up/down offset     %.16g", Selected.upOffset)
end

local function moveSelectedActorToRefActorLoc()
   if not Selected.actor:IsValid() then
      return
   end

   Selected.actor:K2_SetActorLocation(
      {
         X = PARAMS.ACTOR_REF_LOC.x,
         Y = PARAMS.ACTOR_REF_LOC.y,
         Z = PARAMS.ACTOR_REF_LOC.z
      },
      false, {}, false) ---@diagnostic disable-line: missing-fields
end

local function resetLocalOffsetAndRotation()
   if not Selected.actor:IsValid() then
      return
   end

   log.info("Reset up/down offset and angle rotation.")

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = -Selected.angle }, false, {}, false)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalOffset({ X = 0, Y = 0, Z = -Selected.upOffset }, false, {}, false)

   log.info("Subtract rotation     %.16g°", Selected.angle)
   log.info("Subtract up/down offset     %.16g", Selected.upOffset)
   Selected.angle = 0
   Selected.upOffset = 0
end

local function moveActor(n_letter, n_number)
   if not Selected.actor:IsValid() then
      return
   end

   local actorLoc = Selected.actor:K2_GetActorLocation()
   local p_actor = vec3.new(actorLoc.X, actorLoc.Y, actorLoc.Z)

   local newLoc, args = snapToGrid(PARAMS.ACTOR_REF_LOC, p_actor, Selected.actor, n_letter, n_number)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_SetActorLocation({ X = newLoc.x, Y = newLoc.y, Z = newLoc.z }, false, {}, false)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = Selected.angle }, false, {}, false)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalOffset({ X = 0, Y = 0, Z = Selected.upOffset }, false, {}, false)

   if Selected.angle ~= 0 then log.info("Add rotation     %.16g°", Selected.angle) end
   if Selected.upOffset ~= 0 then log.info("Add up/down offset     %.16g", Selected.upOffset) end
end

local function moveActorUpDown(offset)
   if not Selected.actor:IsValid() then
      return
   end

   Selected.upOffset = Selected.upOffset + offset
   log.info("Up/down offset     %.16g", Selected.upOffset)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalOffset({ X = 0, Y = 0, Z = offset }, false, {}, false)
end

local function rotateActor(angle)
   if not Selected.actor:IsValid() then
      return
   end

   Selected.angle = Selected.angle + angle
   log.info(string.format("Rotation angle     %.16g°", Selected.angle))

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalRotation({ Pitch = 0, Roll = 0, Yaw = angle }, false, {}, false)
end

--#region rotate functions
local function rotateSelectedActorClockwise()
   rotateActor(options.rotate.normal)
end

local function rotateSelectedActorCounterclockwise()
   rotateActor(-options.rotate.normal)
end

local function rotateSelectedActorClockwise_big()
   rotateActor(options.rotate.big)
end

local function rotateSelectedActorCounterclockwise_big()
   rotateActor(-options.rotate.big)
end

local function rotateSelectedActorClockwise_very_big()
   rotateActor(options.rotate.very_big)
end

local function rotateSelectedActorCounterclockwise_very_big()
   rotateActor(-options.rotate.very_big)
end
--#endregion rotate functions

--#region move functions
local function moveSelectedActorBackward()
   moveActor(0, -options.move.normal)
end

local function moveSelectedActorLeft()
   moveActor(options.move.normal, 0)
end

local function moveSelectedActorRight()
   moveActor(-options.move.normal, 0)
end

local function moveSelectedActorForward()
   moveActor(0, options.move.normal)
end

local function moveSelectedActorBackward_big()
   moveActor(0, -options.move.big)
end

local function moveSelectedActorLeft_big()
   moveActor(options.move.big, 0)
end

local function moveSelectedActorRight_big()
   moveActor(-options.move.big, 0)
end

local function moveSelectedActorForward_big()
   moveActor(0, options.move.big)
end

local function moveSelectedActorBackward_very_big()
   moveActor(0, -options.move.very_big)
end

local function moveSelectedActorLeft_very_big()
   moveActor(options.move.very_big, 0)
end

local function moveSelectedActorRight_very_big()
   moveActor(-options.move.very_big, 0)
end

local function moveSelectedActorForward_very_big()
   moveActor(0, options.move.very_big)
end

--#region move up/down
local function moveSelectedActorUp()
   moveActorUpDown(options.move.up_down_normal)
end

local function moveSelectedActorDown()
   moveActorUpDown(-options.move.up_down_normal)
end

local function moveSelectedActorUp_big()
   moveActorUpDown(options.move.up_down_big)
end

local function moveSelectedActorDown_big()
   moveActorUpDown(-options.move.up_down_big)
end
local function moveSelectedActorUp_very_big()
   moveActorUpDown(options.move.up_down_very_big)
end

local function moveSelectedActorDown_very_big()
   moveActorUpDown(-options.move.up_down_very_big)
end
--#endregion
--#endregion move functions

--#region registerKeyBind

---@param key Key
---@param modifierKeys ModifierKey[]
---@param callback function
local function registerKeyBind(key, modifierKeys, callback)
   if key ~= nil then
      if IsKeyBindRegistered(key, modifierKeys or {}) then
         local keyName = ""
         for k, v in pairs(Key) do
            if key == v then
               keyName = k
               break
            end
         end

         local modifierKeysList = ""
         for _, keyValue in ipairs(modifierKeys) do
            for k, v in pairs(ModifierKey) do
               if keyValue == v then
                  modifierKeysList = modifierKeysList .. k .. "+"
               end
            end
         end

         log.warn("\nKey bind %q is already registered.", modifierKeysList .. keyName)
      end

      if modifierKeys ~= nil and type(modifierKeys) == "table" and #modifierKeys > 0 then
         RegisterKeyBind(key, modifierKeys, function()
            ExecuteInGameThread(function()
               callback()
            end)
         end)
      else
         RegisterKeyBind(key, function()
            ExecuteInGameThread(function()
               callback()
            end)
         end)
      end
   end
end

registerKeyBind(options.resetLocalOffsetAndRotation_Key,
   options.resetLocalOffsetAndRotation_ModifierKeys,
   resetLocalOffsetAndRotation)


registerKeyBind(options.move.selectActor_Key,
   options.move.selectActor_ModifierKeys,
   selectActor)

registerKeyBind(options.move.selectActorAndApplyLast_Key,
   options.move.selectActorAndApplyLast_ModifierKeys,
   selectActorAndApplyLastOffsetAndRotation)

--#region moveSelectedActor
registerKeyBind(options.move.selectedActorToRefActorLoc_Key,
   options.move.selectedActorToRefActorLoc_ModifierKeys,
   moveSelectedActorToRefActorLoc)

--#region normal
registerKeyBind(options.move.forward_Key,
   options.move.forward_ModifierKeys,
   moveSelectedActorForward)

registerKeyBind(options.move.backward_Key,
   options.move.backward_ModifierKeys,
   moveSelectedActorBackward)

registerKeyBind(options.move.right_Key,
   options.move.right_ModifierKeys,
   moveSelectedActorRight)

registerKeyBind(options.move.left_Key,
   options.move.left_ModifierKeys,
   moveSelectedActorLeft)

registerKeyBind(options.move.up_Key,
   options.move.up_ModifierKeys,
   moveSelectedActorUp)

registerKeyBind(options.move.down_Key,
   options.move.down_ModifierKeys,
   moveSelectedActorDown)
--#endregion normal

--#region big
registerKeyBind(options.move.forward_big_Key,
   options.move.forward_big_ModifierKeys,
   moveSelectedActorForward_big)

registerKeyBind(options.move.backward_big_Key,
   options.move.backward_big_ModifierKeys,
   moveSelectedActorBackward_big)

registerKeyBind(options.move.right_big_Key,
   options.move.right_big_ModifierKeys,
   moveSelectedActorRight_big)

registerKeyBind(options.move.left_big_Key,
   options.move.left_big_ModifierKeys,
   moveSelectedActorLeft_big)

registerKeyBind(options.move.up_big_Key,
   options.move.up_big_ModifierKeys,
   moveSelectedActorUp_big)

registerKeyBind(options.move.down_big_Key,
   options.move.down_big_ModifierKeys,
   moveSelectedActorDown_big)
--#endregion big

--#region very_big
registerKeyBind(options.move.forward_very_big_Key,
   options.move.forward_very_big_ModifierKeys,
   moveSelectedActorForward_very_big)

registerKeyBind(options.move.backward_very_big_Key,
   options.move.backward_very_big_ModifierKeys,
   moveSelectedActorBackward_very_big)

registerKeyBind(options.move.right_very_big_Key,
   options.move.right_very_big_ModifierKeys,
   moveSelectedActorRight_very_big)

registerKeyBind(options.move.left_very_big_Key,
   options.move.left_very_big_ModifierKeys,
   moveSelectedActorLeft_very_big)

registerKeyBind(options.move.up_very_big_Key,
   options.move.up_very_big_ModifierKeys,
   moveSelectedActorUp_very_big)

registerKeyBind(options.move.down_very_big_Key,
   options.move.down_very_big_ModifierKeys,
   moveSelectedActorDown_very_big)
--#endregion very_big
--#endregion moveSelectedActor

--#region rotateSelectedActor
--#region normal rotate
registerKeyBind(options.rotate.clockwise_Key,
   options.rotate.clockwise_ModifierKeys,
   rotateSelectedActorClockwise)

registerKeyBind(options.rotate.counterclockwise_Key,
   options.rotate.counterclockwise_ModifierKeys,
   rotateSelectedActorCounterclockwise)
--#endregion normal rotate

--#region big rotate
registerKeyBind(options.rotate.clockwise_big_Key,
   options.rotate.clockwise_big_ModifierKeys,
   rotateSelectedActorClockwise_big)

registerKeyBind(options.rotate.counterclockwise_big_Key,
   options.rotate.counterclockwise_big_ModifierKeys,
   rotateSelectedActorCounterclockwise_big)
--#endregion big rotate

--#region very big rotate
registerKeyBind(options.rotate.clockwise_very_big_Key,
   options.rotate.clockwise_very_big_ModifierKeys,
   rotateSelectedActorClockwise_very_big)

registerKeyBind(options.rotate.counterclockwise_very_big_Key,
   options.rotate.counterclockwise_very_big_ModifierKeys,
   rotateSelectedActorCounterclockwise_very_big)
--#endregion very big rotate

--#endregion rotateSelectedActor

registerKeyBind(options.snapActorToGrid_Key,
   options.snapActorToGrid_ModifierKeys,
   snapActorToGrid)

registerKeyBind(options.setActorReferenceLocation_Key,
   options.setActorReferenceLocation_ModifierKeys,
   setActorReferenceLocation)

registerKeyBind(options.rotatePlayerToBlackLine_Key,
   options.rotatePlayerToBlackLine_ModifierKeys,
   rotatePlayerToDirection1)

registerKeyBind(options.rotatePlayerToOrangeLine_Key,
   options.rotatePlayerToOrangeLine_ModifierKeys,
   rotatePlayerToDirection2)
--#endregion registerKeyBind

--#region console commands

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("help", function(fullCommand, parameters, outputDevice)
   local helpMsg =
   [[# Snap to grid commands help
Below are the commands to change the parameters. You can also change parameters in the "params.lua" file for each method.
Parameters apply to one or more "methods." For example, the "LONGITUDE_ANGLE" parameter only applies to the "circular" method; it does not apply to the "grid" method.

Commands:

- rloc
Parameter: ACTOR_REF_LOC.
Location of the "actor reference". Press F5 (default) on an object in game to define it.
Used in methods: grid, circular.

- arc
Parameter: ARC_LENGTH.
With method grid: Length between two objects in the grid.
With method circular: Length between two objects on the same longitude.
Used in methods: grid, circular.

- angle
Parameter: ANGLE.
The angle defines grid orientation.
It corresponds to the planeAngle variable in the GeoGebra simulation.
Used in methods: grid.

- lon_angle
Parameter: LONGITUDE_ANGLE.
The angle between each meridian.
It corresponds to the angle between each longitude line on a globe.
Used in methods: circular.

- rot_angle
Parameter: ROTATION_ANGLE.
The rotation angle to be added to the "snapped" object.
Used in methods: grid, circular.
]]

   outputDevice:Log(helpMsg)
   print("\n" .. helpMsg)

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("help2", function(fullCommand, parameters, outputDevice)
   local helpMsg =
   [[# Snap to grid commands help 2
Commands:

- loc
Moves the object under the cursor to a new location.

- offset
Adds an offset to the object under the cursor. Example: "offset 0 0 100" will move it up.

- rot
Adds an rotation to the object under the cursor.

- go
Teleports you to a new location.

- info
Displays some information: player location, parameters (from params.lua), ...

- set_new_location
Temporary changes to the "set_new_location". You can save this option in options.lua.
"set_new_location" changes the behavior when you press the "snapActorToGrid_Key" key (F4 by default).
If "true", the object will be snapped to the grid; the location of the object will be changed.

- set_new_rotation
Temporary changes to the "set_new_rotation". You can save this option in options.lua.
"set_new_rotation" changes the behavior when you press the "snapActorToGrid_Key" key (F4 by default).
If "true", the rotation of the object will be corrected to be tangent to the planet; the rotation of the object will be changed.

- method
Temporary changes to the "method" option. You can save this option in options.lua.
The method (grid or circular) determines how objects will be "snapped".
]]

   outputDevice:Log(helpMsg)
   print("\n" .. helpMsg)

   return true
end)

--#region PARAMS

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("rloc", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: rloc <X> <Y> <Z>\n" ..
       "Example: rloc 123500 0 0\n" ..
       "Current actor reference location (ACTOR_REF_LOC): " ..
       (PARAMS.ACTOR_REF_LOC ~= nil and
          string.format("%.16g %.16g %.16g", PARAMS.ACTOR_REF_LOC.x, PARAMS.ACTOR_REF_LOC.y, PARAMS.ACTOR_REF_LOC.z)
          or "nil")

   if #parameters < 3 then
      outputDevice:Log(helpMsg)
      return true
   end

   local x = tonumber(parameters[1])
   local y = tonumber(parameters[2])
   local z = tonumber(parameters[3])
   if x == nil or y == nil or z == nil then
      outputDevice:Log("At least one parameter is not a number.")
      outputDevice:Log(helpMsg)
      return true
   end

   PARAMS.ACTOR_REF_LOC = vec3.new(x, y, z)
   outputDevice:Log(string.format("New actor reference location (ACTOR_REF_LOC): %.16g %.16g %.16g",
      PARAMS.ACTOR_REF_LOC.x, PARAMS.ACTOR_REF_LOC.y, PARAMS.ACTOR_REF_LOC.z))

   writeParamsFile()

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("arc", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: arc <arc length>\n" ..
       "example: arc 1000\n" ..
       "Current ARC_LENGTH: " .. PARAMS.ARC_LENGTH

   if #parameters < 1 then
      outputDevice:Log(helpMsg)
      return true
   end

   local arc = tonumber(parameters[1])
   if arc == nil or arc == 0 then
      outputDevice:Log("<arc length> is not a number or is equal to 0.")
      outputDevice:Log(helpMsg)
      return true
   end

   PARAMS.ARC_LENGTH = arc
   outputDevice:Log("New ARC_LENGTH: " .. arc)

   writeParamsFile()

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("angle", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: angle <angle in degrees (0° to 360°)>\n" ..
       "Example: angle 90\n" ..
       "Current ANGLE: " .. (PARAMS.ANGLE ~= nil and PARAMS.ANGLE or "nil")

   if #parameters < 1 then
      outputDevice:Log(helpMsg)
      return true
   end

   local angle = tonumber(parameters[1])
   if angle == nil then
      outputDevice:Log("<angle> is not a number.")
      outputDevice:Log(helpMsg)
      return true
   end

   if angle < 0 or angle > 360 then
      outputDevice:Log(helpMsg)
      return true
   end

   PARAMS.ANGLE = angle
   outputDevice:Log("New ANGLE: " .. angle)

   writeParamsFile()

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("lon_angle", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: angle <angle in degrees (-360 to 360)>\n" ..
       "Example: angle 90\n" ..
       "Current LONGITUDE_ANGLE: " .. (PARAMS.ANGLE ~= nil and PARAMS.ANGLE or "nil")

   if #parameters < 1 then
      outputDevice:Log(helpMsg)
      return true
   end

   local angle = tonumber(parameters[1])
   if angle == nil then
      outputDevice:Log("<angle> is not a number.")
      outputDevice:Log(helpMsg)
      return true
   end

   if angle < 0 or angle > 360 then
      outputDevice:Log(helpMsg)
      return true
   end

   PARAMS.ANGLE = angle
   outputDevice:Log("New ANGLE: " .. angle)

   writeParamsFile()

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("rot_angle", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: rot_angle <angle in degrees (-360 to 360)>\n" ..
       "example: rot_angle 45\n" ..
       "Current ROTATION_ANGLE: " .. (PARAMS.ROTATION_ANGLE ~= nil and PARAMS.ROTATION_ANGLE or "nil")

   if #parameters < 1 then
      outputDevice:Log(helpMsg)
      return true
   end

   local angle = tonumber(parameters[1])
   if angle == nil then
      outputDevice:Log("<angle> is not a number.")
      outputDevice:Log(helpMsg)
      return true
   end

   PARAMS.ROTATION_ANGLE = angle
   outputDevice:Log("New ROTATION_ANGLE: " .. angle)

   writeParamsFile()

   return true
end)

--#endregion PARAMS

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("loc", function(fullCommand, parameters, outputDevice)
   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {}
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, false, hitResult)

   local hitActor = UEHelpers.GetActorFromHitResult(hitResult)
   if not hitActor:IsValid() or hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end ---@cast hitActor AActor

   local location = hitActor:K2_GetActorLocation()

   local helpMsg =
       "Usage: loc <X> <Y> <Z>\n" ..
       "Example: loc 123500 0 0\n" ..
       "Current actor location: " ..
       string.format("%.16g %.16g %.16g",
          location.X, location.Y, location.Z)

   log.debug(string.format("Current actor location: " ..
      string.format("%.16g %.16g %.16g",
         location.X, location.Y, location.Z)))

   if #parameters < 3 then
      outputDevice:Log(helpMsg)
      return true
   end

   local x = tonumber(parameters[1])
   local y = tonumber(parameters[2])
   local z = tonumber(parameters[3])
   if x == nil or y == nil or z == nil then
      outputDevice:Log("At least one parameter is not a number.")
      outputDevice:Log(helpMsg)
      return true
   end

   if hitActor:IsA("/Script/Astro.SolarBody") then
      outputDevice:Log("This command does not work on a planet. Move the cursor over an object.")
      return true
   end

   local newLocation = { X = x, Y = y, Z = z }
   hitActor:K2_SetActorLocation(newLocation, false, {}, false) ---@diagnostic disable-line: missing-fields

   local msg = string.format("New actor location: %.16g %.16g %.16g",
      newLocation.x, newLocation.y, newLocation.z)
   outputDevice:Log(msg)
   log.debug(msg)

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("offset", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Add actor local offset\n" ..
       "Usage: offset <X> <Y> <Z>\n" ..
       "Example: offset 0 0 100"

   if #parameters < 3 then
      outputDevice:Log(helpMsg)
      return true
   end

   local x = tonumber(parameters[1])
   local y = tonumber(parameters[2])
   local z = tonumber(parameters[3])
   if x == nil or y == nil or z == nil then
      outputDevice:Log("At least one parameter is not a number.")
      outputDevice:Log(helpMsg)
      return true
   end

   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {}
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, false, hitResult)

   local hitActor = UEHelpers.GetActorFromHitResult(hitResult)
   if not hitActor:IsValid() or hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end ---@cast hitActor AActor

   hitActor:K2_AddActorLocalOffset({ X = x, Y = y, Z = z }, false, hitResult, false)

   outputDevice:Log(string.format("Add offset (%.16g, %.16g, %.16g) on %s", x, y, z, hitActor:GetFName():ToString()))

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("rot", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Add actor local rotation\n" ..
       "Usage: rot <rotation angle>\n" ..
       "example: rot 45"

   if #parameters < 1 then
      outputDevice:Log(helpMsg)
      return true
   end

   local angle = tonumber(parameters[1])
   if angle == nil then
      outputDevice:Log("<rotation angle> is not a number.")
      outputDevice:Log(helpMsg)
      return true
   end

   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {}
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, false, hitResult)

   local hitActor = UEHelpers.GetActorFromHitResult(hitResult)
   if not hitActor:IsValid() or hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end ---@cast hitActor AActor

   local rot = { Roll = 0, Pitch = 0, Yaw = angle } ---@type FRotator
   hitActor:K2_AddActorLocalRotation(rot, false, hitResult, false)

   outputDevice:Log(string.format("Add rotation angle: %.16g on %s", angle, hitActor:GetFName():ToString()))

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("go", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: go <X> <Y> <Z>\n" ..
       "example: go 123500 0 0"

   if #parameters < 3 then
      outputDevice:Log(helpMsg)
      return true
   end

   local x = tonumber(parameters[1])
   local y = tonumber(parameters[2])
   local z = tonumber(parameters[3])
   if x == nil or y == nil or z == nil then
      outputDevice:Log("At least one parameter is not a number.")
      outputDevice:Log(helpMsg)
      return true
   end

   local player = UEHelpers:GetPlayer()
   player:K2_SetActorLocation({ X = x, Y = y, Z = z }, false, {}, false) ---@diagnostic disable-line: missing-fields

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("info", function(fullCommand, parameters, outputDevice)
   local player = UEHelpers:GetPlayer()
   local playerLocation = player:K2_GetActorLocation()

   local msg = string.format(
      "player location (go): %.16g %.16g %.16g\n",
      playerLocation.X, playerLocation.Y, playerLocation.Z)

   if PARAMS ~= nil then
      for key, value in pairs(PARAMS) do
         msg = msg .. string.format("%s: %s\n", key, value)
      end
   end

   log.info("\n" .. msg)
   outputDevice:Log(msg)

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("set_new_location", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: set_new_location {true | false | 1 | 0}\n" ..
       "example: set_new_location true"

   if #parameters < 1 then
      outputDevice:Log(helpMsg)
      return true
   end

   options.set_new_location = (parameters[1] == "true" or parameters[1] == 1) and true or false

   local msg = "set_new_location = " .. tostring(options.set_new_location)
   log.info("\n" .. msg)
   outputDevice:Log(msg)

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("set_new_rotation", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: set_new_rotation {true | false | 1 | 0}\n" ..
       "example: set_new_rotation true"

   if #parameters < 1 then
      outputDevice:Log(helpMsg)
      return true
   end

   options.set_new_rotation = (parameters[1] == "true" or parameters[1] == 1) and true or false

   local msg = "set_new_rotation = " .. tostring(options.set_new_rotation)
   log.info("\n" .. msg)
   outputDevice:Log(msg)

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("method", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: method {grid | circular}\n" ..
       "example: method grid"

   if #parameters < 1 then
      outputDevice:Log(helpMsg)
      return true
   end

   local method = parameters[1]

   loadMethod(method)

   local msg = "Loading method: " .. method
   log.info("\n" .. msg)
   outputDevice:Log(msg)

   return true
end)
--#endregion console commands
