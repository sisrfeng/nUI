local utils = require("nui.utils")
local layout_utils = require("nui.layout.utils")

local _ = utils._

local defaults = utils.defaults
local calculate_window_position = layout_utils.calculate_window_position
local calculate_window_size = layout_utils.calculate_window_size
local get_container_info = layout_utils.get_container_info
local parse_relative = layout_utils.parse_relative

local function normalize_options(options)
  options = _.normalize_layout_options(options)

  return options
end

---@param class NuiLayout
---@return NuiLayout
local function init(class, options, boxes)
  ---@type NuiLayout
  local self = setmetatable({}, { __index = class })

  options = normalize_options(options)

  if not boxes.dir then
    boxes = class.Box(boxes)
  end

  self._ = {
    boxes = boxes,
    loading = false,
    mounted = false,
    win_enter = false,
    win_config = {
      focusable = false,
      style = "minimal",
    },
  }

  local win_config = self._.win_config

  self._.position = parse_relative(options.relative, vim.api.nvim_get_current_win())

  local container_info = get_container_info(self._.position)

  self._.size = calculate_window_size(options.size, container_info.size)
  win_config.width = self._.size.width
  win_config.height = self._.size.height

  self._.position = vim.tbl_extend(
    "force",
    self._.position,
    calculate_window_position(options.position, self._.size, container_info)
  )

  win_config.relative = self._.position.relative
  win_config.win = self._.position.relative == "win" and self._.position.win or nil
  win_config.bufpos = self._.position.bufpos
  win_config.row = self._.position.row
  win_config.col = self._.position.col

  return self
end

---@class NuiLayout
local Layout = setmetatable({
  super = nil,
}, {
  __call = init,
  __name = "NuiLayout",
})

function Layout:mount()
  if self._.loading or self._.mounted then
    return
  end

  self._.loading = true

  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    assert(self.bufnr, "failed to create buffer")
  end

  self.winid = vim.api.nvim_open_win(self.bufnr, self._.win_enter, self._.win_config)
  assert(self.winid, "failed to create popup window")

  local boxes = self._.boxes.boxes

  for i, box in ipairs(boxes.boxes) do
    if box.component then
      local component = box.component
      component:set_layout({
        size = box.size,
        relative = {
          type = "win",
          winid = self.winid,
        },
        position = {
          row = 0,
          col = 30 * (i - 1),
        },
      })
    end
  end

  for i, box in ipairs(boxes.boxes) do
    if box.component then
      local component = box.component
      component:mount()
    end
  end

  self._.loading = false
  self._.mounted = true
end

function Layout:unmount()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  local boxes = self._.boxes.boxes

  for i, box in ipairs(boxes.boxes) do
    if box.component then
      local component = box.component
      component:unmount()
    end
  end

  if self.bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.bufnr = nil
  end

  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
  self.winid = nil

  self._.loading = false
  self._.mounted = false
end

function Layout.Box(boxes, options)
  options = options or {}

  if boxes.mount then
    return {
      component = boxes,
      size = options.size,
      grow = defaults(options.grow, false),
    }
  end

  return {
    boxes = boxes,
    direction = defaults(options.direction, "row"),
    grow = defaults(options.grow, false),
    size = options.size,
  }
end

---@alias NuiLayout.constructor fun(options: table, boxes: table): NuiLayout
---@type NuiLayout|NuiLayout.constructor
local NuiLayout = Layout

return NuiLayout
