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
    it("should generate unique single-character names first", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)

      local name1 = renamer:getShortName()
      local name2 = renamer:getShortName()
      local name3 = renamer:getShortName()

      assert.equals(1, #name1)
      assert.equals(1, #name2)
      assert.equals(1, #name3)
      assert.is_not.equals(name1, name2)
      assert.is_not.equals(name2, name3)
      assert.is_not.equals(name3, name1)
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

      -- Generate 53 names to exhaust single chars
      -- Single chars: _, a-z (26), A-Z (26) = 53 total
      for i = 1, 53 do
        renamer:getShortName()
      end

      -- Next name should be two characters
      local name = renamer:getShortName()
      assert.is_true(#name >= 2)
    end)

    it("should generate three-character names after exhausting single- and two-character names", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)

      

      -- Generate 53*53-1 names to exhaust single- and two-character names
      -- May generate three char names within 53*53-1 iterations due skipping the default restricted keywords
      -- Single chars: _, a-z (26), A-Z (26) = 53 total
      -- Two chars: 53*53-1 names
      for i = 1, 53*53-1 do
        renamer:getShortName()
      end

      -- Next name should be three characters
      local name = renamer:getShortName()
      assert.is_true(#name >= 3)
    end)

  end)

  describe("_generateName", function()
    it("should never output a repeated name", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)

      local repeatitionFound = false
      local seen = {}

      for i = 1, 53^3-1, 1 do
        local shortName = renamer:_generateName()

        if seen[namesshortName] == true then
          repeatitionFound = true
          break
        end
        
        seen[shortName] = true
      end
      assert.is_false(repeatitionFound)
    end)
  end)

end)
