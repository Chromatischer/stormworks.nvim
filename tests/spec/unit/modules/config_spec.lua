describe("Config", function()
  local MockVim = require("mock_vim")
  local config

  setup(function()
    -- Install vim mock
    _G.vim = MockVim

    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

    config = require("stormworks.modules.config")
  end)

  before_each(function()
    MockVim.reset()
  end)

  describe("default configuration", function()
    it("should have config table", function()
      assert.is_table(config.config)
    end)

    it("should have default project markers", function()
      assert.is_table(config.config.project_markers)
      assert.equals(1, #config.config.project_markers)
      assert.equals(".microproject", config.config.project_markers[1])
    end)

    it("should have default user_lib_paths", function()
      assert.is_table(config.config.user_lib_paths)
    end)

    it("should have default keymaps", function()
      assert.is_table(config.config.keymaps)
    end)
  end)

  describe("setup", function()
    it("should merge user configuration", function()
      local user_config = {
        build_command = "custom_build"
      }

      config.setup(user_config)

      assert.equals("custom_build", config.config.build_command)
      -- Other defaults should still exist
      assert.is_table(config.config.project_markers)
    end)

    it("should deep merge nested tables", function()
      local user_config = {
        keymaps = {
          build = "B"
        }
      }

      config.setup(user_config)

      -- User option
      assert.equals("B", config.config.keymaps.build)
      -- Other keymap options should still exist from defaults
      assert.is_not_nil(config.config.keymaps.mark)
    end)

    it("should keep default config if no user config provided", function()
      config.setup()

      assert.is_table(config.config)
      assert.is_table(config.config.project_markers)
      assert.is_table(config.config.keymaps)
    end)
  end)
end)
