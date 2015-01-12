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