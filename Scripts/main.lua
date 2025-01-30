---@class FOutputDevice
---@field Log function

local options = {}
local Selected = { angle = 0, upOffset = 0 }

local UEHelpers = require("UEHelpers")
local logging = require("lib.lua-mods-libs.logging")
modules = "lib.LEEF-math.modules." ---@diagnostic disable-line: lowercase-global
local vec3 = require("lib.LEEF-math.modules.vec3")

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

-- Initialization

LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

options = loadOptions()
loadParameters()

local log = logging.new(LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR)
LOG_LEVEL = nil
MIN_LEVEL_OF_FATAL_ERROR = nil

local actor_reference_location = vec3.new(
   ACTOR_REFERENCE_LOCATION.X,
   ACTOR_REFERENCE_LOCATION.Y,
   ACTOR_REFERENCE_LOCATION.Z)
local arc_length = ARC_LENGTH ---@type number Orange arc of circles.
local plane_angle = PLANE_ANGLE ---@type number
local U_UNIT = vec3.new(0, 0, 0)
local V_UNIT = vec3.new(0, 0, 0)

--------------------------------------------------
---
------@param v FVector
---@return number
local function getVectorLength(v)
   return math.sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z))
end

---@param v vec3
---@return vec3
local function normalizeVector(v)
   local norm = getVectorLength(v)

   if norm > 0 then
      return vec3.new(v.x / norm, v.y / norm, v.z / norm)
   end

   return v
end

---@param v1 vec3
---@param v2 vec3
---@return number
local function getDotProduct(v1, v2)
   return (v1.x * v2.x) + (v1.y * v2.y) + (v1.z * v2.z)
end

---@param v1 vec3
---@param v2 vec3
---@return number
local function getAngleBetweenVectors(v1, v2)
   return math.acos(getDotProduct(normalizeVector(v1), normalizeVector(v2)))
end

---@param point vec3
---@param planeBase vec3
---@param planeNormal_unit vec3 Vector must be normalized (length = 1).
---@return vec3
function vec3.projectPointOnToPlane(point, planeBase, planeNormal_unit)
   --- https://dev.epicgames.com/documentation/en-us/unreal-engine/BlueprintAPI/Math/Vector/ProjectPointontoPlane
   --- https://fr.mathworks.com/matlabcentral/answers/183464-how-do-i-find-the-orthogonal-projection-of-a-point-onto-a-plane#answer_394659
   return point - vec3.scale(planeNormal_unit, vec3.dot(point - planeBase, planeNormal_unit))
end

local function writeOptionsFile()
   local file = io.open(currentModDirectory .. "\\params.lua", "w+")

   assert(file)
   file:write(string.format(
      [[ACTOR_REFERENCE_LOCATION={X=%.16g,Y=%.16g,Z=%.16g}
ARC_LENGTH=%.16g
PLANE_ANGLE=%.16g
]], actor_reference_location.x, actor_reference_location.y, actor_reference_location.z,
      arc_length,
      plane_angle))

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

---@return vec3
local function getPlanetCenter()
   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   local homeBody = playerController.HomeBody   -- 0xC98
   local rootComponent = homeBody.RootComponent -- 0x160

   local loc = rootComponent.RelativeLocation
   return vec3.new(loc.X, loc.Y, loc.Z)
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

local function setActorReferenceLocation()
   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {}
   local clickableChannel = 4

   local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
   playerController:GetHitResultUnderCursorByChannel(clickableChannel, true, hitResult)

   ---@type AActor
   local hitActor = GetActorFromHitResult(hitResult)
   if hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end
   log.info(string.format("HitActor: %s\n", hitActor:GetFullName()))

   local actorLoc = hitActor:K2_GetActorLocation()
   actor_reference_location = vec3.new(actorLoc.X, actorLoc.Y, actorLoc.Z)

   local planetCenter = getPlanetCenter()
   actor_reference_location = actor_reference_location - planetCenter

   log.info(string.format("ACTOR_REFERENCE_LOCATION { X = %.16g, Y = %.16g, Z = %.16g }",
      actor_reference_location.x,
      actor_reference_location.y,
      actor_reference_location.z))

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

---https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/Kismet/UKismetMathLibrary/FindLookAtRotation
---@param start vec3
---@param target vec3
---@return FRotator
function vec3.findLookAtRotation(start, target)
   local d = target - start ---@type vec3 direction vector
   local yaw = math.atan(d.y, d.x)

   local d_norm_xOy = math.sqrt(d.x * d.x + d.y * d.y)
   local pitch = math.atan(d.z, d_norm_xOy)

   return { Pitch = math.deg(pitch), Yaw = math.deg(yaw), Roll = 0 }
end

---Same as vec3.angle_to but the cosine is forced into the interval [-1;1].
---@param a any
---@param b any
---@return number
function vec3.angle_to_safe(a, b)
   --[[ In this example, the cosine is greater than 1.
local u = vec3.new(-73947.640625, 50619.046875, 81827.1953125)
local v = vec3.new(-73947.640625, 50619.04687499999, 81827.19531250001)
local c = vec3.dot(u, v) / (vec3.len(u) * vec3.len(v))
print(string.format("cos=%.64g", c)) -- cos=1.0000000000000002220446049250313080847263336181640625 (!!!)
print(math.acos(c)) -- -nan(ind)
See also: ---https://fr.mathworks.com/matlabcentral/answers/101590-how-can-i-determine-the-angle-between-two-vectors-in-matlab ]]
   local v = math.max(-1, math.min(1, a:normalize():dot(b:normalize())))
   return math.acos(v)
end

---@param pA_0 vec3
---@param p_actor vec3 Actor location.
---@param arcLength number
---@param planeAngle number
---@return vec3, vec3
local function snapToGrid(pA_0, p_actor, arcLength, planeAngle, custom_n_letter, custom_n_number)
   if pA_0.x == nil or pA_0.y == nil or pA_0.z == nil then
      log.error("You must define an ACTOR_REFERENCE_LOCATION (place the cursor on an object and press F5).")
   end

   log.debug("arcLength     " .. arcLength)
   assert(arcLength ~= 0, "arcLength cannot be equal to 0.")

   custom_n_letter = custom_n_letter or 0
   custom_n_number = custom_n_number or 0

   local planetCenter = getPlanetCenter()
   log.debug(string.format("planetCenter     (%.16g, %.16g, %.16g)", planetCenter.x, planetCenter.y, planetCenter.z))

   p_actor = vec3.new(
      p_actor.x - planetCenter.x,
      p_actor.y - planetCenter.y,
      p_actor.z - planetCenter.z)

   local r_0 = vec3.len(pA_0)
   log.debug("r_0     " .. r_0)

   -- segment (pA_0, pointA_0Z) is parallel to the Z axis
   local pointA_0Z = vec3.new(pA_0.x, pA_0.y, pA_0.z + 1)
   log.debug(string.format("pointA_0Z     (%.16g, %.16g, %.16g)", pointA_0Z.x, pointA_0Z.y, pointA_0Z.z))

   local p_vectorOnPlane = vec3.rotate(pointA_0Z, math.rad(planeAngle), pA_0)
   log.debug(string.format("p_vectorOnPlane     (%.16g, %.16g, %.16g)", p_vectorOnPlane.x, p_vectorOnPlane.y,
      p_vectorOnPlane.z))

   local vectorOnPlane = vec3.new(
      p_vectorOnPlane.x - pA_0.x,
      p_vectorOnPlane.y - pA_0.y,
      p_vectorOnPlane.z - pA_0.z)
   local vectorOnPlane_unit = vec3.normalize(vectorOnPlane)
   log.debug(string.format("vectorOnPlane_unit     (%.16g, %.16g, %.16g)",
      vectorOnPlane_unit.x, vectorOnPlane_unit.y, vectorOnPlane_unit.z))

   -- The length of the vector must be equal to the radius of the sphere (pA_0 length).
   -- We resize the vector, because the player can place the object anywhere in the game.
   -- The object will not necessarily be placed correctly on the planet.
   local unit = vec3.normalize(p_actor)
   p_actor = vec3.new(unit.x * r_0, unit.y * r_0, unit.z * r_0)
   log.debug(string.format("p_actor     (%.16g, %.16g, %.16g)", p_actor.x, p_actor.y, p_actor.z))

   -- The vectors pA_0 and userVector are coplanar.
   -- The vector userVector determines the plane position and rotation.
   -- The angle between pA_0 and 𝑢 = 90°.
   -- The angle between pA_0 and 𝑣 = 90°.
   -- The angle between 𝑢 and 𝑣 = 90°.

   -- cross product (or vector product)
   local u = vec3.cross(pA_0, vectorOnPlane)
   local u_unit = vec3.normalize(u)

   local v = vec3.cross(pA_0, u)
   local v_unit = vec3.normalize(v)

   U_UNIT = u_unit
   V_UNIT = v_unit

   local sign_0 = (u_unit.x * p_actor.x) + (u_unit.y * p_actor.y) + (u_unit.z * p_actor.z)
   sign_0 = sign_0 < 0 and -1 or 1
   local sign_1 = (v_unit.x * p_actor.x) + (v_unit.y * p_actor.y) + (v_unit.z * p_actor.z)
   sign_1 = sign_1 < 0 and 1 or -1 -- /!\ inverted sign

   --#region Circular arc 1 ORANGE (left/right)

   -- GeoGebra: projection (point)
   local projection = vec3.projectPointOnToPlane(p_actor, vec3.zero, u_unit)

   -- GeoGebra: α (angle)
   local angleAlpha = vec3.angle_to_safe(p_actor, projection) -- angle in radians

   -- GeoGebra: arc_α (arc circle)
   local arcLength_0 = r_0 * angleAlpha
   local roundedArcLength_0 = round(arcLength_0, arcLength)

   local n_number = math.tointeger(round2((roundedArcLength_0 / arcLength) * sign_0, 0) + custom_n_number)
   assert(n_number ~= nil)

   local theta_0 = arcLength / r_0

   -- pA_N means pA_(-)[0-9]. ex: pA_2, pA_-2, pA_15.
   local pA_N = n_number == 0 and pA_0 or vec3.rotate(pA_0, n_number * theta_0, v)

   local n_number_minus1 = n_number - 1 * sign_0
   local pA_N_minus_1 = n_number - 1 == 0 and pA_0 or vec3.rotate(pA_0, n_number_minus1 * theta_0, v)
   --#endregion

   --#region Circular arc 2 BLACK (down/up)
   local angleBeta = vec3.angle_to_safe(pA_0, projection)

   local projectionLength = vec3.len(projection)

   -- GeoGebra: arc_β (arc circle)
   local arcLength_1 = projectionLength * angleBeta
   local roundedArcLength_1 = round(arcLength_1, arcLength)

   local n_letter = math.tointeger(round2((roundedArcLength_1 / arcLength) * sign_1, 0) + custom_n_letter)
   assert(n_letter ~= nil)

   local r_N = r_0 * math.cos(n_number * theta_0)
   local theta_N = arcLength / r_N

   local r_N_minus1 = r_0 * math.cos(n_number_minus1 * theta_0)
   local theta_N_minus1 = arcLength / r_N_minus1

   --#endregion

   local newActorLocation = vec3.rotate(pA_N, n_letter * theta_N, u)

   local newActorLocation_minus1 = vec3.rotate(pA_N_minus_1, n_letter * theta_N_minus1, u_unit)
   local angle_minus1 = vec3.angle_to_safe(newActorLocation, newActorLocation_minus1)
   local arcLength_minus1 = angle_minus1 * r_0

   newActorLocation = vec3.new(
      newActorLocation.x + planetCenter.x,
      newActorLocation.y + planetCenter.y,
      newActorLocation.z + planetCenter.z)

   -- n_number is the number on the orange line
   log.debug(string.format("newActorLocation     (number=%s, letter=%s)     (%.16g, %.16g, %.16g)", n_number, n_letter,
      newActorLocation.x, newActorLocation.y, newActorLocation.z))
   log.debug(string.format("newActorLocation     {X = %s, Y = %s, Z = %s}",
      newActorLocation.x, newActorLocation.y, newActorLocation.z))

   local scale = math.tointeger(math.max(1, 10 ^ (math.floor(math.log(r_0, 10)) - 1)))
   log.debug("scale     1/" .. scale)

   local fmt = 'Execute({' ..
       '"pA_0 = Point({%.16g, %.16g, %.16g})",' ..
       '"p_actor = Point({%.16g, %.16g, %.16g})",' ..
       '"r_0 = %.16g",' ..
       '"arcLength = %.16g",' ..
       '"planeAngle = %.16g°",' ..
       '"diff_x = x(newActorLocation) - %.16g",' ..
       '"diff_y = y(newActorLocation) - %.16g",' ..
       '"diff_z = z(newActorLocation) - %.16g"' ..
       '})'
   local cmd = string.format(fmt,
      pA_0.x / scale, pA_0.y / scale, pA_0.z / scale,
      p_actor.x / scale, p_actor.y / scale, p_actor.z / scale,
      r_0 / scale,
      math.max(arcLength / scale, 1),
      planeAngle,
      newActorLocation.x / scale, newActorLocation.y / scale, newActorLocation.z / scale)

   log.debug("GeoGebra command:\n\n" .. cmd .. "\n\n")

   cmd = string.format(fmt,
      pA_0.x, pA_0.y, pA_0.z,
      p_actor.x, p_actor.y, p_actor.z,
      r_0,
      arcLength,
      planeAngle,
      newActorLocation.x, newActorLocation.y, newActorLocation.z)

   log.debug("GeoGebra command (original data):\n\n" .. cmd .. "\n\n")

   log.debug(string.format("Arc length between p%s_%s and p%s_%s: %.16g. Difference: %.16g.",
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


   log.debug(string.format("\n\n\nvec3.new(%.16g, %.16g, %.16g))\n\n\n", newActorLocation.x, newActorLocation.y,
      newActorLocation.z))


   return newActorLocation, u_unit
end

---@param actor AActor
---@param location vec3
---@param u_unit vec3
local function setNewRotation(actor, location, u_unit)
   ---@type FHitResult
   ---@diagnostic disable-next-line: missing-fields
   local hitResult = {} --- @type FHitResult

   -- fix rotation
   local rot = vec3.findLookAtRotation(location, getPlanetCenter())
   actor:K2_SetActorRotation(rot, false)
   actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 90, Yaw = 0 }, false, hitResult, false)

   local rightVector = actor:GetActorRightVector()
   local cos_angle = vec3.dot(u_unit, vec3.new(rightVector.X, rightVector.Y, rightVector.Z))
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
   if hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end
   log.debug(string.format("HitActor: %s\n", hitActor:GetFullName()))

   local actorLoc = hitActor:K2_GetActorLocation()
   local p_actor = vec3.new(actorLoc.X, actorLoc.Y, actorLoc.Z)

   local newLoc, u_unit = snapToGrid(actor_reference_location, p_actor, arc_length, plane_angle)

   if options.set_new_rotation then
      setNewRotation(hitActor, newLoc, u_unit)
   end

   if options.set_new_location then
      hitActor:K2_SetActorLocation({ X = newLoc.x, Y = newLoc.y, Z = newLoc.z }, false, sweepHitResult, false)
   end
end

local function initUV()
   -- Initialize U_UNIT and V_UNIT. Required for rotatePlayerTo[Black/Orange]Line functions.
   if actor_reference_location.x ~= nil and actor_reference_location.y ~= nil and actor_reference_location.z ~= nil and plane_angle ~= nil and arc_length ~= nil then
      snapToGrid(actor_reference_location, actor_reference_location, arc_length, plane_angle)
   end
end

local function rotatePlayerToBlackLine()
   if U_UNIT.x == V_UNIT.x and U_UNIT.y == V_UNIT.y and U_UNIT.z == V_UNIT.z then
      initUV()
   end

   local player = UEHelpers:GetPlayer()
   local playerLoc = player:K2_GetActorLocation()
   setNewRotation(player, vec3.new(playerLoc.X, playerLoc.Y, playerLoc.Z), U_UNIT)
   log.info("You look in the direction of the BLACK line.")
end

local function rotatePlayerToOrangeLine()
   if U_UNIT.x == V_UNIT.x and U_UNIT.y == V_UNIT.y and U_UNIT.z == V_UNIT.z then
      initUV()
   end

   local player = UEHelpers:GetPlayer()
   local playerLoc = player:K2_GetActorLocation()
   setNewRotation(player, vec3.new(playerLoc.X, playerLoc.Y, playerLoc.Z), V_UNIT)
   log.info("You look in the direction of the ORANGE line.")
end

if options.snap_on_drop then
   -- See also: RegisterHook("/Script/Astro.PhysicalItem:PlacementTransform", function(Self, Hit) end)
   RegisterHook("/Script/Astro.PhysicalItem:MulticastDroppedInWorld",
      function(self, Component, TerrainComponent, Point, Normal)
         local physicalItem = self:get() ---@diagnostic disable-line: undefined-field

         ---@cast physicalItem APhysicalItem

         local actorLoc = physicalItem:K2_GetActorLocation()
         local p_actor = vec3.new(actorLoc.X, actorLoc.Y, actorLoc.Z)

         local newLoc, u_unit = snapToGrid(actor_reference_location, p_actor, arc_length, plane_angle)

         if options.set_new_rotation then
            setNewRotation(physicalItem, newLoc, u_unit)
         end

         if options.set_new_location then
            Point:set(newLoc)
         end
      end)
end

local function selectActor()
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
   if hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end
   log.info(string.format("Select actor: %s\n",
      hitActor:GetFullName()))

   Selected.actor = hitActor

   -- ---@diagnostic disable-next-line: missing-fields
   -- Selected.actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = Selected.angle }, false, {}, false)

   -- ---@diagnostic disable-next-line: missing-fields
   -- Selected.actor:K2_AddActorLocalOffset({ X = 0, Y = 0, Z = Selected.upOffset }, false, {}, false)

   -- log.info("Add rotation     %.16g°", Selected.angle)
   --  log.info("Add up/down offset     %.16g", Selected.upOffset)

   Selected.angle = 0
   Selected.upOffset = 0
end

local function selectActorAndApplyLastOffsetAndRotation()
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
   if hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end
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

local function resetLocalOffsetAndRotation()
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
   local actorLoc = Selected.actor:K2_GetActorLocation()
   local p_actor = vec3.new(actorLoc.X, actorLoc.Y, actorLoc.Z)

   local newLoc, u_unit = snapToGrid(actor_reference_location, p_actor, arc_length, plane_angle, n_letter, n_number)

   if options.set_new_rotation then
      setNewRotation(Selected.actor, newLoc, u_unit)
   end

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_SetActorLocation({ X = newLoc.x, Y = newLoc.y, Z = newLoc.z }, false, {}, false)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = Selected.angle }, false, {}, false)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalOffset({ X = 0, Y = 0, Z = Selected.upOffset }, false, {}, false)

   log.info("Add rotation     %.16g°", Selected.angle)
   log.info("Add up/down offset     %.16g", Selected.upOffset)
end

local function moveActorUpDown(offset)
   Selected.upOffset = Selected.upOffset + offset
   log.info("Up/down offset     %.16g", Selected.upOffset)

   ---@diagnostic disable-next-line: missing-fields
   Selected.actor:K2_AddActorLocalOffset({ X = 0, Y = 0, Z = offset }, false, {}, false)
end

local function rotateActor(angle)
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

local function registerKeyBind(key, modifierKeys, callback)
   if key ~= nil then
      if IsKeyBindRegistered(key, modifierKeys or {}) then
         error("Key bind is already registered.")
      end

      if modifierKeys ~= nil and type(modifierKeys) == "table" and #modifierKeys > 0 then
         RegisterKeyBind(key, modifierKeys, callback)
      else
         RegisterKeyBind(key, callback)
      end
   end
end

registerKeyBind(options.resetLocalOffsetAndRotation_Key,
   options.resetLocalOffsetAndRotation_ModifierKeys,
   resetLocalOffsetAndRotation)

--#region moveSelectedActor
registerKeyBind(options.move.selectActor_Key,
   options.move.selectActor_ModifierKeys,
   selectActor)

registerKeyBind(options.move.selectActorAndApplyLast_Key,
   options.move.selectActorAndApplyLast_ModifierKeys,
   selectActorAndApplyLastOffsetAndRotation)

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
--#endregion

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
--#endregion

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
--#endregion

--#endregion

--#region rotateSelectedActor

--#region normal rotate
registerKeyBind(options.rotate.clockwise_Key,
   options.rotate.clockwise_ModifierKeys,
   rotateSelectedActorClockwise)

registerKeyBind(options.rotate.counterclockwise_Key,
   options.rotate.counterclockwise_ModifierKeys,
   rotateSelectedActorCounterclockwise)
--#endregion

--#region big rotate
registerKeyBind(options.rotate.clockwise_big_Key,
   options.rotate.clockwise_big_ModifierKeys,
   rotateSelectedActorClockwise_big)

registerKeyBind(options.rotate.counterclockwise_big_Key,
   options.rotate.counterclockwise_big_ModifierKeys,
   rotateSelectedActorCounterclockwise_big)
--#endregion

--#region very big rotate
registerKeyBind(options.rotate.clockwise_very_big_Key,
   options.rotate.clockwise_very_big_ModifierKeys,
   rotateSelectedActorClockwise_very_big)

registerKeyBind(options.rotate.counterclockwise_very_big_Key,
   options.rotate.counterclockwise_very_big_ModifierKeys,
   rotateSelectedActorCounterclockwise_very_big)
--#endregion

--#endregion

registerKeyBind(options.snapActorToGrid_Key,
   options.snapActorToGrid_ModifierKeys,
   snapActorToGrid)

registerKeyBind(options.setActorReferenceLocation_Key,
   options.setActorReferenceLocation_ModifierKeys,
   setActorReferenceLocation)

registerKeyBind(options.rotatePlayerToBlackLine_Key,
   options.rotatePlayerToBlackLine_ModifierKeys,
   rotatePlayerToBlackLine)

registerKeyBind(options.rotatePlayerToOrangeLine_Key,
   options.rotatePlayerToOrangeLine_ModifierKeys,
   rotatePlayerToOrangeLine)

--#region console commands

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("angle", function(fullCommand, parameters, outputDevice)
   local helpMsg =
       "Usage: angle <angle in degrees (0 to 360)>\n" ..
       "Example: angle 90\n" ..
       "Current angle: " .. plane_angle

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

   plane_angle = angle
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
          actor_reference_location.x, actor_reference_location.y, actor_reference_location.z)

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

   actor_reference_location = vec3.new(x, y, z)
   outputDevice:Log(string.format("New actor reference location: %.16g %.16g %.16g",
      actor_reference_location.x, actor_reference_location.y, actor_reference_location.z))

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
   if hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end
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
      newLocation.x, newLocation.y, newLocation.z)
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
       "Current arc length: " .. arc_length

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

   arc_length = arc
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
   if hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end

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
   if hitActor:IsA("/Script/Astro.SolarBody") then
      return
   end

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
      actor_reference_location.x, actor_reference_location.y, actor_reference_location.z,
      arc_length,
      plane_angle,
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

--#endregion console commands

-- Uncomment to run tests.
-- log.setLevel("WARN", "WARN")
-- SnapToGrid = snapToGrid
-- dofile(currentModDirectory .. "\\Scripts\\tests.lua")
-- log.setLevel("INFO", "WARN")
