local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimationPlayer = {}
local activeTracks = {} 
local defaultC0Cache = {} -- [motor] = CFrame
local lastTrackPoses = {} -- [track] = { [partName] = CFrame }

local function getRigSetup(rig)
	local motors = {}
	for _, motor in ipairs(rig:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Part1 then
			if not defaultC0Cache[motor] then
				defaultC0Cache[motor] = motor.C0
			end
			motors[motor.Part1.Name] = motor
		end
	end
	return motors
end

RunService.Stepped:Connect(function(dt)
	for rig, tracks in pairs(activeTracks) do
		local motors = getRigSetup(rig)
		local finalTransforms = {} 
		local activeCount = 0

		for i = #tracks, 1, -1 do
			local track = tracks[i]

			if not track.IsPlaying and track.Weight <= 0.0001 then 
				lastTrackPoses[track] = nil
				table.remove(tracks, i)
				continue 
			end

			activeCount += 1
			local currentKf, nextKf = track:_getActiveKeyframes()
			if not currentKf or not nextKf then continue end

			local duration = nextKf.Time - currentKf.Time
			local alpha = (duration > 0) and math.clamp((track.Time - currentKf.Time) / duration, 0, 1) or 1
			local trackWeight = math.max(track.Weight, 0.0001)

			if not lastTrackPoses[track] then lastTrackPoses[track] = {} end

			for partName, motor in pairs(motors) do
				if track.Mask and not track.Mask[partName] then continue end

				local startCf = currentKf.Poses[partName]
				local endCf = nextKf.Poses[partName]
				local finalPoseForTrack

				if startCf and endCf then
					finalPoseForTrack = startCf:Lerp(endCf, alpha)
					lastTrackPoses[track][partName] = finalPoseForTrack
				else
					finalPoseForTrack = lastTrackPoses[track][partName] or CFrame.identity
				end

				if not finalTransforms[motor] then
					finalTransforms[motor] = {cf = CFrame.identity, weightSum = 0}
				end

				local data = finalTransforms[motor]
				data.cf = data.cf:Lerp(finalPoseForTrack, trackWeight / (data.weightSum + trackWeight))
				data.weightSum += trackWeight
			end
		end

		if activeCount > 0 then
			for motor, data in pairs(finalTransforms) do
				local success = pcall(function()
					local weight = math.clamp(data.weightSum, 0, 1)
					local finalCf = CFrame.identity:Lerp(data.cf, weight)

					motor.Transform = motor.Transform * finalCf
				end)
			end
		else
			activeTracks[rig] = nil
		end
	end
end)

function AnimationPlayer.play(rig, animTable, fadeTime, mask)
	if not rig or not animTable then return nil end
	fadeTime = fadeTime or 0.25

	local endedEvent = Instance.new("BindableEvent")

	local track = {
		Loop = animTable.Loop or false,
		Speed = 1,
		Weight = 0,
		Time = 0,
		IsPlaying = true,
		IsPaused = false,
		Rig = rig,
		_animTable = animTable,
		Mask = nil,
		Ended = endedEvent.Event
	}

	if typeof(mask) == "table" then
		track.Mask = {}
		for _, name in ipairs(mask) do track.Mask[name] = true end
	end

	function track:Pause() self.IsPaused = true end
	function track:Resume() self.IsPaused = false end

	function track:Stop()
		if not self.IsPlaying then return end
		self.IsPlaying = false
		self.Weight = 0
		local motors = getRigSetup(self.Rig)
		for _, motor in pairs(motors) do
			if defaultC0Cache[motor] then motor.C0 = defaultC0Cache[motor] end
		end
		endedEvent:Fire()
	end

	function track:AdjustWeight(target, dur)
		local val = Instance.new("NumberValue")
		val.Value = self.Weight
		local tween = TweenService:Create(val, TweenInfo.new(dur or 0.25), {Value = target})
		val:GetPropertyChangedSignal("Value"):Connect(function() self.Weight = val.Value end)
		tween.Completed:Connect(function() val:Destroy() end)
		tween:Play()
	end

	function track:_getActiveKeyframes()
		local kfs = self._animTable.Keyframes
		for i = 1, #kfs - 1 do
			if self.Time >= kfs[i].Time and self.Time <= kfs[i+1].Time then
				return kfs[i], kfs[i+1]
			end
		end
		return kfs[#kfs-1], kfs[#kfs]
	end

	task.spawn(function()
		track:AdjustWeight(1, fadeTime)
		local totalDuration = animTable.Keyframes[#animTable.Keyframes].Time
		while track.IsPlaying do
			local dt = RunService.Heartbeat:Wait()
			if not track.IsPaused then
				track.Time = track.Time + (dt * track.Speed)
				if track.Time >= totalDuration then
					if track.Loop then 
						track.Time = 0 
					else 
						track:Stop()
						break 
					end
				end
			end
		end
	end)

	if not activeTracks[rig] then activeTracks[rig] = {} end
	table.insert(activeTracks[rig], track)
	return track
end

return AnimationPlayer
