-- Author: Nameous Changey
-- GitHub: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension
-- Workshop: https://steamcommunity.com/id/Bilkokuya/myworkshopfiles/?appid=573090
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

require("sw-micro-project.lua.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
require("sw-micro-project.lua.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.TableUtils")
require("sw-micro-project.lua.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Filepath")

---@class FileSystemUtils
LifeBoatAPI.Tools.FileSystemUtils = {

  --- Copies the given source file to the given destination filepath
  ---@param sourceFilepath Filepath
  ---@param destinationFilepath Filepath
  copyFile = function(sourceFilepath, destinationFilepath)
    local fileContents = LifeBoatAPI.Tools.FileSystemUtils.readAllText(sourceFilepath)
    if fileContents then
      LifeBoatAPI.Tools.FileSystemUtils.writeAllText(destinationFilepath, fileContents)
    end
  end,

  ---@param filepath Filepath
  openForWrite = function(filepath)
    os.execute('mkdir -p "' .. filepath:directory():linux() .. '" 2>/dev/null')
    local file = io.open(filepath:linux(), "wb")
    return file
  end,

  ---reads all text from a file and returns it as a string
  ---@param filePath Filepath path to read from
  ---@return string text from the file
  readAllText = function(filePath)
    local file = io.open(filePath:linux(), "r")
    if not file then
      error(
        "File: "
          .. filePath.rawPath
          .. " as linux: "
          .. filePath:linux()
          .. " is nil!"
          .. "\nCheck that the file exists and the path is correct."
      )
    end
    local data = file:read("*a")
    file:close()
    return data
  end,

  ---writes the given text to a file, overwriting the existing file
  ---@param text string text to write to the file
  ---@param filePath Filepath path to write to
  writeAllText = function(filePath, text)
    local outputFileHandle = LifeBoatAPI.Tools.FileSystemUtils.openForWrite(filePath)
    outputFileHandle:write(text)
    outputFileHandle:close()
  end,

  ---@param dirPath Filepath
  ---@param pattern string? optional pattern to filter files (lua pattern, not shell glob)
  ---@return string[] list of filepaths
  findPathsInDir = function(dirPath, pattern)
    local result = {}

    -- Use vim.fn.glob to get files/directories
    local globPattern = dirPath:linux() .. "/*"
    local items = vim.fn.glob(globPattern, false, true)

    if pattern then
      -- Filter results using lua pattern matching
      for _, item in ipairs(items) do
        local basename = vim.fn.fnamemodify(item, ":t")
        if string.match(basename, pattern) then
          result[#result + 1] = basename
        end
      end
    else
      -- Return all basenames without filtering
      for _, item in ipairs(items) do
        local basename = vim.fn.fnamemodify(item, ":t")
        result[#result + 1] = basename
      end
    end

    return result
  end,

  ---@param dirPath Filepath
  ---@return string[] list of directory names
  findDirsInDir = function(dirPath)
    local result = {}
    local globPattern = dirPath:linux() .. "/*"
    local items = vim.fn.glob(globPattern, false, true)

    for _, item in ipairs(items) do
      if vim.fn.isdirectory(item) == 1 then
        local basename = vim.fn.fnamemodify(item, ":t")
        result[#result + 1] = basename
      end
    end

    return result
  end,

  ---@param dirPath Filepath
  ---@return string[] list of filenames
  findFilesInDir = function(dirPath)
    if vim.fn.isdirectory(dirPath:linux()) == 0 then
      print(dirPath:linux() .. " is file!")
      return { vim.fn.fnamemodify(dirPath:linux(), ":t") }
    end
    local result = {}
    local globPattern = dirPath:linux() .. "/*"
    local items = vim.fn.glob(globPattern, false, true)

    for _, item in ipairs(items) do
      if vim.fn.isdirectory(item) == 0 then
        local basename = vim.fn.fnamemodify(item, ":t")
        result[#result + 1] = basename
      end
    end

    return result
  end,

  ---@param dirPath Filepath root to start search in
  ---@param ignore table? optional table of directory names to ignore
  ---@param extensions table? optional table of file extensions to include (e.g., {lua = true, txt = true})
  ---@return Filepath[] list of filepaths in all subfolders
  findFilesRecursive = function(dirPath, ignore, extensions)
    local files = {}
    local dirsToProcess = { dirPath }

    while #dirsToProcess > 0 do
      local currentDir = table.remove(dirsToProcess)

      -- Get files in current directory
      local filesInDir = LifeBoatAPI.Tools.FileSystemUtils.findFilesInDir(currentDir)
      for _, basename in ipairs(filesInDir) do
        local ext = LifeBoatAPI.Tools.StringUtils.split(basename, ".")
        local fileExt = ext[#ext] -- Get last part as extension

        if extensions and extensions[fileExt] then
          local file = currentDir:add("/" .. basename)
          table.insert(files, file)
        end
      end

      -- Get subdirectories to process
      local dirsInDir = LifeBoatAPI.Tools.FileSystemUtils.findDirsInDir(currentDir)
      for _, dirname in ipairs(dirsInDir) do
        if not ignore or not ignore[dirname] then
          local subDir = currentDir:add("/" .. dirname)
          table.insert(dirsToProcess, subDir)
        end
      end
    end

    return files
  end,
}
