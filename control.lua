require "defines"
require "util"

function onload()
  --glob.version = nil --uncomment this line for a hard reset (all SmartTrain settings will be lost)
  initGlob()
  local rem = removeInvalidTrains()
  if rem > 0 then debugDump("You should never see this! Removed "..rem.." invalid trains") end
end

local defaultTrainSettings = {autoRefuel = true, autoDepart = true}
local defaultSettings =
  { refuel={station="Refuel", rangeMin = 25, rangeMax = 50, time = 300},
    depart={minWait = 240, interval = 120, minFlow = 1}}
local fluids ={["crude-oil"] = true, water=true, ["heavy-oil"]=true, ["light-oil"]=true, ["petroleum-gas"]=true,lubricant=true,["sulfuric-acid"]=true}
showFlyingText = false

MOD = {version="0.1.6"}
local tmpPos = {}
local RED = {r = 0.9}
local GREEN = {g = 0.7}
local YELLOW = {r = 0.8, g = 0.8}

function buildGUI(player)
  destroyGui(player.gui.left.stGui)
  local stGui = player.gui.left.add({type="frame", name="stGui", direction="vertical", style="outer_frame_style"})
  stGui.add({type="flow", name="stSettings", direction="vertical"})
end

function destroyGui(guiA)
  if guiA ~= nil and guiA.valid then
    guiA.destroy()
  end
end

function showSettingsButton(index, parent)
  local gui = parent or game.players[index].gui.left.stGui.stSettings
  if gui.toggleSTSettings ~= nil then
    gui.toggleSTSettings.destroy()
  end
  gui.add({type="button", name="toggleSTSettings", caption = "ST-Settings", style="st_button"})
end

function showTrainInfoWindow(index, trainKey, stationEdit)
  local gui = game.players[index].gui.left.stGui
  if gui.trainSettings ~= nil then
    gui.trainSettings.destroy()
  end
  if glob.trains[trainKey] and glob.trains[trainKey].train.valid then
    local t = glob.trains[trainKey]
    gui = gui.add({type="frame", name="trainSettings", caption="Train: "..t.name, direction="vertical", style="st_frame"})
    local line = "-"
    local dated = " "
    if t.line and glob.trainLines[t.line] then
      line = glob.trainLines[t.line].name
      if glob.trainLines[t.line].changed ~= t.lineVersion then dated = " (outdated)" end
    end
    local trainGui = gui.add({type="frame", name="tbl", direction="horizontal", style="st_inner_frame"})
    trainGui.add({type="label", caption="Refuel", style="st_label"})
    trainGui.add({type="checkbox", name="btn_refuel__"..trainKey, state=t.settings.autoRefuel})
    trainGui.add({type="label", caption="Depart", style="st_label"})
    trainGui.add({type="checkbox", name="btn_depart__"..trainKey, state=t.settings.autoDepart})
    local fl = gui.add({type="frame", direction="horizontal", style="st_inner_frame"})
    fl.add({type="label", caption="Active line: "..line})
    fl.add({type="label", caption=" "..dated})
    local lineKey = t.line
    local line = ""
    local activeLine = ""
    local records = t.train.schedule.records
    if glob.trainLines[lineKey] then
      line = glob.trainLines[lineKey].name
      if lineKey and t.line == lineKey then
        activeLine = glob.trainLines[lineKey].name
        records = glob.trainLines[lineKey].records
      end
    end
    if lineKey then
      lineKey = "__"..lineKey
    else
      lineKey = ""
    end
    local tbl = gui.add({type="frame", name="tbl1", direction="vertical", style="st_inner_frame"})
    tbl = tbl.add({type="table", name="tbl1", colspan=3})
    if #records > 0 then
      tbl.add({type="label", caption="Station", style="st_label"})
      tbl.add({type="label", caption="Time", style="st_label"})
      --      tbl.add({type="label", caption="Dynamic", style="st_label"})
      --      tbl.add({type="label", caption="Edit", style="st_label"})
      tbl.add({type="label", caption=""})
      --      tbl.add({type="label", caption=""})
      for i, s in ipairs(records) do
        local state = (i == stationEdit)
        local stationO = ""
        if stationEdit then stationO = "__"..stationEdit end
        tbl.add({type="label", caption=s.station, style="st_label"})
        tbl.add({type="label", caption=s.time_to_wait/60, style="st_label"})
        -- tbl.add({type="checkbox", name="togglecon__"..i, state=false})
        -- tbl.add({type="checkbox", name="toggleedit__"..trainKey.."__"..i..lineKey, state = state, style="st_checkbox"})
        tbl.add({type="label", caption=""})
      end
    end
    local btns = gui.add({type="frame", name="btns", direction="horizontal", style="st_inner_frame"})
    btns.add({type="button", name="readSchedule__"..trainKey..lineKey, caption="Read from UI", style="st_button"})
    btns.add({type="label", caption=""})
    local btns = gui.add({type="frame", name="btns2", direction="horizontal", style="st_inner_frame"})
    btns.add({type="button", name="saveAsLine__"..trainKey..lineKey, caption="Save as line ", style="st_button"})
    btns.add({type="textfield", name="saveAslineName", text="", style="st_textfield_big"})
  end
end

--function showScheduleWindow(index, trainKey, stationEdit, parent)
--  local gui = parent or game.players[index].gui.left.stGui
--  if glob.trains[trainKey] and glob.trains[trainKey].train.valid then
--    local t = glob.trains[trainKey]
--    local lineKey = t.line
--    if not parent and gui.scheduleSettings ~= nil then
--      gui.scheduleSettings.destroy()
--    end
--    local line = ""
--    local activeLine = ""
--    local records = t.train.schedule.records
--    if glob.trainLines[lineKey] then
--      line = glob.trainLines[lineKey].name
--      if lineKey and t.line == lineKey then
--        activeLine = glob.trainLines[lineKey].name
--        records = glob.trainLines[lineKey].records
--      end
--    end
--    if lineKey then
--      lineKey = "__"..lineKey
--    else
--      lineKey = ""
--    end
--    local type = "frame"
--    if parent then type = "flow" end
--    gui = gui.add({type = type, name = "scheduleSettings", caption="Train schedule", direction="vertical", style="st_frame"})
--    local tbl = gui.add({type="table", name="tbl1", colspan=3})
--    if #records > 0 then
--      tbl.add({type="label", caption="Station", style="st_label"})
--      tbl.add({type="label", caption="Time", style="st_label"})
--      --      tbl.add({type="label", caption="Dynamic", style="st_label"})
--      --      tbl.add({type="label", caption="Edit", style="st_label"})
--      tbl.add({type="label", caption=""})
--      tbl.add({type="label", caption=""})
--      for i, s in ipairs(records) do
--        local state = (i == stationEdit)
--        local stationO = ""
--        if stationEdit then stationO = "__"..stationEdit end
--        tbl.add({type="label", caption=s.station, style="st_label"})
--        tbl.add({type="label", caption=s.time_to_wait/60, style="st_label"})
--        -- tbl.add({type="checkbox", name="togglecon__"..i, state=false})
--        -- tbl.add({type="checkbox", name="toggleedit__"..trainKey.."__"..i..lineKey, state = state, style="st_checkbox"})
--        tbl.add({type="label", caption=""})
--      end
--    end
--    local btns = gui.add({type="flow", name="btns", direction="vertical", style="st_flow"})
--    btns.add({type="button", name="readSchedule__"..trainKey..lineKey, caption="Read from UI", style="st_button"})
--    local btns = gui.add({type="flow", name="btns2", direction="horizontal", style="st_flow"})
--    btns.add({type="button", name="saveAsLine__"..trainKey..lineKey, caption="Save as line", style="st_button"})
--    btns.add({type="textfield", name="saveAslineName", text="", style="st_textfield_big"})
--  else
--    if gui.scheduleSettings ~= nil then
--      gui.scheduleSettings.destroy()
--    end
--  end
--end

function showTrainLinesWindow(index, trainKey, parent)
  local gui = parent or game.players[index].gui.left.stGui
  if gui.trainLines ~= nil then
    gui.trainLines.destroy()
  end
  if glob.trainLines then
    gui = gui.add({type="frame", name="trainLines", caption="Trainlines", direction="vertical", style="st_frame"})
    local t = glob.trains[trainKey]
    local tbl = gui.add({type="table", name="tbl1", colspan=5})
    tbl.add({type="label", caption="Line", style="st_label"})
    tbl.add({type="label", caption="1st station", style="st_label"})
    tbl.add({type="label", caption="#stations", style="st_label"})
    tbl.add({type="label", caption="Active"})
    tbl.add({type="label", caption="Delete"})
    local dirty = 0
    for i, l in pairsByKeys(glob.trainLines) do
      tbl.add({type="label", caption=l.name, style="st_label"})
      tbl.add({type="label", caption=l.records[1].station, style="st_label"})
      tbl.add({type="label", caption=#l.records, style="st_label"})
      tbl.add({type="checkbox", name="activeLine__"..i.."__"..trainKey, state=(i==t.line), style="st_checkbox"})
      tbl.add({type="checkbox", name="markedDelete__"..i.."__"..trainKey, state=false})
      dirty= dirty+1
    end
    local btns = gui.add({type="flow", name="btns", direction="horizontal"})
    btns.add({type="button", name="deleteLines", caption="Delete", style="st_button"})
    if dirty == 0 then gui.destroy() end
  end
end

--function showDynamicRules(index, line, stationKey, trainKey)
--  debugDump({i=index,line=line,station=stationKey, tr=trainKey}, true)
--  local lineName = false
--  local station = ""
--  if line and glob.trainLines[line] then
--    lineName = glob.trainLines[line].name
--  end
--  if lineName and stationKey then
--    station = glob.trainLines[line].records[stationKey].station
--  else
--    station = glob.trains[trainKey].train.schedule.records[stationKey].station
--  end
--  local gui = game.players[index].gui.left.stGui
--  if gui.dynamicRules ~= nil then
--    gui.dynamicRules.destroy()
--  end
--  lineName = lineName or "-"
--  gui = gui.add({type="frame", name="dynamicRules", direction="horizontal"})
--  gui.add({type="label", name="line", caption="Line: "..lineName, style="st_label"})
--  gui.add({type="label", name="station", caption="Station: "..station, style="st_label"})
--  gui.add({ type="button", name="filter__" ..trainKey, style="st-icon-iron-ore"})
--  gui.add({ type="button", name="test__" ..trainKey, style="st-icon-style"})
--  gui.add({type="button", name="togglefilter__"..trainKey, caption = "bool", style="st_button"})
--  gui.add({type="textfield", name="filteramount", style="st_textfield_small"})
--end

--function updateLineEdit(index, trainKey, stationKey, line)
--  local gui = game.players[index].gui.left.stGui
--  if gui.scheduleSettings ~= nil then
--    gui = gui.scheduleSettings.tbl1
--    local records = {}
--    if glob.trainLines[line] then
--      records = glob.trainLines[line].records
--      line = "__"..line
--    else
--      line = ""
--      records = glob.trains[trainKey].train.schedule.records
--    end
--    for i,s in ipairs(records) do
--      if i ~= stationKey then
--        gui["toggleedit__"..trainKey.."__"..i..line].state = (i==stationKey)
--      end
--    end
--  end
--end

function globalSettingsWindow(index, parent)
  local gui = parent or game.players[index].gui.left.stGui.stSettings
  if gui.stGlobalSettings == nil then
    gui.add({type = "frame", name="stGlobalSettings", direction="horizontal", caption="Global settings"})
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

    tbl.add({type= "label", caption="Min. flow rate", style="st_label"})
    tbl.add({type= "textfield", name="minFlow", style="st_textfield_small"})
    tbl.add({type="label", name="lblTrackedTrains", caption = "Tracked trains: "..#glob.trains, style="st_label"})
    tbl.add({type= "label", caption=""})
    tbl.add({type= "button", name="refuelSave", caption="Ok", style="st_button"})

    tbl.refuelRangeMin.text = glob.settings.refuel.rangeMin
    tbl.row1.refuelRangeMax.text = glob.settings.refuel.rangeMax
    tbl.refuelStation.text = glob.settings.refuel.station
    tbl.refuelTime.text = glob.settings.refuel.time / 60
    tbl.departInterval.text = glob.settings.depart.interval / 60
    tbl.minWait.text = glob.settings.depart.minWait / 60
    tbl.minFlow.text = glob.settings.depart.minFlow
  end
end

function onguiclick(event)
  local index = event.playerindex or event.name
  local player = game.players[index]
  local element = event.element
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
    local minFlow = tonumber(settings.minFlow.text)
    glob.settings.depart = {interval = interval, minWait = minWait}
    glob.settings.depart.minFlow = minFlow
    player.gui.left.stGui.stSettings.stGlobalSettings.destroy()
    showSettingsButton(index)
  elseif element.name == "deleteLines" then
    local group = game.players[index].gui.left.stGui.trainLines.tbl1
    local trainKey
    for i, child in pairs(group.childrennames) do
      --local pattern = "(%w+)__([%w%s]*)_*([%w%s]*)_*(%w*)"
      local pattern = "(markedDelete)__([%w%s]*)_*(%d*)"
      local del, line, trainkey = child:match(pattern)
      if del and group[child].state == true then
        trainKey = tonumber(trainkey)
        if glob.trains[trainKey].line == line then
          glob.trains[trainKey].line = false
        end
        glob.trainLines[line] = nil
      end
    end
    refreshUI(index, trainKey)
  else
    local option1, option2, option3, option4 = event.element.name:match("(%w+)__([%w%s]*)_*([%w%s]*)_*(%w*)")

    if option1 == "refuel" then
      option2 = tonumber(option2)
      glob.trains[option2].settings.autoRefuel = not glob.trains[option2].settings.autoRefuel
    elseif option1 == "depart" then
      option2 = tonumber(option2)
      glob.trains[option2].settings.autoDepart = not glob.trains[option2].settings.autoDepart
--    elseif option1 == "filter" then
--      option2 = tonumber(option2)
--      local item = "iron-plate"
--      if player.cursorstack then item = player.cursorstack.name end
--      glob.filter = item or glob.filter
--      --game.players[index].gui.left.stGui.trainSettings.tbl["filter__"..option2].style = "tm-icon-"..
--      --showTrainInfoWindow(index,option2)
--    elseif option1 == "togglefilter" then
--      if element.caption == ">" then
--        element.caption = "<"
--        glob.filterbool = "lesser"
--      else
--        element.caption = ">"
--        glob.filterbool = "greater"
--      end
--      --debugDump(glob.filterbool, true)
--      option2 = tonumber(option2)
--      --showTrainInfoWindow(index,option2)
--    elseif option1 == "toggleedit" then
--      option2 = tonumber(option2)
--      option3 = tonumber(option3)
--      do
--        local option1 = option1 or ""
--        local option2 = option2 or ""
--        local option3 = option3 or ""
--        local option4 = option4
--        debugDump("e: "..event.element.name.." o1: "..option1.." o2: "..option2.." o3: "..option3.." o4: "..option4,true)
--        debugDump({option4},true)
--      end
--      -- @TODO save changes
--      refreshUI(index, option2, option3, option4)
--      updateLineEdit(index,option2,option3, option4)
--      showDynamicRules(index, option4, option3, option2)
    elseif option1 == "readSchedule" then
      option2 = tonumber(option2)
      if glob.trains[option2] ~= nil and glob.trains[option2].train.valid then
        glob.trains[option2].line = false
        glob.trains[option2].lineVersion = false
      end
      refreshUI(index,option2)
    elseif option1 == "saveAsLine" then
      local name = player.gui.left.stGui.trainSettings.btns2.saveAslineName.text
      name = string.gsub(name, "_", " ")
      name = string.gsub(name, "^%s", "")
      name = string.gsub(name, "%s$", "")
      option2 = tonumber(option2)
      local t = glob.trains[option2]
      if name ~= "" and #t.train.schedule.records > 0 then
        local changed = game.tick
        if not glob.trainLines[name] then glob.trainLines[name] = {name=name} end
        glob.trainLines[name].records = t.train.schedule.records
        glob.trainLines[name].changed = changed
        local schedule = t.train.schedule
        schedule.records = glob.trainLines[name].records
        t.train.schedule = schedule
        t.line = name
        t.lineVersion = changed
        refreshUI(index,option2)
      end
    elseif option1 == "activeLine" then
      local trainKey = tonumber(option3)
      local li = option2
      local t = glob.trains[trainKey]
      if t.line ~= li then
        t.line = li
      else
        t.line = false
      end
      t.lineVersion = false
      refreshUI(index, trainKey)
    end
  end
end

function refreshUI(index, trainKey, stationEdit, line)
  trainKey = getTrainKeyFromUI(index)
  showTrainInfoWindow(index,trainKey, stationEdit)
  --showScheduleWindow(index, trainKey, stationEdit)
  --  if stationEdit then
  --    showDynamicRules(index, line, stationEdit, trainKey)
  --  else
  --    destroyGui(game.players[index].gui.left.stGui.dynamicRules)
  --  end
  showTrainLinesWindow(index,trainKey)
end

function getTrainKeyFromUI(index)
  local player = game.players[index]
  if player.opened.type == "locomotive" and player.opened.train ~= nil then
    local key = getKeyByTrain(glob.trains, player.opened.train)
    if not key then
      local ti = getNewTrainInfo(player.opened.train)
      table.insert(glob.trains, ti)
      key = getKeyByTrain(glob.trains, player.opened.train)
    end
    return key
  end
  return nil --should never happen
end

function onplayercreated(event)
  local player = game.getplayer(event.playerindex)
  local gui = player.gui
  if gui.left.stGui == nil then
    buildGUI(player)
  end
end

function oninit() initGlob() end

function initGlob()
  if glob.version == nil or glob.version < MOD.version then
    local v = glob.version or "Nil"
    saveGlob("PreInitv"..v)
  end
  if glob.version == nil or glob.version < "0.1.0" then
    local v = glob.version or "Nil"
    saveGlob("PreInitv"..v)
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
    saveGlob("Initv"..glob.version)
  end
  glob.waitingTrains = glob.waitingTrains or {}
  glob.trains = glob.trains or {}
  glob.refuelTrains = glob.refuelTrains or {}
  glob.trainLines = glob.trainLines or {}
  glob.settings = glob.settings or defaultSettings
  glob.guiDone = glob.guiDone or {}

  if glob.version < "0.1.5" then
    glob.init = nil
    glob.showFlyingText = showFlyingtext
    glob.settings.depart.minFlow = glob.settings.depart.minFlow or defaultSettings.depart.minFlow
    local tmpW = {}
    local tmpR = {}
    for i,t in pairs(glob.trains) do
      t.dynamic = t.dynamic or false
      t.line = t.line or false
      t.lineVersion = t.lineVersion or false
      local cpDepart, cpRefuel = t.settings.autoDepart, t.settings.autoRefuel
      t.settings = {autoDepart = cpDepart, autoRefuel = cpRefuel}
      for wi, wt in pairs(glob.waitingTrains) do
        if trainEquals(t.train,wt.train) then
          t.waiting = {cargo = wt.cargo, arrived = wt.arrived, lastCheck = wt.lastCheck}
          if t.waiting.cargo or t.waiting.arrived or t.waiting.lastCheck then
            table.insert(tmpW, t)
          else
            t.waiting = false
          end
        end
      end
      for ri,tr in pairs(glob.refuelTrains) do
        if trainEquals(t.train, tr.train) then
          t.refueling = {arrived = tr.arrived}
          if t.refueling.arrived then
            table.insert(tmpR, t)
          else
            t.refueling = false
          end
        end
      end
    end
    glob.waitingTrains = tmpW
    glob.refuelTrains = tmpR
    for i,t in pairs(glob.trains) do
      if not t.waiting then t.waiting = false end
      if not t.refueling then t.refueling = false end
    end
    for i,l in pairs(glob.trainLines) do
      if l.line then l.line=nil end
      l.changed = 0
    end
    glob.version = "0.1.5"
    saveGlob("Initv"..glob.version)
  end

  if glob.version < "0.1.7" then
    local tmp = {}
    for i,t in ipairs(glob.trains) do
      local tr = Train:new(t)
      table.insert(tmp, tr)
    end
    glob.trains = tmp
  end

  for i,p in ipairs(game.players) do
    if not glob.guiDone[p.name] then
      buildGUI(p)
      glob.guiDone[p.name] = true
    end
  end
  for _, object in pairs(glob.trains) do
    setmetatable(object, Train)
    assert(getmetatable(object)== Train)
  end
  if #glob.trains >=2 then
    assert(glob.trains[1] == glob.trains[1])
    assert(glob.trains[1] ~= glob.trains[2])
    assert(glob.trains[2] ~= glob.trains[1])
    assert(glob.trains[2] == glob.trains[2])
  end

  if glob.version < MOD.version then saveGlob("PostInit") end
  glob.version = MOD.version
end
game.oninit(function() oninit() end)
game.onload(function() onload() end)


Train = {}
function Train:new(train)
  local o = train or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

Train.__eq = function(trainA, trainB)
  return trainA.train.carriages[1].equals(trainB.train.carriages[1])
end

function Train:printName()
  debugDump(self.name, true)
end

function Train:nextStation()
  local train = self.train
  if train.manualmode == false then
    local schedule = train.schedule
    local tmp = (schedule.current % #schedule.records) + 1
    train.manualmode = true
    schedule.current = tmp
    train.schedule = schedule
    train.manualmode = false
  end
end

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
      local newTrainInfo = {dynamic = false, line = false, settings = {}, waiting = false, refueling = false}
      newTrainInfo.train = train
      if train.locomotives ~= nil and (#train.locomotives.frontmovers > 0 or #train.locomotives.backmovers > 0) then
        newTrainInfo.name = train.locomotives.frontmovers[1].backername or train.locomotives.backmovers[1].backername
        --newTrainInfo.name = string.gsub(newTrainInfo.name, "%.", "")
      else
        newTrainInfo.name = "cargoOnly"
      end
      newTrainInfo.settings = {autoDepart = defaultTrainSettings.autoDepart, autoRefuel = defaultTrainSettings.autoRefuel}
      newTrainInfo.lineVersion = 0
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
  --  for i,t in ipairs(glob.waitingTrains) do
  --    if not t.train.valid or (t.arrived == false and t.lastCheck == nil) then
  --      table.remove(glob.waitingTrains, i)
  --      remWaiting = remWaiting + 1
  --    end
  --  end
  --  for i,t in ipairs(glob.refuelTrains) do
  --    if not t.train.valid or (t.arrived == false and t.lastCheck == nil) then
  --      table.remove(glob.refuelTrains, i)
  --    end
  --  end
  return removed
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

--Only when in automatic mode and stoped!
function nextStation(train)
  if train.manualmode == false then
    local schedule = train.schedule
    local tmp = (schedule.current % #schedule.records) + 1
    train.manualmode = true
    schedule.current = tmp
    train.schedule = schedule
    train.manualmode = false
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
          if d.type ~= nil then
            sum[d.type] = sum[d.type] or 0
            sum[d.type] = sum[d.type] + d.amount
          end
        end
      end
    end
  end
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
    trainKey = getKeyByTrain(glob.trains, train)
  end
  local t = glob.trains[trainKey]
  t.state=getKeyByValue(defines.trainstate, train.state)
  local settings = glob.trains[trainKey].settings
  local fuel = lowestFuel(train)
  local schedule = train.schedule
  --flyingText(getKeyByValue(defines.trainstate, train.state), YELLOW, train.carriages[1].position, showFlyingText)
  if train.state == defines.trainstate["waitstation"] then
    if t.line and glob.trainLines[t.line] then
      if t.line and glob.trainLines[t.line].changed ~= t.lineVersion then
        local waitingAt = t.train.schedule.records[t.train.schedule.current]
        t.train.manualmode = true
        schedule = {records={}}
        local trainLine = glob.trainLines[t.line]
        for i, record in ipairs(trainLine.records) do
          schedule.records[i] = record
        end
        local inLine = inSchedule(waitingAt.station,schedule)
        if inLine then
          schedule.current = inLine
        else
          schedule.current = 1
        end
        t.train.schedule = schedule
        t.train.manualmode = false
        t.lineVersion = trainLine.changed
        flyingText("updating schedule", YELLOW, train.carriages[1].position, glob.showFlyingText)
      end
    elseif t.line and not glob.trainLines[t.line] then
      flyingText("Dettached from line", RED, train.carriages[1].position, glob.showFlyingText)
      t.line = false
      t.lineVersion = false
    end
  end
  if train.state == defines.trainstate["waitstation"] then
    if settings.autoRefuel then
      if fuel >= (glob.settings.refuel.rangeMax * fuelvalue("coal")) and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
        if inSchedule(glob.settings.refuel.station, schedule) and #schedule.records >= 3 then
          train.schedule = removeStation(glob.settings.refuel.station, schedule)
        end
      end
      if schedule.records[schedule.current].station == glob.settings.refuel.station then
        --table.insert(glob.refuelTrains, {train = train, arrived = game.tick})
        t.refueling = {arrived = game.tick}
        table.insert(glob.refuelTrains, t)
        flyingText("refueling", YELLOW, train.carriages[1].position, glob.showFlyingText)
      end
    end
    if settings.autoDepart and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
      --table.insert(glob.waitingTrains, {train = train, cargo = cargoCount(train), arrived = game.tick, settings=settings})
      t.waiting = {cargo = cargoCount(train), arrived = game.tick, lastCheck = false}
      table.insert(glob.waitingTrains, t)
    end
  elseif train.state == defines.trainstate["arrivestation"]  or train.state == defines.trainstate["waitsignal"] or train.state == defines.trainstate["arrivesignal"] or train.state == defines.trainstate["onthepath"] then
    if settings.autoRefuel then
      if fuel < (glob.settings.refuel.rangeMin * fuelvalue("coal")) and not inSchedule(glob.settings.refuel.station, schedule) then
        train.schedule = addStation(glob.settings.refuel.station, schedule, glob.settings.refuel.time)
      end
    end
  end
  if settings.autoRefuel and t.refueling and (train.state == defines.trainstate["onthepath"] or train.state == defines.trainstate["pathlost"] or train.state == defines.trainstate["nopath"]) then
    t.refueling = false
  end
  if settings.autoDepart and t.waiting and (train.state == defines.trainstate["onthepath"] or train.state == defines.trainstate["pathlost"] or train.state == defines.trainstate["nopath"]) then
    t.waiting = false
  end
end

function cargoCompare(c1, c2, minFlow, interval)
  local liquids1 = {}
  local liquids2 = {}
  local goodflow = false
  for l,_ in pairs(fluids) do
    liquids1[l], liquids2[l] = false, false
    if c1[l] ~= nil or c2[l] ~= nil then
      liquids1[l] = c1[l] or 0
      liquids2[l] = c2[l] or 0
      local flow = (liquids1[l] - liquids2[l])/(interval/60)
      if math.abs(flow) >= minFlow then goodflow = true end
      c1[l] = nil
      c2[l] = nil
    end
  end
  local eq = table.compare(c1, c2)
  for l,_ in pairs(fluids) do
    if liquids1[l] ~= false and liquids1[l] > 0 then c1[l] = liquids1[l] end
    if liquids2[l] ~= false and liquids2[l] > 0 then c2[l] = liquids2[l] end
  end
  return (eq and not goodflow)
end

function ontick(event)
  if #glob.refuelTrains > 0 then
    for i,t in pairs(glob.refuelTrains) do
      if type(t.refueling) == "table" and t.settings.autoRefuel then
        local wait = t.refueling.arrived + glob.settings.depart.interval
        if event.tick >= wait then
          if lowestFuel(t.train) >= glob.settings.refuel.rangeMax * fuelvalue("coal") then
            flyingText("Refueling done", YELLOW, t.train.carriages[1].position, glob.showFlyingText)
            glob.refuelTrains[i] = nil
            --nextStation(t.train)
            t:nextStation()
          end
        end
      else
        glob.refuelTrains[i] = nil
      end
    end
  end
  if #glob.waitingTrains > 0 then
    for i,t in pairs(glob.waitingTrains) do
      if type(t.waiting) == "table" and t.settings.autoDepart then
        local wait = (type(t.waiting.arrived) == "number") and t.waiting.arrived + glob.settings.depart.minWait or t.waiting.lastCheck + glob.settings.depart.interval
        if event.tick >= wait then
          local cargo = cargoCount(t.train)
          local last = t.waiting.arrived or t.waiting.lastCheck
          if cargoCompare(cargo, t.waiting.cargo, glob.settings.depart.minFlow, event.tick - last) then
            flyingText("cargoCompare -> leave station", YELLOW, t.train.carriages[1].position, glob.showFlyingText)
            --nextStation(t.train)
            t:nextStation()
            glob.waitingTrains[i] = nil
          else
            flyingText("cargoCompare -> stay at station", YELLOW, t.train.carriages[1].position, glob.showFlyingText)
            t.waiting.lastCheck = event.tick
            t.waiting.arrived = false
            t.waiting.cargo = cargo
          end
        elseif not t.settings.autoDepart then
          glob.waitingTrains[i] = nil
        end
      else
        glob.waitingTrains[i] = nil
      end
    end
  end
  if event.tick%10==9  then
    for pi, player in ipairs(game.players) do
      if player.opened ~= nil and player.opened.valid then
        if player.opened.type == "locomotive" and player.opened.train ~= nil then
          local key = getTrainKeyFromUI(pi)
          if player.gui.left.stGui.trainSettings == nil then
            refreshUI(pi)
            showSettingsButton(pi)
          end
        elseif player.opened.type == "train-stop" and player.gui.left.stGui.stSettings.toggleSTSettings == nil and player.gui.left.stGui.stSettings.stGlobalSettings == nil then
          showSettingsButton(pi)
        end
      elseif player.opened == nil then
        local gui=player.gui.left.stGui
        if gui.stSettings ~= nil then
          destroyGui(player.gui.left.stGui.stSettings.toggleSTSettings)
          destroyGui(player.gui.left.stGui.stSettings.stGlobalSettings)
        end
        if gui ~= nil then
          destroyGui(player.gui.left.stGui.trainSettings)
          --destroyGui(player.gui.left.stGui.scheduleSettings)
          --destroyGui(player.gui.left.stGui.dynamicRules)
          destroyGui(player.gui.left.stGui.trainLines)
        end
      end
    end
  end
end

function getTrainKeyFromUI(index)
  local player = game.players[index]
  local key
  if player.opened ~= nil and player.opened.valid then
    if player.opened.type == "locomotive" and player.opened.train ~= nil then
      key = getKeyByTrain(glob.trains, player.opened.train)
      if not key then
        local ti = getNewTrainInfo(player.opened.train)
        table.insert(glob.trains, ti)
        key = getKeyByTrain(glob.trains, player.opened.train)
      end
    end
    return key
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

function scheduleToString(schedule)
  local tmp = "Schedule: "
  for i=1,#schedule.records do
    tmp = tmp.." "..schedule.records[i].station.."|"..schedule.records[i].time_to_wait/60
  end
  return tmp.." next: "..schedule.current
end

function debugDump(var, force)
  if false or force then
    for i,player in ipairs(game.players) do
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
  if show then
    pos = pos or game.player.position
    color = color or RED
    game.createentity({name="flying-text", position=pos, text=line, color=color})
  end
end

function printToFile(line, path)
  path = path or "log"
  path = table.concat({ "st", "/", path, ".lua" })
  game.makefile( path,  line)
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
  return a.name > b.name
end

function findAllEntitiesByType(type)
  local entities = {}
  for coord in game.getchunks() do
    local X,Y = coord.x, coord.y
    if game.ischunkgenerated{X,Y} then
      local area = {{X*32, Y*32}, {X*32 + 32, Y*32 + 32}}
      for i, entity in ipairs(game.findentitiesfiltered{area = area, type = type}) do
        local key = entity.position.x.."A"..entity.position.y
        local name = entity.backername or entity.name
        local train = entity.train or false
        entities[key] = {name= name, pos = entity.position, train=train}
      end
    end
  end
  return entities
end

function saveGlob(name)
  local n = name or ""
  game.makefile("st/debugGlob"..n..".lua", serpent.block(glob, {name="glob"}))
  --game.makefile("st/loco"..n..".lua", serpent.block(findAllEntitiesByType("locomotive")))
end

remote.addinterface("st",
  {
    printGlob = function(name)
      if name then
        debugDump(glob[name], true)
      else
        debugDump(glob, true)
      end
    end,

    printFile = function(var, name)
      local name = name or "log"
      if glob[var] then
        printToFile(serpent.block(glob[var]), name )
      else
        debugDump("glob["..var.."] not found.")
      end
    end,

    saveGlob = function(name)
      saveGlob(name)
    end,

    hardReset = function(confirm)
      if confirm then
        glob.version = nil
        initGlob()
      end
    end,

    toggleFlyingText = function()
      glob.showFlyingText = not glob.showFlyingText
      debugDump("Flying text: "..tostring(glob.showFlyingText),true)
    end,

    nilGlob = function(key)
      if glob[key] then glob[key] = nil end
    end,

    cleanGui = function()
      for i,player in ipairs(game.players) do
        if player.gui.top.blueprintTools then
          player.gui.top.blueprintTools.destroy()
        end
      end
    end,
    
    printMeta = function()
      local metas = {}
      for i,to in pairs(glob.trains) do
        table.insert(metas, getmetatable(to))
      end
      printToFile(serpent.block(metas, {name="metas"}), "metatables" )
    end,

  --    findStations = function()
  --      local stations = {}
  --      for coord in game.getchunks() do
  --        local X,Y = coord.x, coord.y
  --        if game.ischunkgenerated{X,Y} then
  --          local area = {{X*32, Y*32}, {X*32 + 32, Y*32 + 32}}
  --          for _, entity in ipairs(game.findentitiesfiltered{area = area, type = "train-stop"}) do
  --            local key = entity.position.x.."A"..entity.position.y
  --            key = string.gsub(key, "-", "_")
  --            stations[key] = {entity.backername, entity.position}
  --          end
  --        end
  --      end
  --      printToFile(serpent.block(stations),"stations")
  --    end
  }
)
