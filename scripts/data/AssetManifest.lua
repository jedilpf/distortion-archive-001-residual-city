-- data/AssetManifest.lua: 资源路径清单
local Assets = {}

Assets.char = {
    -- 完整帧动画套件(每动作8帧)
    idle = {}, run = {}, walk = {}, attack = {},
    dash = {}, jump = {}, cast = {}, hit = {},
    knockdown = {}, skillSlash = {},
}
-- 批量填充路径
for i=1,8 do
    Assets.char.idle[i] = string.format("image/frames/hero_idle_%02d.png", i)
    Assets.char.run[i] = string.format("image/frames/hero_run_right_%02d.png", i)
    Assets.char.walk[i] = string.format("image/frames/hero_walk_right_%02d.png", i)
    Assets.char.attack[i] = string.format("image/frames/hero_attack_%02d.png", i)
    Assets.char.dash[i] = string.format("image/frames/hero_dash_right_%02d.png", i)
    Assets.char.jump[i] = string.format("image/frames/hero_jump_%02d.png", i)
    Assets.char.cast[i] = string.format("image/frames/hero_cast_%02d.png", i)
    Assets.char.hit[i] = string.format("image/frames/hero_hit_death_%02d.png", i)
    Assets.char.knockdown[i] = string.format("image/frames/hero_knockdown_getup_%02d.png", i)
    Assets.char.skillSlash[i] = string.format("image/frames/hero_skill_slash_%02d.png", i)
end

Assets.enemy = {
    idle = "image/e01_idle_20260623015723.png",
    walk1 = "image/e01_walk1_20260623015810.png",
    walk2 = "image/e01_walk2_20260623015919.png",
    hurt = "image/e01_hurt_20260623015801.png",
}

Assets.objects = {
    sludge = "image/obj_sludge_20260622060959.png",
    door = "image/obj_nextdoor_20260623020120.png",
    fragment = "image/obj_frag_20260622061034.png",
    dashCore = "image/obj_dashcore_20260622061006.png",
    platUpper = "image/platform_upper_20260623020533.png",
}

Assets.env = {
    bgFar = "image/bg_far.png",
    bgWall = "image/bg_wall.png",
    ground = "image/tile_ground.png",
    platform = "image/tile_platform.png",
    monitor = "image/deco_monitor.png",
    debris = "image/deco_debris.png",
    titleBg = "image/title_bg.png",
    sceneEnding = "image/scene_ending.png",
}

Assets.buttons = {
    attack = "image/btn_atk_20260621193438.png",
    jump = "image/btn_jmp_20260621193517.png",
    clean = "image/btn_cln_20260621193437.png",
    dash = "image/btn_dsh_20260621193531.png",
    pause = "image/btn_pse_20260621193524.png",
    settings = "image/btn_set_20260621193516.png",
}

Assets.audio = {
    bgm_explore = "audio/bgm_explore.ogg",
    bgm_boss = "audio/bgm_boss.ogg",
    bgm_ending = "audio/bgm_ending.ogg",
    sfx_attack = "audio/sfx/sfx_attack.ogg",
    sfx_clean = "audio/sfx/sfx_clean.ogg",
    sfx_dash = "audio/sfx/sfx_dash.ogg",
    sfx_enemy_hit = "audio/sfx/sfx_enemy_hit.ogg",
    sfx_fragment = "audio/sfx/sfx_fragment.ogg",
    sfx_hurt = "audio/sfx/sfx_hurt.ogg",
    sfx_proj = "audio/sfx/sfx_proj.ogg",
    sfx_boss_enter = "audio/sfx/sfx_boss_enter.ogg",
    sfx_boss_die = "audio/sfx/sfx_boss_die.ogg",
}

Assets.font = "Fonts/MiSans-Regular.ttf"

return Assets
