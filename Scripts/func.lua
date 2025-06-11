---@diagnostic disable: lowercase-global

local UEHelpers = require("UEHelpers")
modules = "Scripts.lib.LEEF-math.modules." ---@diagnostic disable-line: lowercase-global
local vec3 = require("Scripts.lib.LEEF-math.modules.vec3")

---@param filename string
---@return boolean
function isFileExists(filename)
    local file = io.open(filename, "r")
    if file ~= nil then
        io.close(file)
        return true
    else
        return false
    end
end

function getParamsFile()
    local currentDirectory = debug.getinfo(2, "S").source:gsub("\\", "/"):match("@?(.+/[Ss]cripts/methods/[^/]+)")
    local file = currentDirectory .. "\\params.lua"

    if not isFileExists(file) then
        local cmd = string.format([[copy "%s\params.example.lua" "%s\params.lua"]],
            currentDirectory,
            currentDirectory)

        print("Copy example params to params.lua. Execute command: " .. cmd .. "\n")

        os.execute(cmd)
    end

    return file
end

---@param paramsFile? string
---@return table
---@return string
function loadParamsFile(paramsFile)
    paramsFile = paramsFile or getParamsFile()
    local params = dofile(paramsFile)
    assert(type(params) == "table", string.format("\nInvalid parameters file: %q.", paramsFile))

    local i, str = 0, ""
    for key, value in pairs(params) do
        str = str .. string.format("%s=%s\n", key, value)
        i = i + 1
    end

    if i > 0 then
        print(string.format("Loaded params (%d): \n%s", i, str))
    else
        print(string.format("WARN: No parameters were loaded from the file %q.", paramsFile))
    end

    return params, paramsFile
end

---@param key Key
---@param modifierKeys? ModifierKey[]
function getKeybindName(key, modifierKeys)
    local modifierKeysList = ""

    if type(modifierKeys) == "table" then
        for _, keyValue in ipairs(modifierKeys) do
            for k, v in pairs(ModifierKey) do
                if keyValue == v then
                    modifierKeysList = modifierKeysList .. k .. "+"
                end
            end
        end
    end

    for k, v in pairs(Key) do
        if key == v then
            return modifierKeysList .. k
        end
    end

    return ""
end

function round2(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 4)
    return math.floor(num * mult + 0.5) / mult
end

---Get nearest multiple of base.
---@param num number
---@param base number
---@return number
function roundToBase(num, base)
    return math.floor(num / base + 0.5) * base
end

---Normalize angle between -180 and 180.
---@param a number Angle in degrees.
---@return number
function normalizeAngle(a)
    a = a % 360
    local b = 0
    if a <= 180 then
        b = a
    else
        b = a - 360
    end

    return b
end

---@return vec3
function getPlanetCenter()
    local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
    local homeBody = playerController.HomeBody   -- 0xC98
    local rootComponent = homeBody.RootComponent -- 0x160

    local loc = rootComponent.RelativeLocation
    return vec3.new(loc.X, loc.Y, loc.Z)
end

function GetActorFromHitResult(HitResult)
    if UnrealVersion:IsBelow(5, 0) then
        return HitResult.Actor:Get()
    elseif UnrealVersion:IsBelow(5, 4) then
        return HitResult.HitObjectHandle.Actor:Get()
    else
        return HitResult.HitObjectHandle.ReferenceObject:Get()
    end
end

---@param actor AActor
---@param location vec3
---@param planetCenter vec3
function fixRotation(actor, location, planetCenter)
    local rot = vec3.findLookAtRotation(location, planetCenter)
    actor:K2_SetActorRotation(rot, true) -- teleportPhysics = true <= seems important to avoid bug with cursor
    ---@diagnostic disable-next-line: missing-fields
    actor:K2_AddActorLocalRotation({ Roll = 0, Pitch = 90, Yaw = 0 }, false, {}, false)
end

function rotatePlayerTo(direction)
    local player = UEHelpers:GetPlayer()
    local playerLoc = player:K2_GetActorLocation()

    fixRotation(player, vec3.new(playerLoc.X, playerLoc.Y, playerLoc.Z), getPlanetCenter())

    local rightVector = player:GetActorRightVector()
    local cos_angle = vec3.dot(direction, vec3.new(rightVector.X, rightVector.Y, rightVector.Z))
    local angle = math.deg(math.acos(cos_angle))
    player:K2_AddActorLocalRotation({ Roll = 0, Pitch = 0, Yaw = angle }, false, {}, false) ---@diagnostic disable-line: missing-fields
end

---https://stackoverflow.com/a/3554821
---@param n number
---@param b number
---@return string
function base(n, b)
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
