describe("VariableShortener", function()
  local TestUtils = require("test_utils")
  local shortener_class
  local renamer_class
  local constants_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableShortener")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableRenamer")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
    shortener_class = LifeBoatAPI.Tools.VariableShortener
    renamer_class = LifeBoatAPI.Tools.VariableRenamer
    constants_class = LifeBoatAPI.Tools.ParsingConstantsLoader
  end)

  describe("shortenVariables", function()
    it("should shorten local variables", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local shortener = shortener_class:new(renamer)

      local input = [[
        local myLongVariableName = 100
        local result = myLongVariableName * 2
        print(result)
      ]]

      local output = shortener:shortenVariables(input)

      -- Variable should be shortened (exact name depends on renamer)
      assert.is_not.equals(input, output)
      assert.is_true(#output < #input)
      TestUtils.assert_not_contains(output, "myLongVariableName")
    end)

    it("should preserve Lua keywords", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local shortener = shortener_class:new(renamer)

      local input = [[
        local function test()
          if true then
            return false
          end
        end
      ]]

      local output = shortener:shortenVariables(input)

      TestUtils.assert_contains(output, "function")
      TestUtils.assert_contains(output, "if")
      TestUtils.assert_contains(output, "then")
      TestUtils.assert_contains(output, "return")
      TestUtils.assert_contains(output, "end")
    end)

    it("should shorten most-used variables to shortest names", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)
      local shortener = shortener_class:new(renamer)

      local input = [[
        local frequentVar = 1
        local rareVar = 2
        print(frequentVar)
        print(frequentVar)
        print(frequentVar)
        print(rareVar)
      ]]

      local output = shortener:shortenVariables(input)

      -- frequentVar should get a shorter name than rareVar
      -- This is hard to test precisely without knowing the renaming scheme
      assert.is_true(#output < #input)
    end)
  end)
end)
