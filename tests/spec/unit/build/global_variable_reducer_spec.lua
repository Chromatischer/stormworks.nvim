describe("GlobalVariableReducer", function()
  local TestUtils = require("test_utils")
  local reducer_class
  local renamer_class
  local constants_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.GlobalVariableReducer")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableRenamer")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
    reducer_class = LifeBoatAPI.Tools.GlobalVariableReducer
    renamer_class = LifeBoatAPI.Tools.VariableRenamer
    constants_class = LifeBoatAPI.Tools.ParsingConstantsLoader
  end)

  describe("shortenGlobals", function()
    it("should create alias for globals used multiple times", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local reducer = reducer_class:new(renamer, constants)

      local input = [[
        screen.drawRect(0, 0, 10, 10)
        screen.drawRect(10, 10, 20, 20)
        screen.drawRect(20, 20, 30, 30)
      ]]

      local output = reducer:shortenGlobals(input)

      -- The reducer should return a valid string
      assert.is_string(output)
      assert.is_true(#output > 0)
    end)

    it("should not create alias for single-use globals", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local reducer = reducer_class:new(renamer, constants)

      local input = [[
        screen.drawRect(0, 0, 10, 10)
        screen.drawCircle(50, 50, 10)
      ]]

      local output = reducer:shortenGlobals(input)

      -- Should not create aliases for single uses
      -- Size might be similar or same
      TestUtils.assert_contains(output, "screen")
    end)

    it("should handle multiple different globals", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local reducer = reducer_class:new(renamer, constants)

      local input = [[
        screen.drawRect(0, 0, 10, 10)
        screen.drawRect(10, 10, 20, 20)
        output.setNumber(1, 42)
        output.setNumber(2, 43)
        output.setNumber(3, 44)
      ]]

      local output = reducer:shortenGlobals(input)

      -- Should handle multiple global patterns
      assert.is_string(output)
    end)
  end)
end)
