require "__SmartTrains__/lib"
require "__SmartTrains__/prototypes/smart_train_stop"

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
      icon_size = 32
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
  }

data.raw["gui-style"].default["st_label_bold"] =
  {
    type = "label_style",
    font = "st-small-bold",
  }

data.raw["gui-style"].default["st_textfield"] =
  {
    type = "textbox_style",
    minimal_width = 60,
    font = "st-small"
  }

data.raw["gui-style"].default["st_textfield_small"] =
  {
    type = "textbox_style",
    width = 40,
    font = "st-small"
  }

data.raw["gui-style"].default["st_textfield_big"] =
  {
    type = "textbox_style",
    minimal_width = 90,
    font = "st-small"
  }
data.raw["gui-style"].default["st_textfield_medium"] =
  {
    type = "textbox_style",
    minimal_width = 45,
    font = "st-small"
  }

data.raw["gui-style"].default["st_textfield_big"] =
  {
    type = "textbox_style",
    minimal_width = 120,
    font = "st-small"
  }
data.raw["gui-style"].default["st_button"] =
  {
    type = "button_style",
    parent = "button",
    font = "st-small-bold"
  }

data.raw["gui-style"].default["st_frame"] =
  {
    type = "frame_style",
    parent="frame",
    top_padding  = 2,
    bottom_padding = 2,
    font = "st-small-bold",
--    flow_style =
--    {
--      max_on_row = 1,
--      resize_row_to_width = false
--    }
  }
data.raw["gui-style"].default["st_inner_frame"] =
  {
    type = "frame_style",
    parent="frame",
    top_padding  = 2,
    bottom_padding = 2,
    font = "st-small-bold",
    graphical_set = { type = "none" },
--    flow_style =
--    {
--      max_on_row = 1,
--    }
  }

data.raw["gui-style"].default["st_flow"] =
  {
    type = "horizontal_flow_style",
    horizontal_spacing = 0,
    vertical_spacing = 2,
    max_on_row = 0,
  }
data.raw["gui-style"].default["st_table"] =
  {
    type = "table_style",
    parent = "table",
  }

data.raw["gui-style"].default["st_checkbox"] =
  {
    type = "checkbox_style",
    parent = "checkbox",
  }

data.raw["gui-style"].default["st_radio"] =
  {
    type = "checkbox_style",
    parent = "checkbox",
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

data.raw["gui-style"].default["st_button_style"] =
  {
    type = "button_style",
    parent = "button",
    font = "default",
    right_padding = 5,
    left_padding = 5,
    left_click_sound =
    {
      {
        filename = "__core__/sound/gui-click.ogg",
        volume = 1
      }
    }
  }

data.raw["gui-style"].default["st_button_style_bold"] =
  {
    type = "button_style",
    font="default-semibold",
    parent = "st_button_style",
  }

data.raw["gui-style"].default["st_disabled_button"] =
  {
    type = "button_style",
    parent = "st_button_style",

    default_font_color={r=0.34, g=0.34, b=0.34},

    hovered_font_color={r=0.34, g=0.34, b=0.38},
    hovered_graphical_set =
    {
      type = "composition",
      filename = "__core__/graphics/gui.png",
      corner_size = {3, 3},
      position = {0, 0}
    },

    clicked_font_color={r=0.34, g=0.34, b=0.38},
    clicked_graphical_set =
    {
      type = "composition",
      filename = "__core__/graphics/gui.png",
      corner_size = {3, 3},
      position = {0, 0}
    },
  }

data.raw["gui-style"].default["st_disabled_button_bold"] =
  {
    type = "button_style",
    parent = "st_disabled_button",
    font = "default-semibold",
    default_font_color={r=0.5, g=0.5, b=0.5},
    hovered_font_color={r=0.5, g=0.5, b=0.5},
  }

data.raw["gui-style"].default["st_page_button"] =
  {
    type = "button_style",
    parent = "st_button_style_bold",
    horizontal_spacing = 0,
    width = 50,
  }

data.raw["gui-style"].default["st_page_button_disabled"] =
  {
    type = "button_style",
    parent = "st_disabled_button_bold",
    horizontal_spacing = 0,
    width = 50,
  }

data.raw["gui-style"].default["st_selected_button"] =
  {
    type = "button_style",
    parent = "st_button_style_bold",

    default_font_color={r=0, g=0, b=0},
    default_graphical_set =
    {
      type = "composition",
      filename = "__core__/graphics/gui.png",
      corner_size = {3, 3},
      position = {0, 8}
    },

    hovered_font_color={r=1, g=1, b=1},
    hovered_graphical_set =
    {
      type = "composition",
      filename = "__core__/graphics/gui.png",
      corner_size = {3, 3},
      position = {0, 16}
    },

    clicked_font_color={r=0, g=0, b=0},
    clicked_graphical_set =
    {
      type = "composition",
      filename = "__core__/graphics/gui.png",
      corner_size = {3, 3},
      position = {0, 0}
    },
  }


for left = 1,60 do
  data.raw["gui-style"].default["st_frame_padding_left_"..left] =
    {
      type = "frame_style",
      parent = "inner_frame",
      left_padding = left
    }

  data.raw["gui-style"].default["st_frame_padding_top_left_"..left] =
    {
      type = "frame_style",
      parent = "inner_frame",
      left_padding = left,
      top_padding = 8
    }
end
--[[
Prototype definition:

data:extend({
{
  type = "custom-input",
  name = "my-custom-input",
  key_sequence = "SHIFT + R",
  consuming = "script-only"

  -- 'consuming'
  -- available options:
  -- none: default if not defined
  -- all: if this is the first input to get this key sequence then no other inputs listening for this sequence are fired
  -- script-only: if this is the first *custom* input to get this key sequence then no other *custom* inputs listening for this sequence are fired. Normal game inputs will still be fired even if they match this sequence.
  -- game-only: The opposite of script-only: blocks game inputs using the same key sequence but lets other custom inputs using the same key sequence fire.
}})

Local definition:

[controls]
my-custom-input=Potato controls

Subscribing to the event:

script.on_event("my-custom-input", function(event) game.players[event.player_index].print(event.input_name .. " ran on tick: " .. tostring(event.tick)) end)

]]--
