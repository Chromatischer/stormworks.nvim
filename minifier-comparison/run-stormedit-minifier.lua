-- Test runner for StormEdit minifier (stravant lua-minify)
dofile("/home/user/stormworks.nvim/minifier-comparison/stormedit-minifier.lua")

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

-- Test files
local testFiles = {
    "/home/user/stormworks.nvim/minifier-comparison/test-input/TWS-Iteration-Y.lua",
    "/home/user/stormworks.nvim/minifier-comparison/test-input/simple-test.lua",
}

print("=" .. string.rep("=", 60))
print("StormEdit Minifier (stravant lua-minify) Test Results")
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

        local minified, minifyErr = minify(source)
        if minified then
            local minifiedSize = #minified
            local reduction = ((originalSize - minifiedSize) / originalSize) * 100

            print("Minified size: " .. minifiedSize .. " chars")
            print("Reduction: " .. string.format("%.1f%%", reduction))

            -- Write output
            local outputPath = "/home/user/stormworks.nvim/minifier-comparison/stormedit-output/" .. filename
            writeFile(outputPath, minified)
            print("Output written to: stormedit-output/" .. filename)
        else
            print("ERROR: " .. tostring(minifyErr))
        end
    end
end

print("\n" .. "=" .. string.rep("=", 60))
