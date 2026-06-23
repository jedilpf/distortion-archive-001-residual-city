-- systems/CombatSystem.lua: 战斗判定系统
local Config = require("config")

local CombatSystem = {}

--- 执行主角近战攻击判定(矩形hitbox)
---@param playerPos Vector2 玩家位置
---@param atkDir number 攻击方向(1=右,-1=左)
---@param enemies table 敌人列表
---@param callbacks table {onHit=fn, onKill=fn}
function CombatSystem.performAttack(playerPos, atkDir, enemies, callbacks)
    -- 攻击矩形: 从主角面前展开
    local atkX = playerPos.x + atkDir * Config.ATK_RANGE * 0.5
    local atkY = playerPos.y  -- 覆盖主角胸口到膝盖
    local atkW = Config.ATK_RANGE
    local atkH = 1.0  -- 垂直覆盖1.0世界单位
    -- 攻击盒AABB
    local atkLeft = atkX - atkW / 2
    local atkRight = atkX + atkW / 2
    local atkBottom = atkY - atkH * 0.6  -- 从膝盖(下方60%)
    local atkTop = atkY + atkH * 0.4     -- 到胸口(上方40%)

    for _, e in ipairs(enemies) do
        if e.alive and e.node and e.invT <= 0 then
            local ep = e.node.position2D
            -- 敌人hurtbox: 以节点为脚底,盒子向上延伸
            local eLeft = ep.x - Config.ENEMY_WIDTH / 2
            local eRight = ep.x + Config.ENEMY_WIDTH / 2
            local eBottom = ep.y
            local eTop = ep.y + Config.ENEMY_HEIGHT
            -- AABB重叠检测
            if atkLeft < eRight and atkRight > eLeft and atkBottom < eTop and atkTop > eBottom then
                e.hp = e.hp - Config.ATK_DMG
                e.invT = 0.2
                if e.body then
                    e.body.linearVelocity = Vector2(atkDir * Config.KNOCKBACK, 3)
                end
                if callbacks.onHit then callbacks.onHit(e) end
                if e.hp <= 0 then
                    e.alive = false
                    local deathPos = Vector2(ep.x, ep.y + Config.ENEMY_HEIGHT * 0.5)
                    if e.node then e.node:Remove(); e.node = nil end
                    if callbacks.onKill then callbacks.onKill(e, deathPos) end
                end
            end
        end
    end
end

--- 敌人攻击命中检测(前方短距离矩形)
---@param enemy table 敌人状态表
---@param playerPos Vector2 玩家位置
---@return boolean 是否命中
function CombatSystem.checkEnemyAttack(enemy, playerPos)
    if enemy.atkState ~= "attack" then return false end
    -- 敌人攻击盒: 正前方短距离
    local ep = enemy.node.position2D
    local dir = enemy.atkDir
    local hitX = ep.x + dir * Config.ENEMY_ATK_HITBOX * 0.5
    local hitY = ep.y + Config.ENEMY_HEIGHT * 0.5
    -- 玩家hurtbox中心
    local dx = math.abs(playerPos.x - hitX)
    local dy = math.abs(playerPos.y - hitY)
    return dx < Config.ENEMY_ATK_HITBOX * 0.5 + Config.PLAYER_BOX_W * 0.5 and dy < 0.6
end

return CombatSystem
