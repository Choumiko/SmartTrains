require "util"
require 'stdlib.area.position'
require 'stdlib.surface'
require 'stdlib.string'
require 'stdlib.table'

Logger = require('stdlib.log.logger')

debug = false

LOGGERS = {}

--LOGGERS.main = Logger.new("SmartTrains","main", true)
--LOGGERS.update = Logger.new("SmartTrains", "updates", true)

-- myevent = game.generateeventname()
-- the name and tick are filled for the event automatically
-- this event is raised with extra parameter foo with value "bar"
--game.raiseevent(myevent, {foo="bar"})

events = {}
events["on_player_opened"] = script.generate_event_name()
events["on_player_closed"] = script.generate_event_name()


require("gui")
require("Train")

defaultTrainSettings = {autoRefuel = false}
defaultSettings =
  { refuel = { station = "Refuel", rangeMin = 25*8, rangeMax = 50*8, time = 600 },
    intervals = {
      write = 60, -- ticks between constant combinator updates
      inactivity = 120, --ticks between cargo comparison
    },
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


train_state = {left_station = 11}

function insertInTable(tableA, key, value)
  if not tableA[key] then tableA[key] = {} end
  table.insert(tableA[key], value)
end

TrainList = {}

TrainList.getMainLocomotive = function(train)
  if train.valid and train.locomotives and (#train.locomotives.front_movers > 0 or #train.locomotives.back_movers > 0) then
    return train.locomotives.front_movers and train.locomotives.front_movers[1] or train.locomotives.back_movers[1]
  end
end

TrainList.getTrainID = function(train)
  local loco = TrainList.getMainLocomotive(train)
  return loco and loco.unit_number
end

TrainList.getLocomotives = function(train)
  local locomotives = {}
  if train.locomotives then
    for _, loco in pairs(train.locomotives.front_movers) do
      table.insert(locomotives, loco)
    end
    for _, loco in pairs(train.locomotives.back_movers) do
      table.insert(locomotives, loco)
    end
  end
  return locomotives
end

TrainList.addTrainInfo = function(train)
  local id = TrainList.getTrainID(train)
  if id then
    assert(not global.trains[id])
    local trainInfo = Train.new(train, id)
    global.trains[id] = trainInfo
    return trainInfo
  end
end

TrainList.updateTrainInfo = function(train)
  local newMainID = TrainList.getTrainID(train)
  if not newMainID then
    log("No locomotive in train")
    return
  end
  local newLocos = TrainList.getLocomotives(train)
  local found = false
  for _, loco in pairs(newLocos) do
    if global.trains[loco.unit_number] then
      if newMainID == loco.unit_number then
        log("found main loco " .. newMainID)
        local ti = global.trains[loco.unit_number]
        assert(not ti.train.valid)
        ti:update(train, newMainID)
        global.trains[newMainID] = ti
        found =  ti
      else
        log("not main loco " .. loco.unit_number)
        global.trains[loco.unit_number] = nil
      end
    end
  end
  return found or TrainList.addTrainInfo(train)
end

TrainList.getTrainInfo = function(train)
  local id = TrainList.getTrainID(train)
  local trainInfo = global.trains[id]
  if not trainInfo then
    if train.valid and id then
      return TrainList.addTrainInfo(train)
    end
  end
  return trainInfo
end

TrainList.getTrainInfoFromUI = function(playerIndex)
  local player = game.players[playerIndex]
  local trainInfo
  if player.opened ~= nil and player.opened.valid then
    if player.opened.type == "locomotive" then
      trainInfo = TrainList.getTrainInfo(player.opened.train)
    end
    return trainInfo
  end
end

TrainList.removeTrain = function(trainInfo)
  global.trains[trainInfo.ID] = nil
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
  global.reset_signals = global.reset_signals or {}

  global.player_opened = global.player_opened or {}
  global.player_passenger = global.player_passenger or {}
  global.showFlyingText = global.showFlyingText or false
  global.playerPage = global.playerPage or {}
  global.playerRules = global.playerRules or {}

  global.guiData = global.guiData or {}
  global.openedName = global.openedName or {}

  -- by force
  global.stationCount = global.stationCount or {}
  global.smartTrainstops = global.smartTrainstops or {}
  global.stationMapping = global.stationMapping or {}
  global.stationMap = global.stationMap or {}
  global.stationNumbers = global.stationNumbers or {}

  global.settings = global.settings or defaultSettings

  global.settings.stationsPerPage = stationsPerPage
  global.settings.linesPerPage = linesPerPage
  global.settings.rulesPerPage = rulesPerPage
  global.settings.mappingsPerPage = mappingsPerPage

  global.settings.intervals = global.settings.intervals or {}
  global.settings.intervals.write = global.settings.intervals.write or defaultSettings.intervals.write
  global.settings.intervals.inactivity = global.settings.intervals.inactivity or defaultSettings.intervals.inactivity

  global.fuel_values = global.fuel_values or {}
  global.fuel_values["coal"] = game.item_prototypes["coal"].fuel_value/1000000

  global.blueprinted_proxies = global.blueprinted_proxies or {}

  setMetatables()
end

local function init_player(player)
  global.playerRules[player.index] = global.playerRules[player.index] or {page=1}
  global.player_passenger[player.index] = player.vehicle
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
  global.stationNumbers[force.name] = global.stationNumbers[force.name] or {}
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
  setMetatables()
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



function get_station_number(force_name, station_name)
  if global.stationMapping[force_name][station_name] then
    return global.stationMapping[force_name][station_name]
  end

  local count_lines = 0
  local station_number = 0
  for line, line_data in pairs(global.trainLines) do
    for index, record in pairs(line_data.records) do
      if record.station == station_name then
        count_lines = count_lines + 1
        station_number = index
      end
    end
  end
  if count_lines > 1 then
    station_number = 0
  end
  return station_number
end

function add_or_update_parameter(behavior, signal, index)
  if behavior then
    local parameters = behavior.parameters.parameters
    if not parameters[index] or (not parameters[index].signal.name or parameters[index].signal.name == signal.signal.name)then
      if signal.count == 0 then
        signal = {signal={type = "item"}, count = 1, index = index}
      end
      parameters[index] = signal
      behavior.parameters = {parameters = parameters}
      return
    else
      for i, param in pairs(parameters) do
        if not param.signal or not param.signal.name then
          if signal.count == 0 then
            signal = {signal={type = "item"}, count = 1, index = i}
          end
          parameters[i] = signal
          parameters[i].index = i
          behavior.parameters = {parameters = parameters}
          return
        end
      end
    end
  end
end

function update_station_numbers()
  for force, smartTrainstops in pairs(global.smartTrainstops) do
    global.stationNumbers[force] = {}
    for key, station in pairs(smartTrainstops) do
      if station.station and station.station.valid then
        local number = get_station_number(force,station.station.backer_name)
        global.stationNumbers[force][station.station.backer_name] = number
        local signal = {signal={type = "virtual", name = "signal-station-number"}, count = number, index = 1}
        add_or_update_parameter(station.cargo.get_or_create_control_behavior(), signal, 1)
      end
    end
  end
end

local function getProxyPositions(trainstop)
  local offset = {
    [0] = {x=-0.5,y=-0.5},
    [2]={x=0.5,y=-0.5},
    [4]={x=0.5,y=0.5},
    [6]={x=-0.5,y=0.5}}
  local offsetcargo = {
    [0] = {x=0.5,y=-0.5},
    [2]={x=0.5,y=0.5},
    [4]={x=-0.5,y=0.5},
    [6]={x=-0.5,y=-0.5}}
  local pos = Position.add(trainstop.position, offset[trainstop.direction])
  local poscargo = Position.add(trainstop.position, offsetcargo[trainstop.direction])
  return {signalProxy = poscargo, cargo = pos}
end

local function recreateProxy(station)
  local trainstop = global.smartTrainstops[station.force.name][stationKey(station)]
  local positions = getProxyPositions(trainstop.station)
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
        log("Updated smart train stop cargo:"..trainstop.station.backer_name)
      end
    else
      if trainstop.cargo and trainstop.cargo.valid then
        if not Position.equals(positions.cargo, trainstop.cargo.position) then
          if not trainstop.cargo.teleport(positions.cargo) then
            log("fail: moved cargo proxy " .. trainstop.station.backer_name)
          end
        end
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
        log("Updated smart train stop signal:"..trainstop.station.backer_name)
      end
    else
      if trainstop.signalProxy and trainstop.signalProxy.valid then
        if not Position.equals(positions.signalProxy, trainstop.signalProxy.position) then
          if not trainstop.signalProxy.teleport(positions.signalProxy) then
            log("fail: moved signal proxy " .. trainstop.station.backer_name)
          end
        end
      end
    end
  end
end

local function fixSmartstopTable()
  local tmp = {
    player  = global.smartTrainstops.player or {},
    enemy   = global.smartTrainstops.enemy or {},
    neutral = global.smartTrainstops.neutral or {}
  }
  local forces = {player = true, enemy=true, neutral=true, gate=true}
  for key, smartStop in pairs(global.smartTrainstops) do
    if not forces[key] then
      if smartStop.entity then
        smartStop.station = smartStop.entity
        smartStop.entity = nil
      end
      if smartStop.proxy then
        smartStop.signalProxy = smartStop.proxy
        smartStop.proxy = nil
      end
      tmp[smartStop.station.force.name] =tmp[smartStop.station.force.name] or {}
      tmp[smartStop.station.force.name][key] = smartStop
    end
  end
  global.smartTrainstops = tmp
  for force, stops in pairs(global.smartTrainstops) do
    for key, smartStop in pairs(stops) do
      recreateProxy(smartStop.station)
    end
  end
end

local update_from_version = {
  ["0.0.0"] = function()
    return update_0_3_77()
  end,
  ["0.3.77"] = function() return "0.3.82" end,
  ["0.3.78"] = function() return "0.3.82" end,
  ["0.3.79"] = function() return "0.3.82" end,
  ["0.3.80"] = function() return "0.3.82" end,
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
      end
    end
    fixSmartstopTable()
    removeInvalidTrains()
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
    global.settings.intervals.noChange = defaultSettings.intervals.inactivity
    global.settings.intervals.cargoRule = global.settings.intervals.read --defaultSettings.intervals.cargoRule

    global.settings.circuit = nil
    global.settings.depart = nil

    global.update_cargo = global.updateTick or {}
    global.check_rules = global.ticks or {}

    for _, t in pairs(global.trains) do
      t.type = t:getType()
      t.update_cargo = t.updateTick
      t.updateTick = nil
      t.last_fuel_update = 0
      t.min_fuel = nil
      t:lowestFuel()
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
          if c.passenger then
            t.passengers = t.passengers + 1
          end
        end
      end
    end
    global.updateTick = nil
    global.ticks = nil
    return "0.3.91"
  end,
  ["0.3.91"] = function()
    for _, t in pairs(global.trains) do
      t.passengers = 0
      for _, c in pairs(t.train.carriages) do
        if c.passenger then
          t.passengers = t.passengers + 1
        end
      end
    end
    return "0.3.92" end,
  ["0.3.92"] = function()
    global.openedTrain = nil
    return "0.3.93"
  end,
  ["0.3.93"] = function() return "0.3.94" end,
  ["0.3.94"] = function() return "0.3.95" end,
  ["0.3.95"] = function()
    fixSmartstopTable()
    local smart_conditions = {}
    for _ , stop in pairs(global.smartTrainstops.player) do
      if stop.station.valid and stop.signalProxy.valid then
        local behavior = stop.signalProxy.get_control_behavior()
        if behavior then
          smart_conditions[stop.station.backer_name] = behavior.circuit_condition.condition
        end
      end
    end


    for name, trainline in pairs(global.trainLines) do
      local tmp = {}
      local records = trainline.records
      trainline.rules.inactivity = trainline.rules.noChange
      trainline.rules.noChange = nil
      local rules = trainline.rules

      for i, record in pairs(records) do
        local wait_conditions = {}
        local compare_type = rules[i].requireBoth and "and" or "or"
        tmp[i] = {
          station=record.station,
          jumpToCircuit = rules[i].jumpToCircuit,
          jumpTo = rules[i].jumpTo
        }
        --normal waiting time
        if not rules[i].keepWaiting then
          table.insert(wait_conditions, {type="time", ticks=record.time_to_wait, compare_type = compare_type} )
          tmp[i].keepWaiting = true
        end
        record.time_to_wait = nil
        --empty rule
        if rules[i].empty then
          table.insert(wait_conditions, {type="empty", compare_type = compare_type} )
          tmp[i].empty = true
        end
        --full rule
        if rules[i].full then
          table.insert(wait_conditions, {type="full", compare_type = compare_type} )
          tmp[i].full = true
        end
        --no change/inactivity rule
        if rules[i].inactivity then
          table.insert(wait_conditions, {type="inactivity", ticks=global.settings.intervals.inactivity, compare_type = compare_type} )
          tmp[i].inactivity = true
        end
        if rules[i].waitForCircuit then
          local wait_condition = {type = "circuit", compare_type = compare_type}
          wait_condition.condition = smart_conditions[tmp[i].station]

          table.insert(wait_conditions, wait_condition )
          tmp[i].circuit = true
        end

        record.wait_conditions = wait_conditions
        if #wait_conditions > 0 then
          record.wait_conditions[1].compare_type = "and"
        end
      end
      trainline.records = records
      trainline.rules = table.deepcopy(tmp)
      tmp = {}
    end

    local remove_invalid = false
    for _, train in pairs(global.trains) do
      if train.train and train.train.valid then
        train.current = train.train.schedule.current
        local schedule
        if train.line and global.trainLines[train.line] then
          local line = global.trainLines[train.line]
          train.rules = table.deepcopy(line.rules)
          train.lineVersion = line.changed
          schedule = train.train.schedule
          schedule.records = global.trainLines[train.line].records
          train.train.schedule = schedule
        end
      else
        remove_invalid = true
      end
    end
    if remove_invalid then
      removeInvalidTrains()
    end
    return "0.3.96"
  end,
  ["0.3.96"] = function()
    global.reset_signals = global.reset_signals or {}
    return "0.3.97"
  end,
  ["0.3.97"] = function() return "0.3.98" end,
  ["0.3.98"] = function() return "0.3.99" end,
  ["0.3.99"] = function()
    update_station_numbers()
    return "0.4.0"
  end,
  ["0.4.0"] = function()
    update_station_numbers()
    return "0.4.1"
  end,
  ["0.4.1"] = function() return "0.4.2" end,
  ["0.4.2"] = function()
    global.settings.intervals.read = nil
    global.settings.intervals.cargoRule = nil
    global.settings.intervals.noChange = nil
    global.settings.minFlow = nil
    return "0.4.3"
  end,
  ["0.4.3"] = function() return "0.4.4" end,
  ["0.4.4"] = function()
    local trains = {}
    local trainCount = #global.trains
    local id = false
    for _, trainInfo in pairs(global.trains) do
      id = TrainList.getTrainID(trainInfo.train)
      assert(id and not trains[id])
      if id then
        trainInfo.ID = id
        trains[id] = trainInfo
      end
    end
    global.train = trains
    return "0.4.5"
  end,
}

function on_configuration_changed(data)
  local status, err = pcall(function()
    if not data.mod_changes then
      return
    end
    if data.mod_changes.SmartTrains then
      local old_version = data.mod_changes.SmartTrains.old_version
      local new_version = data.mod_changes.SmartTrains.new_version
      if old_version then
        saveGlob("PreUpdate"..old_version.."_"..game.tick)
      end
      initGlob()
      init_forces()
      init_players()
      setMetatables()
      if old_version and new_version then
        local ver = update_from_version[old_version] and old_version or "0.0.0"
        while ver ~= new_version do
          ver = update_from_version[ver]()
        end
        debugDump("SmartTrains version changed from "..old_version.." to "..ver,true)
      end

      findStations()
      global.version = new_version
    end
    --update fuelvalue cache, in case the values changed
    for item, _ in pairs(global.fuel_values) do
      global.fuel_values[item] = game.item_prototypes[item].fuel_value/1000000
    end
  end)
  if not status then
    --LOGGERS.main.write()
    error(err, 2)
  end
end

function createProxy(trainstop)
  local positions = getProxyPositions(trainstop)
  local force = trainstop.force.name
  local key = stationKey(trainstop)
  local smartStop = global.smartTrainstops[force][key]
  local keySignal = stationKey({position=positions.signalProxy})
  local keyCargo = stationKey({position=positions.cargo})
  local signalProxy, cargoProxy
  local proxy = {name="smart-train-stop-proxy", direction = 0, force=trainstop.force, position=positions.signalProxy}
  local proxycargo = {name="smart-train-stop-proxy-cargo", direction = trainstop.direction, force=trainstop.force, position=positions.cargo}
  if global.blueprinted_proxies[keySignal] then
    local signal = global.blueprinted_proxies[keySignal]
    if signal and signal.valid then
      --debugDump("signal: "..serpent.line(signal.position),true)
      signal.revive()
    end
    global.blueprinted_proxies[keySignal] = nil
  end
  if global.blueprinted_proxies[keyCargo] then
    local cargo = global.blueprinted_proxies[keyCargo]
    if cargo and cargo.valid then
      --debugDump("cargo: "..serpent.line(cargo.position),true)
      cargo.revive()
    end
    global.blueprinted_proxies[keyCargo] = nil
  end

  if smartStop and smartStop.station and smartStop.station.valid then
    if smartStop.signalProxy and smartStop.signalProxy.valid then
      if not Position.equals(positions.signalProxy, smartStop.signalProxy.position) then
        smartStop.signalProxy.teleport(positions.signalProxy)
        signalProxy = smartStop.signalProxy
        log("moved signal proxy " .. trainstop.backer_name)
      end
    end
    if smartStop.cargo and smartStop.cargo.valid then
      if not Position.equals(positions.cargo, smartStop.cargo.position) then
        smartStop.cargo.teleport(positions.cargo)
        cargoProxy = smartStop.cargo
        log("moved cargo proxy " .. trainstop.backer_name)
      end
    end
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
    cargoProxy.minable = false
    cargoProxy.get_or_create_control_behavior().parameters = nil

    signalProxy.destructible = false
    signalProxy.minable = false
    if not global.smartTrainstops[force][key] then
      global.smartTrainstops[force][key] = {station = trainstop, signalProxy = signalProxy, cargo = cargoProxy}
    else
      assert(signalProxy == global.smartTrainstops[force][key].signalProxy)
      assert(cargoProxy == global.smartTrainstops[force][key].cargo)
      --log("Do something here?!")
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

function round(num, idp)
  local mult = 10 ^ (idp or 0)
  return math.floor(num*mult +0.5)/mult
end

function findTrainStopByTrain(vehicle, rail)
  local surface = vehicle.surface
  local trainDir = round(vehicle.orientation*8,0) % 8
  -- [trainDir][rail.direction][rail.type]
  --debugDump("o: " .. trainDir .. "r: " .. rail.position.x .."|"..rail.position.y,true)
  local offsets = {
    [0] = {
      [0] = {
        ['straight-rail'] = { x = 2, y = -2 }},
      [4] = {
        ['curved-rail'] = { x = 1, y = -5 }},
      [5] = {
        ['curved-rail'] = { x = 3, y = -5 }},
    },
    [2] = {
      [2] = {
        ['straight-rail'] = { x = 2, y = 2 }},
      [6] = {
        ['curved-rail'] = { x = 5, y = 1 }
      },
      [7] = {
        ['curved-rail'] = { x = 5, y = 3 }
      },
    },
    [4] = {
      [0] = {
        ['straight-rail'] = { x = -2, y = 2 },
        ['curved-rail'] = { x = -1, y = 5}
      },
      [1] = {
        ['curved-rail']   = { x = -3, y = 5}},
    },
    [6] = {
      [2] = {
        ['straight-rail'] = { x = -2, y = -2 },
        ['curved-rail']   = { x = -5, y = -1 }},
      [3] = {
        ['curved-rail'] = { x = -5, y = -3 }
      },
    },
  }
  local pos = Position.add(rail.position, offsets[trainDir][rail.direction][rail.type])
  local stops = surface.find_entities_filtered{type="train-stop", area = Position.expand_to_area(pos, 0.25)}
  log("stops " .. #stops)
  flyingText("T", colors.RED, pos, true, rail.surface)
  log(serpent.line({rail={pos=rail.position, dir=rail.direction, name=rail.type}, trainDir=trainDir},{comment=false}))
  if #stops == 0 then
    log("forgot one: ")
    log(serpent.line({rail={pos=rail.position, dir=rail.direction, name=rail.type}, trainDir=trainDir},{comment=false}))
    pos = Position.translate(pos, trainDir, -2)
    stops = surface.find_entities_filtered{type="train-stop", area = Position.expand_to_area(pos, 0.25)}
  end
  return stops[1]
end

function findSmartTrainStopByTrain(vehicle, rail, stationName)
  local station = findTrainStopByTrain(vehicle, rail)
  --TODO trainstop at curve!!
  if station and station.name == "smart-train-stop" and station.backer_name == stationName then
    flyingText("S", colors.GREEN, station.position, true, station.surface)
    return global.smartTrainstops[vehicle.force.name][stationKey(station)]
  end
  return false
end

function removeInvalidTrains(show)
  local removed = 0
  show = show or debug
  for id, ti in pairs(global.trains) do
    if not ti.train or not ti.train.valid or (#ti.train.locomotives.front_movers == 0 and #ti.train.locomotives.back_movers == 0) then
      ti:resetCircuitSignal()

      global.trains[id] = nil
      removed = removed + 1
      -- try to detect change through pressing G/V
    else
      local test = ti:getType()
      if test ~= ti.type then
        ti:resetCircuitSignal()
        global.trains[id] = nil
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

function inSchedule_reverse(station, schedule)
  if type(schedule) == "table" and type(schedule.records) == "table" then
    for i=#schedule.records, 1, -1 do
      if schedule.records[i].station == station then
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
  local tmp = {wait_conditions = {{type="time", ticks = wait, compare_type = "and"}}, station = station}
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

function getKeyByValue(t, value)
  for k, v in pairs(t) do
    if v == value then
      return k
    end
  end
end

function on_train_changed_state(event)
  --log(game.tick.." "..getKeyByValue(defines.train_state, event.train.state))
  --debugLog("train changed state to "..event.train.state.. " s")
  local status, err = pcall(function()
    local train = event.train
    local trainKey
    local t = TrainList.getTrainInfo(train)
    log(serpent.line(t))
    --assert(t.train.valid)
    -- TODO is this for de/coupling an automated train???
    if not t.train.valid then
      t = TrainList.updateTrainInfo(train)
    end

    --log(t.name .. " ".. util.getKeyByValue(defines.train_state, event.train.state))
    t:updateState()

    if t.advancedState == train_state.left_station then
      if t.current then
        log(t.name .. ": Leaving station #" .. t.current .. " " .. t.train.schedule.records[t.current].station .. "  @tick: "..event.tick)
        log(t.name .. ": t.train current #" .. t.train.schedule.current)
      end
      local jump, use_mapping
      local needs_update = (t.line and global.trainLines[t.line]) and t.lineVersion < global.trainLines[t.line].changed or false
      log("Checking line, needs update: " ..serpent.line( needs_update,{comment=false}))
      local oldSchedule = t.train.schedule
      local oldName = t:getStationName(t.current)
      local numRecordsOld = #t.train.schedule.records
      local newSchedule, numRecordsNew, newName
      if needs_update then
        if t:updateLine() then
          newSchedule = t.train.schedule
          newName = t:getStationName(t.current)
          numRecordsNew = #t.train.schedule.records
          log("old count: " .. numRecordsOld .. " new count: " .. numRecordsNew)
          if t.current == numRecordsOld and numRecordsOld < numRecordsNew then
            jump = t.current + 1
            log("setting current to " .. jump)
          end
          if t.current > numRecordsNew then
            jump = 1
            log("setting current to " .. jump)
          end
          --TODO check if jumpTo is still used for the departing station and jump target is valid with the new schedule
        end
      end

      local rules = t:get_rules(t.current)

      if event.tick < t.departAt and rules and (rules.jumpTo or rules.jumpToCircuit) then
        local signalValue = rules.jumpToCircuit
        local gotoStation = rules.jumpTo

        if signalValue then
          signalValue = t:getCircuitValue(t.current)
          --log("signalValue: " .. signalValue)
        end
        use_mapping = global.trainLines[t.line] and global.trainLines[t.line].settings.useMapping or false
        log("Signal: "..serpent.line(signalValue,{comment=false}) .. " use mapping: " .. serpent.line(use_mapping,{comment=false}))
        if use_mapping then
          local jumpSignal, jumpTo
          if signalValue then
            jumpSignal = t:get_first_matching_station(signalValue, t.current)
            log("jumpSignal: " .. serpent.line(jumpSignal, {comment=false}) .. " -> " .. t:getStationName(jumpSignal) or " invalid index")
          end
          if gotoStation then
            jumpTo = t:get_first_matching_station(gotoStation, t.current)
            log("jumpTo: " .. serpent.line(jumpTo, {comment=false}) .. " -> " .. t:getStationName(jumpTo) or " invalid index")
          end
          jump = jumpSignal or jumpTo or false

        else
          jump = (t:isValidScheduleIndex(signalValue)) or gotoStation or false
          log("Jumping to " .. tostring(jump))
        end
      end

      if jump then
        t:nextStation(false, jump)
      end



      t.current = nil
      t:resetWaitingStation(true)
      log(" ")
      return
    end
    if train.state == defines.train_state.wait_signal or train.state == defines.train_state.arrive_signal then
      return
    end

    local settings = t.settings
    local lowest_fuel = t:lowestFuel()

    local schedule = train.schedule
    if train.state == defines.train_state.manual_control_stop or train.state == defines.train_state.manual_control then
      for _, train_ in pairs(global.trains) do
        if train_ == t then
          t:resetWaitingStation()
        end
      end
    elseif train.state == defines.train_state.wait_station then
      --LOGGERS.main.log("Train arrived at " .. t:currentStation() .. "\t\t  train: " .. t.name .. " Speed: " .. t.train.speed)
      --t:updateLine()
      t:setWaitingStation()
      t.current = t.train.schedule.current

      local rules = t:get_rules()
      --log("waiting: " .. serpent.line(rules,{comment=false}))

      t.departAt = event.tick + t:getWaitingTime()
      if settings.autoRefuel then
        if t:currentStation() == t:refuelStation() and #schedule.records == schedule.current then
          t:startRefueling()
        end
      end
    elseif train.state == defines.train_state.arrive_station then
      if t.settings.autoRefuel then
        if lowest_fuel < (global.settings.refuel.rangeMin) and not inSchedule(t:refuelStation(), train.schedule) then
          train.schedule = addStation(t:refuelStation(), train.schedule, global.settings.refuel.time)
          if global.showFlyingText then
            t:flyingText("Refuel station added", colors.YELLOW)
          end
        end
        if lowest_fuel >= (global.settings.refuel.rangeMax) and t:currentStation() ~= t:refuelStation() then
          t:removeRefuelStation()
        end
      end
      --log(t.name .. " updating")
      t:updateLine()
      if t.train.speed ~= 0 then --only update direction when train is moving: prevents direction being lost when train is stopped/started at a station
        t.direction = t.train.speed < 0 and 1 or 0
      end
    end
  end)
  if not status then
    pauseError(err, "train_changed_state")
  end
  --debugLog("train changed state to "..event.train.state.. " e")
  --log("state change e")
end

function on_tick(event)
  local current_tick = event.tick

  if global.reset_signals[current_tick] then
    for _, station in pairs(global.reset_signals[current_tick]) do
      local behavior = station.cargo.get_or_create_control_behavior()
      if behavior then
        local station_number = global.stationNumbers[station.station.force.name][station.station.backer_name] or false
        if station_number and station_number ~= 0 then
          local params = {{signal={type = "virtual", name = "signal-station-number"}, count = station_number, index = 1}}
          behavior.parameters = {parameters = params}
        else
          behavior.parameters = nil
        end
      end
    end
    global.reset_signals[current_tick] = nil
  end

  if global.refueling[current_tick] then
    local status,err = pcall(function()
      local remove_invalid = false
      for _, train in pairs(global.refueling[current_tick]) do
        if train.train and train.train.valid then
          if train.refueling and train.refueling == current_tick then
            if train:lowestFuel() >= global.settings.refuel.rangeMax then
              train:refuelingDone(true)
            else
              train.refueling = current_tick + global.settings.intervals.inactivity
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
      if remove_invalid then removeInvalidTrains() end
    end)
    if not status then
      pauseError(err, "on_tick: refueling")
    end
    global.refueling[current_tick] = nil
  end

  -- update cargo (setWaitingStation <- only if smart stop or full/empty/inactivity rule set
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
      if remove_invalid then removeInvalidTrains() end
    end)
    if not status then
      pauseError(err, "on_tick: update_cargo")
    end
    global.update_cargo[current_tick] = nil
  end

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

function on_player_opened(event)
  if event.entity.valid and game.players[event.player_index].valid then
    if event.entity.type == "locomotive" and event.entity.train then
      global.playerPage[event.player_index] = {schedule=1,lines=1}
      local trainInfo = TrainList.getTrainInfo(event.entity.train)
      GUI.create_or_update(event.player_index)
      trainInfo.opened = true
      global.guiData[event.player_index] = {rules={}}
    elseif event.entity.type == "train-stop" then
      global.playerPage[event.player_index] = {schedule=1,lines=1}
      local force = game.players[event.player_index].force.name
      global.guiData[event.player_index] = {rules={}, mapping=table.deepcopy(global.stationMapping[force])}
      GUI.create_or_update(event.player_index)
      global.openedName[event.player_index] = event.entity.backer_name
    end
  end
end

function schedule_changed(s1, s2)
  if s1.records and s2.records and #s1.records ~= #s2.records then return true end
  local records1 = s1.records
  local records2 = s2.records
  if not records1 or type(records1) ~= type(records2) then return true end

  for i, record in pairs(records1) do
    if not record.wait_conditions and record.wait_conditions ~= records2[i].wait_conditions then return true end
    if record.wait_conditions and not records2[i].wait_conditions then return true end
    if #record.wait_conditions ~= #records2[i].wait_conditions then return true end

    for j, condition in pairs(record.wait_conditions) do
      local condition2 = records2[i].wait_conditions[j]
      if condition.type ~= condition2.type or
        condition.compare_type ~= condition2.compare_type or
        condition.ticks ~= condition2.ticks or
        type(condition) ~= type(condition2) then
        log(serpent.block(condition,{comment=false})) log(" ~= ") log(serpent.block(condition2,{comment=false}))
        return true
      end
      if condition.condition then
        local c1 = condition.condition
        local c2 = condition2.condition
        if c1.comparator ~= c2.comparator or
          c1.constant ~= c2.constant then
          log(serpent.line(c1,{comment=false}) .. " ~= " .. serpent.line(c2,{comment=false}))
          return true
        end
        if type(c1.first_signal) ~= type(c2.first_signal) then return true end
        if c1.first_signal then
          if c1.first_signal.type ~= c2.first_signal.type or
            c1.first_signal.name ~= c2.first_signal.name then
            log(serpent.line(c1.first_signal,{comment=false}) .. " ~= " .. serpent.line(c2.first_signal,{comment=false}))
            return true
          end
        end
        if type(c1.second_signal) ~= type(c2.second_signal) then return true end
        if c1.second_signal then
          if c1.second_signal.type ~= c2.second_signal.type or
            c1.second_signal.name ~= c2.second_signal.name then
            log(serpent.line(c1.second_signal,{comment=false}) .. " ~= " .. serpent.line(c2.second_signal,{comment=false}))
            return true
          end
        end
      end
    end
    if record.station ~= records2[i].station or record.time_to_wait ~= records2[i].time_to_wait then
      return true
    end
  end
  return false
end

function on_player_closed(event)
  if event.entity.valid and game.players[event.player_index].valid then
    if event.entity.type == "locomotive" then
      if event.entity.type == "locomotive" then
        local trainInfo = TrainList.getTrainInfo(event.entity.train)
        GUI.destroy(event.player_index)
        trainInfo.opened = nil
        if trainInfo.line and global.trainLines[trainInfo.line] and schedule_changed(global.trainLines[trainInfo.line], event.entity.train.schedule) and trainInfo.lineVersion ~= 0 then
          --TODO remove log
          log("schedule changed")
          --set line version to -1, so it gets updated at the next station
          trainInfo.lineVersion = -1
          if trainInfo.train.state == defines.train_state.manual_control then
            trainInfo:updateLine()
          end
        end
      end
    elseif event.entity.type == "train-stop" then
      GUI.destroy(event.player_index)
      if event.entity.backer_name ~= global.openedName[event.player_index] then
        on_station_rename(event.entity.force.name, event.entity.backer_name, global.openedName[event.player_index])
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

function on_station_rename(force, newName, oldName)
  local oldc = decreaseStationCount(force, oldName)
  if oldc == 0 then
    renameStation(newName, oldName)
    global.stationMapping[force][oldName] = nil
    for i, stations in pairs(global.stationMap[force]) do
      stations[oldName] = nil
      if not next(global.stationMap[force][i]) then
        global.stationMap[force][i] = nil
      end
    end
    global.stationCount[force][oldName] = nil
  end
  increaseStationCount(force, newName)
  update_station_numbers()
end


-- on_pre_entity_settings_pasted and on_entity_settings_pasted
function on_pre_entity_settings_pasted(event)
  if event.source.type == "train-stop" then
    on_station_rename(event.destination.force.name, event.source.backer_name, event.destination.backer_name)
  end
end

function on_entity_settings_pasted(event)
  if event.source.type == "train-stop" then
    if event.destination.name == "smart-train-stop" and event.source.name == "smart-train-stop" then
      local k_source = stationKey(event.source)
      local k_dest = stationKey(event.destination)
      local proxy_source = global.smartTrainstops[event.source.force.name][k_source].signalProxy
      local proxy_dest = global.smartTrainstops[event.destination.force.name][k_dest].signalProxy
      if proxy_source and proxy_source.valid and proxy_dest and proxy_dest.valid then
        local behavior_source = proxy_source.get_control_behavior()
        if behavior_source then
          local behavior_dest = proxy_dest.get_or_create_control_behavior()
          local cond = behavior_source.circuit_condition
          behavior_dest.circuit_condition = cond
        end
      end
    end
  end
end

script.on_event(defines.events.on_pre_entity_settings_pasted, on_pre_entity_settings_pasted)
script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)

script.on_event(events.on_player_opened, on_player_opened)
script.on_event(events.on_player_closed, on_player_closed)

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
      local c = #ent.train.carriages
      if c == 1 then
        if ctype == "locomotive" then
          TrainList.addTrainInfo(ent.train)
        end
      else
        TrainList.updateTrainInfo(ent.train)
      end
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
      local oldTrainInfo = TrainList.getTrainInfo(ent.train)
      if oldTrainInfo then
        oldTrainInfo:resetCircuitSignal()
      end

      if #ent.train.carriages > 1 then
        if not global.tmpPos then global.tmpPos = {} end
        if ent.train.carriages[ownPos-1] then
          table.insert(global.tmpPos, ent.train.carriages[ownPos-1])
        end
        if ent.train.carriages[ownPos+1] then
          table.insert(global.tmpPos, ent.train.carriages[ownPos+1])
        end
      else
        TrainList.removeTrain(oldTrainInfo)
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
    local type = game.item_prototypes[name].place_result and game.item_prototypes[name].place_result.type
    local results = {}
    if type == "locomotive" or type == "cargo-wagon" then
      if global.tmpPos then
        for _, entity in pairs(global.tmpPos) do
          TrainList.updateTrainInfo(entity.train)
        end
        global.tmpPos = nil
      end
      removeInvalidTrains()
    end
  end)
  if not status then
    pauseError(err, "on_player_mined_item")
  end
end

function on_entity_died(event)
  local status, err = pcall(function()
    if event.entity.type == "locomotive" or event.entity.type == "cargo-wagon" then
      local oldTrainInfo = TrainList.getTrainInfo(event.entity.train)
      if oldTrainInfo then
        oldTrainInfo:resetCircuitSignal()
      end
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
    local trainInfo = TrainList.getTrainInfo(player.vehicle.train)
    if trainInfo then
      trainInfo.passengers = trainInfo.passengers + 1
    end
  end
  if player.vehicle == nil and player.character.name ~= "fatcontroller" and global.player_passenger[player.index] then
    local trainInfo = TrainList.getTrainInfo(global.player_passenger[player.index].train)
    if trainInfo then
      trainInfo.passengers = trainInfo.passengers - 1
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

function flyingText(line, color, pos, show, surface)
  if show or debug then
    color = color or colors.RED
    if not pos then
      for _, p in pairs(game.players) do
        p.surface.create_entity({name="flying-text", position=p.position, text=line, color=color})
      end
      return
    else
      if surface then
        surface.create_entity({name="flying-text", position=pos, text=line, color=color})
      end
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
  global.aaaa = game.tick
  game.write_file("st/debugGlob"..n..".lua", serpent.block(global, {name="glob"}))
  global.aaaa = nil
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
  if global.searchedStations == game.tick then
    return
  end
  initGlob()
  global.stationCount = {}
  init_forces()
  log("Searching smart trainstops...")
  local results = Surface.find_all_entities({ type = 'train-stop', surface = 'nauvis' })

  for _, station in pairs(results) do
    if station.name == "smart-train-stop" then
      recreateProxy(station)
    end
    local force = station.force.name
    if not global.stationCount[force][station.backer_name] then
      global.stationCount[force][station.backer_name] = 0
    end
    global.stationCount[force][station.backer_name] = global.stationCount[force][station.backer_name] + 1
  end
  global.searchedStations = game.tick

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

    local trainInfo = TrainList.getTrainInfo(train)
    if trainInfo then
      if not trainInfo.proxy_chests then trainInfo.proxy_chests = {} end
      trainInfo.proxy_chests[wagon_index] = chest
    end
  end)

  script.on_event(remote.call("logistics_railway", "get_chest_destroyed_event"), function(event)
    local wagon_index = event.wagon_index
    local train = event.train
    --debugDump("destroyed a chest",true)
    local trainInfo = TrainList.getTrainInfo(train)
    if trainInfo then
      if not trainInfo.proxy_chests then return end
      trainInfo.proxy_chests[wagon_index] = nil
      if #trainInfo.proxy_chests == 0 then trainInfo.proxy_chests = nil end
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
        init_forces()
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

    init = function()
      initGlob()
      init_players()
    end,

    set_train_mode = function(lua_train)
      local status, err = pcall(function()
        local trainInfo = TrainList.getTrainInfo(lua_train)

        --debugDump(train,true)
        if trainInfo.waiting then
          trainInfo:resetCircuitSignal()
          trainInfo.waitingStation = false
          trainInfo.waiting = false
        end
      end)
      if not status then
        pauseError(err, "set_train_mode")
      end
    end,

    is_waiting_forever = function(lua_train)
      local status, err = pcall(function()
        if lua_train.valid then
          local trainInfo = TrainList.getTrainInfo(lua_train)
          if trainInfo and trainInfo.line and trainInfo.train.valid then
            if trainInfo.waitForever then
              return trainInfo.train.schedule.records[trainInfo.train.schedule.current].station
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
