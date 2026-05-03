local M = {}
local api = vim.api
local utils = require "floaterm.utils"
local state = require "floaterm.state"
local volt = require "volt"
local volt_redraw = require("volt").redraw
local layout = require "floaterm.layout"

M.setup = function(opts)
  state.config = vim.tbl_deep_extend("force", state.config, opts or {})

  local project_config_path = vim.fn.getcwd() .. "/floaterm.lua"
  if not state.project_config_loaded and vim.fn.filereadable(project_config_path) == 1 then
    local ok, project_terminals = pcall(dofile, project_config_path)
    if ok and type(project_terminals) == "table" then
      state.terminals = state.terminals or {}
      for _, term_opts in ipairs(project_terminals) do
        local details = require("floaterm.utils").new_term(term_opts)
        table.insert(state.terminals, details)
      end
    else
      vim.notify("floaterm: Error loading " .. project_config_path, vim.log.levels.ERROR)
    end
    state.project_config_loaded = true
  end
end

M.open = function()
  state.volt_set = true
  state.sidebuf = state.sidebuf or api.nvim_create_buf(false, true)
  state.barbuf = state.barbuf or api.nvim_create_buf(false, true)
  state.prev_win_focussed = api.nvim_get_current_win()

  local conf = state.config
  local bordered = conf.border
  local usr_terms = type(conf.terminals) == "table" and conf.terminals or conf.terminals()
  state.terminals = state.terminals or vim.tbl_deep_extend("force", {}, usr_terms)

  utils.gen_term_bufs()
  if state.buf and not api.nvim_buf_is_valid(state.buf) then
    state.buf = nil
  end
  state.buf = state.buf or (state.terminals[1] and state.terminals[1].buf)

  state.h = math.floor(vim.o.lines * (conf.size.h / 100))
  state.w = math.floor(vim.o.columns * (conf.size.w / 100))

  local sidebar_w = 20

  if conf.position then 
     conf.position = type(conf.position) == 'table' and conf.position or conf.position()
  end

  local pos_row = conf.position and conf.position.row or (vim.o.lines / 2 - state.h / 2) - 1
  local pos_col = conf.position and conf.position.col or (vim.o.columns / 2 - state.w / 2)

  local sidebar_win_opts = {
    row = pos_row,
    col = pos_col,
    width = sidebar_w,
    height = state.h,
    relative = "editor",
    style = "minimal",
    border = "single",
    zindex = 100,
  }

  state.sidewin = api.nvim_open_win(state.sidebuf, true, sidebar_win_opts)

  local colored_border = {
    { " ", "exdarkborder" },
    { "‾", "FloatSpecialBorder" },
    { " ", "exdarkborder" },
    { " ", "exdarkborder" },
    { " ", "exdarkborder" },
    { " ", "exdarkborder" },
    { " ", "exdarkborder" },
    { " ", "exdarkborder" },
  }

  state.term_win_opts = {
    row = 2,
    col = sidebar_w + (bordered and 2 or 1),
    win = state.sidewin,
    width = state.w - sidebar_w,
    height = state.h - 3,
    relative = "win",
    style = "minimal",
    border = bordered and "single" or colored_border,
    zindex = 100,
  }

  api.nvim_win_set_hl_ns(state.sidewin, state.ns)

  local bar_win_opts = {
    row = -1,
    col = sidebar_w + (bordered and 2 or 1),
    win = state.sidewin,
    width = state.w - sidebar_w,
    height = 1,
    relative = "win",
    style = "minimal",
    border = "single",
    zindex = 100,
  }

  state.barwin = api.nvim_open_win(state.barbuf, false, bar_win_opts)

  if bordered then
    vim.wo[state.barwin].winhl = "Normal:normal,floatBorder:xdarkbg"
  else
    vim.wo[state.barwin].winhl = "Normal:exdarkbg,floatBorder:exdarkborder"
  end

  api.nvim_set_hl(state.ns, "floatBorder", { link = bordered and "comment" or "exblack2border" })
  api.nvim_set_hl(state.ns, "Normal", { link = bordered and "normal" or "exblack2bg" })

  volt.gen_data {
    { buf = state.sidebuf, ns = state.ns, layout = layout.sidebar, xpad = 1 },
    { buf = state.barbuf, ns = state.ns, layout = layout.bar, xpad = 1 },
  }

  api.nvim_set_option_value("modifiable", true, { buf = state.sidebuf })
  api.nvim_set_option_value("modifiable", true, { buf = state.barbuf })

  volt.run(state.sidebuf, { h = sidebar_win_opts.height, w = sidebar_win_opts.width })
  volt.run(state.barbuf, { h = 1, w = bar_win_opts.width })

  state.win = api.nvim_open_win(state.buf, true, state.term_win_opts)

  utils.set_termwin_hl()
  utils.switch_buf(state.buf)
  volt_redraw(state.barbuf, "bar")

  require "floaterm.mappings"()
  require "floaterm.hl"()

  state.bar_redraw_timer = vim.uv.new_timer()

  state.bar_redraw_timer:start(
    0,
    state.bar_redraw_timeout,
    vim.schedule_wrap(function()
      volt_redraw(state.barbuf, "bar")
    end)
  )

  vim.bo[state.sidebuf].ft = "FloatermSidebar"

  api.nvim_create_autocmd("WinClosed", {
    group = api.nvim_create_augroup("FloatermAu", { clear = true }),
    callback = function(args)
      vim.schedule(function()
        if state.volt_set and not state.is_toggling and utils.get_term_by_key(args.buf) then
          require("floaterm.api").delete_term(args.buf)
        end
      end)
    end,
  })
end

M.toggle = function()
  if state.volt_set then
    state.is_toggling = true
    api.nvim_del_augroup_by_name "FloatermAu"
    api.nvim_win_close(state.win, false)
    api.nvim_win_close(state.barwin, false)
    api.nvim_win_close(state.sidewin, false)
    utils.close_timers()
    state.volt_set = false
    api.nvim_set_current_win(state.prev_win_focussed)
    state.is_toggling = false
  else
    M.open()
  end
end

return M
