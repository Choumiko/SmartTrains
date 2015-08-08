function copyPrototype(type, name, newName)
  local p = table.deepcopy(data.raw[type][name])
  p.name = newName
  if p.minable and p.minable.result then
    p.minable.result = newName
  end
  if p.place_result then
    p.place_result = newName
  end
  return p
end
local item = copyPrototype("item","train-stop", "smart-train-stop")
item.icon = "__SmartTrains__/graphics/smart-train-stop-icon.png"
local recipe = copyPrototype("recipe","train-stop", "smart-train-stop")
recipe.enabled = true

local smart_train_stop = copyPrototype("train-stop", "train-stop", "smart-train-stop")
smart_train_stop.icon = "__SmartTrains__/graphics/smart-train-stop-icon.png"

local st_proxy = copyPrototype("lamp","small-lamp","smart-train-stop-proxy")
st_proxy.energy_usage_per_tick = "250W"
st_proxy.light = {intensity = 0.5, size = 5, color={1,1,0,0}}
--st_proxy.collision_box = {{0,0},{0,0}}
st_proxy.collision_mask = {"resource-layer"}
st_proxy.minable.hardness = 100

local st_proxy_i = copyPrototype("item","small-lamp","smart-train-stop-proxy")

data:extend({smart_train_stop,item,recipe, st_proxy, st_proxy_i})