-- data/Level_001D.lua: 状态机墓地(R-04,平台跳跃)
local Config = require("config")

local Level = {}

local GY = Config.GY
local PH = Config.PH

Level.name = "状态机墓地"
Level.roomWidth = 12

Level.platforms = {
    {x=0, y=GY, w=12, h=PH},
    {x=3.5, y=GY+1.8, w=1.6, h=0.4},
    {x=6.0, y=GY+2.8, w=1.6, h=0.4},
    {x=8.5, y=GY+1.8, w=1.6, h=0.4},
}

Level.enemies = {
    {type="semi_executor", x=2.5, y=GY+PH, hp=2},
    {type="semi_executor", x=9.5, y=GY+PH, hp=3},
}

Level.sludges = {
    {x=5.0, y=GY+0.6, blocking=false},
}

Level.interactables = {
    {x=10.6, y=GY+PH, type="exit_door"},
}

Level.hazards = {
    {x=6.5, y=GY+0.5, w=1.0, h=0.3, type="damage"},
}

Level.hasExit = true

Level.killText = {"模块残留：","状态机卡在 idle。","转移条件缺失。"}
Level.clearText = {"TODO：","墓碑文本占位中。"}

Level.wallTexts = {
    {text="状态机墓地 R-04", wx=1, wy=2.2, color={150,150,150,110}, size=10},
    {text="HERE LIES: while(true)", wx=4, wy=3.4, color={110,110,130,100}, size=8},
    {text="未处理的转移：1024", wx=8, wy=2.2, color={120,90,110,100}, size=8},
}

Level.debris = {
    {type="todo",x=2,y=2.6}, {type="missing",x=6,y=3.6}, {type="halfui",x=9,y=2.6},
}

return Level
