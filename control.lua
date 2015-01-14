require "defines"
require "util"

require "gui"

local defaultTrainSettings = {autoRefuel = true, autoDepart = true}
local defaultSettings =
  { refuel={station="Refuel", rangeMin = 25, rangeMax = 50, time = 300},
    depart={minWait = 240, interval = 120, minFlow = 1}}
--local fluids ={["crude-oil"] = true, water=true, ["heavy-oil"]=true, ["light-oil"]=true, ["petroleum-gas"]=true,lubricant=true,["sulfuric-acid"]=true}
local fluids = false
showFlyingText = false

MOD = {version="0.1.6"}
local tmpPos = {}
local RED = {r = 0.9}
local GREEN = {g = 0.7}
local YELLOW = {r = 0.8, g = 0.8}

defines.trainstate["leftstation"] = 11

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
  self.refueling = {arrived = game.tick}
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
  self.waiting = {cargo = self:cargoCount(), arrived = game.tick, lastCheck = false}
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

function Train:nextValidStation(station)
  local schedule = self.train.schedule
  --local tmp = (schedule.current % #schedule.records) + 1
  local tmp = station or schedule.current
  local rules = glob.trainLines[self.line].rules
  if self.line and rules[tmp] then
    local cargo = self:cargoCount()
    local item = cargo[rules[tmp].filter] or 0
    local cond = string.format("return %f %s %f", item, rules[tmp].condition, rules[tmp].count)
    local f = assert(loadstring(cond))()
    if not f then
-- schedule iterator needed?    
      for i=tmp+1,#schedule.records do
        if not rules[i] then
          tmp = i
          break
        else
          local cargo = self:cargoCount()
          local item = cargo[rules[tmp].filter] or 0
          local cond = string.format("return %f %s %f", item, rules[tmp].condition, rules[tmp].count)
          local f = assert(loadstring(cond))()
          if f then
            tmp = i
            break
          end
        end
      end
    end
    local train = self.train
    if train.manualmode == false then
      train.manualmode = true
      schedule.current = tmp
      train.schedule = schedule
      train.manualmode = false
    end
  end
end

function getTrainKeyFromUI(index)
  local player = game.players[index]
  if player.opened.type == "locomotive" and player.opened.train ~= nil then
    local key = getKeyByTrain(glob.trains, player.opened.train)
    if not key then
      local ti = getNewTrainInfo(player.opened.train)
      table.insert(glob.trains, ti)
      key = getKeyByTrain(glob.trains, player.opened.train)
    end
    return key
  end
  return nil --should never happen
end

function onplayercreated(event)
  local player = game.getplayer(event.playerindex)
  local gui = player.gui
  if gui.left.stGui == nil then
    buildGUI(player)
  end
end

function initGlob()
  if glob.version == nil or glob.version < MOD.version then
    local v = glob.version or "Nil"
    saveGlob("PreInitv"..v)
  end
  if glob.version == nil or glob.version < "0.1.0" then
    local v = glob.version or "Nil"
    saveGlob("PreInitv"..v)
    glob.trains = nil
    glob.waitingTrains = nil
    glob.refuelTrains = nil
    glob.trainLines = nil
    glob.settings = nil
    for i,p in ipairs(game.players) do
      destroyGui(p.gui.left.stGui)
      destroyGui(p.gui.center.stGui)
      destroyGui(p.gui.top.stButtons)
    end
    glob.guiDone = nil
    glob.version = "0.1.0"
    saveGlob("Initv"..glob.version)
  end
  glob.trains = glob.trains or {}
  glob.waitingTrains = glob.waitingTrains or {}
  glob.refuelTrains = glob.refuelTrains or {}
  glob.trainLines = glob.trainLines or {}
  glob.settings = glob.settings or defaultSettings
  glob.guiDone = glob.guiDone or {}

  if glob.version < "0.1.5" then
    glob.init = nil
    glob.showFlyingText = showFlyingtext
    glob.settings.depart.minFlow = glob.settings.depart.minFlow or defaultSettings.depart.minFlow
    local tmpW = {}
    local tmpR = {}
    for i,t in pairs(glob.trains) do
      t.dynamic = t.dynamic or false
      t.line = t.line or false
      t.lineVersion = t.lineVersion or false
      local cpDepart, cpRefuel = t.settings.autoDepart, t.settings.autoRefuel
      t.settings = {autoDepart = cpDepart, autoRefuel = cpRefuel}
      for wi, wt in pairs(glob.waitingTrains) do
        if trainEquals(t.train,wt.train) then
          t.waiting = {cargo = wt.cargo, arrived = wt.arrived, lastCheck = wt.lastCheck}
          if t.waiting.cargo or t.waiting.arrived or t.waiting.lastCheck then
            table.insert(tmpW, t)
          else
            t.waiting = false
          end
        end
      end
      for ri,tr in pairs(glob.refuelTrains) do
        if trainEquals(t.train, tr.train) then
          t.refueling = {arrived = tr.arrived}
          if t.refueling.arrived then
            table.insert(tmpR, t)
          else
            t.refueling = false
          end
        end
      end
    end
    glob.waitingTrains = tmpW
    glob.refuelTrains = tmpR
    for i,t in pairs(glob.trains) do
      if not t.waiting then t.waiting = false end
      if not t.refueling then t.refueling = false end
    end
    for i,l in pairs(glob.trainLines) do
      if l.line then l.line=nil end
      l.changed = 0
    end
    glob.version = "0.1.5"
    saveGlob("Initv"..glob.version)
  end

  if glob.version < "0.1.7" then
    local tmp = {}
    for i,t in ipairs(glob.trains) do
      local tr = Train:new(t)
      table.insert(tmp, tr)
    end
    glob.trains = tmp
    glob.refuelTrains, glob.waitingTrains = nil, nil
    glob.guiData = glob.guiData or {}
  end

  for i,p in ipairs(game.players) do
    if not glob.guiDone[p.name] then
      buildGUI(p)
      glob.guiDone[p.name] = true
    end
  end
  for _, object in pairs(glob.trains) do
    setmetatable(object, Train)
    assert(getmetatable(object)== Train)
  end
  if #glob.trains >=2 then
    assert(glob.trains[1] == glob.trains[1])
    assert(glob.trains[1] ~= glob.trains[2])
    assert(glob.trains[2] ~= glob.trains[1])
    assert(glob.trains[2] == glob.trains[2])
  end
  if not fluids then
    fluids = {}
    for index, item in pairs(game.itemprototypes) do
      local fluid = index:match("st%-fluidItem%-(.+)")
      if fluid then
        fluids[fluid] = true
      end
    end
  end
  if glob.version <= MOD.version then saveGlob("PostInit") end
  glob.version = MOD.version
end

function oninit() initGlob() end

function onload()
  --glob.version = nil --uncomment this line for a hard reset (all SmartTrain settings will be lost)
  initGlob()
  local rem = removeInvalidTrains()
  if rem > 0 then debugDump("You should never see this! Removed "..rem.." invalid trains") end
end

function trainEquals(trainA, trainB)
  return trainA.carriages[1].equals(trainB.carriages[1])
end

function getKeyByTrain(tableA, train)
  for i, t in ipairs(tableA) do
    if trainEquals(t.train, train) then
      return i
    end
  end
  return false
end

function getNewTrainInfo(train)
  if train ~= nil then
    local carriages = train.carriages
    if carriages ~= nil and carriages[1] ~= nil and carriages[1].valid then
      local newTrainInfo = {dynamic = false, line = false, settings = {}, waiting = false, refueling = false}
      newTrainInfo.train = train
      if train.locomotives ~= nil and (#train.locomotives.frontmovers > 0 or #train.locomotives.backmovers > 0) then
        newTrainInfo.name = train.locomotives.frontmovers[1].backername or train.locomotives.backmovers[1].backername
      else
        newTrainInfo.name = "cargoOnly"
      end
      newTrainInfo.settings = {autoDepart = defaultTrainSettings.autoDepart, autoRefuel = defaultTrainSettings.autoRefuel}
      newTrainInfo.lineVersion = 0
      return Train:new(newTrainInfo)
    end
  end
end

function removeInvalidTrains()
  local removed = 0
  for i,t in ipairs(glob.trains) do
    if not t.train.valid then
      table.remove(glob.trains, i)
      removed = removed + 1
    end
  end
  return removed
end

function inSchedule(station, schedule)
  for i, rec in ipairs(schedule.records) do
    if rec.station == station then
      return i
    end
  end
  return false
end

function removeStation(station, schedule)
  local found = false
  local tmp = schedule
  for i, rec in ipairs(schedule.records) do
    if rec.station == station then
      found = i
    end
  end
  if found then
    table.remove(schedule.records, found)
  end
  return tmp
end

function addStation(station, schedule, wait, after)
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

function fuelvalue(item)
  return game.itemprototypes[item].fuelvalue
end

function addInventoryContents(invA, invB)
  local res = {}
  for item, c in pairs(invA) do
    invB[item] = invB[item] or 0
    res[item] = c + invB[item]
    invB[item] = nil
    if res[item] == 0 then res[item] = nil end
  end
  for item,c in pairs(invB) do
    res[item] = c
    if res[item] == 0 then res[item] = nil end
  end
  return res
end

function getKeyByValue(tableA, value)
  for i,c in pairs(tableA) do
    if c == value then
      return i
    end
  end
end

function ontrainchangedstate(event)
  local train = event.train
  local trainKey = getKeyByTrain(glob.trains, train)
  if not trainKey then
    table.insert(glob.trains, getNewTrainInfo(train))
    removeInvalidTrains()
    trainKey = getKeyByTrain(glob.trains, train)
  end
  local t = glob.trains[trainKey]
  t:updateState()
  local settings = glob.trains[trainKey].settings
  local fuel = t:lowestFuel()
  local schedule = train.schedule
  if train.state == defines.trainstate["waitstation"] then
    if t.line and glob.trainLines[t.line] then
      if t.line and glob.trainLines[t.line].changed ~= t.lineVersion then
        local waitingAt = t.train.schedule.records[t.train.schedule.current]
        t.train.manualmode = true
        schedule = {records={}}
        local trainLine = glob.trainLines[t.line]
        for i, record in ipairs(trainLine.records) do
          schedule.records[i] = record
        end
        local inLine = inSchedule(waitingAt.station,schedule)
        if inLine then
          schedule.current = inLine
        else
          schedule.current = 1
        end
        t.train.schedule = schedule
        t.train.manualmode = false
        t.lineVersion = trainLine.changed
        flyingText("updating schedule", YELLOW, train.carriages[1].position, glob.showFlyingText)
      end
    elseif t.line and not glob.trainLines[t.line] then
      flyingText("Dettached from line", RED, train.carriages[1].position, glob.showFlyingText)
      t.line = false
      t.lineVersion = false
    end
  end
  --Handle line rules here
  if t.advancedState == defines.trainstate["leftstation"] and glob.trainLines[t.line].rules then
    flyingText("checking line rules", RED, train.carriages[1].position, glob.showFlyingText)
    t:nextValidStation()
  end
  if train.state == defines.trainstate["waitstation"] then
    if settings.autoRefuel then
      if fuel >= (glob.settings.refuel.rangeMax * fuelvalue("coal")) and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
        if inSchedule(glob.settings.refuel.station, schedule) and #schedule.records >= 3 then
          train.schedule = removeStation(glob.settings.refuel.station, schedule)
          flyingText("Refuel station removed", YELLOW, train.carriages[1].position, glob.showFlyingText)
        end
      end
      if schedule.records[schedule.current].station == glob.settings.refuel.station then
        t:startRefueling()
        flyingText("refueling", YELLOW, train.carriages[1].position, glob.showFlyingText)
      end
    end
    if settings.autoDepart and schedule.records[schedule.current].station ~= glob.settings.refuel.station then
      t:startWaiting()
      flyingText("waiting", YELLOW, train.carriages[1].position, glob.showFlyingText)
    end
  elseif train.state == defines.trainstate["arrivestation"]  or train.state == defines.trainstate["waitsignal"] or train.state == defines.trainstate["arrivesignal"] or train.state == defines.trainstate["onthepath"] then
    if settings.autoRefuel then
      if fuel < (glob.settings.refuel.rangeMin * fuelvalue("coal")) and not inSchedule(glob.settings.refuel.station, schedule) then
        train.schedule = addStation(glob.settings.refuel.station, schedule, glob.settings.refuel.time)
        flyingText("Refuel station added", YELLOW, train.carriages[1].position, glob.showFlyingText)
      end
    end
  end
end

function ontick(event)
  for i,train in pairs(glob.trains) do
    if train:isRefueling() then
      local wait = train.refueling.arrived + glob.settings.depart.interval
      if event.tick >= wait then
        if train:lowestFuel() >= glob.settings.refuel.rangeMax * fuelvalue("coal") then
          flyingText("Refueling done", YELLOW, train.train.carriages[1].position, glob.showFlyingText)
          train:refuelingDone(true)
        end
      end
    end
    if train:isWaiting() then
      local wait = (type(train.waiting.arrived) == "number") and train.waiting.arrived + glob.settings.depart.minWait or train.waiting.lastCheck + glob.settings.depart.interval
      if event.tick >= wait then
        local cargo = train:cargoCount()
        local last = train.waiting.arrived or train.waiting.lastCheck
        if train:cargoEquals(cargo, train.waiting.cargo, glob.settings.depart.minFlow, event.tick - last) then
          flyingText("cargoCompare -> leave station", YELLOW, train.train.carriages[1].position, glob.showFlyingText)
          train:waitingDone(true)
        else
          flyingText("cargoCompare -> stay at station", YELLOW, train.train.carriages[1].position, glob.showFlyingText)
          train.waiting.lastCheck = event.tick
          train.waiting.arrived = false
          train.waiting.cargo = cargo
        end
      end
    end
  end
  if event.tick%10==9  then
    for pi, player in ipairs(game.players) do
      if player.opened ~= nil and player.opened.valid then
        if player.opened.type == "locomotive" and player.opened.train ~= nil then
          local key = getTrainKeyFromUI(pi)
          if player.gui.left.stGui.trainSettings == nil then
            refreshUI(pi)
            showSettingsButton(pi)
          end
        elseif player.opened.type == "train-stop" and player.gui.left.stGui.stSettings.toggleSTSettings == nil and player.gui.left.stGui.stSettings.stGlobalSettings == nil then
          showSettingsButton(pi)
        end
      elseif player.opened == nil then
        local gui=player.gui.left.stGui
        if gui.stSettings ~= nil then
          destroyGui(player.gui.left.stGui.stSettings.toggleSTSettings)
          destroyGui(player.gui.left.stGui.stSettings.stGlobalSettings)
        end
        if gui ~= nil and (gui.trainSettings ~= nil or gui.trainLines ~= nil) then
          destroyGui(player.gui.left.stGui.trainSettings)
          destroyGui(player.gui.left.stGui.dynamicRules)
          destroyGui(player.gui.left.stGui.trainLines)
        end
        glob.guiData[pi] = nil
      end
    end
  end
end

function getTrainKeyFromUI(index)
  local player = game.players[index]
  local key
  if player.opened ~= nil and player.opened.valid then
    if player.opened.type == "locomotive" and player.opened.train ~= nil then
      key = getKeyByTrain(glob.trains, player.opened.train)
      if not key then
        local ti = getNewTrainInfo(player.opened.train)
        table.insert(glob.trains, ti)
        key = getKeyByTrain(glob.trains, player.opened.train)
      end
    end
    return key
  end
end

function onbuiltentity(event)
  local ent = event.createdentity
  local ctype = ent.type
  if ctype == "locomotive" or ctype == "cargo-wagon" then
    local newTrainInfo = getNewTrainInfo(ent.train)
    if newTrainInfo ~= nil then
      removeInvalidTrains()
      table.insert(glob.trains, newTrainInfo)
    end
  end
end

function onpreplayermineditem(event)
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
    local old = getKeyByTrain(glob.trains, ent.train)
    if old then table.remove(glob.trains, old) end

    if #ent.train.carriages > 1 then
      if ent.train.carriages[ownPos-1] ~= nil then
        table.insert(tmpPos, ent.train.carriages[ownPos-1].position)
      end
      if ent.train.carriages[ownPos+1] ~= nil then
        table.insert(tmpPos, ent.train.carriages[ownPos+1].position)
      end
    end
  end
end

function onplayermineditem(event)
  local name = event.itemstack.name
  local results = {}
  if name == "diesel-locomotive" or name == "cargo-wagon" and #tmpPos > 0 then
    for i,pos in ipairs(tmpPos) do
      local area = {{pos.x-1, pos.y-1},{pos.x+1, pos.y+1}}
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
    tmpPos = {}
  end
end

function scheduleToString(schedule)
  local tmp = "Schedule: "
  for i=1,#schedule.records do
    tmp = tmp.." "..schedule.records[i].station.."|"..schedule.records[i].time_to_wait/60
  end
  return tmp.." next: "..schedule.current
end

function debugDump(var, force)
  if false or force then
    for i,player in ipairs(game.players) do
      local msg
      if type(var) == "string" then
        msg = var
      else
        msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
      end
      player.print(msg)
    end
  end
end

function flyingText(line, color, pos, show)
  if show then
    pos = pos or game.player.position
    color = color or RED
    game.createentity({name="flying-text", position=pos, text=line, color=color})
  end
end

function printToFile(line, path)
  path = path or "log"
  path = table.concat({ "st", "/", path, ".lua" })
  game.makefile( path,  line)
end

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function sortByName(a,b)
  return a.name > b.name
end

function findAllEntitiesByType(type)
  local entities = {}
  for coord in game.getchunks() do
    local X,Y = coord.x, coord.y
    if game.ischunkgenerated{X,Y} then
      local area = {{X*32, Y*32}, {X*32 + 32, Y*32 + 32}}
      for i, entity in ipairs(game.findentitiesfiltered{area = area, type = type}) do
        local key = entity.position.x.."A"..entity.position.y
        local name = entity.backername or entity.name
        local train = entity.train or false
        entities[key] = {name= name, pos = entity.position, train=train}
      end
    end
  end
  return entities
end

function saveGlob(name)
  local n = name or ""
  game.makefile("st/debugGlob"..n..".lua", serpent.block(glob, {name="glob"}))
  --game.makefile("st/loco"..n..".lua", serpent.block(findAllEntitiesByType("locomotive")))
end

game.oninit(function() oninit() end)
game.onload(function() onload() end)
game.onevent(defines.events.ontick, function(event) ontick(event) end)
game.onevent(defines.events.ontrainchangedstate, function(event) ontrainchangedstate(event) end)
game.onevent(defines.events.onplayermineditem, function(event) onplayermineditem(event) end)
game.onevent(defines.events.onpreplayermineditem, function(event) onpreplayermineditem(event) end)
game.onevent(defines.events.onbuiltentity, function(event) onbuiltentity(event) end)
game.onevent(defines.events.onguiclick, function(event) onguiclick(event) end)
game.onevent(defines.events.onplayercreated, function(event) onplayercreated(event) end)

remote.addinterface("st",
  {
    printGlob = function(name)
      if name then
        debugDump(glob[name], true)
      else
        debugDump(glob, true)
      end
    end,

    printFile = function(var, name)
      local name = name or "log"
      if glob[var] then
        printToFile(serpent.block(glob[var]), name )
      else
        debugDump("glob["..var.."] not found.")
      end
    end,

    saveGlob = function(name)
      saveGlob(name)
    end,

    hardReset = function(confirm)
      if confirm then
        glob.version = nil
        initGlob()
      end
    end,

    toggleFlyingText = function()
      glob.showFlyingText = not glob.showFlyingText
      debugDump("Flying text: "..tostring(glob.showFlyingText),true)
    end,

    nilGlob = function(key)
      if glob[key] then glob[key] = nil end
    end,

    cleanGui = function()
      for i,player in ipairs(game.players) do
        if player.gui.top.blueprintTools then
          player.gui.top.blueprintTools.destroy()
        end
      end
    end,

    printMeta = function()
      local metas = {}
      for i,to in pairs(glob.trains) do
        table.insert(metas, getmetatable(to))
      end
      printToFile(serpent.block(metas, {name="metas"}), "metatables" )
    end,

  --    findStations = function()
  --      local stations = {}
  --      for coord in game.getchunks() do
  --        local X,Y = coord.x, coord.y
  --        if game.ischunkgenerated{X,Y} then
  --          local area = {{X*32, Y*32}, {X*32 + 32, Y*32 + 32}}
  --          for _, entity in ipairs(game.findentitiesfiltered{area = area, type = "train-stop"}) do
  --            local key = entity.position.x.."A"..entity.position.y
  --            key = string.gsub(key, "-", "_")
  --            stations[key] = {entity.backername, entity.position}
  --          end
  --        end
  --      end
  --      printToFile(serpent.block(stations),"stations")
  --    end
  }
)
