require "prototypes/smart_train_stop"

data:extend(
  {
    {
      type = "font",
      name = "st-small",
      from = "default",
      size = 13
    },
    {
      type ="font",
      name = "st-small-bold",
      from = "default-bold",
      size = 13
    },
    {
      type = "item-group",
      name = "st-invisible",
      order = "zz",
      inventory_order = "zz",
      icon = "__base__/graphics/icons/deconstruction-planner.png",
    },
    {
      type = "item-subgroup",
      name = "st-metaitems",
      group = "st-invisible",
      order = "1"
    }
  }
)

data.raw["gui-style"].default["st_label"] =
  {
    type = "label_style",
    font = "st-small",
    font_color = {r=1, g=1, b=1},
    top_padding = 0,
    bottom_padding = 0
  }

data.raw["gui-style"].default["st_textfield"] =
  {
    type = "textfield_style",
    left_padding = 3,
    right_padding = 2,
    minimal_width = 60,
    font = "st-small"
  }

data.raw["gui-style"].default["st_textfield_small"] =
  {
    type = "textfield_style",
    left_padding = 3,
    right_padding = 2,
    minimal_width = 30,
    font = "st-small"
  }
data.raw["gui-style"].default["st_textfield_medium"] =
  {
    type = "textfield_style",
    left_padding = 3,
    right_padding = 2,
    minimal_width = 45,
    font = "st-small"
  }

data.raw["gui-style"].default["st_textfield_big"] =
  {
    type = "textfield_style",
    left_padding = 3,
    right_padding = 2,
    minimal_width = 120,
    font = "st-small"
  }
data.raw["gui-style"].default["st_button"] =
  {
    type = "button_style",
    parent = "default",
    font = "st-small-bold"
  }

data.raw["gui-style"].default["st_frame"] =
  {
    type = "frame_style",
    parent="frame_style",
    top_padding  = 2,
    bottom_padding = 2,
    font = "st-small-bold",
    flow_style =
    {
      max_on_row = 1,
      resize_row_to_width = false
    }
  }
data.raw["gui-style"].default["st_inner_frame"] =
  {
    type = "frame_style",
    parent="frame_style",
    top_padding  = 2,
    bottom_padding = 2,
    font = "st-small-bold",
    graphical_set = { type = "none" },
    flow_style =
    {
      max_on_row = 1,
    }
  }

data.raw["gui-style"].default["st_flow"] =
  {
    type = "flow_style",
    horizontal_spacing = 0,
    vertical_spacing = 2,
    max_on_row = 0,
  }
data.raw["gui-style"].default["st_table"] =
  {
    type = "table_style",
    parent = "table_style",
  }
data.raw["gui-style"].default["st_checkbox"] =
  {
    type = "checkbox_style",
    parent = "checkbox_style",
    font = "st-small",
    default_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 10,
      height = 10,
      x = 43,
      y = 34
    },
    hovered_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 10,
      height = 10,
      x = 54,
      y = 34
    },
    clicked_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 10,
      height = 10,
      x = 65,
      y = 34
    },
    selected =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 10,
      height = 10,
      x = 75,
      y = 34
    }
  }
