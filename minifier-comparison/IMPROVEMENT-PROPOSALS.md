# LifeBoatAPI Minifier: Improvement Proposals

## Executive Summary

The LifeBoatAPI minifier is functional but has **3 critical bugs**, **several high-impact issues**, and **numerous missing optimizations** that could provide an additional **5-15% character savings**.

---

## 🔴 CRITICAL BUGS (Must Fix)

### 1. Duplicate Name Generation in VariableRenamer

**File:** `VariableRenamer.lua:42-45`

**Problem:** The two-character name generation math is incorrect, causing duplicate variable names.

```lua
-- CURRENT (BUGGY):
elseif self.variableNumber <= (size * size) then
  local num1 = math.floor(self.variableNumber % size) + 1
  local num2 = math.floor(self.variableNumber / size) + 1
  return self._replacementCharacters:sub(num2, num2) .. self._replacementCharacters:sub(num1, num1)
end
```

For `variableNumber = 106` (size=53):
- `num1 = (106 % 53) + 1 = 1`
- `num2 = floor(106 / 53) + 1 = 3`
- Result: `a_`

But for `variableNumber = 159`:
- `num1 = (159 % 53) + 1 = 1`
- `num2 = floor(159 / 53) + 1 = 4`
- Result: `b_`

Actually wait, let me recalculate... The issue is the transition point:
- Variable 53: single char `Z`
- Variable 54: should be `__` (first two-char)
- But `54 % 53 = 1`, `floor(54/53) = 1` → `__` ✓

The real bug appears at:
- Variable 106 = 53 + 53: `106 % 53 = 0` → `+1 = 1`, `floor(106/53) = 2` → `a_`
- Variable 107 = 53 + 54: `107 % 53 = 1` → `+1 = 2`, `floor(107/53) = 2` → `a_` DUPLICATE!

**Fix:**
```lua
elseif self.variableNumber <= (size * size) + size then
  local index = self.variableNumber - size - 1  -- 0-based index for two-char names
  local num1 = (index % size) + 1
  local num2 = math.floor(index / size) + 1
  return self._replacementCharacters:sub(num2, num2) .. self._replacementCharacters:sub(num1, num1)
end
```

**Impact:** Could cause variable shadowing and incorrect code in scripts with >53 unique variables.

---

### 2. Wrong Condition in Minimizer Strip Logic

**File:** `Minimizer.lua:118`

**Problem:** `onAttatch` is stripped based on wrong condition.

```lua
-- CURRENT (BUGGY):
if this.params.stripOnDebugDraw then  -- WRONG! Should check stripOnAttatch
  text = this:_stripFunctionByName(text, "onAttatch")
end
```

**Fix:**
```lua
-- This block is actually redundant - onAttatch already stripped at line 113-115
-- REMOVE lines 117-119 entirely, or fix to:
if this.params.stripOnAttatch then
  text = this:_stripFunctionByName(text, "onAttatch")
end
```

**Impact:** `onAttatch` stripped twice when only `stripOnDebugDraw` enabled; wastes processing.

---

### 3. Wrong Class in CommentReplacer

**File:** `CommentReplacer.lua:46`

**Problem:** Class declaration references wrong class.

```lua
-- CURRENT (BUGGY):
LifeBoatAPI.Tools.Class(LifeBoatAPI.Tools.StringReplacer)

-- FIX:
LifeBoatAPI.Tools.Class(LifeBoatAPI.Tools.CommentReplacer)
```

**Impact:** Inheritance/class registration may be incorrect.

---

## 🟠 HIGH-IMPACT ISSUES

### 4. HexadecimalConverter Doesn't Check Length

**File:** `HexadecimalConverter.lua:35`

**Problem:** Converts ALL hex to decimal, even when decimal is longer.

| Hex | Decimal | Chars Saved |
|-----|---------|-------------|
| `0xF` | `15` | +1 |
| `0xFF` | `255` | +1 |
| `0xFFFF` | `65535` | +1 |
| `0xFFFFFF` | `16777215` | **0** |
| `0xFFFFFFFF` | `4294967295` | **-2** (WORSE!) |

**Fix:**
```lua
local decimalStr = tostring(hexAsNum)
if #decimalStr < #hexVal.captures[1] then
  text = stringUtils.subAll(text, pattern, "%1" .. decimalStr)
end
```

**Savings:** 0-5 chars for scripts using large hex values.

---

### 5. NumberLiteralReducer Break-Even Calculation

**File:** `NumberLiteralReducer.lua:56-60`

**Problem:** Threshold calculation is overly conservative.

```lua
-- CURRENT:
local timesNeedingSeen = 1.5 + 2 + #v.captures[1]  -- e.g., 6.5 for "100"
return 1.5 * count[v.captures[1]] >= timesNeedingSeen
-- For "100" (len=3): needs count >= 5 to create variable
```

**Analysis:**
- Creating `n=100` costs 5 chars (including newline)
- Each replacement saves 2 chars (`100` → `n`)
- Break-even: 5/2 = 2.5, so count >= 3 should trigger

**Fix:**
```lua
local aliasCost = 2 + #v.captures[1]  -- "n=100\n" minus the 'n'
local savingsPerUse = #v.captures[1] - 1  -- "100" → "n" saves 2
return count[v.captures[1]] * savingsPerUse > aliasCost
```

**Savings:** 5-20 chars for scripts with repeated numbers.

---

### 6. Variable Shadowing Across Stages

**Problem:** No coordination between stages for generated names.

- `VariableShortener` creates variable `a`
- `GlobalVariableReducer` creates alias `a=screen`
- `NumberLiteralReducer` creates `a=100`

All three might pick `a` independently!

**Fix:** Share a single `VariableRenamer` instance across ALL stages (partially done, but not consistently).

---

## 🟡 MISSING OPTIMIZATIONS

### 7. Constant Folding (Est. 1-3% savings)

**Current:** `local x = 1 + 2` remains as-is
**Proposed:** `local x = 3`

```lua
-- Fold simple arithmetic
text = text:gsub("(%d+)%s*%+%s*(%d+)", function(a, b)
  return tostring(tonumber(a) + tonumber(b))
end)
```

### 8. Negative Number Optimization (Est. 1-2% savings)

**Current:** `-100` treated as operator `-` and number `100` separately
**Proposed:** Recognize and deduplicate negative literals

```lua
-- Before: -100, -100, -100
-- After:  n=-100 n,n,n  (saves ~6 chars)
```

### 9. Shorter Placeholder Format (Est. 0.5% savings)

**Current:** `STRING0000001REPLACEMENT` (23 chars)
**Proposed:** `§1` or `S1` (2-3 chars)

During processing, shorter placeholders mean less memory and faster regex.

### 10. Parenthesis Removal via Precedence Analysis (Est. 1-2% savings)

**Current:** `(a * b) + c` kept as-is
**Proposed:** `a * b + c` (multiplication has higher precedence)

### 11. Keyword Substitution (Est. 0.5% savings)

**Current:** `not x` (5 chars with space)
**Proposed:** `~x` (2 chars) — Note: This is actually NOT valid in Lua 5.1!

Better alternatives:
- `x==nil` → `not x` (actually longer, skip)
- `x~=nil` → `x` (when boolean context)

### 12. Boolean Literal Optimization (Est. 0.5% savings)

**Current:** `true`, `false` (4-5 chars)
**Proposed:** Pre-define `T=true F=false` if used 3+ times

```lua
-- Before (15 chars): if true then false end
-- After (11 chars):  T=true F=false if T then F end
-- Only saves if true/false used 4+ times total
```

### 13. Table Constructor Optimization (Est. 1% savings)

**Current:** `{x=1,y=2,z=3}` (13 chars)
**Proposed:** `{1,2,3}` with index access (7 chars) — Only if keys are sequential integers

### 14. String Escape Optimization (Est. 0.5% savings)

**Current:** `"\n"` (4 chars)
**Proposed:** Actual newline in string (1 char) — Must verify Stormworks handles it

### 15. Dead Local Removal (Est. 2-5% savings)

**Current:** Unused locals like `local unused = 5` remain
**Proposed:** Remove entirely if never referenced

Requires proper scope analysis (AST or multi-pass regex).

---

## 📊 ESTIMATED IMPACT

| Category | Estimated Savings | Difficulty |
|----------|------------------|------------|
| Critical Bug Fixes | Correctness | Easy |
| Hex Length Check | 0-5 chars | Easy |
| Break-Even Fix | 5-20 chars | Easy |
| Constant Folding | 1-3% | Medium |
| Negative Numbers | 1-2% | Medium |
| Parenthesis Removal | 1-2% | Hard |
| Dead Code Removal | 2-5% | Hard |
| **Total Potential** | **5-15%** | - |

---

## 🛠️ IMPLEMENTATION PRIORITY

### Phase 1: Bug Fixes (Immediate)
1. Fix VariableRenamer duplicate name generation
2. Remove redundant onAttatch stripping
3. Fix CommentReplacer class declaration

### Phase 2: Quick Wins (1-2 hours)
4. Add length check to HexadecimalConverter
5. Fix NumberLiteralReducer break-even calculation
6. Add negative number support to NumberLiteralReducer

### Phase 3: Medium Effort (4-8 hours)
7. Implement constant folding
8. Add boolean literal optimization
9. Shorter placeholder format

### Phase 4: Major Improvements (Days)
10. Dead code elimination (requires scope analysis)
11. Parenthesis removal (requires precedence parser)
12. AST-based approach (full rewrite)

---

## 🔬 TESTING RECOMMENDATIONS

1. **Unit tests for VariableRenamer**: Generate 100+ names, verify uniqueness
2. **Regression tests**: Run minifier on corpus of real scripts, compare output
3. **Correctness tests**: Execute minified code, verify same behavior as original
4. **Size tests**: Track character count improvements per optimization
