describe("HexadecimalConverter", function()
  local TestUtils = require("test_utils")
  local converter_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.HexadecimalConverter")
    converter_class = LifeBoatAPI.Tools.HexadecimalConverter
  end)

  -- Note: The method is named 'fixHexademicals' (not 'fixHexadecimals') in the original 
  -- LifeBoatAPI implementation from nameouschangey. We match the actual API.
  describe("fixHexademicals", function()
    it("should convert uppercase hex to decimal", function()
      local converter = converter_class:new()
      local input = "local x = 0xFF"
      local result = converter:fixHexademicals(input)

      assert.truthy(result:match("255"))
      assert.falsy(result:match("0xFF"))
    end)

    it("should convert lowercase hex to decimal", function()
      local converter = converter_class:new()
      local input = "local x = 0xff"
      local result = converter:fixHexademicals(input)

      assert.truthy(result:match("255"))
      assert.falsy(result:match("0xff"))
    end)

    it("should convert multiple hex values", function()
      local converter = converter_class:new()
      local input = "local r, g, b = 0xFF, 0x00, 0x80"
      local result = converter:fixHexademicals(input)

      assert.truthy(result:match("255"))
      assert.truthy(result:match("128"))
      assert.truthy(result:match("0[^x]"))  -- 0 not followed by x
    end)

    it("should handle hex in color values", function()
      local converter = converter_class:new()
      local input = "screen.setColor(0xFF, 0xFF, 0xFF)"
      local result = converter:fixHexademicals(input)

      TestUtils.assert_contains(result, "255")
      TestUtils.assert_not_contains(result, "0xFF")
    end)
  end)
end)
