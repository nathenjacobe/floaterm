local M = {
  ns = vim.api.nvim_create_namespace "Floaterm",
  terminals = nil,
  bar_redraw_timeout = 10000,
  prev_win_focussed = 0,
  sidebar_focus_idx = nil,
  project_config_loaded = false,
  is_toggling = false,

  config = {
    border = false,
    autoinsert = true,
    size = { h = 30, w = 70 },
    persistence = true,

    -- { row , col } or fn() returning the table
    position = nil,

    -- must be functions
    mappings = { sidebar = nil, term = nil },
    terminals = {
      { name = "Terminal" },
    },
  },
}

return M
