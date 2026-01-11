local TestUtils = {}

-- Create temporary directory for test files
function TestUtils.create_temp_dir()
  local path = "/tmp/stormworks_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000))
  os.execute("mkdir -p " .. path)
  return path
end

-- Remove temporary directory
function TestUtils.remove_temp_dir(path)
  os.execute("rm -rf " .. path)
end

-- Write content to file
function TestUtils.write_file(path, content)
  local f = io.open(path, "w")
  if f then
    f:write(content)
    f:close()
    return true
  end
  return false
end

-- Read file content
function TestUtils.read_file(path)
  local f = io.open(path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    return content
  end
  return nil
end

-- Check if string is valid Lua syntax
function TestUtils.is_valid_lua(code)
  local fn, err = loadstring(code)
  if not fn then
    -- Try with load for Lua 5.2+
    fn, err = load(code)
  end
  return fn ~= nil, err
end

-- Assert output is smaller than input
function TestUtils.assert_smaller(original, minimized)
  assert(#minimized < #original,
    string.format("Expected output (%d) to be smaller than input (%d)",
      #minimized, #original))
end

-- Assert strings match (with better error messages)
function TestUtils.assert_contains(str, pattern, msg)
  local found = str:find(pattern, 1, true)
  if not found then
    error(string.format("%s\nExpected to find: %s\nIn string: %s",
      msg or "String does not contain pattern",
      pattern,
      str:sub(1, 200)))
  end
end

function TestUtils.assert_not_contains(str, pattern, msg)
  local found = str:find(pattern, 1, true)
  if found then
    error(string.format("%s\nDid not expect to find: %s\nIn string: %s",
      msg or "String should not contain pattern",
      pattern,
      str:sub(1, 200)))
  end
end

-- Setup LifeBoatAPI globals for build system tests
function TestUtils.setup_lifeboat()
  local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
  package.path = project_root .. "/lua/?.lua;" ..
                 project_root .. "/lua/?/init.lua;" ..
                 package.path

  -- Load base LifeBoatAPI classes
  require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
end

-- Get project root directory
function TestUtils.get_project_root()
  local info = debug.getinfo(1, "S")
  local test_file = info.source:sub(2) -- Remove @ prefix
  local test_dir = test_file:match("^(.*)/tests/")
  return test_dir or "/home/god/Stormworks/stormworks.nvim"
end

-- Create a simple microcontroller script for testing
function TestUtils.create_simple_mc_script()
  return [[
local counter = 0

function onTick()
  counter = counter + 1
  output.setNumber(1, counter)
end

function onDraw()
  screen.setColor(255, 255, 255)
  screen.drawText(5, 5, "Count: " .. counter)
end
]]
end

-- Create a script with require statements
function TestUtils.create_multifile_project(base_dir)
  -- Main file
  local main = [[
require("utils")

function onTick()
  local result = utils.calculate(10)
  output.setNumber(1, result)
end
]]

  -- Utils module
  local utils = [[
utils = {}

function utils.calculate(x)
  return x * 2
end

function utils.format(n)
  return "Value: " .. tostring(n)
end
]]

  TestUtils.write_file(base_dir .. "/main.lua", main)
  TestUtils.write_file(base_dir .. "/utils.lua", utils)

  return main, utils
end

-- Compare two tables deeply
function TestUtils.tables_equal(t1, t2)
  if type(t1) ~= type(t2) then return false end
  if type(t1) ~= "table" then return t1 == t2 end

  for k, v in pairs(t1) do
    if not TestUtils.tables_equal(v, t2[k]) then
      return false
    end
  end

  for k, v in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end

  return true
end

-- Count occurrences of pattern in string
function TestUtils.count_occurrences(str, pattern)
  local count = 0
  local pos = 1
  while true do
    local found = str:find(pattern, pos, true)
    if not found then break end
    count = count + 1
    pos = found + 1
  end
  return count
end

return TestUtils
