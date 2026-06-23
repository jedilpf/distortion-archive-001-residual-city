-- systems/CoordinateSystem.lua: 统一坐标转换
local Config = require("config")

local CoordSys = {}

--- 获取VirtualControls使用的缩放参数
---@return number scale, number offsetX, number offsetY
function CoordSys.getVCParams()
    local W, H = Config.W, Config.H
    local scale = math.min(W, H) / 1080
    local offX = (W - 1920 * scale) / 2
    local offY = (H - 1080 * scale) / 2
    return scale, offX, offY
end

--- 将VirtualControls设计坐标(1920x1080)转为NanoVG屏幕坐标
---@param posX number 设计坐标X
---@param posY number 设计坐标Y
---@param alignH number 水平对齐(HA_LEFT/HA_CENTER/HA_RIGHT)
---@param alignV number 垂直对齐(VA_TOP/VA_CENTER/VA_BOTTOM)
---@return number screenX, number screenY
function CoordSys.buttonToScreen(posX, posY, alignH, alignV)
    local W, H = Config.W, Config.H
    local scale, offX, offY = CoordSys.getVCParams()
    local dx, dy = posX, posY
    local sR = (W - offX) / scale
    local sB = (H - offY) / scale
    local sL = -offX / scale
    local sT = -offY / scale
    if alignH == HA_RIGHT then dx = sR + posX
    elseif alignH == HA_LEFT then dx = sL + posX
    else dx = 960 + posX end
    if alignV == VA_BOTTOM then dy = sB + posY
    elseif alignV == VA_TOP then dy = sT + posY
    else dy = 540 + posY end
    return dx * scale + offX, dy * scale + offY
end

--- 设计坐标Y转NanoVG屏幕Y(用于参考线)
---@param designY number 设计坐标Y(0-1080)
---@return number screenY
function CoordSys.designYToScreen(designY)
    local H = Config.H
    return designY * H / 1080
end

return CoordSys
