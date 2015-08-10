local item = copyPrototype("item","train-stop", "smart-train-stop")
item.icon = "__SmartTrains__/graphics/smart-train-stop-icon.png"
item.order = "a[train-system]-c[train-stop]"
 
local recipe = copyPrototype("recipe","train-stop", "smart-train-stop")
recipe.ingredients = {
  {"train-stop", 1},
  {"advanced-circuit", 2}
}
recipe.enabled = false

local smart_train_stop = copyPrototype("train-stop", "train-stop", "smart-train-stop")
smart_train_stop.icon = "__SmartTrains__/graphics/smart-train-stop-icon.png"

local st_proxy = copyPrototype("lamp","small-lamp","smart-train-stop-proxy")
st_proxy.energy_usage_per_tick = "250W"
st_proxy.light = {intensity = 0.5, size = 5, color={1,1,0,0}}
st_proxy.collision_mask = {"resource-layer"}

local st_proxy_i = copyPrototype("item","small-lamp","smart-train-stop-proxy")

local st_proxyc = copyPrototype("constant-combinator","constant-combinator","smart-train-stop-proxy-cargo")
st_proxyc.collision_mask = {"resource-layer"}
st_proxyc.item_slot_count = 50
local st_proxyc_i = copyPrototype("item","constant-combinator","smart-train-stop-proxy-cargo")

data:extend({smart_train_stop,item,recipe, st_proxy, st_proxy_i,})
data:extend({st_proxyc,st_proxyc_i})

local signalLoco = copyPrototype("virtual-signal", "signal-1", "signal-locomotives")
signalLoco.icon = "__SmartTrains__/graphics/signal_locomotives.png"
signalLoco.subgroup = "virtual-signal"
signalLoco.order = "e[smarttrains]-a[locomotives]"

local signalCargo = copyPrototype("virtual-signal", "signal-1", "signal-cargowagons")
signalCargo.icon = "__SmartTrains__/graphics/signal_cargowagons.png"
signalCargo.subgroup = "virtual-signal"
signalCargo.order = "e[smarttrains]-b[cargowagons]"

data:extend({signalLoco, signalCargo})