-- Simple test case for minifier comparison
-- Author: Test
-- This file tests various Lua constructs

-- Configuration constants
local MAX_TARGETS = 10
local SCREEN_WIDTH = 160
local SCREEN_HEIGHT = 160
local UPDATE_RATE = 60

-- Global state variables
local targetPositions = {}
local targetVelocities = {}
local currentTime = 0
local isEnabled = true
local debugMode = false

-- Utility functions
local function clamp(value, minVal, maxVal)
    if value < minVal then
        return minVal
    elseif value > maxVal then
        return maxVal
    else
        return value
    end
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length > 0 then
        return x / length, y / length
    else
        return 0, 0
    end
end

-- Target management
local function createTarget(posX, posY, velX, velY)
    return {
        x = posX,
        y = posY,
        vx = velX,
        vy = velY,
        age = 0,
        active = true
    }
end

local function updateTarget(target, deltaTime)
    if not target.active then
        return
    end

    target.x = target.x + target.vx * deltaTime
    target.y = target.y + target.vy * deltaTime
    target.age = target.age + deltaTime

    -- Boundary check
    if target.x < 0 or target.x > SCREEN_WIDTH then
        target.vx = -target.vx
        target.x = clamp(target.x, 0, SCREEN_WIDTH)
    end
    if target.y < 0 or target.y > SCREEN_HEIGHT then
        target.vy = -target.vy
        target.y = clamp(target.y, 0, SCREEN_HEIGHT)
    end
end

local function findClosestTarget(x, y)
    local closest = nil
    local closestDist = math.huge

    for i = 1, #targetPositions do
        local target = targetPositions[i]
        if target.active then
            local dist = distance(x, y, target.x, target.y)
            if dist < closestDist then
                closestDist = dist
                closest = target
            end
        end
    end

    return closest, closestDist
end

-- Main callbacks
function onTick()
    currentTime = currentTime + 1 / UPDATE_RATE

    -- Read inputs
    isEnabled = input.getBool(1)
    debugMode = input.getBool(2)

    local inputX = input.getNumber(1)
    local inputY = input.getNumber(2)
    local newTargetSignal = input.getBool(3)

    if not isEnabled then
        return
    end

    -- Create new target on signal
    if newTargetSignal and #targetPositions < MAX_TARGETS then
        local velX = (math.random() - 0.5) * 10
        local velY = (math.random() - 0.5) * 10
        table.insert(targetPositions, createTarget(inputX, inputY, velX, velY))
    end

    -- Update all targets
    for i = 1, #targetPositions do
        updateTarget(targetPositions[i], 1 / UPDATE_RATE)
    end

    -- Find and output closest target
    local closest, dist = findClosestTarget(inputX, inputY)
    if closest then
        output.setNumber(1, closest.x)
        output.setNumber(2, closest.y)
        output.setNumber(3, dist)
        output.setBool(1, true)
    else
        output.setBool(1, false)
    end
end

function onDraw()
    local width = screen.getWidth()
    local height = screen.getHeight()

    -- Background
    screen.setColor(0, 0, 0)
    screen.drawRectF(0, 0, width, height)

    -- Draw all targets
    screen.setColor(255, 0, 0)
    for i = 1, #targetPositions do
        local target = targetPositions[i]
        if target.active then
            screen.drawCircleF(target.x, target.y, 3)

            if debugMode then
                -- Draw velocity vector
                screen.setColor(0, 255, 0)
                screen.drawLine(target.x, target.y, target.x + target.vx, target.y + target.vy)
                screen.setColor(255, 0, 0)
            end
        end
    end

    -- Draw target count
    screen.setColor(255, 255, 255)
    screen.drawText(1, 1, "Targets: " .. #targetPositions)

    if debugMode then
        screen.drawText(1, 8, "Time: " .. string.format("%.1f", currentTime))
    end
end
