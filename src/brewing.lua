-- made by Nicko21
local Gamestate = require 'vendor/gamestate'
local fonts = require 'fonts'
local window = require 'window'
local sound = require 'vendor/TEsound'
local Item = require 'items/item'
local camera = require 'camera'
local Prompt = require 'prompt'
local HUD = require 'hud'
local potion_recipes = require 'items/potion_recipes'
--instantiate this gamestate
local state = Gamestate.new()

local selectionSprite = love.graphics.newImage('images/inventory/selection.png')

local function nonzeroMod(a,b)
  local m = a % b
  if m ~= 0 then
    return m
  else
    return b
  end
end

bundle = {}

--called once when the gamestate is initialized
function state:init()
end

--called when the player enters this gamestate
--enter may take additional arguments from previous as necessary
--@param previous the actual gamestate that the player came from (not just its name)
function state:enter(previous, player, screenshot, cauldronName)
  fonts.set( 'arial' )
  sound.playMusic( "potionlab" )
  self.previous = previous
  self.screenshot = screenshot
  self.cauldronName = cauldronName
  self.player = player
  self.offset = 0
  
  self.background = love.graphics.newImage('images/potions/potion_menu.png')
  self.backgroundPlain = love.graphics.newImage('images/potions/potion_plain.png')
  self.text = "Recipes can be found throughout the game. It's a good idea to collect them. "..
              "If you don't follow the recipes, you'll make a Dud Potion, which has unpredictable side effects when consumed."

  self.hud = HUD.new(previous)

  local playerMaterials = self.player.inventory.pages.materials
  
  self.playerRecipes = {}
  local count = 1
  for _,currentRecipe in pairs(potion_recipes) do
     if self.player.inventory:hasDetail(currentRecipe.name) then
       self.playerRecipes[count] = {}
       self.playerRecipes[count].name = currentRecipe.name
       self.playerRecipes[count].description = currentRecipe.description
       self.playerRecipes[count].info = currentRecipe.info
       count = count + 1
     end
  end
  
  self.total = count - 1
  self.count = 1

  -- This block creates a table of the players inventory with limits on items and also holds how many ingredients are added
  self.values = {}
  self.referanceValues = {} -- Due to the nature of editing the item data once it is in a table, a second table is made
  self.ingredients = {}
  local temp = {}     -- Temp stores the index of an item in the values list
  local count = 0
  for key,orgiMat in pairs(playerMaterials) do
    mat = {name = orgiMat.name, quantity = orgiMat.quantity, description = orgiMat.description}
    if temp[mat.name] == nil then
      count = count + 1
      temp[mat.name] = count
      table.insert(self.values, mat)
      table.insert(self.referanceValues, orgiMat)
      self.ingredients[mat.name] = 0
    else
      self.values[temp[mat.name]].quantity = self.values[temp[mat.name]].quantity + mat.quantity
    end
  end

  self.selected = 1
  self.overall = self.selected + self.offset
  self.current = self.ingredients[self.values[self.overall].name] or nil
end

--called when this gamestate receives a keypress event
--@param button the button that was pressed
function state:keypressed( button )
  self.overall = self.selected + self.offset
  self.current = self.ingredients[self.values[self.overall].name] or nil

  if button == "START" then
    Gamestate.switch(self.previous)
  elseif button == "UP" then
    if (self.selected - 1) <= 0 then
      if (self.offset > 0) then
        self.offset = self.offset - 1
      end
    else
      self.selected  = self.selected - 1
    end
    sound.playSfx('click')
  elseif button == "DOWN" then
    
    if (self.overall < #self.values) then
      if (self.selected + 1) >= 5 then
        self.offset = self.offset + 1
      else
        self.selected = self.selected + 1
      end
    end
    sound.playSfx('click')
  elseif button == "LEFT" then
    if self.current and not (self.current <= 0) then
      self.current  = self.current - 1
    end
    sound.playSfx('click')
  elseif button == "RIGHT" then
    if self.current and (not (self.current >= 4) and not (self.current >= self.values[self.overall].quantity)) then
      self.current  = self.current + 1
    end
    sound.playSfx('click')
  elseif button == "JUMP" then
    self:check()
  elseif button == "INTERACT" then
    self.count = nonzeroMod(self.count + 1, self.total)
  elseif button == "ATTACK" then
    self.count = nonzeroMod(self.count - 1, self.total)
  end
  self.ingredients[self.values[self.overall].name] = self.current
end

function state:brew( potion )
  local SpriteClass = require('nodes/sprite')
  local ItemClass = require('items/item')

  sound.playSfx( self.cauldronName == 'cauldron' and 'potion_brew' or self.cauldronName)

  for mat,amount in pairs(self.ingredients) do
    self.player.inventory:removeManyItems(amount, {name=mat, type="material"})
  end

  local potionItem = require('items/consumables/'..potion)
  local item = ItemClass.new(potionItem)
  self.player.inventory:addItem(item)

  self.player.freeze = true
  self.player.invulnerable = true
  self.player.character.state = "acquire"
  local message = 'You made a {{red}}'..item.description..'{{white}}!'
  local callback = function(result)
     self.prompt = nil
     self.player.freeze = false
     self.player.invulnerable = false
  end
  local options = {'Exit'}
  local node = SpriteClass.new(
    {x = self.player.position.x +14, 
    y = self.player.position.y - 10, 
    properties = {
      animation = "1,1", 
      sheet = 'images/consumables/'..potion..'.png', 
      width = 24, 
      height = 24, 
      mode='once'
      }
    })
  self.prompt = Prompt.new(message, callback, options, node)
end

function state:check()
  local notBlankBrew = false
  for mat,amount in pairs(self.ingredients) do
    if amount >= 1 then
      notBlankBrew = true
    end
  end
  if notBlankBrew then
    local brewed = false
    Gamestate.switch(self.previous)
    for _,currentRecipe in pairs(potion_recipes) do                           -- The logic behind my checking is to count the amount correct ingredients the player has         
      local correctAmount = 0                                                 -- and compare that to the amount of ingredients in the recipe. If they are the same the
      local recipeLenth = 0                                                   -- player has added in all the correct ingredients and a potion can be brewed.
      local recipe = currentRecipe.recipe
      for mat,amount in pairs(currentRecipe.recipe) do
        recipeLenth = recipeLenth + 1
        if self.ingredients[mat] == amount then
          correctAmount = correctAmount + 1
        end
      end
      if  correctAmount == recipeLenth then
        brewed = true
        self:brew(currentRecipe.name)
        break
      end
    end
    if not brewed then
      brewed = true
      self:brew("black_potion")
    end
  else
    sound.playSfx('dbl_beep')
  end
end

--called when this gamestate receives a keyrelease event
--@param button the button that was released
function state:keyreleased( button )
end

--called when the player leaves this gamestate
function state:leave()
end

-- Called when love draws this gamestate
function state:draw()

  if self.screenshot then
    love.graphics.draw( self.screenshot, camera.x, camera.y, 0, window.width / love.graphics:getWidth(), window.height / love.graphics:getHeight() )
  else
    love.graphics.setColor( 0, 0, 0, 1 )
    love.graphics.rectangle( 'fill', 0, 0, love.graphics:getWidth(), love.graphics:getHeight() )
    love.graphics.setColor( 1, 1, 1, 1 )
  end

  self.hud:draw( self.player )

  local width = window.width
  local height = window.height
  local menu_right = camera.x + width/2 - self.background:getWidth()/2
  local menu_top = camera.y + height/2 - self.background:getHeight()/2
  love.graphics.draw( self.background, menu_right,menu_top, 0 )

  local firstcell_right = menu_right + 30
  local firstcell_top = menu_top + 9

  love.graphics.draw(selectionSprite, 
    love.graphics.newQuad(0,0,selectionSprite:getWidth(),selectionSprite:getHeight(),selectionSprite:getWidth(),selectionSprite:getHeight()),
    firstcell_right, firstcell_top + ((self.selected-1) * 22))

  love.graphics.setColor( 1, 1, 1, 1 )
  love.graphics.printf(self.player.controls:getKey('JUMP') .. " BREW", 0, 200, width, 'center')
  love.graphics.printf(self.player.controls:getKey('START') .. " CANCEL", 0, 213, width, 'center')

  for i = 1,4 do
    if self.values[i+self.offset] ~= nil then
      -- Draw images
      self.referanceValues[i+self.offset]:draw({x=firstcell_right-21,y=firstcell_top + 1 + ((i-1) * 22)} , nil, true)
      -- Draw numbers
      love.graphics.printf(self.ingredients[self.values[i+self.offset].name], firstcell_right + 6, firstcell_top + 3.5 + ((i-1) * 22), width, 'left')
      -- Draw names
      love.graphics.printf(self.values[i+self.offset].description, firstcell_right + 25, firstcell_top + 3.5 + ((i-1) * 22), width, 'left')
    end
  end

  -- draw introduction to potions & recipes
  local x1 = menu_right - self.backgroundPlain:getWidth() - 25
  love.graphics.draw (self.backgroundPlain, x1, menu_top)
  love.graphics.printf(self.text, x1 + 16, menu_top + 10, 132, "center")
  
  local x2 = menu_right + self.background:getWidth() + 25
  love.graphics.draw (self.backgroundPlain, x2, menu_top)

    -- lists recipes players have in their inventory
  if self.total == 0 then
    love.graphics.printf("You don't have any recipes yet.", x2 + 16, menu_top + 50, 132, "center")
  else
    --love.graphics.print(self.playerRecipes[self.count], x2 + 16, menu_top + 10)
    --love.graphics.print(self.count, x2 + 16, menu_top + 50)
    for _,currentRecipe in pairs(potion_recipes) do
      local recipe = self.playerRecipes[self.count]
      if currentRecipe.name == recipe.name then
        tastyDetails = fonts.tasty.new("{{teal}}" .. recipe.description .. "{{white}} \n\n" .. recipe.info, x2 + 16, menu_top + 10, 132, love.graphics.getFont(), fonts.colors)
        tastyDetails:draw()
        --instructions to scroll through recipes
        if self.total > 1 then
          recipeInstructions = fonts.tasty.new("Press {{red}}" .. self.player.controls:getKey('INTERACT') .. "{{white}} or {{red}}" .. self.player.controls:getKey('ATTACK') .. "{{white}} to view other recipes.", x2 + 16, menu_top + 100, 132, love.graphics.getFont(), fonts.colors)
          recipeInstructions:draw()
        end
      end
    end
   end
end

--called every update cycle
-- dt the amount of seconds since this was last called
function state:update(dt)
  assert(type(dt)=="number", "update time (dt) must be a number")
end

return state
