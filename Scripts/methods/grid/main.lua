local UEHelpers = require("UEHelpers")
require("func")

--#region Initialization

local log = Log
local vec3 = Vec3

-- load PARAMS global table
local paramsFile = getParamsFile()
PARAMS = loadParamsFile(paramsFile)

--#endregion

---@param point vec3
---@param planeBase vec3
---@param planeNormal_unit vec3 Vector must be normalized (length = 1).
---@return vec3
function vec3.projectPointOnToPlane(point, planeBase, planeNormal_unit)
    --- https://dev.epicgames.com/documentation/en-us/unreal-engine/BlueprintAPI/Math/Vector/ProjectPointontoPlane
    --- https://fr.mathworks.com/matlabcentral/answers/183464-how-do-i-find-the-orthogonal-projection-of-a-point-onto-a-plane#answer_394659
    return point - vec3.scale(planeNormal_unit, vec3.dot(point - planeBase, planeNormal_unit))
end

---@param pA_0 vec3
---@param p_actor vec3 Actor location.
---@param actor? AActor
---@param custom_n_letter? integer
---@param custom_n_number? integer
---@param extra? any
---@return vec3
local function snapToGrid(pA_0, p_actor, actor, custom_n_letter, custom_n_number, extra)
    local arcLength = PARAMS.ARC_LENGTH ---@type number

    if pA_0 == nil then
        error("\n" .. [[You must define an "actor reference location" (place the cursor on an object and press F5).]])
    end
    assert(type(arcLength) == "number", "\narcLength is not a number.")
    assert(arcLength ~= 0, "\narcLength cannot be equal to 0.")

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

    local p_vectorOnPlane = vec3.rotate(pointA_0Z, math.rad(PARAMS.ANGLE), pA_0)
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

    if extra and extra.getUVOnly then
        return vec3.zero
    end

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
    local roundedArcLength_0 = roundToBase(arcLength_0, arcLength)

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
    local roundedArcLength_1 = roundToBase(arcLength_1, arcLength)

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
        PARAMS.ANGLE,
        newActorLocation.x / scale, newActorLocation.y / scale, newActorLocation.z / scale)

    log.debug("GeoGebra command:\n\n" .. cmd .. "\n\n")

    cmd = string.format(fmt,
        pA_0.x, pA_0.y, pA_0.z,
        p_actor.x, p_actor.y, p_actor.z,
        r_0,
        arcLength,
        PARAMS.ANGLE,
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
   --]] --
    log.info(string.format("Point %s %s     letter=%s number=%s",
        base(n_letter, 26), n_number, n_letter, n_number))


    log.debug(string.format("\n\n\nvec3.new(%.16g, %.16g, %.16g))\n\n\n", newActorLocation.x, newActorLocation.y,
        newActorLocation.z))

    -- set rotation
    if OPTIONS.set_new_rotation == true and actor then
        fixRotation(actor, newActorLocation, planetCenter)

        local rightVector = actor:GetActorRightVector()
        local cos_angle = vec3.dot(u_unit, vec3.new(rightVector.X, rightVector.Y, rightVector.Z))
        local angle = math.deg(math.acos(cos_angle))
        actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = angle }, false, {}, false) ---@diagnostic disable-line: missing-fields

        if PARAMS.ROTATION_ANGLE then
            actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = PARAMS.ROTATION_ANGLE }, false, {}, false) ---@diagnostic disable-line: missing-fields
        end
    end

    return newActorLocation
end

local function initUV()
    -- Initialize U_UNIT and V_UNIT. Required for rotatePlayerTo[Black/Orange]Line functions.
    if PARAMS.ACTOR_REF_LOC ~= nil and PARAMS.ANGLE ~= nil and PARAMS.ARC_LENGTH ~= nil then
        snapToGrid(PARAMS.ACTOR_REF_LOC, PARAMS.ACTOR_REF_LOC, nil, nil, nil, { getUVOnly = true })
    end
end

local function getDirectionToBlackLine()
    if U_UNIT.x == V_UNIT.x and U_UNIT.y == V_UNIT.y and U_UNIT.z == V_UNIT.z then
        initUV()
    end

    log.info("You look in the direction of the BLACK line.")

    return V_UNIT
end

local function getDirectionToOrangeLine()
    if U_UNIT.x == V_UNIT.x and U_UNIT.y == V_UNIT.y and U_UNIT.z == V_UNIT.z then
        initUV()
    end

    log.info("You look in the direction of the ORANGE line.")

    return U_UNIT
end

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, string.format("\nUnable to open the params file %q.", paramsFile))

    local line1 = ""
    if PARAMS.ACTOR_REF_LOC == nil then
        line1 = "ACTOR_REF_LOC=nil,"
    else
        line1 = string.format("ACTOR_REF_LOC=Vec3.new(%.16g,%.16g,%.16g),",
            PARAMS.ACTOR_REF_LOC.x, PARAMS.ACTOR_REF_LOC.y, PARAMS.ACTOR_REF_LOC.z)
    end

    -- defaults
    if PARAMS.ARC_LENGTH == nil then PARAMS.ARC_LENGTH = 500 end
    if PARAMS.ANGLE == nil then PARAMS.ANGLE = 90 end
    if PARAMS.ROTATION_ANGLE == nil then PARAMS.ROTATION_ANGLE = 0 end

    file:write(string.format(
        [[return {
%s
ARC_LENGTH=%.16g,
ANGLE=%.16g,
ROTATION_ANGLE=%.16g
}]],
        line1,
        PARAMS.ARC_LENGTH,
        PARAMS.ANGLE,
        PARAMS.ROTATION_ANGLE))

    file:close()
end

-- Uncomment to run tests. Load a game and restart mods.
-- local currentModDirectory = debug.getinfo(1, "S").source:match("@?(.+\\methods\\[^\\]+)")
-- log.setLevel("WARN", "WARN")
-- SnapToGrid = snapToGrid
-- dofile(currentModDirectory .. "\\tests.lua")
-- log.setLevel("INFO", "WARN")

return {
    snapToGrid = snapToGrid,
    writeParamsFile = writeParamsFile,
    getDirection1 = getDirectionToBlackLine,
    getDirection2 = getDirectionToOrangeLine,
}
