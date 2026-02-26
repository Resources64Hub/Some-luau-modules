local Selection = game:GetService("Selection")

local toolbar = plugin:CreateToolbar("Sequence2Lua | by @Shlakiii")
local button = toolbar:CreateButton("Export to Module", "Convert KeyframeSequence to Lua by @Shlakiii", "rbxassetid://15132641040")

local function formatCF(cf)
	local components = {cf:GetComponents()}
	return "CFrame.new(" .. table.concat(components, ", ") .. ")"
end

local function parseToLua(ks)
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)

	local str = "return {\n"
	str ..= "\tName = \"" .. ks.Name .. "\",\n"
	str ..= "\tLoop = " .. tostring(ks.Loop) .. ",\n"
	str ..= "\tKeyframes = {\n"

	-- Пустой CFrame для сравнения
	local emptyCF = CFrame.new()

	for _, kf in ipairs(kfs) do
		str ..= "\t\t{\n"
		str ..= "\t\t\tTime = " .. kf.Time .. ",\n"
		str ..= "\t\t\tPoses = {\n"

		local function collect(pose)
			-- ПРОВЕРКА: Если это Torso или Root и оно пустое - пропускаем запись
			local isRoot = (pose.Name == "Torso" or pose.Name == "HumanoidRootPart" or pose.Name == "RootJoint")
			local isEmpty = (pose.CFrame == emptyCF)

			if not (isRoot and isEmpty) then
				str ..= "\t\t\t\t[\"" .. pose.Name .. "\"] = " .. formatCF(pose.CFrame) .. ",\n"
			end

			for _, sub in ipairs(pose:GetSubPoses()) do collect(sub) end
		end

		for _, pose in ipairs(kf:GetPoses()) do 
			collect(pose) 
		end

		str ..= "\t\t\t}\n\t\t},\n"
	end

	str ..= "\t}\n}"
	return str
end

button.Click:Connect(function()
	local selected = Selection:Get()
	for _, obj in ipairs(selected) do
		if obj:IsA("KeyframeSequence") then
			local module = Instance.new("ModuleScript")
			module.Name = obj.Name .. "_Data"
			module.Source = parseToLua(obj)
			module.Parent = obj.Parent
			print("✅ Exported: " .. obj.Name .. " (Torso fix applied)")
		else
			warn("⚠️ Select KeyframeSequence!")
		end
	end
end)
