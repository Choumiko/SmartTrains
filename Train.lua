Train = {}
function Train:new(train)
  local o = train or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

Train.__eq = function(trainA, trainB)
  return trainA.train.carriages[1].equals(trainB.train.carriages[1])
end

function Train:printName()
  debugDump(self.name, true)
end

function Train:nextStation()
  local train = self.train
  if train.manualmode == false then
    local schedule = train.schedule
    local tmp = (schedule.current % #schedule.records) + 1
    train.manualmode = true
    schedule.current = tmp
    train.schedule = schedule
    train.manualmode = false
  end
end

function Train:startRefueling()
  self.refueling = {nextCheck = game.tick + glob.settings.depart.interval}
  --debugDump({refuel= util.formattime(game.tick)},true)
  local tick = self.refueling.nextCheck
  if not glob.ticks[tick] then
    glob.ticks[tick] = {self}
  else
    table.insert(glob.ticks[tick], self)
  end
end

function Train:isRefueling()
  return type(self.refueling) == "table" and self.settings.autoRefuel
end

function Train:refuelingDone(done)
  if done then
    self.refueling = false
    self:nextStation()
  end
end

function Train:startWaiting()
  self.waiting = {cargo = self:cargoCount(), lastCheck = game.tick, nextCheck = game.tick + glob.settings.depart.minWait}
  local tick = self.waiting.nextCheck
  if not glob.ticks[tick] then
    glob.ticks[tick] = {self}
  else
    table.insert(glob.ticks[tick], self)
  end
end

function Train:isWaiting()
  return type(self.waiting) == "table" and self.settings.autoDepart
end

function Train:waitingDone(done)
  if done then
    self.waiting = false
    self:nextStation()
  end
end

function Train:lowestFuel()
  local minfuel = nil
  local c
  local locos = self.train.locomotives
  if locos ~= nil then
    for i,carriage in ipairs(locos.frontmovers) do
      c = self:calcFuel(carriage.getinventory(1).getcontents())
      if minfuel == nil or c < minfuel then
        minfuel = c
      end
    end
    for i,carriage in ipairs(locos.backmovers) do
      c = self:calcFuel(carriage.getinventory(1).getcontents())
      if minfuel == nil or c < minfuel then
        minfuel = c
      end
    end
    return minfuel
  else
    return 0
  end
end

function Train:calcFuel(contents)
  local value = 0
  --/c game.player.print(game.player.character.vehicle.train.locomotives.frontmovers[1].energy)
  for i, c in pairs(contents) do
    value = value + c*fuelvalue(i)
  end
  return value
end

function Train:cargoCount()
  local sum = {}
  local train = self.train
  for i, wagon in ipairs(train.carriages) do
    if wagon.type == "cargo-wagon" then
      if wagon.name ~= "rail-tanker" then
        --sum = sum + wagon.getcontents()
        sum = addInventoryContents(sum, wagon.getinventory(1).getcontents())
      else
        if remote.interfaces.railtanker and remote.interfaces.railtanker.getLiquidByWagon then
          local d = remote.call("railtanker", "getLiquidByWagon", wagon)
          if d.type ~= nil then
            sum[d.type] = sum[d.type] or 0
            sum[d.type] = sum[d.type] + d.amount
            --self:flyingText(d.type..": "..d.amount, YELLOW, {offset=wagon.position})
          end
        end
      end
    end
  end
  return sum
end

function Train:cargoEquals(c1, c2, minFlow, interval)
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
end

function Train:updateState()
  self.previousState = self.state
  self.state = self.train.state
  if self.previousState == defines.trainstate["waitstation"] and self.state == defines.trainstate["onthepath"] then
    self.advancedState = defines.trainstate["leftstation"]
  else
    self.advancedState = false
  end
end

function Train:nextValidStation()
  local schedule = self.train.schedule
  local train = self.train
  local old = schedule.current
  local tmp = schedule.current
  local rules = glob.trainLines[self.line].rules
  local skipped, c = "", 0
  if self.line and rules[tmp] and not (inSchedule(glob.settings.refuel.station, schedule) and self.settings.autoRefuel) then
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
      if glob.settings.lines.forever then
        self:flyingText("Invalid rules", RED, {offset=1, show=true})
        local prevStation = (schedule.current-2) % #schedule.records + 1
        train.manualmode = true
        schedule.current = prevStation
        train.schedule = schedule
        train.manualmode = false
        return
      else

      end
    elseif skipped ~= "" then
      self:flyingText("Skipped stations: "..skipped, YELLOW, {offset=1})
    end
    assert(tmp <= #schedule.records)
    --debugDump("going to "..schedule.records[tmp].station, true)
    train.manualmode = true
    schedule.current = tmp
    train.schedule = schedule
    train.manualmode = false
  end
end

function Train:flyingText(msg, color, tbl)
  local s = glob.showFlyingText
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
  flyingText(msg, color, pos, s)
end
