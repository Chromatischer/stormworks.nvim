-- Test runner for stormworks.nvim minifier (LifeBoatAPI)

-- Setup the package path
package.path = "/home/user/stormworks.nvim/lua/?.lua;" .. package.path

-- Load the LifeBoatAPI modules
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.StringUtils")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Filepath")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.FileSystemUtils")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.Minimizer")

local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "Could not open file: " .. path
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function writeFile(path, content)
    local file = io.open(path, "w")
    if not file then
        return false, "Could not write file: " .. path
    end
    file:write(content)
    file:close()
    return true
end

-- Create the constants loader (includes Stormworks API names to avoid renaming)
local constants = LifeBoatAPI.Tools.ParsingConstantsLoader:new()

-- Minimizer parameters (aggressive minification)
local params = {
    reduceAllWhitespace = true,
    reduceNewlines = true,
    removeRedundancies = true,
    shortenVariables = true,
    shortenGlobals = true,
    shortenNumbers = true,
    removeComments = true,
    shortenStringDuplicates = true,
    forceNCBoilerplate = false,
    forceBoilerplate = false,
}

-- Create minimizer
local minimizer = LifeBoatAPI.Tools.Minimizer:new(constants, params)

-- Test files
local testFiles = {
    "/home/user/stormworks.nvim/minifier-comparison/test-input/TWS-Iteration-Y.lua",
    "/home/user/stormworks.nvim/minifier-comparison/test-input/simple-test.lua",
}

print("=" .. string.rep("=", 60))
print("Stormworks.nvim Minifier (LifeBoatAPI) Test Results")
print("=" .. string.rep("=", 60))

for _, inputPath in ipairs(testFiles) do
    local filename = inputPath:match("([^/]+)$")
    print("\nProcessing: " .. filename)
    print("-" .. string.rep("-", 40))

    local source, err = readFile(inputPath)
    if not source then
        print("ERROR: " .. err)
    else
        local originalSize = #source
        print("Original size: " .. originalSize .. " chars")

        local ok, minified = pcall(function()
            return minimizer:minimize(source)
        end)

        if ok and minified then
            local minifiedSize = #minified
            local reduction = ((originalSize - minifiedSize) / originalSize) * 100

            print("Minified size: " .. minifiedSize .. " chars")
            print("Reduction: " .. string.format("%.1f%%", reduction))

            -- Write output
            local outputPath = "/home/user/stormworks.nvim/minifier-comparison/stormworks-nvim-output/" .. filename
            writeFile(outputPath, minified)
            print("Output written to: stormworks-nvim-output/" .. filename)
        else
            print("ERROR: " .. tostring(minified))
        end
    end
end

print("\n" .. "=" .. string.rep("=", 60))
