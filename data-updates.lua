table.insert(data.raw["technology"]["automated-rail-transportation"].effects,
  {
    type="unlock-recipe",
    recipe = "smart-train-stop"
  })

if data.raw["item"]["small-lamp-green"] then
  local st_proxy = copyPrototype("lamp","small-lamp-green","smart-train-stop-proxy")
  st_proxy.energy_usage_per_tick = "250W"
  st_proxy.collision_mask = {"resource-layer"}

  local st_proxy_i = copyPrototype("item","small-lamp-green","smart-train-stop-proxy")
  data.raw["lamp"]["smart-train-stop-proxy"] = st_proxy
  data.raw["item"]["smart-train-stop-proxy"] = st_proxy_i
end
