-- Author: Nameous Changey
-- GitHub: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension
-- Workshop: https://steamcommunity.com/id/Bilkokuya/myworkshopfiles/?appid=573090
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.StringUtils")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Filepath")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.FileSystemUtils")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.RedundancyRemover")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.StringCommentsParser")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableShortener")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.GlobalVariableReducer")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.NumberLiteralReducer")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.HexadecimalConverter")

TOTAL_CHAR_LIMIT = 8100 -- Giving some wiggle room just like nameouschangey says to!

---@class MinimizerParams
---@field reduceAllWhitespace   boolean if true, shortens all whitespace duplicates where possible
---@field reduceNewlines        boolean if true, reduces duplicate newlines but not other whitespace
---@field removeRedundancies    boolean if true, removes redundant code sections using the ---@section syntax
---@field shortenVariables      boolean if true, shortens variables down to 1 or 2 character names
---@field shortenGlobals        boolean if true, shortens the sw-global functions, such as screen.drawRect, to e.g. s=screen.drawRect
---@field shortenNumbers        boolean if true, shortens numbers, including removing duplicate number literals and removing leading 0s
---@field forceNCBoilerplate    boolean (recommend false) forces the NC boilerplate to be output, even if it makes the file exceed 4000 characters
---@field forceBoilerplate      boolean (recommend false) forces the user boilerplate to be output, even if it makes the file exceed 4000 characters
---@field removeComments        boolean if true, strips all comments from the output
---@field shortenStringDuplicates boolean if true, reduce duplicate string literals
---@field skipCombinedFileOutput  boolean if true, doesn't output the combined file - to speed up the build process
---@field stripOnDebugDraw      boolean if true, removes any user-defined onDebugDraw() function from compiled output
---@field stripOnAttatch      boolean if true, removes any user-defined onAttatch() function from compiled output

---@class Minimizer : BaseClass
---@field constants ParsingConstantsLoader list of external, global keywords
---@field params MinimizerParams table of params for turning on/off functionality
LifeBoatAPI.Tools.Minimizer = {
  ---@param cls Minimizer
  ---@param constants ParsingConstantsLoader
  ---@param params MinimizerParams
  ---@return Minimizer
  new = function(cls, constants, params)
    local this = LifeBoatAPI.Tools.BaseClass.new(cls)
    this.constants = constants

    this.params = params or {}
    this.params.removeComments = LifeBoatAPI.Tools.DefaultBool(this.params.removeComments, true)
    this.params.reduceAllWhitespace = LifeBoatAPI.Tools.DefaultBool(this.params.reduceAllWhitespace, true)
    this.params.reduceNewlines = LifeBoatAPI.Tools.DefaultBool(this.params.reduceNewlines, true)
    this.params.removeRedundancies = LifeBoatAPI.Tools.DefaultBool(this.params.removeRedundancies, true)
    this.params.shortenVariables = LifeBoatAPI.Tools.DefaultBool(this.params.shortenVariables, true)
    this.params.shortenGlobals = LifeBoatAPI.Tools.DefaultBool(this.params.shortenGlobals, true)
    this.params.shortenNumbers = LifeBoatAPI.Tools.DefaultBool(this.params.shortenNumbers, true)
    this.params.shortenStringDuplicates = LifeBoatAPI.Tools.DefaultBool(this.params.shortenStringDuplicates, true)
    this.params.forceNCBoilerplate = LifeBoatAPI.Tools.DefaultBool(this.params.forceNCBoilerplate, false)
    this.params.forceBoilerplate = LifeBoatAPI.Tools.DefaultBool(this.params.forceBoilerplate, false)
    this.params.skipCombinedFileOutput = LifeBoatAPI.Tools.DefaultBool(this.params.skipCombinedFileOutput, false)
    this.params.stripOnDebugDraw = LifeBoatAPI.Tools.DefaultBool(this.params.stripOnDebugDraw, true)
    this.params.stripOnAttatch = LifeBoatAPI.Tools.DefaultBool(this.params.stripOnAttatch, true)

    return this
  end,

  ---Minimizes the content of the given file and saves it to disk
  ---@param outPath Filepath path to save to or nil to save over the original file
  ---@param this Minimizer
  ---@param inPath Filepath
  ---@return string minimized for use in any other purpose
  minimizeFile = function(this, inPath, outPath, boilerplate)
    local text = LifeBoatAPI.Tools.FileSystemUtils.readAllText(inPath)
    local minimized, newsize = this:minimize(text, boilerplate)
    LifeBoatAPI.Tools.FileSystemUtils.writeAllText(outPath, minimized)

    return minimized, newsize
  end,

  ---@param text string text to be minimized
  ---@param this Minimizer
  ---@return string minimized
  ---@return number sizeWithoutBoilerplate
  minimize = function(this, text, boilerplate)
    boilerplate = boilerplate or ""

    -- insert space at the start prevents issues where the very first character in the file, is part of a variable name
    text = " " .. text .. "\n\n"

    -- remove all redundant strings and comments, avoid these confusing the parse
    local variableRenamer = LifeBoatAPI.Tools.VariableRenamer:new(this.constants)
    local parser = LifeBoatAPI.Tools.StringCommentsParser:new(
      not this.params.removeComments,
      LifeBoatAPI.Tools.StringReplacer:new(variableRenamer)
    )
    text = parser:removeStringsAndComments(text, function(i, text)
      return text:sub(i, i + 10) == "---@section" or text:sub(i, i + 13) == "---@endsection"
    end)

    -- remove all redudant code sections (will become exponentially slower as the codebase gets bigger)
    if this.params.removeRedundancies then
      local remover = LifeBoatAPI.Tools.RedundancyRemover:new()
      text = remover:removeRedundantCode(text)
    end

    -- re-parse to remove all code-section comments now we're done with them
    text = parser:removeStringsAndComments(text)

    -- strip user onDebugDraw() implementations entirely if requested
    if this.params.stripOnDebugDraw then
      text = this:_stripFunctionByName(text, "onDebugDraw")
    end

    -- strip user onAttatch() implementations entirely if requested
    if this.params.stripOnAttatch then
      text = this:_stripFunctionByName(text, "onAttatch")
    end

    -- strip user onAttatch() implementations entirely if requested
    if this.params.stripOnDebugDraw then
      text = this:_stripFunctionByName(text, "onAttatch")
    end

    -- rename variables so everything is consistent (if creating new globals happens, it's important they have unique names)
    if this.params.shortenVariables then
      local shortener = LifeBoatAPI.Tools.VariableShortener:new(variableRenamer, this.constants)
      text = shortener:shortenVariables(text)
    end

    -- final step still todo, replace all external globals if they're used more than once
    if this.params.shortenGlobals then
      local globalShortener = LifeBoatAPI.Tools.GlobalVariableReducer:new(variableRenamer, this.constants)
      text = globalShortener:shortenGlobals(text)
    end

    -- fix hexadecimals
    local hexadecimalFixer = LifeBoatAPI.Tools.HexadecimalConverter:new()
    text = hexadecimalFixer:fixHexademicals(text)

    -- reduce numbers
    if this.params.shortenNumbers then
      local numberShortener = LifeBoatAPI.Tools.NumberLiteralReducer:new(variableRenamer)
      text = numberShortener:shortenNumbers(text)
    end

    -- rename variables as short as we can get (second pass)
    -- New renamer, so everything gets a new name again - now we can do it regarding frequency of use
    if this.params.shortenVariables then
      local shortener =
        LifeBoatAPI.Tools.VariableShortener:new(LifeBoatAPI.Tools.VariableRenamer:new(this.constants), this.constants)
      text = shortener:shortenVariables(text)
    end

    -- remove all unnecessary whitespace, etc. (a real minifier will do a better job, but this gets close enough for us)
    if this.params.reduceNewlines then
      text = LifeBoatAPI.Tools.StringUtils.subAll(text, "\n%s*\n%s*\n", "\n\n") -- remove empty lines
    end

    if this.params.reduceAllWhitespace then
      text = this:_reduceWhitespace(text)
    end

    -- repopulate the original string data now it's safe
    text = parser:repopulateStrings(text, this.params.shortenStringDuplicates)

    local sizeWithoutBoilerplate = #text

    -- Calculate boilerplate sizes
    local nameousSize = 233 + #tostring(sizeWithoutBoilerplate) + #tostring(#text)
    local predictedBoilerplateSize = 0

    if this.params.forceNCBoilerplate or (#text + #boilerplate + nameousSize < TOTAL_CHAR_LIMIT) then
      predictedBoilerplateSize = nameousSize + #boilerplate
    elseif this.params.forceBoilerplate or (#text + #boilerplate < TOTAL_CHAR_LIMIT) then
      predictedBoilerplateSize = #boilerplate
    end

    -- Create Appendix for Port creators
    local additionalBoilerplate = [[Ported for Neovim by Chromatischer]]

    -- Create Nameous boilerplate comment
    local nameousBoilerplate = ([[-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
    -- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
    --      By Nameous Changey
    -- %s
    -- Minimized Size: %s (%s with comment) chars]]):format(
      additionalBoilerplate,
      sizeWithoutBoilerplate,
      sizeWithoutBoilerplate + predictedBoilerplateSize
    )

    -- Add spacing only if comments are kept
    local spacing = this.params.removeComments and "" or "\n\n"

    -- Add boilerplate when space allows
    local fullBoilerplateFits = this.params.forceNCBoilerplate
      or (#text + #boilerplate + #nameousBoilerplate < TOTAL_CHAR_LIMIT)
    local normalBoilerplateFits = this.params.forceBoilerplate or (#text + #boilerplate < TOTAL_CHAR_LIMIT)

    if fullBoilerplateFits then
      text = boilerplate .. "--\n" .. nameousBoilerplate .. "\n" .. spacing .. text
    elseif normalBoilerplateFits then
      text = boilerplate .. "\n" .. spacing .. text
    end

    return text, sizeWithoutBoilerplate
  end,

  ---@param this Minimizer
  ---@param text string text to minimize
  ---@return string text
  _reduceWhitespace = function(this, text)
    -- remove duplicate spacing
    text = LifeBoatAPI.Tools.StringUtils.subAll(text, "%s%s", "\n")

    -- remove whitespace around certain operators
    local characters = {
      "=",
      ",",
      ">",
      "<",
      "+",
      "-",
      "*",
      "/",
      "%",
      "{",
      "}",
      "(",
      ")",
      "[",
      "]",
      "^",
      "|",
      "~",
      "#",
      "..",
    }
    for _, character in ipairs(characters) do
      text = this:_reduceWhitespaceCharacter(text, character)
    end

    -- ,} ;} -> }
    text = LifeBoatAPI.Tools.StringUtils.subAll(text, "[,;]}", "}")
    return text
  end,

  ---@param this Minimizer
  ---@param text string text to minimize
  ---@param character string character/operator to remove space around
  ---@return string text
  _reduceWhitespaceCharacter = function(this, text, character)
    return LifeBoatAPI.Tools.StringUtils.subAll(
      text,
      "%s*" .. LifeBoatAPI.Tools.StringUtils.escape(character) .. "%s*",
      LifeBoatAPI.Tools.StringUtils.escapeSub(character)
    )
  end,

  --- Remove any function with the specified name ... end (and assignment forms) from the source text
  --- This runs after strings/comments are stripped, so simple token scanning is safe (note that this could fail with if statements)
  ---@param this Minimizer
  ---@param text string
  ---@param functionName string
  ---@return string
  _stripFunctionByName = function(this, text, functionName)

    ---finds the next function signature
    ---@param s string The input Text
    ---@param idx any
    ---@param funcName string
    ---@return nil|integer ep, nil|integer sp
    local function find_next_signature(s, idx, funcName)
      local candidates = {} --a table to hold the 
      local patternBase = "%f[%w_]" .. funcName .. "%s*%b()"
      local sp, ep
      sp, ep = s:find("%f[%w_]local%s+function%s+" .. patternBase, idx)
      if sp then
        table.insert(candidates, { sp = sp, ep = ep })
      end
      sp, ep = s:find("%f[%w_]function%s+" .. patternBase, idx)
      if sp then
        table.insert(candidates, { sp = sp, ep = ep })
      end
      sp, ep = s:find("%f[%w_]local%s+" .. funcName .. "%s*=%s*function%s*%b()", idx)
      if sp then
        table.insert(candidates, { sp = sp, ep = ep })
      end
      sp, ep = s:find("%f[%w_]" .. funcName .. "%s*=%s*function%s*%b()", idx)
      if sp then
        table.insert(candidates, { sp = sp, ep = ep })
      end
      table.sort(candidates, function(a, b)
        return a.sp < b.sp
      end)
      if #candidates == 0 then
        return nil, nil
      end
      return candidates[1].sp, candidates[1].ep
    end

    local function find_matching_end(s, after_sig)
      local depth = 0
      local i = after_sig + 1
      while true do
        --find any functions
        local f1 = s:find("%f[%w_]function%f[^%w_]", i)

        --find any if statements
        local i1 = s:find("%f[%w_]if%f[^%w_]", i)

        --find any do statements
        local d1 = s:find("%f[%w_]do%f[^%w_]", i)

        local e1 = s:find("%f[%w_]end%f[^%w_]", i)

        --if there are no more ends and no more keywords then return end of file
        if not f1 and not i1 and not d1 and not e1 then
          return #s + 1
        end

        local isE1BeforeF1 = e1 and (e1 < (f1 or #s))
        local isE1BeforeI1 = e1 and (e1 < (i1 or #s))
        local isE1BeforeD1 = e1 and (e1 < (d1 or #s))
        --if there is an end without a keyword that is found before it in this pass then
        if e1 and (not (f1 or i1 or d1) or (isE1BeforeF1 and isE1BeforeI1 and isE1BeforeD1)) then
          if depth == 0 then --if we are at depth 0 then return the position after the end
            return e1 + 3 -- include 'end'
          end

          --otherwise decrement the depth and resume looking from after the end
          depth = depth - 1 
          i = e1 + 3
        else
          -- else if there was a keyword before the end in this pass
          -- find which word matched first and use that
          depth = depth + 1
          local firstMatch = math.min(f1 or math.huge, i1 or math.huge, d1 or math.huge)
          if f1 and firstMatch == f1 then
            i = f1 + 8
          elseif i1 and firstMatch == i1 then
            i = i1 + 2
          else
            i = d1 + 2
          end
        end
      end
    end

    local i = 1
    while true do
      local s1, s2 = find_next_signature(text, i, functionName)
      if not s1 then --if there is no sp then break out
        break
      end
      local endpos = find_matching_end(text, s2)
      text = text:sub(1, s1 - 1) .. text:sub(endpos)
      i = s1
    end
    return text
  end,
}
LifeBoatAPI.Tools.Class(LifeBoatAPI.Tools.Minimizer)
