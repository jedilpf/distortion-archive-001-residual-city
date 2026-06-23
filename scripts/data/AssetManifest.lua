-- data/AssetManifest.lua: 资源路径清单
local Assets = {}

Assets.char = {
    idle = "image/char_idle1_20260621184424.png",
    run1 = "image/char_run1_20260621184411.png",
    run2 = "image/char_run2_20260621184434.png",
    jump = "image/char_jump_20260621184416.png",
    attack = "image/char_attack_20260621184410.png",
    clean = "image/char_clean_20260621184409.png",
    dash = "image/char_dash_20260621184409.png",
}

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
