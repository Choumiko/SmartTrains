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
    }
  }
)

data.raw["gui-style"].default["st-icon-style"] =
  {
    type = "button_style",
    parent = "slot_button_style",
    width = 32,
    height = 32
--    clicked_graphical_set =
--    {
--      type = "monolith",
--      top_monolith_border = 1,
--      right_monolith_border = 1,
--      bottom_monolith_border = 1,
--      left_monolith_border = 1,
--      monolith_image =
--      {
--        filename = "__core__/graphics/gui.png",
--        priority = "extra-high-no-scale",
--        width = 32,
--        height = 32,
--        x = 111
--      }
--    },
--    hovered_graphical_set =
--    {
--      type = "monolith",
--      top_monolith_border = 1,
--      right_monolith_border = 1,
--      bottom_monolith_border = 1,
--      left_monolith_border = 1,
--      monolith_image =
--      {
--        filename = "__core__/graphics/gui.png",
--        priority = "extra-high-no-scale",
--        width = 32,
--        height = 32,
--        x = 111
--      }
--    }
  }

for typename, sometype in pairs(data.raw) do
  local _, object = next(sometype)
  if object.stack_size then
    for name, item in pairs(sometype) do
      if item.icon then
        local style =
          {
            type = "button_style",
            parent = "st-icon-style",
            width = 32,
            height = 32,
            default_graphical_set =
            {
              type = "monolith",
              top_monolith_border = 1,
              right_monolith_border = 1,
              bottom_monolith_border = 1,
              left_monolith_border = 1,
              monolith_image =
              {
                filename = item.icon,
                priority = "extra-high-no-scale",
                width = 32,
                height = 32,
              }
            },
            hovered_graphical_set =
            {
              type = "monolith",
              top_monolith_border = 1,
              right_monolith_border = 1,
              bottom_monolith_border = 1,
              left_monolith_border = 1,
              monolith_image =
              {
                filename = item.icon,
                priority = "extra-high-no-scale",
                width = 32,
                height = 32
              }
            },
            clicked_graphical_set =
            {
              type = "monolith",
              top_monolith_border = 1,
              right_monolith_border = 1,
              bottom_monolith_border = 1,
              left_monolith_border = 1,
              monolith_image =
              {
                filename = item.icon,
                priority = "extra-high-no-scale",
                width = 32,
                height = 32
              }
            }
          }
        data.raw["gui-style"].default["st-icon-"..name] = style
      end
    end
  end
end

-- Mod defined loading procedures are stored in to this
procedures = {}

-- Overwriting data.extend to take use of procedures
function data.extend(self, otherdata)
  for _, e in ipairs(otherdata) do
    if not e.type or not e.name then
      error("Missing name or type in the following prototype definition " .. serpent.block(e))
    end
    local t = self.raw[e.type]
    if t == nil then
      t = {}
      self.raw[e.type] = t
    end

    t[e.name] = procedures:checkPrototype(e)
  end
end

--For adding new procedure
function procedures:add(func)
  table.insert(self, func)
end

-- Utilize given procedures
function procedures:checkPrototype(prototype)
  for _, f in ipairs(self) do
    prototype = f(prototype) or prototype
  end

  return prototype
end

procedures:add(
  function(prototype)
    if prototype.stack_size and prototype.icon then
      local style =
        {
          type = "button_style",
          parent = "st-icon-style",
          default_graphical_set =
          {
            type = "monolith",
            top_monolith_border = 1,
            right_monolith_border = 1,
            bottom_monolith_border = 1,
            left_monolith_border = 1,
            monolith_image =
            {
              filename = prototype.icon,
              priority = "extra-high-no-scale",
              width = 32,
              height = 32
            }
          },
          hovered_graphical_set =
          {
            type = "monolith",
            top_monolith_border = 1,
            right_monolith_border = 1,
            bottom_monolith_border = 1,
            left_monolith_border = 1,
            monolith_image =
            {
              filename = prototype.icon,
              priority = "extra-high-no-scale",
              width = 32,
              height = 32
            }
          },
          clicked_graphical_set =
          {
            type = "monolith",
            top_monolith_border = 1,
            right_monolith_border = 1,
            bottom_monolith_border = 1,
            left_monolith_border = 1,
            monolith_image =
            {
              filename = prototype.icon,
              priority = "extra-high-no-scale",
              width = 32,
              height = 32
            }
          }
        }
      data.raw["gui-style"].default["st-icon-"..prototype.name] = style
    end
  end
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
        resize_row_to_width = true
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
        resize_row_to_width = true
      }
  }

data.raw["gui-style"].default["st_flow"] =
  {
    type = "flow_style",
    horizontal_spacing = 0,
    vertical_spacing = 2,
    max_on_row = 0,
    resize_row_to_width = true
  }
data.raw["gui-style"].default["st_table"] =
  {
    type = "table_style",
    parent = "table_style",
    resize_row_to_width = true
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
