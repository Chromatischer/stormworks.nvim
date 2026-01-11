describe("StringUtils", function()
  local TestUtils = require("test_utils")
  local string_utils

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.StringUtils")
    string_utils = LifeBoatAPI.Tools.StringUtils
  end)

  describe("subAll", function()
    it("should replace all occurrences recursively", function()
      local input = "AAA"
      local result = string_utils.subAll(input, "AA", "B")

      -- Should replace AA with B, then BA with C if pattern forms again
      assert.is_string(result)
      TestUtils.assert_not_contains(result, "AA")
    end)

    it("should handle simple substitution", function()
      local input = "hello world hello"
      local result = string_utils.subAll(input, "hello", "hi")

      assert.equals("hi world hi", result)
    end)
  end)

  describe("escape", function()
    it("should escape Lua pattern special characters", function()
      local input = "test.pattern"
      local escaped = string_utils.escape(input)

      -- Dot should be escaped (becomes "%.")
      assert.equals("test%.pattern", escaped)
    end)

    it("should escape multiple special characters", function()
      local input = "^$()%.[]*+-?"
      local escaped = string_utils.escape(input)

      -- All special chars should be escaped
      for char in input:gmatch(".") do
        assert.truthy(escaped:match("%%" .. char) or char == "%")
      end
    end)
  end)

  describe("count", function()
    it("should count pattern occurrences", function()
      local input = "aaa bbb aaa ccc aaa"
      local count = string_utils.count(input, "aaa")

      assert.equals(3, count)
    end)

    it("should return 0 for no matches", function()
      local input = "hello world"
      local count = string_utils.count(input, "xyz")

      assert.equals(0, count)
    end)
  end)

  describe("split", function()
    it("should split string by separator", function()
      local input = "a,b,c,d"
      local parts = string_utils.split(input, ",")

      assert.equals(4, #parts)
      assert.equals("a", parts[1])
      assert.equals("b", parts[2])
      assert.equals("c", parts[3])
      assert.equals("d", parts[4])
    end)

    it("should handle empty parts", function()
      local input = "a,,c"
      local parts = string_utils.split(input, ",")

      assert.equals(3, #parts)
      assert.equals("", parts[2])
    end)
  end)
end)
