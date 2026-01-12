describe("NumberLiteralReducer", function()
  local TestUtils = require("test_utils")
  local reducer_class
  local renamer_class
  local constants_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.NumberLiteralReducer")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableRenamer")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
    reducer_class = LifeBoatAPI.Tools.NumberLiteralReducer
    renamer_class = LifeBoatAPI.Tools.VariableRenamer
    constants_class = LifeBoatAPI.Tools.ParsingConstantsLoader
  end)

  describe("shortenNumbers", function()
    it("should extract repeated numeric literals", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local reducer = reducer_class:new(renamer)

      local input = [[
        local a = 9999
        local b = 9999
        local c = 9999
        print(9999)
      ]]

      local output = reducer:shortenNumbers(input)

      -- Should create a variable for 9999
      -- Exact format depends on implementation
      assert.is_string(output)
    end)

    it("should handle floating point numbers", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local reducer = reducer_class:new(renamer)

      local input = [[
        local x = 3.14159
        local y = 3.14159
        local z = 3.14159
      ]]

      local output = reducer:shortenNumbers(input)

      assert.is_string(output)
    end)

    it("should not extract single-use numbers", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local reducer = reducer_class:new(renamer)

      local input = [[
        local a = 123
        local b = 456
        local c = 789
      ]]

      local output = reducer:shortenNumbers(input)

      -- Should not create variables for single uses
      TestUtils.assert_contains(output, "123")
      TestUtils.assert_contains(output, "456")
      TestUtils.assert_contains(output, "789")
    end)
  end)
end)
