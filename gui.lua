GUI = {
  styleprefix = "st_",

  defaultStyles = {
    label = "label",
    button = "button",
    checkbox = "checkbox"
  },

  windows = {
    root = "stGui",
    settings = {"settings"},
    trainInfo = {"trainInfo"}},

  position = "left",

  new = function(index, player)
    local new = {}
    setmetatable(new, {__index=GUI})
    return new
  end,

  create_or_update = function(trainInfo, player_index)
    local player = game.players[player_index]
    if player.valid then
      local main = GUI.buildGui(player)
      GUI.showSettingsButton(main)
      if player.opened and player.opened.type == "locomotive" then
        GUI.showTrainInfoWindow(main, trainInfo, player_index)
      end
      GUI.showTrainLinesWindow(main,trainInfo, player_index)
    end
  end,

  buildGui = function (player)
    GUI.destroyGui(player.gui[GUI.position][GUI.windows.root])
    local stGui = GUI.add(player.gui[GUI.position], {type="frame", name="stGui", direction="vertical", style="outer_frame_style"})
    return GUI.add(stGui, {type="table", name="rows", colspan=1})
  end,

  showSettingsButton = function(parent)
    local gui = parent
    if gui.toggleSTSettings ~= nil then
      gui.toggleSTSettings.destroy()
    end
    GUI.addButton(gui, {name="toggleSTSettings", caption = {"text-st-settings"}})
  end,

  destroyGui = function (guiA)
    if guiA ~= nil and guiA.valid then
      guiA.destroy()
    end
  end,

  destroy = function(player_index)
    local player = false
    if type(player_index) == "number" then
      player = game.players[player_index]
    else
      player = player_index
    end
    if player.valid then
      GUI.destroyGui(player.gui[GUI.position][GUI.windows.root])
    end
  end,

  add = function(parent, e, bind)
    local type, name = e.type, e.name
    if not e.style and (type == "button" or type == "label") then
      e.style = "st_"..type
    end
    if bind then
      if type == "checkbox" then
        e.state = global[bind]
      end
    end
    if type == "checkbox" and not (e.state == true or e.state == false) then
      e.state = false
    end
    return parent.add(e)
  end,

  addButton = function(parent, e, bind)
    e.type="button"
    return GUI.add(parent, e, bind)
  end,

  addLabel = function(parent, e, bind)
    local e = e
    if type(e) == "string" or type(e) == "number" or (type(e) == "table" and e[1]) then
      e = {caption=e}
    end
    e.type="label"
    return GUI.add(parent,e,bind)
  end,

  addTextfield = function(parent, e, bind)
    e.type="textfield"
    return GUI.add(parent, e, bind)
  end,

  addPlaceHolder = function(parent, count)
    local c = count or 1
    for i=1,c do
      GUI.add(parent, {type="label", caption=""})
    end
  end,

  globalSettingsWindow = function(index, parent)
    local gui = parent or game.players[index].gui[GUI.position].stGui.rows
    if gui.globalSettings == nil then
      gui.add({type = "frame", name="globalSettings", direction="horizontal", caption={"text-st-global-settings"}})
      gui.globalSettings.add{type="table", name="tbl", colspan=5}
      local tbl = gui.globalSettings.tbl

      GUI.addLabel(tbl, {"stg-refuel-below1"})
      GUI.addTextfield(tbl, {name="refuelRangeMin", style="st_textfield_small"})
      GUI.addLabel(tbl, {"stg-refuel-below2"})
      local r = GUI.add(tbl, {type="flow", name="row1", direction="horizontal"})
      GUI.addTextfield(r, {name="refuelRangeMax", style="st_textfield_small"})
      GUI.addLabel(r, game.get_localised_item_name("coal"))
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, {"stg-max-refuel-time"})
      GUI.addTextfield(tbl, {name="refuelTime", style="st_textfield_small"})
      GUI.addLabel(tbl,  {"stg-refuel-station"})
      GUI.addTextfield(tbl, {name="refuelStation", style="st_textfield"})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, {"stg-min-wait-time"})
      GUI.addTextfield(tbl, {name="minWait", style="st_textfield_small"})
      GUI.addLabel(tbl, {"stg-autodepart-interval"})
      GUI.addTextfield(tbl, {name="departInterval", style="st_textfield_small"})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, {"stg-min-flow-rate"})
      GUI.addTextfield(tbl, {name="minFlow", style="st_textfield_small"})
      GUI.addLabel(tbl, {"stg-circuit-interval"})
      GUI.addTextfield(tbl, {name="circuitInterval", style="st_textfield_small"})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, {"",{"stg-tracked-trains"}, " ", #global.trains})
      local noStations, uniqueStations = 0,0
      for _,station in pairs(global.stationCount) do
        if station > 0 then
          noStations = noStations + station
          uniqueStations = uniqueStations + 1
        end
      end
      GUI.addLabel(tbl,"Stations: "..uniqueStations.."/"..noStations)

      GUI.addPlaceHolder(tbl)
      GUI.addButton(tbl, {name="globalSettingsSave", caption="Save"})

      tbl.refuelRangeMin.text = global.settings.refuel.rangeMin
      tbl.row1.refuelRangeMax.text = global.settings.refuel.rangeMax
      tbl.refuelStation.text = global.settings.refuel.station
      tbl.refuelTime.text = global.settings.refuel.time / 60
      tbl.departInterval.text = global.settings.depart.interval / 60
      tbl.minWait.text = global.settings.depart.minWait / 60
      tbl.minFlow.text = global.settings.depart.minFlow
      tbl.circuitInterval.text = global.settings.circuit.interval
    end
  end,

  showTrainInfoWindow = function(parent, trainInfo, player_index)
    local gui = parent
    if gui.trainSettings ~= nil then
      gui.trainSettings.destroy()
    end
    local t = trainInfo or global.trains[getTrainKeyFromUI(player_index)]
    local trainKey = getTrainKeyByTrain(global.trains, t.train)
    local trainLine = t.line and global.trainLines[t.line] or false
    gui = GUI.add(gui, {type="frame", name="trainSettings", caption={"", {"lbl-train"}, ": ", t.name, " (", t:getType(),")"}, direction="vertical", style="st_frame"})
    local line = "-"
    local dated = " "
    if trainLine then
      line = trainLine.name
      if trainLine.changed ~= t.lineVersion and
        t.lineVersion >= 0 then dated = {"lbl-outdated"} end
    end
    local tableRows = GUI.add(gui, {type="table", name="rows", colspan=1})
    local checkboxes = GUI.add(tableRows, {type="table", name="checkboxes", colspan=2})
    GUI.add(checkboxes, {type="checkbox", name="btn_refuel__"..trainKey, caption={"lbl-refuel"}, state=t.settings.autoRefuel})
    GUI.add(checkboxes, {type="checkbox", name="btn_depart__"..trainKey, caption={"lbl-depart"}, state=t.settings.autoDepart})
    local tbl = GUI.add(tableRows, {type="table", name="line", colspan=2})
    GUI.addLabel(tbl, {"", {"lbl-active-line"}, ": ", line})
    GUI.addLabel(tbl, {"", " ", dated})
    local lineKey = ""
    local records = t.train.schedule.records
    local rules
    if trainLine then
      records = trainLine.records
      rules = trainLine.rules
      lineKey = "__"..trainLine.name
    end
    local tbl = GUI.add(tableRows, {type="table", name="tbl1", colspan=4, style="st_table"})
    local spp = global.settings.stationsPerPage
    local page = global.playerPage[player_index].schedule or 1
    if #records > 0 then
      GUI.addLabel(tbl, {"lbl-station"})
      GUI.addLabel(tbl, {"lbl-time"})
      if line and rules then
        GUI.addLabel(tbl, {"lbl-rules"})
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
        if line and rules and rules[i] and (rules[i].full or rules[i].empty) then
          local condition = rules[i].full and {"lbl-full"} or {"lbl-empty"}
          GUI.addLabel(tbl, {"",{"lbl-leave-when"}," ",condition})
          GUI.addPlaceHolder(tbl)
        elseif line and rules and rules[i] and rules[i].waitForCircuit then
          local jmp = ""
          if rules[i].jumpTo and rules[i].jumpTo <= #records then
            GUI.addLabel(tbl, {"", {"lbl-jump-to"},"", rules[i].jumpTo})
          end
          if not rules[i].jumpTo then
            GUI.addLabel(tbl, {"lbl-wait-for-circuit"})
          end
          GUI.addPlaceHolder(tbl)
        else
          GUI.addPlaceHolder(tbl,2)
        end
      end
    end
    local btns = GUI.add(tableRows,{type="table", name="btns", colspan=2})
    GUI.addButton(btns, {name="readSchedule__"..trainKey..lineKey, caption={"lbl-read-from-ui"}})
    local pages = GUI.add(btns, {type="flow", name="pages", direction="horizontal"})
    if #records > spp then
      if page > 1 then
        GUI.addButton(pages, {name="prevPageTrain__"..page, caption="<"})
      else
        GUI.addLabel(pages, "< ")
      end
      GUI.addLabel(pages, page.."/"..math.ceil(#records/spp))
      if math.ceil(#records/spp) >= page+1 then
        GUI.addButton(pages, {name="nextPageTrain__"..page, caption=">"})
      else
        GUI.addLabel(pages, " >")
      end
    else
      GUI.addPlaceHolder(pages)
    end
    GUI.addButton(btns, {name="saveAsLine__"..trainKey..lineKey, caption={"lbl-save-as-line"}})
    GUI.addTextfield(btns, {name="saveAslineName", text="", style="st_textfield_big"})
  end,

  showTrainLinesWindow = function(parent, trainInfo, player_index)
    local gui = game.players[player_index].gui[GUI.position].stGui.rows
    local trainKey = trainInfo and getTrainKeyByTrain(global.trains, trainInfo.train) or 0
    if gui.trainLines ~= nil then
      gui.trainLines.destroy()
    end
    local page = global.playerPage[player_index].line or 1
    local c=0
    for _,l in pairs(global.trainLines) do
      c = c+1
    end
    if global.trainLines and c > 0 then
      local trainKey = trainKey or 0
      gui = GUI.add(gui, {type="frame", name="trainLines", caption={"lbl-trainlines"}, direction="vertical", style="st_frame"})
      local tbl = GUI.add(gui, {type="table", name="tbl1", colspan=9})
      GUI.addLabel(tbl, {"lbl-trainline"})
      GUI.addLabel(tbl, {"lbl-1st-station"})
      GUI.addLabel(tbl, {"lbl-number-stations"})
      GUI.addLabel(tbl, {"lbl-number-trains"})
      if trainKey > 0 then
        GUI.addLabel(tbl, {"lbl-active"})
      else
        GUI.addPlaceHolder(tbl)
      end
      GUI.addLabel(tbl, {"lbl-marked"})
      GUI.addLabel(tbl,{"lbl-refuel"})
      GUI.addLabel(tbl,{"lbl-depart"})
      GUI.addPlaceHolder(tbl)
      local dirty = 0
      local spp = global.settings.linesPerPage
      local start = (page-1) * spp + 1
      local max = start + spp - 1
      for i, l in pairsByKeys(global.trainLines) do
        local trainCount = 0
        for _,t in pairs(global.trains) do
          if t.line == i then
            trainCount = trainCount + 1
          end
        end
        dirty= dirty+1
        if dirty >= start and dirty <= max then
          GUI.addLabel(tbl, l.name)
          GUI.addLabel(tbl, l.records[1].station)
          GUI.addLabel(tbl, #l.records)
          GUI.addLabel(tbl, trainCount)
          if trainKey > 0 then
            GUI.add(tbl, {type="checkbox", name="activeLine__"..i.."__"..trainKey, state=(i==trainInfo.line), style="st_checkbox"})
          else
            GUI.addPlaceHolder(tbl)
          end
          GUI.add(tbl, {type="checkbox", name="markedDelete__"..i.."__"..trainKey, state=false})
          GUI.add(tbl,{type="checkbox", name="lineRefuel__"..i.."__"..trainKey, state=l.settings.autoRefuel})
          GUI.add(tbl,{type="checkbox", name="lineDepart__"..i.."__"..trainKey, state=l.settings.autoDepart})
          GUI.addButton(tbl, {name="editRules__"..i, caption={"lbl-rules"}})
          --GUI.addPlaceHolder(tbl)
        end
      end
      local btns = GUI.add(gui, {type="table", name="btns", colspan=6})
      if dirty > spp then
        if page > 1 then
          GUI.addButton(btns, {name="prevPageLine__"..page, caption="<"})
        else
          GUI.addLabel(btns, "< ")
        end
        GUI.addLabel(btns, page.."/"..math.ceil(dirty/spp))
        if max < c then
          GUI.addButton(btns, {name="nextPageLine__"..page, caption=">"})
        else
          GUI.addLabel(btns, " >")
        end
      else
        GUI.addPlaceHolder(btns)
      end
      if dirty == 0 then gui.destroy() end
      GUI.addButton(btns, {name="deleteLines", caption={"lbl-delete-marked"}})
      GUI.addButton(btns,{name="renameLine", caption={"lbl-rename"}})
      GUI.addTextfield(btns,{name="newName", text="", style="st_textfield_big"})
    end
  end,

  showDynamicRules = function(index, line, page)
    --debugDump({i=index,line=line,station=stationKey, tr=trainKey}, true)
    local gui = game.players[index].gui[GUI.position].stGui
    if gui.dynamicRules ~= nil then
      gui.dynamicRules.destroy()
    end
    if line and global.trainLines[line] then
      global.guiData[index].line = line
      local lineName = global.trainLines[line].name
      local records = global.trainLines[line].records
      local rules = global.trainLines[line].rules or {}
      global.guiData[index].rules = table.deepcopy(rules)
      gui = GUI.add(gui, {type="frame", name="dynamicRules", direction="vertical", style="st_frame"})
      gui = GUI.add(gui, {type="frame", name="frm", direction="vertical", style="st_inner_frame"})
      GUI.addLabel(gui, {name="line", caption="Line: "..lineName})
      local tbl = GUI.add(gui, {type="table", name="tbl", colspan=7, style="st_table"})
      GUI.addLabel(tbl, {"lbl-station"})
      GUI.addPlaceHolder(tbl)
      GUI.addLabel(tbl, {"lbl-leave-when"})
      GUI.addPlaceHolder(tbl)
      GUI.addLabel(tbl, {"lbl-keepWaiting"})
      GUI.addLabel(tbl, {"lbl-jump-to"})
      GUI.addPlaceHolder(tbl)
      for i,s in pairs(records) do
        GUI.addLabel(tbl, {caption=i.." "..s.station})
        local states = {full = (rules[i] and rules[i].full ~= nil) and rules[i].full or false,
          empty = (rules[i] and rules[i].empty ~= nil) and rules[i].empty or false,
          keepWaiting = false, waitForCircuit = false}
        states.keepWaiting = rules[i] and rules[i].keepWaiting or false
        states.waitForCircuit = rules[i] and rules[i].waitForCircuit or false
        --states.jumpToCircuit = rules[i] and rules[i].jumpToCircuit or false
        GUI.add(tbl, {type="checkbox", name="leaveEmpty__"..i, caption={"lbl-empty"}, style="st_checkbox", state=states.empty})
        GUI.add(tbl, {type="checkbox", name="leaveFull__"..i, caption={"",{"lbl-full"}," (AND)"}, style="st_checkbox", state=states.full})
        GUI.add(tbl, {type="checkbox", name="waitForCircuit__"..i, caption={"lbl-waitForCircuit"}, state=states.waitForCircuit})
        GUI.add(tbl, {type="checkbox", name="keepWaiting__"..i, state=states.keepWaiting})
        GUI.addTextfield(tbl, {name="jumpTo__"..i, text="", style="st_textfield_small"})
        GUI.add(tbl,{type="checkbox", name="jumpToCircuit__"..i, caption={"lbl-waitForCircuit"}, state=states.jumpToCircuit})
        --GUI.addPlaceHolder(tbl)
        tbl["jumpTo__"..i].text = (rules[i] and rules[i].jumpTo) and rules[i].jumpTo or ""
      end
      GUI.addButton(gui, {name="saveRules__"..line, caption="Save"})
    end
  end,

  sanitizeName = function(name)
    local name = string.gsub(name, "_", " ")
    name = string.gsub(name, "^%s", "")
    name = string.gsub(name, "%s$", "")
    local pattern = "(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)"
    local element = "activeLine__"..name.."__".."something"
    local t1,t2,t3,t4 = element:match(pattern)
    if t1 == "activeLine" and t2 == name and t3 == "something" then
      return name
    else
      return false
    end
  end,

  sanitizeNumber = function(number, default)
    return tonumber(number) or default
  end
}

function onguiclick(event)
  local elementName = event.element.name
  local fullName = ""
  local e = event.element
  while e.parent do
    fullName = e.parent.name .. "."..fullName
    e = e.parent.name
  end
  local status, err = pcall(function()
    local index = event.player_index
    local player = game.players[index]
    local refresh = false
    local element = event.element
    local trainInfo = global.trains[getTrainKeyFromUI(index)]

    --ST-Settings
    if element.name == "toggleSTSettings" then
      if player.gui[GUI.position].stGui.rows.globalSettings == nil then
        GUI.globalSettingsWindow(index)
        GUI.destroyGui(player.gui[GUI.position].stGui.rows.toggleSTSettings)
        GUI.destroyGui(player.gui[GUI.position].stGui.rows.dynamicRules)
        GUI.destroyGui(player.gui[GUI.position].stGui.rows.trainSettings)
        GUI.destroyGui(player.gui[GUI.position].stGui.rows.trainLines)
      else
        player.gui[GUI.position].stGui.rows.toggleSTSettings.destroy()
        refresh = true
      end
      --save settings, return to normal view
    elseif element.name == "globalSettingsSave" then
      local settings = player.gui[GUI.position].stGui.rows.globalSettings.tbl
      local time = GUI.sanitizeNumber(settings.refuelTime.text, global.settings.refuel.time/60)*60
      local min = GUI.sanitizeNumber(settings.refuelRangeMin.text, global.settings.refuel.rangeMin)
      local max = GUI.sanitizeNumber(settings.row1.refuelRangeMax.text, global.settings.refuel.rangeMax)
      local station = settings.refuelStation.text

      global.settings.refuel = {time=time, rangeMin = min, rangeMax = max, station = station}
      local interval = GUI.sanitizeNumber(settings.departInterval.text, global.settings.depart.interval/60)*60
      local minWait = GUI.sanitizeNumber(settings.minWait.text, global.settings.depart.minWait/60)*60
      local minFlow = GUI.sanitizeNumber(settings.minFlow.text, global.settings.depart.minFlow)
      local circuitInterval = GUI.sanitizeNumber(settings.circuitInterval.text,global.settings.circuit.interval)
      if circuitInterval < 1 then circuitInterval = 1 end

      global.settings.depart = {interval = interval, minWait = minWait}
      global.settings.depart.minFlow = minFlow
      global.settings.circuit.interval = circuitInterval
      --global.settings.lines.forever = settings.forever.state

      refresh = true
    elseif element.name == "deleteLines" then
      local group = player.gui[GUI.position].stGui.rows.trainLines.tbl1
      local trainKey
      for i, child in pairs(group.children_names) do
        --local pattern = "(%w+)__([%w%s]*)_*([%w%s]*)_*(%w*)"
        local pattern = "(markedDelete)__([%w%s%-%#%!%$]*)_*(%d*)"
        local del, line, trainkey = child:match(pattern)
        if del and group[child].state == true then
          trainKey = tonumber(trainkey)
          if trainKey > 0 then
            if global.trains[trainKey] and global.trains[trainKey].line == line then
              global.trains[trainKey].line = false
            end
          end
          if global.trainLines[line] then
            global.trainLines[line] = nil
          end
        end
      end
      global.playerPage[index].line = 1
      refresh = true
    else
      local option1, option2, option3, option4 = event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
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
        global.trains[option2].settings.autoRefuel = not global.trains[option2].settings.autoRefuel
      elseif option1 == "depart" then
        option2 = tonumber(option2)
        global.trains[option2].settings.autoDepart = not global.trains[option2].settings.autoDepart
      elseif option1 == "editRules" then
        --GUI.destroyGui(player.gui[GUI.position].stGui.settings.toggleSTSettings)
        GUI.destroyGui(player.gui[GUI.position].stGui.rows.trainSettings)
        GUI.showDynamicRules(index,option2)
      elseif option1 == "saveRules" then
        local line = option2
        local gui = player.gui[GUI.position].stGui.dynamicRules.frm.tbl
        local tmp = {}
        for i,rule in pairs(global.trainLines[line].records) do
          if global.guiData[index].rules[i] then
            tmp[i] = global.guiData[index].rules[i]
            local jump = GUI.sanitizeNumber(gui["jumpTo__"..i].text, false)
            tmp[i].jumpTo = (tmp[i].waitForCircuit and not tmp[i].jumpToCircuit) and jump or false
            if not (tmp[i].empty or tmp[i].full or tmp[i].waitForCircuit) then
              tmp[i].keepWaiting = false
            end
            tmp[i].station = rule.station
          else
            tmp[i] = nil
          end
        end
        --debugDump(tmp,true)
        global.trainLines[line].rules = tmp
        global.guiData[index].rules = {}
        GUI.destroyGui(player.gui[GUI.position].stGui.dynamicRules)
        refresh = true
      elseif option1 == "readSchedule" then
        option2 = tonumber(option2)
        if global.trains[option2] ~= nil and global.trains[option2].train.valid then
          global.trains[option2].line = false
          global.trains[option2].lineVersion = false
        end
        refresh = true
      elseif option1 == "saveAsLine" then
        local name = player.gui[GUI.position].stGui.rows.trainSettings.rows.btns.saveAslineName.text
        name = GUI.sanitizeName(name)
        if name ~= false then
          option2 = tonumber(option2)
          local t = global.trains[option2]
          if name ~= "" and t and #t.train.schedule.records > 0 then
            if not global.trainLines[name] then global.trainLines[name] = {name=name} end
            local changed = game.tick
            global.trainLines[name].settings = {autoRefuel = t.settings.autoRefuel, autoDepart = t.settings.autoDepart}
            global.trainLines[name].records = t.train.schedule.records
            global.trainLines[name].changed = changed
            t.line = name
            t.lineVersion = changed
            if type(global.trainLines[name].rules) == "table" then
              local delete = {}
              local insert = {}
              for j, rule in pairs(global.trainLines[name].rules) do
                local i = inSchedule(rule.station, global.trainLines[name])
                if not i then
                  table.insert(delete, i)
                end
                if i ~= j then
                  table.insert(delete, j)
                  table.insert(insert, {index=i, rule=util.table.deepcopy(rule)})
                end
              end
              for _, i in pairs(delete) do
                global.trainLines[name].rules[i] = nil
              end
              for _, i in pairs(insert) do
                global.trainLines[name].rules[i.index] = i.rule
              end
            end            
          end
        else
          debugDump("Invalid name, only letters, numbers, space, -,#,!,$ are allowed",true)
        end
        refresh = true
      elseif option1 == "lineRefuel" then
        local line = option2
        local trainKey = tonumber(option3)
        local t = global.trains[trainKey]
        if line and global.trainLines[line] then
          line = global.trainLines[line]
          line.settings.autoRefuel = not line.settings.autoRefuel
          line.changed = game.tick
          if t and t.line and t.line == line.name then
            t.settings.autoRefuel = line.settings.autoRefuel
            t.lineVersion = line.changed
          end
        end
        refresh = true
      elseif option1 == "lineDepart" then
        local line = option2
        local trainKey = tonumber(option3)
        local t = global.trains[trainKey]
        if line and global.trainLines[line] then
          line = global.trainLines[line]
          line.settings.autoDepart = not line.settings.autoDepart
          line.changed = game.tick
          if t and t.line and t.line == line.name then
            t.settings.autoDepart = line.settings.autoDepart
            t.lineVersion = line.changed
          end
        end
        refresh = true
      elseif element.name == "renameLine" then
        local group = player.gui[GUI.position].stGui.rows.trainLines.tbl1
        local trainKey, rename
        local count=0
        local newName = player.gui[GUI.position].stGui.rows.trainLines.btns.newName.text
        for i, child in pairs(group.children_names) do
          local pattern = "(markedDelete)__([%w%s%-%#%!%$]*)_*(%d*)"
          local del, line, trainkey = child:match(pattern)
          if del and group[child].state == true then
            count = count+1
            rename = line
          end
        end
        if count == 1 then
          newName = GUI.sanitizeName(newName)
          if newName ~= false then
            if newName ~= "" and not global.trainLines[newName] then
              global.trainLines[newName] = table.deepcopy(global.trainLines[rename])
              global.trainLines[newName].name = newName
              global.trainLines[rename] = nil
              for i,t in pairs(global.trains) do
                if t.line == rename then
                  t.line = newName
                end
              end
            end
          else
            debugDump("Invalid name, only letters, numbers, space, -,#,!,$ are allowed",true)
          end
          refresh = true
        end
      elseif option1 == "activeLine" then
        local trainKey = tonumber(option3)
        local li = option2
        local t = global.trains[trainKey]
        if t.line ~= li then
          t.line = li
          t.lineVersion = -1
          if t.train.speed == 0 then
            t:updateLine()
          end
        else
          t.line = false
        end
        t.lineVersion = -1
        --refresh = true
        GUI.create_or_update(t,index)
      elseif option1 == "prevPageTrain" then
        local page = tonumber(option2)
        page = (page > 1) and page - 1 or 1
        global.playerPage[index].schedule = page
        refresh = true
      elseif option1 == "nextPageTrain" then
        local page = tonumber(option2)
        global.playerPage[index].schedule = page + 1
        refresh = true
      elseif option1 == "prevPageLine" then
        local page = tonumber(option2)
        page = (page > 1) and page - 1 or 1
        global.playerPage[index].line = page
        refresh = true
      elseif option1 == "nextPageLine" then
        local page = tonumber(option2)
        global.playerPage[index].line = page + 1
        refresh = true
      elseif option1 == "leaveFull" then
        if element.state == true then
          if element.parent["leaveEmpty__"..option2].state == true then
            element.parent["leaveEmpty__"..option2].state = false
          end
        end
        if element.parent["leaveFull__"..option2].state == false and
          element.parent["leaveEmpty__"..option2].state == false and
          element.parent["waitForCircuit__"..option2].state == false then
          element.parent["keepWaiting__"..option2].state = false
        end
        local rules = global.guiData[index].rules[tonumber(option2)] or {}
        rules.full = element.state
        rules.empty = element.parent["leaveEmpty__"..option2].state
        rules.keepWaiting = element.parent["keepWaiting__"..option2].state
        rules.waitForCircuit = element.parent["waitForCircuit__"..option2].state
        rules.jumpTo = element.parent["jumpTo__"..option2].text
        rules.jumpToCircuit = element.parent["jumpToCircuit__"..option2].state
        global.guiData[index].rules[tonumber(option2)] = rules
      elseif option1 == "leaveEmpty" then
        if element.state == true then
          if element.parent["leaveFull__"..option2].state == true then
            element.parent["leaveFull__"..option2].state = false
          end
        end
        if element.parent["leaveFull__"..option2].state == false and
          element.parent["leaveEmpty__"..option2].state == false and
          element.parent["waitForCircuit__"..option2].state == false then
          element.parent["keepWaiting__"..option2].state = false
        end
        local rules = global.guiData[index].rules[tonumber(option2)] or {}
        rules.empty = element.state
        rules.full = element.parent["leaveFull__"..option2].state
        rules.keepWaiting = element.parent["keepWaiting__"..option2].state
        rules.waitForCircuit = element.parent["waitForCircuit__"..option2].state
        rules.jumpToCircuit = element.parent["jumpToCircuit__"..option2].state
        global.guiData[index].rules[tonumber(option2)] = rules
      elseif option1 == "keepWaiting" then
        local rules = global.guiData[index].rules[tonumber(option2)] or {}
        rules.empty = element.parent["leaveEmpty__"..option2].state
        rules.full = element.parent["leaveFull__"..option2].state
        rules.waitForCircuit = element.parent["waitForCircuit__"..option2].state
        rules.jumpToCircuit = element.parent["jumpToCircuit__"..option2].state
        if not (rules.empty or rules.full or rules.waitForCircuit) then
          element.state = false
        end
        rules.keepWaiting = element.state
        global.guiData[index].rules[tonumber(option2)] = rules
      elseif option1 == "waitForCircuit" then
        if element.state == false then
          element.parent["jumpTo__"..option2].text = ""
        end
        if element.parent["leaveFull__"..option2].state == false and
          element.parent["leaveEmpty__"..option2].state == false and
          element.parent["waitForCircuit__"..option2].state == false then
          element.parent["keepWaiting__"..option2].state = false
        end
        local rules = global.guiData[index].rules[tonumber(option2)] or {}
        rules.waitForCircuit = element.state
        rules.empty = element.parent["leaveEmpty__"..option2].state
        rules.full = element.parent["leaveFull__"..option2].state
        rules.keepWaiting = element.parent["keepWaiting__"..option2].state
        rules.jumpToCircuit = element.parent["jumpToCircuit__"..option2].state
        global.guiData[index].rules[tonumber(option2)] = rules
      elseif option1 == "jumpToCircuit" then
        if not element.parent["waitForCircuit__"..option2].state then
          element.state = false
        end
        if element.state == true then
          element.parent["jumpTo__"..option2].text = ""
        end
        if element.parent["leaveFull__"..option2].state == false and
          element.parent["leaveEmpty__"..option2].state == false and
          element.parent["waitForCircuit__"..option2].state == false then
          element.parent["keepWaiting__"..option2].state = false
        end
        local rules = global.guiData[index].rules[tonumber(option2)] or {}
        rules.empty = element.parent["leaveEmpty__"..option2].state
        rules.full = element.parent["leaveFull__"..option2].state
        rules.keepWaiting = element.parent["keepWaiting__"..option2].state
        rules.waitForCircuit = element.parent["waitForCircuit__"..option2].state
        rules.jumpToCircuit = element.parent["jumpToCircuit__"..option2].state
        global.guiData[index].rules[tonumber(option2)] = rules
      end
    end
    if refresh then
      GUI.create_or_update(trainInfo,index)
    end
  end)
  if not status then
    pauseError(err, {"on_gui_click", fullName})
  end
end
