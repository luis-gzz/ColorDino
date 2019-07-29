-----------------------------------------------------------------------------------------
--
-- menu.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
local scene = composer.newScene()

-- include Corona's "widget" library
local widget = require "widget"
local dataCabinet = require("plugin.GBCDataCabinet")
local utils = require("utils")
local iap = require("plugin.iap_badger")

--------------------------------------------

-- forward declarations and other locals
local sceneGroup
local playBtn
local removeAdsBtn
local leftBtn
local rightBtn
local dino
local color
local dinoLocked
local levelMenu
local lockedText

local dinoSheetOptions = {
    --required parameters
    width = 24,
    height = 24,
    numFrames = 24,
}
local dinoSequenceData = {
    { name="idle", frames={1, 2, 3, 4}, loopCount = 0, time = 475},
    { name="walk", frames={5, 6, 7, 8, 9, 10}, loopCount = 0, time = 450},
    { name="jump", frames={14, 15, 16, 17}, loopCount = 0, time = 450},
    { name="hurt", frames={19, 20, 21}, loopCount = 0, time = 400},
}

local catalogue = {
    products = {     
        removeAds = {
                --A list of product names or identifiers specific to apple's App Store or Google Play.  Can be different from the product identifier specified in the line above.
                productNames = { 
                    apple="noads123iap", 
                },
                productType = "non-consumable"
        }
    }
}

local function failedListener()
    native.setActivityIndicator( false )
    native.showAlert("Oops!", "Unable to contact App Store at this moment. Try again later!", {"Sounds Good"})
end

local function cancelListener()
    native.setActivityIndicator(false)
end

local iapOptions = { 
    catalogue=catalogue,
    failedListener=failedListener,
    cancelledListener=cancelListener, 
}

local haveAds = nil

function scene:create(event)
    display.setDefault("background", utils.hex2rgb("#b9d4e2"))
    sceneGroup = self.view
    getSaveData()
    
    -- iap
    iap.init(iapOptions)

	-- Title Text
	local titleTextOptions = {
        text = "Color Dino",
        x = 0,
        y = 0,
        width = display.contentWidth - (display.contentWidth / 4),
        font = "./assets/data/3Dventure.ttf",
        fontSize = 48,
        align = "center",
    }
    local titleText = display.newText(titleTextOptions)
    titleText:setFillColor(utils.hex2rgb("#213038"))
    titleText.y = (display.contentHeight / 3) - (titleText.height / 2);
    titleText.x = display.contentCenterX

	
    -- Buttons
    buttonGroup = display.newGroup();
    buttonGroup.anchorChildren = true

	playBtn = widget.newButton{
		label = levelMenu == 1 and "Start" or "Continue lvl. " .. levelMenu,
		defaultFile = "./assets/images/button_norm2x.png",
        overFile = "./assets/images/button_down2x.png",
        font = "./assets/data/nokiafc22.ttf",
        fontSize = 8,
        labelColor = {default = {70/255.0, 78/255.0, 91/255.0}, over = {70/255.0, 78/255.0, 91/255.0}},
		onRelease = onPlayBtnRelease	-- event listener function
    }
    buttonGroup:insert(playBtn)
    
    removeAdsBtn = widget.newButton{
		label = "Remove Ads!",
		defaultFile = "./assets/images/button_norm.png",
        overFile = "./assets/images/button_down.png",
        font = "./assets/data/nokiafc22.ttf",
        fontSize = 8,
        labelColor = {default = {70/255.0, 78/255.0, 91/255.0}, over = {70/255.0, 78/255.0, 91/255.0}},
		onRelease = onRemoveAdsBtnRelease	-- event listener function
    }
    removeAdsBtn:scale(1, 1)
    removeAdsBtn.y = math.ceil(playBtn.y + removeAdsBtn.height * 2)
    removeAdsBtn.x = display.contentCenterX - removeAdsBtn.width / 2
    buttonGroup:insert(removeAdsBtn)
    buttonGroup.y = (display.contentHeight / 3 * 2) + buttonGroup.height / 2;
    buttonGroup.x = display.contentCenterX
    
    -- Dino and left right choose buttons
    color = "green"
    dinoLocked = false
    local dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    dino = display.newSprite(dinoSheet, dinoSequenceData)
    dino:setSequence("idle")
    dino:scale(2, 2)
    dino.x = display.contentCenterX
    dino.y = display.contentCenterY

    leftBtn = widget.newButton{
		label = "<",
		defaultFile = "./assets/images/button_small_norm.png",
        overFile = "./assets/images/button_small_down.png",
        font = "./assets/data/nokiafc22.ttf",
        fontSize = 8,
        labelColor = {default = {70/255.0, 78/255.0, 91/255.0}, over = {70/255.0, 78/255.0, 91/255.0}},
		onRelease = onLeftBtn	-- event listener function
    }
    leftBtn.x = display.contentCenterX - leftBtn.width * 2.5
    leftBtn.y = display.contentCenterY + 5

    rightBtn = widget.newButton{
		label = ">",
		defaultFile = "./assets/images/button_small_norm.png",
        overFile = "./assets/images/button_small_down.png",
        font = "./assets/data/nokiafc22.ttf",
        fontSize = 8,
        labelColor = {default = {70/255.0, 78/255.0, 91/255.0}, over = {70/255.0, 78/255.0, 91/255.0}},
		onRelease = onRightBtn	-- event listener function
    }
    rightBtn.x = display.contentCenterX + leftBtn.width * 2.5
    rightBtn.y = display.contentCenterY + 5
    
    local lockedTextOptions = {
        text = " ",
        x = display.contentCenterX,
        font = "./assets/data/nokiafc22.ttf",
        fontSize = 8,
        align = "center",
    }
    lockedText = display.newText(lockedTextOptions)
    lockedText:setFillColor(utils.hex2rgb("#dc143c"))
    lockedText.y = dino.y + lockedText.height * 3;

	-- all display objects must be inserted into group
	sceneGroup:insert(titleText)
    sceneGroup:insert(buttonGroup)
    sceneGroup:insert(dino)
    sceneGroup:insert(leftBtn)
    sceneGroup:insert(rightBtn)
    sceneGroup:insert(lockedText)
end

function getSaveData() 
    local loadSuccess = dataCabinet.load("game_save")
    if (loadSuccess == false) then
        -- print("No such cabinet... creating one")
        dataCabinet.createCabinet("game_save")
        dataCabinet.set("game_save", "curr_level", 1)
        dataCabinet.set("game_save", "ads", true)
        dataCabinet.save("game_save")
        levelMenu = 1
        haveAds = true
    else 
        -- print("Cabinet exists... loading data")
        levelMenu = dataCabinet.get("game_save", "curr_level")
        haveAds = dataCabinet.get("game_save", "ads")
        -- print(levelMenu)
    end
end

function updateText()
    if (color == "green") then
        lockedText.text = " ";
        dinoLocked = false;
    elseif (color == "blue") then
        if (levelMenu < 10 and haveAds) then
            lockedText.text = "Reach lvl 10 to unlock";
            dinoLocked = true;
        else 
            lockedText.text = " ";
            dinoLocked = false;
        end

    elseif (color == "red") then
        if (levelMenu < 25 and haveAds) then
            lockedText.text = "Reach lvl 25 to unlock";
            dinoLocked = true;
        else 
            lockedText.text = " ";
            dinoLocked = false;
        end

    elseif (color == "yellow") then
        if (levelMenu < 45 and haveAds) then
            lockedText.text = "Reach lvl 45 to unlock";
            dinoLocked = true;
        else
            lockedText.text = " ";
            dinoLocked = false;
        end
    elseif (color == "purple") then
        if (levelMenu < 70 and haveAds) then
            lockedText.text = "Reach lvl 70 to unlock";
            dinoLocked = true;
        else
            lockedText.text = " ";
            dinoLocked = false;
        end
    end

    lockedText.x = display.contentCenterX

end

-- 'onRelease' event listener for playBtn
function onPlayBtnRelease()
    -- go to level1.lua scene
    if (not dinoLocked) then 
        local options = {effect = "fade", time = 500, params = {curr_level = levelMenu, dino_color = color, ads = 0, enableAds = haveAds}}
        composer.removeScene("menu_state")
        composer.gotoScene("game_state", options)
    end
	
	return true	-- indicates successful touch
end

function onLeftBtn()
    sceneGroup:remove(dino)
    local dinoSheet
    if (color == "green") then
        color = "purple";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    elseif (color == "blue") then
        color = "green";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    elseif (color == "red") then
        color = "blue";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    elseif (color == "yellow") then
        color = "red";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    elseif (color == "purple") then
        color = "yellow";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    end

    dino = display.newSprite(dinoSheet, dinoSequenceData)
    dino.x = display.contentCenterX; dino.y = display.contentCenterY
    dino:scale(2, 2)
    dino:setSequence("idle")
    dino:play()
    sceneGroup:insert(dino)
	
	return true	-- indicates successful touch
end

function onRightBtn()
	sceneGroup:remove(dino)
    local dinoSheet
    if (color == "green") then
        color = "blue";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    elseif (color == "blue") then
        color = "red";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    elseif (color == "red") then
        color = "yellow";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    elseif (color == "yellow") then
        color = "purple";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    elseif (color == "purple") then
        color = "green";
        dinoSheet = graphics.newImageSheet("./assets/images/" .. color .. ".png", dinoSheetOptions)
    end

    dino = display.newSprite(dinoSheet, dinoSequenceData)
    dino.x = display.contentCenterX; dino.y = display.contentCenterY
    dino:scale(2, 2)
    dino:setSequence("idle")
    dino:play()
    sceneGroup:insert(dino)

	return true	-- indicates successful touch
end

local spinner

function onRemoveAdsBtnRelease()
    native.showAlert("Remove Ads!", "Pay $1.99 to remove ads and recieve all dino skins?", {"Yes, Please!","Restore Purchase", "Nope"} , onRemoveAdsConfirmation)
end

function onRemoveAdsConfirmation(event)
    if ( event.action == "clicked" ) then
        local i = event.index
        if (i == 1) then
            iap.purchase("removeAds", purchaseListener)
            native.setActivityIndicator(true)
        elseif (i == 2) then
            iap.restore(false, restoreListener, failedListener)
            native.setActivityIndicator(true)
        elseif (i == 3) then
            -- Do nothing just close
        end
    end
end

function purchaseListener(product)
    haveAds = false
    dataCabinet.set("game_save", "ads", false)
    dataCabinet.save("game_save")

    iap.saveInventory()

    native.setActivityIndicator(false)
    native.showAlert("Hooray!", "You are now playing ad free!", {"Sounds Good"})

    -- print "Purchase made"
end

function restoreListener(productName, event)

    if (productName=="removeAds") then
        haveAds = false
        dataCabinet.set("game_save", "ads", false)
        dataCabinet.save("game_save")
    end

    iap.saveInventory()

    native.setActivityIndicator(false)
    native.showAlert("Hooray!", "You are now playing ad free!", {"Sounds Good"})
    
    -- print "restored!"
end

function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase
	
    if phase == "will" then
        getSaveData()

    elseif phase == "did" then
        dino:play()
	end	
end

function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase
	
	if event.phase == "will" then 
	elseif phase == "did" then
	end	
end

function scene:destroy( event )
	local sceneGroup = self.view
	
	if playBtn then
		playBtn:removeSelf(); playBtn = nil
    end

    if removeAdsBtn then
		removeAdsBtn:removeSelf(); removeAdsBtn = nil
    end

    if leftBtn then
		leftBtn:removeSelf(); leftBtn = nil
    end

    if rightBtn then
		rightBtn:removeSelf(); rightBtn = nil
    end
    
    if dino then 
        dino:removeSelf()
		dino = nil
    end
end

---------------------------------------------------------------------------------

-- Listener setup
local updateTextTimer = timer.performWithDelay(100, updateText, 0)
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------

return scene
