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

function showTrainInfoWindow(index, trainKey)
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
    local rules = {}
    if glob.trainLines[lineKey] then
      line = glob.trainLines[lineKey].name
      if lineKey and t.line == lineKey then
        activeLine = glob.trainLines[lineKey].name
        records = glob.trainLines[lineKey].records
        rules = glob.trainLines[lineKey].rules or {}
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
      if line ~= "" and #rules > 0 then
        tbl.add({type="label", caption="Rules", style="st_label"})
      else
        tbl.add({type="label", caption=""})
      end
      for i, s in ipairs(records) do
        tbl.add({type="label", caption=s.station, style="st_label"})
        tbl.add({type="label", caption=s.time_to_wait/60, style="st_label"})
        -- tbl.add({type="checkbox", name="togglecon__"..i, state=false})
        if line ~= "" and rules[i] then
          local fl = tbl.add({type="flow", name ="fl"..i, direction="horizontal"})
          fl.add({type="checkbox", state=false, style="st-icon-"..rules[i].filter})
          fl.add({type="label", caption=" "..rules[i].condition.." "..rules[i].count, style="st_label"})
        else
          tbl.add({type="label", caption=""})
        end
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

function showTrainLinesWindow(index, trainKey, parent)
  local gui = parent or game.players[index].gui.left.stGui
  if gui.trainLines ~= nil then
    gui.trainLines.destroy()
  end
  if glob.trainLines then
    gui = gui.add({type="frame", name="trainLines", caption="Trainlines", direction="vertical", style="st_frame"})
    local t = glob.trains[trainKey]
    local tbl = gui.add({type="table", name="tbl1", colspan=6})
    tbl.add({type="label", caption="Line", style="st_label"})
    tbl.add({type="label", caption="1st station", style="st_label"})
    tbl.add({type="label", caption="#stations", style="st_label"})
    tbl.add({type="label", caption="Active", style="st_label"})
    tbl.add({type="label", caption="Delete", style="st_label"})
    tbl.add({type="label", caption=""})
    local dirty = 0
    for i, l in pairsByKeys(glob.trainLines) do
      tbl.add({type="label", caption=l.name, style="st_label"})
      tbl.add({type="label", caption=l.records[1].station, style="st_label"})
      tbl.add({type="label", caption=#l.records, style="st_label"})
      tbl.add({type="checkbox", name="activeLine__"..i.."__"..trainKey, state=(i==t.line), style="st_checkbox"})
      tbl.add({type="checkbox", name="markedDelete__"..i.."__"..trainKey, state=false})
      tbl.add({type="button", name="editRules__"..i, caption="Rules", style="st_button"})
      dirty= dirty+1
    end
    local btns = gui.add({type="flow", name="btns", direction="horizontal"})
    btns.add({type="button", name="deleteLines", caption="Delete", style="st_button"})
    if dirty == 0 then gui.destroy() end
  end
end

function showDynamicRules(index, line)
  --debugDump({i=index,line=line,station=stationKey, tr=trainKey}, true)
  local gui = game.players[index].gui.left.stGui
  if gui.dynamicRules ~= nil then
    gui.dynamicRules.destroy()
  end
  if line and glob.trainLines[line] then
    local lineName = glob.trainLines[line].name
    local records = glob.trainLines[line].records
    local rules = glob.trainLines[line].rules or {}
    gui = gui.add({type="frame", name="dynamicRules", direction="vertical", style="st_frame"})
    gui = gui.add({type="frame", name="frm", direction="vertical", style="st_inner_frame"})
    gui.add({type="label", name="line", caption="Line: "..lineName, style="st_label"})
    local tbl = gui.add({type="table", name="tbl", colspan=4, style="st_table"})
    tbl.add({type="label", caption="Station", style="st_label"})
    tbl.add({type="label", caption="Filter", style="st_label"})
    tbl.add({type="label", caption=""})
    tbl.add({type="label", caption=""})
    glob.guiData[index].rules = glob.guiData[index].rules or {}
    for i,s in ipairs(records) do
      local filter = "style"
      local condition = ">"
      local count = "1"
      if rules[i] then
        filter, condition, count = rules[i].filter, rules[i].condition, rules[i].count
        glob.guiData[index].rules[i] = filter
      end
      tbl.add({type="label", caption=i.." "..s.station, style="st_label"})
      tbl.add({type="checkbox", name="filterItem__"..i, style="st-icon-"..filter, state=false})
      tbl.add({type="button", name="togglefilter__"..i, caption = condition, style="circuit_condition_sign_button_style"})
      tbl.add({type="textfield", name="filteramount__"..i, style="st_textfield_small"})
      if count ~= "" then
        tbl["filteramount__"..i].text = count
      end
    end
    gui.add({type="button", name="saveRules__"..line, caption="Save", style="st_button"})
    gui.add({type="button", name="getLiquidItems", caption="Liquid items", style="st_button"})
  end
end

function updateLineEdit(index, trainKey, stationKey, line)
  local gui = game.players[index].gui.left.stGui
  if gui.scheduleSettings ~= nil then
    gui = gui.scheduleSettings.tbl1
    local records = {}
    if glob.trainLines[line] then
      records = glob.trainLines[line].records
      line = "__"..line
    else
      line = ""
      records = glob.trains[trainKey].train.schedule.records
    end
    for i,s in ipairs(records) do
      --if i ~= stationKey then
        gui["toggleedit__"..trainKey.."__"..i..line].state = (i==stationKey)
      --else
        --gui["toggleedit__"..trainKey.."__"..i..line].state = not gui["toggleedit__"..trainKey.."__"..i..line].state
      --end
    end
  end
end

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
  if not glob.guiData[index] then glob.guiData[index] = {} end
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
  elseif element.name == "getLiquidItems" then
    for fluid, _ in pairs(fluids) do
      local item = "st-fluidItem-"..fluid
      if player.getitemcount(item) < 1 then
        player.insert({name=item, count=1})
      end
    end
  else
    local option1, option2, option3, option4 = event.element.name:match("(%w+)__([%w%s]*)_*([%w%s]*)_*(%w*)")
    do
      local option1 = option1 or ""
      local option2 = option2 or ""
      local option3 = option3 or ""
      local option4 = option4 or ""
      --debugDump("e: "..event.element.name.." o1: "..option1.." o2: "..option2.." o3: "..option3,true)
      --debugDump(option4,true)
    end
    if option1 == "refuel" then
      option2 = tonumber(option2)
      glob.trains[option2].settings.autoRefuel = not glob.trains[option2].settings.autoRefuel
    elseif option1 == "depart" then
      option2 = tonumber(option2)
      glob.trains[option2].settings.autoDepart = not glob.trains[option2].settings.autoDepart
    elseif option1 == "filterItem" then
      local item = "style"
      local stationIndex = tonumber(option2)
      if player.cursorstack then item = player.cursorstack.name end
      player.gui.left.stGui.dynamicRules.frm.tbl[event.element.name].style = "st-icon-"..item
      player.gui.left.stGui.dynamicRules.frm.tbl[event.element.name].state = false
      if not glob.guiData[index].rules then glob.guiData[index].rules = {} end
      glob.guiData[index].rules[stationIndex] = item
    elseif option1 == "togglefilter" then
      local stationIndex = tonumber(option2)
      local newCaption = ">"
      if element.caption == ">" then
        newCaption = "<"
      elseif element.caption == "<" then
        newCaption = "="
      elseif element.caption == "=" then
        newCaption = ">="
      elseif element.caption == ">=" then
        newCaption = "<="
      elseif element.caption == "<=" then
        newCaption = ">"
      end
      element.caption = newCaption
--      if not glob.guiData[index].rules then glob.guiData[index].rules = {[stationIndex]={}} end
--      glob.guiData[index].rules[stationIndex].condition = newCaption
    elseif option1 == "editRules" then
      showDynamicRules(index,option2)
    elseif option1 == "saveRules" then
      local line = option2
      local gui = player.gui.left.stGui.dynamicRules.frm.tbl
      local tmp = {}
      for i,rule in pairs(glob.trainLines[line].records) do
--        tbl.add({type="checkbox", name="filterItem__" ..trainKey.."__"..line.."__"..i, style="st-icon-style", state=false})
--        tbl.add({type="button", name="togglefilter__"..trainKey.."__"..line.."__"..i, caption = "<", style="circuit_condition_sign_button_style"})
--        tbl.add({type="textfield", name="filteramount__"..trainKey.."__"..line.."__"..i, style="st_textfield_small"})
        local item = glob.guiData[index].rules[i]
        local condition = gui["togglefilter__"..i].caption
        local count = tonumber(gui["filteramount__"..i].text) or 0
        if item and item ~= "style" then
          tmp[i] = {filter=item, condition=condition, count=count}
        else
          tmp[i] = nil
        end                
      end
      glob.trainLines[line].rules = tmp
      glob.guiData[index].rules = nil
      destroyGui(player.gui.left.stGui.dynamicRules)
      refreshUI(index)
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

function refreshUI(index, trainKey)
  trainKey = getTrainKeyFromUI(index)
  destroyGui(game.players[index].gui.left.stGui.dynamicRules)
  showTrainInfoWindow(index,trainKey)
  --showScheduleWindow(index, trainKey, stationEdit)
--    if stationEdit then
--      showDynamicRules(index, line, trainKey)
--    else
--      
--    end
  showTrainLinesWindow(index,trainKey)
end