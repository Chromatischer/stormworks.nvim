describe("VariableRenamer", function()
  local TestUtils = require("test_utils")
  local renamer_class
  local constants_class
  local generatedNames = {}

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableRenamer")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
    renamer_class = LifeBoatAPI.Tools.VariableRenamer
    constants_class = LifeBoatAPI.Tools.ParsingConstantsLoader    
  end)

  describe("_generateName", function()
    it("should never output a repeated name", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)

      local repeatitionFound = false
      local seen = {}

      --Uses the following in order to generate the generatedNames array so that it doesn't need to be filled in on the fly
      for i = 1, 53^3-1, 1 do
        local shortName = renamer:_generateName()

        if seen[shortName] == true then
          print("Found repeated name: " .. i .. ": " .. shortName)
          repeatitionFound = true
        end

        generatedNames[i] = shortName
        seen[shortName] = true
      end
      

      
      assert.is_false(repeatitionFound)
    end)
  end)

  describe("_checkIsValidName", function()
    it("should return true for valid names", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)

      assert.is_true(renamer:_checkIsValidName("a"))
      assert.is_true(renamer:_checkIsValidName("b"))
      assert.is_true(renamer:_checkIsValidName("c"))
      assert.is_true(renamer:_checkIsValidName("d"))
      assert.is_true(renamer:_checkIsValidName("e"))
      assert.is_true(renamer:_checkIsValidName("f"))
    end)

    it("should return false for names that are restricted keywords", function()
      local constants = constants_class:new()
      constants:addRestrictedKeywords({"a", "b", "c", "d"})
      local renamer = renamer_class:new(constants)
      assert.is_false(renamer:_checkIsValidName("a"))
      assert.is_false(renamer:_checkIsValidName("b"))
      assert.is_false(renamer:_checkIsValidName("c"))
      assert.is_false(renamer:_checkIsValidName("if"))
      assert.is_false(renamer:_checkIsValidName("for"))
      assert.is_false(renamer:_checkIsValidName("end"))
    end)
  end)

  describe("getShortName", function()
    it("should generate the same output with and without the prefilled generatedNames cache", function ()


      local constants = constants_class:new()
      local renamerWithoutCache = renamer_class:new(constants)
      local renamerWithCache = renamer_class:new(constants)

      local uncached1 = renamerWithoutCache:getShortName()
      local cached1 = renamerWithCache:getShortName(generatedNames)


      local uncached2 = renamerWithoutCache:getShortName()
      local cached2 = renamerWithCache:getShortName(generatedNames)


      local uncached3 = renamerWithoutCache:getShortName()
      local cached3 = renamerWithCache:getShortName(generatedNames)


      assert.equals(uncached1, cached1)
      assert.equals(uncached2, cached2)
      assert.equals(uncached3, cached3)
    end) --it is now safe to simply use the cache

    it("should generate unique single-character names first", function()
      local constants = constants_class:new()
      local renamer = renamer_class:new(constants)

      local name1 = renamer:getShortName(generatedNames)
      local name2 = renamer:getShortName(generatedNames)
      local name3 = renamer:getShortName(generatedNames)

      --uniqueness is guarenteed through the testing to _generatedName
      assert.equals(1, #name1)
      assert.equals(1, #name2)
      assert.equals(1, #name3)
    end)

    it("should skip restricted keywords", function()
      local constants = constants_class:new()
      constants:addRestrictedKeywords({"a", "b", "c"})
      local renamer = renamer_class:new(constants)

      -- Generate names, should skip a, b, c
      for i = 1, 5 do
        local name = renamer:getShortName(generatedNames)
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
        renamer:getShortName(generatedNames)
      end

      -- Next name should be two characters
      local name = renamer:getShortName(generatedNames)
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
        renamer:getShortName(generatedNames)
      end

      -- Next name should be three characters
      local name = renamer:getShortName(generatedNames)
      assert.is_true(#name >= 3)
    end)

  end)

end)
