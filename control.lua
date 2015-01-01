require "defines"
require "util"

-- range in coal, add refuelStation to schedule when below min, remove refuelStation when above max
-- times in ticks (60/s)
local defaultSettings =
  { refuel={station="Refuel", rangeMin = 25, rangeMax = 50, time = 300},
    depart={minWait = 120, interval = 120}}

local defaultTrainSettings = {autoRefuel = true, autoDepart = true}
local tmpPos = {}

function buildGUI(player)
  destroyGui(player.gui.left.stGui)
  destroyGui(player.gui.center.stGui)
  destroyGui(player.gui.top.stButtons)

  player.gui.left.add({type="flow", name="stGui", direction="vertical"})
  local stButtons = player.gui.top.add({type="flow", name="stButtons", direction="horizontal"})
  stButtons.add({type="button", name="toggleSTSettings", caption = {"text-st"}})
end

function destroyGui(guiA)
  if guiA ~= nil and guiA.valid then
    guiA.destroy()
  end
end

function showTrainInfoWindow(index, trainKey)
  local gui = game.players[index].gui.left.stGui
  if gui["trainSettings__"..trainKey] ~= nil then
    gui["trainSettings__"..trainKey].destroy()
  end
  gui = gui.add({type="frame", name="trainSettings__"..trainKey, direction="vertical"})
  if glob.trains[trainKey].train.valid then
    local t = glob.trains[trainKey]
    local trainGui = gui.add({type="table", name="tbl", colspan=3})
    trainGui.add({type="label", caption="Name"})
    trainGui.add({type="label", caption=""})
    trainGui.add({type="label", caption="Auto-"})

    trainGui.add({type="label", caption=""})
    trainGui.add({type="label", caption="Refuel"})
    trainGui.add({type="label", caption="Depart"})

    trainGui.add({type="label", caption=t.name, name="lbl"..trainKey})
    trainGui.add({type="checkbox", name="btn_refuel__"..trainKey, state=t.settings.autoRefuel})--, caption=math.floor(lowestFuel(t.train)/fuelvalue("coal")).." coal"})
    trainGui.add({type="checkbox", name="btn_depart__"..trainKey, state=t.settings.autoDepart})
  end
end

function globalSettingsWindow(index)
  local gui = game.players[index].gui.center
  if gui.stGui == nil then
    gui.add({type="flow", name="stGui", direction="vertical"})
    gui.stGui.add({ type="flow", name="stSettings", direction="vertical"})
    gui.stGui.stSettings.add({type = "frame", name="stGlobalSettings", direction="horizontal", caption="Global settings"})
    gui.stGui.stSettings.stGlobalSettings.add{type="table", name="tbl", colspan=5}
    local tbl = gui.stGui.stSettings.stGlobalSettings.tbl

    tbl.add({type= "label", name="lblRangeMin", caption="Refuel below"})
    tbl.add({type= "textfield",name="refuelRangeMin", style="number_textfield_style"})
    tbl.add({type= "label", name="lblRangeMax", caption="coal, remove Station above"})
    tbl.add({type= "textfield", name="refuelRangeMax", style="number_textfield_style"})
    tbl.add({type= "label", name="lblRangeEnd", caption="coal"})

    tbl.add({type= "label", name="lblRefuelTime", caption="Refuel time:"})
    tbl.add({type="textfield", name="refuelTime", style="number_textfield_style"})
    tbl.add({type= "label", name="lblRefuelStation", caption="Refuel station:"})
    tbl.add({type= "textfield", name="refuelStation"})
    tbl.add({type= "label", caption=""})

    tbl.add({type= "label", caption="Minimum waiting time"})
    tbl.add({type= "textfield", name="minWait", style="number_textfield_style"})
    tbl.add({type= "label", caption="Check interval for autodepart"})
    tbl.add({type= "textfield", name="departInterval", style="number_textfield_style"})
    tbl.add({type= "button", name="refuelSave", caption="Ok"})

    tbl.refuelRangeMin.text = glob.settings.refuel.rangeMin
    tbl.refuelRangeMax.text = glob.settings.refuel.rangeMax
    tbl.refuelStation.text = glob.settings.refuel.station
    tbl.refuelTime.text = glob.settings.refuel.time / 60
    tbl.departInterval.text = glob.settings.depart.interval / 60
    tbl.minWait.text = glob.settings.depart.minWait / 60
  end
end

function onguiclick(event)
  local index = type(event.element)=="table" and event.element.playerindex or element
  local player = game.players[index]
  local element = event.element
  --debugLog("index: "..index.." element:"..element.name,true)
  if element.name == "toggleSTSettings" then
    if player.gui.center.stGui == nil then
      globalSettingsWindow(index)
    else
      destroyGui(player.gui.center.stGui)
    end
  elseif element.name == "refuelSave" then
    local settings = player.gui.center.stGui.stSettings.stGlobalSettings.tbl
    local time, min, max, station = tonumber(settings.refuelTime.text)*60, tonumber(settings.refuelRangeMin.text), tonumber(settings.refuelRangeMax.text), settings.refuelStation.text
    glob.settings.refuel = {time=time, rangeMin = min, rangeMax = max, station = station}
    local interval, minWait = tonumber(settings.departInterval.text)*60, tonumber(settings.minWait.text)*60
    glob.settings.depart = {interval = interval, minWait = minWait}

    destroyGui(player.gui.center.stGui)
  else
    local _, _, option1, option2 = event.element.name:find("(%a+)__(%d+)")
    --debugLog("o1: "..option1.." o2: "..option2,true)
    option2 = tonumber(option2)
    if option1 == "refuel" then
      glob.trains[option2].settings.autoRefuel = not glob.trains[option2].settings.autoRefuel
    elseif option1 == "depart" then
      glob.trains[option2].settings.autoDepart = not glob.trains[option2].settings.autoDepart
    end
  end
end

function onplayercreated(event)
  local player = game.getplayer(event.playerindex)
  local gui = player.gui
  if gui.left.stGui == nil or gui.center.stGui == nil or gui.top.stButtons == nil then
    buildGUI(player)
  end
end

function oninit() initGlob() end

function onload()
  initGlob()
  --debugLog(util.formattime(game.tick).." onload",true)
  local rem = removeInvalidTrains()
  if rem > 0 then debugLog("You should never see this! Removed "..rem.." invalid trains") end
end

function initGlob()
  if glob.version == nil or glob.version == "0.0.1" then
    glob.waitingTrains = nil
    glob.trains = nil
  end
  if glob.version == "0.0.2" then
    for i,t in ipairs(glob.waitingTrains) do
      t.arrived = t.tick
      t.station = t.train.schedule.current
    end
    glob.waitingTrains = {}
  end
  if glob.waitingTrains == nil then glob.waitingTrains = {} end
  if glob.trains == nil then glob.trains = {} end
  if glob.settings == nil then glob.settings = defaultSettings end
  if glob.guiDone == nil then glob.guiDone = {} end
  for i,p in ipairs(game.players) do
    if not glob.guiDone[p.name] then
      buildGUI(p)
      glob.guiDone[p.name] = true
    end
  end
  if glob.version == nil or glob.version == "0.0.1" then
    if not glob.settings.depart then glob.settings.depart = defaultSettings.depart end
    for i,t in ipairs(glob.trains) do
      glob.trains[i] = getNewTrainInfo(t)
    end
    glob.waitingTrains = {}
  end
  glob.version = "0.0.3"
end
game.oninit(function() oninit() end)
game.onload(function() onload() end)

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
      newTrainInfo.settings = defaultTrainSettings
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

function inSchedule(station, schedule)
  for i, rec in ipairs(schedule.records) do
    if rec.station == station then
      return true
    end
  end
  return false
end

function removeStation(station, schedule)
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

function nextStation(train)
  local schedule = train.schedule
  if #schedule.records > 0 then
    schedule.records[schedule.current].time_to_wait = 0
    train.schedule = schedule
  end
end

function fuelvalue(item)
  return game.itemprototypes[item].fuelvalue
end

function calcFuel(contents)
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
  local sum = {}
  for i, wagon in ipairs(train.carriages) do
    if wagon.type == "cargo-wagon" then
      if wagon.name ~= "rail-tanker" then
        --sum = sum + wagon.getcontents()
        sum = addInventoryContents(sum, wagon.getinventory(1).getcontents())
      else
        if remote.interfaces.railtanker and remote.interfaces.railtanker.getLiquidByWagon then
          local d = remote.call("railtanker", "getLiquidByWagon", wagon)
          --debugLog(serpent.dump(d),true)
          if d.type ~= nil then
            sum[d.type] = sum[d.type] or 0
            sum[d.type] = sum[d.type] + d.amount
          end
        end
      end
    end
  end
  --debugLog(serpent.dump(sum),true)
  return sum
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
  --debugLog(getKeyByValue(defines.trainstate, train.state), true)

  if train.state == defines.trainstate["waitstation"] then
    if settings.autoRefuel then
      if fuel >= (glob.settings.refuel.rangeMax * fuelvalue("coal")) and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
        if inSchedule(glob.settings.refuel.station, schedule) and #schedule.records >= 3 then
          train.schedule = removeStation(glob.settings.refuel.station, schedule)
        end
      end
    end
    if settings.autoDepart and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
      table.insert(glob.waitingTrains, {train = train, cargo = cargoCount(train), arrived = game.tick, wait = train.schedule.records[train.schedule.current].time_to_wait, station = train.schedule.current, settings=settings})
      --debugLog(util.formattime(event.tick).." arrived Station:"..train.schedule.current.." "..train.schedule.records[train.schedule.current].station,true)
    end
  elseif train.state == defines.trainstate["arrivestation"] and schedule.records[schedule.current].station ~= glob.settings.refuel.station and settings.autoDepart then
    --insert waiting      
  elseif train.state == defines.trainstate["arrivestation"]  or train.state == defines.trainstate["waitsignal"] or train.state == defines.trainstate["arrivesignal"] or train.state == defines.trainstate["onthepath"] then
    if settings.autoRefuel then
      if fuel < (glob.settings.refuel.rangeMin * fuelvalue("coal")) and not inSchedule(glob.settings.refuel.station, schedule) then
        train.schedule = addStation(glob.settings.refuel.station, schedule, glob.settings.refuel.time)
      end
    end
  end

  if settings.autoDepart and #glob.waitingTrains > 0 and (train.state == defines.trainstate["onthepath"] or train.state == defines.trainstate["manualcontrol"]) then
    local found = getKeyByTrain(glob.waitingTrains, train)
    if found then
      if train.state == defines.trainstate["onthepath"] then
--        local settings = glob.waitingTrains[found].settings
        local t = glob.waitingTrains[found]
        local station, time = t.station, t.wait
        local schedule = train.schedule
--        local prev = schedule.current - 1
--        if prev == 0 then prev = #schedule.records end
--        if schedule.records[prev].station == glob.settings.refuel.station then prev = prev-1 end
--        schedule.records[prev].time_to_wait = glob.waitingTrains[found].wait
        schedule.records[station].time_to_wait = time
        train.schedule = schedule
        table.remove(glob.waitingTrains, found)
      elseif train.state == defines.trainstate["manualcontrol"] then
        table.remove(glob.waitingTrains, found)
      end
    end
  end
end

--function tableCompare( tbl1, tbl2 )
--    for k, v in pairs( tbl1 ) do
--        if  type(v) == "table" and type(tbl2[k]) == "table" then
--            if not table.compare( v, tbl2[k] )  then return false end
--        else
--            if ( v ~= tbl2[k] ) then return false end
--            --if not equalOrNilAnd0(v, tbl2[k]) then return false end
--        end
--    end
--    for k, v in pairs( tbl2 ) do
--        if type(v) == "table" and type(tbl1[k]) == "table" then
--            if not table.compare( v, tbl1[k] ) then return false end
--        else 
--            if v ~= tbl1[k] then return false end
--            --if not equalOrNilAnd0(v, tbl2[k]) then return false end
--        end
--    end
--    return true
--end
--function equalOrNilAnd0(v1, v2)
--  return v1 == v2 or (v1 == nil and v2 == 0) or (v1 == 0 and v2 == nil)
--end

function ontick(event)
  if #glob.waitingTrains > 0 then
    for i,t in ipairs(glob.waitingTrains) do
      local wait = (type(t.arrived) == "number") and t.arrived + glob.settings.depart.minWait or t.lastCheck + glob.settings.depart.interval
      if t.settings.autoDepart and event.tick >= wait then
        local cargo = cargoCount(t.train)
        --local data = util.formattime(event.tick).." "..table.concat(table.pack(table.unpack(cargo)), " ")
        --debugLog(serpent.dump({cargo, t.cargo}), true)
        --debugLog(serpent.dump(tableCompare(cargo, t.cargo)),true)
        --debugLog(data, true)
        if table.compare(cargo, t.cargo) then
          nextStation(t.train)
          t.arrived = false
        else
          t.lastCheck = event.tick
          t.cargo = cargo
          t.arrived = false
        end
      elseif not t.settings.autoDepart then
        table.remove(glob.waitingTrains, i)
      end
    end
  end
  if event.tick%10==9  then
    for pi, player in ipairs(game.players) do
      if player.opened ~= nil and player.opened.valid and player.opened.type == "locomotive" and player.opened.train ~= nil then
        local key = getKeyByTrain(glob.trains, player.opened.train)
        if not key then
          table.insert(glob.trains, getNewTrainInfo(player.opened.train))
          key = getKeyByTrain(glob.trains, player.opened.train)
        elseif player.gui.left.stGui["trainSettings__"..key] == nil then
          showTrainInfoWindow(pi, key)
        end
      elseif player.opened == nil then --and glob.opened[pi] ~= nil then
        for n, name in ipairs(player.gui.left.stGui.childrennames) do
          destroyGui(player.gui.left.stGui[name])
      end
      end
    end
  end
end


function onbuiltentity(event)
  local ent = event.createdentity
  local ctype = ent.type
  if ctype == "locomotive" or ctype == "cargo-wagon" then
    local newTrainInfo = getNewTrainInfo(ent.train)
    if newTrainInfo ~= nil then
      removeInvalidTrains()
      table.insert(glob.trains, newTrainInfo)
    end
  end
end

function onpreplayermineditem(event)
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
end

function onplayermineditem(event)
  local name = event.itemstack.name
  local results = {}
  if name == "diesel-locomotive" or name == "cargo-wagon" and #tmpPos > 0 then
    for i,pos in ipairs(tmpPos) do
      local area = {{pos.x-1, pos.y-1},{pos.x+1, pos.y+1}}
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
    tmpPos = {}
  end
end

game.onevent(defines.events.ontick, function(event) ontick(event) end)
game.onevent(defines.events.ontrainchangedstate, function(event) ontrainchangedstate(event) end)
game.onevent(defines.events.onplayermineditem, function(event) onplayermineditem(event) end)
game.onevent(defines.events.onpreplayermineditem, function(event) onpreplayermineditem(event) end)
game.onevent(defines.events.onbuiltentity, function(event) onbuiltentity(event) end)
game.onevent(defines.events.onguiclick, function(event) onguiclick(event) end)
game.onevent(defines.events.onplayercreated, function(event) onplayercreated(event) end)


--local start = nil
--local stop = nil
--local printed = nil
--game.onevent(defines.events.ontick, function(event)
--    if game.player.character and game.player.character.vehicle and game.player.character.vehicle.name == "diesel-locomotive" then
--      if game.player.character.vehicle.train.locomotives.frontmovers[1].getitemcount("raw-wood") == 2 and start == nil then
--        --start = game.player.character.vehicle.train.locomotives.frontmovers[1].position
--        start = game.tick
--        game.player.print("start: "..serpent.dump(start))
--      end
--      if stop == nil and game.player.character.vehicle.train.locomotives.frontmovers[1].getitemcount("raw-wood") < 1 then
--        --stop = game.player.character.vehicle.train.locomotives.frontmovers[1].position
--        stop = game.tick
--        game.player.print("stop: "..serpent.dump(stop))
--      end
--      if not printed and game.player.character.vehicle.train.locomotives.frontmovers[1].getitemcount("raw-wood") < 1 then
--        game.player.print("start: "..serpent.dump(start))
--        game.player.print("end: "..serpent.dump(stop))
--        game.player.print("dur: "..(stop-start)/60)
--        game.player.print("formula: ".. 8000000 / 600000)
--        --game.player.print("dist: "..util.distance(start,stop))
--        printed = true
--      end
--    else
--      if printed then
--        start, stop, printed = nil,nil,nil
--      end
--    end
--end)

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

function printToFile(line, path)
  path = path or "log"
  path = table.concat({ "st", "/", path, ".txt" })
  game.makefile( path,  line)
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

    printG = function(name)
      local name = name or "log"
      if _G then
        printToFile( serpent.block(_G), name )
      else
        globalPrint("Global not found.")
      end
    end
  }
)
