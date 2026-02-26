local AnimationParser = {}
local _cache = {}

local function flattenPoses(pose, flatTable)
	flatTable[pose.Name] = pose.CFrame
	for _, subPose in ipairs(pose:GetSubPoses()) do
		flattenPoses(subPose, flatTable)
	end
end

function AnimationParser.get(ks)
	if _cache[ks] then return _cache[ks] end

	local animData = {
		Name = ks.Name,
		Loop = ks.Loop,
		Keyframes = {}
	}

	for _, kf in ipairs(ks:GetKeyframes()) do
		local kfData = {
			Time = kf.Time,
			Poses = {}
		}
		for _, pose in ipairs(kf:GetPoses()) do
			flattenPoses(pose, kfData.Poses)
		end
		table.insert(animData.Keyframes, kfData)
	end

	table.sort(animData.Keyframes, function(a, b) return a.Time < b.Time end)
	_cache[ks] = animData
	return animData
end

return AnimationParser
