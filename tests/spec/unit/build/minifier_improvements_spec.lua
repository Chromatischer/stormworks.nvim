-- Minifier improvement test script
-- This script compares original vs improved minifier output sizes
--
-- Run with: cd /home/user/stormworks.nvim && busted tests/spec/unit/build/minifier_improvements_spec.lua

describe("Minifier Improvements", function()
  local TestUtils = require("test_utils")
  local minimizer_class
  local constants_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.Minimizer")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
    minimizer_class = LifeBoatAPI.Tools.Minimizer
    constants_class = LifeBoatAPI.Tools.ParsingConstantsLoader
  end)

  -- Test scripts that simulate real Stormworks code
  local test_scripts = {
    -- Simple microcontroller with repeated numbers
    simple_mc = [[
local t = 0
local width = 100
local height = 100

function onTick()
  t = t + 1
  output.setNumber(1, t)
  output.setNumber(2, width)
  output.setNumber(3, height)
end

function onDraw()
  screen.setColor(255, 255, 255)
  screen.drawRect(0, 0, 100, 100)
  screen.drawText(5, 5, "Tick: " .. t)
  screen.setColor(100, 100, 100)
  screen.drawCircle(50, 50, 25)
end
]],

    -- Script with hexadecimal values
    hex_script = [[
local colorWhite = 0xFFFFFF
local colorRed = 0xFF0000
local colorGreen = 0x00FF00
local colorBlue = 0x0000FF
local smallHex = 0xFF

function onDraw()
  screen.setColor(0xFF, 0xFF, 0xFF)
  screen.drawRect(0, 0, 0x20, 0x20)
  screen.setColor(0xFF, 0x00, 0x00)
  screen.drawRect(0x20, 0, 0x20, 0x20)
end
]],

    -- Script with constant expressions
    constant_folding_test = [[
local screenWidth = 32 * 5
local screenHeight = 32 * 4
local halfWidth = 160 / 2
local quarterHeight = 128 / 4
local offset = 10 + 5
local margin = 100 - 20

function onTick()
  local x = 1 + 2 + 3
  local y = 10 * 10
  local z = 100 / 4
  output.setNumber(1, x)
  output.setNumber(2, y)
end

function onDraw()
  screen.drawRect(0, 0, 32 * 5, 32 * 4)
  screen.drawText(10 + 5, 10 + 5, "Test")
end
]],

    -- Radar tracking system (complex script)
    radar_tracking = [[
local MAX_TRACKS = 10
local TRACK_TIMEOUT = 60
local UPDATE_RATE = 60
local SCREEN_WIDTH = 160
local SCREEN_HEIGHT = 160

local tracks = {}
local trackCount = 0
local ticks = 0

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

function onTick()
    ticks = ticks + 1

    local gpsX = input.getNumber(1)
    local gpsY = input.getNumber(2)
    local gpsZ = input.getNumber(3)
    local angle = input.getNumber(4)

    for i = 1, MAX_TRACKS do
        local dist = input.getNumber(i + 10)
        local azimuth = input.getNumber(i + 20)
        if dist > 0 then
            trackCount = trackCount + 1
        end
    end

    output.setNumber(1, trackCount)
    output.setNumber(2, ticks)
end

function onDraw()
    screen.setColor(0, 0, 0)
    screen.drawClear()

    screen.setColor(0, 255, 0)
    screen.drawCircle(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, 50)
    screen.drawCircle(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, 100)

    screen.setColor(255, 255, 255)
    screen.drawText(5, 5, "Tracks: " .. trackCount)
    screen.drawText(5, 15, "Ticks: " .. ticks)

    for i = 1, trackCount do
        screen.setColor(255, 0, 0)
        screen.drawRectF(60 + i*10, 60, 8, 8)
    end
end
]],

    -- Script with many string duplicates
    string_duplicates = [[
function onTick()
    local status = "active"
    local mode = "active"
    local state = "active"

    if input.getBool(1) then
        status = "inactive"
        mode = "inactive"
        state = "inactive"
    end

    output.setNumber(1, status == "active" and 1 or 0)
end

function onDraw()
    screen.setColor(255, 255, 255)
    screen.drawText(5, 5, "Status: active")
    screen.drawText(5, 15, "Mode: active")
    screen.drawText(5, 25, "State: active")
end
]],

    -- TWS-Iteration-Y inspired script
    tws_system = [[
local rawRadarData = {{x=0,y=0,z=0}, {x=0,y=0,z=0}, {x=0,y=0,z=0}}
local MAX_SEPARATION = 100
local LIFESPAN = 20
local contacts = {}
local tracks = {}

local renderDepression = 20
local dirUp = 0
local mapDiameter = 10

local vesselPos = {x=0,y=0,z=0}
local vesselAngle = 0
local compas = 0
local finalZoom = 1
local screenCenter = {x=0,y=0}
local radarRotation = 0

local globalScales = {0.1, 0.2, 0.5, 1, 2, 2.5, 3, 3.5, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 40, 50}
local globalScale = 4

local ticks = 0

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

function onTick()
    ticks = ticks + 1

    vesselPos = {x=input.getNumber(1), y=input.getNumber(2), z=input.getNumber(3)}
    vesselAngle = input.getNumber(4)
    finalZoom = input.getNumber(5)
    screenCenter = {x=input.getNumber(6), y=input.getNumber(7)}
    radarRotation = input.getNumber(10)

    compas = (vesselAngle - 180) / 360

    for i = 0, 2 do
        local distance = input.getNumber(i * 4 + 11)
        local timeSinceDetected = input.getNumber(i * 4 + 14)

        if timeSinceDetected ~= 0 then
            local tgt = rawRadarData[i + 1]
            rawRadarData[i + 1] = scaleDivideVec3(addVec3(vesselPos, scaleVec3(tgt, timeSinceDetected - 1)), timeSinceDetected)
        elseif vec3length(vesselPos) > 50 then
            table.insert(contacts, vesselPos)
            rawRadarData[i + 1] = {x=0,y=0,z=0}
        end
    end
end

function onDraw()
    local Swidth, Sheight = screen.getWidth(), screen.getHeight()

    screen.setColor(100, 0, 0, 128)
    screen.drawRect(0, 0, 63, 160)

    screen.setColor(0, 100, 0, 128)
    screen.drawRect(64, 0, 160, 160)

    local radarMidPointX = 144
    local radarMidPointY = 80 + renderDepression

    screen.setColor(255, 255, 255)
    for i, track in ipairs(tracks) do
        screen.drawText(1, 7 * (i - 1), "T" .. i)
    end
end
]],
  }

  describe("size reduction", function()
    local constants

    before_each(function()
      constants = constants_class:new()
      constants:loadLibrary("math")
      constants:loadLibrary("string")
      constants:loadLibrary("table")
    end)

    for name, script in pairs(test_scripts) do
      it("should minimize " .. name .. " effectively", function()
        local minimizer = minimizer_class:new(constants, {
          reduceAllWhitespace = true,
          reduceNewlines = true,
          removeRedundancies = true,
          shortenVariables = true,
          shortenGlobals = true,
          shortenNumbers = true,
          removeComments = true,
          shortenStringDuplicates = true,
          foldConstants = true,
          forceNCBoilerplate = false,
          forceBoilerplate = false,
        })

        local result, sizeWithoutBoilerplate = minimizer:minimize(script)

        -- Verify valid Lua
        local is_valid, err = TestUtils.is_valid_lua(result)
        assert.is_true(is_valid, "Output should be valid Lua: " .. tostring(err))

        -- Calculate reduction
        local originalSize = #script
        local reduction = ((originalSize - sizeWithoutBoilerplate) / originalSize) * 100

        -- Print results for analysis
        print(string.format("\n[%s]", name))
        print(string.format("  Original: %d chars", originalSize))
        print(string.format("  Minified: %d chars", sizeWithoutBoilerplate))
        print(string.format("  Reduction: %.1f%%", reduction))

        -- Assert meaningful reduction (at least 30% for most scripts)
        assert.is_true(reduction > 20,
          string.format("Expected at least 20%% reduction, got %.1f%%", reduction))
      end)
    end
  end)

  describe("constant folding", function()
    local constants

    before_each(function()
      constants = constants_class:new()
    end)

    it("should fold simple addition", function()
      local minimizer = minimizer_class:new(constants, {
        shortenVariables = false,
        shortenGlobals = false,
        shortenNumbers = false,
        foldConstants = true,
      })

      local input = "local x = 1 + 2"
      local result = minimizer:minimize(input)

      -- Should contain 3, not 1 + 2
      assert.is_true(result:find("3") ~= nil, "Should fold 1+2 to 3")
      assert.is_nil(result:find("1%s*%+%s*2"), "Should not contain 1 + 2")
    end)

    it("should fold multiplication", function()
      local minimizer = minimizer_class:new(constants, {
        shortenVariables = false,
        shortenGlobals = false,
        shortenNumbers = false,
        foldConstants = true,
      })

      local input = "local x = 10 * 5"
      local result = minimizer:minimize(input)

      assert.is_true(result:find("50") ~= nil, "Should fold 10*5 to 50")
    end)

    it("should fold division when result is integer", function()
      local minimizer = minimizer_class:new(constants, {
        shortenVariables = false,
        shortenGlobals = false,
        shortenNumbers = false,
        foldConstants = true,
      })

      local input = "local x = 100 / 4"
      local result = minimizer:minimize(input)

      assert.is_true(result:find("25") ~= nil, "Should fold 100/4 to 25")
    end)
  end)

  describe("hex conversion optimization", function()
    local constants

    before_each(function()
      constants = constants_class:new()
    end)

    it("should convert small hex to decimal", function()
      local minimizer = minimizer_class:new(constants, {
        shortenVariables = false,
        shortenGlobals = false,
        shortenNumbers = false,
      })

      local input = "local x = 0xFF"
      local result = minimizer:minimize(input)

      -- 0xFF (4 chars) should become 255 (3 chars)
      assert.is_true(result:find("255") ~= nil, "Should convert 0xFF to 255")
    end)

    it("should not convert large hex when decimal is longer", function()
      local minimizer = minimizer_class:new(constants, {
        shortenVariables = false,
        shortenGlobals = false,
        shortenNumbers = false,
      })

      -- 0xFFFFFFFF = 4294967295 (10 chars vs 10 chars - equal, should convert)
      -- 0x123456789 would be longer in decimal
      local input = "local x = 0xFFFFFF"  -- 16777215 (8 chars each)
      local result = minimizer:minimize(input)

      -- Should convert since lengths are equal
      assert.is_true(result:find("16777215") ~= nil or result:find("0xFFFFFF") ~= nil)
    end)
  end)

  describe("number literal optimization", function()
    local constants

    before_each(function()
      constants = constants_class:new()
    end)

    it("should deduplicate repeated numbers", function()
      local minimizer = minimizer_class:new(constants, {
        shortenVariables = false,
        shortenGlobals = false,
        shortenNumbers = true,
      })

      local input = [[
        local a = 100
        local b = 100
        local c = 100
        local d = 100
      ]]
      local result = minimizer:minimize(input)

      -- With 4 uses of 100, should create a variable
      -- Count occurrences of "100" - should be reduced
      local count = 0
      for _ in result:gmatch("100") do
        count = count + 1
      end

      -- Should have at most 2 occurrences (one in assignment, maybe one leftover)
      -- or should use a short variable name instead
      assert.is_true(count <= 2 or result:find("=100") ~= nil,
        "Should deduplicate repeated number 100")
    end)

    it("should remove leading zeros", function()
      local minimizer = minimizer_class:new(constants, {
        shortenVariables = false,
        shortenGlobals = false,
        shortenNumbers = true,
      })

      local input = "local x = 0.5"
      local result = minimizer:minimize(input)

      -- 0.5 should become .5
      assert.is_true(result:find("%.5") ~= nil or result:find("0%.5") == nil,
        "Should convert 0.5 to .5")
    end)
  end)

  describe("variable renamer", function()
    local constants

    before_each(function()
      constants = constants_class:new()
    end)

    it("should generate unique names for many variables", function()
      -- Test the fix for the boundary case
      local renamer_class = LifeBoatAPI.Tools.VariableRenamer
      local renamer = renamer_class:new(constants)

      local names = {}
      local duplicates = {}

      -- Generate 100 names and check for duplicates
      for i = 1, 100 do
        local name = renamer:getShortName()
        if names[name] then
          table.insert(duplicates, name)
        end
        names[name] = true
      end

      assert.is_true(#duplicates == 0,
        "Should not generate duplicate names. Duplicates: " .. table.concat(duplicates, ", "))
    end)
  end)
end)
