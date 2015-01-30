GUI = {
  new = function(index, player)
    local new = {}
    setmetatable(new, {__index=GUI})
    return new
  end,

  onNotify = function(self, entity, event)

  end,

  add = function(parent, e, bind)
    local type, name = e.type, e.name
    if not e.style and (type == "button" or type == "label") then
      e.style = "st_"..type
    end
    if bind then
      if type == "checkbox" then
        e.state = glob[bind]
      end
    end
    return parent.add(e)
  end,
  addButton = function(parent, e, bind)
    e.type="button"
    return GUI.add(parent, e, bind)
  end,

  addLabel = function(parent, e, bind)
    local e = e
    if type(e) == "string" or type(e) == "number" then
      e = {caption=e}
    end
    e.type="label"
    return GUI.add(parent,e,bind)
  end,

  addTextfield = function(parent, e, bind)
    e.type="textfield"
    return GUI.add(parent, e, binf)
  end,

  addPlaceHolder = function(parent, count)
    local c = count or 1
    for i=1,c do
      GUI.add(parent, {type="label", caption=""})
    end
  end,

  globalSettingsWindow = function(index, parent)
    local gui = parent or game.players[index].gui.left.stGui.settings
    if gui.globalSettings == nil then
      gui.add({type = "frame", name="globalSettings", direction="horizontal", caption="Global settings"})
      gui.globalSettings.add{type="table", name="tbl", colspan=5}
      local tbl = gui.globalSettings.tbl

      GUI.addLabel(tbl, "Go to Refuel station below")
      GUI.addTextfield(tbl, {name="refuelRangeMin", style="st_textfield_small"})
      GUI.addLabel(tbl, "coal, leave above")
      local r = GUI.add(tbl, {type="flow", name="row1", direction="horizontal"})
      GUI.addTextfield(r, {name="refuelRangeMax", style="st_textfield_small"})
      GUI.addLabel(r, "coal")
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, "max. refuel time:")
      GUI.addTextfield(tbl, {name="refuelTime", style="st_textfield_small"})
      GUI.addLabel(tbl, "Refuel station:")
      GUI.addTextfield(tbl, {name="refuelStation", style="st_textfield"})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, "Min. waiting time")
      GUI.addTextfield(tbl, {name="minWait", style="st_textfield_small"})
      GUI.addLabel(tbl, "Interval for autodepart")
      GUI.addTextfield(tbl, {name="departInterval", style="st_textfield_small"})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, "Min. flow rate")
      GUI.addTextfield(tbl, {name="minFlow", style="st_textfield_small"})
      GUI.addLabel(tbl,"With invalid rules:")
      GUI.add(tbl,{type="checkbox", name="forever", state=glob.settings.lines.forever, caption="wait forever"})
      GUI.addPlaceHolder(tbl)
      
      GUI.addLabel(tbl, "Tracked trains: "..#glob.trains)
      GUI.addPlaceHolder(tbl, 2)
      GUI.addButton(tbl, {name="globalSettingsSave", caption="Save"})

      tbl.refuelRangeMin.text = glob.settings.refuel.rangeMin
      tbl.row1.refuelRangeMax.text = glob.settings.refuel.rangeMax
      tbl.refuelStation.text = glob.settings.refuel.station
      tbl.refuelTime.text = glob.settings.refuel.time / 60
      tbl.departInterval.text = glob.settings.depart.interval / 60
      tbl.minWait.text = glob.settings.depart.minWait / 60
      tbl.minFlow.text = glob.settings.depart.minFlow
    end
  end,

  showDynamicRules = function(index, line, page)
    --debugDump({i=index,line=line,station=stationKey, tr=trainKey}, true)
    local gui = game.players[index].gui.left.stGui
    if gui.dynamicRules ~= nil then
      gui.dynamicRules.destroy()
    end
    if line and glob.trainLines[line] then
      local lineName = glob.trainLines[line].name
      local records = glob.trainLines[line].records
      local rules = glob.trainLines[line].rules or {}
      gui = GUI.add(gui, {type="frame", name="dynamicRules", direction="vertical", style="st_frame"})
      gui = GUI.add(gui, {type="frame", name="frm", direction="vertical", style="st_inner_frame"})
      GUI.addLabel(gui, {name="line", caption="Line: "..lineName})
      local tbl = GUI.add(gui, {type="table", name="tbl", colspan=4, style="st_table"})
      GUI.addLabel(tbl, "Station")
      GUI.addLabel(tbl, "Filter")
      GUI.addPlaceHolder(tbl, 2)

      glob.guiData[index].rules = glob.guiData[index].rules or {}
      for i,s in ipairs(records) do
        local filter = "style"
        local condition = ">"
        local count = "1"
        if rules[i] then
          filter, condition, count = rules[i].filter, rules[i].condition, rules[i].count
          glob.guiData[index].rules[i] = filter
        end
        GUI.addLabel(tbl, {caption=i.." "..s.station})
        GUI.add(tbl, {type="checkbox", name="filterItem__"..i, style="st-icon-"..filter, state=false})
        GUI.addButton(tbl, {name="togglefilter__"..i, caption = condition, style="circuit_condition_sign_button_style"})
        GUI.addTextfield(tbl, {name="filteramount__"..i, style="st_textfield_medium"})
        if count ~= "" then
          tbl["filteramount__"..i].text = count
        end
      end
      GUI.addButton(gui, {name="saveRules__"..line, caption="Save"})
      GUI.addButton(gui, {name="getLiquidItems", caption="Liquid items"})
    end
  end,

  showSettingsButton = function(index, parent)
    local gui = parent or game.players[index].gui.left.stGui.settings
    if gui.toggleSTSettings ~= nil then
      gui.toggleSTSettings.destroy()
    end
    GUI.addButton(gui, {name="toggleSTSettings", caption = "ST-Settings"})
  end,

  showTrainInfoWindow = function(index, trainKey, train, trainLine, page)
    local gui = game.players[index].gui.left.stGui
    if gui.trainSettings ~= nil then
      gui.trainSettings.destroy()
    end
    local t = train
    gui = GUI.add(gui, {type="frame", name="trainSettings", caption="Train: "..t.name, direction="vertical", style="st_frame"})
    local line = "-"
    local dated = " "
    if trainLine then
      line = trainLine.name
      if trainLine.changed ~= t.lineVersion then dated = " (outdated)" end
    end
    local tableRows = GUI.add(gui, {type="table", name="rows", colspan=1})
    local checkboxes = GUI.add(tableRows, {type="table", name="checkboxes", colspan=2})
    GUI.add(checkboxes, {type="checkbox", name="btn_refuel__"..trainKey, caption="Refuel", state=t.settings.autoRefuel})
    GUI.add(checkboxes, {type="checkbox", name="btn_depart__"..trainKey, caption="Depart", state=t.settings.autoDepart})
    local tbl = GUI.add(tableRows, {type="table", name="line", colspan=2})
    GUI.addLabel(tbl, "Active line: "..line)
    GUI.addLabel(tbl, " "..dated)
    local lineKey = ""
    local records = t.train.schedule.records
    local rules
    if trainLine then
      records = trainLine.records
      rules = trainLine.rules
      lineKey = "__"..trainLine.name
    end
    local tbl = GUI.add(tableRows, {type="table", name="tbl1", colspan=4, style="st_table"})
    local spp = glob.settings.stationsPerPage
    local page = page or 1
    if #records > 0 then
      GUI.addLabel(tbl, "Station")
      GUI.addLabel(tbl, "Time")
      if line and rules then
        GUI.addLabel(tbl, "Rules")
      else
        GUI.addPlaceHolder(tbl)
      end
      GUI.addPlaceHolder(tbl)
      local start = (page-1) * spp + 1
      local max = start + spp - 1
      if max > #records then max = #records end
      for i=start, max do
        local s = records[i]
        GUI.addLabel(tbl, i.." "..s.station)
        GUI.addLabel(tbl, s.time_to_wait/60)
        if line and rules and rules[i] then
          tbl.add({type="checkbox", state=false, style="st-icon-"..rules[i].filter})
          GUI.addLabel(tbl, " "..rules[i].condition.." "..rules[i].count)
        else
          GUI.addPlaceHolder(tbl)
          GUI.addPlaceHolder(tbl)
        end
      end
    end
    local btns = tableRows.add({type="table", name="btns", colspan=2})
    GUI.addButton(btns, {name="readSchedule__"..trainKey..lineKey, caption="Read from UI"})
    local pages = GUI.add(btns, {type="flow", name="pages", direction="horizontal"})
    if #records > spp then
      GUI.addButton(pages, {name="prevPageTrain__"..page, caption="<"})
      GUI.addLabel(pages, page.."/"..math.ceil(#records/spp))
      GUI.addButton(pages, {name="nextPageTrain__"..page, caption=">"})
    else
      GUI.addPlaceHolder(pages)
    end
    GUI.addButton(btns, {name="saveAsLine__"..trainKey..lineKey, caption="Save as line "})
    GUI.addTextfield(btns, {name="saveAslineName", text="", style="st_textfield_big"})
  end,
  
  showTrainLinesWindow = function(index, trainKey, activeLine, page)
    local gui = game.players[index].gui.left.stGui
    if gui.trainLines ~= nil then
      gui.trainLines.destroy()
    end
    local page = page or 1
    local c=0
    for _,l in pairs(glob.trainLines) do
      c = c+1
    end
    if glob.trainLines and c > 0 then
      local trainKey = trainKey or 0
      gui = GUI.add(gui, {type="frame", name="trainLines", caption="Trainlines", direction="vertical", style="st_frame"})
      local tbl = GUI.add(gui, {type="table", name="tbl1", colspan=6})
      GUI.addLabel(tbl, "Line")
      GUI.addLabel(tbl, "1st station")
      GUI.addLabel(tbl, "#stations")
      if trainKey > 0 then
        GUI.addLabel(tbl, "Active")
      else
        GUI.addPlaceHolder(tbl)
      end
      GUI.addLabel(tbl, "Marked")
      GUI.addPlaceHolder(tbl)
      local dirty = 0
      local spp = glob.settings.stationsPerPage
      local start = (page-1) * spp + 1
      local max = start + spp - 1
      for i, l in pairsByKeys(glob.trainLines) do
        dirty= dirty+1
        if dirty >= start and dirty <= max then
          GUI.addLabel(tbl, l.name)
          GUI.addLabel(tbl, l.records[1].station)
          GUI.addLabel(tbl, #l.records)
          if trainKey > 0 then
            GUI.add(tbl, {type="checkbox", name="activeLine__"..i.."__"..trainKey, state=(i==activeLine), style="st_checkbox"})
          else
            GUI.addPlaceHolder(tbl)
          end
          GUI.add(tbl, {type="checkbox", name="markedDelete__"..i.."__"..trainKey, state=false})
          GUI.addButton(tbl, {name="editRules__"..i, caption="Rules"})
        end
      end
      local btns = GUI.add(gui, {type="table", name="btns", colspan=6})
      if dirty > spp then
        GUI.addButton(btns, {name="prevPageLine__"..page, caption="<"})
        GUI.addLabel(btns, page.."/"..math.ceil(dirty/spp))
        GUI.addButton(btns, {name="nextPageLine__"..page, caption=">"})
      else
        GUI.addPlaceHolder(btns)
      end
      if dirty == 0 then gui.destroy() end
      GUI.addButton(btns, {name="deleteLines", caption="Delete marked"})
      GUI.addButton(btns,{name="renameLine", caption="Rename"})
      GUI.addTextfield(btns,{name="newName", text="", style="st_textfield_big"})
    end
  end
}

function destroyGui(guiA)
  if guiA ~= nil and guiA.valid then
    guiA.destroy()
  end
end

function buildGUI(player)
  destroyGui(player.gui.left.stGui)
  local stGui = GUI.add(player.gui.left, {type="frame", name="stGui", direction="vertical", style="outer_frame_style"})
  GUI.add(stGui, {type="frame", name="settings", direction="horizontal", style="st_inner_frame"})
end

function refreshUI(index, stationPage, linePage)
  local trainLine = false
  local trainKey = 0
  local train
  local type = game.player.opened.type
  destroyGui(game.players[index].gui.left.stGui.dynamicRules)
  GUI.showSettingsButton(index)
  if type == "locomotive" then
    trainKey = getTrainKeyFromUI(index)
    train = glob.trains[trainKey]
    if train.line then trainLine = glob.trainLines[train.line] end
    GUI.showTrainInfoWindow(index, trainKey, glob.trains[trainKey], trainLine, stationPage)
  end
  local activeLine = trainLine and trainLine.name or false
  GUI.showTrainLinesWindow(index, trainKey, activeLine, linePage)
end

function onguiclick(event)
  local index = event.playerindex or event.name
  local player = game.players[index]
  local refresh = false
  if not glob.guiData[index] then glob.guiData[index] = {} end
  local element = event.element
  if element.name == "toggleSTSettings" then
    if player.gui.left.stGui.settings.globalSettings == nil then
      GUI.globalSettingsWindow(index)
      destroyGui(player.gui.left.stGui.settings.toggleSTSettings)
      destroyGui(player.gui.left.stGui.dynamicRules)
      destroyGui(player.gui.left.stGui.trainSettings)
      destroyGui(player.gui.left.stGui.trainLines)
    else
      player.gui.left.stGui.settings.toggleSTSettings.destroy()
      refresh = true
    end
  elseif element.name == "globalSettingsSave" then
    local settings = player.gui.left.stGui.settings.globalSettings.tbl
    local time, min, max, station = tonumber(settings.refuelTime.text)*60, tonumber(settings.refuelRangeMin.text), tonumber(settings.row1.refuelRangeMax.text), settings.refuelStation.text
    glob.settings.refuel = {time=time, rangeMin = min, rangeMax = max, station = station}
    local interval, minWait = tonumber(settings.departInterval.text)*60, tonumber(settings.minWait.text)*60
    local minFlow = tonumber(settings.minFlow.text)
    glob.settings.depart = {interval = interval, minWait = minWait}
    glob.settings.depart.minFlow = minFlow
    glob.settings.lines.forever = settings.forever.state
    player.gui.left.stGui.settings.globalSettings.destroy()
    refresh = true
  elseif element.name == "renameLine" then
    local group = game.players[index].gui.left.stGui.trainLines.tbl1
    local trainKey, rename
    local count=0
    local newName = game.players[index].gui.left.stGui.trainLines.btns.newName.text
    for i, child in pairs(group.childrennames) do
      local pattern = "(markedDelete)__([%w%s]*)_*(%d*)"
      local del, line, trainkey = child:match(pattern)
      if del and group[child].state == true then
        count = count+1
        rename = line
      end
    end
    if count == 1 then
      newName = string.gsub(newName, "_", " ")
      newName = string.gsub(newName, "^%s", "")
      newName = string.gsub(newName, "%s$", "")
      if newName ~= "" and not glob.trainLines[newName] then
        glob.trainLines[newName] = table.deepcopy(glob.trainLines[rename])
        glob.trainLines[newName].name = newName
        glob.trainLines[rename] = nil
        for i,t in ipairs(glob.trains) do
          if t.line == rename then
            t.line = newName
          end
        end
      end
    end
    refresh = true
  elseif element.name == "deleteLines" then
    local group = game.players[index].gui.left.stGui.trainLines.tbl1
    local trainKey
    for i, child in pairs(group.childrennames) do
      --local pattern = "(%w+)__([%w%s]*)_*([%w%s]*)_*(%w*)"
      local pattern = "(markedDelete)__([%w%s]*)_*(%d*)"
      local del, line, trainkey = child:match(pattern)
      if del and group[child].state == true then
        trainKey = tonumber(trainkey)
        if trainKey > 0 then
          if glob.trains[trainKey] and glob.trains[trainKey].line == line then
            glob.trains[trainKey].line = false
          end
        end
        if glob.trainLines[line] then
            glob.trainLines[line] = nil
        end
      end
    end
    refresh = true
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
      --destroyGui(player.gui.left.stGui.settings.toggleSTSettings)
      destroyGui(player.gui.left.stGui.trainSettings)
      GUI.showDynamicRules(index,option2)
    elseif option1 == "saveRules" then
      local line = option2
      local gui = player.gui.left.stGui.dynamicRules.frm.tbl
      local tmp = {}
      for i,rule in pairs(glob.trainLines[line].records) do
        local item = glob.guiData[index].rules[i]
        local condition = gui["togglefilter__"..i].caption
        local count = tonumber(gui["filteramount__"..i].text) or 0
        if item and item ~= "style" then
          tmp[i] = {filter=item, condition=condition, count=count, forever=forever}
        else
          tmp[i] = nil
        end
      end
      glob.trainLines[line].rules = tmp
      glob.guiData[index].rules = nil
      destroyGui(player.gui.left.stGui.dynamicRules)
      refresh = true
    elseif option1 == "readSchedule" then
      option2 = tonumber(option2)
      if glob.trains[option2] ~= nil and glob.trains[option2].train.valid then
        glob.trains[option2].line = false
        glob.trains[option2].lineVersion = false
      end
      refresh = true
    elseif option1 == "saveAsLine" then
      local name = player.gui.left.stGui.trainSettings.rows.btns.saveAslineName.text
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
        refresh = true
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
      --refresh = true
      GUI.showTrainInfoWindow(index, trainKey, t, glob.trainLines[t.line])
      GUI.showTrainLinesWindow(index,trainKey, t.line)
    elseif option1 == "prevPageTrain" then
      local page = tonumber(option2)
      if page > 1 then
        page = page-1
      else
        return
      end
      refreshUI(index, page)
    elseif option1 == "nextPageTrain" then
      local page = tonumber(option2)
      page = page+1
      local trainKey = getTrainKeyFromUI(index)
      local t = glob.trains[trainKey]
      refreshUI(index, page)
    elseif option1 == "prevPageLine" then
      local page = tonumber(option2)
      if page > 1 then
        page = page-1
      else
        return
      end
      refreshUI(index, nil, page)
    elseif option1 == "nextPageLine" then
      local page = tonumber(option2)
      page = page+1
      local trainKey = getTrainKeyFromUI(index)
      local t = glob.trains[trainKey]
      refreshUI(index, nil, page)
    end
  end
  if refresh then
    refreshUI(index)
  end
end
