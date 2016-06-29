function get_waiting_time(record)
  if (record.wait_conditions ~= nil) then
    for _, cond in pairs(record.wait_conditions) do
      if (cond.type == "time") then
--        game.players[1].print(cond.ticks)
        return cond.ticks
      end
    end
  end   
  return 0;
end


function copyPrototype(type, name, newName)
  if not data.raw[type][name] then error("type "..type.." "..name.." doesn't exist") end
  local p = table.deepcopy(data.raw[type][name])
  p.name = newName
  if p.minable and p.minable.result then
    p.minable.result = newName
  end
  if p.place_result then
    p.place_result = newName
  end
  if p.result then
    p.result = newName
  end
  return p
end

return copyPrototype