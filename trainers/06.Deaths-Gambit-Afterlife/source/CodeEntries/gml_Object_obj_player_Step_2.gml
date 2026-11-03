if (amistanding == 1)
{
    air_dash_count = 0;
}
if (!place_free(x, y))
{
    for (i = 0; i < 16; i++)
    {
        if (place_free(x, y + i))
        {
            y += i;
            break;
        }
    }
}
if (scr_is_talent_owned(143) == 1)
{
    if (bloodborne_talent_timer > 0)
    {
        bloodborne_talent_timer -= 1;
    }
    if (bloodborne_talent_timer == 1)
    {
        instance_create(x, y, obj_bloodborne_ready);
    }
    if (bloodborne_talent_timer == 0 && global.ProHealth < ceil(global.ProMaxHealth * 0.1) && Pdead == 0)
    {
        bloodborne_talent_timer = 18000;
        aud_play_sound(957, 0, 0);
        instance_create(x, y, obj_cast_bloodborne);
        instance_create(x, y, obj_bloodknight_effect1);
    }
}
if (global.playersanity > 200)
{
    global.playersanity = 200;
}
if (global.playersanity < 0)
{
    global.playersanity = 0;
}
if (global.playersanity > sanityprev)
{
    aa = instance_create(obj_player.x, obj_player.y, obj_player_spookyghost2);
    aa.depth = obj_player.depth + 2;
}
sanityprev = global.playersanity;
if (os_type == os_ps4 || os_type == os_ps5 || os_type == os_gdk || os_type == os_xboxone)
{
    if (wspeed == 0 || x == xprevious)
    {
        x = round(x);
    }
}
if (abilityalarm != 2061)
{
    tomeroll = 0;
}
if (abilityalarm == 1014)
{
    stunned = 1;
}
if (scr_is_talent_owned(27))
{
    if (obj_player.arrowammo > 60)
    {
        obj_player.arrowammo = 60;
    }
}
else if (obj_player.arrowammo > 40)
{
    obj_player.arrowammo = 40;
}
if (obj_player.energyammo > 100)
{
    obj_player.energyammo = 100;
}
if (global.soulenergy < 0)
{
    global.soulenergy = 0;
}
if (sprite_index == scr_halberd_1())
{
    obj_player.swordstage = 1;
    if (key_check_released(UnknownEnum.Value_4) || key_check_released(UnknownEnum.Value_4))
    {
        cantchargeanymore = 1;
    }
}
else if (sprite_index == scr_halberd_charge())
{
    if (audio_is_playing(sfx_pl_halberd_atk1_01))
    {
        audio_stop_sound(sfx_pl_halberd_atk1_01);
    }
    if (audio_is_playing(sfx_pl_halberd_atk1_02))
    {
        audio_stop_sound(sfx_pl_halberd_atk1_02);
    }
    if (audio_is_playing(sfx_pl_halberd_atk1_03))
    {
        audio_stop_sound(sfx_pl_halberd_atk1_03);
    }
}
else
{
    cantchargeanymore = 0;
}
if (sprite_index == scr_shield_broken_sprite && image_index < 1 && instance_exists(obj_player_shield_broken_ui))
{
    instance_create(x, y, obj_player_shield_broken_ui);
}
if (abilityalarm != 1062)
{
    if (audio_is_playing(sfx_pl_sword_bastard_atk3_01))
    {
        audio_stop_sound(sfx_pl_sword_bastard_atk3_01);
    }
    if (audio_is_playing(sfx_pl_sword_bastard_atk3_02))
    {
        audio_stop_sound(sfx_pl_sword_bastard_atk3_02);
    }
    if (audio_is_playing(sfx_pl_sword_bastard_atk3_03))
    {
        audio_stop_sound(sfx_pl_sword_bastard_atk3_03);
    }
    if (audio_is_playing(sfx_pl_sword_bastard_atk3_04))
    {
        audio_stop_sound(sfx_pl_sword_bastard_atk3_04);
    }
}
if (sprite_prev == 342 || sprite_prev == 529 || sprite_prev == 537 || sprite_prev == 603)
{
    if (sprite_index == spr_player_bigsword1A2 || sprite_index == spr_player_drake1 || sprite_index == spr_player_darkeater1 || sprite_index == spr_player_stone1)
    {
        var rand = irandom(30);
        if (rand < 10)
        {
            aud_play_sound(434, 0, 0);
        }
        else if (rand > 20)
        {
            aud_play_sound(435, 0, 0);
        }
        else
        {
            aud_play_sound(436, 0, 0);
        }
    }
}
sprite_prev = sprite_index;
if ((sprite_index == spr_player_bigsword1A2 && image_index < 1) || (sprite_index == spr_player_drake1 && image_index < 1) || (sprite_index == spr_player_darkeater1 && image_index < 1) || (sprite_index == spr_player_stone1 && image_index < 1))
{
    if (!audio_is_playing(sfx_pl_sword_bastard_atk1_1) && !audio_is_playing(sfx_pl_sword_bastard_atk1_2) && !audio_is_playing(sfx_pl_sword_bastard_atk1_3))
    {
        var rand = irandom(30);
        if (rand < 10)
        {
            aud_play_sound(431, 0, 0);
        }
        else if (rand > 20)
        {
            aud_play_sound(432, 0, 0);
        }
        else
        {
            aud_play_sound(433, 0, 0);
        }
    }
}
if (sprite_index == spr_player_bigsword_charge1 || sprite_index == spr_player_drake_charge || sprite_index == spr_player_darkeater_charge || sprite_index == spr_player_stone_charge)
{
    if (!audio_is_playing(sfx_pl_scythe_chargemove_loop))
    {
        audio_stop_sound(sfx_pl_sword_bastard_atk1_1);
        audio_stop_sound(sfx_pl_sword_bastard_atk1_2);
        audio_stop_sound(sfx_pl_sword_bastard_atk1_3);
        aud_play_sound(553, 0, 0);
    }
}
if (audio_is_playing(sfx_pl_scythe_chargemove_loop) && sprite_index != spr_player_bigsword_charge1 && sprite_index != spr_player_drake_charge && sprite_index != spr_player_darkeater_charge && sprite_index != spr_player_stone_charge)
{
    audio_stop_sound(sfx_pl_scythe_chargemove_loop);
}
if (sprite_index == spr_player_halberd_charge || sprite_index == spr_player_inqhalberd_charge || sprite_index == spr_player_gaianhalberd_charge || sprite_index == spr_player_vadoshalberd_charge || sprite_index == spr_player_bigsword_charge1 || sprite_index == spr_player_bigsword_charge1B || sprite_index == spr_player_darkeater_charge || sprite_index == spr_player_drake_charge || sprite_index == spr_player_stone_charge)
{
    charge_attack += 0.02;
}
if (sprite_index != spr_player_halberd_charge && sprite_index != spr_player_inqhalberd_charge && sprite_index != spr_player_gaianhalberd_charge && sprite_index != spr_player_vadoshalberd_charge && sprite_index != spr_player_halberd1 && sprite_index != spr_player_inqhalberd1 && sprite_index != spr_player_gaianhalberd1 && sprite_index != spr_player_vadoshalberd1 && sprite_index != spr_player_bigsword_charge1 && sprite_index != spr_player_bigsword_charge1B && sprite_index != spr_player_darkeater_charge && sprite_index != spr_player_drake_charge && sprite_index != spr_player_stone_charge && sprite_index != spr_player_bigsword1A2 && sprite_index != spr_player_darkeater1 && sprite_index != spr_player_drake1 && sprite_index != spr_player_stone1)
{
    charge_attack = 1;
}
__view_set(e__VW.YView, 0, ceil(global.view_y));
event_user(7);
if ((sprite_index == player_roll_right && roll_fade == 0) || (sprite_index == player_roll_left && roll_fade == 0))
{
    if (instance_exists(obj_playerhorse) && obj_playerhorse.state != "idle_noplayer")
    {
        sprite_index = scr_idle_sprite();
    }
    else
    {
        fade = instance_create(x, y, obj_player_dodgeroll_fade);
        fade.sprite_index = sprite_index;
        fade.image_index = image_index;
        fade.image_xscale = dir;
        fade.depth = depth + 2;
        roll_fade = 4;
    }
}
else if (roll_fade > 0)
{
    roll_fade -= 1;
}
if ((sprite_index == player_roll_right && image_index < 1.3) || (sprite_index == player_roll_left && image_index < 1.3))
{
    obj_gun.alt_attack = 0;
    nextdecision = 0;
    nextaction = 0;
    obj_player.nextaction = 0;
    obj_gun.weaponswitch = 0;
    obj_player.swordstage = 0;
    obj_gun.nextattack = 0;
    if (plr_key_left == 1 && gamepad_xaxis(0) < 0.5)
    {
        dir = -1;
    }
    if (plr_key_right == 1 && gamepad_xaxis(0) > 0.5)
    {
        dir = 1;
    }
}
var aa = 0;
if (abilityalarm != 0 && image_index <= (scr_dodgeroll_frame(sprite_index) + 0.5))
{
    aa = 1;
}
if (backstep_timer == 0)
{
    if (window_has_focus() && aa == 0)
    {
        scr_backstep();
    }
    backstep_timer = -1;
}
else if (backstep_timer > 0)
{
    backstep_timer -= 1;
    if (plr_key_right == true || plr_key_left == true || gamepad_xaxis(0) > 0.5 || gamepad_xaxis(0) < -0.5)
    {
        scr_player_dodgeroll();
        backstep_timer = -1;
    }
    if (nextdecision != 0 || nextaction != 0 || stunned != 0 || abilityalarm != 0)
    {
    }
}
if (sprite_index != spr_crashdown1 && vspeed > fallspeedmax)
{
    vspeed = fallspeedmax;
}
if (alt_melee_buff_negation > 0)
{
    alt_melee_buff_negation -= 1;
}
if (energyammo > 100)
{
    energyammo = 100;
}
if (sprite_index == spr_player_upgrade1 && room != Gaian_Cradle1C && room != room_avatar_of_thalamus)
{
    if (image_index > 1 && image_index <= 15)
    {
        __view_set(e__VW.WView, 0, global.view_w + 2);
        __view_set(e__VW.HView, 0, global.view_h + 1);
    }
    if (image_index > 30 && image_index <= 45)
    {
        __view_set(e__VW.WView, 0, global.view_w - 2);
        __view_set(e__VW.HView, 0, global.view_h - 1);
    }
    if (image_index == 15)
    {
        instance_create(x, y, obj_upgrade_shadow);
    }
    if (image_index == 30)
    {
        with (obj_upgrade_shadow)
        {
            instance_destroy();
        }
    }
}
if (abilityalarm == 2202)
{
    image_speed = 0.25;
    if (image_index >= 8.5)
    {
        sprite_index = scr_shield_end_sprite();
    }
    heavy_block_timer += 0.25;
    aa = 1;
    if (instance_exists(obj_perfectblock))
    {
        aa = 3;
    }
    if (dir == -1)
    {
        if (heavy_block_timer > 0.9 && heavy_block_timer < 11)
        {
            scr_player_move(ceil((11 - heavy_block_timer) * -1) / aa);
            repeat (3)
            {
                instance_create(x + random_range(-30, 10), y + 32, oSlideDust);
            }
        }
    }
    if (dir == 1)
    {
        if (heavy_block_timer > 0.9 && heavy_block_timer < 11)
        {
            scr_player_move(ceil((11 - heavy_block_timer) / aa));
            repeat (3)
            {
                instance_create(x + random_range(-30, 10), y + 32, oSlideDust);
            }
        }
    }
}
if (global.soulenergymax < global.soulenergy)
{
    global.soulenergy = global.soulenergymax;
}
if (stunned == 0 && amistanding == 1 && indodgeroll == 0 && GlobalVariables.endurancedelay > 68)
{
    GlobalVariables.endurancedelay = 68;
}
if (obj_player.diminishing_returns_air < 1)
{
    obj_player.diminishing_returns_air += 0.001;
}
if (obj_player.diminishing_returns_air > 1)
{
    obj_player.diminishing_returns_air = 1;
}
if (shielded == 1)
{
    shielded_time += 1;
}
else
{
    shielded_time = 0;
}
if ((global.Endurance <= 1 && nextaction == 12) || (global.Endurance <= 1 && nextaction == 13))
{
    if (indodgeroll == 0 && abilityalarm != 1050 && nextaction != 0)
    {
        nextaction = 0;
    }
}
if (sprite_index == scr_runright_sprite() || sprite_index == scr_runleft_sprite())
{
    how_long_moving += 1;
    if (indodgeroll == 0 && abilityalarm != 1050 && nextaction != 0 && how_long_moving == 2)
    {
        how_long_moving = 0;
        nextaction = 0;
    }
}
else
{
    how_long_moving = 0;
}
if (nextaction != 0 && alarm[9] == -1 && obj_gun.alarm[8] == -1 && indodgeroll == 0 && !instance_exists(obj_player_knockback))
{
    scr_player_nextaction_manager(nextaction);
}
if (buffer_counter < buffer_max)
{
    buffer_counter += 1;
    if (amistanding == 1 && air_action == 30)
    {
        buffer_counter = buffer_max;
        scr_player_jump();
    }
    else if (amistanding == 1)
    {
        buffer_counter = buffer_max;
        nextaction = air_action;
    }
}
if (air_jump_held > 0)
{
    air_jump_held -= 1;
}
if (divekick_held > 0)
{
    divekick_held -= 1;
}
if (air_jump_cancel > 0)
{
    air_jump_cancel -= 1;
    if (air_jump_cancel == 1)
    {
        air_action = 0;
        air_jump_held = 0;
    }
}
if (amistanding == 1 && air_action == 0)
{
    air_jump_held = 0;
}
if (sprite_index == spr_player_skullaxe_crash && image_index >= 12 && image_index < 12.25)
{
    instance_create(x, y, obj_skull_axe_spike_sfx);
    if (dir == 1)
    {
        spike = instance_create(x + 93, y + 32, obj_skullaxe_spike);
        spike.image_index = 10;
        spike = instance_create(x + 93 + 40, y + 32, obj_skullaxe_spike);
        spike.image_index = 9;
        spike = instance_create(x + 93 + 80, y + 32, obj_skullaxe_spike);
        spike.image_index = 8;
        spike = instance_create(x + 93 + 120, y + 32, obj_skullaxe_spike);
        spike.image_index = 7;
        spike = instance_create(x + 93 + 160, y + 32, obj_skullaxe_spike);
        spike.image_index = 6;
        spike = instance_create(x + 93 + 200, y + 32, obj_skullaxe_spike);
        spike.image_index = 5;
        spike = instance_create(x + 93 + 240, y + 32, obj_skullaxe_spike);
        spike.image_index = 4;
        spike = instance_create(x + 93 + 280, y + 32, obj_skullaxe_spike);
        spike.image_index = 3;
        spike = instance_create(x + 93 + 320, y + 32, obj_skullaxe_spike);
        spike.image_index = 2;
    }
    else
    {
        spike = instance_create(x - 93, y + 32, obj_skullaxe_spike);
        spike.image_index = 10;
        spike = instance_create(x - 93 - 40, y + 32, obj_skullaxe_spike);
        spike.image_index = 9;
        spike = instance_create(x - 93 - 80, y + 32, obj_skullaxe_spike);
        spike.image_index = 8;
        spike = instance_create(x - 93 - 120, y + 32, obj_skullaxe_spike);
        spike.image_index = 7;
        spike = instance_create(x - 93 - 160, y + 32, obj_skullaxe_spike);
        spike.image_index = 6;
        spike = instance_create(x - 93 - 200, y + 32, obj_skullaxe_spike);
        spike.image_index = 5;
        spike = instance_create(x - 93 - 240, y + 32, obj_skullaxe_spike);
        spike.image_index = 4;
        spike = instance_create(x - 93 - 280, y + 32, obj_skullaxe_spike);
        spike.image_index = 3;
        spike = instance_create(x - 93 - 320, y + 32, obj_skullaxe_spike);
        spike.image_index = 2;
    }
}
if (sprite_index == spr_player_lioneljumpd && image_index >= 36 && image_index < 36.5 && !instance_exists(obj_fangofgaia_flower1))
{
    instance_create((x - 120) + irandom(240), y + 32, obj_fangofgaia_flower1);
    instance_create((x - 120) + irandom(240), y + 32, obj_fangofgaia_flower1);
    instance_create((x - 120) + irandom(240), y + 32, obj_fangofgaia_flower1);
}
if (sprite_index == spr_crashdown2 && !instance_exists(obj_phoenixdagger_controller) && instance_number(obj_phoenixblade_orb) > 3)
{
    instance_create(x, y, obj_phoenixdagger_controller);
}
if (sprite_index == spr_crashdown2 && !instance_exists(obj_skullaxe_controller) && instance_number(obj_skullaxe_orb) > 3)
{
    instance_create(x, y, obj_skullaxe_controller);
}
if (sprite_index == spr_crashdown2 && !instance_exists(obj_vild_greatsword_controller) && instance_number(obj_vild_greatsword_orb) > 3)
{
    instance_create(x, y, obj_vild_greatsword_controller);
}
if (sprite_index == spr_player_dash && image_index < 3 && !instance_exists(obj_darkeater_effect) && instance_number(obj_darkeater_greatsword_orb) > 0)
{
    instance_create(x, y + 32, obj_darkeater_effect);
}
if (sprite_index == spr_crashdown2 && !instance_exists(obj_gaian_greatsword_controller) && instance_number(obj_gaian_greatsword_orb) > 3)
{
    instance_create(x, y + 32, obj_gaian_greatsword_controller);
}
if (sprite_index == spr_crashdown2 && !instance_exists(obj_amulvaro_meteor_shower_controller) && instance_number(obj_amulvaro_sabre_orb) > 3)
{
    instance_create(x, y + 32, obj_amulvaro_meteor_shower_controller);
}
if (sprite_index == spr_crashdown2 && instance_number(obj_inquisitor_orb) > 3)
{
    with (obj_inquisitor_orb)
    {
        instance_destroy();
    }
    aud_play_sound(1943, 0, 0);
    var dire = 0;
    repeat (30)
    {
        bul = instance_create(x, y + 20, obj_inqhalberd_projectileA);
        bul.direction = dire;
        bul.speed = 4;
        dire += 12;
    }
}
if (sprite_index == spr_crashdown2 && instance_number(obj_newscythe_orb) > 0)
{
    with (obj_newscythe_orb)
    {
        instance_destroy();
    }
}
if (sprite_index == spr_crashdown2 && global.soulenergy >= 120)
{
    var inv_item_wep1_unpgraded = global.inv_item_wep1;
    var inv_item_wep2_unpgraded = global.inv_item_wep2;
    while (inv_item_wep1_unpgraded > 1000)
    {
        inv_item_wep1_unpgraded -= 1000;
    }
    while (inv_item_wep2_unpgraded > 1000)
    {
        inv_item_wep2_unpgraded -= 1000;
    }
    if (inv_item_wep1_unpgraded == 248 || inv_item_wep2_unpgraded == 248)
    {
        if (instance_exists(obj_reap) && obj_reap.stacks > 4)
        {
            global.soulenergy -= 120;
            instance_create(x, y, obj_screen_flash);
            instance_create(x, y, obj_player_scythe_ultimate_restless);
            idd = instance_create(obj_player.x - 1200, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            idd = instance_create(obj_player.x - 900, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            idd = instance_create(obj_player.x - 600, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            idd = instance_create(obj_player.x - 300, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            idd = instance_create(obj_player.x, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            idd = instance_create(obj_player.x + 300, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            idd = instance_create(obj_player.x + 600, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            idd = instance_create(obj_player.x + 900, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            idd = instance_create(obj_player.x + 1200, obj_player.y + 200 + 700, obj_player_scythe_ultimate2);
            idd.image_yscale = 2;
            with (obj_mouse)
            {
                shake = 10;
            }
        }
    }
}
if (instance_exists(obj_playerclimb) || (instance_exists(obj_playerhorse) && obj_playerhorse.state != "idle_noplayer"))
{
    how_long_amistanding_true = 0;
    how_long_amistanding_false = 0;
}
if (amistanding == 1 && how_long_amistanding_false > 50 && room != Sunken_City1 && room != Sunken_City2B && room != Sunken_City2C && room != Sunken_City3 && room != Sunken_City_boss && room != Amulvaro_boss2 && room != bossrush_amulvaro)
{
    if (abilityalarm != 1097 && indodgeroll == 0)
    {
        if (sprite_index == player_jump || sprite_index == player_jump2 || sprite_index == player_jump_end)
        {
            stunned = 1;
            image_index = 0;
            abilityalarm = 1049;
            alarm[9] = 32;
            with (obj_mouse)
            {
                shake = 4;
            }
            var rand = random(100);
            if (rand > -1 && rand < 33)
            {
                aud_play_sound(1043, 4, false);
            }
            else if (rand > 33 && rand < 66)
            {
                aud_play_sound(1044, 4, false);
            }
            else if (rand > 66 && rand < 100)
            {
                aud_play_sound(1045, 4, false);
            }
        }
        else
        {
        }
    }
    else
    {
    }
}
if (amistanding == 1 && how_long_amistanding_false > 20)
{
    instance_create(x, y + 11, obj_land_effect);
}
else if (amistanding == 1 && how_long_amistanding_false > 3)
{
    instance_create(x - 2, y + 8, obj_land_effect1);
}
if (amistanding == 1)
{
    how_long_amistanding_true += 1;
    how_long_amistanding_false = 0;
    double_jump = 0;
    if (instance_exists(obj_bulwark_aura))
    {
        obj_bulwark_aura.triple_jump = 0;
    }
    if (instance_exists(obj_endless_aura))
    {
        obj_endless_aura.triple_jump = 0;
    }
    if (instance_exists(obj_ash_aura))
    {
        obj_ash_aura.triple_jump = 0;
    }
    if (instance_exists(obj_ash_aura_plus))
    {
        obj_ash_aura_plus.triple_jump = 0;
    }
    air_dash = 0;
    picked_up_extra_jump = 0;
}
else
{
    how_long_amistanding_true = 0;
}
if (sprite_index == player_jump || sprite_index == player_jump2 || sprite_index == player_jump_end)
{
    if (vspeed > 0)
    {
        how_long_amistanding_false += 1;
    }
    if (vspeed < 0)
    {
        how_long_amistanding_false = 0;
    }
}
else
{
    how_long_amistanding_false = 0;
}
if (megastunned == 2)
{
    slideA = 0;
    slideD = 0;
    wspeed = 0;
    sliding = 0;
}
if (sprite_index == scr_shield_broken_sprite() && image_index > 28.4)
{
    scr_alarm9();
    alarm[9] = -1;
    megatunned = 0;
    hurtdir = 0;
    obj_player.sprite_index = scr_idle_sprite();
}
if (sprite_index != scr_shield_broken_sprite() && sprite_index != player_hurt && hurtdir != 0)
{
    stunned = 0;
    megastunned = 0;
    abilityalarm = 0;
    hurtdir = 0;
    obj_player.sprite_index = scr_idle_sprite();
}
if (steam_is_screenshot_requested())
{
    var file = "Deaths_Gambit_" + string(global.scrn_num) + ".png";
    screen_save(file);
    steam_send_screenshot(file, window_get_width(), window_get_height());
    global.scrn_num += 1;
}
if ((nextdecision == 1 && hurt == 0 && indodgeroll == 0 && abilityalarm == 0) || (abilityalarm != 0 && nextdecision == 1 && image_index >= scr_dodgeroll_frame(sprite_index) && global.Endurance > 0))
{
    if (abilityalarm != 0 && nextdecision == 1 && image_index >= scr_dodgeroll_frame(sprite_index))
    {
        abilityalarm = 0;
        stunned = 0;
    }
    nextdecision = 0;
    scr_player_dodgeroll();
}
if ((nextdecision == 14 && hurt == 0 && indodgeroll == 0 && abilityalarm == 0 && aa == 0) || (abilityalarm != 0 && nextdecision == 14 && image_index >= scr_dodgeroll_frame(sprite_index) && global.Endurance > 0 && aa == 0))
{
    if (abilityalarm != 0 && nextdecision == 14 && image_index >= scr_dodgeroll_frame(sprite_index))
    {
        abilityalarm = 0;
        stunned = 0;
    }
    nextdecision = 0;
    if (window_has_focus())
    {
        scr_backstep();
    }
}
if (global.debug_build == 0)
{
    if (global.ProHealth > 9999)
    {
        global.ProHealth = 9999;
    }
    if (global.player_ultra_essence > 99999999)
    {
        global.player_ultra_essence = 99999999;
    }
    if (global.player_ultra_essence < 0)
    {
        global.player_ultra_essence = 0;
    }
}
if (!instance_exists(obj_rusty_charm) && !instance_exists(obj_fortitude) && !instance_exists(obj_shard_aura) && !instance_exists(obj_darkcrystal_phoenyx_plume) && !instance_exists(obj_Resilience) && !instance_exists(obj_hard_phoenyx_plume) && !instance_exists(obj_fortitude3) && !instance_exists(obj_priest_dmgtkn_debuff) && !instance_exists(obj_fortitude2) && !instance_exists(obj_bulwark_dmgtkn_debuff))
{
    obj_player.damagetakenbuff = 1;
}
if (sprite_index == scr_shield_hit_sprite() || sprite_index == scr_shield_start_sprite() || sprite_index == player_hurt2 || sprite_index == player_hurt || sprite_index == scr_runleft_sprite() || sprite_index == scr_runright_sprite() || sprite_index == scr_idle_sprite())
{
    with (obj_gun)
    {
        obj_gun.weaponswitch = 0;
        obj_player.swordstage = 0;
        obj_gun.nextattack = 0;
        obj_gun.alt_attack = 0;
    }
}
if (sprite_index == sPlayerJumpDbl && image_index > 6.74)
{
    sprite_index = player_jump;
    image_index = 8;
}
if (sprite_index != sPlayerJumpDbl && obj_player.double_jump == 1)
{
    obj_player.double_jump = 2;
}
if (sprite_index == sPlayerJumpDbl && image_index == 2)
{
    for (i = 0; i < 5; i++)
    {
        o = instance_create(x + random_range(-30, -10), (y - 20) + random_range(-15, 15), oParticleFeather);
        o.direction = point_direction(x, y - 100, o.x, o.y);
        o = instance_create(x + random_range(10, 30), (y - 20) + random_range(-15, 15), oParticleFeather);
        o.direction = point_direction(x, y - 100, o.x, o.y);
    }
}
if (sprite_index == sPlayerJumpDbl && image_index == 5 && global.performancemode == 0)
{
    for (i = 0; i < 5; i++)
    {
        o = instance_create(x + random_range(-25, -10), (y - 40) + random_range(-15, 15), oParticleFeather);
        o.direction = point_direction(x, y, o.x, o.y);
        o.speed = random_range(0, 2);
        o = instance_create(x + random_range(10, 25), (y - 40) + random_range(-15, 15), oParticleFeather);
        o.direction = point_direction(x, y, o.x, o.y);
        o.speed = random_range(0, 2);
    }
}
if (megastunned != 0)
{
    if ((sprite_index == spr_player_shield_broken && image_index > 30.5) || (sprite_index == spr_player_shield_broken_wood && image_index > 30.5) || (sprite_index == spr_player_shield_broken_maw && image_index > 30.5) || (sprite_index == spr_player_shield_broken_phoenix && image_index > 30.5) || (sprite_index == spr_player_shield_broken_eye && image_index > 30.5) || (sprite_index == spr_player_shield_broken_light && image_index > 30.5) || (sprite_index == spr_player_shield_turtle_broken && image_index > 30.5) || (sprite_index == spr_player_shield_bulwark_broken && image_index > 30.5) || (sprite_index == spr_player_shield_shaman_broken && image_index > 30.5) || (sprite_index == spr_player_shield_moss_broken && image_index > 30.5) || (sprite_index == spr_player_shield_corpse_broken && image_index > 30.5) || (sprite_index == spr_player_shield_drake_break && image_index > 30.5) || (sprite_index == spr_player_shield_energy_break && image_index > 30.5) || (sprite_index == spr_player_shield_death_break && image_index > 30.5) || (sprite_index == spr_player_shield_corpseless_broken && image_index > 30.5))
    {
        shielded = 0;
        stunned = 0;
        megastunned = 0;
        abilityalarm = 0;
        alarm[9] = -2;
        global.casttimecurrent = 0;
    }
}
if ((plr_key_left == 0 && plr_key_right == 0 && gamepad_xaxis(0) < 0.7 && gamepad_xaxis(0) > -0.7 && sprite_index == scr_shield_walkback_sprite()) || (plr_key_left == 0 && plr_key_right == 0 && gamepad_xaxis(0) < 0.7 && gamepad_xaxis(0) > -0.7 && sprite_index == scr_shield_walk_sprite()))
{
    sprite_index = scr_shield_end_sprite();
}
weptype = 0;
if (obj_gun.lastweaponslot == 1)
{
    if (global.inv_item_wep2 == 241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 1241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 2241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 3241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 4241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 5241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 6241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 7241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 8241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 9241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 10241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 11241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep2 == 12241)
    {
        weptype = 1;
    }
}
if (obj_gun.lastweaponslot == 2)
{
    if (global.inv_item_wep1 == 241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 1241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 2241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 3241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 4241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 5241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 6241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 7241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 8241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 9241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 10241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 11241)
    {
        weptype = 1;
    }
    if (global.inv_item_wep1 == 12241)
    {
        weptype = 1;
    }
}
if (weptype == 0)
{
    if (room == Obsidian_Plateau0_edit || room == room_dampe || room == Obsidian_Plateau2_edit || room == Obsidian_Plateau_Kaern_Intro || room == Obsidian_Plateau_Kaern || room == bossrush_kaern)
    {
        if (sprite_index == spr_player_katana_charge_move || sprite_index == spr_player_katana_charge_moveback || sprite_index == spr_player_katana_charge_idle)
        {
            sprite_index = spr_player_katana_charge_move;
            if ((plr_key_left == 1 && plr_key_right == 0) || gamepad_xaxis(0) < -0.7)
            {
                dir = 1;
            }
            if ((plr_key_left == 0 && plr_key_right == 1) || gamepad_xaxis(0) > 0.7)
            {
                dir = -1;
            }
        }
    }
    else if (sprite_index == spr_player_katana_charge_move || sprite_index == spr_player_katana_charge_moveback || sprite_index == spr_player_katana_charge_idle)
    {
        sprite_index = spr_player_katana_charge_move;
        if ((plr_key_left == 1 && plr_key_right == 0) || gamepad_xaxis(0) < -0.7)
        {
            dir = -1;
        }
        if ((plr_key_left == 0 && plr_key_right == 1) || gamepad_xaxis(0) > 0.7)
        {
            dir = 1;
        }
    }
    if (sprite_index == spr_player_katana_charge_move || sprite_index == spr_player_katana_charge_moveback)
    {
        if ((plr_key_left == 1 && plr_key_right == 1) || (plr_key_left == 0 && plr_key_right == 0 && gamepad_xaxis(0) > -0.7 && gamepad_xaxis(0) < 0.7))
        {
            sprite_index = spr_player_katana_charge_idle;
        }
    }
    if (sprite_index == spr_player_katana_charge_start && image_index >= 2 && image_index < 2.24)
    {
        aud_play_sound(661, 0, 0);
    }
    if (sprite_index == spr_player_katana_charge_attack && image_index >= 1 && image_index <= 1.24)
    {
        aud_play_sound(531, 0, 0);
    }
    if (sprite_index == spr_player_amulvaro_charge_start && image_index >= 2 && image_index < 2.24)
    {
        aud_play_sound(661, 0, 0);
    }
    if (sprite_index == spr_player_amulvaro_charge_attack && image_index >= 1 && image_index <= 1.24)
    {
        aud_play_sound(531, 0, 0);
    }
}
else
{
    if (room == Obsidian_Plateau0_edit || room == room_dampe || room == Obsidian_Plateau2_edit || room == Obsidian_Plateau_Kaern_Intro || room == Obsidian_Plateau_Kaern || room == bossrush_kaern)
    {
        if (sprite_index == spr_player_amulvaro_charge_move || sprite_index == spr_player_amulvaro_charge_moveback || sprite_index == spr_player_amulvaro_charge_idle)
        {
            sprite_index = spr_player_amulvaro_charge_move;
            if ((plr_key_left == 1 && plr_key_right == 0) || gamepad_xaxis(0) < -0.7)
            {
                dir = 1;
            }
            if ((plr_key_left == 0 && plr_key_right == 1) || gamepad_xaxis(0) > 0.7)
            {
                dir = -1;
            }
        }
    }
    else if (sprite_index == spr_player_amulvaro_charge_move || sprite_index == spr_player_amulvaro_charge_moveback || sprite_index == spr_player_amulvaro_charge_idle)
    {
        sprite_index = spr_player_amulvaro_charge_move;
        if ((plr_key_left == 1 && plr_key_right == 0) || gamepad_xaxis(0) < -0.7)
        {
            dir = -1;
        }
        if ((plr_key_left == 0 && plr_key_right == 1) || gamepad_xaxis(0) > 0.7)
        {
            dir = 1;
        }
    }
    if (sprite_index == spr_player_amulvaro_charge_move || sprite_index == spr_player_amulvaro_charge_moveback)
    {
        if ((plr_key_left == 1 && plr_key_right == 1) || (plr_key_left == 0 && plr_key_right == 0 && gamepad_xaxis(0) > -0.7 && gamepad_xaxis(0) < 0.7))
        {
            sprite_index = spr_player_amulvaro_charge_idle;
        }
    }
    if (sprite_index == spr_player_katana_charge_start && image_index >= 2 && image_index < 2.24)
    {
        aud_play_sound(661, 0, 0);
    }
    if (sprite_index == spr_player_katana_charge_attack && image_index >= 1 && image_index <= 1.24)
    {
        aud_play_sound(531, 0, 0);
    }
    if (sprite_index == spr_player_amulvaro_charge_start && image_index >= 2 && image_index < 2.24)
    {
        aud_play_sound(661, 0, 0);
    }
    if (sprite_index == spr_player_amulvaro_charge_attack && image_index >= 1 && image_index <= 1.24)
    {
        aud_play_sound(531, 0, 0);
    }
    if (os_is_xbox() || os_type == os_ps4 || os_type == os_switch || gamepad_is_connected(keymap.slot) == 1 || gamepad_is_connected(1) == 1 || gamepad_is_connected(2) == 1 || gamepad_is_connected(3) == 1)
    {
        if (sprite_index == spr_player_amulvaro_charge_attack)
        {
            dir = katana_lastdir;
        }
    }
}
if (sprite_index == spr_player_katana_charge_move && weptype == 1)
{
    sprite_index = spr_player_amulvaro_charge_move;
}
if (sprite_index == spr_player_slide && image_index < 3)
{
    if (room == Obsidian_Plateau0_edit || room == room_dampe || room == Obsidian_Plateau2_edit || room == Obsidian_Plateau_Kaern_Intro || room == Obsidian_Plateau_Kaern || room == bossrush_kaern)
    {
        if (gamepad_xaxis(0) < -0.7)
        {
            dir = 1;
        }
        if (gamepad_xaxis(0) > 0.7)
        {
            dir = -1;
        }
    }
    else
    {
        if (gamepad_xaxis(0) < -0.7)
        {
            dir = -1;
        }
        if (gamepad_xaxis(0) > 0.7)
        {
            dir = 1;
        }
    }
}
if (hurt != 0)
{
    daggerdodge = 0;
}
if (lastjump > -1)
{
    lastjump -= 1;
}
if (global.ProMaxHealth < global.ProHealth)
{
    global.ProHealth = global.ProMaxHealth;
}
if (instance_exists(obj_fadetoblack_save))
{
    dodgeroll_invincibility = 1;
}
if (stunned == 1 || (plr_key_attack2 && plr_key_attack1))
{
    if (global.inv_item_wep1 == 217 || global.inv_item_wep2 == 217)
    {
    }
    else
    {
        with (obj_gun)
        {
            visible = false;
            obj_player.drawhead = 0;
            with (obj_player)
            {
                currentlyshooting = 0;
            }
            bowstage = 0;
            sprite_index = Nothing;
            image_index = 0;
            image_speed = 0.25;
            global.shotCharging = 0;
            global.shotCharging2 = 0;
        }
    }
}
if (amistanding == 0)
{
    amistanding_time += 1;
    climbjump_new -= 1;
}
else
{
    climbjump_new = 0;
    if (amistanding_time != 0)
    {
        scr_pl_land_sound();
    }
    amistanding_time = 0;
}
if ((sprite_index == spr_player_katana1 && image_index >= 2 && image_index < 2.25) || (sprite_index == spr_player_amulvaro1 && image_index >= 2 && image_index < 2.25))
{
    if (!audio_is_playing(sfx_pl_katana_atk1_01) && !audio_is_playing(sfx_pl_katana_atk1_02) && !audio_is_playing(sfx_pl_katana_atk1_03))
    {
        var rand = random(100);
        if (rand > -1 && rand < 33)
        {
            aud_play_sound(522, 4, false);
        }
        else if (rand > 33 && rand < 66)
        {
            aud_play_sound(523, 4, false);
        }
        else if (rand > 66 && rand < 101)
        {
            aud_play_sound(524, 4, false);
        }
    }
}
if (sprite_index == spr_player_scythe_ab1_base && image_index == 1)
{
    aud_play_sound(2040, 4, false);
}
if (sprite_index == spr_player_scythe_ab1_base && image_index == 12)
{
    var rand = random(100);
    if (rand > -1 && rand < 33)
    {
        aud_play_sound(549, 4, false);
    }
    else if (rand > 33 && rand < 66)
    {
        aud_play_sound(550, 4, false);
    }
    else if (rand > 66 && rand < 101)
    {
        aud_play_sound(551, 4, false);
    }
}
if (sprite_index == spr_player_scythe_ab1_base2 && image_index == 1)
{
    aud_play_sound(2040, 4, false);
}
if (sprite_index == spr_player_scythe_ab1_base2 && image_index == 12)
{
    var rand = random(100);
    if (rand > -1 && rand < 33)
    {
        aud_play_sound(549, 4, false);
    }
    else if (rand > 33 && rand < 66)
    {
        aud_play_sound(550, 4, false);
    }
    else if (rand > 66 && rand < 101)
    {
        aud_play_sound(551, 4, false);
    }
}
if (sprite_index == spr_player_save_rest3 && image_index > 0.99 && image_index < 1.24)
{
    aud_play_sound(913, 0, false);
}
if (place_free(x, y + 16))
{
    amistanding = 0;
}
else if (sprite_index != sPlayerJumpDbl)
{
    if (amistanding == 0 && wspeed > 2)
    {
        wspeed -= 2;
    }
    amistanding = 1;
    with (obj_gun)
    {
        cantairattack = 0;
    }
    if (instance_exists(obj_bulwark_aura))
    {
        obj_bulwark_aura.triple_jump = 0;
    }
    if (instance_exists(obj_endless_aura))
    {
        obj_endless_aura.triple_jump = 0;
    }
    if (instance_exists(obj_ash_aura))
    {
        obj_ash_aura.triple_jump = 0;
    }
    if (instance_exists(obj_ash_aura_plus))
    {
        obj_ash_aura_plus.triple_jump = 0;
    }
    air_dash = 0;
    double_jump = 0;
    picked_up_extra_jump = 0;
}
if (collision_rectangle(bbox_left, bbox_bottom, bbox_right, bbox_bottom + 8, obj_block_jumpthrough, 1, 1))
{
    if (!(sprite_index == sPlayerJumpDbl && vspeed < 0))
    {
        amistanding = 1;
        with (obj_gun)
        {
            cantairattack = 0;
        }
    }
}
if (!hitground_after_climbing)
{
    if (amistanding)
    {
        hitground_after_climbing = true;
    }
}
if (gamepad_button_check_released(keymap.slot, gp_face2) == 1 && obj_player.no_backstep == 1)
{
    nextdecision = 0;
    obj_player.no_backstep = 0;
}
if (obj_player.shielded == 1)
{
    vspeed = 0;
    gravity = 0;
}
if (vspeed < -1)
{
    if (obj_player.Pdead == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (instance_exists(obj_save_button) == true)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (instance_number(obj_merchant_ui) == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (instance_number(obj_crafting_ui) > 0)
    {
        exit;
    }
    if (instance_number(obj_abilityshop_ui) == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (instance_number(obj_exit_icon) == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (instance_number(obj_challengeui) == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (instance_number(obj_enchantui) == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (instance_number(obj_disenchantui) == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (GlobalVariables.isinventoryopen == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (Deactivate == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
    if (disableactions == 1)
    {
        vspeed = 0;
        gravity = 0;
    }
}
if (recently_charged > -1)
{
    recently_charged -= 1;
}
if (sprite_index == spr_player_inqhalberd1 && recently_charged > 0 && image_index >= 9 && image_index < 10.33)
{
    if (obj_player.dir == 1)
    {
        borb = instance_create(x + 70, y, obj_inqhalberd_projectile1);
        borb = instance_create(x + 70, y, obj_inqhalberd_projectile1);
        borb = instance_create(x + 70, y, obj_inqhalberd_projectile2);
        borb.hspeed = 2;
        borb.gravity = 0.1;
        borb.gravity_direction = 270;
        borb = instance_create(x + 70, y, obj_inqhalberd_projectile2);
        borb.hspeed = 2;
        borb.gravity = 0.1;
        borb.gravity_direction = 90;
    }
    else
    {
        borb = instance_create(x - 70, y, obj_inqhalberd_projectile1);
        borb = instance_create(x - 70, y, obj_inqhalberd_projectile1);
        borb = instance_create(x - 70, y, obj_inqhalberd_projectile2);
        borb.hspeed = -2;
        borb.gravity = 0.1;
        borb.gravity_direction = 270;
        borb = instance_create(x - 70, y, obj_inqhalberd_projectile2);
        borb.hspeed = -2;
        borb.gravity = 0.1;
        borb.gravity_direction = 90;
    }
    recently_charged = 0;
}
var ypos = obj_mouse.y;
if (ypos < (obj_player.y - 32))
{
    ypos = obj_player.y - 32;
}
if (ypos > (obj_player.y + 32))
{
    ypos = obj_player.y + 32;
}
if (keymap.type == 1)
{
    ypos = obj_player.y;
}
if (gamepad_is_connected(keymap.slot) == 1)
{
    if (gamepad_yaxis(keymap.slot) < -0.6)
    {
        ypos = obj_player.y - 32;
    }
    if (gamepad_yaxis(keymap.slot) > 0.6)
    {
        ypos = obj_player.y + 32;
    }
    if (gamepad_axis_value(keymap.slot, gp_axisrv) < -0.6)
    {
        ypos = obj_player.y - 32;
    }
    if (gamepad_axis_value(keymap.slot, gp_axisrv) > 0.6)
    {
        ypos = obj_player.y + 32;
    }
}
if (vspeed < -7 && abilityalarm == 0 && hurt == 0 && stunned == 0)
{
    if (double_jump == 1 && sprite_index != player_jump)
    {
        sprite_index = sPlayerJumpDbl;
        image_speed = 0.25;
    }
    else if (double_jump == 1 && sprite_index == sPlayerJumpDbl && image_index > 6.74)
    {
        sprite_index = player_jump;
        image_index = 8;
    }
    else
    {
        sprite_index = player_jump;
    }
}
if (instance_exists(obj_playerhorse) && obj_playerhorse.state != "idle_noplayer")
{
}
else
{
    scr_player_footstep();
}
if (hurt == 1 && megastunned == 0)
{
    whichkeycast = 0;
    var hurtmove = hurttime / 12;
    if (hurttime > 19)
    {
        hopecollected = 1;
    }
    with (obj_mouse)
    {
        shake = 4;
    }
    scr_player_move(hurtmove * -1);
}
if (hurt == 2 && megastunned == 0)
{
    var hurtmove = hurttime / 12;
    if (hurttime > 20)
    {
        hopecollected = 0.2;
    }
    with (obj_mouse)
    {
        shake = 4;
    }
    scr_player_move(hurtmove);
}
if (hurt != 0)
{
    whichkeycast = 0;
    whichcast = 0;
    stunned = 0;
    global.casttimecurrent = 0;
    global.casttime = 0;
    abilityalarm = 0;
    if (instance_exists(obj_bullet))
    {
        with (obj_bullet)
        {
            instance_destroy();
        }
    }
    if (instance_exists(obj_PlayerCastBar))
    {
        with (obj_PlayerCastBar)
        {
            instance_destroy();
        }
    }
}
if (sprite_index == spr_player_slide)
{
    mask_index = spr_player_mask1;
}
else if (instance_exists(obj_playerhorse) && obj_playerhorse.state != "idle_noplayer" && obj_playerhorse.state != "mount_transition" && obj_playerhorse.state != "slowdown_noplayer" && obj_playerhorse.state != "playermount" && obj_playerhorse.state != "player_dismount")
{
    mask_index = spr_player_mask_horse;
}
else
{
    mask_index = spr_player_mask;
}
if ((sprite_index == spr_player_magictome1 && !instance_exists(obj_player_knockback) && !instance_exists(obj_player_knockback2)) || (sprite_index == spr_player_magictome2 && !instance_exists(obj_player_knockback) && !instance_exists(obj_player_knockback2)) || (sprite_index == spr_player_magictome3 && !instance_exists(obj_player_knockback) && !instance_exists(obj_player_knockback2)) || (sprite_index == spr_player_magictome_air && !instance_exists(obj_player_knockback) && !instance_exists(obj_player_knockback2)))
{
    temp3 = global.inv_item_wep1;
    temp4 = global.inv_item_wep2;
    repeat (13)
    {
        if (temp3 > 1000)
        {
            temp3 -= 1000;
        }
    }
    repeat (13)
    {
        if (temp4 > 1000)
        {
            temp4 -= 1000;
        }
    }
    weptype = 0;
    if (obj_gun.lastweaponslot == 1 || alt_melee_lock != 0)
    {
        if (temp4 == 110)
        {
            weptype = 1;
        }
        if (temp4 == 111)
        {
            weptype = 2;
        }
        if (temp4 == 109)
        {
            weptype = 3;
        }
    }
    if (obj_gun.lastweaponslot == 2 || alt_melee_lock != 0)
    {
        if (temp3 == 110)
        {
            weptype = 1;
        }
        if (temp3 == 111)
        {
            weptype = 2;
        }
        if (temp3 == 109)
        {
            weptype = 3;
        }
    }
    if (obj_gun.lastweaponslot == 1)
    {
        if (temp4 == 110)
        {
            weptype = 1;
        }
        if (temp4 == 111)
        {
            weptype = 2;
        }
        if (temp4 == 109)
        {
            weptype = 3;
        }
    }
    if (weptype == 0)
    {
        if (sprite_index == spr_player_magictome1 && image_index == 2)
        {
            direction = 180;
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 43, y, obj_bullet);
                with (idd)
                {
                    destroyed_on_contact = 0;
                    move_towards_point(obj_player.x + 200, ypos, 11);
                    image_angle = direction;
                }
            }
            else
            {
                idd = instance_create(x - 43, y, obj_bullet);
                with (idd)
                {
                    destroyed_on_contact = 0;
                    move_towards_point(obj_player.x - 200, ypos, 11);
                    image_angle = direction;
                }
            }
            latestbullet = idd;
            idd.weapontype = 2061;
            idd.melee = 1;
            idd.onehit = 1;
            idd.destroyed_on_contact = 1;
            idd.bullet_reflector = 1;
            if (instance_exists(idd))
            {
                maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
            }
            with (idd)
            {
                event_user(0);
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome2 && image_index == 3)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos + 32, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                with (idd)
                {
                    event_user(0);
                }
            }
            else
            {
                idd = instance_create(x - 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos + 32, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                with (idd)
                {
                    event_user(0);
                }
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome3 && image_index == 5)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos + 32, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y - 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos - 32, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                with (idd)
                {
                    event_user(0);
                }
            }
            else
            {
                idd = instance_create(x - 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos + 32, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y - 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos - 32, 11);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 2061;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome_air && image_index == 7)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    speed = 11;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 0;
                }
                idd2 = instance_create(x + 25, y + 25, obj_bullet);
                with (idd2)
                {
                    speed = 11;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 328;
                    image_angle = direction;
                }
                idd3 = instance_create(x, y + 25, obj_bullet);
                with (idd3)
                {
                    speed = 11;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 270;
                    image_angle = direction;
                }
            }
            else
            {
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    speed = 11;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 180;
                    image_angle = direction;
                }
                idd2 = instance_create(x - 25, y + 25, obj_bullet);
                with (idd2)
                {
                    speed = 11;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 212;
                    image_angle = direction;
                }
                idd3 = instance_create(x, y + 25, obj_bullet);
                with (idd3)
                {
                    speed = 11;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 270;
                    image_angle = direction;
                }
            }
            latestbullet = idd;
            idd.weapontype = 2061;
            idd.melee = 1;
            idd.onehit = 1;
            idd.destroyed_on_contact = 1;
            idd.bullet_reflector = 1;
            latestbullet = idd2;
            idd2.weapontype = 2061;
            idd2.melee = 1;
            idd2.onehit = 1;
            idd2.destroyed_on_contact = 1;
            idd2.bullet_reflector = 1;
            latestbullet = idd3;
            idd3.weapontype = 2061;
            idd3.melee = 1;
            idd3.onehit = 1;
            idd3.destroyed_on_contact = 1;
            idd3.bullet_reflector = 1;
            var mastery = 0;
            if (instance_exists(obj_airattackbuff_valk))
            {
                mastery = obj_airattackbuff_valk.stacks + 1;
            }
            with (idd)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            with (idd2)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            with (idd3)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            if (mastery > 0)
            {
                with (idd)
                {
                    weapondamage *= mastery;
                }
                with (idd2)
                {
                    weapondamage *= mastery;
                }
                with (idd3)
                {
                    weapondamage *= mastery;
                }
            }
            if (instance_exists(obj_airattackbuff_valk))
            {
                with (obj_airattackbuff_valk)
                {
                    instance_destroy();
                }
            }
            speed = 0;
        }
    }
    if (weptype == 1)
    {
        if (sprite_index == spr_player_magictome1 && image_index == 2)
        {
            direction = 180;
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 43, y, obj_bullet);
                with (idd)
                {
                    destroyed_on_contact = 0;
                    move_towards_point(obj_player.x + 200, ypos, 4);
                    image_angle = direction;
                }
            }
            else
            {
                idd = instance_create(x - 43, y, obj_bullet);
                with (idd)
                {
                    destroyed_on_contact = 0;
                    move_towards_point(obj_player.x - 200, ypos, 4);
                    image_angle = direction;
                }
            }
            latestbullet = idd;
            idd.weapontype = 20610;
            idd.melee = 1;
            idd.onehit = 1;
            idd.destroyed_on_contact = 1;
            idd.bullet_reflector = 1;
            if (instance_exists(idd))
            {
                maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
            }
            with (idd)
            {
                event_user(0);
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome2 && image_index == 3)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos + 32, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            else
            {
                idd = instance_create(x - 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos + 32, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome3 && image_index == 5)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos + 32, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y - 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos - 32, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            else
            {
                idd = instance_create(x - 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos + 32, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y - 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos - 32, 4);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20610;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome_air && image_index == 7)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    speed = 4;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 0;
                }
                idd2 = instance_create(x + 25, y + 25, obj_bullet);
                with (idd2)
                {
                    speed = 4;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 328;
                    image_angle = direction;
                }
                idd3 = instance_create(x, y + 25, obj_bullet);
                with (idd3)
                {
                    speed = 4;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 270;
                    image_angle = direction;
                }
            }
            else
            {
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    speed = 4;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 180;
                    image_angle = direction;
                }
                idd2 = instance_create(x - 25, y + 25, obj_bullet);
                with (idd2)
                {
                    speed = 4;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 212;
                    image_angle = direction;
                }
                idd3 = instance_create(x, y + 25, obj_bullet);
                with (idd3)
                {
                    speed = 4;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 270;
                    image_angle = direction;
                }
            }
            latestbullet = idd;
            idd.weapontype = 20610;
            idd.melee = 1;
            idd.onehit = 1;
            idd.destroyed_on_contact = 1;
            idd.bullet_reflector = 1;
            latestbullet = idd2;
            idd2.weapontype = 20610;
            idd2.melee = 1;
            idd2.onehit = 1;
            idd2.destroyed_on_contact = 1;
            idd2.bullet_reflector = 1;
            latestbullet = idd3;
            idd3.weapontype = 20610;
            idd3.melee = 1;
            idd3.onehit = 1;
            idd3.destroyed_on_contact = 1;
            idd3.bullet_reflector = 1;
            var mastery = 0;
            if (instance_exists(obj_airattackbuff_valk))
            {
                mastery = obj_airattackbuff_valk.stacks + 1;
            }
            with (idd)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            with (idd2)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            with (idd3)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            if (mastery > 0)
            {
                with (idd)
                {
                    weapondamage *= mastery;
                }
                with (idd2)
                {
                    weapondamage *= mastery;
                }
                with (idd3)
                {
                    weapondamage *= mastery;
                }
            }
            if (instance_exists(obj_airattackbuff_valk))
            {
                with (obj_airattackbuff_valk)
                {
                    instance_destroy();
                }
            }
            speed = 0;
        }
    }
    if (weptype == 2)
    {
        if (sprite_index == spr_player_magictome1 && image_index == 2)
        {
            direction = 180;
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 43, y, obj_bullet);
                with (idd)
                {
                    destroyed_on_contact = 0;
                    move_towards_point(obj_player.x + 200, ypos, 22);
                    image_angle = direction;
                }
            }
            else
            {
                idd = instance_create(x - 43, y, obj_bullet);
                with (idd)
                {
                    destroyed_on_contact = 0;
                    move_towards_point(obj_player.x - 200, ypos, 22);
                    image_angle = direction;
                }
            }
            latestbullet = idd;
            idd.weapontype = 20611;
            idd.melee = 1;
            idd.onehit = 1;
            idd.destroyed_on_contact = 1;
            idd.bullet_reflector = 1;
            if (instance_exists(idd))
            {
                maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
            }
            with (idd)
            {
                event_user(0);
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome2 && image_index == 3)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos + 32, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            else
            {
                idd = instance_create(x - 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos + 32, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome3 && image_index == 5)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos + 32, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x + 50, y - 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x + 200, ypos - 32, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            else
            {
                idd = instance_create(x - 50, y, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos + 32, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
                idd = instance_create(x - 50, y - 8, obj_bullet);
                with (idd)
                {
                    move_towards_point(obj_player.x - 200, ypos - 32, 22);
                    image_angle = direction;
                    destroyed_on_contact = 0;
                }
                latestbullet = idd;
                idd.weapontype = 20611;
                idd.melee = 1;
                idd.onehit = 1;
                idd.destroyed_on_contact = 1;
                idd.bullet_reflector = 1;
                if (instance_exists(idd))
                {
                    maxbulletdamage = idd.weapondamage + scr_weapon_charge_damage(idd.weapontype);
                }
                with (idd)
                {
                    event_user(0);
                }
            }
            speed = 0;
        }
        if (sprite_index == spr_player_magictome_air && image_index == 7)
        {
            if (obj_player.dir == 1)
            {
                idd = instance_create(x + 50, y + 8, obj_bullet);
                with (idd)
                {
                    speed = 22;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 0;
                }
                idd2 = instance_create(x + 25, y + 25, obj_bullet);
                with (idd2)
                {
                    speed = 22;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 328;
                    image_angle = direction;
                }
                idd3 = instance_create(x, y + 25, obj_bullet);
                with (idd3)
                {
                    speed = 22;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 270;
                    image_angle = direction;
                }
            }
            else
            {
                idd = instance_create(x - 50, y + 8, obj_bullet);
                with (idd)
                {
                    speed = 22;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 180;
                    image_angle = direction;
                }
                idd2 = instance_create(x - 25, y + 25, obj_bullet);
                with (idd2)
                {
                    speed = 22;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 212;
                    image_angle = direction;
                }
                idd3 = instance_create(x, y + 25, obj_bullet);
                with (idd3)
                {
                    speed = 22;
                    image_xscale = 1;
                    destroyed_on_contact = 0;
                    direction = 270;
                    image_angle = direction;
                }
            }
            latestbullet = idd;
            idd.weapontype = 20611;
            idd.melee = 1;
            idd.onehit = 1;
            idd.destroyed_on_contact = 1;
            idd.bullet_reflector = 1;
            latestbullet = idd2;
            idd2.weapontype = 20611;
            idd2.melee = 1;
            idd2.onehit = 1;
            idd2.destroyed_on_contact = 1;
            idd2.bullet_reflector = 1;
            latestbullet = idd3;
            idd3.weapontype = 20611;
            idd3.melee = 1;
            idd3.onehit = 1;
            idd3.destroyed_on_contact = 1;
            idd3.bullet_reflector = 1;
            var mastery = 0;
            if (instance_exists(obj_airattackbuff_valk))
            {
                mastery = obj_airattackbuff_valk.stacks + 1;
            }
            with (idd)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            with (idd2)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            with (idd3)
            {
                event_user(0);
                weapondamage = ceil(weapondamage * 0.5);
            }
            if (mastery > 0)
            {
                with (idd)
                {
                    weapondamage *= mastery;
                }
                with (idd2)
                {
                    weapondamage *= mastery;
                }
                with (idd3)
                {
                    weapondamage *= mastery;
                }
            }
            if (instance_exists(obj_airattackbuff_valk))
            {
                with (obj_airattackbuff_valk)
                {
                    instance_destroy();
                }
            }
            speed = 0;
        }
    }
    if (weptype == 3)
    {
        if (sprite_index == spr_player_magictome1 && image_index == 2)
        {
            if (obj_player.dir == 1)
            {
                item = instance_create(x + 43, y, obj_throwable_item);
                item.throw_xspeed = 5;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
            }
            else
            {
                item = instance_create(x - 43, y, obj_throwable_item);
                item.throw_xspeed = -5;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
            }
        }
        if (sprite_index == spr_player_magictome2 && image_index == 3)
        {
            if (obj_player.dir == 1)
            {
                item = instance_create(x + 43, y, obj_throwable_item);
                item.throw_xspeed = 5;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x + 43, y, obj_throwable_item);
                item.throw_xspeed = 6;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
            }
            else
            {
                item = instance_create(x - 43, y, obj_throwable_item);
                item.throw_xspeed = -5;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x - 43, y, obj_throwable_item);
                item.throw_xspeed = -6;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
            }
        }
        if (sprite_index == spr_player_magictome3 && image_index == 5)
        {
            if (obj_player.dir == 1)
            {
                item = instance_create(x + 43, y, obj_throwable_item);
                item.throw_xspeed = 5;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x + 43, y, obj_throwable_item);
                item.throw_xspeed = 6;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x + 43, y, obj_throwable_item);
                item.throw_xspeed = 7;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
            }
            else
            {
                item = instance_create(x - 43, y, obj_throwable_item);
                item.throw_xspeed = -5;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x - 43, y, obj_throwable_item);
                item.throw_xspeed = -6;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x - 43, y, obj_throwable_item);
                item.throw_xspeed = -7;
                item.item_id = 17;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
            }
        }
        if (sprite_index == spr_player_magictome_air && image_index == 7)
        {
            var mastery = 0;
            if (instance_exists(obj_airattackbuff_valk))
            {
                mastery = obj_airattackbuff_valk.stacks + 1;
            }
            if (obj_player.dir == 1)
            {
                item = instance_create(x + 50, y + 8, obj_throwable_item);
                item.throw_xspeed = 4;
                item.item_id = 17;
                item.air_attack = mastery;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x + 25, y + 25, obj_throwable_item);
                item.throw_xspeed = 2;
                item.item_id = 17;
                item.air_attack = mastery;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x, y + 25, obj_throwable_item);
                item.throw_xspeed = 0.5;
                item.item_id = 17;
                item.air_attack = mastery;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
            }
            else
            {
                item = instance_create(x - 50, y + 8, obj_throwable_item);
                item.throw_xspeed = -4;
                item.item_id = 17;
                item.air_attack = mastery;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x - 25, y + 25, obj_throwable_item);
                item.throw_xspeed = -2;
                item.item_id = 17;
                item.air_attack = mastery;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
                item = instance_create(x, y + 25, obj_throwable_item);
                item.throw_xspeed = -0.5;
                item.item_id = 17;
                item.air_attack = mastery;
                item.sprite_index = spr_player_magictome_purple;
                item.image_xscale = 1;
                item.image_yscale = 1;
                item.depth = -2000;
                item.throw_yspeed = 0;
            }
            with (obj_airattackbuff_valk)
            {
                instance_destroy();
            }
        }
    }
}

enum UnknownEnum
{
    Value_1 = 1,
    Value_2,
    Value_3,
    Value_4
}

enum e__VW
{
    XView,
    YView,
    WView,
    HView,
    Angle,
    HBorder,
    VBorder,
    HSpeed,
    VSpeed,
    Object,
    Visible,
    XPort,
    YPort,
    WPort,
    HPort,
    Camera,
    SurfaceID
}
