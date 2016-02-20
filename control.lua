require "defines"
require "util"

-- myevent = game.generateeventname()
-- the name and tick are filled for the event automatically
-- this event is raised with extra parameter foo with value "bar"
--game.raiseevent(myevent, {foo="bar"})
events = {}
events["on_player_opened"] = script.generate_event_name()
events["on_player_closed"] = script.generate_event_name()

debug = false

require("gui")
require("Train")

defaultTrainSettings = {autoRefuel = false, autoDepart = false}
defaultSettings =
  { refuel={station="Refuel", rangeMin = 25*8, rangeMax = 50*8, time = 600},
    depart={minWait = 240, interval = 120, minFlow = 1},
    circuit={interval = 2},
    lines={forever=false}
  }
stationsPerPage = 5
linesPerPage = 5
rulesPerPage = 5

local tmpPos = {}
RED = {r = 0.9}
GREEN = {g = 0.7}
YELLOW = {r = 0.8, g = 0.8}

defines.trainstate.left_station = 11

function util.formattime(ticks, showTicks)
  if ticks then
    local seconds = ticks / 60
    local minutes = math.floor((seconds)/60)
    local seconds = math.floor(seconds - 60*minutes)
    local tick = ticks - (minutes*60*60+seconds*60)
    local format = showTicks and "%d:%02d:%02d" or "%d:%02d"
    return string.format(format, minutes, seconds, tick)
  else
    return "-"
  end
end

function initGlob()
  global.version = global.version or "0.3.7"
  global.trains = global.trains or {}
  global.trainLines = global.trainLines or {}
  global.ticks = global.ticks or {}
  global.stopTick = global.stopTick or {}
  global.updateTick = global.updateTick or {}

  global.player_opened = global.player_opened or {}
  global.showFlyingText = global.showFlyingText or false
  global.playerPage = global.playerPage or {}
  global.playerRules = global.playerRules or {}
  global.smartTrainstops = global.smartTrainstops or {}

  global.guiData = global.guiData or {}
  global.openedName = global.openedName or {}
  global.openedTrain = global.openedTrain or {}
  global.stationCount = global.stationCount or {}

  global.settings = global.settings or defaultSettings
  global.settings.lines = global.settings.lines or {}

  global.settings.lines.forever = false

  global.settings.stationsPerPage = stationsPerPage
  global.settings.linesPerPage = linesPerPage
  global.settings.rulesPerPage = rulesPerPage

  if not global.settings.circuit then
    global.settings.circuit = table.deepcopy(defaultSettings.circuit)
  end

  setMetatables()
end

function setMetatables()
  for _, object in pairs(global.trains) do
    resetMetatable(object, Train)
  end
end

local function init_player(player)
  global.playerRules[player.index] = global.playerRules[player.index] or {page=1}
end

local function init_players()
  for i,player in pairs(game.players) do
    init_player(player)
  end
end

local function on_player_created(event)
  init_player(game.players[event.player_index])
end

function oninit()
  initGlob()
  findStations()
end

function onload()
  --initGlob()
  setMetatables()
  --local rem = removeInvalidTrains(false)
  --if rem > 0 then debugDump("You should never see this! Removed "..rem.." invalid trains") end
end

function on_configuration_changed(data)
  local status, err = pcall(function()
    if not data or not data.mod_changes then
      return
    end
    --debugDump(data,true)
    if data.mod_changes.SmartTrains then
      local old_version = data.mod_changes.SmartTrains.old_version
      local new_version = data.mod_changes.SmartTrains.new_version
      initGlob()
      init_players()
      if not old_version or old_version < "0.3.2" then
        findStations()
      end
      global.version = new_version
    end
  end)
  if not status then error(err, 2) end
end

function resetMetatable(o, mt)
  setmetatable(o,{__index=mt})
  return o
end

function addPos(p1,p2)
  if not p1.x then
    error("Invalid position", 2)
  end
  if p2 and not p2.x then
    error("Invalid position 2", 2)
  end
  local p2 = p2 or {x=0,y=0}
  return {x=p1.x+p2.x, y=p1.y+p2.y}
end

function expandPos(pos, range)
  local range = range or 0.5
  if not pos or not pos.x then error("invalid pos",3) end
  return {{pos.x - range, pos.y - range}, {pos.x + range, pos.y + range}}
end

function createProxy(trainstop)
  local offset = {[0] = {x=-0.5,y=-0.5},[2]={x=0.5,y=-0.5},[4]={x=0.5,y=0.5},[6]={x=-0.5,y=0.5}}
  local offsetcargo = {[0] = {x=-0.5,y=0.5},[2]={x=-0.5,y=-0.5},[4]={x=0.5,y=-0.5},[6]={x=0.5,y=0.5}}
  local pos = addPos(trainstop.position, offset[trainstop.direction])
  local poscargo = addPos(trainstop.position, offsetcargo[trainstop.direction])

  local proxy = {name="smart-train-stop-proxy", direction=0, force=trainstop.force, position=pos}
  local proxycargo = {name="smart-train-stop-proxy-cargo", direction=0, force=trainstop.force, position=poscargo}
  local area = expandPos(pos,0.2)
  local ent = trainstop.surface.find_entities_filtered{area = area, name="smart-train-stop-proxy", force = trainstop.force}
  if not ent[1] then
    ent = trainstop.surface.create_entity(proxy)
  else
    ent = ent[1]
  end
  if ent.valid then
    global.smartTrainstops[stationKey(trainstop)] = {entity = trainstop, proxy=ent}
    ent.minable = false
    ent.destructible = false
  end
  area = expandPos(poscargo,0.2)
  local ent2 = trainstop.surface.find_entities_filtered{area = area, name="smart-train-stop-proxy-cargo", force = trainstop.force}
  if not ent2[1] then
    ent2 = trainstop.surface.create_entity(proxycargo)
  else
    ent2 = ent2[1]
  end
  if ent.valid and ent2.valid then
    global.smartTrainstops[stationKey(trainstop)].cargo = ent2
    ent2.minable = false
    ent2.operable = false
    ent2.destructible = false
  end
end

function removeProxy(trainstop)
  if global.smartTrainstops[stationKey(trainstop)] then
    local proxy = global.smartTrainstops[stationKey(trainstop)].proxy
    local cargo = global.smartTrainstops[stationKey(trainstop)].cargo
    if proxy and proxy.valid then
      proxy.destroy()
    end
    if cargo and cargo.valid then
      cargo.destroy()
    end
    global.smartTrainstops[stationKey(trainstop)] = nil
  end
end

function recreateProxy(trainstop)
  local offset = {[0] = {x=-0.5,y=-0.5},[2]={x=0.5,y=-0.5},[4]={x=0.5,y=0.5},[6]={x=-0.5,y=0.5}}
  local offsetcargo = {[0] = {x=-0.5,y=0.5},[2]={x=-0.5,y=-0.5},[4]={x=0.5,y=-0.5},[6]={x=0.5,y=0.5}}
  if trainstop.entity.valid then
    if not trainstop.cargo or not trainstop.cargo.valid then
      local poscargo = addPos(trainstop.entity.position, offsetcargo[trainstop.entity.direction])
      local proxycargo = {name="smart-train-stop-proxy-cargo", direction=0, force=trainstop.entity.force, position=poscargo}
      local ent2 = trainstop.entity.surface.create_entity(proxycargo)
      if ent2.valid then
        global.smartTrainstops[stationKey(trainstop.entity)].cargo = ent2
        ent2.minable = false
        ent2.operable = false
        ent2.destructible = false
        debugDump("Updated smart train stop:"..trainstop.entity.backer_name,true)
      end
    end
    if not trainstop.proxy or not trainstop.proxy.valid then
      local pos = addPos(trainstop.position, offset[trainstop.direction])
      local proxy = {name="smart-train-stop-proxy", direction=0, force=trainstop.entity.force, position=pos}
      local ent = trainstop.surface.create_entity(proxy)
      if ent.valid then
        global.smartTrainstops[stationKey(trainstop)].proxy=ent
        ent.minable = false
        ent.destructible = false
      end
    end
  end
end

function findSmartTrainStopByTrain(vehicle, stationName)
  --local areas = {expandPos(vehicle.carriages[1].position, 3), expandPos(vehicle.carriages[#vehicle.carriages].position, 3)}
  local surface = vehicle.surface
  local found = false

  local area = expandPos(vehicle.position, 3)
  --for _,area in pairs(areas) do
  for _1, station in pairs(surface.find_entities_filtered{area=area, name="smart-train-stop"}) do
    --flyingText("S", GREEN, station.position, true)
    if station.backer_name == stationName then
      found = station
      break
    end
    if found then break end
  end
  --end
  return found
end

function removeInvalidTrains(show)
  local removed = 0
  local show = show or debug
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
    flyingText("Removed "..removed.." invalid trains", RED, false, true)
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
  local wait = wait or 600
  local count = #schedule.records
  local tmp = {time_to_wait = wait, station = station}
  if after then
    table.insert(schedule.records, after+1, tmp)
  else
    table.insert(schedule.records, tmp)
  end
  return schedule
end

function fuelvalue(item)
  return game.item_prototypes[item].fuel_value/1000000
end

function fuel_value_to_coal(value)
  return math.ceil(value/(game.item_prototypes["coal"].fuel_value/1000000))
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

function getKeyByValue(tableA, value)
  for i,c in pairs(tableA) do
    if c == value then
      return i
    end
  end
end

function ontrainchangedstate(event)
  --debugDump(getKeyByValue(defines.trainstate, event.train.state),true)
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
    local settings = global.trains[trainKey].settings
    local fuel = t:lowestFuel()
    local schedule = train.schedule
    if train.state == defines.trainstate.manual_control_stop or train.state == defines.trainstate.manual_control then
      local done = false
      for tick, trains in pairs(global.ticks) do
        for i, train in pairs(trains) do
          if train == t then
            if not train.waitForever then
              train:resetCircuitSignal()
              t.waitingStation = false
              train.waiting = false
              train.refueling = false
              trains[i] = nil
              done = true
            end
          end
        end
      end
      if not done then
        for i, train in pairs(global.trains) do
          if train == t then
            if not train.waitForever then
              train:resetCircuitSignal()
              t.waitingStation = false
              train.waiting = false
              train.refueling = false
            end
          end
        end
      end
    end
    if train.state == defines.trainstate.wait_station then
      t:updateLine()
      local smartStop = t:setWaitingStation()
      if smartStop then
        t:setCircuitSignal()
        local tick = event.tick + global.settings.circuit.interval
        insertInTable(global.updateTick,tick,t)
      end
      t.departAt = event.tick + schedule.records[schedule.current].time_to_wait
      if settings.autoRefuel then
        if t:lowestFuel() >= (global.settings.refuel.rangeMax) and t:currentStation() ~= t:refuelStation() then
          t:removeRefuelStation()
        end
        if t:currentStation() == t:refuelStation() then
          t:startRefueling()
          t:flyingText("refueling", YELLOW)
        end
      end
      if t.line and global.trainLines[t.line] and global.trainLines[t.line].rules and global.trainLines[t.line].rules[schedule.current] then
        t:startWaitingForRules()
      end
      if settings.autoDepart and t:currentStation() ~= t:refuelStation() and #schedule.records > 1 then
        t:startWaitingForAutoDepart()
        t:flyingText("waiting", YELLOW)
      end
      if t:isWaiting() then
      --debugDump("waiting",true)
      end
    elseif train.state == defines.trainstate.arrive_station or train.state == defines.trainstate.wait_signal or train.state == defines.trainstate.arrive_signal then
      if t.settings.autoRefuel then
        if t:lowestFuel() < (global.settings.refuel.rangeMin) and not inSchedule(t:refuelStation(), train.schedule) then
          train.schedule = addStation(t:refuelStation(), train.schedule, global.settings.refuel.time)
          t:flyingText("Refuel station added", YELLOW)
        end
      end
    end
    if train.state == defines.trainstate.arrive_station then
      t.direction = t.train.speed < 0 and 1 or 0
    end
    if t.advancedState == defines.trainstate.left_station then
      t:resetCircuitSignal()
      t.waitingStation = false
      t.waiting = false
      t.refueling = false
      t.departAt = false
      --    if t.line and global.trainLines[t.line] and global.trainLines[t.line].rules and global.trainLines[t.line].rules[train.schedule.current] then
      --      --Handle line rules here
      --      --t:flyingText("checking line rules", GREEN, {offset=-1})
      --      t:nextValidStation()
      --    end
    end
  end
  )
  if not status then
    pauseError(err, "train_changed_state")
  end
end

function insertInTable(tableA, key, value)
  if not tableA[key] then tableA[key] = {} end
  table.insert(tableA[key], value)
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

function ontick(event)
  if global.updateTick[event.tick] then
    for _, train in pairs(global.updateTick[event.tick]) do
      local status,err = pcall(
        function()
          if train.train and train.train.valid and train.waitingStation then
            train:setCircuitSignal()
            insertInTable(global.updateTick,event.tick+global.settings.circuit.interval,train)
          else
            removeInvalidTrains(true)
          end
        end)
      if not status then
        pauseError(err, "on_tick: updateCircuit")
      end
    end
    global.updateTick[event.tick] = nil
  end

  if event.tick % 60 == 0 then
    local status,err = pcall(
      function()
        for i,train in pairs(global.trains) do
          if train.train and train.train.valid then
            if train.line and train.train.speed == 0 then
              train:updateLine()
            end
          else
            removeInvalidTrains(true)
          end
        end
      end)
    if not status then
      pauseError(err, "on_tick: updateLine")
    end
  end


  if global.stopTick[event.tick] then
    local status,err = pcall(
      function()
        for i,train in pairs(global.stopTick[event.tick]) do
          if train.train and train.train.valid then
            train.train.manual_mode = true
            --debugDump("manual mode set",true)
          else
            removeInvalidTrains(true)
          end
        end
        global.stopTick[event.tick] = nil
      end)
  end
  if global.ticks[event.tick] then
    local status,err = pcall(
      function()
        for i,train in pairs(global.ticks[event.tick]) do
          if train.train.valid then
            train.lastMessage = train.lastMessage or 0
            if train.departAt  and event.tick - train.lastMessage >= 120 then
              local text = train.waitForever and "waiting forever" or "Leaving in "..util.formattime(train.departAt-event.tick)
              train:flyingText(text, RED,{offset=-2})
            end
            --for i,train in pairs(global.trains) do
            if train:isRefueling() then
              if event.tick >= train.refueling.nextCheck then
                if train:lowestFuel() >= global.settings.refuel.rangeMax then
                  train:flyingText("Refueling done", YELLOW)
                  train:refuelingDone(true)
                else
                  local nextCheck = event.tick + global.settings.depart.interval
                  train.refueling.nextCheck = nextCheck
                  if not global.ticks[nextCheck] then
                    global.ticks[nextCheck] = {train}
                  else
                    table.insert(global.ticks[nextCheck], train)
                  end
                end
              end
            end
            if train:isWaiting() then
              --local wait = (type(train.waiting.arrived) == "number") and train.waiting.arrived + global.settings.depart.minWait or train.waiting.lastCheck + global.settings.depart.interval
              if event.tick >= train.waiting.nextCheck then
                local keepWaiting = nil
                local cargo
                local rules
                if  train:isWaitingForRules() then
                  --Handle leave when full/empty rules here
                  --train:flyingText("checking full/empty rules", GREEN, {offset=-1})
                  rules = global.trainLines[train.line].rules[train.train.schedule.current]
                  --debugDump(rules,true)
                  local full = train:isCargoFull()
                  local empty = train:isCargoEmpty()
                  local signal, signalValue = train:getCircuitSignal()
                  if  (rules.full and full and not rules.waitForCircuit) or  -- only full set
                    (rules.empty and empty and not rules.waitForCircuit) or --only empty set
                    (rules.waitForCircuit and signal and not (rules.empty or rules.full)) or --circuit and empty/full NOT set
                    (rules.waitForCircuit and signal and ((rules.empty and empty) or (rules.full and full))) then

                    local jump = rules.waitForCircuit and rules.jumpTo or false
                    jump = rules.jumpToCircuit and signalValue or jump
                    train:waitingDone(true, jump)
                    if not (rules.jumpTo or rules.jumpToCircuit) then
                      train:flyingText("leave station", YELLOW, {offset=-1})
                    end
                    keepWaiting = false
                  else
                    local txt = (rules.full and not train:isCargoFull()) and "not full" or "not empty"
                    txt = rules.waitForCircuit and "waiting for circuit" or txt
                    if rules.full or rules.empty or rules.waitForCircuit then
                      if not rules.waitForCircuit or (rules.waitForCircuit and event.tick - train.lastMessage >= 120) then
                        train:flyingText(txt, YELLOW, {offset=-1})
                        train.lastMessage = event.tick
                      end
                    end
                    keepWaiting = true
                  end
                elseif train:isWaitingForAutoDepart() and (keepWaiting == nil or keepWaiting) then
                  cargo = train:cargoCount()
                  local last = train.waiting.lastCheck
                  if train:cargoEquals(cargo, train.waiting.cargo, global.settings.depart.minFlow, event.tick - last) then
                    train:flyingText("leave station", YELLOW)
                    train:waitingDone(true)
                    keepWaiting = false
                  else
                    train:flyingText("cargo changed", YELLOW)
                    keepWaiting = true
                  end
                end
                if keepWaiting and train.train.speed == 0 then
                  train.waiting.lastCheck = event.tick
                  train.waiting.cargo = cargo
                  local nextCheck = event.tick + global.settings.depart.interval
                  if rules and rules.waitForCircuit then
                    nextCheck = event.tick + global.settings.circuit.interval
                  end
                  train.waiting.nextCheck = nextCheck
                  if not global.ticks[nextCheck] then
                    global.ticks[nextCheck] = {train}
                  else
                    table.insert(global.ticks[nextCheck], train)
                  end
                else
                  train:resetCircuitSignal()
                  train.waitingStation = false
                  train.waiting = false
                  train.waitForever = false
                end
              end
            end
          else
            removeInvalidTrains(true)
          end
        end
        global.ticks[event.tick] = nil
      end
    )
    if not status then
      pauseError(err, "on_tick_trains")
    end
  end
  if event.tick%10==9  then
    local status,err = pcall(
      function()
        for pi, player in pairs(game.players) do
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
    )
    if not status then
      pauseError(err, "on_tick_players")
    end
  end
end

function on_player_opened(event)
  if event.entity.valid and game.players[event.player_index].valid then
    if event.entity.type == "locomotive" and event.entity.train then
      global.playerPage[event.player_index] = {schedule=1,lines=1}
      local name = event.entity.backer_name or event.entity.name
      local trainInfo = getTrainFromEntity(event.entity)
      removeInvalidTrains(true)
      GUI.create_or_update(trainInfo, event.player_index)
      global.guiData[event.player_index] = {rules={}}
      global.openedTrain[event.player_index] = event.entity.train
    elseif event.entity.type == "train-stop" then
      global.playerPage[event.player_index] = {schedule=1,lines=1}
      GUI.create_or_update(false, event.player_index)
      global.guiData[event.player_index] = {rules={}}
      global.openedName[event.player_index] = event.entity.backer_name
    end
  end
end

function on_player_closed(event)
  if event.entity.valid and game.players[event.player_index].valid then
    if event.entity.type == "locomotive" and event.entity.train then
      local name = event.entity.backer_name or event.entity.name
      GUI.destroy(event.player_index)
      global.guiData[event.player_index] = nil
      global.playerRules[event.player_index].page = 1
      global.openedTrain[event.player_index] = nil
      --set line version to -1, so it gets updated at the next station
      local train = getTrainFromEntity(event.entity)
      if train.line and train.lineVersion ~= 0 then
        train.lineVersion = -1
      end
    elseif event.entity.type == "train-stop" then
      GUI.destroy(event.player_index)
      global.guiData[event.player_index] = nil
      global.playerRules[event.player_index].page = 1
      if event.entity.backer_name ~= global.openedName[event.player_index] then
        on_station_rename(event.entity, global.openedName[event.player_index])
      end
    end
  end
end

function on_station_rename(station, oldName)
  local oldc = decreaseStationCount(oldName)
  local newc = increaseStationCount(station.backer_name)
  if oldc == 0 then
    renameStation(station.backer_name, oldName)
  end
end

function decreaseStationCount(name)
  if not global.stationCount[name] then
    global.stationCount[name] = 1
  end
  global.stationCount[name] = global.stationCount[name] - 1
  if global.stationCount[name] == 0 then
    local found = false
    for line, data in pairs(global.trainLines) do
      for i, record in pairs(data.records) do
        if record.station == name then
          found = true
          break
        end
      end
    end
    if not found then
      global.stationCount[name] = nil
      return 0
    end
  end
  return global.stationCount[name]
end

function increaseStationCount(name)
  if not global.stationCount[name] or global.stationCount[name] < 0 then
    global.stationCount[name] = 0
  end
  global.stationCount[name] = global.stationCount[name] + 1
  return global.stationCount[name]
end

function renameStation(newName, oldName)
  --update global.trainLines with new name
  debugDump("Updating lines",true)
  for line, data in pairs(global.trainLines) do
    for i, record in pairs(data.records) do
      if record.station == oldName then
        debugDump("Line "..line.." changed: "..oldName.." to "..newName,true)
        record.station = newName
      end
    end
    if type(data.rules) == "table" then
      for i, rule in pairs(data.rules) do
        if rule.station == oldName then
          rule.station = newName
        end
      end
    end
  end
end

script.on_event(events.on_player_opened, on_player_opened)
script.on_event(events.on_player_closed, on_player_closed)

function getTrainFromEntity(ent)
  for i,trainInfo in pairs(global.trains) do
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
        local ti = getTrainFromEntity(player.opened)
        key = getTrainKeyByTrain(global.trains, player.opened.train)
      end
    end
    return key
  end
end

function onbuiltentity(event)
  local status, err = pcall(function()
    local ent = event.created_entity
    local ctype = ent.type
    --debugDump({e=ent.ghost_name, t=ctype},true)
    if ctype == "entity-ghost" and (ent.ghost_name == "smart-train-stop-proxy" or ent.ghost_name == "smart-train-stop-proxy-cargo") then
      local surface = ent.surface
      local name = ent.ghost_name
      local area = expandPos(ent.position, 0.2)
      ent.revive()
      local ent = surface.find_entities_filtered{area=area, name = name}
      debugDump({ent[1].name},true)
      ent[1].destructible = false
      ent[1].minable = false
      if ent[1].name == "smart-train-stop-proxy-cargo" then 
        ent[1].operable = false
      end
      return
    end
    if ctype == "locomotive" or ctype == "cargo-wagon" then
      local newTrainInfo = getTrainFromEntity(ent)
      removeInvalidTrains(true)
    end
    if ctype == "train-stop" then
      increaseStationCount(ent.backer_name)
    end
    if ent.name == "smart-train-stop" then
      createProxy(event.created_entity)
    end
  end)
  if not status then
    pauseError(err, "on_built_entity")
  end
end

function onpreplayermineditem(event)
  local status, err = pcall(function()
    local ent = event.entity
    local ctype = ent.type
    if ctype == "locomotive" or ctype == "cargo-wagon" then
      local oldTrain = ent.train
      local ownPos
      for i,carriage in pairs(ent.train.carriages) do
        if ent == carriage then
          ownPos = i
          break
        end
      end
      removeInvalidTrains(true)
      local old = getTrainKeyByTrain(global.trains, ent.train)
      if old then table.remove(global.trains, old) end

      if #ent.train.carriages > 1 then
        if ent.train.carriages[ownPos-1] ~= nil then
          table.insert(tmpPos, ent.train.carriages[ownPos-1].position)
        end
        if ent.train.carriages[ownPos+1] ~= nil then
          table.insert(tmpPos, ent.train.carriages[ownPos+1].position)
        end
      end
    end
    if ctype == "train-stop" then
      decreaseStationCount(ent.backer_name)
    end
    if ent.name == "smart-train-stop" then
      removeProxy(event.entity)
    end
  end)
  if not status then
    pauseError(err, "on_pre_player_mined_item")
  end
end

function onplayermineditem(event)
  local status, err = pcall(function()
    local name = event.item_stack.name
    local results = {}
    if name == "diesel-locomotive" or name == "cargo-wagon" then
      if #tmpPos > 0 then
        for i,pos in pairs(tmpPos) do
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
          for i, t in pairs(result) do
            getTrainFromEntity(t)
          end
        end
        tmpPos = {}
      end
      removeInvalidTrains(true)
    end
  end)
  if not status then
    pauseError(err, "on_player_mined_item")
  end
end

function onentitydied(event)
  local status, err = pcall(function()
    debugDump(event.entity.name)
    removeInvalidTrains(true)
    if event.entity.type == "locomotive" or event.entity.type == "cargo-wagon" then
      removeInvalidTrains(true)
      return
    end
    if event.entity.type == "train-stop" then
      decreaseStationCount(event.entity.backer_name)
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
    increaseStationCount(event.created_entity.backer_name)
  end
  if event.created_entity.name == "smart-train-stop" then
    createProxy(event.created_entity)
  end
end

function on_robot_pre_mined(event)
  if event.entity.type == "train-stop" then
    decreaseStationCount(event.entity.backer_name)
  end
  if event.entity.name == "smart-train-stop" then
    removeProxy(event.entity)
  end
end

function scheduleToString(schedule)
  local tmp = "Schedule: "
  for i=1,#schedule.records do
    tmp = tmp.." "..schedule.records[i].station.."|"..schedule.records[i].time_to_wait/60
  end
  return tmp.." next: "..schedule.current
end

function debugDump(var, force)
  if false or force then
    for i,player in pairs(game.players) do
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
    local pos = {}
    color = color or RED
    if not pos then
      for i,p in pairs(game.players) do
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


--for k,v in ipairs(alphanumsort(unsorted)) do print(v) end
function alphanumsort(o)
  --local maxl = 0
  --for n,v in ipairs(o) do tostring(v):gsub("%d+", function(d) if #d > maxl then maxl = #d end; return d end) end
  --local function padnum(d) return ("%0"..maxl.."d"):format(d) end
  local function padnum(d) return ("%012d"):format(d) end
  table.sort(o, function(a,b)
    return tostring(a):gsub("%d+",padnum):lower() < tostring(b):gsub("%d+",padnum):lower() end)
  return o
end

function findAllEntitiesByType(surface, type)
  local entities = {}
  for coord in surface.get_chunks() do
    local X,Y = coord.x, coord.y
    if surface.is_chunk_generated{X,Y} then
      local area = {{X*32, Y*32}, {X*32 + 32, Y*32 + 32}}
      for i, entity in pairs(surface.find_entities_filtered{area = area, type = type}) do
        local key = entity.position.x.."A"..entity.position.y
        local name = entity.backer_name or entity.name
        local train = entity.train or false
        entities[key] = {name= name, pos = entity.position, train=train}
      end
    end
  end
  return entities
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
end

function stationKey(station)
  if type(station) == "boolean" then error("wrong type", 2) end
  return station.position.x..":"..station.position.y
end

function findStations()

  -- create shorthand object for primary game surface
  local surface = game.surfaces['nauvis']

  -- determine map size
  local min_x, min_y, max_x, max_y = 0, 0, 0, 0
  for c in surface.get_chunks() do
    if c.x < min_x then
      min_x = c.x
    elseif c.x > max_x then
      max_x = c.x
    end
    if c.y < min_y then
      min_y = c.y
    elseif c.y > max_y then
      max_y = c.y
    end
  end

  -- create bounding box covering entire generated map
  local bounds = {{min_x*32,min_y*32},{max_x*32,max_y*32}}
  for _, station in pairs(surface.find_entities_filtered{area=bounds, type="train-stop"}) do
    local key = stationKey(station)
    if not global.stationCount[station.backer_name] then
      global.stationCount[station.backer_name] = 0
    end
    global.stationCount[station.backer_name] = global.stationCount[station.backer_name] + 1
  end
end

script.on_init(oninit)
script.on_load(onload)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_train_changed_state, ontrainchangedstate)
script.on_event(defines.events.on_player_mined_item, onplayermineditem)
script.on_event(defines.events.on_preplayer_mined_item, onpreplayermineditem)
script.on_event(defines.events.on_entity_died, onentitydied)
script.on_event(defines.events.on_built_entity, onbuiltentity)
script.on_event(defines.events.on_gui_click, onguiclick)
script.on_event(defines.events.on_robot_pre_mined, on_robot_pre_mined)
script.on_event(defines.events.on_robot_built_entity, on_robot_built_entity)
script.on_event(defines.events.on_tick, ontick)

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
      local name = name or "log"
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
        global = {}
        initGlob()
        init_players()
      end
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
      script.on_event(events.on_player_opened, nil)
      script.on_event(events.on_player_closed, nil)
      global.ticks = {}
      global.stopTick = {}
      global.updateTick = {}
      for i, t in pairs(global.trains) do
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
      script.on_event(defines.events.on_train_changed_state, ontrainchangedstate)
      script.on_event(defines.events.on_gui_click, onguiclick)
      script.on_event(defines.events.on_tick, ontick)
      script.on_event(events.on_player_opened, on_player_opened)
      script.on_event(events.on_player_closed, on_player_closed)
    end,
    
    init = function()
      initGlob()
      init_players()
    end,
    
    set_train_mode = function(lua_train, mode)
      local status, err = pcall(function()
        local trainKey = getTrainKeyByTrain(global.trains, lua_train)
        local train = global.trains[trainKey]
        
        --debugDump(train,true)
        if train.waitForever or train.waiting then
          if train.waiting and global.ticks[train.waiting.nextCheck] then
            local id = false
              for i, train2 in pairs(global.ticks[train.waiting.nextCheck]) do
                if train2.train == train.train then
                  id = i
                end
              end
              if id then global.ticks[train.waiting.nextCheck][id] = nil end
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
      local trainKey = getTrainKeyByTrain(global.trains, lua_train)
      local train = global.trains[trainKey]
      --debugDump(train,true)
      if train.line then
        if train.waitForever then
          return train.train.schedule.records[train.train.schedule.current].station
        else
          return false
        end        
      else
        return false
      end
    end,
    
    
  }
)
