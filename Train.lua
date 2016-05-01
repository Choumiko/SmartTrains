function startsWith(String,needle)
  return string.sub(String,1,string.len(needle))==needle
end

Train = {

    new = function(train)
      if train.valid then
        local new = {
          train = train,
          dynamic = false,
          line = false,
          lineVersion = 0,
          settings = {},
          waiting = false,
          refueling = false,
          advancedState = false,
          cargo = {},
          cargoUpdated = 0,
          direction = 0 -- 0 = front, 1 back
        --manualMode = train.manual_mode
        }
        new.settings.autoDepart = defaultTrainSettings.autoDepart
        new.settings.autoRefuel = defaultTrainSettings.autoRefuel
        if train.locomotives ~= nil and (#train.locomotives.front_movers > 0 or #train.locomotives.back_movers > 0) then
          if train.locomotives.front_movers[1] then
            new.name = train.locomotives.front_movers[1].backer_name
          elseif train.locomotives.back_movers[1] then
            new.name = train.locomotives.back_movers[1].backer_name
          else
            new.name = "Some Loco"
            debugDump("Some loco",true)
          end
        else
          new.name = "cargoOnly"
        end
        setmetatable(new, {__index = Train})
        new.type = new:getType()
        return new
      end
    end,

    getType = function(self)
      --local type = string.rep("L",#self.train.locomotives.front_movers).."-"..string.rep("C", #self.train.cargo_wagons).."-"..string.rep("L",#self.train.locomotives.back_movers)
      local type = ""
      for _,c in pairs(self.train.carriages) do
        local str = c.type == "locomotive" and "L" or "C"
        type = type..str
      end
      type = string.gsub(type, "L%-%-L", "LL")
      return string.gsub(string.gsub(type, "^-", ""), "-$", "")
    end,

    printName = function(self)
      debugDump(self.name, true)
    end,

    nextStation = function(self, force, index)
      local train = self.train
      if self.settings.autoRefuel then
        if self:lowestFuel() < (global.settings.refuel.rangeMin) and not inSchedule(self:refuelStation(), train.schedule) then
          train.schedule = addStation(self:refuelStation(), train.schedule, global.settings.refuel.time)
          self:flyingText("Refuel station added", YELLOW)
        end
      end
      if train.manual_mode == false or force then
        local schedule = train.schedule
        local tmp = (schedule.current % #schedule.records) + 1
        if index and index > 0 and index <= #schedule.records then
          tmp = index
          self:flyingText("Going to "..schedule.records[index].station, YELLOW, {offset = -1}) --TODO localisation
        end
        --all below is needed to make a train go to another station, don't change!
        train.manual_mode = true
        schedule.current = tmp
        train.schedule = schedule
        train.manual_mode = false
      end
    end,

    isValidScheduleIndex = function(self, index)
      if index and index > 0 and index <= #self.train.schedule.records then
        return index
      end

      return false
    end,

    refuelStation = function(self)
      local station = global.settings.refuel.station
      local lType = self:getType()
      local locos = string.match(lType,"^(L*)-*C*$")
      local refuelStation = station.." "..lType
      local match = false
      local force = self.train.carriages[1].force.name
      for name, c in pairs(global.stationCount[force]) do
        if name == refuelStation and c > 0 then
          return refuelStation
        end
        if locos then
          --debugDump(name..": "..station.." "..locos,true)
          --debugDump(startsWith(name,station.." "..locos),true)
          if startsWith(name,station.." "..locos) and string.match(name,"^"..station.."%s(L*)") == locos then
            match = name
          end
        end
      end
      if match then
        return match
      else
        return station
      end
    end,

    startRefueling = function(self)
      self.refueling = {nextCheck = game.tick + global.settings.depart.interval}
      --debugDump({refuel= util.formattime(game.tick)},true)
      local tick = self.refueling.nextCheck
      if not global.ticks[tick] then
        global.ticks[tick] = {self}
      else
        table.insert(global.ticks[tick], self)
      end
    end,

    isRefueling = function(self)
      return type(self.refueling) == "table" and self.settings.autoRefuel
    end,

    refuelingDone = function(self, done)
      if done then
        self.refueling = false
        self:nextStation()
      end
    end,

    removeRefuelStation = function(self)
      if inSchedule(self:refuelStation(), self.train.schedule) and #self.train.schedule.records >= 3 then
        self.train.schedule = removeStation(self:refuelStation(), self.train.schedule)
        self:flyingText("Refuel station removed", YELLOW) --TODO localisation
      end
    end,

    currentStation = function(self)
      if self.train.valid and type(self.train.schedule.records) == "table" and self.train.schedule.records[self.train.schedule.current] then
        return self.train.schedule.records[self.train.schedule.current].station
      else
        return false
      end
    end,

    startWaitingForAutoDepart = function(self)
      self.waiting = {cargo = self:cargoCount(), lastCheck = game.tick, nextCheck = game.tick + global.settings.depart.minWait}
      local tick = self.waiting.nextCheck
      insertInTable(global.ticks, tick, self )
    end,

    isWaitingForAutoDepart = function(self)
      return type(self.waiting) == "table" and type(self.waiting.cargo) == "table" and self.settings.autoDepart --and self.train.manual_mode == false
    end,

    waitingDone = function(self, done, index)
      if done then
        local force = self.waitForever or false
        self:resetCircuitSignal()
        self.waiting = false
        self:nextStation(force, index)
        --debugDump("waitForever unset")
        self.waitForever = false
      end
    end,

    get_rules = function(self)
      return (self.line and global.trainLines[self.line] and global.trainLines[self.line].rules) and global.trainLines[self.line].rules[self.train.schedule.current] or false
    end,

    startWaitingForRules = function(self)
      if not self.waiting then
        local nextCheck = self.train.schedule.records[self.train.schedule.current].time_to_wait == 10 and game.tick + 9 or game.tick + global.settings.depart.minWait
        self.waiting = {lastCheck = game.tick, nextCheck = nextCheck}
        local rules = self:get_rules()
        self.waitForever = false
        if rules then
          if rules.keepWaiting then
            --debugDump(util.formattime(game.tick,true).." waitForever set",true)
            self.waitForever = true
          end
          if rules.waitForCircuit then
            self.waiting.nextCheck = game.tick + global.settings.circuit.interval
          end
        end
        local tick = self.waiting.nextCheck
        insertInTable(global.ticks, tick, self)
      end
    end,

    isWaitingForRules = function(self)
      local rules = self:get_rules()
      return type(self.waiting) == "table" and rules
    end,

    isWaiting = function(self)
      return type(self.waiting) == "table"
    end,

    -- return true when at a smart train stop
    setWaitingStation = function(self)
      local vehicle = (self.direction and self.direction == 0) and self.train.carriages[1] or self.train.carriages[#self.train.carriages]
      --self:flyingText("V", GREEN, {offset=vehicle.position})
      local station = findSmartTrainStopByTrain(vehicle, self.train.schedule.records[self.train.schedule.current].station)
      local proxy, cargoProxy = false, false
      if station then
        local smartStop = global.smartTrainstops[vehicle.force.name][stationKey(station)]
        --self:flyingText("S", GREEN, {offset=station.position})
        proxy = (smartStop and smartStop.proxy) and smartStop.proxy or false
        cargoProxy = (smartStop and smartStop.cargo) and smartStop.cargo or false
      end
      self.waitingStation = {station = station, signalProxy = proxy, cargoProxy = cargoProxy}
      return station and proxy and cargoProxy
    end,

    getCircuitSignal = function(self)
      if self.waitingStation and self.waitingStation.signalProxy and self.waitingStation.signalProxy.valid then
        return self.waitingStation.signalProxy.get_circuit_condition(1).fulfilled and self.waitingStation.signalProxy.energy > 0
      end
      return false
    end,

    getCircuitValue = function(self)
      if self.waitingStation and self.waitingStation.signalProxy and self.waitingStation.signalProxy.valid then
        local condition = self.waitingStation.signalProxy.get_circuit_condition(1)
        local signal = (condition.condition and condition.condition.first_signal and condition.condition.first_signal.name) and condition.condition.first_signal or false
        if signal and signal.name then
          return deduceSignalValue(self.waitingStation.signalProxy, signal, 1)
        end
      end
      return false
    end,

    setCircuitSignal = function(self)
      if self.waitingStation and self.waitingStation.cargoProxy and self.waitingStation.cargoProxy.valid then
        --debugLog("setSignal " ..self.waitingStation.station.backer_name, game.tick.." ")
        local cargoProxy = self.waitingStation.cargoProxy
        --local output = cargoProxy.get_circuit_condition(1)
        local output = {parameters={}}
        local passenger = 0
        for _, carriage in pairs(self.train.carriages) do
          if carriage.passenger and carriage.passenger.name ~= "fatcontroller" then
            passenger = passenger + 1
            break
          end
        end
        --debugLog("getFuel s")
        local min_fuel = self:lowestFuel()
        --debugLog("getFuel e")
        output.parameters[1]={signal={type = "virtual", name = "signal-train-at-station"}, count = 1, index = 1}
        output.parameters[2]={signal={type = "virtual", name = "signal-locomotives"}, count = #self.train.locomotives.front_movers+#self.train.locomotives.back_movers, index = 2}
        output.parameters[3]={signal={type = "virtual", name = "signal-cargowagons"}, count = #self.train.cargo_wagons, index = 3}
        output.parameters[4]={signal={type = "virtual", name = "signal-passenger"}, count = passenger, index = 4}
        output.parameters[5]={signal={type = "virtual", name = "signal-lowest-fuel"}, count = min_fuel, index = 5}

        local i=6
        if self.line and global.trainLines[self.line] and global.trainLines[self.line].number ~= 0 then
          output.parameters[6]={signal={type = "virtual", name = "signal-line"}, count = global.trainLines[self.line].number, index = 6}
          i=7
        end

        --debugLog("getCargo s")
        local cargoCount = self:cargoCount()
        for name, count in pairs(cargoCount) do
          local type = "item"
          if game.fluid_prototypes[name] then
            type = "fluid"
            count = math.floor(count)
          end
          output.parameters[i]={signal={type = type, name = name}, count=count, index = i}
          i=i+1
          if i>50 then break end
        end
        --debugLog("getCargo e")
        --debugLog("set Condition s")
        cargoProxy.set_circuit_condition(1,output)
        --debugLog("set Condition e")
      end
      --debugLog("setSignal e")
    end,

    resetCircuitSignal = function(self)
      if self.waitingStation and self.waitingStation.cargoProxy and self.waitingStation.cargoProxy.valid then
        local cargoProxy = self.waitingStation.cargoProxy
        local output = {parameters={}}
        --output.parameters[1]={signal={type = "virtual", name = "signal-cargowagons"}, count = -1, index = 1}
        --game.write_file("st/debugOutput.lua", serpent.block(output, {name="output"}))
        --local v = cargoProxy.valid and "valid" or "invalid"
        --debugDump("CargoProxy: "..cargoProxy.name.." "..v,true)
        --debugDump(output.parameters,true)
        cargoProxy.set_circuit_condition(1,output)
      end
    end,

    --returns fuelvalue (in MJ)
    lowestFuel = function(self)
      local minfuel = nil
      local c
      local locos = self.train.locomotives
      if locos ~= nil then
        for _, carriage in pairs(locos.front_movers) do
          c = self:calcFuel(carriage.get_inventory(1).get_contents())
          if minfuel == nil or c < minfuel then
            minfuel = c
          end
        end
        for _, carriage in pairs(locos.back_movers) do
          c = self:calcFuel(carriage.get_inventory(1).get_contents())
          if minfuel == nil or c < minfuel then
            minfuel = c
          end
        end
        return minfuel
      else
        return 0
      end
    end,

    calcFuel = function(self, contents)
      local value = 0
      --/c game.player.print(game.player.character.vehicle.train.locomotives.front_movers[1].energy)
      for i, c in pairs(contents) do
        value = value + c*fuelvalue(i)
      end
      return value
    end,

    cargoCount = function(self)
      if self.cargoUpdated + global.settings.circuit.interval - 1 < game.tick then
        local sum = {}
        local train = self.train
        --sum = train.get_contents()
        for i, wagon in pairs(train.cargo_wagons) do
          if not self.proxy_chests or not self.proxy_chests[i] then
            if wagon.type == "cargo-wagon" then
              if wagon.name ~= "rail-tanker" then
                --sum = sum + wagon.getcontents()
                sum = addInventoryContents(sum, wagon.get_inventory(1).get_contents())
              else
                if remote.interfaces.railtanker and remote.interfaces.railtanker.getLiquidByWagon then
                  local d = remote.call("railtanker", "getLiquidByWagon", wagon)
                  if d.type ~= nil then
                    sum[d.type] = sum[d.type] or 0
                    sum[d.type] = sum[d.type] + d.amount
                    --self:flyingText(d.type..": "..d.amount, YELLOW, {offset={x=wagon.position.x,y=wagon.position.y+1}})
                  end
                end
              end
            end
          else
            --wagon is used by logistics railway
            local inventory = self.proxy_chests[i].get_inventory(defines.inventory.chest)
            local contents = inventory.get_contents()
            sum = addInventoryContents(sum, contents)
          end
        end
        self.cargo = sum
        self.cargoUpdated = game.tick
      end
      return self.cargo
    end,

    cargoEquals = function(self, c1, c2, minFlow, interval)
      local liquids1 = {}
      local liquids2 = {}
      local goodflow = false
      local fluids = game.fluid_prototypes
      for l,_ in pairs(fluids) do
        liquids1[l], liquids2[l] = false, false
        if c1[l] ~= nil or c2[l] ~= nil then
          liquids1[l] = c1[l] or 0
          liquids2[l] = c2[l] or 0
          local flow = (liquids1[l] - liquids2[l])/(interval/60)
          if math.abs(flow) >= minFlow then goodflow = true end
          --self:flyingText("flow: "..flow, YELLOW, {offset=1})
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
    end,

    isCargoEmpty = function(self)
      local train = self.train
      for i, wagon in pairs(train.cargo_wagons) do
        if self.proxy_chests and self.proxy_chests[i] then
          --wagon is used by logistics railway
          local chest = self.proxy_chests[i]
          local inventory = chest.get_inventory(defines.inventory.chest)
          --debugDump({i=i, empty=inventory.is_empty()},true)
          if not inventory.is_empty() then
            return false
          end
        else
          if wagon.name ~= "rail-tanker" then
            if not wagon.get_inventory(1).is_empty() then
              return false
            end
          else
            if remote.interfaces.railtanker and remote.interfaces.railtanker.getLiquidByWagon then
              local d = remote.call("railtanker", "getLiquidByWagon", wagon)
              if d.type ~= nil then
                if math.floor(d.amount) > 0 then
                  return false
                end
              end
            end
          end
        end
      end
      return true
    end,

    isCargoFull = function(self)
      local train = self.train
      local inv_full = function(inv)
        --check if all slots are blocked
        if inv.hasbar() and inv.getbar() == 0 then
          return false
        end
        if inv.can_insert{name="railgun", count=1} then
          --inserted railgun -> at least 1 slot is free
          return false
        end
        -- check if all stacks are full
        local contents = inv.get_contents()
        for item, _ in pairs(contents) do
          if inv.can_insert{name=item, count=1} then
            return false
          end
        end
        -- all stacks are full,
        return true
      end

      for i, wagon in pairs(train.cargo_wagons) do
        if self.proxy_chests and self.proxy_chests[i] then
          --wagon is used by logistics railway
          local chest = self.proxy_chests[i]
          local inventory = chest.get_inventory(defines.inventory.chest)
          if not inv_full(inventory) then return false end
        else
          if wagon.name ~= "rail-tanker" then
            local inv = wagon.get_inventory(1)
            if not inv_full(inv) then return false end
          else
            if remote.interfaces.railtanker and remote.interfaces.railtanker.getLiquidByWagon then
              local d = remote.call("railtanker", "getLiquidByWagon", wagon)
              if d.type ~= nil then
                if math.ceil(d.amount) < 2500 then
                  return false
                end
              end
            end
          end
        end
      end
      return true
    end,

    updateState = function(self)
      --debugDump(util.formattime(game.tick,true).."@ "..getKeyByValue(defines.trainstate, self.train.state),true)
      self.previousState = self.state
      self.state = self.train.state
      if self.previousState == defines.trainstate.wait_station and self.state == defines.trainstate.on_the_path then
        self.advancedState = defines.trainstate.left_station
        --debugDump(game.tick.." left_station",true)
      else
        self.advancedState = false
      end
    end,

    updateLine = function(self)
      if self.opened or self.train.state == defines.trainstate.arrive_signal or self.train.state == defines.trainstate.wait_signal then
        return
      end
      local oldmode = self.train.manual_mode
      if self.line and global.trainLines[self.line] then
        if self.settings.autoRefuel and self.train.schedule.current == inSchedule(self:refuelStation(), self.train.schedule) then
          --self:flyingText("Skipping line update", YELLOW)
          return
        end
        local trainLine = global.trainLines[self.line]
        if self.line and trainLine.changed <= self.lineVersion then
          return
        end
        if self.line then
          --debugDump("updating line "..self.line.." train: "..self.train.carriages[1].backer_name,true)
          local rules = trainLine.rules
          if self.lineVersion >= 0 then
            self:flyingText("updating schedule", YELLOW) --TODO localisation
          end
          local waitingAt = self.train.schedule.records[self.train.schedule.current] or {station="", time_to_wait=0}
          local schedule = {records={}}
          for i, record in pairs(trainLine.records) do
            if rules then
              if rules[i].keepWaiting then
                record.time_to_wait = 2^32-1
              else
                record.time_to_wait = rules[i].original_time
              end
            end
            schedule.records[i] = record
          end

          local inLine = inSchedule(waitingAt.station,schedule)
          if inLine then
            schedule.current = inLine
          else
            schedule.current = 1
          end
          self.settings.autoRefuel = trainLine.settings.autoRefuel
          self.settings.autoDepart = trainLine.settings.autoDepart
          self.lineVersion = trainLine.changed

          self.train.manual_mode = true
          self.train.schedule = schedule
          self.train.manual_mode = oldmode

        end
      elseif (self.line and not global.trainLines[self.line]) then
        self:flyingText("Dettached from line", RED) --TODO localisation
        local schedule = self.train.schedule
        for _, record in pairs(schedule.records) do
          if record.time_to_wait == 2^32-1 then
            record.time_to_wait = 200*60
          end
        end
        self.waitForever = false
        self.line = false
        self.lineVersion = false

        self.train.manual_mode = true
        self.train.schedule = schedule
        self.train.manual_mode = oldmode
      end
    end,

    flyingText = function(self, msg, color, tbl)
      local s = global.showFlyingText
      local offset = 0
      if type(tbl) == "table" then
        s = tbl.show or s
        offset = tbl.offset or offset
      end
      local pos = self.train.carriages[1].position
      if type(offset) == "table" then
        pos = offset
      elseif type(offset) == "number" then
        pos.y = pos.y + offset
      end
      if s then self.train.carriages[1].surface.create_entity({name="flying-text", position=pos, text=msg, color=color}) end
    end
}
Train.__eq = function(trainA, trainB)
  return trainA.train.carriages[1] == trainB.train.carriages[1]
end
