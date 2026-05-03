local map = vim.keymap.set
local state = require "floaterm.state"
local api = require "floaterm.api"
local utils = require "floaterm.utils"
local volt_redraw = require("volt").redraw

local function sidebar_move(direction)
  if not state.sidebar_focus_idx then
    return
  end
  local new_idx = state.sidebar_focus_idx + direction
  if new_idx > 0 and new_idx <= #state.terminals then
    state.sidebar_focus_idx = new_idx
    volt_redraw(state.sidebuf, "bufs")
    vim.api.nvim_win_set_cursor(state.sidewin, { new_idx, 0 })
  end
end

local function sidebar_select()
  if not state.sidebar_focus_idx then
    return
  end
  local term = state.terminals[state.sidebar_focus_idx]
  if term then
    utils.switch_buf(term.buf)
    -- and switch back to the terminal window
    api.switch_wins() -- this should work if we are in sidewin
  end
end

return function()
  map("n", "e", api.edit_name, { buffer = state.sidebuf, silent = true })
  map("n", "a", function()
    api.new_term { name = "auto" }
  end, { buffer = state.sidebuf, silent = true })
  map("n", "d", api.delete_term, { buffer = state.sidebuf, silent = true })
  map("n", "<C-l>", api.switch_wins, { buffer = state.sidebuf, silent = true })

  -- New mappings for sidebar navigation
  map("n", "j", function()
    sidebar_move(1)
  end, { buffer = state.sidebuf, silent = true })
  map("n", "<Down>", function()
    sidebar_move(1)
  end, { buffer = state.sidebuf, silent = true })
  map("n", "k", function()
    sidebar_move(-1)
  end, { buffer = state.sidebuf, silent = true })
  map("n", "<Up>", function()
    sidebar_move(-1)
  end, { buffer = state.sidebuf, silent = true })

  map("n", "<Enter>", sidebar_select, { buffer = state.sidebuf, silent = true })

  map("n", "l", api.switch_wins, { buffer = state.sidebuf, silent = true })
  map("n", "<Right>", api.switch_wins, { buffer = state.sidebuf, silent = true })
  map("n", "h", api.switch_wins, { buffer = state.sidebuf, silent = true })
  map("n", "<Left>", api.switch_wins, { buffer = state.sidebuf, silent = true })

  if state.config.mappings.sidebar then
    state.config.mappings.sidebar(state.sidebuf)
  end
end
