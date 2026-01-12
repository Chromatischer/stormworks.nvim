describe("VariableRenamer", function()
  local TestUtils = require("test_utils")
  local renamer_class
  local constants_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableRenamer")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
    renamer_class = LifeBoatAPI.Tools.VariableRenamer
    constants_class = LifeBoatAPI.Tools.ParsingConstantsLoader
  end)

  describe("getShortName", function()
    it("should generate single-character names first", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)

      local name1 = renamer:getShortName()
      local name2 = renamer:getShortName()
      local name3 = renamer:getShortName()

      assert.equals(1, #name1)
      assert.equals(1, #name2)
      assert.equals(1, #name3)
      assert.is_not.equals(name1, name2)
    end)

    it("should skip restricted keywords", function()
      local constants = constants_class:new()
      constants:addRestrictedKeywords({"a", "b", "c"})
      local renamer = renamer_class:new(constants)

      -- Generate names, should skip a, b, c
      local names = {}
      for i = 1, 10 do
        local name = renamer:getShortName()
        table.insert(names, name)
      end

      for _, name in ipairs(names) do
        assert.is_not.equals("a", name)
        assert.is_not.equals("b", name)
        assert.is_not.equals("c", name)
      end
    end)

    it("should generate two-character names after exhausting single chars", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)

      -- Generate many names to exhaust single chars
      -- Single chars: _, a-z (26), A-Z (26) = 53 total
      for i = 1, 54 do
        renamer:getShortName()
      end

      -- Next name should be two characters
      local name = renamer:getShortName()
      assert.is_true(#name >= 2)
    end)
  end)
end)
