require "defines"
local refuelStation = "Refuel"
local refuelRange = {min = 25, max = 50} -- in coal

local function scheduleToString(schedule)
    local tmp = "Schedule: "
    for i=1,#schedule.records do
        tmp = tmp.." "..schedule.records[i].station.."|"..schedule.records[i].time_to_wait/60
    end
    return tmp.." next: "..schedule.current
end

local function debugLog(msg)
    if false then
        game.player.print(msg)
    end
end

local function inSchedule(station, schedule)
    for i=1,#schedule.records do
        if schedule.records[i].station == station then
            return true
        end
    end
    return false
end

local function removeStation(station, schedule)
    local found = false
    local tmp = schedule
    for i=1,#schedule.records do
        if schedule.records[i].station == refuelStation then
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
local function fuelvalue(item)
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

local function distance(point1, point2)
    local diffX = point1.x - point2.x
    local diffY = point1.y - point2.y
    return math.sqrt(diffX ^ 2 + diffY ^ 2)
end
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
            --game.player.print("dist: "..distance(start,stop))
            printed = true
        end
    else
        if printed then
            start, stop, printed = nil,nil,nil
        end
    end
end)
--]]
game.onevent(defines.events.ontrainchangedstate, function(event)
    local train = event.train
    local inv = train.locomotives.frontmovers[1].getinventory(1)
    local con = inv.getcontents()
    local fuel = calcFuel(con)
    local schedule = train.schedule
    if train.state == defines.trainstate["waitstation"] then
        if fuel > (refuelRange.max * fuelvalue("coal")) and schedule.records[schedule.current].station ~= refuelStation then
            train.schedule = removeStation(station, schedule)
        end
        debugLog("@wait "..scheduleToString(train.schedule))
    elseif train.state == defines.trainstate["arrivestation"]  or train.state == defines.trainstate["waitsignal"] or train.state == defines.trainstate["arrivesignal"] or train.state == defines.trainstate["onthepath"] then
        if fuel < (refuelRange.min * fuelvalue("coal")) and not inSchedule(refuelStation, schedule) then
            --train.schedule = addStation(refuelStation, schedule, 300, schedule.current)
            train.schedule = addStation(refuelStation, schedule, 300)
        end
        debugLog("@arrive "..scheduleToString(train.schedule))
    end
end)