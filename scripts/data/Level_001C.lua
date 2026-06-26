-- data/Level_001C.lua: 渲染回廊(R-03,冲刺穿越)
local Config = require("config")

local Level = {}

local GY = Config.GY
local PH = Config.PH

Level.name = "渲染回廊"
Level.roomWidth = 12

Level.platforms = {
    {x=0, y=GY, w=12, h=PH},
    {x=5.5, y=GY+2.2, w=1.6, h=0.4},
}

Level.enemies = {
    {type="semi_executor", x=9.0, y=GY+PH, hp=3},
}

Level.sludges = {
    {x=3.0, y=GY+0.6, blocking=false},
}

Level.interactables = {
    {x=10.6, y=GY+PH, type="exit_door"},
}

Level.hazards = {
    {x=4.0, y=GY+0.5, w=1.4, h=0.3, type="damage"},
    {x=6.8, y=GY+0.5, w=1.4, h=0.3, type="damage"},
}

Level.hasExit = true

Level.killText = {"模块残留：","渲染管线占用中。","掉帧：已忽略。"}
Level.clearText = {"TODO：","回廊光照未烘焙。"}

Level.wallTexts = {
    {text="渲染回廊 R-03", wx=1, wy=2.2, color={150,150,150,110}, size=10},
    {text="WARNING: 帧率不稳定", wx=4.5, wy=2.4, color={150,110,80,110}, size=8},
    {text="冲刺穿越损坏区段", wx=5.5, wy=1.7, color={80,150,150,110}, size=8},
}

Level.debris = {
    {type="popup",x=2,y=2.8}, {type="halfui",x=7,y=3.0}, {type="hpbar",x=9.5,y=3.0},
}

return Level
