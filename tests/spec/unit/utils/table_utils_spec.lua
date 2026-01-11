describe("TableUtils", function()
  local TestUtils = require("test_utils")
  local table_utils

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.TableUtils")
    table_utils = LifeBoatAPI.Tools.TableUtils
  end)

  describe("iwhere (filter)", function()
    it("should filter table by predicate", function()
      local input = {1, 2, 3, 4, 5}
      local result = table_utils.iwhere(input, function(v) return v % 2 == 0 end)

      -- Note: iwhere returns nil for non-matching values, so we need to count non-nil values
      local count = 0
      for _, v in ipairs(result) do
        if v ~= nil then count = count + 1 end
      end
      assert.equals(2, count)
    end)

    it("should return table with nils when nothing matches", function()
      local input = {1, 3, 5}
      local result = table_utils.iwhere(input, function(v) return v % 2 == 0 end)

      -- Check all values are nil
      for _, v in ipairs(result) do
        assert.is_nil(v)
      end
    end)
  end)

  describe("iselect (map)", function()
    it("should transform each element", function()
      local input = {1, 2, 3}
      local result = table_utils.iselect(input, function(v) return v * 2 end)

      assert.equals(3, #result)
      assert.equals(2, result[1])
      assert.equals(4, result[2])
      assert.equals(6, result[3])
    end)
  end)

  describe("islice (slice)", function()
    it("should slice table from start to end", function()
      local input = {1, 2, 3, 4, 5}
      local result = table_utils.islice(input, 2, 4)

      assert.equals(3, #result)
      assert.equals(2, result[1])
      assert.equals(3, result[2])
      assert.equals(4, result[3])
    end)

    it("should handle slice to end", function()
      local input = {1, 2, 3, 4, 5}
      local result = table_utils.islice(input, 3)

      assert.equals(3, #result)
      assert.equals(3, result[1])
      assert.equals(4, result[2])
      assert.equals(5, result[3])
    end)
  end)

  describe("containsValue (contains)", function()
    it("should return true if value exists", function()
      local input = {1, 2, 3, 4, 5}
      assert.is_true(table_utils.containsValue(input, 3))
    end)

    it("should return false if value does not exist", function()
      local input = {1, 2, 3, 4, 5}
      assert.is_false(table_utils.containsValue(input, 10))
    end)
  end)
end)
