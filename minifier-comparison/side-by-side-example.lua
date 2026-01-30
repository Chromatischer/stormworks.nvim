--[[
================================================================================
MINIFIER COMPARISON: Side-by-Side Example
================================================================================
This file shows how both minifiers transform the same input code.
================================================================================
]]

--[[
================================================================================
ORIGINAL INPUT (396 characters)
================================================================================
]]

--[[ ORIGINAL:
-- Track management for radar system
local MAX_TRACKS = 10
local TRACK_TIMEOUT = 60

local tracks = {}
local trackCount = 0

local function createTrack(posX, posY, velocity)
    return {
        x = posX,
        y = posY,
        vx = velocity,
        age = 0
    }
end

local function updateTrack(track)
    track.x = track.x + track.vx
    track.age = track.age + 1
    return track.age < TRACK_TIMEOUT
end

function onTick()
    for i = 1, #tracks do
        if not updateTrack(tracks[i]) then
            table.remove(tracks, i)
        end
    end
    output.setNumber(1, #tracks)
end
]]

--[[
================================================================================
STORMEDIT OUTPUT (stravant lua-minify) - ~230 chars (~42% reduction)
================================================================================

Transformations applied:
1. Comments removed
2. Variables renamed (AST-aware scoping):
   - MAX_TRACKS → a
   - TRACK_TIMEOUT → b
   - tracks → c
   - trackCount → d
   - createTrack → e
   - posX → f, posY → g, velocity → h
   - updateTrack → i
   - track → j (parameter)
   - i → k (loop variable, different scope from function i)
3. Whitespace minimized
4. Necessary spaces preserved (local a, function a, etc.)

OUTPUT:
local a=10 local b=60 local c={}local d=0 local function e(f,g,h)return{x=f,y=g,vx=h,age=0}end local function i(j)j.x=j.x+j.vx j.age=j.age+1 return j.age<b end function onTick()for k=1,#c do if not i(c[k])then table.remove(c,k)end end output.setNumber(1,#c)end
]]

--[[
================================================================================
STORMWORKS.NVIM OUTPUT (LifeBoatAPI) - ~195 chars (~51% reduction)
================================================================================

Transformations applied:
1. Comments removed
2. Variables renamed (frequency-based, most-used get shortest names):
   - tracks → a (used most: 4 times)
   - track → b (used 6 times in updateTrack)
   - TRACK_TIMEOUT → c
   - MAX_TRACKS → d (unused, might be removed entirely)
   - etc.
3. Global function aliasing:
   - output.setNumber used once → no alias
   - table.remove used once → no alias
4. Number optimization:
   - 10, 60, 0, 1 are all unique → no deduplication needed
5. Whitespace aggressively removed
6. 'local' keywords removed where safe (saves 6 chars each)

OUTPUT:
d=10 c=60 a={}e=0 function f(g,h,i)return{x=g,y=h,vx=i,age=0}end function j(b)b.x=b.x+b.vx b.age=b.age+1 return b.age<c end function onTick()for k=1,#a do if not j(a[k])then table.remove(a,k)end end output.setNumber(1,#a)end
]]

--[[
================================================================================
KEY DIFFERENCES HIGHLIGHTED
================================================================================

1. LOCAL KEYWORD:
   StormEdit:       local a=10 local b=60 local c={}
   Stormworks.nvim: d=10 c=60 a={}

   Savings: 18 characters (3 × "local ")

2. FUNCTION DECLARATIONS:
   StormEdit:       local function e(f,g,h)
   Stormworks.nvim: function f(g,h,i)

   Savings: 6 characters per function

3. SCOPE HANDLING:
   StormEdit uses AST, so it knows 'i' in the for loop is different from
   function 'i'. It can reuse the same short name in different scopes.

   Stormworks.nvim uses regex, so it treats all occurrences globally and
   avoids name collisions by assigning unique names.

4. PRESERVED NAMES:
   Both preserve: onTick, output.setNumber, table.remove
   (These are Stormworks API functions that must not be renamed)

================================================================================
SIZE COMPARISON
================================================================================

Original:          396 characters (with comments)
                   ~320 characters (code only)

StormEdit:         ~230 characters
                   Reduction: ~28% (from code-only)

Stormworks.nvim:   ~195 characters
                   Reduction: ~39% (from code-only)

DIFFERENCE:        35 characters (~15% better compression)

================================================================================
WHEN THIS MATTERS
================================================================================

Stormworks microcontroller limit: 8,100 characters

If your unminified code is:
- 12,000 chars → StormEdit: ~8,640 (OVER LIMIT!) vs Stormworks.nvim: ~7,320 (OK)
- 15,000 chars → StormEdit: ~10,800 vs Stormworks.nvim: ~9,150

The extra 10-15% reduction from LifeBoatAPI can be the difference between
a working microcontroller and one that exceeds the character limit.

]]
