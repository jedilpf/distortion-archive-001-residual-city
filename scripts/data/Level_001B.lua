-- data/Level_001B.lua: 回收车间(R-02)
local Config = require("config")

local Level = {}

local GY = Config.GY
local PH = Config.PH

Level.name = "回收车间"
Level.roomWidth = 12

Level.platforms = {
    {x=0, y=GY, w=12, h=PH},
    {x=4.5, y=GY+2.0, w=2.0, h=0.4},
    {x=8.0, y=GY+2.6, w=2.0, h=0.4},
}

Level.enemies = {
    {type="semi_executor", x=3.5, y=GY+PH, hp=2},
    {type="semi_executor", x=8.5, y=GY+PH, hp=3},
}

Level.sludges = {
    {x=6.0, y=GY+0.6, blocking=true},
    {x=9.5, y=GY+0.6, blocking=false},
}

Level.interactables = {
    {x=10.6, y=GY+PH, type="exit_door"},
}

Level.hazards = {
    {x=6.7, y=GY+0.5, w=1.0, h=0.3, type="damage"},
}

Level.hasExit = true

Level.killText = {"模块残留：","巡逻AI已生成。","寻路逻辑：仅左右。"}
Level.clearText = {"TODO：","回收完成度未统计。"}

Level.wallTexts = {
    {text="回收车间 R-02", wx=1, wy=2.2, color={150,150,150,110}, size=10},
    {text="待回收原型：∞", wx=4, wy=1.8, color={120,100,80,100}, size=8},
    {text="提炼率：0.3%", wx=8.5, wy=2.0, color={80,120,80,100}, size=8},
}

Level.debris = {
    {type="hpbar",x=1.2,y=2.6}, {type="todo",x=5,y=3.0}, {type="missing",x=9,y=3.2},
}

return Level
