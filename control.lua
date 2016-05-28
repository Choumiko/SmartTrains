require "defines"
require "util"
require 'stdlib.area.position'
require 'stdlib.surface'
require 'stdlib.string'
require 'stdlib.table'

Logger = require('stdlib.log.logger')

debug = false

LOGGERS = {}

LOGGERS.main = Logger.new("SmartTrains","main", true)
LOGGERS.update = Logger.new("SmartTrains", "updates", true)

-- myevent = game.generateeventname()
-- the name and tick are filled for the event automatically
-- this event is raised with extra parameter foo with value "bar"
--game.raiseevent(myevent, {foo="bar"})
use_EventsPlus = false

if not use_EventsPlus or not remote.interfaces.EventsPlus then
  events = {}
  events["on_player_opened"] = script.generate_event_name()
  events["on_player_closed"] = script.generate_event_name()
end

require("gui")
require("Train")

defaultTrainSettings = {autoRefuel = false}
defaultSettings =
  { refuel = { station = "Refuel", rangeMin = 25*8, rangeMax = 50*8, time = 600 },
    minFlow = 1, -- minimal liquid change to count as changed
    intervals = {
      write = 60, -- ticks between constant combinator updates
      read = 12, -- ticks between reading signal
      noChange = 120, --ticks between cargo comparison
      cargoRule = 12 -- ticks between cargo rule checks (full/empty), refuelcheck
    },
  }

defaultRule = {
  empty = false,
  full = false,
  noChange = false,
  jumpTo = false,
  jumpToCircuit = false,
  keepWaiting = false,
  original_time = 60*30,
  station = "",
  waitForCircuit = false,
  requireBoth = false
}

stationsPerPage = 5
linesPerPage = 5
rulesPerPage = 5
mappingsPerPage = 10

colors = {
  RED = {r = 0.9},
  GREEN = {g = 0.7},
  YELLOW = {r = 0.8, g = 0.8}
}


trainstate = {left_station = 11}

function insertInTable(tableA, key, value)
  if not tableA[key] then tableA[key] = {} end
  table.insert(tableA[key], value)
end

local function debugLog(var, prepend)
  if not global.debug_log then return end
  local str = prepend or ""
  for _,_ in pairs(game.players) do
    local msg
    if type(var) == "string" then
      msg = var
    else
      msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
    end
    --player.print(str..msg)
    log(str..msg)
  end
end

function util.getKeyByValue(tableA, value)
  for i,c in pairs(tableA) do
    if c == value then
      return i
    end
  end
end

function util.formattime(ticks, showTicks)
  if ticks then
    local seconds = ticks / 60
    local minutes = math.floor((seconds)/60)
    seconds = math.floor(seconds - 60*minutes)
    local tick = ticks - (minutes*60*60+seconds*60)
    local format = showTicks and "%d:%02d:%02d" or "%d:%02d"
    return string.format(format, minutes, seconds, tick)
  else
    return "-"
  end
end

function resetMetatable(o, mt)
  setmetatable(o,{__index=mt})
  return o
end

function setMetatables()
  for _, object in pairs(global.trains) do
    resetMetatable(object, Train)
  end

  if global.update_cargo then
    for _, tick in pairs(global.update_cargo) do
      for _, object in pairs(tick) do
        resetMetatable(object, Train)
      end
    end
  end

  if global.check_rules then
    for _, tick in pairs(global.check_rules) do
      for _, object in pairs(tick) do
        resetMetatable(object, Train)
      end
    end
  end
end

function initGlob()
  global = global or {}
  global.version = global.version or "0.3.75"
  global.trains = global.trains or {}
  global.trainLines = global.trainLines or {}

  global.scheduleUpdate = global.scheduleUpdate or {}
  global.update_cargo = global.update_cargo or {}
  global.check_rules = global.check_rules or {}
  global.refueling = global.refueling or {}

  global.player_opened = global.player_opened or {}
  global.player_passenger = global.player_passenger or {}
  global.showFlyingText = global.showFlyingText or false
  global.playerPage = global.playerPage or {}
  global.playerRules = global.playerRules or {}

  global.guiData = global.guiData or {}
  global.openedName = global.openedName or {}
  global.openedTrain = global.openedTrain or {}

  -- by force
  global.stationCount = global.stationCount or {}
  global.smartTrainstops = global.smartTrainstops or {}
  global.stationMapping = global.stationMapping or {}
  global.stationMap = global.stationMap or {}

  global.settings = global.settings or defaultSettings

  global.settings.stationsPerPage = stationsPerPage
  global.settings.linesPerPage = linesPerPage
  global.settings.rulesPerPage = rulesPerPage
  global.settings.mappingsPerPage = mappingsPerPage

  global.settings.intervals = global.settings.intervals or {}
  global.settings.intervals.write = global.settings.intervals.write or defaultSettings.intervals.write
  global.settings.intervals.read = global.settings.intervals.read or defaultSettings.intervals.read
  global.settings.intervals.noChange = global.settings.intervals.noChange or defaultSettings.intervals.noChange

  global.fuel_values = global.fuel_values or {}
  global.fuel_values["coal"] = game.item_prototypes["coal"].fuel_value/1000000

  global.blueprinted_proxies = global.blueprinted_proxies or {}

  setMetatables()
end

local function init_player(player)
  global.playerRules[player.index] = global.playerRules[player.index] or {page=1}
end

local function init_players()
  for _,player in pairs(game.players) do
    init_player(player)
  end
end

local function init_force(force)
  initGlob()
  global.stationCount[force.name] = global.stationCount[force.name] or {}
  global.smartTrainstops[force.name] = global.smartTrainstops[force.name] or {}
  global.stationMapping[force.name] = global.stationMapping[force.name] or {}
  global.stationMap[force.name] = global.stationMap[force.name] or {}
end

local function init_forces()
  for _, force in pairs(game.forces) do
    init_force(force)
  end
end

local function on_force_created(event)
  init_force(event.force)
end

local function on_player_created(event)
  init_player(game.players[event.player_index])
end

function oninit()
  initGlob()
  init_forces()
  init_players()
  findStations()
end

function onload()
  log("on load")
  --initGlob()
  setMetatables()
  --local rem = removeInvalidTrains(false)
  --if rem > 0 then debugDump("You should never see this! Removed "..rem.." invalid trains") end
end

local function updateSetting(setting, defaults, old_keys)
  setting = table.update(setting, defaults, true) table.remove_keys(setting, old_keys)
end

local function update_0_3_77()
  global.settings.lines = nil
  global.stopTick = nil
  for _, line in pairs(global.trainLines) do
    for i,record in pairs(line.records) do
      if not line.rules then line.rules = {} end
      if not line.rules[i] then
        local rule = {}
        rule.empty = false
        rule.full = false
        rule.jumpTo = false
        rule.jumpToCircuit = false
        rule.keepWaiting = false
        rule.original_time = record.time_to_wait
        rule.station = record.station
        rule.waitForCircuit = false
        line.rules[i] = rule
      else
        if not line.rules[i].original_time then
          line.rules[i].original_time = record.time_to_wait
        end
        if line.rules[i].keepWaiting then
          record.time_to_wait = 2^32-1
        end
      end
    end
    if line.rules[false] then line.rules[false] = nil end
    line.number = 0
    line.changed = game.tick
  end
  local trainLine, rules
  for _, train in pairs(global.trains) do
    if train.line and global.trainLines[train.line] and train.waitForever then
      trainLine = global.trainLines[train.line]
      rules = trainLine.rules
      local schedule = {records={}, current=train.train.schedule.current}
      for i, record in pairs(trainLine.records) do
        if rules then
          if rules[i].keepWaiting then
            record.time_to_wait = 2^32-1
          else
            record.time_to_wait = rules[i].original_time
          end
        end
        schedule.records[i] = record
      end
      train.train.schedule = schedule
    end
  end
  return "0.3.77"
end

local update_from_version = {
  ["0.0.0"] = function()
    return update_0_3_77()
  end,
  ["0.3.77"] = function() return "0.3.78" end,
  ["0.3.78"] = function() return "0.3.79" end,
  ["0.3.79"] = function() return "0.3.80" end,
  ["0.3.80"] = function() return "0.3.81" end,
  ["0.3.81"] = function() return "0.3.82" end,
  ["0.3.82"] = function()
    for _, line in pairs(global.trainLines) do
      for _, rule in pairs(line.rules) do
        if (rule.empty or rule.full) and rule.waitForCircuit then
          rule.requireBoth = true
        else
          rule.requireBoth = false
        end
      end
    end
    local c = 0
    for i, t in pairs(global.trains) do
      t.dynamic = nil
      if t.settings then
        t.settings.autoDepart = nil
      end
      t.type = t:getType()
      if t.waitingStation and t.waitingStation.station and t.waitingStation.station.valid then
        t.waitingStation.key = stationKey(t.waitingStation.station)
      end
      local update
      local line = t.line and global.trainLines[t.line]
      if line then
        update = t.lineVersion < global.trainLines[t.line].changed
      elseif t.line and not global.trainLines[t.line] then
        update = true
      end

      if update then
        t.scheduleUpdate = game.tick + 60 + i
        insertInTable(global.scheduleUpdate, t.scheduleUpdate, t)
        c = c + 1
        log(t.scheduleUpdate .. ": " .. i)
      end
    end
    log(game.tick .. " Total: " .. c)
    removeInvalidTrains(true,true)
    global.stationCount = {}
    global.smartTrainstops = {}
    init_forces()
    findStations()

    for _, l in pairs(global.trainLines) do
      l.settings.useMapping = false
      l.settings.number = l.number or 0
      l.number = nil
      l.settings.autoDepart = nil
    end
    local smart_stop
    local found
    for _, t in pairs(global.trains) do
      if t.waitingStation and t.waitingStation.key then
        found = false
        smart_stop = global.smartTrainstops[t.train.carriages[1].force.name][t.waitingStation.key]
        t.waitingStation = smart_stop
        for tick, trains in pairs(global.updateTick) do
          for i, t2 in pairs(trains) do
            if t.train == t2.train and not found then
              --log("Uref found["..tick .."]["..i.."] "..t.name)
              global.updateTick[tick][i] = t
              t.updateTick = tick
              found = true
            end
          end
        end
      end
    end
    return "0.3.9"
  end,
  ["0.3.9"] = function()
    global.settings.intervals.write = global.settings.circuit.interval or defaultSettings.intervals.write
    global.settings.intervals.read = global.settings.circuit.interval or defaultSettings.intervals.read
    global.settings.intervals.noChange = defaultSettings.intervals.noChange
    global.settings.intervals.cargoRule = global.settings.intervals.read --defaultSettings.intervals.cargoRule
    global.settings.minFlow = global.settings.depart.minFlow or defaultSettings.minFlow

    global.settings.circuit = nil
    global.settings.depart = nil

    global.update_cargo = global.updateTick or {}
    global.check_rules = global.ticks or {}

    for _, t in pairs(global.trains) do
      t.type = t:getType()
      t.update_cargo = t.updateTick
      t.updateTick = nil
      t.last_fuel_update = 0
      t:lowestFuel()
      t:check_filters()
      t.passengers = 0

      if t.waiting then
        if t.waiting.lastCheck then
          t.waiting.lastCargoCheck = t.waiting.lastCheck
          t.waiting.nextCargoCheck = t.waiting.lastCheck + global.settings.intervals.noChange
          t.waiting.nextCargoRule = t.waiting.lastCheck + global.settings.intervals.write
          t.waiting.lastCheck = nil
        end
      end

      if t.refueling then
        local tick = type(t.refueling) == "table" and t.refueling.nextCheck or t.refueling
        insertInTable(global.refueling, tick, t)
        t.refueling = tick
      end

      for _, c in pairs(t.train.carriages) do
        if c.name == "rail-tanker" then
          t.railtanker = true
        end
        if c.passenger ~= nil and c.passenger.connected and c.passenger.character.name ~= "fatcontroller" then
          t.passengers = t.passengers + 1
          global.player_passenger[c.passenger.index] = c
        end
      end
    end
    global.updateTick = nil
    global.ticks = nil
    return "0.3.91"
  end,
}

function on_configuration_changed(data)
  local status, err = pcall(function()
    if not data or not data.mod_changes then
      return
    end
    --debugDump(data,true)
    if data.mod_changes.SmartTrains then
      local old_version = data.mod_changes.SmartTrains.old_version
      local new_version = data.mod_changes.SmartTrains.new_version
      LOGGERS.main.log("Updating SmartTrains from " .. serpent.line(old_version, {comment=false}) .. " to " .. new_version)
      local searched_stations = false
      initGlob()
      init_forces()
      init_players()
      setMetatables()
      if old_version then
        saveGlob("PreUpdate"..old_version.."_"..game.tick)
        local ver = update_from_version[old_version] and old_version or "0.0.0"
        while ver ~= "0.3.91" do
          log(ver)
          ver = update_from_version[ver]()
        end
        debugDump("SmartTrains version changed from "..old_version.." to "..ver,true)
      end
      if not old_version then
        findStations()
      end
      global.version = new_version
      if old_version then
        saveGlob("PostUpdate"..old_version.."_"..game.tick)
      end
      LOGGERS.main.log("Updating to " .. new_version .." done, tick: " .. game.tick)
      LOGGERS.main.write()
    end
    --update fuelvalue cache, in case the values changed
    for item, _ in pairs(global.fuel_values) do
      global.fuel_values[item] = game.item_prototypes[item].fuel_value/1000000
    end
  end)
  if not status then
    LOGGERS.main.write()
    error(err, 2)
  end
end

local function getProxyPositions(trainstop)
  local offset = {[0] = {x=-0.5,y=-0.5},[2]={x=0.5,y=-0.5},[4]={x=0.5,y=0.5},[6]={x=-0.5,y=0.5}}
  local offsetcargo = {[0] = {x=-0.5,y=0.5},[2]={x=-0.5,y=-0.5},[4]={x=0.5,y=-0.5},[6]={x=0.5,y=0.5}}
  local pos = Position.add(trainstop.position, offset[trainstop.direction])
  local poscargo = Position.add(trainstop.position, offsetcargo[trainstop.direction])
  return {signalProxy = pos, cargo = poscargo}
end

function createProxy(trainstop)
  local positions = getProxyPositions(trainstop)
  local key = stationKey(trainstop)
  local keySignal = stationKey({position=positions.signalProxy})
  local keyCargo = stationKey({position=positions.cargo})
  local signalProxy, cargoProxy
  local force = trainstop.force.name
  local proxy = {name="smart-train-stop-proxy", direction=0, force=trainstop.force, position=positions.signalProxy}
  local proxycargo = {name="smart-train-stop-proxy-cargo", direction=0, force=trainstop.force, position=positions.cargo}
  if global.blueprinted_proxies[keySignal] then
    local signal = global.blueprinted_proxies[keySignal]
    if signal and signal.valid then
      debugDump("signal: "..serpent.line(signal.position),true)
      signal.revive()
    end
    global.blueprinted_proxies[keySignal] = nil
  end
  if global.blueprinted_proxies[keyCargo] then
    local cargo = global.blueprinted_proxies[keyCargo]
    if cargo and cargo.valid then
      debugDump("cargo: "..serpent.line(cargo.position),true)
      cargo.revive()
    end
    global.blueprinted_proxies[keyCargo] = nil
  end

  signalProxy = trainstop.surface.find_entity("smart-train-stop-proxy", positions.signalProxy)
  if not signalProxy then
    signalProxy = trainstop.surface.create_entity(proxy)
  end

  cargoProxy = trainstop.surface.find_entity("smart-train-stop-proxy-cargo", positions.cargo)
  if not cargoProxy then
    cargoProxy = trainstop.surface.create_entity(proxycargo)
  end
  if signalProxy.valid and cargoProxy.valid then
    cargoProxy.operable = false
    cargoProxy.destructible = false
    cargoProxy.set_circuit_condition(1, {parameters={}})
    signalProxy.destructible = false
    if not global.smartTrainstops[force][key] then
      global.smartTrainstops[force][key] = {station = trainstop, signalProxy = signalProxy, cargo = cargoProxy}
    end
  else
    pauseError("Could not find signal/cargo proxy for " .. trainstop.backer_name .. " @ " .. serpent.line(trainstop.position,{comment=false}))
  end
end

function removeProxy(trainstop)
  local force = trainstop.force.name
  local key = stationKey(trainstop)
  if global.smartTrainstops[force][key] then
    local proxy = global.smartTrainstops[force][key].signalProxy
    local cargo = global.smartTrainstops[force][key].cargo
    if proxy and proxy.valid then
      proxy.destroy()
    end
    if cargo and cargo.valid then
      cargo.destroy()
    end
    global.smartTrainstops[force][key] = nil
  end
end

local function recreateProxy(trainstop)
  local positions = getProxyPositions(trainstop)

  if trainstop.station.valid then
    local force = trainstop.station.force.name
    if not trainstop.cargo or not trainstop.cargo.valid then
      local poscargo = positions.cargo
      local proxycargo = {name="smart-train-stop-proxy-cargo", direction=0, force=trainstop.station.force, position=poscargo}
      local ent2 = trainstop.station.surface.create_entity(proxycargo)
      if ent2.valid then
        global.smartTrainstops[force][stationKey(trainstop.station)].cargo = ent2
        ent2.minable = false
        ent2.operable = false
        ent2.destructible = false
        debugDump("Updated smart train stop:"..trainstop.station.backer_name,true)
      end
    end
    if not trainstop.signalProxy or not trainstop.signalProxy.valid then
      local pos = positions.signalProxy
      local proxy = {name="smart-train-stop-proxy", direction=0, force=trainstop.station.force, position=pos}
      local ent = trainstop.station.surface.create_entity(proxy)
      if ent.valid then
        global.smartTrainstops[force][stationKey(trainstop.station)].signalProxy=ent
        ent.minable = false
        ent.destructible = false
      end
    end
  end
end

function findSmartTrainStopByTrain(vehicle, stationName)
  local surface = vehicle.surface
  local found = false

  local area = Position.expand_to_area(vehicle.position, 3)
  --for _,area in pairs(areas) do
  for _, station in pairs(surface.find_entities_filtered{area=area, name="smart-train-stop"}) do
    --flyingText("S", GREEN, station.position, true)
    if station.backer_name == stationName then
      found = station
      break
    end
    if found then break end
  end
  if found then
    found = global.smartTrainstops[vehicle.force.name][stationKey(found)] or false
  end
  return found
end

function removeInvalidTrains(show)
  local removed = 0
  show = show or debug
  for i=#global.trains,1,-1 do
    local ti = global.trains[i]
    if not ti.train or not ti.train.valid or (#ti.train.locomotives.front_movers == 0 and #ti.train.locomotives.back_movers == 0) then
      ti:resetCircuitSignal()

      table.remove(global.trains, i)
      removed = removed + 1
      -- try to detect change through pressing G/V
    else
      local test = ti:getType()
      if test ~= ti.type then
        ti:resetCircuitSignal()
        table.remove(global.trains, i)
        removed = removed + 1
      end
    end
  end
  if removed > 0 and show then
    flyingText("Removed "..removed.." invalid trains", colors.RED, false, true)
  end
  return removed
end

function inSchedule(station, schedule)
  if type(schedule) == "table" and type(schedule.records) == "table" then
    for i, rec in pairs(schedule.records) do
      if rec.station == station then
        return i
      end
    end
  end
  return false
end

function removeStation(station, schedule)
  local found = false
  local tmp = schedule
  for i, rec in pairs(schedule.records) do
    if rec.station == station then
      found = i
    end
  end
  if found then
    table.remove(schedule.records, found)
  end
  return tmp
end

function addStation(station, schedule, wait, after)
  wait = wait or 600
  local tmp = {time_to_wait = wait, station = station}
  if after then
    table.insert(schedule.records, after+1, tmp)
  else
    table.insert(schedule.records, tmp)
  end
  return schedule
end

function fuelvalue(item)
  if not global.fuel_values[item] then
    global.fuel_values[item] = game.item_prototypes[item].fuel_value/1000000
  end
  --return game.item_prototypes[item].fuel_value/1000000
  return global.fuel_values[item]
end

function fuel_value_to_coal(value)
  return math.ceil(value/global.fuel_values["coal"])
end

function addInventoryContents(invA, invB)
  local res = {}
  for item, c in pairs(invA) do
    invB[item] = invB[item] or 0
    res[item] = c + invB[item]
    invB[item] = nil
    if res[item] == 0 then res[item] = nil end
  end
  for item,c in pairs(invB) do
    res[item] = c
    if res[item] == 0 then res[item] = nil end
  end
  return res
end

function on_train_changed_state(event)
  --debugDump(game.tick.." "..getKeyByValue(defines.trainstate, event.train.state),true)
  --log("state change : ".. util.getKeyByValue(defines.trainstate, event.train.state))
  --debugLog("train changed state to "..event.train.state.. " s")
  local status, err = pcall(function()
    local train = event.train
    local trainKey = getTrainKeyByTrain(global.trains, train)
    local t
    if trainKey then
      t = global.trains[trainKey]
    end
    if not trainKey or (t.train and not t.train.valid) then
      removeInvalidTrains(true)
      getTrainFromEntity(train.carriages[1])
      trainKey = getTrainKeyByTrain(global.trains, train)
      t = global.trains[trainKey]
    end
    if not t.train or not t.train.valid then
      local name = "cargo wagon"
      if train.locomotives ~= nil and (#train.locomotives.front_movers > 0 or #train.locomotives.back_movers > 0) then
        name = train.locomotives.front_movers[1].backer_name or train.locomotives.back_movers[1].backer_name
      end
      debugDump("Couldn't validate train "..name,true)
      return
    end
    t:updateState()
    if t.advancedState == trainstate.left_station then
      t:resetWaitingStation()
      t:updateLine()
      return
    end
    if train.state == defines.trainstate.wait_signal or train.state == defines.trainstate.arrive_signal then
      return
    end
    local settings = global.trains[trainKey].settings
    local lowest_fuel = t:lowestFuel()
    t.min_fuel = lowest_fuel
    local schedule = train.schedule
    if train.state == defines.trainstate.manual_control_stop or train.state == defines.trainstate.manual_control then
      local done = false
      for _, trains in pairs(global.check_rules) do
        for i, trainData in pairs(trains) do
          if trainData == t then
            t:resetWaitingStation()
            trains[i] = nil
            done = true
          end
        end
      end
      if not done then
        for _, train_ in pairs(global.trains) do
          if train_ == t then
            t:resetWaitingStation()
          end
        end
      end
    elseif train.state == defines.trainstate.wait_station then
      LOGGERS.main.log("Train arrived at " .. t:currentStation() .. "\t\t  train: " .. t.name .. " Speed: " .. t.train.speed)
      t:updateLine()
      t:setWaitingStation()

      t.departAt = event.tick + schedule.records[schedule.current].time_to_wait
      if settings.autoRefuel then
        if lowest_fuel >= (global.settings.refuel.rangeMax) and t:currentStation() ~= t:refuelStation() then
          t:removeRefuelStation()
        end
        if t:currentStation() == t:refuelStation() and #schedule.records == schedule.current then
          t:startRefueling()
        end
      end
    elseif train.state == defines.trainstate.arrive_station then
      if t.settings.autoRefuel then
        if lowest_fuel < (global.settings.refuel.rangeMin) and not inSchedule(t:refuelStation(), train.schedule) then
          train.schedule = addStation(t:refuelStation(), train.schedule, global.settings.refuel.time)
          if global.showFlyingText then
            t:flyingText("Refuel station added", colors.YELLOW)
          end
        end
      end
      t.direction = t.train.speed < 0 and 1 or 0
    end
  end)
  if not status then
    pauseError(err, "train_changed_state")
  end
  --debugLog("train changed state to "..event.train.state.. " e")
  --log("state change e")
end

--https://github.com/GopherAtl/logistic-combinators/blob/master/control.lua
function deduceSignalValue(entity,signal,condNum)
  local t=2^31
  local v=0
  condNum=condNum or 1
  local condition=entity.get_circuit_condition(condNum)
  local restore = util.table.deepcopy(condition)
  condition.condition.first_signal=signal
  condition.condition.comparator="<"
  while t~=1 do
    condition.condition.constant=v
    entity.set_circuit_condition(condNum,condition)
    t=t/2
    if entity.get_circuit_condition(condNum).fulfilled==true then
      v=v-t
    else
      v=v+t
    end
  end
  condition.condition.constant=v
  entity.set_circuit_condition(condNum,condition)
  if entity.get_circuit_condition(condNum).fulfilled then
    v=v-1
  end
  entity.set_circuit_condition(condNum,restore)
  return v
end

function on_tick(event)
  local current_tick = event.tick


  if global.refueling[current_tick] then
    local status,err = pcall(function()
      local remove_invalid = false
      for _, train in pairs(global.refueling[current_tick]) do
        if train.train and train.train.valid then
          if train.refueling and train.refueling == current_tick then
            if train:lowestFuel() >= global.settings.refuel.rangeMax then
              train:refuelingDone(true)
            else
              train.refueling = current_tick + global.settings.intervals.noChange
              insertInTable(global.refueling, train.refueling, train)
            end
          --else
            --LOGGERS.main.log("Invalid tick refueling \t"..train.name)
            --LOGGERS.main.log(serpent.block(train,{comment=false}))
          end
        else
          remove_invalid = true
        end
      end
      if remove_invalid then removeInvalidTrains(true) end
    end)
    if not status then
      pauseError(err, "on_tick: refueling")
    end
    global.refueling[current_tick] = nil
  end

  -- update cargo (setWaitingStation <- only if smart stop or full/empty/noChange rule set
  -- write to combinator (setWaitingStation
  if global.update_cargo[current_tick] then
    local status,err = pcall(function()
      local remove_invalid = false
      for _, train in pairs(global.update_cargo[current_tick]) do
        if train.train and train.train.valid then
          if train.update_cargo and train.update_cargo == current_tick then
            --LOGGERS.main.log("tick cargo \t"..train.name)
            --log(current_tick .. " set circuit")
            train:setCircuitSignal()
            --train:updateCircuitSignal()
            --log("set circuit e")
            train.update_cargo = current_tick + global.settings.intervals.write
            insertInTable(global.update_cargo, train.update_cargo, train)
            --else
            --log(game.tick .. " " .. train.name .. " invalid updatetick")
          --else
            --LOGGERS.main.log("Invalid tick cargo \t"..train.name)
            --LOGGERS.main.log(serpent.block(train,{comment=false}))
          end
        else
          remove_invalid = true
        end
      end
      if remove_invalid then removeInvalidTrains(true) end
    end)
    if not status then
      pauseError(err, "on_tick: update_cargo")
    end
    global.update_cargo[current_tick] = nil
  end

  -- read signal from lamp (only if smart stop and (waitForCircuit or goto signal)
  -- read signal value from lamp (only if smart stop and (signal == true and ((waitForCircuit and not requireBoth) or (full/empty and goto signal))
  -- check rules (only if rules set, only check necessary rules
  if global.check_rules[current_tick] then
    local status,err = pcall(function()
      local remove_invalid = false
      for _, train in pairs(global.check_rules[current_tick]) do
        if train.train and train.train.valid then
          --LOGGERS.main.log("tick signal \t"..train.name)
          --debugLog(" tick s", game.tick)
          if global.showFlyingText then
            train.lastMessage = train.lastMessage or 0
            if train.departAt  and current_tick - train.lastMessage >= 120 then
              local text
              if train.waitForever then
                text = "waiting forever"
              else
                text = "Leaving in "..util.formattime(train.departAt-current_tick)
              end
              train:flyingText(text, colors.RED,{offset=-2})
            end
          end
          if train:isWaitingForRules() and current_tick == train.waiting.nextCheck then
            local rules = train:get_rules()
            --debugDump(rules,true)
            local full = false
            local empty = false
            local noChange = false
            local signal = false

            -- fastest rule!?
            if rules.waitForCircuit then
              signal = train:getCircuitSignal()
              --log(current_tick .. " signal valid "..serpent.line(signal,{comment=false}))
            end

            -- full/empty checks only if necessary
            if not rules.requireBoth or (rules.requireBoth and signal) then
              if current_tick >= train.waiting.nextCargoRule or (rules.requireBoth and signal) then
                if rules.full then
                  full = train:isCargoFull()
                  log(current_tick .. " cargo full "..serpent.line(full,{comment=false}))
                  train.waiting.nextCargoRule = current_tick + global.settings.intervals.cargoRule
                end
                if rules.empty then
                  empty = train:isCargoEmpty()
                  log(current_tick .. " cargo empty "..serpent.line(empty,{comment=false}))
                  train.waiting.nextCargoRule = current_tick + global.settings.intervals.cargoRule
                end
              end
            end
            if rules.noChange and (current_tick >= train.waiting.nextCargoCheck) then
              local cargo
              cargo = train:cargoCount()
              noChange = train:cargoEquals(cargo, train.waiting.cargo, global.settings.minFlow, current_tick - train.waiting.lastCargoCheck)
              --log(current_tick .. " no change "..serpent.line(noChange,{comment=false}))
              train.waiting.cargo = cargo
              train.waiting.nextCargoCheck = current_tick + global.settings.intervals.noChange
              train.waiting.lastCargoCheck = current_tick
            end

            local cargo_requirement = (rules.full and full) or (rules.empty and empty) or (rules.noChange and noChange)
            local keepWaiting
            if (rules.requireBoth and cargo_requirement and signal)
              or (not rules.requireBoth and ( cargo_requirement or ( rules.waitForCircuit and signal )))
            then
              --LOGGERS.main.log("Train ready for departure from " .. train:currentStation() .. "\t\t  train: " .. train.name)
              local signalValue = false
              if rules.jumpToCircuit then
                signalValue = rules.jumpToCircuit and train:getCircuitValue() or false
                log(current_tick .. " signal value "..serpent.line(signalValue, {comment=false}))
              end
              local use_mapping = global.trainLines[train.line] and global.trainLines[train.line].settings.useMapping or false
              local jump
              if use_mapping then
                local jumpSignal, jumpTo
                if signalValue then
                  jumpSignal = train:get_first_matching_station(signalValue)
                  log("jumpSignal:" .. serpent.line(jumpSignal, {comment=false}))
                  --LOGGERS.main.log("Mapping signal \t" .. signalValue .. " to " .. (train:getStationName(jumpSignal) or " invalid index"))
                end
                if rules.jumpTo then
                  jumpTo = train:get_first_matching_station(rules.jumpTo)
                  log("jumpTo:" .. serpent.line(jumpTo, {comment=false}))
                  --LOGGERS.main.log("Mapping station # \t" .. rules.jumpTo .. " to " .. (train:getStationName(jumpTo) or " invalid index"))
                end
                jump = jumpSignal or jumpTo or false

              else
                jump = (signal and train:isValidScheduleIndex(signalValue)) or rules.jumpTo or false
              end
              train:waitingDone(true, jump)
              keepWaiting = false
            else
              if global.showFlyingText then
                local txt = (rules.full and not full) and "not full" or "not empty"
                txt = rules.waitForCircuit and "waiting for circuit" or txt
                if rules.full or rules.empty or rules.waitForCircuit then
                  if current_tick - train.lastMessage >= 120 then
                    train:flyingText(txt, colors.YELLOW, {offset=-1})
                    train.lastMessage = current_tick
                  end
                end
              end
              keepWaiting = true
            end
            if keepWaiting and train.train.speed == 0 then
              local nextCheck = current_tick + global.settings.intervals.read
              train.waiting.nextCheck = nextCheck
              insertInTable(global.check_rules, nextCheck, train)
            else
              train:resetWaitingStation()
              --TODO remove copied rules
            end
          end
        else
          remove_invalid = true
        end
      end
      if remove_invalid then removeInvalidTrains(true) end
    end)
    if not status then
      pauseError(err, "on_tick: check_rules")
    end
    global.check_rules[current_tick] = nil
  end

  if global.scheduleUpdate[current_tick] then
    local status,err = pcall(function()
      --log(current_tick .. " scheduleUpdate " .. #global.scheduleUpdate[current_tick])
      local remove_invalid = false
      for _,train in pairs(global.scheduleUpdate[current_tick]) do
        if train.train and train.train.valid then
          if train.line and train.scheduleUpdate == current_tick and not train:updateLine() then
            --log(current_tick .. " retry " .. train.name)
            --line wasn't updated, retry in 1 second
            train.scheduleUpdate = current_tick + 60
            insertInTable(global.scheduleUpdate, train.scheduleUpdate, train)
          end
        else
          remove_invalid = true
        end
      end
      if remove_invalid then removeInvalidTrains(true) end
    end)
    if not status then
      pauseError(err, "on_tick: updateLine")
    end
    global.scheduleUpdate[current_tick] = nil
  end

  if not use_EventsPlus or not remote.interfaces.EventsPlus and current_tick%10==9  then
    if current_tick%10==9  then
      local status,err = pcall(function()
        for pi, player in pairs(game.players) do
          if player.connected then
            if player.opened ~= nil and not global.player_opened[player.name] then
              game.raise_event(events["on_player_opened"], {entity=player.opened, player_index=pi})
              global.player_opened[player.name] = player.opened
            end
            if global.player_opened[player.name] and player.opened == nil then
              game.raise_event(events["on_player_closed"], {entity=global.player_opened[player.name], player_index=pi})
              global.player_opened[player.name] = nil
            end
          end
        end
      end)
      if not status then
        pauseError(err, "on_tick_players")
      end
    end
  end
end

function on_player_opened(event)
  if event.entity.valid and game.players[event.player_index].valid then
    if event.entity.type == "locomotive" and event.entity.train then
      global.playerPage[event.player_index] = {schedule=1,lines=1}
      local trainInfo = getTrainFromEntity(event.entity)
      removeInvalidTrains(true,true)
      GUI.create_or_update(trainInfo, event.player_index)
      global.guiData[event.player_index] = {rules={}}
      global.openedTrain[event.player_index] = event.entity.train
      if trainInfo then
        trainInfo.opened = true
      end
    elseif event.entity.type == "train-stop" then
      global.playerPage[event.player_index] = {schedule=1,lines=1}
      local force = game.players[event.player_index].force.name
      global.guiData[event.player_index] = {rules={}, mapping=table.deepcopy(global.stationMapping[force])}
      GUI.create_or_update(false, event.player_index)
      global.openedName[event.player_index] = event.entity.backer_name
    end
  end
end

function on_player_closed(event)
  if event.entity.valid and game.players[event.player_index].valid then
    if event.entity.type == "locomotive" or event.entity.type == "cargo-wagon" then
      local train = getTrainFromEntity(event.entity)
      if event.entity.type == "locomotive" then
        GUI.destroy(event.player_index)
        global.openedTrain[event.player_index] = nil
        --set line version to -1, so it gets updated at the next station
        train.opened = nil
        if train.line and train.lineVersion ~= 0 then
          train.lineVersion = -1
        end
      else
        train:check_filters()
      end
    elseif event.entity.type == "train-stop" then
      GUI.destroy(event.player_index)
      if event.entity.backer_name ~= global.openedName[event.player_index] then
        on_station_rename(event.entity, global.openedName[event.player_index])
      end
    end
  end
end

function decreaseStationCount(force, name)
  if not global.stationCount[force][name] then
    global.stationCount[force][name] = 1
  end
  global.stationCount[force][name] = global.stationCount[force][name] - 1
  if global.stationCount[force][name] == 0 then
    local found = false
    for _, data in pairs(global.trainLines) do
      for _, record in pairs(data.records) do
        if record.station == name then
          found = true
          break
        end
      end
    end
    if not found then
      global.stationCount[force][name] = nil
      return 0
    end
  end
  return global.stationCount[force][name]
end

function increaseStationCount(force, name)
  if not global.stationCount[force][name] or global.stationCount[force][name] < 0 then
    global.stationCount[force][name] = 0
  end
  global.stationCount[force][name] = global.stationCount[force][name] + 1
  return global.stationCount[force][name]
end

function renameStation(newName, oldName)
  --update global.trainLines with new name
  --debugDump("Updating lines",true)
  for line, data in pairs(global.trainLines) do
    for _, record in pairs(data.records) do
      if record.station == oldName then
        debugDump("Line "..line.." changed: "..oldName.." to "..newName,true) --TODO localisation
        record.station = newName
      end
    end
    if type(data.rules) == "table" then
      for _, rule in pairs(data.rules) do
        if rule.station == oldName then
          rule.station = newName
        end
      end
    end
  end
end

function on_station_rename(station, oldName)
  local force = station.force.name
  local oldc = decreaseStationCount(force, oldName)
  if oldc == 0 then
    renameStation(station.backer_name, oldName)
    global.stationMapping[force][oldName] = nil
    for i, stations in pairs(global.stationMap[force]) do
      stations[oldName] = nil
      if not next(global.stationMap[force][i]) then
        global.stationMap[force][i] = nil
      end
    end
  end
  increaseStationCount(force,station.backer_name)
end

if use_EventsPlus and remote.interfaces.EventsPlus then
  script.on_event(remote.call("EventsPlus", "getEvent", "on_player_opened"), on_player_opened)
  script.on_event(remote.call("EventsPlus", "getEvent", "on_player_closed"), on_player_closed)
else
  script.on_event(events.on_player_opened, on_player_opened)
  script.on_event(events.on_player_closed, on_player_closed)
end

function getTrainFromEntity(ent)
  for _,trainInfo in pairs(global.trains) do
    if ent.train == trainInfo.train then
      return trainInfo
    end
  end
  local new = Train.new(ent.train)
  table.insert(global.trains, new)
  return new
end

function getTrainKeyByTrain(table, train)
  for i,trainInfo in pairs(table) do
    if train == trainInfo.train then
      return i
    end
  end
  return false
end

function getTrainKeyFromUI(index)
  local player = game.players[index]
  local key
  if player.opened ~= nil and player.opened.valid then
    if player.opened.type == "locomotive" and player.opened.train ~= nil then
      key = getTrainKeyByTrain(global.trains, player.opened.train)
      if not key then
        getTrainFromEntity(player.opened)
        key = getTrainKeyByTrain(global.trains, player.opened.train)
      end
    end
    return key
  end
end

function on_built_entity(event)
  local status, err = pcall(function()
    local ent = event.created_entity
    local ctype = ent.type
    --debugDump({e=ent.ghost_name, t=ctype},true)
    if ctype == "entity-ghost" then
      if (ent.ghost_name == "smart-train-stop-proxy" or ent.ghost_name == "smart-train-stop-proxy-cargo") then
        global.blueprinted_proxies[stationKey(ent)] = ent
      end
    end
    if ctype == "locomotive" or ctype == "cargo-wagon" then
      getTrainFromEntity(ent)
      removeInvalidTrains(true)
    end
    if ctype == "train-stop" then
      increaseStationCount(ent.force.name, ent.backer_name)
    end
    if ent.name == "smart-train-stop" then
      createProxy(event.created_entity)
    end
  end)
  if not status then
    pauseError(err, "on_built_entity")
  end
end

function on_preplayer_mined_item(event)
  local status, err = pcall(function()
    local ent = event.entity
    local ctype = ent.type
    if ctype == "locomotive" or ctype == "cargo-wagon" then
      local ownPos
      for i,carriage in pairs(ent.train.carriages) do
        if ent == carriage then
          ownPos = i
          break
        end
      end
      local old = getTrainKeyByTrain(global.trains, ent.train)
      if old then
        local t = global.trains[old]
        if t then
          t:resetCircuitSignal()
        end
        table.remove(global.trains, old)
      end
      removeInvalidTrains(true)

      if #ent.train.carriages > 1 then
        if not global.tmpPos then global.tmpPos = {} end
        if ent.train.carriages[ownPos-1] ~= nil then
          table.insert(global.tmpPos, ent.train.carriages[ownPos-1].position)
        end
        if ent.train.carriages[ownPos+1] ~= nil then
          table.insert(global.tmpPos, ent.train.carriages[ownPos+1].position)
        end
      end
    end
    if ctype == "train-stop" then
      decreaseStationCount(ent.force.name, ent.backer_name)
    end
    if ent.name == "smart-train-stop" then
      removeProxy(event.entity)
    end
  end)
  if not status then
    pauseError(err, "on_pre_player_mined_item")
  end
end

function on_player_mined_item(event)
  local status, err = pcall(function()
    local name = event.item_stack.name
    local results = {}
    if name == "diesel-locomotive" or name == "cargo-wagon" then
      if global.tmpPos then
        for _,pos in pairs(global.tmpPos) do
          local area = {{pos.x-1, pos.y-1},{pos.x+1, pos.y+1}}
          local loco = game.players[event.player_index].surface.find_entities_filtered{area=area, type="locomotive"}
          local wagon = game.players[event.player_index].surface.find_entities_filtered{area=area, type="cargo-wagon"}
          if #loco > 0 then
            table.insert(results, loco)
          elseif #wagon > 0 then
            table.insert(results, wagon)
          end
        end
        for _, result in pairs(results) do
          for _, t in pairs(result) do
            getTrainFromEntity(t)
          end
        end
        global.tmpPos = nil
      end
      removeInvalidTrains(true)
    end
  end)
  if not status then
    pauseError(err, "on_player_mined_item")
  end
end

function on_entity_died(event)
  local status, err = pcall(function()
    removeInvalidTrains(true)
    if event.entity.type == "locomotive" or event.entity.type == "cargo-wagon" then
      local old = getTrainKeyByTrain(global.trains, event.entity.train)
      if old then
        local t = global.trains[old]
        if t then
          t:resetCircuitSignal()
        end
      end
      removeInvalidTrains(true)
      return
    end
    if event.entity.type == "train-stop" then
      decreaseStationCount(event.entity.force.name, event.entity.backer_name)
    end
    if event.entity.name == "smart-train-stop" then
      removeProxy(event.entity)
    end
  end)
  if not status then
    pauseError(err, "on_entity_died")
  end
end

function on_robot_built_entity(event)
  if event.created_entity.type == "train-stop" then
    increaseStationCount(event.created_entity.force.name, event.created_entity.backer_name)
  end
  if event.created_entity.name == "smart-train-stop" then
    createProxy(event.created_entity)
  end
end

function on_robot_pre_mined(event)
  if event.entity.type == "train-stop" then
    decreaseStationCount(event.entity.force.name, event.entity.backer_name)
  end
  if event.entity.name == "smart-train-stop" then
    removeProxy(event.entity)
  end
end

function on_player_driving_changed_state(event)
  local player = game.players[event.player_index]
  if not player.connected then
    return
  end
  if player.vehicle ~= nil and player.character.name ~= "fatcontroller" and (player.vehicle.type == "locomotive" or player.vehicle.type == "cargo-wagon") then
    global.player_passenger[player.index] = player.vehicle
    local i = getTrainKeyByTrain(global.trains, player.vehicle.train)
    local ti = i and global.trains[i] or false
    if ti then
      ti.passengers = ti.passengers + 1
    end
  end
  if player.vehicle == nil and player.character.name ~= "fatcontroller" and global.player_passenger[player.index] then
    local i = getTrainKeyByTrain(global.trains, global.player_passenger[player.index].train)
    local ti = i and global.trains[i] or false
    if ti then
      ti.passengers = ti.passengers - 1
    end
    global.player_passenger[player.index] = nil
  end
end

function debugDump(var, force)
  if false or force then
    for _, player in pairs(game.players) do
      local msg
      if type(var) == "string" then
        msg = var
      else
        msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
      end
      player.print(msg)
    end
  end
end

function flyingText(line, color, pos, show)
  if show or debug then
    color = color or colors.RED
    if not pos then
      for _, p in pairs(game.players) do
        p.surface.create_entity({name="flying-text", position=p.position, text=line, color=color})
      end
      return
    end
  end
end

function printToFile(line, path)
  path = path or "log"
  path = table.concat({ "st", "/", path, ".lua" })
  game.write_file( path,  line)
end

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function sortByName(a,b)
  local function padnum(d) return ("%012d"):format(d) end
  --table.sort(o, function(a,b)
  return tostring(a):gsub("%d+",padnum):lower() < tostring(b):gsub("%d+",padnum):lower()
    --return a < b
end

function saveGlob(name)
  local n = name or ""
  game.write_file("st/debugGlob"..n..".lua", serpent.block(global, {name="glob"}))
  --game.write_file("st/loco"..n..".lua", serpent.block(findAllEntitiesByType("locomotive")))
end

function pauseError(err, desc)
  debugDump("Error in SmartTrains:",true)
  debugDump(err,true)
  global.error = {msg = err, desc = desc}
  game.write_file("errorReportSmartTrains.txt", serpent.block(global, {name="global"}))
  global.error = nil
  for _, logger in pairs(LOGGERS) do
    logger.write()
  end
end

function stationKey(station)
  if type(station) == "boolean" then error("wrong type", 2) end
  return station.position.x..":"..station.position.y
end

function findStations()
  initGlob()
  global.smartTrainstops = {}
  global.stationCount = {}
  init_forces()
  LOGGERS.main.log("Searching smart trainstops...")
  log("Searching smart trainstops...")
  local results = Surface.find_all_entities({ type = 'train-stop', surface = 'nauvis' })

  for _, station in pairs(results) do
    if station.name == "smart-train-stop" then
      --debugDump("SmartStop: "..station.backer_name,true)
      createProxy(station)
    end
    local force = station.force.name
    if not global.stationCount[force][station.backer_name] then
      global.stationCount[force][station.backer_name] = 0
    end
    global.stationCount[force][station.backer_name] = global.stationCount[force][station.backer_name] + 1
  end
  LOGGERS.main.log("Found " .. #results .. " smart trainstops (all forces)")
  log("Found " .. #results .. " smart trainstops (all forces)")
end

script.on_init(oninit)
script.on_load(onload)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_force_created, on_force_created)
--script.on_event(defines.events.on_forces_merging, on_forces_merging)

script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
script.on_event(defines.events.on_player_mined_item, on_player_mined_item)
script.on_event(defines.events.on_preplayer_mined_item, on_preplayer_mined_item)
script.on_event(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)

script.on_event(defines.events.on_entity_died, on_entity_died)
script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_gui_click, on_gui_click.on_gui_click)
script.on_event(defines.events.on_robot_pre_mined, on_robot_pre_mined)
script.on_event(defines.events.on_robot_built_entity, on_robot_built_entity)
script.on_event(defines.events.on_tick, on_tick)

if remote.interfaces.logistics_railway then
  script.on_event(remote.call("logistics_railway", "get_chest_created_event"), function(event)
    local chest = event.chest
    local wagon_index = event.wagon_index
    local train = event.train
    --debugDump("Chest: "..util.positiontostr(chest.position),true)
    local trainKey = getTrainKeyByTrain(global.trains, train)
    if trainKey then
      local t = global.trains[trainKey]
      if not t.proxy_chests then t.proxy_chests = {} end
      t.proxy_chests[wagon_index] = chest
    end
  end)

  script.on_event(remote.call("logistics_railway", "get_chest_destroyed_event"), function(event)
    local wagon_index = event.wagon_index
    local train = event.train
    --debugDump("destroyed a chest",true)
    local trainKey = getTrainKeyByTrain(global.trains, train)
    if trainKey then
      local t = global.trains[trainKey]
      if not t.proxy_chests then return end
      t.proxy_chests[wagon_index] = nil
      if #t.proxy_chests == 0 then t.proxy_chests = nil end
    end
  end)
end

remote.add_interface("st",
  {
    printGlob = function(name)
      if name then
        debugDump(global[name], true)
      else
        debugDump(global, true)
      end
    end,

    printFile = function(var, name)
      name = name or "log"
      if global[var] then
        printToFile(serpent.block(global[var]), name )
      else
        debugDump("global["..var.."] not found.")
      end
    end,
    --/c remote.call("st", "saveGlob")
    saveGlob = function(name)
      saveGlob(name)
    end,

    hardReset = function(confirm)
      if confirm then
        global = nil
        initGlob()
        init_players()
        findStations()
      end
    end,

    findStations = function()
      findStations()
    end,

    toggleFlyingText = function()
      global.showFlyingText = not global.showFlyingText
      debugDump("Flying text: "..tostring(global.showFlyingText),true)
    end,

    nilGlob = function(key)
      if global[key] then global[key] = nil end
    end,

    resetGui = function(player)
      if player and player.valid then
        GUI.destroy(player)
      end
    end,

    deduceSignal = function(entity)
      debugDump(deduceSignalValue(entity,entity.get_circuit_condition(1).condition.first_signal,1),true)
    end,

    deactivate = function()
      script.on_event(defines.events.on_train_changed_state, nil)
      script.on_event(defines.events.on_tick, nil)
      script.on_event(defines.events.on_gui_click, nil)
      if remote.interfaces.EventsPlus then
        script.on_event(remote.call("EventsPlus", "getEvent", "on_player_opened"), nil)
        script.on_event(remote.call("EventsPlus", "getEvent", "on_player_closed"), nil)
      else
        script.on_event(events.on_player_opened, nil)
        script.on_event(events.on_player_closed, nil)
      end

      for _, t in pairs(global.trains) do
        if t:isWaiting() then
          t.waiting = false
          t:nextStation(t.waitForever)
          t.waitForever = false
        end
        if t:isRefueling() then
          t:refuelingDone(true)
        end
      end
    end,

    activate = function()
      script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
      script.on_event(defines.events.on_gui_click, on_gui_click.on_gui_click)
      script.on_event(defines.events.on_tick, on_tick)
      if remote.interfaces.EventsPlus then
        script.on_event(remote.call("EventsPlus", "getEvent", "on_player_opened"), on_player_opened)
        script.on_event(remote.call("EventsPlus", "getEvent", "on_player_closed"), on_player_closed)
      else
        script.on_event(events.on_player_opened, on_player_opened)
        script.on_event(events.on_player_closed, on_player_closed)
      end
    end,

    init = function()
      initGlob()
      init_players()
    end,

    set_train_mode = function(lua_train)
      local status, err = pcall(function()
        local trainKey = getTrainKeyByTrain(global.trains, lua_train)
        local train = global.trains[trainKey]

        --debugDump(train,true)
        if train.waitForever or train.waiting then
          if train.waiting and global.check_rules[train.waiting.nextCheck] then
            local id = false
            for i, train2 in pairs(global.check_rules[train.waiting.nextCheck]) do
              if train2.train == train.train then
                id = i
              end
            end
            if id then global.check_rules[train.waiting.nextCheck][id] = nil end
          end
          train:resetCircuitSignal()
          train.waitingStation = false
          train.waiting = false
          train.waitForever = false
        end
      end)
      if not status then
        pauseError(err, "set_train_mode")
      end
    end,

    is_waiting_forever = function(lua_train)
      local status, err = pcall(function()
        if lua_train.valid then
          local trainKey = getTrainKeyByTrain(global.trains, lua_train)
          local train = global.trains[trainKey]
          --debugDump(train,true)
          if train and train.line and train.train.valid then
            if train.waitForever then
              return train.train.schedule.records[train.train.schedule.current].station
            else
              return false
            end
          else
            return false
          end
        end
        return false
      end)
      if not status then
        pauseError(err, "set_train_mode")
        return false
      else
        return err
      end
    end,

    smart_stops = function(player)
      for _,s in pairs(global.smartTrainstops[player.force.name]) do
        player.print(s.station.backer_name)
      end
    end,

    debuglog = function()
      global.debug_log = not global.debug_log
      local state = global.debug_log and "on" or "off"
      debugDump("Debug: "..state,true)
    end,

    countTrains = function()
      local t = #global.trains
      local ticksC = 0
      local ticksU = 0
      for tick, trains in pairs(global.check_rules) do
        ticksC = ticksC + #trains
        log("tick " .. tick ..": " .. #trains)
      end
      for _, trains in pairs(global.update_cargo) do
        ticksU = ticksU + #trains
      end
      debugDump({t=t,c=ticksC,u=ticksU},true)
    end
  }
)
