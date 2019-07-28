-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
local utils = require("utils")

-- hide the status bar
display.setStatusBar(display.HiddenStatusBar)
display.setDefault("background", utils.hex2rgb("#b3d5e4"))
display.setDefault("minTextureFilter", "nearest")
display.setDefault("magTextureFilter", "nearest")

-- include the Corona "composer" module
local composer = require "composer"

-- load menu screen
composer.gotoScene("menu_state")