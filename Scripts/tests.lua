local function round2(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 4)
    return math.floor(num * mult + 0.5) / mult
end

---@param v1 FVector
---@param v2 FVector
local function testVectorsEquality(v1, v2)
    local d = 13
    assert(round2(v1.X, d) == round2(v2.X, d))
    assert(round2(v1.Y, d) == round2(v2.Y, d))
    assert(round2(v1.Z, d) == round2(v2.Z, d))
end

local function doTests()
    local originLoc = { X = 4.171236016214089, Y = -2.638007398631546, Z = -0.801066203134074 }

    testVectorsEquality(
        SnapToGrid(originLoc, { X = -0.638367766645711, Y = 2.236192370531383, Z = 4.426277248036436 }, 1.65,
            0),
        { X = -0.54689800739288, Y = 2.2629141807556, Z = 4.4249429702759 })

    testVectorsEquality(
        SnapToGrid(originLoc, { X = -0.638367766645711, Y = 2.236192370531383, Z = 4.426277248036436 }, 1.65,
            180),
        { X = -0.54689848423004, Y = 2.2629132270813, Z = 4.4249429702759 })

    testVectorsEquality(
        SnapToGrid(originLoc, { X = -0.638367766645711, Y = 2.236192370531383, Z = 4.426277248036436 }, 1.65,
            360),
        { X = -0.54689800739288, Y = 2.2629141807556, Z = 4.4249429702759 })

    testVectorsEquality(
        SnapToGrid(originLoc, { X = -0.638367766645711, Y = 2.236192370531383, Z = 4.426277248036436 }, 1.65,
            40),
        { X = -0.28085052967072, Y = 3.6867775917053, Z = 3.3658275604248 })

    testVectorsEquality(
        SnapToGrid(originLoc, { X = 3.822901723714558, Y = 2.600836010452138, Z = 1.902912099271975 }, 2,
            75),
        { X = 3.6860539913177, Y = 2.3983626365662, Z = 2.379255771637 })

    testVectorsEquality(
        SnapToGrid(originLoc, { X = 0.577454978090593, Y = 3.557974949321559, Z = 3.465163777987794 }, 0.001,
            1),
        { X = 0.57736885547638, Y = 3.5577104091644, Z = 3.4654488563538 })

    originLoc = { X = 4.171236016214089, Y = -2.638007398631546, Z = -0.801066203134074 }
    testVectorsEquality(
        SnapToGrid(originLoc, { X = 4.610936652954811, Y = 1.153150831377694, Z = 1.552258465118106 }, 100,
            4.789),
        { X = 4.171236038208, Y = -2.63800740242, Z = -0.80106621980667 })

    testVectorsEquality(
        SnapToGrid(originLoc, { X = 4.108444020581478, Y = 1.385417188004814, Z = -2.490242346625952 }, 123.456,
            278.789),
        { X = 4.171236038208, Y = -2.63800740242, Z = -0.80106621980667 })
end

doTests()
