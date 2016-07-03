local item = copyPrototype("item","train-stop", "smart-train-stop")
item.icon = "__SmartTrains__/graphics/smart-train-stop-icon.png"
item.order = "a[train-system]-cb[train-stop]"

local recipe = copyPrototype("recipe","train-stop", "smart-train-stop")
recipe.ingredients = {
  {"train-stop", 1},
  {"advanced-circuit", 2}
}
recipe.enabled = false

local smart_train_stop = copyPrototype("train-stop", "train-stop", "smart-train-stop")
smart_train_stop.icon = "__SmartTrains__/graphics/smart-train-stop-icon.png"
smart_train_stop.selection_box = {{-0.6, -0.6}, {0.6, 0.6}}

local st_proxy = copyPrototype("lamp", "small-lamp","smart-train-stop-proxy")
st_proxy.icon = "__SmartTrains__/graphics/lamp/icon.png"
st_proxy.picture_off.filename = "__SmartTrains__/graphics/lamp/light-off.png"
st_proxy.picture_off.shift = { 0, 0 } 
st_proxy.picture_on.filename = "__SmartTrains__/graphics/lamp/light-on-patch.png"
st_proxy.picture_on.shift = { -0.015625, -0.1875 }
st_proxy.energy_usage_per_tick = "250W"
st_proxy.collision_mask = { "resource-layer" }
st_proxy.light = { intensity = 0.5, size = 5, color = { r = 0.02, g = 0.2, b = 0.02, a = 0 } }
st_proxy.minable = nil

local st_proxy_i = copyPrototype("item", "small-lamp", "smart-train-stop-proxy")
table.insert(st_proxy_i.flags, "hidden")

local st_proxyc = copyPrototype("constant-combinator","constant-combinator","smart-train-stop-proxy-cargo")
st_proxyc.collision_mask = {"resource-layer"}
st_proxyc.item_slot_count = 50
st_proxyc.minable = nil

local st_proxyc_i = copyPrototype("item","constant-combinator","smart-train-stop-proxy-cargo")
table.insert(st_proxyc_i.flags, "hidden")

data:extend({smart_train_stop,item,recipe, st_proxy, st_proxy_i,})
data:extend({st_proxyc,st_proxyc_i})

table.insert(data.raw["technology"]["automated-rail-transportation"].effects,
{
  type="unlock-recipe",
  recipe = "smart-train-stop"
})

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

local signalStation = copyPrototype("virtual-signal", "signal-1", "signal-station-number")
signalStation.icon = "__base__/graphics/icons/signal/signal_S.png"
signalStation.subgroup = "virtual-signal"
signalStation.order = "e[smarttrains]-g[stationnumber]"

local signalDestination = copyPrototype("virtual-signal", "signal-1", "signal-destination")
signalDestination.icon = "__base__/graphics/icons/signal/signal_D.png"
signalDestination.subgroup = "virtual-signal"
signalDestination.order = "e[smarttrains]-h[destination]"

data:extend({signalStop, signalLoco, signalCargo, signalPassenger, signalFuel, signalLine, signalStation, signalDestination})
