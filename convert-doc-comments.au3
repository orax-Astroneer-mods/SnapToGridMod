#cs
	This AutoIt script converts some annotations in vec3.lua to annotations for Lua Language Server. https://luals.github.io/
	Result copied in clipboard.
#ce

Local $f = FileRead(@ScriptDir & "\Scripts\lib\LEEF-math\modules\vec3.lua")

$f = StringRegExpReplace($f, "(?m)^-- @tparam (\w+) (\w+)( .+)?", "---@param $2 $1$3")
$f = StringRegExpReplace($f, "(?m)^-- @treturn (\w+) (\w+)( .+)?", "---@return $1 $2$3")

Local $str = _
		"---@class vec3" & @LF & _
		"---@field x number" & @LF & _
		"---@field y number" & @LF & _
		"---@field z number" & @LF & @LF
$f = $str & $f
ClipPut($f)
