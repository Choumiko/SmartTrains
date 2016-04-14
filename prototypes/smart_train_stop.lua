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

local copyfrom = "small-lamp"
if data.raw["item"]["small-lamp-green"] then
  copyfrom = "small-lamp-green"
end

local st_proxy = copyPrototype("lamp", copyfrom,"smart-train-stop-proxy")
st_proxy.energy_usage_per_tick = "250W"
st_proxy.collision_mask = {"resource-layer"}

if data.raw["item"]["small-lamp-green"] then
  st_proxy.light = {intensity = 0.5, size = 5, color={1,1,0,0}}
end

local st_proxy_i = copyPrototype("item", copyfrom, "smart-train-stop-proxy")
table.insert(st_proxy_i.flags, "hidden")

local st_proxyc = copyPrototype("constant-combinator","constant-combinator","smart-train-stop-proxy-cargo")
st_proxyc.collision_mask = {"resource-layer"}
st_proxyc.item_slot_count = 50
local st_proxyc_i = copyPrototype("item","constant-combinator","smart-train-stop-proxy-cargo")
table.insert(st_proxyc_i.flags, "hidden")

data:extend({smart_train_stop,item,recipe, st_proxy, st_proxy_i,})
data:extend({st_proxyc,st_proxyc_i})

local signalStop = copyPrototype("virtual-signal", "signal-1", "signal-train-at-station")
signalStop.icon = "__SmartTrains__/graphics/signal_train_at_station.png"
signalStop.subgroup = "virtual-signal"
signalStop.order = "e[smarttrains]-a[train-at-station]"

local signalLoco = copyPrototype("virtual-signal", "signal-1", "signal-locomotives")
signalLoco.icon = "__SmartTrains__/graphics/signal_locomotives.png"
signalLoco.subgroup = "virtual-signal"
signalLoco.order = "e[smarttrains]-b[locomotives]"

local signalCargo = copyPrototype("virtual-signal", "signal-1", "signal-cargowagons")
signalCargo.icon = "__SmartTrains__/graphics/signal_cargowagons.png"
signalCargo.subgroup = "virtual-signal"
signalCargo.order = "e[smarttrains]-c[cargowagons]"

local signalPassenger = copyPrototype("virtual-signal", "signal-1", "signal-passenger")
signalPassenger.icon = "__SmartTrains__/graphics/signal_passenger.png"
signalPassenger.subgroup = "virtual-signal"
signalPassenger.order = "e[smarttrains]-d[passenger]"

local signalFuel = copyPrototype("virtual-signal", "signal-1", "signal-lowest-fuel")
signalFuel.icon = "__SmartTrains__/graphics/signal_lowest_fuel.png"
signalFuel.subgroup = "virtual-signal"
signalFuel.order = "e[smarttrains]-e[lowestfuel]"

local signalLine = copyPrototype("virtual-signal", "signal-1", "signal-line")
signalLine.icon = "__SmartTrains__/graphics/signal_line.png"
signalLine.subgroup = "virtual-signal"
signalLine.order = "e[smarttrains]-f[line]"

data:extend({signalStop, signalLoco, signalCargo, signalPassenger, signalFuel, signalLine})
