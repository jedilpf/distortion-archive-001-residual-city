-- entities/EnemyFactory.lua: 敌人创建工厂
local Config = require("config")

local EnemyFactory = {}

function EnemyFactory.create(scene, enemyData)
    local n = scene:CreateChild("Enemy")
    n:SetPosition2D(enemyData.x, enemyData.y)
    local b = n:CreateComponent("RigidBody2D")
    b.bodyType = BT_DYNAMIC
    b.fixedRotation = true
    b.gravityScale = 1
    b.linearDamping = 0.5
    -- 主体碰撞盒(矩形,底部对齐脚底)
    local sh = n:CreateComponent("CollisionBox2D")
    sh:SetSize(Config.ENEMY_WIDTH, Config.ENEMY_HEIGHT)
    sh:SetCenter(0, Config.ENEMY_HEIGHT / 2)  -- 中心上移,底部对齐节点位置(脚底)
    sh.density = 1.5
    sh.friction = 0.3
    sh.categoryBits = Config.CAT_ENEMY
    sh.maskBits = Config.CAT_GROUND | Config.CAT_PLAYER
    return {
        type = enemyData.type or "semi_executor",
        node = n,
        body = b,
        hp = enemyData.hp or 3,
        alive = true,
        invT = 0,
        moveDir = 1,
        moveT = 0,
        -- 攻击AI状态
        atkState = "idle",   -- idle/windup/attack/cooldown
        atkTimer = 0,
        atkDir = 1,
        baseX = enemyData.x,
        baseY = enemyData.y,
    }
end

return EnemyFactory
