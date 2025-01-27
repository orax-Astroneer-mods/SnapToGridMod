LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel
ACTOR_REFERENCE_LOCATION = { X = 0, Y = 0, Z = 0 } ---@type FVector
ARC_LENGTH = 0 ---@type number Orange arc of circles.
PLANE_ANGLE = 0 ---@type number
U_UNIT = { X = 0, Y = 0, Z = 0 } ---@type FVector
V_UNIT = { X = 0, Y = 0, Z = 0 } ---@type FVector

---@class FOutputDevice
---@field Log function

local options = {}

local UEHelpers = require("UEHelpers")
local logging = require("lib.lua-mods-libs.logging")

local mathlib = UEHelpers.GetKismetMathLibrary()
local currentModDirectory = debug.getinfo(1, "S").source:match("@?(.+\\Mods\\[^\\]+)")

---@param filename string
---@return boolean
local function isFileExists(filename)
   local file = io.open(filename, "r")
   if file ~= nil then
      io.close(file)
      return true
   else
      return false
   end
end

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

local function loadParameters()
   local file = string.format([[%s\params.lua]], currentModDirectory)

   if not isFileExists(file) then
      local cmd = string.format([[copy "%s\params.example.lua" "%s\params.lua"]],
         currentModDirectory,
         currentModDirectory)

      print("Copy example params to params.lua. Execute command: " .. cmd .. "\n")

      os.execute(cmd)
   end

   dofile(file)
end

options = loadOptions()
loadParameters()
local log = logging.new(LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR)

--------------------------------------------------

local function writeOptionsFile()
   local file = io.open(currentModDirectory .. "\\params.lua", "w+")

   assert(file)
   file:write(string.format(
      [[ACTOR_REFERENCE_LOCATION={X=%.16g,Y=%.16g,Z=%.16g}
ARC_LENGTH=%.16g
PLANE_ANGLE=%.16g
]], ACTOR_REFERENCE_LOCATION.X, ACTOR_REFERENCE_LOCATION.Y, ACTOR_REFERENCE_LOCATION.Z,
      ARC_LENGTH,
      PLANE_ANGLE))

   file:close()
end

-- get nearest multiple of base
local function round(num, base)
   return math.floor(num / base + 0.5) * base
end

local function round2(num, numDecimalPlaces)
   local mult = 10 ^ (numDecimalPlaces or 4)
   return math.floor(num * mult + 0.5) / mult
end

---@return FVector
local function getPlanetCenter()
   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   local homeBody = playerController.HomeBody   -- 0xC98
   local rootComponent = homeBody.RootComponent -- 0x160

   local loc = rootComponent.RelativeLocation
   return { X = loc.X, Y = loc.Y, Z = loc.Z }
end

local function GetActorFromHitResult(HitResult)
   if UnrealVersion:IsBelow(5, 0) then
      return HitResult.Actor:Get()
   elseif UnrealVersion:IsBelow(5, 4) then
      return HitResult.HitObjectHandle.Actor:Get()
   else
      return HitResult.HitObjectHandle.ReferenceObject:Get()
   end
end

---@param v FVector
---@return number
local function getVectorLength(v)
   return math.sqrt((v.X * v.X) + (v.Y * v.Y) + (v.Z * v.Z))
end

---@param v FVector
---@return FVector
local function normalizeVector(v)
   local norm = getVectorLength(v)

   if norm > 0 then
      return { X = v.X / norm, Y = v.Y / norm, Z = v.Z / norm }
   end

   return v
end

---@param v1 FVector
---@param v2 FVector
---@return number
local function getDotProduct(v1, v2)
   return (v1.X * v2.X) + (v1.Y * v2.Y) + (v1.Z * v2.Z)
end

---@param v1 FVector
---@param v2 FVector
---@return number
local function getAngleBetweenVectors(v1, v2)
   return math.acos(getDotProduct(normalizeVector(v1), normalizeVector(v2)))
end

local function setActorReferenceLocation()
   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {}
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, true, hitResult)

   ---@type AActor
   local hitActor = GetActorFromHitResult(hitResult)
   log.info(string.format("HitActor: %s\n", hitActor:GetFullName()))

   ACTOR_REFERENCE_LOCATION = hitActor:K2_GetActorLocation()

   local planetCenter = getPlanetCenter()
   ACTOR_REFERENCE_LOCATION = {
      X = ACTOR_REFERENCE_LOCATION.X - planetCenter.X,
      Y = ACTOR_REFERENCE_LOCATION.Y - planetCenter.Y,
      Z = ACTOR_REFERENCE_LOCATION.Z - planetCenter.Z
   }

   log.info(string.format("ACTOR_REFERENCE_LOCATION { X = %.16g, Y = %.16g, Z = %.16g }",
      ACTOR_REFERENCE_LOCATION.X,
      ACTOR_REFERENCE_LOCATION.Y,
      ACTOR_REFERENCE_LOCATION.Z))

   writeOptionsFile()
end

---https://stackoverflow.com/a/3554821
---@param n number
---@param b number
---@return string
local function base(n, b)
   n = math.floor(n)
   if not b or b == 10 then return tostring(n) end
   local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
   local t = {}
   local sign = ""
   if n < 0 then
      sign = "-"
      n = -n
   end
   repeat
      local d = (n % b) + 1
      n = math.floor(n / b)
      table.insert(t, 1, letters:sub(d, d))
   until n == 0
   return sign .. table.concat(t, "")
end

---@param pA_0 FVector
---@param p_actor FVector Actor location.
---@param arcLength number
---@param planeAngle number
---@return FVector, FVector
local function snapToGrid(pA_0, p_actor, arcLength, planeAngle)
   if pA_0.X == nil or pA_0.Y == nil or pA_0.Z == nil then
      log.error("You must define an ACTOR_REFERENCE_LOCATION (place the cursor on an object and press F5).")
   end

   log.debug("arcLength     " .. arcLength)
   assert(arcLength ~= 0, "arcLength cannot be equal to 0.")

   local planetCenter = getPlanetCenter()
   log.debug(string.format("planetCenter     (%s, %s, %s)", planetCenter.X, planetCenter.Y, planetCenter.Z))

   p_actor = {
      X = p_actor.X - planetCenter.X,
      Y = p_actor.Y - planetCenter.Y,
      Z = p_actor.Z - planetCenter.Z
   }

   local r_0 = getVectorLength(pA_0)
   log.debug("r_0     " .. r_0)

   -- segment (pA_0, pointA_0Z) is parallel to the Z axis
   local pointA_0Z = { X = pA_0.X, Y = pA_0.Y, Z = pA_0.Z + 1 } ---@type FVector
   log.debug(string.format("pointA_0Z     (%s, %s, %s)", pointA_0Z.X, pointA_0Z.Y, pointA_0Z.Z))

   local p_vectorOnPlane = mathlib:RotateAngleAxis(pointA_0Z, planeAngle, pA_0)
   log.debug(string.format("p_vectorOnPlane     (%s, %s, %s)", p_vectorOnPlane.X, p_vectorOnPlane.Y, p_vectorOnPlane.Z))

   local vectorOnPlane = {
      X = p_vectorOnPlane.X - pA_0.X,
      Y = p_vectorOnPlane.Y - pA_0.Y,
      Z = p_vectorOnPlane.Z - pA_0.Z
   }
   local vectorOnPlane_unit = normalizeVector(vectorOnPlane)
   log.debug(string.format("vectorOnPlane_unit     (%s, %s, %s)",
      vectorOnPlane_unit.X, vectorOnPlane_unit.Y, vectorOnPlane_unit.Z))

   -- The length of the vector must be equal to the radius of the sphere (pA_0 length).
   -- We resize the vector, because the player can place the object anywhere in the game.
   -- The object will not necessarily be placed correctly on the planet.
   local unit = normalizeVector(p_actor)
   p_actor = { X = unit.X * r_0, Y = unit.Y * r_0, Z = unit.Z * r_0 }
   log.debug(string.format("actor     (%s, %s, %s)", p_actor.X, p_actor.Y, p_actor.Z))

   -- The vectors pA_0 and userVector are coplanar.
   -- The vector userVector determines the plane position and rotation.
   -- The angle between pA_0 and 𝑢 = 90°.
   -- The angle between pA_0 and 𝑣 = 90°.
   -- The angle between 𝑢 and 𝑣 = 90°.

   -- cross product (or vector product)
   local u = mathlib:Cross_VectorVector(normalizeVector(pA_0), vectorOnPlane_unit)
   local u_unit = normalizeVector(u)

   local v = mathlib:Cross_VectorVector(pA_0, u)
   local v_unit = normalizeVector(v)

   U_UNIT = u_unit
   V_UNIT = v_unit

   local sign_0 = (u_unit.X * p_actor.X) + (u_unit.Y * p_actor.Y) + (u_unit.Z * p_actor.Z)
   sign_0 = sign_0 < 0 and -1 or 1
   local sign_1 = (v_unit.X * p_actor.X) + (v_unit.Y * p_actor.Y) + (v_unit.Z * p_actor.Z)
   sign_1 = sign_1 < 0 and 1 or -1 -- /!\ inverted sign

   --#region Circular arc 1 ORANGE (left/right)

   -- GeoGebra: projection (point)
   local projection = mathlib:ProjectPointOnToPlane(p_actor, { X = 0, Y = 0, Z = 0 }, u_unit)
   -- GeoGebra: α (angle)
   local angleAlpha = getAngleBetweenVectors(p_actor, projection)

   -- GeoGebra: arc_α (arc circle)
   local arcLength_0 = r_0 * angleAlpha
   local roundedArcLength_0 = round(arcLength_0, arcLength)

   local n_number = math.tointeger(round2((roundedArcLength_0 / arcLength) * sign_0, 0))
   assert(n_number ~= nil)

   local theta_0 = arcLength / r_0

   -- pA_N means pA_(-)[0-9]. ex: pA_2, pA_-2, pA_15.
   local pA_N = n_number == 0 and pA_0 or mathlib:RotateAngleAxis(pA_0, math.deg(n_number * theta_0), v)

   local n_number_minus1 = n_number - 1 * sign_0
   local pA_N_minus_1 = n_number - 1 == 0 and pA_0 or
       mathlib:RotateAngleAxis(pA_0, math.deg(n_number_minus1 * theta_0), v)
   --#endregion
   --#region Circular arc 2 BLACK (down/up)
   local angleBeta = getAngleBetweenVectors(pA_0, projection)

   local projectionLength = getVectorLength(projection)

   -- GeoGebra: arc_β (arc circle)
   local arcLength_1 = projectionLength * angleBeta
   local roundedArcLength_1 = round(arcLength_1, arcLength)

   local n_letter = math.tointeger(round2((roundedArcLength_1 / arcLength) * sign_1, 0))
   assert(n_letter ~= nil)

   local r_N = r_0 * math.cos(n_number * theta_0)
   local theta_N = arcLength / r_N

   local r_N_minus1 = r_0 * math.cos(n_number_minus1 * theta_0)
   local theta_N_minus1 = arcLength / r_N_minus1

   --#endregion

   local newActorLocation = mathlib:RotateAngleAxis(pA_N, math.deg(n_letter * theta_N), u_unit)
   local newActorLocation_minus1 = mathlib:RotateAngleAxis(pA_N_minus_1, math.deg(n_letter * theta_N_minus1), u_unit)

   local angle_minus1 = getAngleBetweenVectors(newActorLocation, newActorLocation_minus1)
   local arcLength_minus1 = angle_minus1 * r_0

   newActorLocation = {
      X = newActorLocation.X + planetCenter.X,
      Y = newActorLocation.Y + planetCenter.Y,
      Z = newActorLocation.Z + planetCenter.Z
   }

   -- n_number is the number on the orange line
   log.debug(string.format("newActorLocation     (number=%s, letter=%s)     (%s, %s, %s)", n_number, n_letter,
      newActorLocation.X, newActorLocation.Y, newActorLocation.Z))
   log.debug(string.format("newActorLocation     {X = %s, Y = %s, Z = %s}",
      newActorLocation.X, newActorLocation.Y, newActorLocation.Z))

   local scale = math.tointeger(math.max(1, 10 ^ (math.floor(math.log(r_0, 10)) - 1)))
   log.debug("scale     1/" .. scale)

   local cmd = string.format('Execute({' ..
      '"pA_0 = Point({%.16g, %.16g, %.16g})",' ..
      '"p_actor = Point({%.16g, %.16g, %.16g})",' ..
      '"r_0 = %.16g",' ..
      '"arcLength = %.16g",' ..
      '"planeAngle = %.16g°",' ..
      '"error_x = x(newActorLocation) - %.16g",' ..
      '"error_y = y(newActorLocation) - %.16g",' ..
      '"error_z = z(newActorLocation) - %.16g"' ..
      '})',
      pA_0.X / scale, pA_0.Y / scale, pA_0.Z / scale,
      p_actor.X / scale, p_actor.Y / scale, p_actor.Z / scale,
      r_0 / scale,
      math.max(arcLength / scale, 1),
      planeAngle,
      newActorLocation.X / scale, newActorLocation.Y / scale, newActorLocation.Z / scale)

   log.debug("GeoGebra command:\n\n" .. cmd .. "\n\n")

   log.info(string.format("Arc length between p%s_%s and p%s_%s: %.16g. Difference: %.16g.",
      base(n_letter, 26), n_number, base(n_letter, 26), n_number_minus1, arcLength_minus1, arcLength_minus1 - arcLength))

   --[[ examples:
      n0=3 => p*_3; n0=34 => p*_34
      n1=1 => pB_*; n1=3 => pC_* (orange line)

      arc length between:
         pA_0 and pA_1 = ARC_LENGTH (black line)
         pA_0 and pB_0 = ARC_LENGTH (orange line)
         pB_0 and pC_0 = ARC_LENGTH (orange line)
         pY_0 and pZ_0 = ARC_LENGTH (orange line)
         pB_0 and pB_1 = ARC_LENGTH + error (black line)
   ]]
   log.info(string.format("Point %s %s     letter=%s number=%s",
      base(n_letter, 26), n_number, n_letter, n_number))

   return newActorLocation, u_unit
end

---@param actor AActor
---@param location FVector
---@param u_unit FVector
local function setNewRotation(actor, location, u_unit)
   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {} --- @type FHitResult

   -- fix rotation
   local rot = mathlib:FindLookAtRotation(location, getPlanetCenter())
   actor:K2_SetActorRotation(rot, false)
   actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 90, Yaw = 0 }, false, hitResult, false)

   local rightVector = actor:GetActorRightVector()
   local cos_angle = getDotProduct(u_unit, rightVector)
   local angle = math.deg(math.acos(cos_angle))
   rot = { Roll = 0, Pitch = 0, Yaw = angle } ---@type FRotator
   actor:K2_AddActorLocalRotation(rot, false, hitResult, false)
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
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, true, hitResult)

   ---@type AActor
   local hitActor = GetActorFromHitResult(hitResult)
   log.debug(string.format("HitActor: %s\n", hitActor:GetFullName()))

   local p_actor = hitActor:K2_GetActorLocation()
   local newLoc, u_unit = snapToGrid(ACTOR_REFERENCE_LOCATION, p_actor, ARC_LENGTH, PLANE_ANGLE)

   if options.set_new_rotation then
      setNewRotation(hitActor, newLoc, u_unit)
   end

   if options.set_new_location then
      hitActor:K2_SetActorLocation(newLoc, false, sweepHitResult, false)
   end
end

local function initUV()
   -- Initialize U_UNIT and V_UNIT. Required for rotatePlayerTo[Black/Orange]Line functions.
   if ACTOR_REFERENCE_LOCATION.X ~= nil and ACTOR_REFERENCE_LOCATION.Y ~= nil and ACTOR_REFERENCE_LOCATION.Z ~= nil and PLANE_ANGLE ~= nil and ARC_LENGTH ~= nil then
      snapToGrid(ACTOR_REFERENCE_LOCATION, ACTOR_REFERENCE_LOCATION, ARC_LENGTH, PLANE_ANGLE)
   end
end

local function rotatePlayerToBlackLine()
   if U_UNIT.X == V_UNIT.X and U_UNIT.Y == V_UNIT.Y and U_UNIT.Z == V_UNIT.Z then
      initUV()
   end

   local player = UEHelpers:GetPlayer()
   setNewRotation(player, player:K2_GetActorLocation(), U_UNIT)
   log.info("You look in the direction of the BLACK line.")
end

local function rotatePlayerToOrangeLine()
   if U_UNIT.X == V_UNIT.X and U_UNIT.Y == V_UNIT.Y and U_UNIT.Z == V_UNIT.Z then
      initUV()
   end

   local player = UEHelpers:GetPlayer()
   setNewRotation(player, player:K2_GetActorLocation(), V_UNIT)
   log.info("You look in the direction of the ORANGE line.")
end

if options.snap_on_drop then
   -- See also: RegisterHook("/Script/Astro.PhysicalItem:PlacementTransform", function(Self, Hit) end)
   RegisterHook("/Script/Astro.PhysicalItem:MulticastDroppedInWorld",
      function(self, Component, TerrainComponent, Point, Normal)
         local physicalItem = self:get() ---@diagnostic disable-line: undefined-field

         ---@cast physicalItem APhysicalItem

         local p_actor = physicalItem:K2_GetActorLocation()
         local newLoc, u_unit = snapToGrid(ACTOR_REFERENCE_LOCATION, p_actor, ARC_LENGTH, PLANE_ANGLE)

         if options.set_new_rotation then
            setNewRotation(physicalItem, newLoc, u_unit)
         end

         if options.set_new_location then
            Point:set(newLoc)
         end
      end)
end

if options.snapActorToGrid_Key ~= nil then
   if options.snapActorToGrid_ModifierKey ~= nil then
      RegisterKeyBind(options.snapActorToGrid_Key, { options.snapActorToGrid_ModifierKey }, snapActorToGrid)
   else
      RegisterKeyBind(options.snapActorToGrid_Key, snapActorToGrid)
   end
end

if options.setActorReferenceLocation_Key ~= nil then
   if options.setActorReferenceLocation_ModifierKey ~= nil then
      RegisterKeyBind(options.setActorReferenceLocation_Key, { options.setActorReferenceLocation_ModifierKey },
         setActorReferenceLocation)
   else
      RegisterKeyBind(options.setActorReferenceLocation_Key, setActorReferenceLocation)
   end
end

if options.rotatePlayerToBlackLine_Key ~= nil then
   if options.rotatePlayerToBlackLine_ModifierKey ~= nil then
      RegisterKeyBind(options.rotatePlayerToBlackLine_Key, { options.rotatePlayerToBlackLine_ModifierKey },
         rotatePlayerToBlackLine)
   else
      RegisterKeyBind(options.rotatePlayerToBlackLine_Key, rotatePlayerToBlackLine)
   end
end

if options.rotatePlayerToOrangeLine_Key ~= nil then
   if options.rotatePlayerToOrangeLine_ModifierKey ~= nil then
      RegisterKeyBind(options.rotatePlayerToOrangeLine_Key, { options.rotatePlayerToOrangeLine_ModifierKey },
         rotatePlayerToOrangeLine)
   else
      RegisterKeyBind(options.rotatePlayerToOrangeLine_Key, rotatePlayerToOrangeLine)
   end
end

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("angle", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: angle <angle in degrees (0 to 360)>\n" ..
       "Example: angle 90\n" ..
       "Current angle: " .. PLANE_ANGLE

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

   PLANE_ANGLE = angle
   outputDevice:Log("New angle: " .. angle)

   writeOptionsFile()

   return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("rloc", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: rloc <X> <Y> <Z>\n" ..
       "Example: rloc 123500 0 0\n" ..
       "Current actor reference location: " ..
       string.format("%.16g %.16g %.16g",
          ACTOR_REFERENCE_LOCATION.X, ACTOR_REFERENCE_LOCATION.Y, ACTOR_REFERENCE_LOCATION.Z)

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

   ACTOR_REFERENCE_LOCATION = { X = x, Y = y, Z = z }
   outputDevice:Log(string.format("New actor reference location: %.16g %.16g %.16g",
      ACTOR_REFERENCE_LOCATION.X, ACTOR_REFERENCE_LOCATION.Y, ACTOR_REFERENCE_LOCATION.Z))

   writeOptionsFile()

   return true
end)

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
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, true, hitResult)

   ---@type AActor
   local hitActor = GetActorFromHitResult(hitResult)
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

   local newLocation = { X = x, Y = y, Z = z }
   hitActor:K2_SetActorLocation(newLocation, false, {}, false) ---@diagnostic disable-line: missing-fields

   local msg = string.format("New actor location: %.16g %.16g %.16g",
      newLocation.X, newLocation.Y, newLocation.Z)
   outputDevice:Log(msg)
   log.debug(msg)

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
       "Current arc length: " .. ARC_LENGTH

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

   ARC_LENGTH = arc
   outputDevice:Log("New arc length: " .. arc)

   writeOptionsFile()

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
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, true, hitResult)

   ---@type AActor
   local hitActor = GetActorFromHitResult(hitResult)

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
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, true, hitResult)

   ---@type AActor
   local hitActor = GetActorFromHitResult(hitResult)

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
      "actor reference location (rloc): %.16g %.16g %.16g\n" ..
      "arc length (arc): %.16g\n" ..
      "plane angle (angle): %.16g\n" ..
      "player location (go): %.16g %.16g %.16g\n",
      ACTOR_REFERENCE_LOCATION.X, ACTOR_REFERENCE_LOCATION.Y, ACTOR_REFERENCE_LOCATION.Z,
      ARC_LENGTH,
      PLANE_ANGLE,
      playerLocation.X, playerLocation.Y, playerLocation.Z)

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

-- Uncomment to run tests.
-- SnapToGrid = snapToGrid
-- dofile(currentModDirectory .. "\\Scripts\\tests.lua")
