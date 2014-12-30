require "defines"
require "util"

local refuelStation = "Refuel" -- name of the refueling station
local refuelRangeMin = 25 -- in coal, add refuelStation to schedule when below min, remove refuelStation when above max
local refuelRangeMax = 50
local refuelTime = 300 -- 1s = 60
local minWait = 120 -- 1s = 60
local tmpPos = {}

function buildGUI(player)
  destroyGui(player.gui.left.stGui)
  destroyGui(player.gui.center.stGui)
  destroyGui(player.gui.top.stButtons)
  
  player.gui.left.add({type="flow", name="stGui", direction="vertical"}) 
  local stButtons = player.gui.top.add({type="flow", name="stButtons", direction="horizontal"})
  stButtons.add({type="button", name="toggleSTSettings", caption = {"text-st-collapsed"}})
end

function destroyGui(guiA)
  if guiA ~= nil and guiA.valid then
    guiA.destroy()
  end
end

game.onevent(defines.events.onplayercreated, function(event)
  local player = game.getplayer(event.playerindex)
  local gui = player.gui
--  buildGUI(player)
  if gui.left.stGui == nil or gui.center.stGui == nil or gui.top.stButtons == nil then
    buildGUI(player)
  end
end)

function showTrainInfoWindow(index)
  local gui = game.players[index].gui.left.stGui
  if gui.trainInfo ~= nil then
    gui.trainInfo.destroy()
  end
  gui = gui.add({type="flow", name="st_settingsButton", direction="vertical"})
  gui.add({type="flow", name="flowh", direction="horizontal"})
  gui = gui.add({type="frame", name="frm", direction="vertical"})
  gui.add({type="flow", name="buttons", direction="horizontal"})
  gui.buttons.add({type="button", name="st_toggle_Settings", caption = "Settings"})
  if #glob.trains > 0 then
    local trainGui = gui.add({type="table", name="tbl", colspan=2})
    trainGui.add({type="label", caption=""})
    --trainGui.add({type="label", caption=""})        
    trainGui.add({type="label", caption="Autorefuel"})
    for i,t in ipairs(glob.trains) do
      trainGui.add({type="label", caption=t.name, name="lbl"..i})
      --trainGui.add({type="button", name="btn_schedule__"..i, caption=" S "})
      trainGui.add({type="checkbox", name="btn_refuel__"..i, state=t.settings.autoRefuel})--, caption=math.floor(lowestFuel(t.train)/fuelvalue("coal")).." coal"})
    end
  end
end

function globalSettingsWindow(index)
  local gui = game.players[index].gui.center
  if gui.stGui == nil then
    gui.add({type="flow", name="stGui", direction="vertical"})
    gui.stGui.add({ type="flow", name="stSettings", direction="vertical"})
    gui.stGui.stSettings.add({type = "frame", name="stGlobalSettings", direction="horizontal", caption="Refuel settings"})
    gui.stGui.stSettings.stGlobalSettings.add{type="table", name="tbl", colspan=5}
    local tbl = gui.stGui.stSettings.stGlobalSettings.tbl
  
    tbl.add({type= "label", name="lblRangeMin", caption="Refuel below"})
    tbl.add({type= "textfield",name="refuelRangeMin", style="number_textfield_style"})
    tbl.add({type= "label", name="lblRangeMax", caption="coal, remove Station above"})
    tbl.add({type= "textfield", name="refuelRangeMax", style="number_textfield_style"})
    tbl.add({type= "label", name="lblRangeEnd", caption="coal"})
    
    tbl.add({type= "label", name="lblRefuelTime", caption="Refuel time(1/s):"})
    tbl.add({type="textfield", name="refuelTime", style="number_textfield_style"})
    tbl.add({type= "label", name="lblRefuelStation", caption="Refuel station:"})
    tbl.add({type= "textfield", name="refuelStation"})
    tbl.add({type= "button", name="refuelSave", caption="Ok"})
    
    tbl.refuelRangeMin.text = glob.settings.refuel.rangeMin or refuelRangeMin
    tbl.refuelRangeMax.text = glob.settings.refuel.rangeMax or refuelRangeMax
    tbl.refuelStation.text = glob.settings.refuel.station
    tbl.refuelTime.text = glob.settings.refuel.time / 60
  end
end

game.onevent(defines.events.onguiclick, function(event)
  local index = type(event.element)=="table" and event.element.playerindex or element
  local player = game.players[index]
  local element = event.element
  if element.name == "toggleSTSettings" then
    if player.gui.left.stGui.st_settingsButton == nil then
      showTrainInfoWindow(index)
      event.element.caption = {"text-st"}
    else
      destroyGui(player.gui.left.stGui.st_settingsButton)
      event.element.caption = {"text-st-collapsed"}
    end
  elseif element.name == "st_toggle_Settings" then
    if player.gui.center.stGui == nil then
      globalSettingsWindow(index)
    else
      destroyGui(player.gui.center.stGui)
    end
  elseif element.name == "refuelSave" then
    local settings = player.gui.center.stGui.stSettings.stGlobalSettings.tbl
    local time, min, max, station = tonumber(settings.refuelTime.text)*60, tonumber(settings.refuelRangeMin.text), tonumber(settings.refuelRangeMax.text), settings.refuelStation.text
    glob.settings.refuel = {time=time, rangeMin = min, rangeMax = max, station = station}
--    for i,t in ipairs(glob.trains) do
--      if t.settings.refueling.autoRefuel then
--        t.settings.refueling = {autoRefuel = t.settings.refueling.autoRefuel, station=station, range={min=min, max=max}, time=time}
--      end
--    end
    destroyGui(player.gui.center.stGui)
  else
    local _, _, option1, option2 = event.element.name:find("(%a+)__(%d+)")
    --debugLog("o1: "..option1.." o2: "..option2,true)
    option2 = tonumber(option2)
    if option1 == "refuel" then
      glob.trains[option2].settings.autoRefuel = not glob.trains[option2].settings.autoRefuel
    end
  end
end)

game.oninit(function()
  initGlob()
end)

game.onload(function()
  initGlob()
  local rem = removeInvalidTrains()
  if rem > 0 then debugLog("You should never see this! Removed "..rem.." invalid trains", true) end
end)

function initGlob()
  if glob.waitingTrains == nil then glob.waitingTrains = {} end
  if glob.trains == nil then glob.trains = {} end
  if glob.settings == nil then
    glob.settings = {refuel={}}
    glob.settings.refuel = {station = refuelStation, rangeMin = refuelRangeMin, rangeMax = refuelRangeMax, time = refuelTime}
  end
  if glob.guiDone == nil then glob.guiDone = {} end
  for i,p in ipairs(game.players) do
    if not glob.guiDone[p.name] then
      buildGUI(p)
      glob.guiDone[p.name] = true
    end
  end
  if glob.version == nil then
    glob.version = "0.0.1"
    for i,t in ipairs(glob.trains) do
      if not t.name then
        if t.train.locomotives ~= nil and (#t.train.locomotives.frontmovers > 0 or #t.train.locomotives.backmovers > 0) then
          t.name = t.train.locomotives.frontmovers[1].backername or t.train.locomotives.backmovers[1].backername
        else
          t.name = "cargoOnly"
        end
      end
      if not t.settings then t.settings = {autoRefuel = true} end
      if t.settings.refueling then t.settings.refueling = nil end
    end
    for i,t in ipairs(glob.waitingTrains) do
      if not t.settings then t.settings = {autoRefuel = true} end
    end
  end
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
      if train.locomotives ~= nil and (#train.locomotives.frontmovers > 0 or #train.locomotives.backmovers > 0) then
        newTrainInfo.name = train.locomotives.frontmovers[1].backername or train.locomotives.backmovers[1].backername
      else
        newTrainInfo.name = "cargoOnly"
      end
      newTrainInfo.settings = {autoRefuel = true}
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
    --debugLog("advance from "..schedule.records[schedule.current].station)
    train.schedule = schedule
  end
end

function fuelvalue(item)
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

function lowestFuel(train)
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
  --debugLog(getKeyByValue(defines.trainstate, train.state))
  if train.state == defines.trainstate["waitstation"] then
    if settings.autoRefuel then
      if fuel >= (glob.settings.refuel.rangeMax * fuelvalue("coal")) and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
        if inSchedule(glob.settings.refuel.station, schedule) and #schedule.records >= 3 then
          train.schedule = removeStation(glob.settings.refuel.station, schedule)
        end
      end
    end
    if schedule.records[schedule.current].station ~= glob.settings.refuel.station then
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
    if settings.autoRefuel then
      if fuel < (glob.settings.refuel.rangeMin * fuelvalue("coal")) and not inSchedule(glob.settings.refuel.station, schedule) then
        --train.schedule = addStation(refuelStation, schedule, 300, schedule.current)
        train.schedule = addStation(glob.settings.refuel.station, schedule, glob.settings.refuel.time)
      end
    end
  end

  if #glob.waitingTrains > 0 and (train.state == defines.trainstate["onthepath"] or train.state == defines.trainstate["manualcontrol"]) then
    local found = getKeyByTrain(glob.waitingTrains, train)
    if found then
      local settings = glob.waitingTrains[found].settings
      if train.state == defines.trainstate["onthepath"] then
        local schedule = train.schedule
        local prev = schedule.current - 1
        if prev == 0 then prev = #schedule.records end
        if schedule.records[prev].station == glob.settings.refuel.station then prev = prev-1 end
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
--    if glob.guiInit == false then
--      buildGUI()
--      glob.guiInit = true
--    end
    if #glob.waitingTrains > 0 then
      for i,t in ipairs(glob.waitingTrains) do
        if event.tick >= t.tick+minWait then
          local cargo = cargoCount(t.train)
          --local data = util.formattime(event.tick).." "..cargo.." r:"..(cargo-t.cargo)/(minWait/60)
          --debugLog(data, true)
          if cargo == t.cargo then
            nextStation(t.train)
          else
            --debugLog(t.train.schedule.records[t.train.schedule.current].station..": "..(math.abs(cargo-t.cargo)/(minWait/60)).."items/s",true)
            t.tick = event.tick
          end
          t.cargo = cargo
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
        --game.player.print("dist: "..util.distance(start,stop))
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
    for i,player in ipairs(game.players) do
      player.print(msg)
    end
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
    
    printG = function()
    if _G then
      printToFile( serpent.block(_G), "log" )
    else
      globalPrint("Global not found.")
    end
  end,

    resetWaiting = function()
      glob.waitingTrains = {}
    end,
    resetGui = function()
      for i, player in pairs(game.players) do
        if player.gui.center.stGui ~= nil then
          player.gui.center.stGui.destroy()
        end
      end
    end
  }
)
function printToFile(line, path)
  path = path or "log"
  path = table.concat({ "st", "/", path, ".txt" })
  game.makefile( path,  line)
end
