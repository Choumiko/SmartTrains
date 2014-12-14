require "defines"

local function inSchedule(station, schedule)
    for i=1,#schedule.records do
        if schedule.records[i].station == station then
            return true
        end
    end
    return false
end

game.onevent(defines.events.ontrainchangedstate, function(event)
    local train = event.train
    local fuel = train.locomotives.frontmovers[1].getitemcount("raw-wood")
    local schedule = train.schedule
    game.player.print("wood: "..fuel)
    if train.state == defines.trainstate["waitstation"] then
        if fuel > 6 and schedule.records[schedule.current].station ~= "Refuel" then
            for i=1,#schedule.records do
                if schedule.records[i].station == "Refuel" then
                    schedule.records[i] = nil
                end
            end
            train.schedule = schedule
        end
        game.player.print("@wait "..serpent.dump(schedule))
    elseif train.state == defines.trainstate["arrivestation"] then
        if fuel < 5 and not inSchedule("Refuel", schedule) then
            local i = #schedule.records+1
            schedule.records[i] = {}
            schedule.records[i].time_to_wait = 600
            schedule.records[i].station ="Refuel"
            train.schedule = schedule
        end
        game.player.print("@arrive "..serpent.dump(train.schedule))
    end
end)