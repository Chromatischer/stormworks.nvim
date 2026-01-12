describe("StringBuilder", function()
  local TestUtils = require("test_utils")
  local string_builder_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.StringBuilder")
    string_builder_class = LifeBoatAPI.Tools.StringBuilder
  end)

  describe("add (append)", function()
    it("should add strings", function()
      local sb = string_builder_class:new()
      sb:add("hello")
      sb:add(" ")
      sb:add("world")

      local result = sb:getString()
      assert.equals("hello world", result)
    end)

    it("should handle multiple adds", function()
      local sb = string_builder_class:new()
      for i = 1, 10 do
        sb:add(tostring(i))
      end

      local result = sb:getString()
      assert.equals("12345678910", result)
    end)
  end)

  describe("getString (toString)", function()
    it("should convert to string", function()
      local sb = string_builder_class:new()
      sb:add("test")

      local result = sb:getString()
      assert.is_string(result)
      assert.equals("test", result)
    end)

    it("should handle empty builder", function()
      local sb = string_builder_class:new()

      local result = sb:getString()
      assert.equals("", result)
    end)
  end)

  describe("addLine", function()
    it("should add string with newline", function()
      local sb = string_builder_class:new()
      sb:addLine("line1")
      sb:addLine("line2")

      local result = sb:getString()
      assert.equals("line1\nline2\n", result)
    end)
  end)

  describe("addFront", function()
    it("should add to the beginning", function()
      local sb = string_builder_class:new()
      sb:add("world")
      sb:addFront("hello ")

      local result = sb:getString()
      assert.equals("hello world", result)
    end)
  end)
end)
