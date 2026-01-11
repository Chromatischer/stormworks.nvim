describe("Project", function()
  local MockVim = require("mock_vim")
  local TestUtils = require("test_utils")
  local project
  local temp_dir

  setup(function()
    -- Install vim mock
    _G.vim = MockVim

    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

    project = require("stormworks.modules.project")
  end)

  before_each(function()
    MockVim.reset()
    temp_dir = TestUtils.create_temp_dir()
    MockVim._state.cwd = temp_dir
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("detect", function()
    it("should detect .microproject in current directory", function()
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")

      local detected = project.detect(temp_dir)

      assert.is_not_nil(detected)
      assert.equals(temp_dir, detected)
    end)

    it("should search upward for .microproject", function()
      local sub_dir = temp_dir .. "/src/components"
      os.execute("mkdir -p " .. sub_dir)

      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")

      local detected = project.detect(sub_dir)

      assert.is_not_nil(detected)
      assert.equals(temp_dir, detected)
    end)

    it("should return nil if no .microproject found", function()
      local detected = project.detect(temp_dir)

      assert.is_nil(detected)
    end)

    it("should stop at filesystem root", function()
      local detected = project.detect("/")

      assert.is_nil(detected)
    end)
  end)

  describe("load_config", function()
    it("should load project configuration", function()
      local marker_path = temp_dir .. "/.microproject"
      local config_content = [[
return {
  is_microcontroller = true,
  libraries = {"LifeBoatAPI"},
}
]]
      TestUtils.write_file(marker_path, config_content)

      local config = project.load_config(temp_dir)

      assert.is_table(config)
      assert.is_true(config.is_microcontroller)
      assert.is_table(config.libraries)
    end)

    it("should return default config if file invalid", function()
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "invalid lua syntax {{{")

      local config = project.load_config(temp_dir)

      -- Should return empty/default config
      assert.is_table(config)
    end)

    it("should handle missing file", function()
      local config = project.load_config(temp_dir)

      assert.is_table(config)
    end)
  end)

  describe("setup", function()
    it("should initialize project from current directory", function()
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")

      local proj = project.setup(temp_dir)

      assert.is_table(proj)
      assert.is_not_nil(proj.root)
      assert.is_table(proj.config)
    end)

    it("should return nil if no project detected", function()
      local proj = project.setup(temp_dir)

      assert.is_nil(proj)
    end)
  end)
end)
