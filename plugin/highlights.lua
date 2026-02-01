-- Stormworks section annotation highlighting
-- Define highlight groups for ---@section and ---@endsection annotations

local function setup_highlights()
  -- Define custom highlight groups
  vim.api.nvim_set_hl(0, 'StormworksSection', { link = 'SpecialComment', default = true })
  vim.api.nvim_set_hl(0, 'StormworksEndSection', { link = 'SpecialComment', default = true })

  -- Link TreeSitter captures to our highlight groups
  vim.api.nvim_set_hl(0, '@stormworks.section', { link = 'StormworksSection', default = true })
  vim.api.nvim_set_hl(0, '@stormworks.endsection', { link = 'StormworksEndSection', default = true })
end

-- Set up highlights on load
setup_highlights()

-- Persist highlights after colorscheme changes
vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('StormworksHighlights', { clear = true }),
  callback = setup_highlights,
  desc = 'Re-apply Stormworks section annotation highlights after colorscheme change',
})
