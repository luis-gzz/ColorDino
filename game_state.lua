-----------------------------------------------------------------------------------------
--
-- game_state.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
local scene = composer.newScene()

-- include Corona's "physics" library and more
local physics = require "physics"
local utils = require("utils")
local widget = require "widget"
local dataCabinet = require("plugin.GBCDataCabinet")
local appodeal = require( "plugin.appodeal" )
--------------------------------------------

-- forward declarations and other locals
local screenW, screenH, halfW = display.actualContentWidth, display.actualContentHeight, display.contentCenterX
local shakeamount = 0
local bgColors = {"#e4c5b3", "#b3d5e4", "#d8bfd8", "#d8bfd8", "#e4c5b3", "#c1d6c2", "#b3d5e4", "#c1d6c2"}

local level, gotEmAlll, levelText, instructions

local tileMap
local totalTiles, coloredTiles, destroyedTiles
local tilesOGHeight, tilesOGWidth, tilesOGX, tilesOGY
local tileSheetOptions = {
    --required parameters
    width = 24,
    height = 29,
    numFrames = 6,
}
local tileSequenceData = {
    { name="white", frames={1}, loopCount = 1, time = 475},
    { name="blue", frames={2}, loopCount = 1, time = 450},
    { name="red", frames={3}, loopCount = 1, time = 450},
    { name="green", frames={4}, loopCount = 1, time = 400},
    { name="yellow", frames={5}, loopCount = 1, time = 400},
    { name="purple", frames={6}, loopCount = 1, time = 400},
}

local dino, dinoRect, color, isDinoOnTile, isDinoJumping, dinoJumpTimer, dinoMovementAllowed, isDinoFalling
local dino_RUN_SPEED = 80
local dinoSheetOptions = {
    --required parameters
    width = 24,
    height = 24,
    numFrames = 24,
}
local dinoSequenceData = {
    { name="idle", frames={1, 2, 3, 4}, loopCount = 0, time = 475},
    { name="walk", frames={5, 6, 7, 8, 9, 10}, loopCount = 0, time = 450},
    { name="hurt", frames={14, 15, 16, 17}, loopCount = 1, time = 500},
    { name="jump", frames={19, 20, 21, 22, 23}, loopCount = 1, time = 500},
}

local asteroidPool, asteroidTimer
local ASTEROID_TIME = 2200
local asteroidSheetOptions = {
    --required parameters
    width = 22,
    height = 23,
    numFrames = 1,
}
local rockSequenceData = {
    {name="rock", frames={1}, loopCount = 1, time = 475},
}

local adCalls, haveAds, minBeforeAds

local gameOverBtn, isThereGameOverBtn

function scene:create( event )
    -- physics.setDrawMode( "hybrid" )

    gotEmAll = false; isThereGameOverBtn = false
    minBeforeAds = 4
    adCalls = event.params.ads
    haveAds = event.params.enableAds
    level = event.params.curr_level
    color = event.params.dino_color
    sceneGroup = self.view
    sceneGroup.originalX = sceneGroup.x
    sceneGroup.originalY = sceneGroup.y
    display.setDefault("background", utils.hex2rgb(bgColors[math.random(#bgColors)]))

    physics.start()
    physics.pause()

    if (haveAds) then
        appodeal.init( adListener, { appKey="e3bc6a644f13972d787c0f785a9334c051bd7fb4a9ee9df2", testMode = false } )
    end
    
    local levelTextOptions = {
        text = "lvl. " .. level,
        x = display.contentCenterX,
        font = "./assets/data/3Dventure.ttf", fontSize = 32,
        align = "center",
    }
    levelText = display.newText(levelTextOptions)
    levelText:setFillColor(utils.hex2rgb("#213038"))
    levelText.y = levelText.height / (display.contentHeight > 510 and .8 or 1.75) + levelText.height;
    sceneGroup:insert(levelText)

    local homeBtn = widget.newButton{
		label = "",
		defaultFile = "./assets/images/home_btn.png",
        overFile = "./assets/images/home_btn_down.png",
		onRelease = onHomeBtnRelease	-- event listener function
    }
    homeBtn.x = display.contentWidth - (display.contentHeight > 510 and 20 or 15) ; 
    homeBtn.y = (display.contentHeight > 510 and 40 or 15) 
    sceneGroup:insert(homeBtn)

    tileMap = generateMap()
    -- tileMap:addEventListener("tap", nextLevel)
    coloredTiles = 0
    destroyedTiles = 0
    tilesOGHeight = tileMap.height; tilesOGWidth = tileMap.width
    tilesOGX = tileMap.x; tilesOGY = tileMap.y
    sceneGroup:insert(tileMap)

    local dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    dino = display.newSprite(dinoSheet, dinoSequenceData)
    -- dino.anchorX = 0; dino.anchorY = 0
    dino:setSequence("idle"); dino:play()
    dino.x = tileMap[1].x + tileMap[1].width / 2; dino.y = tileMap[1].y + tileMap[1].height / 2 - dino.height / 4;
    isDinoOnTile = true; isDinoJumping = false; dinoMovementAllowed = true; isDinoFalling = false
    dino.myName = "dino"
    dinoRect = display.newRect(dino.x, dino.y + 5, 11, 7)
    dinoRect:setFillColor(0,0,0,0)
    sceneGroup:insert(dino)
    sceneGroup:insert(dinoRect)

    local runLevel = level
    while runLevel > 100 do 
        runLevel = runLevel - 100
    end
    dino_RUN_SPEED = 80 + (.325 * runLevel)
	
    -- add physics to the crate
    local offsetRectParams = { halfWidth=5, halfHeight=6, x=1, y=2, angle=0 }
    physics.addBody(dino, "dynamic", {density=0.0001, friction=0.0, bounce=0.0, box = offsetRectParams})
    dino.gravityScale = 0	
    dino.isSensor = true

    asteroidPool = {}
    for i = 1, 10 do 
        local rockSheet = graphics.newImageSheet("./assets/images/rock.png", asteroidSheetOptions)
        local rock = display.newSprite(rockSheet, rockSequenceData)
        rock.x = -50; rock.y = -50
        rock.id = i
        rock.myName = "rock"
        physics.addBody(rock, "dynamic", {density=0.0001, friction=0.0, bounce=0.0})
        rock.gravityScale = 0	
        rock.isSensor = true
        rock.isAlive = false
        asteroidPool[i] = rock
        sceneGroup:insert(rock)
    end

    -- print(utils.randomFloat(0.5, 0.67) * ASTEROID_TIME)
    asteroidTimer = timer.performWithDelay(utils.randomFloat(0.6, 0.75) * ASTEROID_TIME, spawnAsteroid)
    ASTEROID_TIME = 5050

    if (level == 1) then 
        local instructionsOptions = {
            text = "Swipe to turn. Tap to jump.",
            x = display.contentCenterX, y = tileMap.y + tileMap.height * 1.2,
            font = "./assets/data/nokiafc22.ttf", fontSize = 12,
            align = "center", width = display.contentWidth / 4 * 2
        }
        instructions = display.newText(instructionsOptions)
        instructions:setFillColor(utils.hex2rgb("#000000"))
        sceneGroup:insert(instructions)
    end
end

function gameSceneReseter(adCallios)
    local options = {effect = "fade", time = 500, params = {curr_level = level, dino_color = color, ads = adCallios, enableAds = haveAds}}
    composer.removeScene("game_state")
    composer.gotoScene("game_state", options)
end

local function update (event)
    if (dino and coloredTiles and destroyedTiles and destroyedTiles and tileMap) then 

        if not isDinoFalling and not gotEmAll then 
            dinoRect.x = dino.x; dinoRect.y = dino.y + 5

            dinoIsOnTile = false
            local collisionTiles = hasDinoCollidedTiles(dinoRect, tileMap)
            for k, tile in pairs(collisionTiles) do
                dinoIsOnTile = true
                if (tile.sequence ~= color and tile.iAmAlive == true) then 
                    tile:setSequence(color)
                    tile:play()
                    coloredTiles = coloredTiles + 1
                end
            end

            if (not dinoIsOnTile and not isDinoJumping) then 
                -- print("dino fell")
                dinoPerish()
            end

            local vx, vy = dino:getLinearVelocity()
            if ((math.abs(vx) > 0 or math.abs(vy) > 0) and not isDinoJumping and not isDinoFalling) then 
                if (dino.sequence ~= "walk") then 
                    dino:setSequence("walk")
                    dino:play()
                end
            elseif ((vx == 0 and vy == 0) and not isDinoJumping and not isDinoFalling) then
                if (dino.sequence ~= "idle") then 
                    -- print("setting to idle")
                    dino:setSequence("idle")
                    dino:play()
                end
            end
        end

        if (not isDinoFalling and (coloredTiles + destroyedTiles >= totalTiles) and (coloredTiles >= 3)) then 
            if (not gotEmAll) then
                -- print("got em all")
                dinoMovementAllowed = false
                dino:setLinearVelocity(0, 0)
                dino:setSequence("idle")
                dino:play()
                addGameOverBtn("Next Level!")
                gotEmAll = true; isThereGameOverBtn = true
            end
        end

        if not isThereGameOverBtn and isDinoFalling and dino.y > display.contentHeight + 10 then
            isThereGameOverBtn = true
            -- print("fell all teh way")
            addGameOverBtn("Reset Level!")
        end

        if shakeamount > 0 then
            local shake = math.random( shakeamount )
            sceneGroup.x = sceneGroup.originalX + math.random( -shake, shake )
            sceneGroup.y = sceneGroup.originalY + math.random( -shake, shake )
            shakeamount = shakeamount - 1
        end

    end
end

function dinoPerish()
    isDinoFalling = true
    dino:setLinearVelocity(0, 0)
    dino:toBack()
    dino:setSequence("hurt")
    dino:play()
    timer.performWithDelay(200, function() return dino:setLinearVelocity(0, dino_RUN_SPEED * 1.5) end , 1)
end

function generateMap()
    local mapSizeX, mapSizeY
    local percentTilesToRemove = .375
    local tileGroup = display.newGroup()

    local mapArray = {{1,1,1,1,1}
                    ,{0,0,0,0,1}
                    ,{1,1,1,1,1}
                    ,{1,0,0,0,0}
                    ,{1,1,1,1,1}
                    ,{0,0,0,0,1}
                    ,{1,1,1,1,1}}

    local tempLvl = level
    while tempLvl > 100 do
        tempLvl = tempLvl - 100
    end 

    if (tempLvl <= 50) then
        mapSizeX = 5
        mapSizeY = 7
    elseif (tempLvl > 25 and tempLvl <= 50) then
        mapSizeX = 6
        mapSizeY = 7
    elseif (tempLvl > 50 and tempLvl <= 100) then
        mapSizeX = 6
        mapSizeY = 8
    end

    local randomSeed = 4339482334945
    math.randomseed(level * randomSeed + randomSeed)

    if (level > 1) then
        mapArray = {}
        
        for i = 1, mapSizeX do
            mapArray[i] = {}
        
            for j = 1, mapSizeY do
                mapArray[i][j] = 1
            end
        end

        local numToRemove = math.floor((mapSizeX * mapSizeY) * percentTilesToRemove);

        for i = 1, numToRemove do
            local randomX = math.random(mapSizeX)
            local randomY = math.random(mapSizeY)
            mapArray[randomX][randomY] = 0;
        end

    end

    local tileSheet = graphics.newImageSheet("./assets/images/tiles/tiles_all.png", tileSheetOptions)
    for i = 1, mapSizeX do
        for j = 1, mapSizeY do
            if mapArray[i][j] == 1 then
                local tile = display.newSprite(tileSheet, tileSequenceData)
                tile.anchorX = 0; tile.anchorY = 0
                local offsetRectParams = { halfWidth=12, halfHeight=12, x=12, y=12, angle=0 }
                physics.addBody(tile, "kinematic", {density=1e6, friction=0.0, bounce=0.0, box=offsetRectParams})
                tile.gravityScale = 0
                tile.x = tileGroup.x + ((i - 1) * 24)
                tile.y = tileGroup.y + ((j - 1) * 24)
                tile:setSequence("white"); tile:play()
                tile.myName = "tile"; tile.iAmAlive = true
                tileGroup:insert(tile);
            end
        end
    end

    tileGroup.anchorChildren = true
    tileGroup.anchorX = 0
    tileGroup.anchorY = 0
    tileGroup.x = display.contentCenterX - tileGroup.width / 2
    tileGroup.y = display.contentCenterY - tileGroup.height / 2

    for i = 1, tileGroup.numChildren do
        tileGroup[i].x = tileGroup[i].x + tileGroup.x
        tileGroup[i].y = tileGroup[i].y + tileGroup.y
    end

    totalTiles = tileGroup.numChildren
    return tileGroup

end

function hasDinoCollidedTiles(dino_rect, tiles)
    local collidedTiles = {}

    for i = 1, tiles.numChildren do
        if (dinoRect == nil) then  -- Make sure the first object exists
            return {}
        end

        if (tiles[i] ~= nil) then  -- Make sure the other object exists
            tile = tiles[i]
        
            local left = dino_rect.contentBounds.xMin <= tile.contentBounds.xMin and dino_rect.contentBounds.xMax >= tile.contentBounds.xMin
            local right = dino_rect.contentBounds.xMin >= tile.contentBounds.xMin and dino_rect.contentBounds.xMin <= tile.contentBounds.xMax
            local up = dino_rect.contentBounds.yMin <= tile.contentBounds.yMin and dino_rect.contentBounds.yMax >= tile.contentBounds.yMin
            local down = dino_rect.contentBounds.yMin >= tile.contentBounds.yMin and dino_rect.contentBounds.yMin <= (tile.contentBounds.yMax - 5)

            if (left or right) and (up or down) then 
                table.insert(collidedTiles, tile)
            end
        end
        
    end
    return collidedTiles
end

function rockHasCollided(self, event)
    if (event.phase == "began") then 
        if (event.other.myName == "tile" and event.other.id == self.id) then 
            timer.performWithDelay(1, function() return killRockAndTile(self, event) end)
        end
    elseif (event.phase == "ended") then
        
    end
end

function killRockAndTile(self, event)
    shakeamount = 15
    
    if self and dino then 
        if (utils.distance(dino.x, dino.y, self.x, self.y) < 20) then
            dinoPerish()
        end

        self:setLinearVelocity(0, 0)
        self.x = -50
        self.y = -50
        self.isAlive = false
        self:removeEventListener("collision")
    end

    if event.other then
        if (event.other.iAmAlive and event.other.sequence ~= color) then
            destroyedTiles = destroyedTiles + 1
        end

        event.other.iAmAlive = false
        event.other:toBack()
        event.other:setLinearVelocity(0, 100)
    end
        
end

function spawnAsteroid()

    local nextRock = nil
    local i = 1

    while nextRock == nil and i < 10 do 
        if (asteroidPool[i].isAlive == false) then
            nextRock = asteroidPool[i]
        end

        i = i + 1
    end

    nextRock.collision = rockHasCollided

    local randTileInd = math.random(totalTiles - destroyedTiles)
    local randTile = tileMap[randTileInd]

    while randTile.isAlive == false do 
        randTileInd = math.random(totalTiles - destroyedTiles)
        randTile = tileMap[randTileInd]
    end

    randTile.id = nextRock.id
    randTile.isAlive = false

    if (randTile.y < display.contentHeight / 3) then
        nextRock.x = (((randTile.x < display.contentWidth / 2) and utils.randomFloat(.01, .5) or utils.randomFloat(.5, .99)) * display.contentWidth);
        nextRock.y = -30;
        
    elseif (randTile.y >= display.contentHeight / 3) then
        nextRock.x = (randTile.x < display.contentWidth / 2) and -30 or (display.contentWidth + 30);
        nextRock.y = (utils.randomFloat(0, .55) * display.contentHeight);
    end

    local velVectorX = (randTile.x + 7) - nextRock.x
    local velVectorY = (randTile.y + 7) - nextRock.y 

    local mag = math.sqrt((velVectorX * velVectorX) + (velVectorY * velVectorY))

    local normX = velVectorX / mag
    local normY = velVectorY / mag

    local speed = 50
    local xSpeed = normX * speed
    local ySpeed = normY * speed

    nextRock.isAlive = true
    -- print("spawning rock")
    nextRock:setLinearVelocity(xSpeed, ySpeed)
    nextRock:addEventListener("collision")

    -- print(utils.randomFloat(0.5, 0.67) * ASTEROID_TIME)
    asteroidTimer = timer.performWithDelay(utils.randomFloat(0.5, 0.67) * ASTEROID_TIME, spawnAsteroid)

end

function touchControls(event)
    local swipeDist = utils.distance(event.xStart, event.yStart, event.x, event.y)
    local angle = utils.angleBetweenTwoPts(event.xStart, event.yStart, event.x, event.y)

    if event.phase == "ended" and level == 1 and instructions ~= nil then
        instructions:removeSelf()
        instructions = nil
    end

    if event.phase == "ended" and not isDinoFalling and dinoMovementAllowed then
        -- print("swipe DISTANCE: " .. swipeDist)
        -- print("swipe ANGLE: " .. angle)
        if (swipeDist < 10 and not isDinoJumping) then
            -- print("jump!")
            isDinoJumping = true;
            dinoJumpTimer = timer.performWithDelay(360, stopDinoJump)
            dino:setSequence("jump")
            dino:play()
        elseif (swipeDist >= 10 and ((angle > -45 and angle <= 0) or (angle < 45 and angle >= 0))) then
            dino:setLinearVelocity(0, dino_RUN_SPEED)
            -- print("Down")

        elseif (swipeDist >= 10 and ((angle >= -180 and angle < -135) or (angle <= 180 and angle > 135))) then
            dino:setLinearVelocity(0, -dino_RUN_SPEED)
            -- print("Up")

        elseif (swipeDist >= 10 and (angle > 45 and angle <= 135)) then
            dino:setLinearVelocity(dino_RUN_SPEED, 0)
            dino.xScale = 1 
            -- print("Right")

        elseif (swipeDist >= 10 and (angle < -45 and angle >= -135)) then
            dino:setLinearVelocity(-dino_RUN_SPEED, 0)
            dino.xScale = -1 
            -- print("Left")

        end

    end       
  end

function nextLevel()
    level = level + 1
    adCalls = adCalls + 1

    -- print("NEXT LEVEL: " .. level)

    local loadSuccess = dataCabinet.load("game_save")
    if (loadSuccess) then
        dataCabinet.set("game_save", "curr_level", level)
        dataCabinet.save("game_save")
    end

    if (haveAds and adCalls > minBeforeAds and appodeal.isLoaded("interstitial")) then
        -- print ("NEXT LEVEL: " .. level)
        appodeal.show("interstitial")
    else
        gameSceneReseter(adCalls)
    end
    
end

function resetLevel()
    -- print ("RESET LEVEL: " .. level)
    adCalls = adCalls + 1

    if (haveAds and adCalls > minBeforeAds and appodeal.isLoaded("interstitial")) then
        appodeal.show("interstitial")
    else
        gameSceneReseter(adCalls)
    end
    
end

function addGameOverBtn(btn_label)
    gameOverBtn = widget.newButton{
		label = btn_label,
		defaultFile = "./assets/images/button_norm.png",
        overFile = "./assets/images/button_down.png",
        font = "./assets/data/nokiafc22.ttf",
        fontSize = 8,
        labelColor = {default = {70/255.0, 78/255.0, 91/255.0}, over = {70/255.0, 78/255.0, 91/255.0}},
        onRelease = btn_label == "Reset Level!" and resetLevel or nextLevel
    }
    gameOverBtn.id = btn_label == "Reset Level!" and "reset" or "next"
    gameOverBtn.x = display.contentCenterX
    gameOverBtn.y = tilesOGY + tilesOGHeight + gameOverBtn.height * 2

    sceneGroup:insert(gameOverBtn)
end

function stopDinoJump(event)
    isDinoJumping = false
    dino:setSequence("idle")
    dino:play()
end

function adListener(event)
 
    if (event.phase == "init") then  -- Successful initialization
        appodeal.show("banner" , {placement = "BannerBottom"})
    elseif (event.phase == "failed") then
        if event.type == "interstitial" then
            gameSceneReseter(3)
        end
    elseif (event.phase == "closed") then 
        -- print ("NEXT LEVEL: " .. level)
        gameSceneReseter(0)
    end
end

function onHomeBtnRelease()
    local options = {effect = "fade", time = 100}
    composer.removeScene("game_state")
    composer.gotoScene("menu_state", options)

	return true	-- indicates successful touch
end

function scene:show(event)
	local sceneGroup = self.view
	local phase = event.phase
	
	if phase == "will" then
	elseif phase == "did" then
        physics.start()
	end
end

function scene:hide(event)
	local sceneGroup = self.view
	
	local phase = event.phase
	
	if event.phase == "will" then
        physics.stop()

	elseif phase == "did" then
	end	
	
end

function scene:destroy(event)
    Runtime:removeEventListener("enterFrame", update)
    Runtime:removeEventListener("touch", touchControls)
    Runtime:removeEventListener("system", onSystemEvent)

    if (haveAds) then
        appodeal.hide("banner")
    end

    if (dinoJumpTimer ~= nil) then
        timer.cancel(dinoJumpTimer)
    end

    if (asteroidTimer ~= nil) then
        timer.cancel(asteroidTimer)
    end

    if dino then
        dino:removeSelf(); dino = nil
    end

    if tileMap then
        tileMap:removeSelf(); tileMap = nil
    end

    if (gameOverBtn ~= nil) then 
        gameOverBtn.isVisible = false
        gameOverBtn:removeSelf(); gameOverBtn = nil
    end

    if (homeBtn ~= nil) then 
        homeBtn:removeSelf(); homeBtn = nil
    end

    if (levelText ~= nil) then 
        levelText:removeSelf(); levelText = nil
    end

    for _, rock in ipairs(asteroidPool) do
        if rock then
            rock:removeSelf(); rock = nil
        end
    end

	local sceneGroup = self.view
	
	package.loaded[physics] = nil
	physics = nil
end

local dinoTimerTimeRem = -100
local rockTimerTimeRem = -100
function onSystemEvent(event)
    if event.type == "applicationSuspend" then 
        if (dinoJumpTimer ~= nil) then dinoTimerTimeRem = timer.pause(dinoJumpTimer) end
        if (asteroidTimer ~= nil) then rockTimerTimeRem = timer.pause(asteroidTimer) end
    elseif event.type == "applicationResume" then
        if (dinoTimerTimeRem ~= -100) then dinoJumpTimer = timer.performWithDelay(dinoTimerTimeRem, stopDinoJump) end
        if (rockTimerTimeRem ~= -100) then asteroidTimer = timer.performWithDelay(rockTimerTimeRem, spawnAsteroid) end
    end
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)
Runtime:addEventListener("enterFrame", update)
Runtime:addEventListener("touch", touchControls)
Runtime:addEventListener("system", onSystemEvent)

-- local isDinoDeadTimer = timer.performWithDelay(400, isDinoDead, 0)
-----------------------------------------------------------------------------------------

return scene