if mods["IndustrialRevolution"] then
    local tech = data.raw["technology"]["automated-rail-transportation"]
    if not tech.effects then tech.effects = {} end
    local found = false
    for _, effect in pairs(tech.effects) do
        if effect.type and effect.type == "unlock-recipe" and effect.recipe == "smart-train-stop" then
            found = true
            break
        end
    end
    if not found then
        table.insert(tech.effects,
        {
            type="unlock-recipe",
            recipe = "smart-train-stop"
        })
    end
    data.raw.recipe["smart-train-stop"].ingredients = {
        {"train-stop", 1},
        {"controller-mk1", 2}
    }
end