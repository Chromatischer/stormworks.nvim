-- Author: Nameous Changey
-- GitHub: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension
-- Workshop: https://steamcommunity.com/id/Bilkokuya/myworkshopfiles/?appid=573090
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

-- combines multiple scripts into one by following the require tree.
-- resulting script can then be passed through luamin to minify it (or alternate tools)

require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.TableUtils")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.StringUtils")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.FileSystemUtils")

---@class Combiner : BaseClass
---@field systemRequires string[] list of system libraries that are OK to import, but should be stripped
---@field filesByRequire table<string,string> table of require names -> filenames
---@field loadedFileData table<string,string> table of require names -> filecontents
LifeBoatAPI.Tools.Combiner = {

  ---@param cls Combiner
  ---@return Combiner
  new = function(cls)
    local this = LifeBoatAPI.Tools.BaseClass.new(cls)
    this.filesByRequire = {}
    this.loadedFileData = {}
    this.systemRequires = { "table", "math", "string" }
    this._logFilepath = nil
    this._logFileTruncated = false
    return this
  end,

  ---@param this Combiner
  ---@param filepath Filepath
  setLogFile = function(this, filepath)
    this._logFilepath = filepath
    this._logFileTruncated = false
  end,

  ---@param this Combiner
  ---@param text string
  _log = function(this, text)
    if not this._logFilepath then
      return
    end
    local path = this._logFilepath
    local dir = path:directory():linux()
    os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    local mode = this._logFileTruncated and "ab" or "wb"
    local file = io.open(path:linux(), mode)
    if not file then
      return
    end
    file:write(text .. "\n")
    file:close()
    this._logFileTruncated = true
  end,

  ---@param this Combiner
  ---@param rootDirectory Filepath sourcecode root folder, to load files from
  addRootFolder = function(this, rootDirectory)
    print("Adding rootFolder: " .. rootDirectory:linux())
    local filesByRequire = this:_getDataByRequire(rootDirectory)
    for _, value in ipairs(filesByRequire) do
      print("File: " .. value)
    end
    LifeBoatAPI.Tools.TableUtils.addRange(this.filesByRequire, filesByRequire)
  end,

  ---@param this Combiner
  ---@param entryPointFile Filepath
  ---@param outputFile Filepath
  combineFile = function(this, entryPointFile, outputFile)
    local text = LifeBoatAPI.Tools.FileSystemUtils.readAllText(entryPointFile)
    local combinedText = this:combine(text, entryPointFile)
    LifeBoatAPI.Tools.FileSystemUtils.writeAllText(outputFile, combinedText)

    return combinedText
  end,

  ---@param this Combiner
  ---@param data string
  combine = function(this, data, entryPointFile)
    data = "\n" .. data -- ensure the file starts with a new line, so any first-line requires get found
    this:_log(("== combine %s =="):format(entryPointFile:linux()))

    local requiresSeen = {}
    local filesSeen = {}
    local iterations = 0
    local MAX_ITER = 20000
    local keepSearching = true
    while keepSearching do
      keepSearching = false
      local require = data:match("\n%s-require%([\"'](..-)[\"']%)")
      if require then
        keepSearching = true
        local escapedRequire = LifeBoatAPI.Tools.StringUtils.escape(require)
        local fullstring = "\n%s-require%([\"']" .. escapedRequire .. "[\"']%)%s-"
        if requiresSeen[require] then
          -- already seen this, so we just cut it from the file
          this:_log("skip duplicate require " .. require)
          data = data:gsub(fullstring, "")
        else
          -- valid require to be replaced with the file contents
          requiresSeen[require] = true

          if this.filesByRequire[require] then
            local filename = this.filesByRequire[require]
            this:_log("resolve " .. require .. " -> " .. filename:linux())

            -- Avoid re-including the same file (guards circular/self requires with different names)
            local fileKey = filename:linux()
            if filesSeen[fileKey] then
              this:_log("skip already included file " .. fileKey)
              data = data:gsub(fullstring, "")
            else
              filesSeen[fileKey] = true

            -- only load each file's contentes one time
              if not this.loadedFileData[require] then
                this.loadedFileData[require] = LifeBoatAPI.Tools.FileSystemUtils.readAllText(filename)
              end

              local filedata = this.loadedFileData[require]
              data = data:gsub(fullstring, LifeBoatAPI.Tools.StringUtils.escapeSub("\n" .. filedata .. "\n"), 1) -- only first instance
            end
          elseif LifeBoatAPI.Tools.TableUtils.containsValue(this.systemRequires, require) then
            data = data:gsub(fullstring, "") -- remove system requires, without error, as long as they are allowed in the game
          else
            print("filesByRequire does not contain: " .. require)
            for _, value in ipairs(this.filesByRequire) do
              print("Contains: " .. value)
            end
            this:_log("missing require " .. require .. " in " .. entryPointFile:linux())
            error("Require " .. require .. " was not found when building: " .. entryPointFile:linux() .. "!")
          end
        end
      end

      iterations = iterations + 1
      if iterations > MAX_ITER then
        this:_log("aborting combine due to excessive iterations; possible unresolved require loop")
        break
      end
    end
    return data
  end,

  ---@param this Combiner
  ---@param rootDirectory Filepath
  _getDataByRequire = function(this, rootDirectory)
    local requiresToFilecontents = {}
    print("Searching: " .. rootDirectory:linux() .. " recursively!")
    local files = LifeBoatAPI.Tools.FileSystemUtils.findFilesRecursive(
      rootDirectory,
      { [".vscode"] = 1, ["_release"] = 1, ["_intermediate"] = 1, [".git"] = 1 },
      { ["lua"] = 1, ["luah"] = 1 }
    )

    for _, filename in ipairs(files) do
      if type(filename) ~= "table" then
        print("Filename is not Filepath object! " .. filename)
      end
      local requireName = filename:linux():gsub(LifeBoatAPI.Tools.StringUtils.escape(rootDirectory:linux()) .. "/", "")
      requireName = requireName:gsub("/", ".") -- slashes -> . style
      requireName = requireName:gsub("%.init.lua$", "") -- if name is init.lua, strip it
      requireName = requireName:gsub("%.lua$", "") -- if name ends in .lua, strip it
      requireName = requireName:gsub("%.luah$", "") -- "hidden" lua files

      requiresToFilecontents[requireName] = filename

      -- Also allow requires that are prefixed with the root folder name (e.g. require("project.module"))
      local rootBasename = rootDirectory:filename()
      if rootBasename and rootBasename ~= "" and requireName ~= "" then
        local prefixed = rootBasename .. "." .. requireName
        if not requiresToFilecontents[prefixed] then
          requiresToFilecontents[prefixed] = filename
        end
      end
    end

    return requiresToFilecontents
  end,
}
LifeBoatAPI.Tools.Class(LifeBoatAPI.Tools.Combiner)
