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
    it("should have default build options", function()
      assert.is_table(config.build)
      assert.is_table(config.build.minifier)
    end)

    it("should have default LÖVE options", function()
      assert.is_table(config.love)
    end)

    it("should have default library paths", function()
      assert.is_table(config.libraries)
    end)

    it("should have default keymaps", function()
      assert.is_table(config.keys)
    end)
  end)

  describe("setup", function()
    it("should merge user configuration", function()
      local user_config = {
        build = {
          minifier = {
            shortenVariables = false
          }
        }
      }

      local merged = config.setup(user_config)

      assert.is_false(merged.build.minifier.shortenVariables)
      -- Other defaults should still exist
      assert.is_table(merged.love)
    end)

    it("should deep merge nested tables", function()
      local user_config = {
        build = {
          minifier = {
            shortenVariables = false
          }
        }
      }

      local merged = config.setup(user_config)

      -- User option
      assert.is_false(merged.build.minifier.shortenVariables)
      -- Other minifier options should still exist from defaults
      assert.is_not_nil(merged.build.minifier.removeComments)
    end)

    it("should return default config if no user config provided", function()
      local merged = config.setup()

      assert.is_table(merged)
      assert.is_table(merged.build)
      assert.is_table(merged.love)
    end)
  end)
end)
