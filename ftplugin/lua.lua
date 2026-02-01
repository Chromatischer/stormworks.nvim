-- Stormworks section annotation highlighting fallback
-- Provides matchadd-based highlighting when TreeSitter is unavailable

-- Only apply fallback if TreeSitter is not active for this buffer
local function is_treesitter_active()
  if not vim.treesitter or not vim.treesitter.highlighter then
    return false
  end
  return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil
end

-- Apply fallback highlighting using matchadd
local function setup_fallback_highlighting()
  if is_treesitter_active() then
    return -- TreeSitter is handling it
  end

  -- Match ---@section lines
  vim.fn.matchadd('StormworksSection', '^\\s*---@section\\>.*$')

  -- Match ---@endsection lines
  vim.fn.matchadd('StormworksEndSection', '^\\s*---@endsection\\>.*$')
end

-- Set up fallback highlighting for this buffer
setup_fallback_highlighting()
