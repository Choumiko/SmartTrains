table.insert(data.raw["technology"]["automated-rail-transportation"].effects,
  {
    type="unlock-recipe",
    recipe = "smart-train-stop"
  })  

for k,prototype in pairs(data.raw["fluid"]) do
  data:extend(
    {
      {
        type = "item",
        name = "st-fluidItem-"..prototype.name,
        icon = prototype.icon,
        flags = {"goes-to-main-inventory"},
        subgroup = "st-metaitems",
        order = "d[liquid-item]",
        stack_size = 1
      },
    })
    local style =
          {
            type = "checkbox_style",
            parent = "st-icon-style",
            default_background =
            {
              filename = prototype.icon,
              width = 32,
              height = 32
            },
            hovered_background =
            {
              filename = prototype.icon,
              width = 32,
              height = 32
            },
            checked_background =
            {
              filename = prototype.icon,
              width = 32,
              height = 32
            },
            clicked_background =
            {
              filename = prototype.icon,
              width = 32,
              height = 32
            }
          }
      data.raw["gui-style"].default["st-icon-"..prototype.name] = style
end
data.raw["gui-style"].default["st-icon-style"] =
  {
    type = "checkbox_style",
    parent = "checkbox_style",
    width = 32,
    height = 32,
    bottom_padding = 8,
    default_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111
    },
    hovered_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111
    },
    clicked_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111
    },
    checked =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111
    }
  }
for typename, sometype in pairs(data.raw) do
  local _, object = next(sometype)
  if object.stack_size then
    for name, item in pairs(sometype) do
      if item.icon then
        local style =
          {
            type = "checkbox_style",
            parent = "st-icon-style",
            default_background =
            {
              filename = item.icon,
              width = 32,
              height = 32
            },
            hovered_background =
            {
              filename = item.icon,
              width = 32,
              height = 32
            },
            checked_background =
            {
              filename = item.icon,
              width = 32,
              height = 32
            },
            clicked_background =
            {
              filename = item.icon,
              width = 32,
              height = 32
            }
          }
        data.raw["gui-style"].default["st-icon-"..name] = style
      end
    end
  end
end
