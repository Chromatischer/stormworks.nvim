describe("Minimizer", function()
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

  describe("minimize", function()
    local constants

    before_each(function()
      constants = constants_class:new()
      constants:loadLibrary("math")
      constants:loadLibrary("string")
      constants:loadLibrary("table")
    end)

    it("should produce valid Lua code", function()
      local minimizer = minimizer_class:new(constants, {})
      local input = [[
        local function calculateArea(width, height)
          return width * height
        end
        local area = calculateArea(10, 20)
        print(area)
      ]]

      local result, size = minimizer:minimize(input)
      local is_valid, err = TestUtils.is_valid_lua(result)

      assert.is_true(is_valid, "Output should be valid Lua: " .. tostring(err))
    end)

    it("should reduce code size", function()
      local minimizer = minimizer_class:new(constants, {})
      local input = [[
        -- This is a comment
        local myLongVariableName = 100
        local anotherLongName = myLongVariableName * 2
        print(anotherLongName)
      ]]

      local result, size = minimizer:minimize(input)

      TestUtils.assert_smaller(input, result)
    end)

    it("should strip onDebugDraw when configured", function()
      local minimizer = minimizer_class:new(constants, {stripOnDebugDraw = true})
      local input = [[
        function onTick() end

        function onDebugDraw()
          print("debug")
        end

        function onDraw() end
      ]]

      local result = minimizer:minimize(input)

      TestUtils.assert_not_contains(result, "onDebugDraw")
      TestUtils.assert_contains(result, "onTick")
      TestUtils.assert_contains(result, "onDraw")
    end)

    it("should respect shortenVariables=false option", function()
      local minimizer = minimizer_class:new(constants, {shortenVariables = false})
      local input = [[
        local myVariable = 100
        print(myVariable)
      ]]

      local result = minimizer:minimize(input)

      -- Variable name should be preserved
      TestUtils.assert_contains(result, "myVariable")
    end)

    it("should remove comments by default", function()
      local minimizer = minimizer_class:new(constants, {})
      -- Using string concatenation to avoid nested bracket strings
      local input = "-- This is a comment\n" ..
        "local x = 1 -- another comment\n" ..
        "--" .. "[[ Multi\n" ..
        "line\n" ..
        "comment ]" .. "]\n" ..
        "print(x)"

      local result = minimizer:minimize(input)

      TestUtils.assert_not_contains(result, "This is a comment")
      TestUtils.assert_not_contains(result, "another comment")
      TestUtils.assert_not_contains(result, "Multi")
    end)

    it("should handle strings correctly", function()
      local minimizer = minimizer_class:new(constants, {})
      local input = [[
        local s = "test string -- not a comment"
        print(s)
      ]]

      local result = minimizer:minimize(input)

      -- String content should be preserved
      TestUtils.assert_contains(result, "test string")
      TestUtils.assert_contains(result, "not a comment")
    end)
  end)
end)
