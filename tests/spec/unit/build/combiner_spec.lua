describe("Combiner", function()
  local TestUtils = require("test_utils")
  local combiner_class
  local filepath_class
  local temp_dir

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.Combiner")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Filepath")
    combiner_class = LifeBoatAPI.Tools.Combiner
    filepath_class = LifeBoatAPI.Tools.Filepath
  end)

  before_each(function()
    temp_dir = TestUtils.create_temp_dir()
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("combine", function()
    it("should resolve single require statement", function()
      local combiner = combiner_class:new()

      -- Create module
      TestUtils.write_file(temp_dir .. "/module.lua", [[
moduleVar = "test"
]])

      -- Create main script
      local main = [[
require("module")
print(moduleVar)
]]

      combiner:addRootFolder(filepath_class:new(temp_dir))
      local result = combiner:combine(main, filepath_class:new(temp_dir .. "/main.lua"))

      TestUtils.assert_contains(result, "moduleVar")
      TestUtils.assert_not_contains(result, 'require("module")')
    end)

    it("should resolve multiple require statements", function()
      local combiner = combiner_class:new()

      TestUtils.write_file(temp_dir .. "/utils.lua", "utils = {}")
      TestUtils.write_file(temp_dir .. "/helpers.lua", "helpers = {}")

      local main = [[
require("utils")
require("helpers")
print("done")
]]

      combiner:addRootFolder(filepath_class:new(temp_dir))
      local result = combiner:combine(main, filepath_class:new(temp_dir .. "/main.lua"))

      TestUtils.assert_contains(result, "utils = {}")
      TestUtils.assert_contains(result, "helpers = {}")
      TestUtils.assert_not_contains(result, 'require("utils")')
    end)

    it("should handle nested requires", function()
      local combiner = combiner_class:new()

      TestUtils.write_file(temp_dir .. "/a.lua", [[
require("b")
a_var = "a"
]])
      TestUtils.write_file(temp_dir .. "/b.lua", [[
b_var = "b"
]])

      local main = [[
require("a")
print(a_var, b_var)
]]

      combiner:addRootFolder(filepath_class:new(temp_dir))
      local result = combiner:combine(main, filepath_class:new(temp_dir .. "/main.lua"))

      TestUtils.assert_contains(result, "a_var")
      TestUtils.assert_contains(result, "b_var")
    end)

    it("should skip duplicate requires", function()
      local combiner = combiner_class:new()

      TestUtils.write_file(temp_dir .. "/utils.lua", "utils = {}")

      local main = [[
require("utils")
require("utils")
print(utils)
]]

      combiner:addRootFolder(filepath_class:new(temp_dir))
      local result = combiner:combine(main, filepath_class:new(temp_dir .. "/main.lua"))

      -- Should only include utils once
      assert.equals(1, TestUtils.count_occurrences(result, "utils = {}"))
    end)
  end)
end)
