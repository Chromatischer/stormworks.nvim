-- Author: Nameous Changey
-- GitHub: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension
-- Workshop: https://steamcommunity.com/id/Bilkokuya/myworkshopfiles/?appid=573090
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.TableUtils")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.StringUtils")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.StringBuilder")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.VariableRenamer")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")

--- Finds and converts all Hexadecimals into decimals
--- Stormworks doesn't natively support Hex numbers (0x123 is fine, 0xfff is incorrect caught as an error), this enables them
---@class HexadecimalConverter : BaseClass
LifeBoatAPI.Tools.HexadecimalConverter = {

  ---@return HexadecimalConverter
  new = function(cls)
    local this = LifeBoatAPI.Tools.BaseClass.new(cls)
    return this
  end,

  ---@param this HexadecimalConverter
  fixHexademicals = function(this, text)
    local stringUtils = LifeBoatAPI.Tools.StringUtils

    -- variables shortened are not keywords, and not global names (because those are a pita)
    local hexValues = stringUtils.find(text, "[^%w_](0x%x+)")
    for i = 1, #hexValues do
      local hexVal = hexValues[i]
      local hexAsNum = tonumber(hexVal.captures[1])
      local decimalStr = tostring(hexAsNum)

      -- Only convert if decimal representation is shorter or equal length
      -- This saves chars for large hex values like 0xFFFFFF -> 16777215 (8 chars both)
      if #decimalStr <= #hexVal.captures[1] then
        text = stringUtils.subAll(text, "([^%w_])" .. stringUtils.escape(hexVal.captures[1]), "%1" .. decimalStr)
      end
    end

    return text
  end,
}

LifeBoatAPI.Tools.Class(LifeBoatAPI.Tools.HexadecimalConverter)
