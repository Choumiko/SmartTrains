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
          advancedState = false
        }
        new.settings.autoDepart = defaultTrainSettings.autoDepart
        new.settings.autoRefuel = defaultTrainSettings.autoRefuel
        if train.locomotives ~= nil and (#train.locomotives.front_movers > 0 or #train.locomotives.back_movers > 0) then
          new.name = train.locomotives.front_movers[1].backer_name or train.locomotives.back_movers[1].backer_name
        else
          new.name = "cargoOnly"
        end
        setmetatable(new, {__index = Train})
        new.type = new:getType()
        return new
      end
    end,

    getType = function(self)
      local type = string.rep("L",#self.train.locomotives.front_movers).."-"..string.rep("C", #self.train.cargo_wagons).."-"..string.rep("L",#self.train.locomotives.back_movers)
      return string.gsub(string.gsub(type, "^-", ""), "-$", "")
    end,

    printName = function(self)
      debugDump(self.name, true)
    end,

    nextStation = function(self)
      local train = self.train
      if train.manual_mode == false then
        local schedule = train.schedule
        local tmp = (schedule.current % #schedule.records) + 1
        train.manual_mode = true
        schedule.current = tmp
        train.schedule = schedule
        train.manual_mode = false
      end
    end,

    refuelStation = function(self)
      return global.settings.refuel.station.. " "..self:getType()
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
        self:flyingText("Refuel station removed", YELLOW)
      end
    end,

    startWaiting = function(self)
      self.waiting = {cargo = self:cargoCount(), lastCheck = game.tick, nextCheck = game.tick + global.settings.depart.minWait}
      local tick = self.waiting.nextCheck
      if not global.ticks[tick] then
        global.ticks[tick] = {self}
      else
        table.insert(global.ticks[tick], self)
      end
    end,

    isWaiting = function(self)
      return type(self.waiting) == "table" and self.settings.autoDepart
    end,

    waitingDone = function(self, done)
      if done then
        self.waiting = false
        self:nextStation()
      end
    end,

    lowestFuel = function(self)
      local minfuel = nil
      local c
      local locos = self.train.locomotives
      if locos ~= nil then
        for i,carriage in pairs(locos.front_movers) do
          c = self:calcFuel(carriage.get_inventory(1).get_contents())
          if minfuel == nil or c < minfuel then
            minfuel = c
          end
        end
        for i,carriage in pairs(locos.back_movers) do
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
      local sum = {}
      local train = self.train
      for i, wagon in pairs(train.carriages) do
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
                self:flyingText(d.type..": "..math.floor(d.amount), YELLOW, {offset={x=wagon.position.x,y=wagon.position.y+1}})
              end
            end
          end
        end
      end
      return sum
    end,

    cargoEquals = function(self, c1, c2, minFlow, interval)
      local liquids1 = {}
      local liquids2 = {}
      local goodflow = false
      for l,_ in pairs(fluids) do
        liquids1[l], liquids2[l] = false, false
        if c1[l] ~= nil or c2[l] ~= nil then
          liquids1[l] = c1[l] or 0
          liquids2[l] = c2[l] or 0
          local flow = (liquids1[l] - liquids2[l])/(interval/60)
          if math.abs(flow) >= minFlow then goodflow = true end
          self:flyingText("flow: "..flow, YELLOW, {offset=1})
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

    updateState = function(self)
      self.previousState = self.state
      self.state = self.train.state
      if self.previousState == defines.trainstate["wait_station"] and self.state == defines.trainstate["on_the_path"] then
        self.advancedState = defines.trainstate["left_station"]
      else
        self.advancedState = false
      end
    end,

    updateLine = function(self)
      if self.line and global.trainLines[self.line] then
        local trainLine = global.trainLines[self.line]
        if self.line and trainLine.changed > self.lineVersion then
          local waitingAt = self.train.schedule.records[self.train.schedule.current]
          self.train.manual_mode = true
          local schedule = {records={}}
          for i, record in pairs(trainLine.records) do
            schedule.records[i] = record
          end
          local inLine = inSchedule(waitingAt.station,schedule)
          if inLine then
            schedule.current = inLine
          else
            schedule.current = 1
          end
          self.train.schedule = schedule
          self.settings.autoRefuel = trainLine.settings.autoRefuel
          self.settings.autoDepart = trainLine.settings.autoDepart
          self.train.manual_mode = false
          self.lineVersion = trainLine.changed
          self:flyingText("updating schedule", YELLOW)
        end
      elseif self.line and not global.trainLines[self.line] then
        self:flyingText("Dettached from line", RED)
        self.line = false
        self.lineVersion = false
      end
    end,

    nextValidStation = function(self)
      local schedule = self.train.schedule
      local train = self.train
      local old = schedule.current
      local tmp = schedule.current
      local rules = global.trainLines[self.line].rules
      local skipped, c = "", 0
      if self.line and rules[tmp] and not (inSchedule(global.settings.refuel.station, schedule) and self.settings.autoRefuel) then
        local cargo = self:cargoCount()
        local filter = rules[tmp].filter
        local filter = filter:match("st%-fluidItem%-(.+)") or rules[tmp].filter
        local item = cargo[filter] or 0
        local compare = rules[tmp].condition
        if compare == "=" then compare = "==" end
        local cond = string.format("return %f %s %f", item, compare, rules[tmp].count)
        local f = assert(loadstring(cond))()
        --debugDump({cond, f},true)
        if not f then
          skipped = schedule.records[tmp].station
          c = c+1
          for i=1,#schedule.records do
            local k = math.abs(i + tmp - 1) % (#schedule.records)+1
            if not rules[k] then
              tmp = k
              break
            else
              local cargo = self:cargoCount()
              local filter = rules[k].filter
              local filter = filter:match("st%-fluidItem%-(.+)") or rules[k].filter
              local item = cargo[filter] or 0
              local item = cargo[rules[k].filter] or 0
              local compare = rules[k].condition
              if compare == "=" then compare = "==" end
              local cond = string.format("return %f %s %f", item, compare, rules[k].count)
              local f = assert(loadstring(cond))()
              --debugDump({cond, f},true)
              if f then
                tmp = k
                break
              end
              skipped = skipped..", "..schedule.records[k].station
              c=c+1
            end
          end
        end
        if #schedule.records <= c+1 then
          if global.settings.lines.forever then
            self:flyingText("Invalid rules", RED, {offset=1, show=true})
            local prevStation = (schedule.current-2) % #schedule.records + 1
            train.manual_mode = true
            schedule.current = prevStation
            train.schedule = schedule
            train.manual_mode = false
            return
          else

          end
        elseif skipped ~= "" then
          self:flyingText("Skipped stations: "..skipped, YELLOW, {offset=1})
        end
        assert(tmp <= #schedule.records)
        --debugDump("going to "..schedule.records[tmp].station, true)
        train.manual_mode = true
        schedule.current = tmp
        train.schedule = schedule
        train.manual_mode = false
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
      self.train.carriages[1].surface.create_entity({name="flying-text", position=pos, text=msg, color=color})
    end
}
Train.__eq = function(trainA, trainB)
  return trainA.train.carriages[1] == trainB.train.carriages[1]
end
