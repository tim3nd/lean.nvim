local find_project_root = require('lspconfig.util').root_pattern('leanpkg.toml')
local dirname = require('lspconfig.util').path.dirname

local util = require"lean._util"
local components = require('lean.infoview.components')
local subprocess_check_output = util.subprocess_check_output

local html = require('lean.html')

local lean3 = {}

-- Ideally this obviously would use a TOML parser but yeah choosing to
-- do nasty things and not add the dependency for now.
local _PROJECT_MARKER = '.*lean_version.*\".*:3.*'
local _STANDARD_LIBRARY_PATHS = '.*/[^/]*lean[%-]+3.+/lib/'

--- Detect whether the current buffer is a Lean 3 file using regex matching.
function lean3.__detect_regex(filename)
  local bufnr = vim.fn.bufnr(filename)
  if bufnr == -1 then return end

  local path = vim.uri_to_fname(vim.uri_from_bufnr(bufnr))
  if path:match(_STANDARD_LIBRARY_PATHS) then return true end

  local project_root = find_project_root(path)
  if project_root then
    local result = vim.fn.readfile(project_root .. '/leanpkg.toml')
    for _, line in ipairs(result) do
      if line:match(_PROJECT_MARKER) then return true end
    end
  end

  return false
end

--- Detect whether the current buffer is a Lean 3 file using elan.
function lean3.__detect_elan(filename)
  local bufnr = vim.fn.bufnr(filename)
  if bufnr == -1 then return end

  local path = vim.uri_to_fname(vim.uri_from_bufnr(bufnr))
  local version_string = (require"lean._util".subprocess_check_output
    { command = "lean", args = {"--version"}, cwd = dirname(path) })[1]
  local _, _, version_num = version_string:find("version (%d+)%.%d+%.%d+")
  if version_num == "3" then return true end

  return false
end

--- Return the current Lean 3 search path.
---
--- Includes both the Lean 3 core libraries as well as project-specific
--- directories (i.e. equivalent to what is reported by `lean --path`).
function lean3.__current_search_paths()
  local root = vim.lsp.buf.list_workspace_folders()[1]
  local result = subprocess_check_output{command = "lean", args = {"--path"}, cwd = root }
  return vim.fn.json_decode(table.concat(result, '')).path
end

local function is_widget_element(result)
  return type(result) == 'table' and result.t;
end

local class_to_hlgroup = {
  ["expr-boundary highlight"] = "leanInfoExternalHighlight";
  ["bg-blue br3 ma1 ph2 white"] = "leanInfoField";
  ["bg-gray br3 ma1 ph2 white"] = "leanInfoFieldAlt";
  ["goal-goals"] = "leanInfoGoals";
  ["goal-hyp b pr2"] = "leanInfoGoalHyp";
  ["goal-vdash b"] = "leanInfoGoalVDash";
}

-- mapping from lean3 events to standard div events
local to_event = {
  ["onMouseEnter"] = "mouse_enter";
  ["onMouseLeave"] = "mouse_leave";
  ["onClick"] = "click";
}

function lean3.update_infoview(pin, bufnr, params, use_widget, opts, _this_tick)
  local parent_div = html.Div:new({}, "")
  local widget

  local list_first
  local goal_first = true

  local function parse_widget(result)
    local div = html.Div:new({}, "")
    local function parse_children(children)
      local prev_div
      for _, child in pairs(children) do
        local last_hard_stop = false
        if prev_div then
          local prev_div_string = prev_div:render()
          if #prev_div_string > 0 then
            local last_char = prev_div_string:sub(#prev_div_string, #prev_div_string)
            if last_char ~= " " and last_char ~= "\n" and last_char ~= "(" then
              last_hard_stop = true
            end
          end
        end

        local new_div = parse_widget(child)
        local new_div_string = new_div:render()
        if #new_div_string == 0 then goto continue end

        local this_hard_start = false
        if #new_div_string > 0 then
          local first_char = new_div_string:sub(1, 1)
          if first_char ~= " " and first_char ~= "\n" and first_char ~= ")" and first_char ~= "," then
            this_hard_start = true
          end
        end

        if last_hard_stop and this_hard_start then
          div:insert_div({}, " ", "separator")
        end

        div:insert_new_div(new_div)

        prev_div = new_div

        ::continue::
      end
    end

    if type(result) == "string" then
      result = result:gsub('^%s*(.-)%s$', '%1')

      div:insert_div({}, result, "html-string")

      return div
    elseif is_widget_element(result) then
      local tag = result.t
      local children = result.c
      local attributes = result.a
      local class_name = attributes and attributes.className
      local tooltip = result.tt
      local events = {}
      local hlgroup

      if tag == "ul" then
        list_first = true
      end

      if tag == "li" then
        if list_first then
          list_first = false
        else
          div:insert_div({}, "\n", "list-separator")
        end
      end

      if tag == "label" or tag == "select" or tag == "option" then return div, false end
      hlgroup = class_to_hlgroup[class_name]
      if tag == "button" then hlgroup = hlgroup or "leanInfoButton" end

      if class_name == "goal-goals" then
        div:insert_div({}, '▶ ', "goal-prefix")
        goal_first = false
      end
      if class_name == "lh-copy mt2" and not goal_first then
        div:insert_div({}, '\n', "goal-separator")
      end

      local debug_tags = false
      if debug_tags then
        --div:insert_div({element = result}, "<" .. tag .. ">", "element")
        div:insert_div({element = result}, "<" .. tag ..
        " attributes(" .. vim.inspect(attributes) .. ")" ..
        " events(" .. vim.inspect(result.e) .. ")" ..
        ">", "element")
      end
      local element_div = div:start_div({element = result, event = events}, "", "element")
      element_div.hlgroup = function()
        return html.util.highlight_check(element_div) or hlgroup
      end

      -- close tooltip button
      if tag == "button" and result.c and result.c[1] == "x" then
        element_div.tags.event.clear = function(this_tick)
          if not this_tick then
            pin.tick = pin.tick + 1
            this_tick = pin.tick
          end

          element_div.tags.event["click"](this_tick)
          return true
        end
      end

      if result.e then
        for event, handler in pairs(result.e) do
          local div_event = to_event[event]
          events[div_event] = function(this_tick)
            if not this_tick then
              pin.tick = pin.tick + 1
              this_tick = pin.tick
            end

            local success = pin:_update(false, 0, this_tick, {widget_event = {
              widget = widget,
              kind = event,
              handler = handler,
              args = { type = 'unit' },
              textDocument = pin.position_params.textDocument
            }})

            if this_tick ~= pin.tick then return success, true end

            if div_event ~= "click" then return success, true end

            return success, false
          end
        end
      end

      if tag == "hr" then
        div:insert_div({}, "|", "rule", "leanInfoFieldSep")
      end

      parse_children(children)

      if tooltip then
        div:start_div({element = result, event = {}}, "→[", "tooltip", "leanInfoTooltip")
        div:insert_new_div(parse_widget(tooltip))
        div:insert_div({element = result}, "]", "tooltip-close")
        div:end_div()
      end
      div:end_div()
      if debug_tags then
        div:insert_div({element = result}, "</" .. tag .. ">", "element")
      end
      return div
    else
      parse_children(result.c)
      return div
    end
  end

  params = vim.deepcopy(params)
  if use_widget then
    local err, result
    if not (opts and opts.widget_event) then
      local _err, _result = util.a_request(bufnr, "$/lean/discoverWidget", params)
      err, result = _err, _result
    else
      local _err, _result = util.a_request(bufnr, "$/lean/widgetEvent", opts.widget_event)
      err, result = _err, _result
      if result and result.record then result = result.record end
    end

    if not err and result and result.widget and result.widget.html then
      if result.effects then
        for _, effect in pairs(result.effects) do
          if effect.kind == "reveal_position" then
            local this_infoview = require"lean.infoview".get_current_infoview()
            local this_info = this_infoview and this_infoview.info
            local this_window = this_info and this_info.last_window
            if this_window and vim.api.nvim_win_is_valid(this_window) then
              vim.api.nvim_win_set_buf(this_window, vim.uri_to_bufnr(vim.uri_from_fname(effect.file_name)))
              vim.api.nvim_set_current_win(this_window)
              vim.api.nvim_win_set_cursor(this_window, {effect.line, effect.column})
            end
          end
        end
      end

      widget = result.widget
      parent_div:insert_new_div(parse_widget(result.widget.html))
      parent_div:end_div()
    end
  else
    pin:clear_undo_list()
    local _, result = util.a_request(bufnr, "$/lean/plainGoal", params)
    if pin.tick ~= _this_tick then return true end
    if result and type(result) == "table" then
      parent_div:insert_new_div(components.goal(result))
    end
  end
  if pin.tick ~= _this_tick then return true end
  parent_div:insert_new_div(components.diagnostics(bufnr, params.position.line))
  if pin.tick ~= _this_tick then return true end

  pin.div:insert_new_div(parent_div)

  if not (opts and opts.widget_event) then
    pin.div.tags.event.clear_all(_this_tick)
    if pin.tick ~= _this_tick then return true end
    pin.div.tags.event.replay(_this_tick)
  end
end

function lean3.lsp_enable(opts)
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ['textDocument/publishDiagnostics'] = util.wrap_handler(
      require"vim.lsp.handlers"['textDocument/publishDiagnostics'],
      util.mk_handler(require"lean.lsp".handlers.diagnostics_handler))
  })
  require'lspconfig'.lean3ls.setup(opts)
end

return lean3
