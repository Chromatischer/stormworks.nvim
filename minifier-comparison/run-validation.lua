#!/usr/bin/env lua
--[[
  Minifier Validation Script

  Run this script to verify the minifier improvements work correctly.

  Usage:
    cd /home/user/stormworks.nvim
    lua minifier-comparison/run-validation.lua

  Or with neovim:
    nvim --headless -c "luafile minifier-comparison/run-validation.lua" -c "qa"
]]

-- Setup package path
local script_path = debug.getinfo(1, "S").source:sub(2)
local project_root = script_path:match("^(.*)/minifier%-comparison/")
if not project_root then
  project_root = "."
end

package.path = project_root .. "/lua/?.lua;" ..
               project_root .. "/lua/?/init.lua;" ..
               package.path

-- Mock vim if not available
if not _G.vim then
  _G.vim = {
    fn = {
      expand = function(s) return s end,
      filereadable = function() return 1 end,
    },
    loop = {
      fs_stat = function() return { type = "file" } end,
    },
    tbl_deep_extend = function(mode, ...)
      local result = {}
      for _, t in ipairs({...}) do
        for k, v in pairs(t) do
          result[k] = v
        end
      end
      return result
    end,
  }
end

-- Load LifeBoatAPI
print("Loading LifeBoatAPI...")
local ok, err = pcall(function()
  require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
  require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.Minimizer")
  require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
end)

if not ok then
  print("Error loading LifeBoatAPI: " .. tostring(err))
  os.exit(1)
end

print("LifeBoatAPI loaded successfully!")

-- Test scripts
local test_scripts = {
  {
    name = "simple_mc",
    code = [[
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
]]
  },
  {
    name = "constant_folding",
    code = [[
local screenWidth = 32 * 5
local screenHeight = 32 * 4
local halfWidth = 160 / 2
local offset = 10 + 5

function onTick()
  local x = 1 + 2 + 3
  local y = 10 * 10
  output.setNumber(1, x)
end

function onDraw()
  screen.drawRect(0, 0, 32 * 5, 32 * 4)
end
]]
  },
  {
    name = "hex_values",
    code = [[
local colorWhite = 0xFFFFFF
local colorRed = 0xFF0000
local smallHex = 0xFF

function onDraw()
  screen.setColor(0xFF, 0xFF, 0xFF)
  screen.drawRect(0, 0, 0x20, 0x20)
end
]]
  },
  {
    name = "radar_tracking",
    code = [[
local MAX_TRACKS = 10
local TRACK_TIMEOUT = 60
local SCREEN_WIDTH = 160
local SCREEN_HEIGHT = 160
local tracks = {}
local ticks = 0

function vec3length(v)
    return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
end

function onTick()
    ticks = ticks + 1
    local gpsX = input.getNumber(1)
    local gpsY = input.getNumber(2)

    for i = 1, MAX_TRACKS do
        local dist = input.getNumber(i + 10)
    end
    output.setNumber(1, ticks)
end

function onDraw()
    screen.setColor(0, 255, 0)
    screen.drawCircle(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, 50)
    screen.drawText(5, 5, "Ticks: " .. ticks)
end
]]
  },
}

-- Run tests
print("\n" .. string.rep("=", 60))
print("MINIFIER VALIDATION RESULTS")
print(string.rep("=", 60))

local constants = LifeBoatAPI.Tools.ParsingConstantsLoader:new()
constants:loadLibrary("math")
constants:loadLibrary("string")
constants:loadLibrary("table")

local total_original = 0
local total_minified = 0

for _, test in ipairs(test_scripts) do
  local minimizer = LifeBoatAPI.Tools.Minimizer:new(constants, {
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

  local result, size = minimizer:minimize(test.code)
  local original_size = #test.code
  local reduction = ((original_size - size) / original_size) * 100

  total_original = total_original + original_size
  total_minified = total_minified + size

  print(string.format("\n[%s]", test.name))
  print(string.format("  Original:  %4d chars", original_size))
  print(string.format("  Minified:  %4d chars", size))
  print(string.format("  Reduction: %5.1f%%", reduction))

  -- Validate Lua syntax (use loadstring for Lua 5.1 compatibility)
  local load_fn = loadstring or load
  local fn, err = load_fn(result)
  if fn then
    print("  Syntax:    VALID")
  else
    print("  Syntax:    INVALID - " .. tostring(err))
  end
end

-- Summary
local total_reduction = ((total_original - total_minified) / total_original) * 100
print("\n" .. string.rep("=", 60))
print("SUMMARY")
print(string.rep("=", 60))
print(string.format("Total original:  %d chars", total_original))
print(string.format("Total minified:  %d chars", total_minified))
print(string.format("Total reduction: %.1f%%", total_reduction))
print(string.rep("=", 60))

-- Test VariableRenamer for duplicates
print("\n" .. string.rep("=", 60))
print("VARIABLE RENAMER UNIQUENESS TEST")
print(string.rep("=", 60))

require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableRenamer")
local renamer = LifeBoatAPI.Tools.VariableRenamer:new(constants)
local names = {}
local duplicates = {}

for i = 1, 200 do
  local name = renamer:getShortName()
  if names[name] then
    table.insert(duplicates, string.format("%s (at %d and %d)", name, names[name], i))
  else
    names[name] = i
  end
end

if #duplicates == 0 then
  print("Generated 200 unique variable names: PASS")
else
  print("FAIL - Duplicate names found:")
  for _, dup in ipairs(duplicates) do
    print("  " .. dup)
  end
end

print("\n" .. string.rep("=", 60))
print("VALIDATION COMPLETE")
print(string.rep("=", 60))
