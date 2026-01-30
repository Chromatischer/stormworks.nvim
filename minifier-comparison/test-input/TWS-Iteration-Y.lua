-- Author: Chromatischer
-- GitHub: github.com/Chromatischer
-- Workshop: steamcommunity.com/profiles/76561199061545480/
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeBoatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

-- CH1: GPS X
-- CH2: GPS Y
-- CH3: GPS Z
-- CH4: Vessel Angle
-- CH5: Global Scale
-- CH6: Screen Center X
-- CH7: Screen Center Y
-- CH8: Touch X
-- CH9: Touch Y
-- CH10: Radar Rotation
-- CH11-22: Contact Data (4 channels per contact: distance, azimuth, elevation, timeSinceDetected)
-- CH13: ???

-- CHB2: Is Depressed
-- CHB2: Global Darkmode
-- CHB3: Self Is Selected
-- CHB4-6: Target Detected Status (1 per contact)
--#endregion

rawRadarData = { {x=0,y=0,z=0}, {x=0,y=0,z=0}, {x=0,y=0,z=0} }
MAX_SEPARATION = 100
LIFESPAN = 20
contacts = {}
tracks = {}

renderDepression = 20
dirUp = 0
mapDiameter = 10

vesselPos = {x=0,y=0,z=0}
vesselAngle = 0
compas = 0
finalZoom = 1
screenCenter = {x=0,y=0}
radarRotation = 0
isDepressed = false
CHDarkmode = false
SelfIsSelected = false
vesselPitch = 0

globalScales = { 0.1, 0.2, 0.5, 1, 2, 2.5, 3, 3.5, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 40, 50 }
globalScale = 4

ticks = 0

function vec3length(v)
    return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
end

function vec2length(v)
    return math.sqrt(v.x*v.x + v.y*v.y)
end

function addVec3(a, b)
    return {x=a.x+b.x, y=a.y+b.y, z=a.z+b.z}
end

function scaleVec3(v, s)
    return {x=v.x*s, y=v.y*s, z=v.z*s}
end

function scaleDivideVec3(v, s)
    return {x=v.x/s, y=v.y/s, z=v.z/s}
end

function subtract(a, b)
    return {x=a.x-b.x, y=a.y-b.y}
end

function transformScalar(relative, angle, scale)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    return {x=relative.x*cos_a - relative.y*sin_a, y=relative.x*sin_a + relative.y*cos_a}
end

function radarToGlobalCoordinates(distance, azimuth, elevation, vesselPos, radarRotation, vesselPitch)
    local cosAz = math.cos(azimuth + radarRotation)
    local sinAz = math.sin(azimuth + radarRotation)
    local cosEl = math.cos(elevation + vesselPitch)
    local sinEl = math.sin(elevation + vesselPitch)
    return {
        x = distance * cosEl * sinAz,
        y = distance * cosEl * cosAz,
        z = distance * sinEl
    }
end

function updateTrackT(tracks)
    local updated = {}
    for i, track in ipairs(tracks) do
        track.age = (track.age or 0) + 1
        if track.age < LIFESPAN * 60 then
            table.insert(updated, track)
        end
    end
    return updated
end

function hungarianTrackingAlgorithm(contacts, tracks, maxSep, maxAge, config)
    for _, contact in ipairs(contacts) do
        local bestTrack = nil
        local bestDist = maxSep
        for _, track in ipairs(tracks) do
            local dx = contact.x - track.x
            local dy = contact.y - track.y
            local dz = contact.z - track.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dist < bestDist then
                bestDist = dist
                bestTrack = track
            end
        end
        if bestTrack then
            bestTrack.x = contact.x
            bestTrack.y = contact.y
            bestTrack.z = contact.z
            bestTrack.age = 0
        else
            table.insert(tracks, {x=contact.x, y=contact.y, z=contact.z, age=0, id=#tracks+1})
        end
    end
    return tracks
end

function trackToString(track)
    return string.format("T%d: %.0f,%.0f", track.id or 0, track.x or 0, track.y or 0)
end

function onTick()
    ticks = ticks + 1

    vesselPos = {x=input.getNumber(1), y=input.getNumber(2), z=input.getNumber(3)}
    vesselAngle = input.getNumber(4)
    finalZoom = input.getNumber(5)
    screenCenter = {x=input.getNumber(6), y=input.getNumber(7)}
    touchX = input.getNumber(8)
    touchY = input.getNumber(9)
    radarRotation = input.getNumber(10)

    isDepressed = input.getBool(1)
    CHDarkmode = input.getBool(2)
    SelfIsSelected = input.getBool(3)

    if SelfIsSelected then
        compas = (vesselAngle - 180) / 360

        dataOffset = 11
        boolOffset = 4

        for i = 0, 2 do
            distance = input.getNumber(i * 4 + dataOffset)
            targetDetected = input.getBool(i + boolOffset)
            timeSinceDetected = input.getNumber(i * 4 + 3 + dataOffset)

            tgtRelativePos = radarToGlobalCoordinates(
                distance,
                input.getNumber(i * 4 + 1 + dataOffset),
                input.getNumber(i * 4 + 2 + dataOffset),
                vesselPos,
                radarRotation,
                vesselPitch
            )
            tgtWorldPos = addVec3(tgtRelativePos, vesselPos)

            tgt = rawRadarData[i + 1] or {x=0,y=0,z=0}

            if timeSinceDetected ~= 0 then
                rawRadarData[i + 1] =
                    scaleDivideVec3(addVec3(tgtWorldPos, scaleVec3(tgt, timeSinceDetected - 1)), timeSinceDetected)
            elseif vec3length(tgtWorldPos) > 50 then
                table.insert(contacts, tgtWorldPos)
                rawRadarData[i + 1] = {x=0,y=0,z=0}
            end
        end

        tracks = updateTrackT(tracks)

        if radarRotation < 0.01 and #contacts > 0 then
            tracks = hungarianTrackingAlgorithm(contacts, tracks, MAX_SEPARATION, LIFESPAN * 60, {})
            contacts = {}
        end
    end
end

function onDraw()
    Swidth, Sheight = screen.getWidth(), screen.getHeight()

    screen.setColor(100, 0, 0, 128)
    screen.drawRect(0, 0, 63, 160)

    screen.setColor(0, 100, 0, 128)
    screen.drawRect(64, 0, 160, 160)

    radarMidPointX = 144
    radarMidPointY = 80 + renderDepression

    function transformWS(world, center, updir, scale)
        relative = subtract(world, center)
        return transformScalar(relative, math.atan(relative.y, relative.x) - updir, vec2length(relative) / scale)
    end

    vesselScreenPos = transformWS(vesselPos, screenCenter, dirUp, globalScales[globalScale])

    screen.setColor(255, 255, 255)
    for _, track in ipairs(tracks) do
        screen.drawText(1, 7 * (_ - 1), trackToString(track))
    end
end
