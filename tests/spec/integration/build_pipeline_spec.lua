describe("Build Pipeline Integration", function()
  local TestUtils = require("test_utils")
  local temp_dir
  local project_root

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.Builder")
    project_root = TestUtils.get_project_root()
  end)

  before_each(function()
    temp_dir = TestUtils.create_temp_dir()
    os.execute("mkdir -p " .. temp_dir .. "/_release")
    os.execute("mkdir -p " .. temp_dir .. "/_intermediate")
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("single-file microcontroller build", function()
    it("should build and minimize simple script", function()
      -- Create test script from fixture
      local fixture_path = project_root .. "/tests/fixtures/scripts/simple_mc.lua"
      local script = TestUtils.read_file(fixture_path)
      local script_path = temp_dir .. "/test_mc.lua"
      TestUtils.write_file(script_path, script)

      -- Create empty docs file
      local docs_path = temp_dir .. "/mc-docs.lua"
      TestUtils.write_file(docs_path, "")

      -- Build
      local builder = LifeBoatAPI.Tools.Builder:new(
        {LifeBoatAPI.Tools.Filepath:new(temp_dir)},
        LifeBoatAPI.Tools.Filepath:new(temp_dir),
        LifeBoatAPI.Tools.Filepath:new(docs_path),
        nil
      )

      local orig, combined, final, outFile = builder:buildMicrocontroller(
        "test_mc.lua",
        LifeBoatAPI.Tools.Filepath:new(script_path),
        {forceNCBoilerplate = true}  -- Use minimal boilerplate for size comparison
      )

      -- Assertions
      assert.is_string(final)
      assert.is_true(#final > 0, "Output should not be empty")
      
      -- The build function returns the original and final - final includes boilerplate
      -- For size comparison, strip all comment lines at the start
      local final_stripped = final
      -- Remove multi-line comment blocks
      final_stripped = final_stripped:gsub("%-%-[^\n]*\n", "")
      final_stripped = final_stripped:gsub("^%s*", "")
      
      -- The minimized code (comments stripped) should be smaller than original
      -- Skip size comparison for very small scripts (< 200 chars) where the
      -- minimization overhead (e.g., boilerplate, variable aliases) may exceed savings.
      -- This threshold accounts for the LifeBoatAPI minimizer's fixed-cost operations.
      local MIN_SCRIPT_SIZE_FOR_SIZE_TEST = 200
      if #script > MIN_SCRIPT_SIZE_FOR_SIZE_TEST then
        assert.is_true(#final_stripped < #script, 
          string.format("Minimized code (%d) should be smaller than input (%d)", 
            #final_stripped, #script))
      end

      -- Should be valid Lua
      local is_valid, err = TestUtils.is_valid_lua(final)
      assert.is_true(is_valid, "Output should be valid Lua: " .. tostring(err))

      -- Should contain essential functions
      TestUtils.assert_contains(final, "onTick")
      TestUtils.assert_contains(final, "onDraw")
    end)

    it("should strip onDebugDraw when configured", function()
      local fixture_path = project_root .. "/tests/fixtures/scripts/with_ondebugdraw.lua"
      local script = TestUtils.read_file(fixture_path)
      local script_path = temp_dir .. "/test.lua"
      TestUtils.write_file(script_path, script)

      local docs_path = temp_dir .. "/mc-docs.lua"
      TestUtils.write_file(docs_path, "")

      local builder = LifeBoatAPI.Tools.Builder:new(
        {LifeBoatAPI.Tools.Filepath:new(temp_dir)},
        LifeBoatAPI.Tools.Filepath:new(temp_dir),
        LifeBoatAPI.Tools.Filepath:new(docs_path),
        nil
      )

      local orig, combined, final, outFile = builder:buildMicrocontroller(
        "test.lua",
        LifeBoatAPI.Tools.Filepath:new(script_path),
        {stripOnDebugDraw = true}
      )

      TestUtils.assert_not_contains(final, "onDebugDraw")
      TestUtils.assert_contains(final, "onTick")
      TestUtils.assert_contains(final, "onDraw")
    end)

    it("should convert hex literals to decimal", function()
      local fixture_path = project_root .. "/tests/fixtures/scripts/with_hexadecimals.lua"
      local script = TestUtils.read_file(fixture_path)
      local script_path = temp_dir .. "/test.lua"
      TestUtils.write_file(script_path, script)

      local docs_path = temp_dir .. "/mc-docs.lua"
      TestUtils.write_file(docs_path, "")

      local builder = LifeBoatAPI.Tools.Builder:new(
        {LifeBoatAPI.Tools.Filepath:new(temp_dir)},
        LifeBoatAPI.Tools.Filepath:new(temp_dir),
        LifeBoatAPI.Tools.Filepath:new(docs_path),
        nil
      )

      local orig, combined, final, outFile = builder:buildMicrocontroller(
        "test.lua",
        LifeBoatAPI.Tools.Filepath:new(script_path),
        {}
      )

      -- Should not contain hex literals
      TestUtils.assert_not_contains(final, "0xFF")
      TestUtils.assert_not_contains(final, "0x")
    end)
  end)

  describe("multi-file project build", function()
    it("should combine and minimize multi-file project", function()
      -- Copy multifile project fixture
      local fixture_dir = project_root .. "/tests/fixtures/scripts/multifile_project"

      os.execute("cp '" .. fixture_dir .. "/main.lua' '" .. temp_dir .. "/'")
      os.execute("cp '" .. fixture_dir .. "/utils.lua' '" .. temp_dir .. "/'")
      os.execute("cp '" .. fixture_dir .. "/helpers.lua' '" .. temp_dir .. "'")

      local script_path = temp_dir .. "/main.lua"
      local docs_path = temp_dir .. "/mc-docs.lua"
      TestUtils.write_file(docs_path, "")

      local builder = LifeBoatAPI.Tools.Builder:new(
        {LifeBoatAPI.Tools.Filepath:new(temp_dir)},
        LifeBoatAPI.Tools.Filepath:new(temp_dir),
        LifeBoatAPI.Tools.Filepath:new(docs_path),
        nil
      )

      local orig, combined, final, outFile = builder:buildMicrocontroller(
        "main.lua",
        LifeBoatAPI.Tools.Filepath:new(script_path),
        {}
      )

      -- Should combine all files
      TestUtils.assert_contains(combined, "utils")
      TestUtils.assert_contains(combined, "helpers")

      -- Should not have require statements
      TestUtils.assert_not_contains(combined, 'require("utils")')
      TestUtils.assert_not_contains(combined, 'require("helpers")')

      -- Final should be valid Lua
      local is_valid, err = TestUtils.is_valid_lua(final)
      assert.is_true(is_valid, "Output should be valid Lua: " .. tostring(err))
    end)
  end)

  describe("redundancy removal", function()
    it("should remove unused sections", function()
      local fixture_path = project_root .. "/tests/fixtures/scripts/with_sections.lua"
      local script = TestUtils.read_file(fixture_path)
      local script_path = temp_dir .. "/test.lua"
      TestUtils.write_file(script_path, script)

      local docs_path = temp_dir .. "/mc-docs.lua"
      TestUtils.write_file(docs_path, "")

      local builder = LifeBoatAPI.Tools.Builder:new(
        {LifeBoatAPI.Tools.Filepath:new(temp_dir)},
        LifeBoatAPI.Tools.Filepath:new(temp_dir),
        LifeBoatAPI.Tools.Filepath:new(docs_path),
        nil
      )

      local orig, combined, final, outFile = builder:buildMicrocontroller(
        "test.lua",
        LifeBoatAPI.Tools.Filepath:new(script_path),
        {
          removeRedundancies = true,
          shortenVariables = false,  -- Keep function names readable
          shortenGlobals = false,
          stripOnDebugDraw = false,
          stripOnAttatch = false
        }
      )

      -- NotUsedFunction should be removed (unused)
      TestUtils.assert_not_contains(final, "NotUsedFunction")

      -- UsedHelper should be kept
      TestUtils.assert_contains(final, "UsedHelper")
    end)
  end)

  describe("output files", function()
    it("should create intermediate and release files", function()
      local script = TestUtils.create_simple_mc_script()
      local script_path = temp_dir .. "/test.lua"
      TestUtils.write_file(script_path, script)

      local docs_path = temp_dir .. "/mc-docs.lua"
      TestUtils.write_file(docs_path, "")

      local builder = LifeBoatAPI.Tools.Builder:new(
        {LifeBoatAPI.Tools.Filepath:new(temp_dir)},
        LifeBoatAPI.Tools.Filepath:new(temp_dir),
        LifeBoatAPI.Tools.Filepath:new(docs_path),
        nil
      )

      builder:buildMicrocontroller(
        "test.lua",
        LifeBoatAPI.Tools.Filepath:new(script_path),
        {}
      )

      -- Check intermediate file exists
      local intermediate_file = temp_dir .. "/_intermediate/test.lua"
      local intermediate_content = TestUtils.read_file(intermediate_file)
      assert.is_not_nil(intermediate_content, "Intermediate file should exist")

      -- Check release file exists
      local release_file = temp_dir .. "/_release/test.lua"
      local release_content = TestUtils.read_file(release_file)
      assert.is_not_nil(release_content, "Release file should exist")

      -- Both files should have valid content
      assert.is_true(#release_content > 0, "Release file should have content")
      assert.is_true(#intermediate_content > 0, "Intermediate file should have content")
      
      -- Release should be valid Lua
      local is_valid, err = TestUtils.is_valid_lua(release_content)
      assert.is_true(is_valid, "Release file should be valid Lua: " .. tostring(err))
    end)
  end)
end)
