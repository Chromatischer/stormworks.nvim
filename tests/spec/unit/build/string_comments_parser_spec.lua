describe("StringCommentsParser", function()
  local TestUtils = require("test_utils")
  local parser_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.StringCommentsParser")
    parser_class = LifeBoatAPI.Tools.StringCommentsParser
  end)

  describe("removeStringsAndComments", function()
    it("should remove single-line comments", function()
      local parser = parser_class:new()
      local input = 'local x = 1 -- this is a comment\nlocal y = 2'
      local result = parser:removeStringsAndComments(input)

      TestUtils.assert_not_contains(result, "this is a comment")
      TestUtils.assert_contains(result, "local x = 1")
      TestUtils.assert_contains(result, "local y = 2")
    end)

    it("should remove multi-line comments", function()
      local parser = parser_class:new()
      local input = 'local x = 1 --[[ multi\nline\ncomment ]] local y = 2'
      local result = parser:removeStringsAndComments(input)

      TestUtils.assert_not_contains(result, "multi")
      TestUtils.assert_not_contains(result, "comment")
      TestUtils.assert_contains(result, "local x = 1")
      TestUtils.assert_contains(result, "local y = 2")
    end)

    it("should replace strings with placeholders", function()
      local parser = parser_class:new()
      local input = 'local s = "hello world"'
      local result = parser:removeStringsAndComments(input)

      assert.truthy(result:match("STRING%d+REPLACEMENT"))
      TestUtils.assert_not_contains(result, "hello world")
    end)

    it("should handle escaped quotes in strings", function()
      local parser = parser_class:new()
      local input = [[local s = "hello \"world\""]]
      local result = parser:removeStringsAndComments(input)

      -- String should be fully replaced
      assert.truthy(result:match("STRING%d+REPLACEMENT"))
      TestUtils.assert_not_contains(result, "hello")
    end)

    it("should handle multiline bracket strings", function()
      local parser = parser_class:new()
      -- Using concatenation to avoid nested bracket strings
      local input = "local s = [[" .. "multiline\nstring\nhere" .. "]]"
      local result = parser:removeStringsAndComments(input)

      assert.truthy(result:match("STRING%d+REPLACEMENT"))
    end)

    it("should preserve comment-like patterns in strings", function()
      local parser = parser_class:new()
      local input = 'local s = "not -- a comment"'
      local result = parser:removeStringsAndComments(input)

      -- String should be replaced as a whole
      assert.truthy(result:match("STRING%d+REPLACEMENT"))
    end)
  end)

  describe("repopulateStrings", function()
    it("should restore original string content", function()
      local parser = parser_class:new()
      local input = 'local s = "hello world"'
      local stripped = parser:removeStringsAndComments(input)
      local restored = parser:repopulateStrings(stripped, false)

      TestUtils.assert_contains(restored, '"hello world"')
    end)

    it("should handle multiple strings", function()
      local parser = parser_class:new()
      local input = 'local s1 = "first"\nlocal s2 = "second"'
      local stripped = parser:removeStringsAndComments(input)
      local restored = parser:repopulateStrings(stripped, false)

      TestUtils.assert_contains(restored, '"first"')
      TestUtils.assert_contains(restored, '"second"')
    end)
  end)
end)
