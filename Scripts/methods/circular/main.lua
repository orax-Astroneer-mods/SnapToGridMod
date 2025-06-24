local UEHelpers = require("UEHelpers")
require("func")

--#region Initialization

local log = Log
local vec3 = Vec3

-- load PARAMS global table
local paramsFile = getParamsFile()
PARAMS = loadParamsFile(paramsFile)

--#endregion

---@param pA_0 vec3
---@param p_actor vec3 Actor location.
---@param actor? AActor
---@param custom_n_letter? integer
---@param custom_n_number? integer
---@param extra? any
---@return vec3
local function snapToGrid(pA_0, p_actor, actor, custom_n_letter, custom_n_number, extra)
    local arcLength = PARAMS.ARC_LENGTH ---@type number
    local longitudeAngle = PARAMS.LONGITUDE_ANGLE ---@type number

    local p_A_0_forward = PARAMS.ACTOR_REF_FORWARD

    if pA_0 == nil or p_A_0_forward == nil then
        error(string.format("\n" ..
            [[You must define an "actor reference location" and an "actor reference forward" (place the cursor on an object and press %s).]],
            getKeybindName(OPTIONS.setActorReferenceLocation_Key, OPTIONS.setActorReferenceLocation_ModifierKeys)))
    end
    assert(type(arcLength) == "number", "\narcLength is not a number.")
    assert(arcLength ~= 0, "\narcLength cannot be equal to 0.")
    assert(type(longitudeAngle) == "number", "\nlongitudeAngle is not a number.")

    custom_n_letter = custom_n_letter or 0
    custom_n_number = custom_n_number or 0
    -- We invert custom_n_letter to rotate clockwise with 6 and counterclockwise with 4.
    custom_n_letter = -custom_n_letter

    local planetCenter = getPlanetCenter()
    log.debug(string.format("planetCenter     (%.16g, %.16g, %.16g)", planetCenter.x, planetCenter.y, planetCenter.z))

    p_actor = vec3.new(
        p_actor.x - planetCenter.x,
        p_actor.y - planetCenter.y,
        p_actor.z - planetCenter.z)

    local r_0 = vec3.len(pA_0)

    local u = vec3.normalize(vec3.cross(pA_0, p_A_0_forward))
    local v = vec3.normalize(vec3.cross(pA_0, u))
    local w = vec3.new(-v.x, -v.y, -v.z)

    local u_unit = vec3.normalize(u)
    local v_unit = vec3.normalize(v)
    local w_unit = vec3.normalize(w)

    U_UNIT = u_unit
    V_UNIT = v_unit

    local sign = (u_unit.x * p_actor.x) + (u_unit.y * p_actor.y) + (u_unit.z * p_actor.z)
    sign = sign < 0 and -1 or 1

    local sign_w = (w_unit.x * p_actor.x) + (w_unit.y * p_actor.y) + (w_unit.z * p_actor.z)
    sign_w = sign_w < 0 and -1 or 1

    local cosAB = vec3.dot(vec3.normalize(pA_0), vec3.normalize(p_A_0_forward))
    local cosAC = vec3.dot(vec3.normalize(pA_0), vec3.normalize(p_actor))
    local cosBC = vec3.dot(vec3.normalize(p_A_0_forward), vec3.normalize(p_actor))
    cosAB = math.max(-1, math.min(1, cosAB))
    cosAC = math.max(-1, math.min(1, cosAC))
    cosBC = math.max(-1, math.min(1, cosBC))

    local angle = vec3.angle_to_safe(pA_0, p_actor)

    local lonArcLength = r_0 * angle
    local roundedLonArcLength = roundToBase(lonArcLength, arcLength) * sign_w

    local n_number = math.tointeger(round2((roundedLonArcLength / arcLength), 0) + custom_n_number)
    assert(n_number ~= nil)
    n_number = n_number * sign_w

    roundedLonArcLength = arcLength * n_number
    local newLatAngle = (roundedLonArcLength / r_0)

    -- n_number
    local newActorLocation = vec3.rotate(pA_0, newLatAngle, u)

    local cosBAC = (cosBC - cosAB * cosAC) / (math.sin(math.acos(cosAB)) * math.sin(math.acos(cosAC)))
    cosBAC = math.max(-1, math.min(1, cosBAC))

    local roundedAngle = normalizeAngle(roundToBase(math.deg(math.acos(cosBAC)), longitudeAngle))

    local n_letter = math.tointeger(round2((roundedAngle / longitudeAngle) * sign, 0) + custom_n_letter)
    assert(n_letter ~= nil)
    local newAngle = normalizeAngle(longitudeAngle * n_letter)
    n_letter = math.tointeger(round2((newAngle / longitudeAngle), 0)) -- fix n_letter
    assert(n_letter ~= nil)

    newActorLocation = vec3.rotate(newActorLocation, math.rad(newAngle), pA_0)

    newActorLocation = vec3.new(
        newActorLocation.x + planetCenter.x,
        newActorLocation.y + planetCenter.y,
        newActorLocation.z + planetCenter.z)

    log.info(string.format("Point %s %s     letter=%s number=%s",
        base(n_letter, 26), n_number, n_letter, n_number))

    -- set rotation
    if OPTIONS.set_new_rotation == true and actor then
        fixRotation(actor, newActorLocation, planetCenter)

        actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = newAngle }, false, {}, false) ---@diagnostic disable-line: missing-fields

        if PARAMS.ROTATION_ANGLE then
            actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = PARAMS.ROTATION_ANGLE }, false, {}, false) ---@diagnostic disable-line: missing-fields
        end
    end

    return newActorLocation
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

    local line2 = ""
    if PARAMS.ACTOR_REF_FORWARD == nil then
        line2 = "ACTOR_REF_FORWARD=nil,"
    else
        line2 = string.format("ACTOR_REF_FORWARD=Vec3.new(%.16g,%.16g,%.16g),",
            PARAMS.ACTOR_REF_FORWARD.x, PARAMS.ACTOR_REF_FORWARD.y, PARAMS.ACTOR_REF_FORWARD.z)
    end

    -- defaults
    if PARAMS.ARC_LENGTH == nil then PARAMS.ARC_LENGTH = 500 end
    if PARAMS.LONGITUDE_ANGLE == nil then PARAMS.LONGITUDE_ANGLE = 10 end
    if PARAMS.ROTATION_ANGLE == nil then PARAMS.ROTATION_ANGLE = 0 end

    file:write(string.format(
        [[return {
%s
%s
ARC_LENGTH=%.16g,
LONGITUDE_ANGLE=%.16g,
ROTATION_ANGLE=%.16g
}]],
        line1,
        line2,
        PARAMS.ARC_LENGTH,
        PARAMS.LONGITUDE_ANGLE,
        PARAMS.ROTATION_ANGLE))

    file:close()
end

---@param actor AActor
---@param hitResult FHitResult
local function onSetActorReference(actor, hitResult)
    local forward = actor:GetActorForwardVector()
    PARAMS.ACTOR_REF_FORWARD = vec3.new(forward.X, forward.Y, forward.Z)
end

return {
    snapToGrid = snapToGrid,
    writeParamsFile = writeParamsFile,
    onSetActorReference = onSetActorReference,
}
