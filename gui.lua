function page_count(item_count, items_per_page)
    return math.floor((item_count - 1) / (items_per_page)) + 1
end

function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
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
    stationMapping = "stationMapping",

    position = "left",

    create_or_update = function(player_index)
        local player = game.players[player_index]
        if player.valid then
            local main = GUI.buildGui(player)
            if player.opened then
                GUI.showSettingsButton(main)
                if player.opened.type == "locomotive" then
                    GUI.showTrainInfoWindow(main, player_index)
                elseif player.opened.type == "train-stop" then
                    if not main.frameMapping or not main.frameMapping.valid then
                        GUI.add(main, { type = "frame", name = "frameMapping", caption = "Station mapping", direction = "vertical", style = "st_frame" })
                    end
                    GUI.showStationMapping(player_index)
                end
                GUI.showTrainLinesWindow(main, player_index)
            else
                GUI.destroy(player_index)
            end
        end
    end,

    buildGui = function (player)
        GUI.destroyGui(player.gui[GUI.position][GUI.windows.root])
        local stGui = GUI.add(player.gui[GUI.position], {type="frame", name="stGui", direction="vertical", style="outer_frame"})
        return GUI.add(stGui, {type="table", name="rows", column_count=1})
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
        local player
        if type(player_index) == "number" then
            player = game.players[player_index]
        else
            player = player_index
        end
        if player.valid then
            GUI.destroyGui(player.gui[GUI.position][GUI.windows.root])
            global.guiData[player.index] = nil
            global.playerRules[player_index].page = 1
        end
    end,

    add = function(parent, e, bind)
        local type = e.type
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

    addLabel = function(parent, e_, bind)
        local e = e_
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
        for _=1,c do
            GUI.add(parent, {type="label", caption=""})
        end
    end,

    globalSettingsWindow = function(index, parent)
        local gui = parent or game.players[index].gui[GUI.position].stGui.rows
        if gui.globalSettings == nil then
            gui.add({type = "frame", name="globalSettings", direction="vertical", caption={"text-st-global-settings"}})
            local refueling = gui.globalSettings.add({type = "frame", name="frm_refueling", direction="horizontal", style = "st_inner_frame", caption = {"stg-refueling"}})

            local coal_min = fuel_value_to_coal(global.settings.refuel.rangeMin)
            local coal_max = fuel_value_to_coal(global.settings.refuel.rangeMax)

            local tbl = refueling.add{type="table", name="tbl", column_count=4}
            GUI.addLabel(tbl, {"stg-refuel-below1"})
            GUI.addTextfield(tbl, {name="refuelRangeMin", style="st_textfield_small", text = global.settings.refuel.rangeMin})
            GUI.addLabel(tbl, {"", {"stg-MJ"}, " ("..coal_min.." ", game.item_prototypes["coal"].localised_name, ")",{"stg-refuel-below2"}})
            local r = GUI.add(tbl, {type="flow", name="row1", direction="horizontal"})
            GUI.addTextfield(r, {name="refuelRangeMax", style="st_textfield_small", text = global.settings.refuel.rangeMax})
            GUI.addLabel(r, {"", {"stg-MJ"}, " ("..coal_max.." ", game.item_prototypes["coal"].localised_name,")"})

            GUI.addLabel(tbl, {"stg-max-refuel-time"})
            GUI.addTextfield(tbl, {name="refuelTime", style="st_textfield_small", text = global.settings.refuel.time / 60})
            GUI.addLabel(tbl,  {"stg-refuel-station"})
            GUI.addTextfield(tbl, {name="refuelStation", style="st_textfield_medium", text = global.settings.refuel.station})

            local intervals = gui.globalSettings.add({type = "frame", name="frm_intervals", direction="horizontal", style = "st_inner_frame", caption = {"stg-intervals"}})
            tbl = intervals.add{type="table", name="tbl", column_count=2, style="st_table"}

            GUI.addLabel(tbl, {"stg-intervals-write"}).style.left_padding = 10
            GUI.addTextfield(tbl, {name="intervals_write", style="st_textfield_small", text = global.settings.intervals.write})

            GUI.addLabel(tbl, {"",{"stg-tracked-trains"}, " ", TrainList.getCount()})
            local noStations, uniqueStations = 0,0
            local force = game.players[index].force.name
            for _,station in pairs(global.stationCount[force]) do
                if station > 0 then
                    noStations = noStations + station
                    uniqueStations = uniqueStations + 1
                end
            end
            GUI.addLabel(tbl,{"", {"lbl-stations"}, ": ", uniqueStations, "/", noStations})

            GUI.addButton(tbl, {name="globalSettingsSave", caption="Save"})
        end
    end,

    showTrainInfoWindow = function(parent, player_index)
        local gui = parent
        if gui.trainSettings ~= nil then
            gui.trainSettings.destroy()
        end
        local t = TrainList.getTrainInfoFromUI(player_index)
        if not t then
            return
        end

        --log(serpent.line(trainInfo))
        --log(serpent.line({kUI=keyUI, trainkey=trainKey, t=t}))
        local trainLine = t.line and global.trainLines[t.line] or false
        local useMapping = trainLine and trainLine.settings.useMapping or false
        gui = GUI.add(gui, {type="frame", name="trainSettings", caption={"", {"lbl-train"}, ": ", t.name, " (", t:getType(),")"}, direction="vertical", style="st_frame"})
        local line = "-"
        local dated = " "
        if trainLine then
            line = trainLine.name
            if trainLine.changed ~= t.lineVersion and
                t.lineVersion >= 0 then dated = {"lbl-outdated"} end
        end
        local tableRows = GUI.add(gui, {type="table", name="rows", column_count=1})
        local checkboxes = GUI.add(tableRows, {type="table", name="checkboxes", column_count=2})
        if not trainLine then
            GUI.add(checkboxes, {type="checkbox", name="btn_refuel__"..t.ID, caption={"lbl-refuel"}, state=t.settings.autoRefuel})
        end
        local tbl = GUI.add(tableRows, {type="table", name="line", column_count=2})
        GUI.addLabel(tbl, {"", {"lbl-active-line"}, ": ", line})
        GUI.addLabel(tbl, {"", " ", dated})
        local lineKey = ""
        local records = t.train.schedule and t.train.schedule.records
        local rules
        if trainLine then
            records = trainLine.records
            rules = trainLine.rules
            lineKey = "__"..trainLine.name
        end
        local tbl1 = GUI.add(tableRows, {type="table", name="tbl1", column_count=3, style="st_table"})
        local spp = global.settings.stationsPerPage
        local page = global.playerPage[player_index].schedule or 1
        if records and #records > 0 then
            GUI.addLabel(tbl1, {"lbl-station"})
            GUI.addLabel(tbl1, {"lbl-leave-when"})
            GUI.addPlaceHolder(tbl1)
            local start = (page-1) * spp + 1
            local max = start + spp - 1
            if max > #records then max = #records end
            for i=start, max do
                local s = records[i]

                local time
                local chunks = {}
                local chunk = {}

                GUI.addLabel(tbl1, i.." "..s.station)
                if s.wait_conditions then
                    for c_index, condition in pairs(s.wait_conditions) do
                        if c_index > 1 then
                            table.insert(chunk, " ")
                            table.insert(chunk, condition.compare_type == "or" and {"lbl-or"} or "&")
                            table.insert(chunk, " ")
                        end
                        if condition.type == "time" then
                            table.insert(chunk, {"lbl-time", math.floor(condition.ticks/60)})
                        elseif condition.type == "circuit" then
                            table.insert(chunk, {"lbl-wait-for-circuit"})
                        else
                            table.insert(chunk, {"lbl-"..condition.type})
                        end

                    end
                end
                --local time = (trainLine and rules[i] and rules[i].keepWaiting) and {"lbl-forever"} or (s.time_to_wait > 12010 and {"lbl-forever"}) or math.floor(s.time_to_wait/60)
                table.insert(chunks, chunk)
                if rules then
                    local rule = rules[i]
                    if rule.jumpToCircuit or rule.jumpTo then
                        table.insert(chunk, ": ")
                    end

                    if rule.jumpToCircuit then
                        table.insert(chunk, {"lbl-jump-to-signal"})
                        if rule.jumpTo then
                            table.insert(chunk, " or ")
                        end
                    end

                    if rule.jumpTo and not useMapping and rule.jumpTo <= #records then
                        table.insert(chunks, {{"lbl-jump-to"}, "", rule.jumpTo})
                    elseif rule.jumpTo and useMapping and global.stationMap[game.players[player_index].force.name][rule.jumpTo] then
                        local mappedID = t:get_first_matching_station(rule.jumpTo, i)
                        if mappedID and mappedID>0 then
                            table.insert(chunks, {{"lbl-jump-to"}, "", mappedID , " (mapped #", rule.jumpTo, ')'})
                        else
                            table.insert(chunks, {"invalid #", " (mapped #", rule.jumpTo, ')'}) --TODO: localisation
                        end
                    elseif rule.jumpTo then
                        table.insert(chunks, {"invalid #"}) --TODO: localisation
                    end
                end
                local text = {""}
                for _, chunk_ in pairs(chunks) do
                    for _, bit in pairs(chunk_) do
                        table.insert(text, bit)
                    end
                end
                GUI.addLabel(tbl1, text)
                GUI.addPlaceHolder(tbl1)
            end
        end
        local btns = GUI.add(tableRows,{type="table", name="btns", column_count=2})

        local pages = GUI.add(btns, {type="flow", name="pages", direction="horizontal", style = "st_flow"})
        if records and #records > spp then
            if page > 1 then
                GUI.addButton(pages, {name = "firstPageTrain", caption = "|<", style = "st_page_button"})
                GUI.addButton(pages, {name="prevPageTrain__"..page, caption="<", style="st_page_button"})
            else
                GUI.addButton(pages, {caption = "|<", style = "st_page_button_disabled"})
                GUI.addButton(pages, {name="asdfFoo", caption="<", style="st_page_button_disabled"})
            end
            GUI.addButton(pages, {caption=page.."/"..math.ceil(#records/spp), style="st_page_button_disabled"})
            if math.ceil(#records/spp) >= page+1 then
                GUI.addButton(pages, {name="nextPageTrain__"..page, caption=">", style="st_page_button"})
                GUI.addButton(pages, {name = "lastPageTrain", caption = ">|", style = "st_page_button"})
            else
                GUI.addButton(pages, {name="asdfFoo2", caption= ">", style="st_page_button_disabled"})
                GUI.addButton(pages, {caption = ">|", style = "st_page_button_disabled"})
            end
        else
            GUI.addPlaceHolder(pages)
        end
        GUI.addPlaceHolder(btns)
        local buttonFlow = GUI.add(btns, {type = "flow", name = "btnFlow", direction = "horizontal"})
        GUI.addButton(buttonFlow, {name="saveAsLine__"..t.ID..lineKey, caption={"lbl-save-as-line"}})
        local line_ = GUI.addTextfield(buttonFlow, {name="saveAslineName", text="", style="st_textfield_big"})
        if trainLine then
            line_.text = trainLine.name
        end
    end,

    showTrainLinesWindow = function(gui, player_index)
        local trainInfo = TrainList.getTrainInfoFromUI(player_index)
        local trainKey = trainInfo and trainInfo.ID or 0
        if gui.trainLines ~= nil then
            gui.trainLines.destroy()
        end
        local page = global.playerPage[player_index].line or 1
        local c_lines=0
        local trainCount = {}
        for l,_ in pairs(global.trainLines) do
            trainCount[l] = 0
            c_lines = c_lines+1
        end
        if global.trainLines and c_lines > 0 then
            trainKey = trainKey or 0
            gui = GUI.add(gui, {type="frame", name="trainLines", caption={"lbl-trainlines"}, direction="vertical", style="st_frame"})
            local tbl = GUI.add(gui, {type="table", name="tbl1", column_count=8})
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
            GUI.addPlaceHolder(tbl)
            local dirty = 0
            local spp = global.settings.linesPerPage
            local start = (page-1) * spp + 1
            local max = start + spp - 1
            for _,t in pairs(global.trains) do
                if t.line and trainCount[t.line] then
                    trainCount[t.line] = trainCount[t.line] + 1
                end
            end
            local c_trains
            for i, l in pairsByKeys(global.trainLines, sortByName) do
                dirty= dirty+1
                if dirty >= start and dirty <= max then
                    c_trains = trainCount[l.name] or 0
                    --log(serpent.block(l,{comment=false}))
                    GUI.addLabel(tbl, l.name)
                    GUI.addLabel(tbl, l.records[1].station)
                    GUI.addLabel(tbl, #l.records)
                    GUI.addLabel(tbl, c_trains)
                    if trainKey > 0 then
                        GUI.add(tbl, {type="checkbox", name="activeLine__"..i.."__"..trainKey, state=(i==trainInfo.line), style="st_checkbox"})
                    else
                        GUI.addPlaceHolder(tbl)
                    end
                    GUI.add(tbl, {type="checkbox", name="markedDelete__"..i.."__"..trainKey, state=false})
                    GUI.add(tbl,{type="checkbox", name="lineRefuel__"..i.."__"..trainKey, state=l.settings.autoRefuel})
                    GUI.addButton(tbl, {name="editRules__"..i, caption={"lbl-rules"}, style="st_button_style_bold"})
                end
            end

            local buttonFlow = GUI.add(gui,{name="buttonFlow", type="flow"})
            local pageButtons = GUI.add(buttonFlow, {name="btns", type="flow", style = "st_flow"})
            if dirty > spp then
                if page > 1 then
					GUI.addButton(pageButtons, {name="prevPageLine__"..page, caption="<", style="st_page_button"})
                else
                    GUI.addButton(pageButtons, {caption="<", style="st_page_button_disabled"})
                end
                GUI.addButton(pageButtons, {caption=page.."/"..math.ceil(dirty/spp), style="st_page_button_disabled"})
                if max < c_lines then
                    GUI.addButton(pageButtons, {name="nextPageLine__"..page, caption=">",style="st_page_button"})
                else
                    GUI.addButton(pageButtons, {caption=">", style="st_page_button_disabled"})
                end
            end
            if dirty == 0 then gui.destroy() end
            GUI.addButton(buttonFlow, {name="deleteLines", caption={"lbl-delete-marked"}})
            GUI.addButton(buttonFlow,{name="renameLine", caption={"lbl-rename"}})
            GUI.addTextfield(buttonFlow,{name="newName", text="", style="st_textfield_big"})
        end
    end,

    showStationMapping = function(player_index)
        local player = game.players[player_index]
        local gui = player.gui[GUI.position].stGui.rows.frameMapping
        if gui.stationMapping ~= nil then
            gui.stationMapping.destroy()
        end
        if gui.buttonFlow ~= nil then
            gui.buttonFlow.destroy()
        end
        local guiData = global.guiData[player_index]
        guiData.mapping = guiData.mapping or {}
        local page = global.playerPage[player_index].mapping or 1
        local c=0
        for _, count in pairs(global.stationCount[player.force.name]) do
            if count then -- count could be 0 for stations that are still in a line but have no actual/existing station anymore
                c = c+1
            end
        end
        local dirty = 1
        local spp = global.settings.mappingsPerPage
        local start = (page-1) * spp + 1
        local max = start + spp - 1

        local tbl = GUI.add( gui, { type = "table", name = "stationMapping", column_count = 5 } )
        local c1 = 1

        for name, count in pairsByKeys(global.stationCount[player.force.name], sortByName) do
            if dirty >= start and dirty <= max then
                GUI.add( tbl, { type = "label", name = "station_map_label_" .. c1, caption = name } )
                local text = global.guiData[player_index].mapping[name] or ""
                GUI.add( tbl, { type = "textfield", name = "station_map_" .. c1, style = "st_textfield_small", text = text } )
                if c1 % 2 == 1 then
                    GUI.add( tbl, { type = "label", caption = "   "})
                end
                c1 = c1 + 1
            end
            dirty= dirty+1
        end


        local buttonFlow = GUI.add(gui,{name="buttonFlow", type="flow"})
        local btns = GUI.add(buttonFlow, {name="pageButtons", type="flow", style = "st_flow"})

        if dirty > spp then
            if page > 1 then
                GUI.addButton(btns, {name="firstPageMapping", caption="|<", style="st_page_button"})
                GUI.addButton(btns, {name="prevPageMapping__"..page, caption="<", style="st_page_button"})
            else
                GUI.addButton(btns, {caption="|<", style="st_page_button_disabled"})
                GUI.addButton(btns, {caption="<", style="st_page_button_disabled"})
            end
            GUI.addButton(btns, {caption=page.."/"..math.ceil(dirty/spp), style="st_page_button_disabled"})
            if max < c then
                GUI.addButton(btns, {name="nextPageMapping__"..page, caption=">",style="st_page_button"})
                GUI.addButton(btns,{name="lastPageMapping", caption=">|", style="st_page_button"})
            else
                GUI.addButton(btns, {caption=">", style="st_page_button_disabled"})
                GUI.addButton(btns,{caption=">|", style="st_page_button_disabled"})
            end
        end
        GUI.addButton( buttonFlow, { caption = "Save", name = "saveMapping" } )
    end,

    showDynamicRules = function(index, line, rule_button, stay_opened)
        --debugDump({i=index,line=line,station=stationKey, tr=trainKey}, true)
        local gui = game.players[index].gui[GUI.position].stGui
        local guiData = global.guiData[index]
        if gui.dynamicRules ~= nil then
            gui.dynamicRules.destroy()
            if guiData.line == line then
                if guiData.rules_button and guiData.rules_button.valid then
                    guiData.rules_button.style = "st_button_style_bold"
                end
                if not stay_opened then
                    --log("not stay open")
                    guiData.line = false
                    guiData.line_number = false
                    guiData.use_mapping = false
                    return
                end
            end
        end
        if line and global.trainLines[line] then
            local records = guiData.records
            local rules = guiData.rules

            if rule_button and rule_button.valid then
                rule_button.style = "st_selected_button"
                guiData.rules_button = rule_button
            end
            guiData.line = line
            local lineName = global.trainLines[line].name
            local line_number = guiData.line_number
            local use_mapping = guiData.use_mapping

            gui = GUI.add(gui, {type="frame", name="dynamicRules", direction="vertical", style="st_frame"})
            gui = GUI.add(gui, {type="frame", name="frm", direction="vertical", style="st_inner_frame"})
            local flow = GUI.add(gui, {type="flow", name="rulesFlow", direction="horizontal"})
            GUI.addLabel(flow, {name="line", caption="Line: "..lineName}) --TODO localisation
            GUI.addLabel(flow, {name="line_number", caption="#: "})
            GUI.addTextfield( flow, {name="lineNumber__"..line, style="st_textfield_small", text=line_number})
            GUI.add( flow, { type = "checkbox", name = "useMapping__" .. line, style = "st_checkbox", caption = "use station mapping", state = use_mapping } ) --TODO localisation

            local tbl = GUI.add(gui,{type="table", name="tbltophdr", column_count=3, style="st_table"})

            GUI.addPlaceHolder(tbl,1)
            GUI.add(tbl, {name="tophdr_flow1", type="flow", direction="horizontal"})

            local top_hdr2 = GUI.add(tbl, {name="tophdr_flow2", type="flow", direction="horizontal"})
            GUI.addLabel(top_hdr2, {caption="    "})
            GUI.addLabel(top_hdr2, {caption={"lbl-go-to-header"}, style="st_label_bold"})


            GUI.addPlaceHolder(tbl,1)
            GUI.add(tbl, {name="tophdr_flow3", type="flow", direction="horizontal"})

            local test_table2 = GUI.add(tbl, {name="tophdr_flow4", type="flow", direction="horizontal"})

            GUI.addLabel(test_table2, {caption={"lbl-jump-to-signal-header"}, style="st_label_bold"})
            GUI.addLabel(test_table2, {caption="   "})

            GUI.addLabel(test_table2, {caption={"lbl-jump-to-header"}, style="st_label_bold"})
            GUI.addLabel(test_table2, {caption="   "})

            local page = global.playerRules[index].page or 1
            local upper = page*global.settings.rulesPerPage
            local lower = page*global.settings.rulesPerPage-global.settings.rulesPerPage
            for i,s in pairs(records) do
                if i>lower and i<=upper then
                    local rule = rules[i]
                    local states = {
                        jumpToCircuit = rule and rule.jumpToCircuit or false,
                        jumpTo = (rule and rule.jumpTo) and rule.jumpTo or "",
                    }

                    GUI.addLabel(tbl, {caption="#" .. i .. " " .. s.station, style="st_label_bold"})
                    GUI.add(tbl, {name="rules_flow_a"..i, type="flow", direction="horizontal"})

                    local record1 = GUI.add(tbl, {name="rules_flow_b"..i, type="flow", direction="horizontal"})
                    GUI.add(record1,{type="checkbox", name="jumpToCircuit__"..i, style="st_checkbox", state=states.jumpToCircuit, left_padding=15})
                    GUI.addLabel(record1, {caption="           "})

                    GUI.addTextfield(record1, {name="jumpTo__"..i, text=states.jumpTo, style="st_textfield_small", left_padding=8})
                end
            end

            local buttonFlow = GUI.add(gui,{name="buttonFlow", type="flow"})
            local pageButtons = GUI.add(buttonFlow, {name="pageButtons", type="flow", style = "st_flow"})

            local firstPage = GUI.addButton(pageButtons,{name="firstPageRule", caption="|<", style="st_page_button"})
            local prevPage = GUI.addButton(pageButtons,{name="prevPageRule", caption="<", style="st_page_button"})
            if page == 1 then
                firstPage.style = "st_page_button_disabled"
                prevPage.style = "st_page_button_disabled"
            end

            local maxPage = page_count(#records, global.settings.rulesPerPage)
            GUI.addButton(pageButtons,{name="rule_page_number", caption=page.."/"..maxPage, style="st_disabled_button_bold"})

            local nextPage = GUI.addButton(pageButtons, {name="nextPageRule", caption=">", style="st_page_button"})
            local lastPage = GUI.addButton(pageButtons, {name = "lastPageRule", caption = ">|", style = "st_page_button"})
            if page == maxPage then
                nextPage.style = "st_page_button_disabled"
                lastPage.style = "st_page_button_disabled"
            end

            GUI.addButton(buttonFlow, {name="saveRules__"..line, caption="Save", style="st_button_style_bold"})
        end
    end,

    find_relative = function(e, name_, option2, flow)
        local name = name_..option2
        return e.parent.parent.parent["rules_flow_"..flow..option2]["padding_frame__"..name][name]
    end,

    get_station_options = function(e, option2)
        return {
            jumpToCircuit   = GUI.find_relative(e, "jumpToCircuit__", option2, "b"),
            jumpTo          = GUI.find_relative(e, "jumpTo__", option2, "b"),
        }
    end,

    get_mapping_from_gui = function(player)
        local tbl = player.gui[GUI.position].stGui.rows.frameMapping.stationMapping
        --local tbl = element.parent.parent.stationMapping
        local mappings = tbl.children_names
        for _, name in pairs(mappings) do
            if string.starts_with(name, "station_map_label_") then
                local i = tonumber(name:match("station_map_label_*(%w*)"))
                local station = tostring(tbl[name].caption)
                local text = trim(tbl["station_map_" .. i].text)
                if text ~= "" then
                    text = tonumber(text)
                else
                    text = false
                end

                if text == nil then
                    -- no valid number, restore from saved mapping
                    text = global.stationMapping[player.force.name][station]
                    player.print("Invalid mapping for "..station..", '" .. tbl["station_map_" .. i].text .. "' is not a number") --TODO localisation
                end
                global.guiData[player.index].mapping[station] = text or false
            end
        end
    end,

    save_station_options = function(opts, index, option2)
        local rules = global.guiData[index].rules[tonumber(option2)] or {}

        rules.jumpToCircuit = opts.jumpToCircuit.state
        rules.jumpTo = opts.jumpTo.text

        global.guiData[index].rules[tonumber(option2)] = rules
    end,
}

function sanitizeName(name_)
    local name = string.gsub(name_, "_", " ")
    name = string.gsub(name, "^%s", "")
    name = string.gsub(name, "%s$", "")
    local pattern = "(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)"
    local element = "activeLine__"..name.."__".."something"
    local t1,t2,t3,_ = element:match(pattern)
    if t1 == "activeLine" and t2 == name and t3 == "something" then --TODO something?? really..
        return name
    else
        return false
    end
end

function sanitizeNumber(number, default)
    number = tonumber(number)
    return (number ~= "" and number) or default
end

function sanitize_rules(player, line, rules, page)
    --local page = global.playerRules[player.index].page or 1
    local upper = page*global.settings.rulesPerPage
    local lower = page*global.settings.rulesPerPage-global.settings.rulesPerPage

    local gui = player.gui[GUI.position].stGui.dynamicRules.frm.tbltophdr
    for i, rule in pairs(rules) do
        if i>lower and i<=upper  and gui["rules_flow_b"..i] then
            rule.jumpTo = sanitizeNumber(gui["rules_flow_b"..i]["padding_frame__jumpTo__"..i]["jumpTo__"..i].text, false) or false
            rule.station = tostring(global.trainLines[line].records[i].station)
        end
    end

    return rules
end

on_gui_checked_state_changed = {
    on_gui_checked_state_changed = function(event)
        log("on checked: " .. serpent.block(event.element.name))
        log("state: " .. serpent.block(event.element.state))

        local elementName = event.element.name
        local status, err = pcall(function()
            local player = game.players[event.player_index]
            local refresh = false
            local element = event.element

            if on_gui_checked_state_changed[element.name] then
                log("Element name:" .. element.name)
                refresh = on_gui_checked_state_changed[element.name](player)
            else
                local option1, option2, option3, _ = event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
                log("Options: " .. serpent.line(option1) .. " " .. serpent.line(option2) .. " " .. serpent.line(option3))
                if on_gui_checked_state_changed[option1] then
                    refresh = on_gui_checked_state_changed[option1](player, option2, option3, element)
                end
            end
            if refresh then
                GUI.create_or_update(event.player_index)
            end
        end)
        if not status then
            pauseError(err, {"on_gui_click", elementName})
        end
    end,

    jumpToCircuit = function(player, option2, _, element)
        local opts = GUI.get_station_options(element, option2)
        log("get_station_options")
        log(serpent.block(opts))
        GUI.save_station_options(opts, player.index, option2)
    end,

    refuel = function(_, option2, _, element)
        option2 = tonumber(option2)
        global.trains[option2].settings.autoRefuel = element.state--not global.trains[option2].settings.autoRefuel
    end,

    activeLine = function(player, option2, option3)
        local trainKey = tonumber(option3)
        local li = option2
        local t = global.trains[trainKey]
        if t.line ~= li then
            t.line = li
            t.lineVersion = -1
            if t.train.speed == 0 then
                if not t:updateLine() then
                    t.scheduleUpdate = game.tick + 60
                    insertInTable(global.scheduleUpdate, t.scheduleUpdate, t)
                end
            end
        else
            t.line = false
            local schedule = t.train.schedule
            t.train.schedule = schedule
        end
        t.lineVersion = -1
        GUI.create_or_update(player.index)
    end,

    lineRefuel = function(_, option2, option3)
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
}

on_gui_click = {
    add_trains_to_update = function(line, newConditions)
        if not newConditions then return end
        for i, train in pairs(global.trains) do
            if train and train.line and train.line == line and train.train.valid
                and train.train.state == defines.train_state.wait_station and not train.opened then
                if newConditions[train.train.schedule.current] then
                    local schedule = train.train.schedule
                    schedule.records[train.train.schedule.current].wait_conditions = newConditions[train.train.schedule.current]
                    train.train.schedule = schedule
                end
            end
        end
    end,

    on_gui_click = function(event)
        if event.element.type == "checkbox" then
            return
        end

        local elementName = event.element.name
        local status, err = pcall(function()
            local player = game.players[event.player_index]
            local refresh = false
            local element = event.element

            if on_gui_click[element.name] then
                refresh = on_gui_click[element.name](player)
            else
                local option1, option2, option3, _ = event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
                if on_gui_click[option1] then
                    refresh = on_gui_click[option1](player, option2, option3, element)
                end
            end
            if refresh then
                GUI.create_or_update(event.player_index)
            end
        end)
        if not status then
            pauseError(err, {"on_gui_click", elementName})
        end
    end,

    toggleSTSettings = function(player)
        if player.gui[GUI.position].stGui.rows.globalSettings == nil then
            GUI.globalSettingsWindow(player.index)
            GUI.destroyGui(player.gui[GUI.position].stGui.rows.frameMapping)
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
        local settings = player.gui[GUI.position].stGui.rows.globalSettings

        local refueling = settings.frm_refueling.tbl
        local time = sanitizeNumber(refueling.refuelTime.text, global.settings.refuel.time/60)*60
        local min = sanitizeNumber(refueling.refuelRangeMin.text, global.settings.refuel.rangeMin)
        local max = sanitizeNumber(refueling.row1.refuelRangeMax.text, global.settings.refuel.rangeMax)
        local station = refueling.refuelStation.text
        global.settings.refuel = {time=time, rangeMin = min, rangeMax = max, station = station}

        local intervals = settings.frm_intervals.tbl
        local i_inactivity = 120 --sanitizeNumber(intervals.intervals_inactivity.text, global.settings.intervals.inactivity)
        local i_write = sanitizeNumber(intervals.intervals_write.text, global.settings.intervals.write)

        if i_write < 1 then i_write = 1 end

        global.settings.intervals = {write = i_write, inactivity = i_inactivity}

        return true
    end,

    deleteLines = function(player)
        local group = player.gui[GUI.position].stGui.rows.trainLines.tbl1
        local trainKey
        for _, child in pairs(group.children_names) do
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
        update_station_numbers()
        return true
    end,

    prepareRulesWindow = function(player)
        local guiData = global.guiData[player.index]
        local line = guiData.line
        local maxPage = page_count(#global.trainLines[line].records, global.settings.rulesPerPage)
        local page = global.playerRules[player.index].page

        local rulesFlow = player.gui[GUI.position].stGui.dynamicRules.frm.rulesFlow
        local textfield = rulesFlow["lineNumber__"..line]
        guiData.line_number = math.floor(sanitizeNumber(textfield.text,0))
        local use_mapping = rulesFlow["useMapping__" .. line].state
        guiData.use_mapping = use_mapping

        guiData.rules = sanitize_rules(player,line,guiData.rules, page)

        return guiData, page, maxPage, line
    end,

    nextPageRule = function(player)
        local guiData, page, maxPage, line = on_gui_click.prepareRulesWindow(player)

        page = page < maxPage and page + 1 or page
        global.playerRules[player.index].page = page
        GUI.showDynamicRules(player.index, line, guiData.rules_button, true)
        return false
    end,

    prevPageRule = function(player)
        local guiData, page, maxPage, line = on_gui_click.prepareRulesWindow(player)

        page =  page > 1 and page - 1 or 1
        global.playerRules[player.index].page = page
        GUI.showDynamicRules(player.index, line, guiData.rules_button, true)
        return false
    end,

    firstPageRule = function(player)
        local guiData, page, maxPage, line = on_gui_click.prepareRulesWindow(player)

        page =  1
        global.playerRules[player.index].page = page
        GUI.showDynamicRules(player.index, line, guiData.rules_button, true)
        return false
    end,

    lastPageRule = function(player)
        local guiData, page, maxPage, line = on_gui_click.prepareRulesWindow(player)

        page =  maxPage
        global.playerRules[player.index].page = page
        GUI.showDynamicRules(player.index, line, guiData.rules_button, true)
        return false
    end,

    renameLine = function(player)
        local group = player.gui[GUI.position].stGui.rows.trainLines.tbl1
        local rename
        local count=0
        local newName = player.gui[GUI.position].stGui.rows.trainLines.buttonFlow.newName.text
        for _, child in pairs(group.children_names) do
            local pattern = "(markedDelete)__([%w%s%-%#%!%$]*)_*(%d*)"
            local del, line, _ = child:match(pattern)
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
                    for _,t in pairs(global.trains) do
                        if t.line == rename then
                            t.line = newName
                        end
                    end
                end
            else
                debugDump("Invalid name, only letters, numbers, space, -,#,!,$ are allowed",true) --TODO localisation
            end
            update_station_numbers()
            return true
        end
        update_station_numbers()
        return false
    end,

    editRules = function(player, option2, _, element)
        --GUI.destroyGui(player.gui[GUI.position].stGui.settings.toggleSTSettings)
        GUI.destroyGui(player.gui[GUI.position].stGui.rows.trainSettings)
        local guiData = global.guiData[player.index]
        if guiData.rules_button and guiData.rules_button.valid then
            guiData.rules_button.style = "st_button_style_bold"
        end
        --log("write rules to guiData")
        local line = global.trainLines[option2]

        guiData.line_number = line.settings.number
        guiData.use_mapping = line.settings.useMapping
        guiData.records = table.deepcopy(line.records)
        guiData.rules = table.deepcopy(line.rules)
        global.playerRules[player.index].page = 1
        GUI.showDynamicRules(player.index, option2, element)
    end,

    saveRules = function(player, option2)
        local line = option2
        local trainline = global.trainLines[line]
        --local gui = player.gui[GUI.position].stGui.dynamicRules.frm.tbl
        local rulesFlow = player.gui[GUI.position].stGui.dynamicRules.frm.rulesFlow
        local textfield = rulesFlow["lineNumber__"..line]
        trainline.settings.number = math.floor(sanitizeNumber(textfield.text,0))

        local use_mapping = rulesFlow["useMapping__" .. line].state
        trainline.settings.useMapping = use_mapping
        trainline.rules = table.deepcopy(sanitize_rules(player, line, global.guiData[player.index].rules, global.playerRules[player.index].page))
        trainline.changed = game.tick


        global.guiData[player.index] = {}
        global.playerRules[player.index].page = 1
        debugDump("Saved line "..line.." with "..#global.trainLines[line].records.." stations",true)
        GUI.destroyGui(player.gui[GUI.position].stGui.dynamicRules)

        return true
    end,

    saveAsLine = function(player, option2)
        local name = player.gui[GUI.position].stGui.rows.trainSettings.rows.btns.btnFlow.saveAslineName.text
        name = sanitizeName(name)
        if name ~= false then
            option2 = tonumber(option2)
            local t = global.trains[option2]
            local is_copy = t.line and t.line ~= name
            if not t.train.schedule or not t.train.schedule.records then
                player.print("Train has no stations in the schedule") --TODO localization
                return
            end

            if name ~= "" and t and t.train.valid and #t.train.schedule.records > 0 then
                local records = util.table.deepcopy(t.train.schedule.records)
                --new train line
                if not global.trainLines[name] then
                    global.trainLines[name] = {name=tostring(name), settings = {autoRefuel = false, useMapping = false, number = 0} }
                end

                local trainline = global.trainLines[name]
                local rules = trainline and util.table.deepcopy(trainline.rules) or {}
                for s_index, record in pairs(records) do
                    if record.station then
                        record.station = tostring(record.station)
                    end
                    record.wait_conditions = record.wait_conditions or {}
                    rules[s_index] = rules[s_index] or {}

                    rules[s_index].empty = nil
                    rules[s_index].full = nil
                    rules[s_index].circuit = nil
                    rules[s_index].inactivity = nil

                    for c_index, condition in pairs(record.wait_conditions) do
                        if condition.type == "full" then
                            rules[s_index].full = true
                        end
                        if condition.type == "empty" then
                            rules[s_index].empty = true
                        end
                        if condition.type == "inactivity" then
                            rules[s_index].inactivity = true
                        end
                        if condition.type == "circuit" then
                            rules[s_index].circuit = true
                        end
                    end
                end

                local update_conditions = function(record, rule)
                    local new_rule = table.deepcopy(rule)
                    new_rule.empty = nil
                    new_rule.full = nil
                    new_rule.circuit = nil
                    new_rule.inactivity = nil
                    for c_index, condition in pairs(record.wait_conditions) do
                        if condition.type == "full" then
                            new_rule.full = true
                        end
                        if condition.type == "empty" then
                            new_rule.empty = true
                        end
                        if condition.type == "inactivity" then
                            new_rule.inactivity = true
                        end
                        if condition.type == "circuit" then
                            new_rule.circuit = true
                        end
                    end
                    new_rule.station = record.station
                    return new_rule
                end

                local new_rules = table.deepcopy(rules)
                local diff = {}
                local new_station
                local old_records_by_name = {}
                local new_records_by_name = {}
                local changed_index
                local correction = 0
                if trainline.records then
                    local name
                    for i, record in pairs(trainline.records) do
                        name = tostring(record.station)
                        old_records_by_name[name] = old_records_by_name[name] or {}
                        old_records_by_name[name][i] = table.deepcopy(record)
                    end
                    for i, record in pairs(records) do
                        name = tostring(record.station)
                        new_records_by_name[name] = new_records_by_name[name] or {}
                        new_records_by_name[name][i] = table.deepcopy(record)
                    end
                    --log(serpent.block(old_records_by_name, {sparse=true, name = "old_records"}))
                    --log(serpent.block(new_records_by_name, {sparse=true, name = "new_records"}))

                    local missing_rules = {}
                    --check each record of the new line if it exists in the old
                    for name, r in pairs(new_records_by_name) do
                        for i, record in pairs(r) do
                            --name and index match, copy rules
                            if old_records_by_name[name] and old_records_by_name[name][i] then
                                new_rules[i] = update_conditions( record, rules[i] )
                                --new station, add empty rule
                            elseif not old_records_by_name[name] then
                                new_rules[i] = update_conditions( record, {})
                                changed_index = i
                                --no match found, save name and index to check later
                            else
                                new_rules[i] = { station = name, missing = true }
                                table.insert( missing_rules, {index = i, station = name})
                            end
                        end
                    end
                    if not changed_index then
                        for i, r in pairs(trainline.records) do
                            if not new_records_by_name[r.station] then
                                changed_index = i
                                break
                            end
                        end
                    end
                    --log(serpent.block(missing_rules, {name = "missing_rules"}))
                    local prev_index, next_index
                    local index_mapping = {}
                    for _, missing_rule in pairs(missing_rules) do
                        prev_index = missing_rule.index - 1
                        next_index = missing_rule.index + 1
                        local prev_record = trainline.records[prev_index] and trainline.records[prev_index].station and trainline.records[prev_index]
                        local next_record = trainline.records[next_index] and trainline.records[next_index].station and trainline.records[next_index]
                        if prev_record and prev_record.station == missing_rule.station then
                            assert(new_rules[missing_rule.index].missing)
                            log(string.format("prev_record: old_index: %s, new_index: %s", prev_index, missing_rule.index))
                            new_rules[missing_rule.index] = update_conditions( records[missing_rule.index], rules[prev_index])
                            correction = 1
                        end
                        if next_record and next_record.station == missing_rule.station then
                            assert(new_rules[missing_rule.index].missing)
                            log(string.format("next_record: old_index: %s, new_index: %s", prev_index, missing_rule.index))
                            new_rules[missing_rule.index] = update_conditions( records[missing_rule.index], rules[next_index])
                            correction = -1
                        end
                    end
                end

                --remove/add rules if needed
                if #new_rules > #records then
                    for i=#new_rules, #records+1 do
                        new_rules[i] = nil
                    end
                end
                if not trainline.settings.useMapping and changed_index then
                    --log("correction " .. correction)
                    --log("changed_index " .. changed_index)
                    local changed
                    for i, rule in pairs(new_rules) do
                        if rule.jumpTo and rule.jumpTo >= changed_index then
                            rule.jumpTo = rule.jumpTo + correction
                            changed = true
                        end
                    end
                    if changed then
                        player.print({"", {"msg-station-index-changed", {"lbl-jump-to-header"}}})
                    end
                end

                --log(serpent.block(new_rules, {sparse=true, name = "new_rules"}))
                local changed = game.tick

                local conditions_changed = function()
                    if #records ~= #trainline.records then
                        return false
                    end
                    local diff = {}
                    local records2 = table.deepcopy(trainline.records)
                    for recordIndex, record in pairs(records) do
                        if record.station == records2[recordIndex].station then
                            --log(record.station .. " " .. records2[recordIndex].station)
                            --log(serpent.block({c1=record, c2=records2[recordIndex]}, {comment=false}))
                            if not util.table.compare(record.wait_conditions, records2[recordIndex].wait_conditions) then
                                diff[recordIndex] = table.deepcopy(record.wait_conditions)
                            end
                        else
                            return false
                        end
                    end
                    --log(serpent.block(diff,{comment=false}))
                    return diff
                end
                local new_conditions = trainline.records and conditions_changed()
                trainline.records = records
                trainline.rules = table.deepcopy(new_rules)

                trainline.changed = changed

                if is_copy then
                    trainline.records = table.deepcopy(global.trainLines[t.line].records)
                    trainline.rules = table.deepcopy(global.trainLines[t.line].rules)
                    trainline.settings = table.deepcopy(global.trainLines[t.line].settings)
                end

                t.line = name
                t.lineVersion = changed
                t.rules = table.deepcopy(trainline.rules)
                update_station_numbers()
                on_gui_click.add_trains_to_update(name, new_conditions)
            end
        else
            debugDump("Invalid name, only letters, numbers, space, -,#,!,$ are allowed",true) --TODO localisation
        end
        return true
    end,

    prevPageTrain = function(player,option2)
        local page = tonumber(option2)
        page = (page > 1) and page - 1 or 1
        global.playerPage[player.index].schedule = page
        return true
    end,

    nextPageTrain = function(player,option2)
        local page = tonumber(option2)
        global.playerPage[player.index].schedule = page + 1
        return true
    end,

    firstPageTrain = function(player)
        global.playerPage[player.index].schedule = 1
        return true
    end,

    lastPageTrain = function(player)
        local t = TrainList.getTrainInfoFromUI(player.index)
        if not t or not t.train.valid then
            return
        end
        local records = t.train.schedule and t.train.schedule.records or false
        local trainLine = t.line and global.trainLines[t.line] or false
        if trainLine then
            records = trainLine.records
        end
        if records and #records > 0 then
            local spp = global.settings.stationsPerPage
            local page = math.ceil(#records / spp)

            global.playerPage[player.index].schedule = page
            return true
        end
    end,

    prevPageLine = function(player,option2)
        local page = tonumber(option2)
        page = (page > 1) and page - 1 or 1
        global.playerPage[player.index].line = page
        return true
    end,

    nextPageLine = function(player,option2)
        local page = tonumber(option2)
        global.playerPage[player.index].line = page + 1
        return true
    end,

    prevPageMapping = function(player,option2)
        GUI.get_mapping_from_gui(player)
        local page = tonumber(option2)
        page = (page > 1) and page - 1 or 1
        global.playerPage[player.index].mapping = page
        GUI.showStationMapping(player.index)
        return false
    end,

    nextPageMapping = function(player,option2)
        GUI.get_mapping_from_gui(player)
        local page = tonumber(option2)
        global.playerPage[player.index].mapping = page + 1
        GUI.showStationMapping(player.index)
        return false
    end,

    firstPageMapping = function(player, option2)
        GUI.get_mapping_from_gui(player)
        local page = tonumber(option2)
        global.playerPage[player.index].mapping = 1
        GUI.showStationMapping(player.index)
        return false
    end,

    lastPageMapping = function(player, option2)
        GUI.get_mapping_from_gui(player)
        local page = tonumber(option2)
        global.playerPage[player.index].mapping = math.ceil(table.count(global.stationCount[player.force.name]) / global.settings.mappingsPerPage)
        GUI.showStationMapping(player.index)
        return false
    end,

    saveMapping = function(player)
        GUI.get_mapping_from_gui(player)
        --global.stationMapping[player.force.name] = table.deepcopy(global.guiData[player.index].mapping)
        local force = player.force.name
        global.stationMap[force] = {}
        for name, id in pairs(global.guiData[player.index].mapping) do
            global.stationMap[force][id] = global.stationMap[force][id] or {}
            if id then
                global.stationMapping[force][name] = id
                global.stationMap[force][id][name] = true
                global.stationNumbers[force][name] = id
            else
                global.stationMapping[force][name] = nil
                global.stationMap[force][id][name] = nil
                global.stationNumbers[force][name] = nil
            end
            if not next(global.stationMap[force][id]) then
                global.stationMap[force][id] = nil
            end
        end
        player.print("Saved station mapping") --TODO localisation
        update_station_numbers()
        return false
    end,
}
