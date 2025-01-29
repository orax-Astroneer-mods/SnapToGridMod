local vec3 = require("lib.LEEF-math.modules.vec3")

---@param v vec3
---@param v_expected vec3
local function testVectorsEquality(v, v_expected)
    local x, x_expected = string.format("%.16g", v.x), string.format("%.16g", v_expected.x)
    local y, y_expected = string.format("%.16g", v.z), string.format("%.16g", v_expected.z)
    local z, z_expected = string.format("%.16g", v.z), string.format("%.16g", v_expected.z)

    assert(x == x_expected, string.format("x=%s     expected=%s", x, x_expected))
    assert(y == y_expected, string.format("z=%s     expected=%s", y, z_expected))
    assert(z == z_expected, string.format("z=%s     expected=%s", z, z_expected))
end

local function doTests()
    local originLoc = vec3.new(4.171236016214089, -2.638007398631546, -0.801066203134074)

    testVectorsEquality(
        SnapToGrid(originLoc, vec3.new(-0.638367766645711, 2.236192370531383, 4.426277248036436), 1.65,
            0),
        vec3.new(-0.5468981747921451, 2.262914605417948, 4.42494292336016))

    testVectorsEquality(
        SnapToGrid(originLoc, vec3.new(-0.638367766645711, 2.236192370531383, 4.426277248036436), 1.65,
            180),
        vec3.new(-0.5468981747921452, 2.262914605417949, 4.42494292336016))

    testVectorsEquality(
        SnapToGrid(originLoc, vec3.new(-0.638367766645711, 2.236192370531383, 4.426277248036436), 1.65,
            360),
        vec3.new(-0.5468981747921451, 2.262914605417948, 4.42494292336016))

    testVectorsEquality(
        SnapToGrid(originLoc, vec3.new(-0.638367766645711, 2.236192370531383, 4.426277248036436), 1.65,
            40),
        vec3.new(-0.2808499600127707, 3.686777863754219, 3.365827132116666))

    testVectorsEquality(
        SnapToGrid(originLoc, vec3.new(3.822901723714558, 2.600836010452138, 1.902912099271975), 2,
            75),
        vec3.new(3.686054233267249, 2.398363251820293, 2.379255745339409))

    testVectorsEquality(
        SnapToGrid(originLoc, vec3.new(0.577454978090593, 3.557974949321559, 3.465163777987794), 0.001,
            1),
        vec3.new(0.5773689727578781, 3.557711803279051, 3.465448281839661))

    originLoc = vec3.new(4.171236016214089, -2.638007398631546, -0.801066203134074)
    testVectorsEquality(
        SnapToGrid(originLoc, vec3.new(4.610936652954811, 1.153150831377694, 1.552258465118106), 100,
            4.789),
        vec3.new(4.171236016214089, -2.638007398631546, -0.801066203134074))

    testVectorsEquality(
        SnapToGrid(originLoc, vec3.new(4.108444020581478, 1.385417188004814, -2.490242346625952), 123.456,
            278.789),
        vec3.new(4.171236016214089, -2.638007398631546, -0.801066203134074))
end

doTests()
