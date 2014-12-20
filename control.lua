require "defines"
local refuelStation = "Refuel"
local refuelRange = {min = 25, max = 50} -- in coal
local tmpPos = {}

game.oninit(function()
  initGlob()
end)

game.onload(function()
    initGlob()
end)

function initGlob()
  if glob.init ~= nil then return end
  glob.init = true
  glob.trains = {}
end

game.onevent(defines.events.onbuiltentity,
  function(event)
    local ent = event.createdentity
    local ctype = ent.type
    if ctype == "locomotive" or ctype == "cargo-wagon" then
    --if ctype == "locomotive" then
        local newTrainInfo = getNewTrainInfo(ent.train)
        if newTrainInfo ~= nil then
            removeInvalidTrains()
            table.insert(glob.trains, newTrainInfo)
            printGlob()
        end    
    end
  end
)

game.onevent(defines.events.onpreplayermineditem, function(event)
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
        for i, train in ipairs(glob.trains) do
            if train.carriages[1].equals(ent.train.carriages[1]) then
                table.remove(glob.trains, i)
                break
            end
        end
        if #ent.train.carriages > 1 then
            if ent.train.carriages[ownPos-1] ~= nil then
                table.insert(tmpPos, ent.train.carriages[ownPos-1].position)
            end
            if ent.train.carriages[ownPos+1] ~= nil then
                table.insert(tmpPos, ent.train.carriages[ownPos+1].position)
            end
        end
    end
end)

game.onevent(defines.events.onplayermineditem, function(event)
    local name = event.itemstack.name
    local results = {}
    if name == "diesel-locomotive" or name == "cargo-wagon" and #tmpPos > 0 then
        for i,pos in ipairs(tmpPos) do
            area = {{pos.x-1, pos.y-1},{pos.x+1, pos.y+1}}
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
        printGlob()
        tmpPos = {}
    end
end)

function printGlob()
    debugLog("# "..#glob.trains)
    for i,t in ipairs(glob.trains) do
        debugLog("Train "..i..": carriages:"..#t.carriages)
    end
end

function getNewTrainInfo(train)
	if train ~= nil then
		local carriages = train.carriages
		if carriages ~= nil and carriages[1] ~= nil and carriages[1].valid then
			local newTrainInfo = {}
			newTrainInfo.train = train
			--newTrainInfo.firstCarriage = getFirstCarriage(train)
			newTrainInfo.carriages = train.carriages
            --newTrainInfo.refuelStation = refuelStation
            --newTrainInfo.refuelRange = refuelRange
			return newTrainInfo
		end
	end
end

function removeInvalidTrains()
    for i,t in ipairs(glob.trains) do
        if not t.train.valid then
            table.remove(glob.trains, i)
        end
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

local function lowestFuel(train)
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

game.onevent(defines.events.ontrainchangedstate, function(event)
    local train = event.train
    local fuel = lowestFuel(train)
    local schedule = train.schedule
    if train.state == defines.trainstate["waitstation"] then
        if fuel > (refuelRange.max * fuelvalue("coal")) and schedule.records[schedule.current].station ~= refuelStation then
            train.schedule = removeStation(station, schedule)
        end
    elseif train.state == defines.trainstate["arrivestation"]  or train.state == defines.trainstate["waitsignal"] or train.state == defines.trainstate["arrivesignal"] or train.state == defines.trainstate["onthepath"] then
        if fuel < (refuelRange.min * fuelvalue("coal")) and not inSchedule(refuelStation, schedule) then
            --train.schedule = addStation(refuelStation, schedule, 300, schedule.current)
            train.schedule = addStation(refuelStation, schedule, 300)
        end
    end
end)

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

function scheduleToString(schedule)
    local tmp = "Schedule: "
    for i=1,#schedule.records do
        tmp = tmp.." "..schedule.records[i].station.."|"..schedule.records[i].time_to_wait/60
    end
    return tmp.." next: "..schedule.current
end

function debugLog(msg, force)
    if true or force then
        game.player.print(msg)
    end
end
remote.addinterface("st",
{
  printGlob = function(name)
    debugLog(serpent.dump(glob.trains), true)
  end,
  
  reset = function()
    glob.trains = nil
    initGlob()
  end
}
)