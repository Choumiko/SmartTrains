function page_count(item_count, items_per_page)
  return math.floor((item_count - 1) / (items_per_page)) + 1
end

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
    
    --insert this element into a frame for padding purposes
    if e.left_padding then
      local name = nil
      if e.name then
        name = "padding_frame__"..e.name
      end
    
      local top = ""
      if e.top_padding then
        top ="top_"
      end
      
      local frame = parent.add({type="frame", name=name, style="st_frame_padding_"..top.."left_"..e.left_padding})
      e.left_padding = nil
      e.top_padding = nil
      
      return frame.add(e)
    end
    
    return parent.add(e)
  end,

  addButton = function(parent, e, bind)
    e.type="button"
    if not e.style then
      e.style = "st_button_style"
    end
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

      local coal_min = fuel_value_to_coal(global.settings.refuel.rangeMin)
      local coal_max = fuel_value_to_coal(global.settings.refuel.rangeMax)

      GUI.addLabel(tbl, {"stg-refuel-below1"})
      GUI.addTextfield(tbl, {name="refuelRangeMin", style="st_textfield", text = global.settings.refuel.rangeMin})
      GUI.addLabel(tbl, {"", {"stg-MJ"}, " ("..coal_min.." ", game.item_prototypes["coal"].localised_name, ")",{"stg-refuel-below2"}})
      local r = GUI.add(tbl, {type="flow", name="row1", direction="horizontal"})
      GUI.addTextfield(r, {name="refuelRangeMax", style="st_textfield", text = global.settings.refuel.rangeMax})
      GUI.addLabel(r, {"", {"stg-MJ"}, " ("..coal_max.." ", game.item_prototypes["coal"].localised_name,")"})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, {"stg-max-refuel-time"})
      GUI.addTextfield(tbl, {name="refuelTime", style="st_textfield_small", text = global.settings.refuel.time / 60})
      GUI.addLabel(tbl,  {"stg-refuel-station"})
      GUI.addTextfield(tbl, {name="refuelStation", style="st_textfield_big", text = global.settings.refuel.station})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, {"stg-min-wait-time"})
      GUI.addTextfield(tbl, {name="minWait", style="st_textfield_small", text = global.settings.depart.minWait / 60})
      GUI.addLabel(tbl, {"stg-autodepart-interval"})
      GUI.addTextfield(tbl, {name="departInterval", style="st_textfield_small", text = global.settings.depart.interval / 60})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, {"stg-min-flow-rate"})
      GUI.addTextfield(tbl, {name="minFlow", style="st_textfield_small", text = global.settings.depart.minFlow})
      GUI.addLabel(tbl, {"stg-circuit-interval"})
      GUI.addTextfield(tbl, {name="circuitInterval", style="st_textfield_small", text = global.settings.circuit.interval})
      GUI.addPlaceHolder(tbl)

      GUI.addLabel(tbl, {"",{"stg-tracked-trains"}, " ", #global.trains})
      local noStations, uniqueStations = 0,0
      for _,station in pairs(global.stationCount) do
        if station > 0 then
          noStations = noStations + station
          uniqueStations = uniqueStations + 1
        end
      end
      GUI.addPlaceHolder(tbl)
      GUI.addLabel(tbl,{"", {"lbl-stations"}, ": ", uniqueStations, "/", noStations})

      GUI.addButton(tbl, {name="globalSettingsSave", caption="Save"})
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
        GUI.addLabel(tbl, {"lbl-leave-when"})
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
        local time = (trainLine and rules[i] and rules[i].keepWaiting) and {"lbl-forever"} or (s.time_to_wait > 12010 and {"lbl-forever"}) or s.time_to_wait/60
        GUI.addLabel(tbl, time)
        local inf = ""
        local text = {""}
        if line and rules and rules[i] then
          if (rules[i].full or rules[i].empty) then
            local condition = rules[i].full and {"lbl-full"} or {"lbl-empty"}
            table.insert(text, condition)
            table.insert(text, " ")
          --GUI.addLabel(tbl, {"", condition})
          --GUI.addPlaceHolder(tbl)
          end
          if rules[i].waitForCircuit then
            if rules[i].empty or rules[i].full then
              table.insert(text, "& ")
            end
            if rules[i].jumpTo and rules[i].jumpTo <= #records then
              table.insert(text, {"lbl-jump-to"})
              table.insert(text, "")
              table.insert(text, rules[i].jumpTo)
              --GUI.addLabel(tbl, {"", {"lbl-jump-to"},"", rules[i].jumpTo})
              
            elseif rules[i].jumpTo then
              --TODO: Tell the user the destination # is invalid
            end
            if not rules[i].jumpTo then
              table.insert(text, {"lbl-wait-for-circuit"})
              --GUI.addLabel(tbl, {"lbl-wait-for-circuit"})
            end
          end
          GUI.addLabel(tbl, text)
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
        GUI.addButton(pages, {name="prevPageTrain__"..page, caption="<", style="st_button_style_bold"})
      else
        GUI.addButton(pages, {name="asdfFoo", caption="<", style="st_disabled_button_bold"})
      end
      GUI.addButton(pages, {caption=page.."/"..math.ceil(#records/spp), style="st_disabled_button_bold"})
      if math.ceil(#records/spp) >= page+1 then
        GUI.addButton(pages, {name="nextPageTrain__"..page, caption=">", style="st_button_style"})
      else
        GUI.addButton(pages, {name="asdfFoo2", caption= ">", style="st_disabled_button_bold"})
      end
    else
      GUI.addPlaceHolder(pages)
    end
    GUI.addButton(btns, {name="saveAsLine__"..trainKey..lineKey, caption={"lbl-save-as-line"}})
    local line = GUI.addTextfield(btns, {name="saveAslineName", text="", style="st_textfield_big"})
    if trainLine then
      line.text = trainLine.name
    end
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
      for i, l in pairsByKeys(global.trainLines, sortByName) do
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
          GUI.addButton(tbl, {name="editRules__"..i, caption={"lbl-rules"}, style="st_button_style_bold"})
        end
      end
      local btns = GUI.add(gui, {type="table", name="btns", colspan=6})
      if dirty > spp then
        if page > 1 then
          GUI.addButton(btns, {name="prevPageLine__"..page, caption="<", style="st_button_style_bold"})
        else
          GUI.addButton(btns, {caption="<", style="st_disabled_button_bold"})
        end
        GUI.addButton(btns, {caption=page.."/"..math.ceil(dirty/spp), style="st_disabled_button_bold"})
        if max < c then
          GUI.addButton(btns, {name="nextPageLine__"..page, caption=">",style="st_button_style_bold"})
        else
          GUI.addButton(btns, {caption=">", style="st_disabled_button_bold"})
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
      local line_number = global.trainLines[line].number
      global.guiData[index].rules = global.guiData[index].rules or table.deepcopy(rules)
      gui = GUI.add(gui, {type="frame", name="dynamicRules", direction="vertical", style="st_frame"})
      gui = GUI.add(gui, {type="frame", name="frm", direction="vertical", style="st_inner_frame"})
      local flow = GUI.add(gui, {type="flow", name="rulesFlow", direction="horizontal"})
      GUI.addLabel(flow, {name="line", caption="Line: "..lineName})
      GUI.addLabel(flow, {name="line_number", caption="#: "})
      GUI.addTextfield(flow,{name="lineNumber__"..line, style="st_textfield_small", text=line_number})

      local tbl = GUI.add(gui, {type="table", name="tbl", colspan=14, style="st_table"})
	  
      --1
      GUI.addLabel(tbl, {caption={"lbl-station"}, style="st_label_bold"})

      --2
      GUI.addLabel(tbl, {caption={"lbl-empty-header"}, style="st_label_bold"})
      GUI.addLabel(tbl, {caption="   "})

      --3 
      GUI.addLabel(tbl, {caption={"lbl-full-header"}, style="st_label_bold"})
      GUI.addLabel(tbl, {caption="   "})

      --4
      GUI.addLabel(tbl, {caption={"lbl-and-header"}, style="st_label_bold"})
      GUI.addLabel(tbl, {caption="   "})

      --5
      GUI.addLabel(tbl, {caption={"lbl-wait-for-circuit-header"}, style="st_label_bold"})
      GUI.addLabel(tbl, {caption="   "})

      --6
      GUI.addLabel(tbl, {caption={"lbl-keepWaiting"}, style="st_label_bold"})
      GUI.addLabel(tbl, {caption="   "})

      --7
      GUI.addLabel(tbl, {caption={"lbl-jump-to-header"}, style="st_label_bold"})
      GUI.addLabel(tbl, {caption="   "})

      --8
      GUI.addLabel(tbl, {caption={"lbl-jump-to-signal-header"}, style="st_label_bold"})
      

      local page = global.playerRules[index].page or 1
      local upper = page*global.settings.rulesPerPage
      local lower = page*global.settings.rulesPerPage-global.settings.rulesPerPage

      for i,s in pairs(records) do
        if i>lower and i<=upper then
          local states = {
            full = (rules[i] and rules[i].full ~= nil) and rules[i].full or false,
            empty = (rules[i] and rules[i].empty ~= nil) and rules[i].empty or false,
            keepWaiting = rules[i] and rules[i].keepWaiting or false, 
            waitForCircuit = rules[i] and rules[i].waitForCircuit or false,
            requireBoth = rules[i] and rules[i].requireBoth or false,
            jumpToCircuit = rules[i] and rules[i].jumpToCircuit or false,
            jumpTo = (rules[i] and rules[i].jumpTo) and rules[i].jumpTo or ""
          }
          
          --1
          GUI.addLabel(tbl, {caption="#"..i.." "..s.station, style="st_label_bold"})

          --2
          GUI.add(tbl, {type="checkbox", name="leaveEmpty__"..i, style="st_radio", left_padding=14, top_padding=true, state=states.empty})
          GUI.addLabel(tbl, {caption="   "})

          --3
          --GUI.add(tbl, {type="checkbox", name="leaveFull__"..i, caption={"",{"lbl-full"}," (AND OR)"}, style="st_radio_left_10", state=states.full})
          GUI.add(tbl, {type="checkbox", name="leaveFull__"..i, style="st_radio", left_padding=7, top_padding=true, state=states.full}) --4
          GUI.addLabel(tbl, {caption="   "})

          --4
          GUI.add(tbl, {type="checkbox", name="requireBoth__"..i, style="st_checkbox", left_padding=7, state=states.requireBoth}) --4
          GUI.addLabel(tbl, {caption="   "})

          --5
          GUI.add(tbl, {type="checkbox", name="waitForCircuit__"..i, style="st_checkbox", left_padding=11, state=states.waitForCircuit}) --6
          GUI.addLabel(tbl, {caption="   "})

          --6
          GUI.add(tbl, {type="checkbox", name="keepWaiting__"..i, style="st_checkbox", left_padding=9, state=states.keepWaiting}) --5
          GUI.addLabel(tbl, {caption="   "})

          --7
          GUI.addTextfield(tbl, {name="jumpTo__"..i, text=states.jumpTo, style="st_textfield_small", left_padding=8})
          GUI.addLabel(tbl, {caption="   "})

          --8
          GUI.add(tbl,{type="checkbox", name="jumpToCircuit__"..i, style="st_checkbox", left_padding=22, state=states.jumpToCircuit}) --12
        end
      end
      
      local buttonFlow = GUI.add(gui,{name="buttonFlow", type="flow"})
      local pageButtons = GUI.add(buttonFlow, {name="pageButtons", type="flow"})

      local prevPage = GUI.addButton(pageButtons,{name="prevPageRule", caption="<", style="st_button_style_bold"})
      if page == 1 then
        prevPage.style = "st_disabled_button_bold"
      end
      local maxPage = page_count(#records, global.settings.rulesPerPage)
      GUI.addButton(pageButtons,{name="rule_page_number", caption=page.."/"..maxPage, style="st_disabled_button_bold"})

      local nextPage = GUI.addButton(pageButtons,{name="nextPageRule", caption=">", style="st_button_style_bold"})
      if page == maxPage then
        nextPage.style = "st_disabled_button_bold"
      end

      GUI.addButton(buttonFlow, {name="saveRules__"..line, caption="Save", style="st_button_style_bold"})
    end
  end,
  
  find_relative = function(e, name)
    return e.parent.parent["padding_frame__"..name][name]
  end,

  get_station_options = function(e, option2)
    return {
      leaveEmpty = GUI.find_relative(e, "leaveEmpty__"..option2),
      leaveFull = GUI.find_relative(e, "leaveFull__"..option2),
      requireBoth = GUI.find_relative(e, "requireBoth__"..option2),
      waitForCircuit = GUI.find_relative(e, "waitForCircuit__"..option2),
      keepWaiting = GUI.find_relative(e, "keepWaiting__"..option2),
      jumpTo = GUI.find_relative(e, "jumpTo__"..option2),
      jumpToCircuit = GUI.find_relative(e, "jumpToCircuit__"..option2),
    }
  end,

  save_station_options = function(opts, index, option2)
    local rules = global.guiData[index].rules[tonumber(option2)] or {}

    rules.empty = opts.leaveEmpty.state
    rules.full = opts.leaveFull.state
    rules.requireBoth = opts.requireBoth.state
    rules.waitForCircuit = opts.waitForCircuit.state
    rules.keepWaiting = opts.keepWaiting.state
    rules.jumpToCircuit = opts.jumpToCircuit.state

    rules.jumpTo = opts.jumpTo.text

    global.guiData[index].rules[tonumber(option2)] = rules
  end,
}

function sanitizeName(name)
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
end

function sanitizeNumber(number, default)
  return tonumber(number) or default
end

function sanitize_rules(player, line, rules, page)
  --local page = global.playerRules[player.index].page or 1
  local upper = page*global.settings.rulesPerPage
  local lower = page*global.settings.rulesPerPage-global.settings.rulesPerPage

  local gui = player.gui[GUI.position].stGui.dynamicRules.frm.tbl
  local tmp = {}
  for i,rule in pairs(global.trainLines[line].records) do
    if global.guiData[player.index].rules[i] then
      tmp[i] = global.guiData[player.index].rules[i]
      if i>lower and i<=upper then
        tmp[i].jumpTo = sanitizeNumber(gui["padding_frame__jumpTo__"..i]["jumpTo__"..i].text, false) or false
        
        if not (tmp[i].empty or tmp[i].full or tmp[i].waitForCircuit) then
          tmp[i].keepWaiting = false
        end
        tmp[i].station = rule.station
      end
    else
      tmp[i] = {jumpTo=false, empty=false,full=false,waitForCircuit=false,keepWaiting=false,station=false}
    end
  end
  return tmp
end

on_gui_click = {
  on_gui_click = function(event)
    local elementName = event.element.name
    local status, err = pcall(function()
      local player = game.players[event.player_index]
      local refresh = false
      local element = event.element
      local trainInfo = global.trains[getTrainKeyFromUI(event.player_index)]

      if on_gui_click[element.name] then
        refresh = on_gui_click[element.name](player)
      else
        local option1, option2, option3, option4 = event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
        if on_gui_click[option1] then
          refresh = on_gui_click[option1](player, option2, option3, element)
        end
      end
      if refresh then
        GUI.create_or_update(trainInfo,event.player_index)
      end
    end)
    if not status then
      pauseError(err, {"on_gui_click", elementName})
    end
  end,

  toggleSTSettings = function(player)
    if player.gui[GUI.position].stGui.rows.globalSettings == nil then
      GUI.globalSettingsWindow(player.index)
      GUI.destroyGui(player.gui[GUI.position].stGui.rows.toggleSTSettings)
      GUI.destroyGui(player.gui[GUI.position].stGui.rows.dynamicRules)
      GUI.destroyGui(player.gui[GUI.position].stGui.rows.trainSettings)
      GUI.destroyGui(player.gui[GUI.position].stGui.rows.trainLines)
      return false
    else
      player.gui[GUI.position].stGui.rows.toggleSTSettings.destroy()
      return true
    end
  end,

  globalSettingsSave = function(player)
    local settings = player.gui[GUI.position].stGui.rows.globalSettings.tbl
    local time = sanitizeNumber(settings.refuelTime.text, global.settings.refuel.time/60)*60
    local min = sanitizeNumber(settings.refuelRangeMin.text, global.settings.refuel.rangeMin)
    local max = sanitizeNumber(settings.row1.refuelRangeMax.text, global.settings.refuel.rangeMax)
    local station = settings.refuelStation.text
    global.settings.refuel = {time=time, rangeMin = min, rangeMax = max, station = station}

    local interval = sanitizeNumber(settings.departInterval.text, global.settings.depart.interval/60)*60
    local minWait = sanitizeNumber(settings.minWait.text, global.settings.depart.minWait/60)*60
    local minFlow = sanitizeNumber(settings.minFlow.text, global.settings.depart.minFlow)
    local circuitInterval = sanitizeNumber(settings.circuitInterval.text,global.settings.circuit.interval)
    if circuitInterval < 1 then circuitInterval = 1 end

    global.settings.depart = {interval = interval, minWait = minWait}
    global.settings.depart.minFlow = minFlow
    global.settings.circuit.interval = circuitInterval

    return true
  end,

  deleteLines = function(player)
    local group = player.gui[GUI.position].stGui.rows.trainLines.tbl1
    local trainKey
    for i, child in pairs(group.children_names) do
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
    global.playerPage[player.index].line = 1
    return true
  end,

  nextPageRule = function(player)
    local line = global.guiData[player.index].line
    local maxPage = page_count(#global.trainLines[line].records, global.settings.rulesPerPage)
    local page = global.playerRules[player.index].page
    global.guiData[player.index].rules = sanitize_rules(player,line,global.guiData[player.index].rules, page)
    page = page < maxPage and page + 1 or page
    global.playerRules[player.index].page = page
    GUI.showDynamicRules(player.index,line)
    return false
  end,

  prevPageRule = function(player)
    local line = global.guiData[player.index].line
    local page = global.playerRules[player.index].page
    global.guiData[player.index].rules = sanitize_rules(player,line,global.guiData[player.index].rules, page)
    page =  page > 1 and page - 1 or 1
    global.playerRules[player.index].page = page
    GUI.showDynamicRules(player.index,line)
    return false
  end,

  renameLine = function(player)
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
      newName = sanitizeName(newName)
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
      return true
    end
    return false
  end,

  refuel = function(player, option2)
    option2 = tonumber(option2)
    global.trains[option2].settings.autoRefuel = not global.trains[option2].settings.autoRefuel
  end,

  depart = function(player, option2)
    option2 = tonumber(option2)
    global.trains[option2].settings.autoDepart = not global.trains[option2].settings.autoDepart
  end,

  editRules = function(player, option2)
    --GUI.destroyGui(player.gui[GUI.position].stGui.settings.toggleSTSettings)
    GUI.destroyGui(player.gui[GUI.position].stGui.rows.trainSettings)
    global.guiData[player.index].rules = false
    global.playerRules[player.index].page = 1
    GUI.showDynamicRules(player.index,option2)
  end,

  saveRules = function(player, option2)
    local line = option2
    --local gui = player.gui[GUI.position].stGui.dynamicRules.frm.tbl
    local textfield = player.gui[GUI.position].stGui.dynamicRules.frm.rulesFlow["lineNumber__"..line]
    global.trainLines[line].number = math.floor(sanitizeNumber(textfield.text,0))
    local tmp = {}
    global.guiData[player.index].rules = sanitize_rules(player,line,global.guiData[player.index].rules, global.playerRules[player.index].page)
    global.trainLines[line].rules = table.deepcopy(global.guiData[player.index].rules)
    global.guiData[player.index].rules = false
    global.playerRules[player.index].page = 1
    debugDump("Saved line "..line.." with "..#global.trainLines[line].records.." stations",true)
    GUI.destroyGui(player.gui[GUI.position].stGui.dynamicRules)
    return true
  end,

  readSchedule = function(player, option2)
    option2 = tonumber(option2)
    if global.trains[option2] ~= nil and global.trains[option2].train.valid then
      global.trains[option2].line = false
      global.trains[option2].lineVersion = false
    end
    return true
  end,

  saveAsLine = function(player, option2)
    local name = player.gui[GUI.position].stGui.rows.trainSettings.rows.btns.saveAslineName.text
    name = sanitizeName(name)
    if name ~= false then
      option2 = tonumber(option2)
      local t = global.trains[option2]
      local is_copy = t.line and t.line ~= name
      local empty_rule = {
        empty = false,
        full = false,
        jumpTo = false,
        jumpToCircuit = false,
        keepWaiting = false,
        original_time = 30*60,
        station = "",
        waitForCircuit = false,
      }
      
      if name ~= "" and t and t.train.valid and #t.train.schedule.records > 0 then
        --new train line
        if not global.trainLines[name] then
          global.trainLines[name] = {name=name, number=0, rules={}}
          local rules = global.trainLines[name].rules
          for s_index, record in pairs(t.train.schedule.records) do
            local rule = table.deepcopy(empty_rule)
            rule.original_time = record.time_to_wait
            rule.station = record.station
            rules[s_index] = rule
          end
        end
        
        local changed = game.tick
        global.trainLines[name].settings = {autoRefuel = t.settings.autoRefuel, autoDepart = t.settings.autoDepart}
        global.trainLines[name].records = t.train.schedule.records
        global.trainLines[name].changed = changed

        if is_copy then
          global.trainLines[name].rules = table.deepcopy(global.trainLines[t.line].rules)
        end
        
        --remove/add rules if needed        
        -- update original_time if time ~= 2^32-1
        local records = global.trainLines[name].records
        local remove_rule = {}
        for r_index, rule in pairs(global.trainLines[name].rules) do
          if records[r_index] and records[r_index].time_to_wait ~= 2^32-1 then
            rule.original_time = records[r_index].time_to_wait
          end
        end
        local max_record = #global.trainLines[name].records+1
        local max_rules = #global.trainLines[name].rules+1
        for i=max_rules,max_record,-1 do
          if global.trainLines[name].rules[i] and not global.trainLines[name].records[i] then
            global.trainLines[name].rules[i] = nil
          end
        end        
        --add missing rules
        for i, record in pairs(records) do
          if not global.trainLines[name].rules[i] then
            local rule = table.deepcopy(empty_rule)
            rule.original_time = record.time_to_wait
            rule.station = record.station
            global.trainLines[name].rules[i] = rule
          end
        end

        t.line = name
        t.lineVersion = changed
      end
    else
      debugDump("Invalid name, only letters, numbers, space, -,#,!,$ are allowed",true)
    end
    return true
  end,

  lineRefuel = function(player, option2)
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
    return true
  end,

  lineDepart = function(player, option2, option3)
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
    return true
  end,

  activeLine = function(player, option2, option3)
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
      local schedule = t.train.schedule
      local rules = global.trainLines[li].rules
      for i, record in pairs(schedule.records) do
        if record.time_to_wait == 2^32-1 then
          record.time_to_wait = 200*60
          if rules and rules[i] then
            record.time_to_wait = rules[i].original_time or record.time_to_wait
          end
        end
      end
      t.train.schedule = schedule
    end
    t.lineVersion = -1
    GUI.create_or_update(t,player.index)
  end,

  prevPageTrain = function(player,option2, option3)
    local page = tonumber(option2)
    page = (page > 1) and page - 1 or 1
    global.playerPage[player.index].schedule = page
    return true
  end,

  nextPageTrain = function(player,option2, option3)
    local page = tonumber(option2)
    global.playerPage[player.index].schedule = page + 1
    return true
  end,

  prevPageLine = function(player,option2, option3)
    local page = tonumber(option2)
    page = (page > 1) and page - 1 or 1
    global.playerPage[player.index].line = page
    return true
  end,

  nextPageLine = function(player,option2, option3)
    local page = tonumber(option2)
    global.playerPage[player.index].line = page + 1
    return true
  end,

  leaveFull = function(player, option2, option3, element)
    local opts = GUI.get_station_options(element, option2)
    
    if element.state == true then
      if opts.leaveEmpty.state == true then
        opts.leaveEmpty.state = false
      end
    end
    if opts.leaveFull.state == false and
      opts.leaveEmpty.state == false and
      opts.waitForCircuit.state == false then
      opts.keepWaiting.state = false
    end
    
    if not opts.waitForCircuit.state or (not opts.leaveEmpty.state and not opts.leaveFull.state) then 
			opts.requireBoth.state = false
		end
    
    GUI.save_station_options(opts, player.index, option2)
  end,

  leaveEmpty = function(player, option2, option3, element)
    local opts = GUI.get_station_options(element, option2)
    
    if element.state == true then
      if opts.leaveFull.state == true then
        opts.leaveFull.state = false
      end
    end
    
    if opts.leaveFull.state == false and
      opts.leaveEmpty.state == false and
      opts.waitForCircuit.state == false then
      opts.keepWaiting.state = false
    end
    
    if not opts.waitForCircuit.state or (not opts.leaveEmpty.state and not opts.leaveFull.state) then 
			opts.requireBoth.state = false
		end
    
    GUI.save_station_options(opts, player.index, option2)
  end,

  keepWaiting = function(player, option2, option3, element)
    local opts = GUI.get_station_options(element, option2)
  
    if opts.leaveFull.state == false and
      opts.leaveEmpty.state == false and
      opts.waitForCircuit.state == false then
        opts.keepWaiting.state = false
    end
  
    GUI.save_station_options(opts, player.index, option2)
  end,  
  
  requireBoth = function(player, option2, option3, element)
    local opts = GUI.get_station_options(element, option2)
  
    if not opts.waitForCircuit.state or (not opts.leaveEmpty.state and not opts.leaveFull.state) then 
			opts.requireBoth.state = false
		end
  
    GUI.save_station_options(opts, player.index, option2)
  end,

  waitForCircuit = function(player, option2, option3, element)
    local opts = GUI.get_station_options(element, option2)

    if opts.leaveFull.state == false and
      opts.leaveEmpty.state == false and
      opts.waitForCircuit.state == false then
        opts.keepWaiting.state = false
    end
    
    if not opts.waitForCircuit.state or (not opts.leaveEmpty.state and not opts.leaveFull.state) then 
			opts.requireBoth.state = false
		end
    
    GUI.save_station_options(opts, player.index, option2)
  end,

  jumpToCircuit = function(player, option2, option3, element)
    local opts = GUI.get_station_options(element, option2)
    
    if opts.leaveFull.state == false and
      opts.leaveEmpty.state == false and
      opts.waitForCircuit.state == false then
      opts.keepWaiting.state = false
    end
    
    GUI.save_station_options(opts, player.index, option2)
  end,
}
