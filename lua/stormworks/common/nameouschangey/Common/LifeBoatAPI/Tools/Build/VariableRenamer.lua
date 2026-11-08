-- Author: Nameous Changey
-- GitHub: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension
-- Workshop: https://steamcommunity.com/id/Bilkokuya/myworkshopfiles/?appid=573090
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.ParsingConstantsLoader")

--------------------------------------------------------------------------------------------------------------------
---@class VariableRenamer : BaseClass
---@field constants ParsingConstantsLoader
LifeBoatAPI.Tools.VariableRenamer = {
  _replacementCharacters = "_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", -- no need for more than this with 4K chars

  ---@return VariableRenamer
  new = function(cls, constants)
    local self = LifeBoatAPI.Tools.BaseClass.new(cls)
    self.constants = constants
    self.variableNumber = 1
    return self
  end,

  --- Note, after the update increasing the number of availible chars from 4096 to 8192 the resonably expected amount of variables has dramatically increased,
  --- but should not excede the amount of valid names generated in the 53^3 possible combinations
  ---@param self VariableRenamer
  getShortName = function(self, preCachedTableOfNames)
    local name = ""
    if preCachedTableOfNames == nil then
      repeat
        name = self:_generateName()
      until self:_checkIsValidName(name)
      return name
    else
      repeat
        if preCachedTableOfNames[self.variableNumber] ~= nil then
          name = preCachedTableOfNames[self.variableNumber]
          self.variableNumber = self.variableNumber+1
        else
          name = self:_generateName()
          preCachedTableOfNames[self.variableNumber-1] = name
        end
      until self:_checkIsValidName(name)
      return name
    end
  end,



  _checkIsValidName = function(self, name)
    return not self.constants.restrictedKeywords[name]
      and not self.constants.baseNames[name]
      and not self.constants.fullNames[name]
  end,

  _generateName = function(self)
    local size = #self._replacementCharacters
    local name = nil
    
    if self.variableNumber <= size then
      name =  self._replacementCharacters:sub(self.variableNumber, self.variableNumber)
    elseif self.variableNumber <= (size * size - 1) then
      local num1 = math.floor(self.variableNumber % size) + 1
      local num2 = math.floor(self.variableNumber / size) + 1
      name =  self._replacementCharacters:sub(num2, num2) .. self._replacementCharacters:sub(num1, num1)
    elseif self.variableNumber <= (size * size * size - 1) then
      local num1 = math.floor(self.variableNumber % size) + 1
      local num2 = math.floor(self.variableNumber / size % size) + 1
      local num3 = math.floor(self.variableNumber / (size * size)) + 1
      name =  self._replacementCharacters:sub(num3, num3) .. self._replacementCharacters:sub(num2, num2) .. self._replacementCharacters:sub(num1, num1)
    end

    self.variableNumber = self.variableNumber + 1

    if name == nil then
      --if we have run out of unique 3 character names then:
      return "L" .. tostring(self.variableNumber)
    else
      return name
    end
    
  end,
}
LifeBoatAPI.Tools.Class(LifeBoatAPI.Tools.VariableRenamer)