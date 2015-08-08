for _, force in pairs(game.forces) do
  force.reset_recipes()
  force.reset_technologies()
  local techs = force.technologies
  local recipes = force.recipes
  if techs["automated-rail-transportation"].researched then
    recipes["smart-train-stop"].enabled = true
  end
end
