require "defines"
local refuelStation = "Refuel" -- name of the refueling station
local refuelRangeMin = 25 -- in coal, add refuelStation to schedule when below min, remove refuelStation when above max
local refuelRangeMax = 50
local refuelTime = 300 -- 1s = 60
local minWait = 120 -- 1s = 60
local tmpPos = {}

game.oninit(function()
  initGlob()
end)

game.onload(function()
  initGlob()
  local rem = removeInvalidTrains()
  if rem > 0 then game.player.print("You should never see this! Removed "..rem.." invalid trains") end
end)

function initGlob()
  if glob.waitingTrains == nil then
    glob.waitingTrains = {}
  end
  if glob.init ~= nil then return end
  glob.init = true
  glob.trains = {}
end

game.onevent(defines.events.onbuiltentity,
  function(event)
    local ent = event.createdentity
    local ctype = ent.type
    if ctype == "locomotive" or ctype == "cargo-wagon" then
      local newTrainInfo = getNewTrainInfo(ent.train)
      if newTrainInfo ~= nil then
        removeInvalidTrains()
        table.insert(glob.trains, newTrainInfo)
        printGlob()
      end
    end
  end
)

function trainEquals(trainA, trainB)
  if trainA.carriages[1].equals(trainB.carriages[1]) then
    return true
  end
  return false
end

function getKeyByTrain(tableA, train)
  for i, t in ipairs(tableA) do
    if trainEquals(t.train, train) then
      return i
    end
  end
  return false
end

game.onevent(defines.events.onpreplayermineditem, function(event)
  local ent = event.entity
  local ctype = ent.type
  if ctype == "locomotive" or ctype == "cargo-wagon" then
    local oldTrain = ent.train
    local ownPos
    for i,carriage in ipairs(ent.train.carriages) do
      if ent.equals(carriage) then
        ownPos = i
        break
      end
    end
    removeInvalidTrains()
    local old = getKeyByTrain(glob.trains, ent.train)
    if old then table.remove(glob.trains, old) end
    old = getKeyByTrain(glob.waitingTrains, ent.train)
    if old then table.remove(glob.waitingTrains, old) end

    if #ent.train.carriages > 1 then
      if ent.train.carriages[ownPos-1] ~= nil then
        table.insert(tmpPos, ent.train.carriages[ownPos-1].position)
      end
      if ent.train.carriages[ownPos+1] ~= nil then
        table.insert(tmpPos, ent.train.carriages[ownPos+1].position)
      end
    end
  end
end)

game.onevent(defines.events.onplayermineditem, function(event)
  local name = event.itemstack.name
  local results = {}
  if name == "diesel-locomotive" or name == "cargo-wagon" and #tmpPos > 0 then
    for i,pos in ipairs(tmpPos) do
      area = {{pos.x-1, pos.y-1},{pos.x+1, pos.y+1}}
      local loco = game.findentitiesfiltered{area=area, type="locomotive"}
      local wagon = game.findentitiesfiltered{area=area, type="cargo-wagon"}
      if #loco > 0 then
        table.insert(results, loco)
      elseif #wagon > 0 then
        table.insert(results, wagon)
      end
    end
    for _, result in ipairs(results) do
      for i, t in ipairs(result) do
        table.insert(glob.trains, getNewTrainInfo(t.train))
      end
    end
    removeInvalidTrains()
    printGlob()
    tmpPos = {}
  end
end)

function printGlob()
  debugLog("# "..#glob.trains)
  for i,t in ipairs(glob.trains) do
    debugLog("Train "..i..": carriages:"..#t.train.carriages)
  end
end

function getNewTrainInfo(train)
  if train ~= nil then
    local carriages = train.carriages
    if carriages ~= nil and carriages[1] ~= nil and carriages[1].valid then
      local newTrainInfo = {}
      newTrainInfo.train = train
      newTrainInfo.settings = {refueling = {station=refuelStation, range = {min = refuelRangeMin,max = refuelRangeMax}, time = refuelTime}}
      return newTrainInfo
    end
  end
end

function removeInvalidTrains()
  local removed = 0
  for i,t in ipairs(glob.trains) do
    if not t.train.valid then
      table.remove(glob.trains, i)
      removed = removed + 1
    end
  end
  for i,t in ipairs(glob.waitingTrains) do
    if not t.train.valid then
      table.remove(glob.waitingTrains, i)
    end
  end
  return removed
end

local function inSchedule(station, schedule)
  for i, rec in ipairs(schedule.records) do
    if rec.station == station then
      return true
    end
  end
  return false
end

local function removeStation(station, schedule)
  local found = false
  local tmp = schedule
  for i, rec in ipairs(schedule.records) do
    if rec.station == station then
      found = i
    end
  end
  if found then
    table.remove(schedule.records, found)
  end
  return tmp
end

local function addStation(station, schedule, wait, after)
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

function nextStation(train)
  local schedule = train.schedule
  if #schedule.records > 0 then
    schedule.records[schedule.current].time_to_wait = 0
    debugLog("advance from "..schedule.records[schedule.current].station)
    train.schedule = schedule
  end
end

local function fuelvalue(item)
  return game.itemprototypes[item].fuelvalue
end

local function calcFuel(contents)
  local value = 0
  --/c game.player.print(game.player.character.vehicle.train.locomotives.frontmovers[1].energy)
  for i, c in pairs(contents) do
    value = value + c*fuelvalue(i)
  end
  return value
end

local function distance(point1, point2)
  local diffX = point1.x - point2.x
  local diffY = point1.y - point2.y
  return math.sqrt(diffX ^ 2 + diffY ^ 2)
end

local function lowestFuel(train)
  local minfuel = nil
  local c
  for i,carriage in ipairs(train.carriages) do
    if carriage.type == "locomotive" then
      c = calcFuel(carriage.getinventory(1).getcontents())
      if minfuel == nil or c < minfuel then
        minfuel = c
      end
    end
  end
  return minfuel
end

function cargoCount(train)
  local sum = 0
  for _, wagon in ipairs(train.carriages) do
    if wagon.type == "cargo-wagon" then
      if wagon.name ~= "rail-tanker" then
        sum = sum + wagon.getitemcount()
      else
        local d = remote.call("railtanker", "getLiquidByWagon", wagon)
        --debugLog(serpent.dump(d),true)
        sum = sum + d.amount
      end
    end
  end
  return sum
end

function getKeyByValue(tableA, value)
  for i,c in pairs(tableA) do
    if c == value then
      return i
    end
  end
end
game.onevent(defines.events.ontrainchangedstate, function(event)

  end)
game.onevent(defines.events.ontrainchangedstate, function(event)
  local train = event.train
  local trainKey = getKeyByTrain(glob.trains, train)
  if not trainKey then
    table.insert(glob.trains, getNewTrainInfo(train))
    removeInvalidTrains()
    trainKey = #glob.trains
  end
  local settings = glob.trains[trainKey].settings
  local fuel = lowestFuel(train)
  local schedule = train.schedule
  debugLog(getKeyByValue(defines.trainstate, train.state))
  if train.state == defines.trainstate["waitstation"] then
    debugLog("Fuel: "..fuel.." req: "..(settings.refueling.range.max * fuelvalue("coal")))
    if fuel >= (settings.refueling.range.max * fuelvalue("coal")) and schedule.records[schedule.current].station ~= settings.refueling.station then
      if inSchedule(settings.refueling.station, schedule) and #schedule.records >= 3 then
        train.schedule = removeStation(settings.refueling.station, schedule)
      end
    end
    if schedule.records[schedule.current].station ~= settings.refueling.station then
      --debugLog("wCargo: "..cargoCount(train).."@"..game.tick,true)
      local tanker = false
      -- for _, wagon in ipairs(train.carriages) do
      -- if wagon.name == "rail-tanker" then
      -- tanker = true
      -- break
      -- end
      -- end
      if not tanker then
        table.insert(glob.waitingTrains, {train = train, cargo = cargoCount(train), tick = game.tick, wait = train.schedule.records[train.schedule.current].time_to_wait, settings=settings})
      end
    end
  elseif train.state == defines.trainstate["arrivestation"]  or train.state == defines.trainstate["waitsignal"] or train.state == defines.trainstate["arrivesignal"] or train.state == defines.trainstate["onthepath"] then
    if fuel < (settings.refueling.range.min * fuelvalue("coal")) and not inSchedule(settings.refueling.station, schedule) then
      --train.schedule = addStation(refuelStation, schedule, 300, schedule.current)
      train.schedule = addStation(settings.refueling.station, schedule, settings.refueling.time)
    end
  end

  if #glob.waitingTrains > 0 and (train.state == defines.trainstate["onthepath"] or train.state == defines.trainstate["manualcontrol"]) then
    local found = getKeyByTrain(glob.waitingTrains, train)
    if found then
      local settings = glob.waitingTrains[found].settings
      if train.state == defines.trainstate["onthepath"] then
        --debugLog("oCargo: "..cargoCount(train).."@"..game.tick,true)
        local schedule = train.schedule
        local prev = schedule.current - 1
        if prev == 0 then prev = #schedule.records end
        if schedule.records[prev].station == settings.refueling.station then prev = prev-1 end
        schedule.records[prev].time_to_wait = glob.waitingTrains[found].wait
        train.schedule = schedule
        table.remove(glob.waitingTrains, found)
      elseif train.state == defines.trainstate["manualcontrol"] then
        table.remove(glob.waitingTrains, found)
      end
    end
  end
end)

game.onevent(defines.events.ontick,
  function(event)
    if event.tick % minWait == 0 then
      if #glob.waitingTrains > 0 then
        for i,t in ipairs(glob.waitingTrains) do
          local cargo = cargoCount(t.train)
          if (t.tick + minWait) <= event.tick then
            if cargo == t.cargo then
              nextStation(t.train)
            else
              --debugLog(t.train.schedule.records[t.train.schedule.current].station..": "..(math.abs(cargo-t.cargo)/(minWait/60)).."items/s",true)
              t.cargo = cargo
            end
          end
        end
      end
    end
  end
)
--[[

local start = nil

local stop = nil

local printed = nil

game.onevent(defines.events.ontick, function(event)
    if game.player.character and game.player.character.vehicle and game.player.character.vehicle.name == "diesel-locomotive" then
      if game.player.character.vehicle.train.locomotives.frontmovers[1].getitemcount("raw-wood") == 2 and start == nil then
        --start = game.player.character.vehicle.train.locomotives.frontmovers[1].position
        start = game.tick
        game.player.print("start: "..serpent.dump(start))
      end

      if stop == nil and game.player.character.vehicle.train.locomotives.frontmovers[1].getitemcount("raw-wood") < 1 then
        --stop = game.player.character.vehicle.train.locomotives.frontmovers[1].position
        stop = game.tick
        game.player.print("stop: "..serpent.dump(stop))
      end

      if not printed and game.player.character.vehicle.train.locomotives.frontmovers[1].getitemcount("raw-wood") < 1 then
        game.player.print("start: "..serpent.dump(start))
        game.player.print("end: "..serpent.dump(stop))
        game.player.print("dur: "..(stop-start)/60)
        game.player.print("formula: ".. 8000000 / 600000)
        --game.player.print("dist: "..distance(start,stop))
        printed = true
      end
    else
      if printed then
        start, stop, printed = nil,nil,nil
      end
    end
end)
--]]

function scheduleToString(schedule)
  local tmp = "Schedule: "
  for i=1,#schedule.records do
    tmp = tmp.." "..schedule.records[i].station.."|"..schedule.records[i].time_to_wait/60
  end
  return tmp.." next: "..schedule.current
end

function debugLog(msg, force)
  if false or force then
    game.player.print(msg)
  end
end
remote.addinterface("st",
  {
    printGlob = function(name)
      if name then
        debugLog(serpent.dump(glob[name]), true)
      else
        debugLog(serpent.dump(glob), true)
      end
    end,

    resetWaiting = function()
      glob.waitingTrains = {}
      glob.trains = {}
    end
  }
)
