local state = require "floaterm.state"
local utils = require "floaterm.utils"
local volt_redraw = require("volt").redraw
local M = {}

M.edit_name = function()
  local row = state.sidebar_focus_idx or utils.get_buf_on_cursor()

  if row then
    vim.ui.input({ prompt = "   Enter name: " }, function(input)
      if input and #input > 0 then
        state.terminals[row].name = input
        vim.api.nvim_echo({}, false, {})
        volt_redraw(state.sidebuf, "bufs")
      end
    end)
  end
end

M.new_term = function(opts)
  opts = opts or {}

  local function create_and_insert_term(term_opts)
    local details = utils.new_term(term_opts)
    local insert_at = (state.sidebar_focus_idx and state.sidebar_focus_idx + 1) or (#state.terminals + 1)
    table.insert(state.terminals, insert_at, details)
    utils.regenerate_keymaps()
    volt_redraw(state.sidebuf, "all")

    if not term_opts.hidden then
      utils.switch_buf(details.buf)
    end
  end

  if opts.name == "auto" then
    vim.ui.input({ prompt = "   Enter name: " }, function(input)
      opts.name = input
      vim.api.nvim_echo({}, false, {})
      create_and_insert_term(opts)
    end)
  else
    create_and_insert_term(opts)
  end
end

M.switch_wins = function()
  local curwin = vim.api.nvim_get_current_win()
  local newwin_name

  if curwin == state.win then
    newwin_name = "sidewin"
  elseif curwin == state.sidewin then
    newwin_name = "win"
  end

  if newwin_name == "sidewin" then
    local cur_index = utils.get_term_by_key(state.buf)
    state.sidebar_focus_idx = cur_index and cur_index[1] or 1
    volt_redraw(state.sidebuf, "bufs")
  elseif newwin_name == "win" then
    state.sidebar_focus_idx = nil
    volt_redraw(state.sidebuf, "bufs")
  end

  if newwin_name then
    vim.api.nvim_set_current_win(state[newwin_name])
  end
end

M.cycle_term_bufs = function(direction)
  if not state.terminals or #state.terminals == 0 then
    return
  end

  local cur_index = utils.get_term_by_key(state.buf)

  if not cur_index then
    utils.switch_buf(state.terminals[1].buf)
    return
  end

  local new_index = (cur_index[1] + (direction == "prev" and -2 or 0)) % #state.terminals
  utils.switch_buf(state.terminals[new_index + 1].buf)
end

M.delete_term = function(buf)
  local method = buf and "automatic" or "manual"

  if not buf then
    local i = state.sidebar_focus_idx or utils.get_buf_on_cursor()
    if i then
      buf = state.terminals[i].buf
    end
  end

  if buf then
    local index = utils.get_term_by_key(buf)[1]
    local newbuf_i = (index == 1 and index + 1) or index - 1

    table.remove(state.terminals, index)
    utils.regenerate_keymaps()

    if #state.terminals == 0 then
      M.new_term()
    end

    newbuf_i = #state.terminals == 1 and 1 or newbuf_i

    if method == "manual" then
      vim.api.nvim_buf_delete(buf, { force = true })
    end

    utils.switch_buf(state.terminals[newbuf_i].buf)

    local total_lines = vim.api.nvim_buf_get_lines(state.sidebuf, 0, -1, false)

    vim.api.nvim_set_option_value("modifiable", true, { buf = state.sidebuf })
    require("volt").set_empty_lines(state.sidebuf, #total_lines, 20)
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.sidebuf })

    volt_redraw(state.sidebuf, "all")
  end
end

M.send_cmd = function(opts)
  if not state.terminals then
    require("floaterm").open()
    require("floaterm.api").new_term(opts)
  else
    opts.cmd = type(opts.cmd) == "string" and opts.cmd or opts.cmd()
    opts.buf = opts.buf or state.buf
    local bufdetails = utils.get_term_by_key(opts.buf)[2]

    if opts.name then
      bufdetails = utils.get_term_by_key(opts.name, "name")[2]
    end

    local job_id = vim.b[bufdetails.buf].terminal_job_id
    vim.api.nvim_chan_send(job_id, opts.cmd .. " \n")
    vim.api.nvim_buf_call(bufdetails.buf, function()
      vim.cmd [[normal G]]
    end)
  end
end

return M
