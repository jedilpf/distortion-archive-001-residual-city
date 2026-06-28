-- data/Level_001E.lua: 内存泥沼(R-05,清理密集)
local Config = require("config")

local Level = {}

local GY = Config.GY
local PH = Config.PH

Level.name = "内存泥沼"
Level.roomWidth = 12

Level.platforms = {
    {x=0, y=GY, w=12, h=PH},
    {x=7.0, y=GY+2.2, w=2.0, h=0.4},
}

Level.enemies = {
    {type="semi_executor", x=4.0, y=GY+PH, hp=3},
    {type="semi_caster", x=9.0, y=GY+PH, hp=2},  -- 近战+远程混编,施法器在后排压制
}

Level.sludges = {
    {x=2.5, y=GY+0.6, blocking=false},
    {x=5.0, y=GY+0.6, blocking=true},
    {x=6.2, y=GY+0.6, blocking=false},
    {x=9.0, y=GY+0.6, blocking=false},
}

Level.interactables = {
    {x=10.6, y=GY+PH, type="exit_door"},
}

Level.hazards = {
    {x=5.9, y=GY+0.5, w=0.8, h=0.3, type="damage"},
}

Level.hasExit = true

Level.killText = {"模块残留：","内存未释放。","泄漏：持续中。"}
Level.clearText = {"TODO：","GC 从未实现。"}

Level.wallTexts = {
    {text="内存泥沼 R-05", wx=1, wy=2.2, color={150,150,150,110}, size=10},
    {text="LEAK: 12.4 GB", wx=4.5, wy=2.0, color={150,110,80,110}, size=8},
    {text="清理可回收碎片", wx=7, wy=1.7, color={120,90,200,110}, size=8},
}

Level.debris = {
    {type="hpbar",x=1.5,y=2.6}, {type="missing",x=5,y=3.0},
    {type="todo",x=8,y=3.0}, {type="popup",x=9.5,y=2.8},
}

return Level
