local TG_Travel = {}
function TG_Travel.GetTime(targetPos, walkSpeed, hrp)
    if not hrp or not walkSpeed or walkSpeed <= 0 then return 0 end
    local distance = (targetPos - hrp.Position).Magnitude
    -- t = S / v
    local calculatedTime = distance / walkSpeed
    return calculatedTime
end

function TG_Travel.GetRequiredSpeed(targetPos, seconds, hrp)
    if not hrp or seconds <= 0 then return 0 end
    local distance = (targetPos - hrp.Position).Magnitude
    return distance / seconds
end
return TG_Travel
