require "defines"
require "util"
local RED = {r = 0.9}
local GREEN = {g = 0.7}
local YELLOW = {r = 0.8, g = 0.8}
-- range in coal, add refuelStation to schedule when below min, remove refuelStation when above max
-- times in ticks (60/s)
local defaultSettings =
  { refuel={station="Refuel", rangeMin = 25, rangeMax = 50, time = 300},
    depart={minWait = 240, interval = 120, minFlow = 1}}

local defaultTrainSettings = {autoRefuel = true, autoDepart = true}
local tmpPos = {}
MOD = {version="0.1.2"}

function buildGUI(player)
  destroyGui(player.gui.left.stGui)

  local stGui = player.gui.left.add({type="flow", name="stGui", direction="vertical"})
  stGui.add({type="flow", name="stSettings", direction="vertical"})
end

function destroyGui(guiA)
  if guiA ~= nil and guiA.valid then
    guiA.destroy()
  end
end

function showSettingsButton(index)
  local gui = game.players[index].gui.left.stGui.stSettings
  if gui.toggleSTSettings ~= nil then
    gui.toggleSTSettings.destroy()
  end
  gui.add({type="button", name="toggleSTSettings", caption = "ST-Settings", style="st_button"})
end

function showTrainInfoWindow(index, trainKey)
  local gui = game.players[index].gui.left.stGui
  if gui.trainSettings ~= nil then
    gui.trainSettings.destroy()
  end
  if glob.trains[trainKey].train.valid then
    gui = gui.add({type="flow", name="trainSettings", direction="vertical"})
    local t = glob.trains[trainKey]
    local trainGui = gui.add({type="table", name="tbl", colspan=3})
    trainGui.add({type="label", caption="Name", style="st_label"})
    trainGui.add({type="label", caption=""})
    trainGui.add({type="label", caption="Auto-", style="st_label"})

    trainGui.add({type="label", caption=""})
    trainGui.add({type="label", caption="Refuel", style="st_label"})
    trainGui.add({type="label", caption="Depart", style="st_label"})

    trainGui.add({type="label", caption=t.name, name="lbl"..trainKey, style="st_label"})
    trainGui.add({type="checkbox", name="btn_refuel__"..trainKey, state=t.settings.autoRefuel})--, caption=math.floor(lowestFuel(t.train)/fuelvalue("coal")).." coal"})
    trainGui.add({type="checkbox", name="btn_depart__"..trainKey, state=t.settings.autoDepart})
    
    trainGui.add({ type="checkbox", name="filter__" ..trainKey, style="tm-icon-"..glob.filter, state = true })
    trainGui.add({type="button", name="togglefilter__"..trainKey, caption = glob.filterbool, style="st_button"})
    trainGui.add({type="textfield", name="filteramount", style="st_textfield_small"})
    showLinesWindow(index, trainKey)
  end
end

function showLinesWindow(index, trainKey, line)
  local line = line or ""
  local gui = game.players[index].gui.left.stGui
  if glob.trains[trainKey].train.valid then
    if gui.lineSettings ~= nil then
      gui.lineSettings.destroy()
    end
    local t = glob.trains[trainKey]
    gui = gui.add({type="flow", name="lineSettings", direction="vertical"})
    if #t.train.schedule.records > 0 then
      local tbl = gui.add({type="table", name="tbl1", colspan=4})
      tbl.add({type="label", name="activeLine", caption="Active line: "..line, style="st_label"})
      tbl.add({type="label", caption=""})
      tbl.add({type="label", caption=""})
      tbl.add({type="label", caption=""})
            
      tbl.add({type="label", caption="Station", style="st_label"})
      tbl.add({type="label", caption="Time", style="st_label"})
      tbl.add({type="label", caption="Dynamic", style="st_label"})
      tbl.add({type="label", caption="Edit", style="st_label"})
      local current = t.train.schedule.current
      for i, s in ipairs(t.train.schedule.records) do
        tbl.add({type="label", caption=s.station, style="st_label"})
        tbl.add({type="label", caption=s.time_to_wait/60, style="st_label"})
        tbl.add({type="checkbox", name="togglecon__"..i, state=false})
        tbl.add({type="checkbox", name="toggleedit__"..trainKey.."__"..i, state=false})
      end
    end
    local btns = gui.add({type="flow", name="btns", direction="horizontal"})
    btns.add({type="button", name="readSchedule__"..trainKey, caption="Read", style="st_button"})
    btns.add({type="button", name="loadSchedule__"..trainKey, caption="Load", style="st_button"})
    btns.add({type="button", name="saveSchedule__"..trainKey, caption="Save", style="st_button"})
    btns.add({type="textfield", name="lineName", text="", style="st_textfield_big"})
    btns.lineName.text = line
  else
    if gui.lineSettings ~= nil then
      gui.lineSettings.destroy()
    end
  end
end

function updateLineEdit(index, trainKey, stationKey)
  local gui = game.players[index].gui.left.stGui
  if gui.lineSettings ~= nil then
    gui = gui.lineSettings.tbl1
    local records = glob.trains[trainKey].train.schedule.records
    for i,s in ipairs(records) do
      gui["toggleedit__"..trainKey.."__"..i].state = (i==stationKey)
    end
  end
end

function globalSettingsWindow(index)
  local gui = game.players[index].gui.left.stGui.stSettings
  if gui.stGlobalSettings == nil then
    gui.add({type = "flow", name="stGlobalSettings", direction="horizontal", caption="Global settings"})
    gui.stGlobalSettings.add{type="table", name="tbl", colspan=5}
    local tbl = gui.stGlobalSettings.tbl

    tbl.add({type= "label", name="lblRangeMin", caption="Go to Refuel station below", style="st_label"})
    tbl.add({type= "textfield",name="refuelRangeMin", style="st_textfield_small"})
    tbl.add({type= "label", name="lblRangeMax", caption="coal, leave above", style="st_label"})
    local r = tbl.add({type="flow", name="row1", direction="horizontal"})
    r.add({type= "textfield", name="refuelRangeMax", style="st_textfield_small"})
    r.add({type= "label", name="lblRangeEnd", caption="coal", style="st_label"})
    tbl.add({type= "label", caption=""})

    tbl.add({type= "label", name="lblRefuelTime", caption="max. refuel time:", style="st_label"})
    tbl.add({type="textfield", name="refuelTime", style="st_textfield_small"})
    tbl.add({type= "label", name="lblRefuelStation", caption="Refuel station:", style="st_label"})
    tbl.add({type= "textfield", name="refuelStation", style="st_textfield"})
    tbl.add({type= "label", caption=""})

    tbl.add({type= "label", caption="Min. waiting time", style="st_label"})
    tbl.add({type= "textfield", name="minWait", style="st_textfield_small"})
    tbl.add({type= "label", caption="Interval for autodepart", style="st_label"})
    tbl.add({type= "textfield", name="departInterval", style="st_textfield_small"})
    tbl.add({type= "label", caption=""})
    
    tbl.add({type="label", name="lblTrackedTrains", caption = "Tracked trains: "..#glob.trains, style="st_label"})
    tbl.add({type= "label", caption=""})
    tbl.add({type= "label", caption=""})
    tbl.add({type= "button", name="refuelSave", caption="Ok", style="st_button"})
    
    tbl.refuelRangeMin.text = glob.settings.refuel.rangeMin
    tbl.row1.refuelRangeMax.text = glob.settings.refuel.rangeMax
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
    if player.gui.left.stGui.stSettings.stGlobalSettings == nil then
      globalSettingsWindow(index)
      destroyGui(player.gui.left.stGui.stSettings.toggleSTSettings)
    else
      player.gui.left.stGui.stSettings.toggleSTSettings.destroy()
    end
  elseif element.name == "refuelSave" then
    local settings = player.gui.left.stGui.stSettings.stGlobalSettings.tbl
    local time, min, max, station = tonumber(settings.refuelTime.text)*60, tonumber(settings.refuelRangeMin.text), tonumber(settings.row1.refuelRangeMax.text), settings.refuelStation.text
    glob.settings.refuel = {time=time, rangeMin = min, rangeMax = max, station = station}
    local interval, minWait = tonumber(settings.departInterval.text)*60, tonumber(settings.minWait.text)*60
    glob.settings.depart = {interval = interval, minWait = minWait}
    glob.settings.depart.minFlow = defaultSettings.depart.minFlow
    player.gui.left.stGui.stSettings.stGlobalSettings.destroy()
    showSettingsButton(index)
  else
    local option1, option2, option3 = event.element.name:match("(%a+)__(%d*)_*(%d*)")
    option1 = option1 or ""
    option2 = option2 or ""
    option3 = option3 or ""
    debugLog("o1: "..option1.." o2: "..option2.." o3: "..option3,true)
    
    if option1 == "refuel" then
      option2 = tonumber(option2)
      glob.trains[option2].settings.autoRefuel = not glob.trains[option2].settings.autoRefuel
    elseif option1 == "depart" then
      option2 = tonumber(option2)
      glob.trains[option2].settings.autoDepart = not glob.trains[option2].settings.autoDepart
    elseif option1 == "filter" then
      debugLog(serpent.dump(event.element),true)
      option2 = tonumber(option2)
      local item = "iron-plate"
      if player.cursorstack then item = player.cursorstack.name end 
      glob.filter = item or glob.filter
      game.players[index].gui.left.stGui.trainSettings.tbl["filter__"..option2].style = "tm-icon-"..glob.filter
      --showTrainInfoWindow(index,option2)
    elseif option1 == "togglefilter" then
      if element.caption == ">" then
        element.caption = "<"
        glob.filterbool = "lesser" 
      else 
        element.caption = ">"
        glob.filterbool = "greater"
      end
      debugLog(glob.filterbool, true)
      option2 = tonumber(option2)
      --showTrainInfoWindow(index,option2)
    elseif option1 == "toggleedit" then
      option2 = tonumber(option2)
      option3 = tonumber(option3)
      updateLineEdit(index,option2,option3)
    elseif option1 == "readSchedule" then
      option2 = tonumber(option2)
      local name = player.gui.left.stGui.lineSettings.btns.lineName.text
      showLinesWindow(index, option2, name)
    elseif option1 == "saveSchedule" then
      local name = player.gui.left.stGui.lineSettings.btns.lineName.text
      if name ~= "" then
        option2 = tonumber(option2)
        local t = glob.trains[option2]
        glob.trainLines[name] = t.train.schedule.records
        t.line = name
        showLinesWindow(index, option2, name)
      end       
    elseif option1 == "loadSchedule" then
      local name = player.gui.left.stGui.lineSettings.btns.lineName.text
      if name ~= "" and glob.trainLines[name] then
        option2 = tonumber(option2)
        local t = glob.trains[option2]
        local schedule = t.train.schedule 
        schedule.records = glob.trainLines[name]
        t.train.schedule = schedule
        t.line = name
        showLinesWindow(index, option2, name)
      end
    end
  end
end

function onplayercreated(event)
  local player = game.getplayer(event.playerindex)
  local gui = player.gui
  if gui.left.stGui == nil then
    buildGUI(player)
  end
end

function oninit() initGlob() end

function onload()
  initGlob()
  --printToFile(util.formattime(game.tick).." onload", "onload")
  local rem, remWaiting = removeInvalidTrains()
  if rem > 0 or remWaiting > 0 then debugLog("You should never see this! Removed "..rem.." invalid trains and "..remWaiting.." waiting trains") end
end

function initGlob()
  if glob.version == nil or glob.version < "0.1.0" then
    glob.trains = nil
    glob.waitingTrains = nil
    glob.refuelTrains = nil
    glob.trainLines = nil
    glob.settings = nil
    for i,p in ipairs(game.players) do
        destroyGui(p.gui.left.stGui)
        destroyGui(p.gui.center.stGui)
        destroyGui(p.gui.top.stButtons)
    end
    glob.guiDone = nil
    glob.version = "0.1.0"
  end
  glob.filter = glob.filter or "iron-plate"
  glob.filterbool = glob.filterbool or "<"
  glob.waitingTrains = glob.waitingTrains or {}
  glob.trains = glob.trains or {}
  glob.refuelTrains = glob.refuelTrains or {}
  glob.trainLines = glob.trainLines or {}
  glob.settings = glob.settings or defaultSettings
  glob.guiDone = glob.guiDone or {}
  if glob.version < "0.1.2" then
    glob.settings.depart.minFlow = glob.settings.depart.minFlow or defaultSettings.depart.minFlow
    for i,t in ipairs(glob.trains) do
      t.dynamic = t.dynamic or false
      t.line = t.line or false
    end    
  end
  for i,p in ipairs(game.players) do
    if not glob.guiDone[p.name] then
      buildGUI(p)
      glob.guiDone[p.name] = true
    end
  end
  glob.version = MOD.version
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
      local newTrainInfo = {dynamic = false, line = false}
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
  local remWaiting = 0
  for i,t in ipairs(glob.trains) do
    if not t.train.valid then
      table.remove(glob.trains, i)
      removed = removed + 1
    end
  end
  for i,t in ipairs(glob.waitingTrains) do
    if not t.train.valid or (t.arrived == false and t.lastCheck == nil) then
      table.remove(glob.waitingTrains, i)
      remWaiting = remWaiting + 1
    end
  end
  for i,t in ipairs(glob.refuelTrains) do
    if not t.train.valid or (t.arrived == false and t.lastCheck == nil) then
      table.remove(glob.refuelTrains, i)
    end
  end
  return removed, remWaiting
end

function inSchedule(station, schedule)
  for i, rec in ipairs(schedule.records) do
    if rec.station == station then
      return i
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
  --flyingText(getKeyByValue(defines.trainstate, train.state), YELLOW, train.carriages[1].position)
  if train.state == defines.trainstate["waitstation"] then
    if settings.autoRefuel then
      if fuel >= (glob.settings.refuel.rangeMax * fuelvalue("coal")) and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
        if inSchedule(glob.settings.refuel.station, schedule) and #schedule.records >= 3 then
          train.schedule = removeStation(glob.settings.refuel.station, schedule)
        end
      end
      if schedule.records[schedule.current].station == glob.settings.refuel.station then
        table.insert(glob.refuelTrains, {train = train, arrived = game.tick})
        flyingText("refueling", YELLOW, train.carriages[1].position)
      end
    end
    if settings.autoDepart and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
      table.insert(glob.waitingTrains, {train = train, cargo = cargoCount(train), arrived = game.tick, wait = train.schedule.records[train.schedule.current].time_to_wait, station = train.schedule.current, settings=settings})
      flyingText("waiting", YELLOW, train.carriages[1].position)
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
  if settings.autoRefuel and #glob.refuelTrains > 0 and (train.state == defines.trainstate["onthepath"] or train.state == defines.trainstate["manualcontrol"]) then
    local found = getKeyByTrain(glob.refuelTrains, train)
    if found then
      if train.state == defines.trainstate["onthepath"] then
        local t = glob.refuelTrains[found]
        local schedule = train.schedule
-- Try: train.schedule = t.origSchedule
        local station = inSchedule(glob.settings.refuel.station, schedule)
        schedule.records[station].time_to_wait = glob.settings.refuel.time
        train.schedule = schedule
        table.remove(glob.refuelTrains, found)
      elseif train.state == defines.trainstate["manualcontrol"] then
        table.remove(glob.refuelTrains, found)
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
-- Try: train.schedule = t.origSchedule
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

function cargoCompare(c1, c2, minFlow, interval)
  local oil1, oil2 = false, false
  local flow = 0
  if c1["crude-oil"] ~= nil or c2["crude-oil"] ~= nil then
    oil1 = c1["crude-oil"] or 0
    oil2 = c2["crude-oil"] or 0
    flow = (oil1 - oil2)/(interval/60)
    c1["crude-oil"] = nil
    c2["crude-oil"] = nil
  end
  local eq = table.compare(c1, c2)
  if oil1 ~= false and oil1 > 0 then c1["crude-oil"] = oil1 end
  if oil2 ~= false and oil2 > 0 then c2["crude-oil"] = oil2 end
  --debugLog(util.formattime(game.tick).." flow: "..flow.." i:"..interval, true)
  return (eq and math.abs(flow) < minFlow)  
end

function ontick(event)
  if #glob.refuelTrains > 0 then
    for i,t in ipairs(glob.refuelTrains) do
      local wait = t.arrived + glob.settings.depart.interval
      if event.tick >= wait then
        if lowestFuel(t.train) >= glob.settings.refuel.rangeMax * fuelvalue("coal") then
          flyingText("Refueling done", YELLOW, t.train.carriages[1].position)
          nextStation(t.train)
        end
      end 
    end
  end
  if #glob.waitingTrains > 0 then
    for i,t in ipairs(glob.waitingTrains) do
      local wait = (type(t.arrived) == "number") and t.arrived + glob.settings.depart.minWait or t.lastCheck + glob.settings.depart.interval
      --debugLog("depart: "..serpent.dump({t.settings.autoDepart, event.tick >= wait}),true)
      if t.settings.autoDepart and event.tick >= wait then
        local cargo = cargoCount(t.train)
        local last = t.arrived or t.lastCheck
        --debugLog(serpent.dump({cargo, t.cargo}), true)
        --debugLog(serpent.dump(tableCompare(cargo, t.cargo)),true)
--        local flow = false
--        if cargo["crude-oil"] ~= nil or t.cargo["crude-oil"] ~= nil then
--          cargo["crude-oil"] = cargo["crude-oil"] or 0
--          t.cargo["crude-oil"] = t.cargo["crude-oil"] or 0
--          flow = (cargo["crude-oil"] - t.cargo["crude-oil"])/((event.tick - last)/60)
--          local data = util.formattime(event.tick).." oil flow/s: "..flow
--          debugLog(data, true)
--        end
        if cargoCompare(cargo, t.cargo, glob.settings.depart.minFlow, event.tick - last) then
          flyingText("cargoCompare -> leave station", YELLOW, t.train.carriages[1].position)
          nextStation(t.train)
          t.lastCheck = false
          t.arrived = false
        else
          flyingText("cargoCompare -> stay at station", YELLOW, t.train.carriages[1].position)
          t.lastCheck = event.tick
          t.arrived = false          
          t.cargo = cargo
        end
      elseif not t.settings.autoDepart then
        table.remove(glob.waitingTrains, i)
      end
    end
  end
  if event.tick%10==9  then
    for pi, player in ipairs(game.players) do
      if player.opened ~= nil and player.opened.valid then
        if player.opened.type == "locomotive" and player.opened.train ~= nil then
          local key = getKeyByTrain(glob.trains, player.opened.train)
          if not key then
            table.insert(glob.trains, getNewTrainInfo(player.opened.train))
            key = getKeyByTrain(glob.trains, player.opened.train)
          elseif player.gui.left.stGui.trainSettings == nil then
            showTrainInfoWindow(pi, key)
            showSettingsButton(pi)
          end
        elseif player.opened.type == "train-stop" and player.gui.left.stGui.stSettings.toggleSTSettings == nil and player.gui.left.stGui.stSettings.stGlobalSettings == nil then
            showSettingsButton(pi)
        end 
      elseif player.opened == nil then --and glob.opened[pi] ~= nil then
            destroyGui(player.gui.left.stGui.stSettings.toggleSTSettings)
            destroyGui(player.gui.left.stGui.stSettings.stGlobalSettings)
            destroyGui(player.gui.left.stGui.trainSettings)
            destroyGui(player.gui.left.stGui.lineSettings)
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

function flyingText(line, colour, pos)
  pos = pos or game.player.position
  colour = colour or RED
  game.createentity({name="flying-text", position=pos, text=line, color=colour})
end

function printToFile(line, path)
  path = path or "log"
  path = table.concat({ "st", "/", path, ".txt" })
  debugLog(line, true)
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
    end,
    
    resetTrains = function()
      glob.trains = {}
      glob.waitingTrains = {}
    end
  }
)
