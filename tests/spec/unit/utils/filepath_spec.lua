describe("Filepath", function()
  local TestUtils = require("test_utils")
  local filepath_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Filepath")
    filepath_class = LifeBoatAPI.Tools.Filepath
  end)

  describe("new", function()
    it("should create filepath from string", function()
      local fp = filepath_class:new("/home/user/test.lua")

      assert.is_not_nil(fp)
      assert.is_string(fp:linux())
    end)

    it("should handle relative paths", function()
      local fp = filepath_class:new("relative/path/file.lua")

      assert.is_not_nil(fp)
    end)
  end)

  describe("linux", function()
    it("should convert to Linux path format", function()
      local fp = filepath_class:new("C:\\Users\\test\\file.lua")
      local linux_path = fp:linux()

      -- Linux paths use forward slashes
      assert.truthy(linux_path:find("/") or not linux_path:find("\\"))
    end)
  end)

  describe("filename", function()
    it("should extract filename from path", function()
      local fp = filepath_class:new("/home/user/test.lua")
      local filename = fp:filename()

      assert.equals("test.lua", filename)
    end)

    it("should handle path without extension", function()
      local fp = filepath_class:new("/home/user/test")
      local filename = fp:filename()

      assert.equals("test", filename)
    end)
  end)

  describe("directory", function()
    it("should get parent directory", function()
      local fp = filepath_class:new("/home/user/test.lua")
      local parent = fp:directory()

      -- Parent should be /home/user/ or equivalent
      assert.is_not_nil(parent)
      TestUtils.assert_not_contains(parent:linux(), "test.lua")
    end)
  end)
end)
