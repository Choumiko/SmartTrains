Train = {

    new = function(train)
      if train.valid then
        local new = {
          train = train,
          line = false,
          lineVersion = 0,
          settings = {},
          waiting = false,
          refueling = false,
          advancedState = false,
          cargo = {},
          cargoUpdated = 0,
          last_fuel_update = 0,
          direction = 0, -- 0 = front, 1 back
          railtanker = false, -- has a railtanker wagon
          has_filter = false, -- has a filter set in one of the wagons,
          passengers = 0,
        --manualMode = train.manual_mode
        }
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
        for _, c in pairs(train.carriages) do
          if c.name == "rail-tanker" then
            new.railtanker = true
          end
          if c.passenger and c.passenger.name ~= "fatcontroller" then
            new.passengers = new.passengers + 1
          end
        end
        setmetatable(new, {__index = Train})
        new.type = new:getType()
        new:check_filters()
        return new
      end
    end,

    check_filters = function(self)
      self.has_filter = false
      for _, c in pairs(self.train.cargo_wagons) do
        for i=1, #c.get_inventory(1) do
          if c.get_filter(i) then
            self.has_filter = true
            return true
          end
        end
      end
      return false
    end,

    getType = function(self)
      local parts = {}
      local found
      for _,c in pairs(self.train.carriages) do
        found = false
        if c.type == "locomotive" then
          for i, fm in pairs(self.train.locomotives.front_movers) do
            if fm == c then
              table.insert(parts,'F')
              found = true
              break
            end
          end
          if not found then
            for i, bm in pairs(self.train.locomotives.back_movers) do
              if bm == c then
                table.insert(parts,'B')
                break
              end
            end
          end
        else
          table.insert(parts, 'c')
        end
      end
      return table.concat(parts,'')
    end,

    printName = function(self)
      debugDump(self.name, true)
    end,

    get_first_matching_station = function(self, value)
      local stations = global.stationMap[self.train.carriages[1].force.name][value]
      if not stations then
        return false
      end
      local schedule = self.train.schedule
      local records = schedule.records
      local current = schedule.current
      local num_records = #records
      local index
      for i = 0, num_records - 2 do
        index = (current + i) % num_records + 1
        if stations[records[index].station] then
          return index
        end
      end
      return false
    end,

    nextStation = function(self, force, index)
      local train = self.train
      if self.settings.autoRefuel then
        if self:lowestFuel() < (global.settings.refuel.rangeMin) and not inSchedule(self:refuelStation(), train.schedule) then
          train.schedule = addStation(self:refuelStation(), train.schedule, global.settings.refuel.time)
          self:flyingText("Refuel station added", colors.YELLOW)
        end
      end
      if train.manual_mode == false or force then
        local schedule = train.schedule

        local tmp = (schedule.current % #schedule.records) + 1
        if index and index > 0 and index <= #schedule.records then
          tmp = index
          self:flyingText("Going to "..schedule.records[index].station, colors.YELLOW, {offset = -1}) --TODO localisation
        else
          self:flyingText("leave station", colors.YELLOW, {offset=-1})
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
          --debugDump(string.starts_with(name,station.." "..locos),true)
          if string.starts_with(name, station.." "..locos) and string.match(name,"^"..station.."%s(L*)") == locos then
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
      local tick = game.tick + global.settings.intervals.write
      self.refueling = {nextCheck = tick}
      insertInTable(global.refueling, tick, self)
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
        self:flyingText("Refuel station removed", colors.YELLOW) --TODO localisation
      end
    end,

    currentStation = function(self)
      if self.train.valid and type(self.train.schedule.records) == "table" and self.train.schedule.records[self.train.schedule.current] then
        return self.train.schedule.records[self.train.schedule.current].station
      else
        return false
      end
    end,

    getStationName = function(self, index)
      if self.train.valid and self:isValidScheduleIndex(index) and type(self.train.schedule.records) == "table" then
        return self.train.schedule.records[index].station
      else
        return false
      end
    end,

    waitingDone = function(self, done, index)
      if done then
        local force = self.waitForever or false
        self:resetCircuitSignal()
        self.waiting = false
        self.update_cargo = false
        self:nextStation(force, index)
        --debugDump("waitForever unset")
        self.waitForever = false
        --TODO remove copied rules 
      end
    end,

    get_rules = function(self)
      local rules = (self.line and global.trainLines[self.line] and global.trainLines[self.line].rules) and global.trainLines[self.line].rules[self.train.schedule.current] or false
      if rules then
        local defaultRule = {empty = true, full = true, noChange = true, waitForCircuit = false}
        for k, _ in pairs(defaultRule) do
          if rules[k] then
            return rules
          end
        end
      end
      return false
    end,

    get_rule = function(self, name)
      local rules = self:get_rules()
      if rules then
        local defaultRule = {empty = true, full = true, noChange = true, waitForCircuit = false}
        return rules[name]
      end
      return false
    end,

    isWaitingForRules = function(self)
      return type(self.waiting) == "table" and self:get_rules()
    end,

    isWaiting = function(self)
      return type(self.waiting) == "table"
    end,

    -- return true when at a smart train stop
    setWaitingStation = function(self)
      if self.waiting then
        return
      end
      local vehicle = (self.direction and self.direction == 0) and self.train.carriages[1] or self.train.carriages[#self.train.carriages]
      self.waitingStation = findSmartTrainStopByTrain(vehicle, self.train.schedule.records[self.train.schedule.current].station)
      local current_tick = game.tick
      local rules = self:get_rules()

      if not self.waitingStation and rules and (rules.waitForCircuit or rules.jumpToCircuit) then
        --TODO proper error message
        debugDump("No smart trainstop with rule that requires one", true) --TODO localisation
        return
      end
      LOGGERS.main.log(serpent.line(rules, {comment=false}))
      local nextUpdate = current_tick + global.settings.intervals.write
      local nextRulesCheck = current_tick + global.settings.intervals.read
      local nextCargoRule = current_tick + global.settings.intervals.cargoRule
      if self.train.schedule.records[self.train.schedule.current].time_to_wait == 10 then
        nextUpdate = current_tick + 2
        nextRulesCheck = current_tick + 9
      end
      self.waiting = {}
      self.waitForever = false

      -- update cargo (only if smart stop or full/empty/noChange rule set
      -- write to combinator (only if smart stop)
      local cargo
      if (rules and ( rules.empty or rules.full or rules.noChange) ) or self.waitingStation then
        cargo = self:cargoCount()
        self:setCircuitSignal()
        log("insert cargo")
        insertInTable(global.update_cargo, nextUpdate, self)
        self.update_cargo = nextUpdate
        if rules and rules.noChange then
          self.waiting.cargo = cargo
          self.waiting.nextCargoCheck = current_tick + global.settings.intervals.noChange
          self.waiting.lastCargoCheck = current_tick
        end
      end

      if rules then
        if rules.keepWaiting then
          --debugDump(util.formattime(current_tick,true).." waitForever set",true)
          self.waitForever = true
        end
        -- read signal from lamp (only if smart stop and (waitForCircuit or goto signal)
        -- read signal value from lamp (only if smart stop and (signal == true and ((waitForCircuit and not requireBoth) or (full/empty and goto signal))
        -- check rules
        if rules.waitForCircuit or rules.full or rules.empty or rules.noChange then
          log("insert signal")
          insertInTable(global.check_rules, nextRulesCheck, self)
          self.waiting.nextCheck = nextRulesCheck
          self.waiting.nextCargoRule = nextCargoRule
        end
        
        if rules.empty or rules.full or rules.noChange or rules.waitForCircuit then
          self:flyingText("waiting for rules", colors.YELLOW)
        end
        --TODO copy rules for that station to train
      end
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
      if self.waitingStation and self.waitingStation.cargo and self.waitingStation.cargo.valid then
        local cargoProxy = self.waitingStation.cargo
        --local output = cargoProxy.get_circuit_condition(1)
        local output = {parameters={}}

        local min_fuel = self:lowestFuel()
        output.parameters[1]={signal={type = "virtual", name = "signal-train-at-station"}, count = 1, index = 1}
        output.parameters[2]={signal={type = "virtual", name = "signal-locomotives"}, count = #self.train.locomotives.front_movers+#self.train.locomotives.back_movers, index = 2}
        output.parameters[3]={signal={type = "virtual", name = "signal-cargowagons"}, count = #self.train.cargo_wagons, index = 3}


        output.parameters[4]={signal={type = "virtual", name = "signal-passenger"}, count = self.passengers, index = 4}
        output.parameters[5]={signal={type = "virtual", name = "signal-lowest-fuel"}, count = min_fuel, index = 5}

        local i=6
        if self.line and global.trainLines[self.line] and global.trainLines[self.line].settings.number ~= 0 then
          output.parameters[6]={signal={type = "virtual", name = "signal-line"}, count = global.trainLines[self.line].settings.number, index = 6}
          i=7
        end

        local cargoCount = self:cargoCount(true)
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
        cargoProxy.set_circuit_condition(1,output)
      end
    end,

    updateCircuitSignal = function(self)
      if self.waitingStation and self.waitingStation.cargo and self.waitingStation.cargo.valid then
        local cargoProxy = self.waitingStation.cargo
        local output = cargoProxy.get_circuit_condition(1)

        local min_fuel = self:lowestFuel()

        output.parameters[4].count = self.passengers
        output.parameters[5].count = min_fuel

        local i=6
        if self.line and global.trainLines[self.line] and global.trainLines[self.line].settings.number ~= 0 then
          output.parameters[6]={signal={type = "virtual", name = "signal-line"}, count = global.trainLines[self.line].settings.number, index = 6}
          i=7
        end

        local cargoCount = self:cargoCount(true)
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
        cargoProxy.set_circuit_condition(1,output)
      end
    end,

    resetCircuitSignal = function(self)
      if self.waitingStation and self.waitingStation.cargo and self.waitingStation.cargo.valid then
        self.waitingStation.cargo.set_circuit_condition(1, {parameters={}})
      end
    end,

    --returns fuelvalue (in MJ)
    lowestFuel = function(self)
      --TODO cache result for ~1s?
      if self.last_fuel_update +60 <= game.tick then
        local minfuel
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
          self.minFuel = minfuel
        else
          self.minFuel = 0
        end
      end
      return self.minFuel
    end,

    calcFuel = function(self, contents)
      local value = 0
      --/c game.player.print(game.player.character.vehicle.train.locomotives.front_movers[1].energy)
      for i, c in pairs(contents) do
        value = value + c*fuelvalue(i)
      end
      return value
    end,

    cargoCount = function(self, exact)
      local current_tick = game.tick
      if (not exact and self.cargoUpdated > current_tick - 12) or self.cargoUpdated == current_tick then -- update cargo only if older than 12 ticks (default circuit update rate)
        --LOGGERS.main.log("cached cargo "..self.name)
        log("cached cargo")
        return self.cargo
      end
      if self.cargoUpdated + global.settings.intervals.write <= current_tick then
        --log("new cargo")
        --LOGGERS.main.log("update cargo "..self.name)
        local sum = {}
        local train = self.train
        if not self.railtanker and not self.proxy_chests then
          sum = train.get_contents()
        else
          for i, wagon in pairs(train.cargo_wagons) do
            if not self.proxy_chests or not self.proxy_chests[i] then
              if wagon.name ~= "rail-tanker" then
                --sum = sum + wagon.getcontents()
                sum = addInventoryContents(sum, wagon.get_inventory(1).get_contents())
              else
                if remote.interfaces.railtanker and remote.interfaces.railtanker.getLiquidByWagon then
                  local d = remote.call("railtanker", "getLiquidByWagon", wagon)
                  if d.type ~= nil then
                    sum[d.type] = sum[d.type] or 0
                    sum[d.type] = sum[d.type] + d.amount
                    --self:flyingText(d.type..": "..d.amount, colors.YELLOW, {offset={x=wagon.position.x,y=wagon.position.y+1}})
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
        end
        self.cargo = sum
        self.cargoUpdated = current_tick
      end
      return self.cargo
    end,

    cargoEquals = function(self, c1, c2, minFlow, interval)
      local liquids1 = {}
      local liquids2 = {}
      local goodflow = false
      local fluids = game.fluid_prototypes
      c1 = c1 or {}
      c2 = c2 or {}
      --log("c1 "..serpent.line(c1))
      --log("c2 "..serpent.line(c2))
      local abs = math.abs
      for l,_ in pairs(fluids) do
        liquids1[l], liquids2[l] = false, false
        if c1[l] ~= nil or c2[l] ~= nil then
          liquids1[l] = c1[l] or 0
          liquids2[l] = c2[l] or 0
          local flow = (liquids1[l] - liquids2[l])/(interval/60)
          if abs(flow) >= minFlow then
            goodflow = true
          end
          --self:flyingText("flow: "..flow, colors.YELLOW, {offset=1})
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
      if not self.railtanker and not self.proxy_chests then
        return train.get_item_count() == 0
      end
      local floor = math.floor
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
                if floor(d.amount) > 0 then
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
      local inv_full = function(inv, wagon)
        --check if all slots are blocked
        if inv.can_insert{name="railgun", count=1} then
          --inserted railgun -> at least 1 slot is free
          return false
        end
        if inv.hasbar() and inv.getbar() == 0 then
          return false
        end
        -- check if all stacks are full
        local contents = inv.get_contents()
        for item, _ in pairs(contents) do
          if inv.can_insert{name=item, count=1} then
            return false
          end
        end
        if wagon and self.has_filter then
          local filtered_item
          for i=1, #inv do
            filtered_item = wagon.get_filter(i)
            if filtered_item then
              if inv.can_insert{name=filtered_item, count=1} then return false end
            end
          end
        end
        -- all stacks are full, filtered slots are full
        return true
      end
      local ceil = math.ceil
      for i, wagon in pairs(train.cargo_wagons) do
        if self.proxy_chests and self.proxy_chests[i] then
          --wagon is used by logistics railway
          local chest = self.proxy_chests[i]
          local inventory = chest.get_inventory(defines.inventory.chest)
          if not inv_full(inventory) then return false end
        else
          if wagon.name ~= "rail-tanker" then
            local inv = wagon.get_inventory(1)
            if not inv_full(inv, wagon) then return false end
          else
            if remote.interfaces.railtanker and remote.interfaces.railtanker.getLiquidByWagon then
              local d = remote.call("railtanker", "getLiquidByWagon", wagon)
              if ceil(d.amount) < 2500 then
                return false
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
        self.advancedState = trainstate.left_station
        --debugDump(game.tick.." left_station",true)
      else
        self.advancedState = false
      end
    end,

    --- Update a trainline
    -- @return #boolean whether the line was updated
    updateLine = function(self)
      if self.train.speed ~= 0 or self.opened or self.train.state == defines.trainstate.arrive_signal or self.train.state == defines.trainstate.wait_signal then
        return false
      end
      --log(game.tick .. " update line")
      local oldmode = self.train.manual_mode
      if self.line and global.trainLines[self.line] then
        if self.settings.autoRefuel and self.train.schedule.current == inSchedule(self:refuelStation(), self.train.schedule) and self.train.schedule.current == #self.train.schedule then
          self:flyingText("Skipping line update, refueling", colors.YELLOW)
          return false
        end
        local trainLine = global.trainLines[self.line]
        if self.line and trainLine.changed <= self.lineVersion then
          return true --already updated
        end
        if self.line then
          --debugDump("updating line "..self.line.." train: "..self.train.carriages[1].backer_name,true)
          local rules = trainLine.rules
          if self.lineVersion >= 0 then
            self:flyingText("updating schedule", colors.YELLOW) --TODO localisation
          end
          --TODO copy rule to train if waiting at a station
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
          if self.train.state == defines.trainstate.wait_station and not inLine then
            self:flyingText("Current station not in new schedule, skipping update", colors.RED) --TODO localisation
            log(game.tick .. "Current station not in new schedule, skipping update")
            return false
          end
          if inLine then
            schedule.current = inLine
          else
            schedule.current = 1
          end
          self.settings.autoRefuel = trainLine.settings.autoRefuel
          self.lineVersion = trainLine.changed
          self.train.manual_mode = true
          self.train.schedule = schedule
          self.train.manual_mode = oldmode
          LOGGERS.main.log("Train updated schedule for line " .. self.line .. "\t\t train: " .. self.name)
          return true
        end
      elseif (self.line and not global.trainLines[self.line]) then
        self:flyingText("Dettached from line", colors.RED) --TODO localisation
        local schedule = self.train.schedule
        for _, record in pairs(schedule.records) do
          if record.time_to_wait == 2^32-1 then
            record.time_to_wait = 200*60
          end
        end
        LOGGERS.main.log("Train detached from line " .. self.line .. "\t\t train: " .. self.name)
        self.waitForever = false
        self.line = false
        self.lineVersion = false

        self.train.manual_mode = true
        self.train.schedule = schedule
        self.train.manual_mode = oldmode
        return true
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
