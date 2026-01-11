describe("Builder", function()
  local TestUtils = require("test_utils")
  local builder_class
  local filepath_class
  local temp_dir

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.Builder")
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Filepath")
    builder_class = LifeBoatAPI.Tools.Builder
    filepath_class = LifeBoatAPI.Tools.Filepath
  end)

  before_each(function()
    temp_dir = TestUtils.create_temp_dir()
    os.execute("mkdir -p " .. temp_dir .. "/_release")
    os.execute("mkdir -p " .. temp_dir .. "/_intermediate")
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("buildMicrocontroller", function()
    it("should build simple microcontroller script", function()
      -- Create a simple script
      local script = TestUtils.create_simple_mc_script()
      local script_path = temp_dir .. "/test_mc.lua"
      TestUtils.write_file(script_path, script)

      -- Create empty docs file
      local docs_path = temp_dir .. "/mc-docs.lua"
      TestUtils.write_file(docs_path, "")

      -- Build
      local builder = builder_class:new(
        {filepath_class:new(temp_dir)},
        filepath_class:new(temp_dir),
        filepath_class:new(docs_path),
        nil
      )

      local orig, combined, final, outFile = builder:buildMicrocontroller(
        "test_mc.lua",
        filepath_class:new(script_path),
        {}
      )

      -- Assertions
      assert.is_string(final)
      assert.is_true(#final > 0)

      -- Output should be valid Lua
      local is_valid, err = TestUtils.is_valid_lua(final)
      assert.is_true(is_valid, "Output should be valid Lua: " .. tostring(err))
    end)
  end)

  describe("buildAddonScript", function()
    it("should build addon script", function()
      -- Create a simple addon script
      local script = [[
        function onCreate()
          -- addon init
        end

        function onTick()
          -- addon tick
        end
      ]]
      local script_path = temp_dir .. "/test_addon.lua"
      TestUtils.write_file(script_path, script)

      -- Create empty docs file
      local docs_path = temp_dir .. "/addon-docs.lua"
      TestUtils.write_file(docs_path, "")

      -- Build
      local builder = builder_class:new(
        {filepath_class:new(temp_dir)},
        filepath_class:new(temp_dir),
        nil,
        filepath_class:new(docs_path)
      )

      local orig, combined, final, outFile = builder:buildAddonScript(
        "test_addon.lua",
        filepath_class:new(script_path),
        {}
      )

      -- Assertions
      assert.is_string(final)
      assert.is_true(#final > 0)
    end)
  end)
end)
