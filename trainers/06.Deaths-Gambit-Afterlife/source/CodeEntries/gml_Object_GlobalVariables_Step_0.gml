if (ignore_fullscreen_fix > 0)
{
    ignore_fullscreen_fix--;
}
if (bug_fix_equip_sfx > 0)
{
    bug_fix_equip_sfx--;
}
soul_sprite_index += 0.25;
if (soul_sprite_index >= 6)
{
    soul_sprite_index = 0;
}
if (count_down_exp > 0)
{
    count_down_exp--;
}
if (can_switch_items_timer > 0)
{
    can_switch_items_timer--;
}
if (previous_window_w != window_get_width() || previous_window_h != window_get_height())
{
    alarm[7] = 2;
    alarm[8] = 4;
}
previous_window_w = window_get_width();
previous_window_h = window_get_height();
mouselock_update();
if (switch_controls == 0)
{
    if (keymap.type == 1)
    {
        if (os_type == os_ps4 || gamepad_get_description(keymap.slot) == "PLAYSTATION(R)3 Controller")
        {
            controllertype = 1;
        }
        else if (os_is_xbox() || gamepad_get_description(keymap.slot) == "Xbox 360 Controller (XInput STANDARD GAMEPAD)")
        {
            controllertype = 0;
        }
        else if (os_type == os_switch)
        {
            controllertype = 2;
        }
        else
        {
            controllertype = 0;
        }
    }
}
else if (keymap.type == 1)
{
    if (os_type == os_ps4 || gamepad_get_description(keymap.slot) == "PLAYSTATION(R)3 Controller")
    {
        controllertype = 1;
    }
    else if (os_is_xbox() || gamepad_get_description(keymap.slot) == "Xbox 360 Controller (XInput STANDARD GAMEPAD)")
    {
        controllertype = 0;
    }
    else if (os_type == os_switch)
    {
        controllertype = 2;
    }
    else
    {
        controllertype = 0;
    }
}
time_played += 1;
if (time_played >= 3600)
{
    time_played = 0;
    time_played_minutes += 1;
}
if (time_played_minutes > 59)
{
    time_played_minutes = 0;
    time_played_hours += 1;
}
if (slowmo == 0)
{
    if (room_speed < 60 && obj_gun.alarm[11] <= -1)
    {
        if (!roomspeed_debug())
        {
            room_speed = 60;
        }
        spineunit_restore_slomoframe(1411);
        spineunit_restore_slomoframe(1412);
        spineunit_restore_slomoframe(1414);
        spineunit_restore_slomoframe(1415);
        spineunit_restore_slomoframe(1291);
        spineunit_restore_slomoframe(240);
        spineunit_restore_slomoframe(1458);
        spineunit_restore_slomoframe(1387);
        spineunit_restore_slomoframe(1459);
        spineunit_restore_slomoframe(6284);
        spineunit_restore_slomoframe(1871);
        spineunit_restore_slomoframe(1872);
        spineunit_restore_slomoframe(1468);
        spineunit_restore_slomoframe(1873);
        spineunit_restore_slomoframe(1476);
        spineunit_restore_slomoframe(2063);
        spineunit_restore_slomoframe(1877);
        spineunit_restore_slomoframe(1943);
        spineunit_restore_slomoframe(1944);
        spineunit_restore_slomoframe(1419);
    }
    if (obj_gun.alarm[11] <= -1)
    {
        if (!roomspeed_debug())
        {
            room_speed = 60;
        }
    }
}
if (slowmo == 1)
{
    if (room_speed < 60)
    {
        spineunit_restore_slomoframe(1411);
        spineunit_restore_slomoframe(1412);
        spineunit_restore_slomoframe(1414);
        spineunit_restore_slomoframe(1415);
        spineunit_restore_slomoframe(1291);
        spineunit_restore_slomoframe(240);
        spineunit_restore_slomoframe(1458);
        spineunit_restore_slomoframe(1387);
        spineunit_restore_slomoframe(1459);
        spineunit_restore_slomoframe(6284);
        spineunit_restore_slomoframe(1871);
        spineunit_restore_slomoframe(1872);
        spineunit_restore_slomoframe(1468);
        spineunit_restore_slomoframe(1873);
        spineunit_restore_slomoframe(1476);
        spineunit_restore_slomoframe(2063);
        spineunit_restore_slomoframe(1877);
        spineunit_restore_slomoframe(1943);
        spineunit_restore_slomoframe(1944);
        spineunit_restore_slomoframe(1419);
    }
    if (!roomspeed_debug())
    {
        room_speed = 60;
    }
}
var rm_speed = 20;
if (instance_exists(obj_player_perfect_block) && obj_player_perfect_block.image_index <= 1.5)
{
    rm_speed = 10;
}
if (obj_gun.alarm[11] > -1)
{
    if (room_speed != rm_speed)
    {
        spineunit_store_slomoframe(1411);
        spineunit_store_slomoframe(1412);
        spineunit_store_slomoframe(1414);
        spineunit_store_slomoframe(1415);
        spineunit_store_slomoframe(1291);
        spineunit_store_slomoframe(240);
        spineunit_store_slomoframe(1458);
        spineunit_store_slomoframe(1387);
        spineunit_store_slomoframe(1459);
        spineunit_store_slomoframe(6284);
        spineunit_store_slomoframe(1871);
        spineunit_store_slomoframe(1872);
        spineunit_store_slomoframe(1468);
        spineunit_store_slomoframe(1873);
        spineunit_store_slomoframe(1476);
        spineunit_store_slomoframe(2063);
        spineunit_store_slomoframe(1877);
        spineunit_store_slomoframe(1943);
        spineunit_store_slomoframe(1944);
        spineunit_store_slomoframe(1419);
    }
    if (!roomspeed_debug())
    {
        room_speed = rm_speed;
    }
}
if (obj_player.sprite_index == spr_player_shield_moss_walkback || obj_player.sprite_index == spr_player_shield_moss_walk || obj_player.sprite_index == spr_player_shield_moss_hit || obj_player.sprite_index == spr_player_shield_moss_end || obj_player.sprite_index == spr_player_shield_moss || obj_player.sprite_index == spr_player_shield_moss_kick || obj_player.sprite_index == spr_player_shield_moss_parry || obj_player.sprite_index == spr_player_shield_moss_broken)
{
    if (global.Endurance > 0)
    {
        global.Endurance -= 0.25;
        GlobalVariables.endurancedelay = 20;
    }
}
if (obj_player.sprite_index == spr_player_shield_corpse || obj_player.sprite_index == spr_player_shield_corpse_end || obj_player.sprite_index == spr_player_shield_corpse_broken || obj_player.sprite_index == spr_player_shield_corpse_hit || obj_player.sprite_index == spr_player_shield_corpse_kick || obj_player.sprite_index == spr_player_shield_corpse_parry || obj_player.sprite_index == spr_player_shield_corpse_walk || obj_player.sprite_index == spr_player_shield_corpse_walkback)
{
    if (room == room_heart_of_fear1)
    {
    }
    else
    {
        obj_player.poison += 1;
        if (obj_player.poison > 120)
        {
            if (instance_number(obj_poison_debuff) == 0)
            {
                buff = instance_create(x, y, obj_poison_debuff);
                buff.x = 500;
                buff.parenttarget = obj_buffui.id;
            }
        }
    }
}
if (global.Endurance < 0)
{
    global.Endurance = 0;
}
if (global.Endurance > global.EnduranceMax)
{
    global.Endurance = global.EnduranceMax;
}
if (endurancedelay > 0)
{
    endurancedelay -= 2;
}
if (global.Endurance < global.EnduranceMax && instance_number(obj_recentroll) == 0 && endurancedelay < 1)
{
    if (obj_player.shielded == 0 && !instance_exists(obj_nostaminaregen))
    {
        global.Endurance += (1.5 * (1 + (global.staminaregen / 100)));
    }
    else if (!instance_exists(obj_nostaminaregen))
    {
        global.Endurance += (0.15 * (1 + (global.staminaregen / 100)) * (obj_player.stamina_regen_increase + 1));
    }
    if (instance_number(obj_dragonberry) == 1)
    {
        if (obj_player.shielded == 0)
        {
            global.Endurance += (1 * (1 + (global.staminaregen / 100)));
        }
        else
        {
            global.Endurance += (0.15 * (1 + (global.staminaregen / 100)));
        }
    }
    if (instance_number(obj_lightningdark) == 1)
    {
        if (obj_player.shielded == 0)
        {
            global.Endurance += (4 * (1 + (global.staminaregen / 100)));
        }
        else
        {
            global.Endurance += (1 * (1 + (global.staminaregen / 100)));
        }
    }
    if (instance_exists(obj_grimgauds_brew))
    {
        global.Endurance -= 0.05;
    }
}
if (obj_player.poison > 0)
{
    obj_player.poison -= 0.05;
}
if (obj_player.contagion_count > 0)
{
    obj_player.contagion_count -= 0.01;
}
if (room != room_above_gaianscradle)
{
    obj_player.wraith_meter = 0;
}
if (obj_player.shock > 0)
{
    obj_player.shock -= 0.05;
}
if (obj_player.feathersilence > 0)
{
    obj_player.feathersilence -= 0.05;
}
event_user(6);
with (other)
{
    if (GlobalVariables.keymap_just_destroyed_timer > 0)
    {
        GlobalVariables.keymap_just_destroyed_timer--;
    }
    if (keymap.type == 0 && keyboard_check_pressed(ord("M")) == 1 && !instance_exists(obj_save_button) == true)
    {
        var _can_open_map = true;
        if (instance_exists(obj_cant_open_map) || instance_exists(obj_cutscene_master) || obj_player.Deactivate == 1 || obj_player.disableactions == 1 || GlobalVariables.visible == false)
        {
            _can_open_map = false;
        }
        if (instance_exists(obj_options_ui_keymap) || GlobalVariables.keymap_just_destroyed_timer > 0)
        {
            _can_open_map = false;
        }
        if (_can_open_map)
        {
            if (isinventoryopen == 1 && keymap.type == 0)
            {
                with (obj_goldinv_slider)
                {
                    state = 3;
                    oInventory.invmenupage = 3;
                    instance_create(-1000, -1000, obj_exit_icon);
                    if (oInventory.alarm[10] < 1)
                    {
                        aud_play_sound(2420, 0, 0);
                        oInventory.alarm[10] = 10;
                    }
                }
            }
            else
            {
                open_map = 1;
                event_user(2);
                if (open_map == 1)
                {
                    oInventory.invmenupage = 3;
                }
                open_map = 0;
            }
        }
    }
    if (instance_exists(obj_NEW_levelup_menu) && obj_NEW_levelup_menu.dont_obj_must_press_confirm == 1 && !instance_exists(obj_must_press_confirm_destroyed) && gamepad_button_check_pressed(keymap.slot, keymap.back_button) == 1 && instance_exists(obj_save_button) == true)
    {
        instance_create(x, y, obj_must_press_confirm);
    }
    else if ((key_check_pressed_gamepad(UnknownEnum.Value_33) == 1 && !instance_exists(obj_teleport_ui) && !instance_exists(obj_NEW_levelup_menu)) || (gamepad_button_check_pressed(keymap.slot, keymap.back_button) == 1 && instance_exists(obj_save_button) == true && !instance_exists(obj_teleport_ui)))
    {
        event_user(2);
    }
    if (keymap.type == 0 && key_check_pressed(UnknownEnum.Value_33))
    {
        event_user(2);
    }
    if (gamepad_button_check_pressed(keymap.slot, keymap.back_button) == 1 && isinventoryopen == 1)
    {
        event_user(3);
        obj_player.no_backstep = 1;
    }
}
if (global.abilityslot_1_cooldown > 0)
{
    global.abilityslot_1_cooldown -= 1;
}
if (global.abilityslot_2_cooldown > 0)
{
    global.abilityslot_2_cooldown -= 1;
}
if (global.abilityslot_3_cooldown > 0)
{
    global.abilityslot_3_cooldown -= 1;
}
if (global.abilityslot_4_cooldown > 0)
{
    global.abilityslot_4_cooldown -= 1;
}
if (scr_is_talent_owned(28) == 1)
{
    if (global.abilityslot_1_cooldown <= 0 && abilityslot_1_cooldown_previous > 0)
    {
        instance_create(x, y, obj_ab1_timing);
    }
    if (global.abilityslot_2_cooldown <= 0 && abilityslot_2_cooldown_previous > 0)
    {
        instance_create(x, y, obj_ab2_timing);
    }
    if (global.abilityslot_3_cooldown <= 0 && abilityslot_3_cooldown_previous > 0)
    {
        instance_create(x, y, obj_ab3_timing);
    }
    if (global.abilityslot_4_cooldown <= 0 && abilityslot_4_cooldown_previous > 0)
    {
        instance_create(x, y, obj_ab4_timing);
    }
}
abilityslot_1_cooldown_previous = global.abilityslot_1_cooldown;
abilityslot_2_cooldown_previous = global.abilityslot_2_cooldown;
abilityslot_3_cooldown_previous = global.abilityslot_3_cooldown;
abilityslot_4_cooldown_previous = global.abilityslot_4_cooldown;
if (room == Obsidian_Plateau0)
{
    __background_set(e__BG.X, 1, global.view_x / 1.1);
    __background_set(e__BG.X, 2, global.view_x / 3);
    __background_set(e__BG.X, 4, 2484 + (obj_player.x / 10));
    __background_set(e__BG.X, 6, 2850 + (obj_player.x / 15));
    __background_set(e__BG.X, 3, global.view_x / 6);
}
global.ProBarHealth = (global.ProHealth / global.ProMaxHealth) * 100;
if (global.ProHealth < 0)
{
    global.ProHealth = 0;
}
if (global.ProHealth > global.ProMaxHealth)
{
    global.ProHealth = global.ProMaxHealth;
    global.ProHealth = global.ProMaxHealth;
}
if (global.ProBarHealth > global.HurtHealth)
{
    global.HurtHealth = global.ProBarHealth;
}
if (global.ProBarHealth < global.HurtHealth && alarm[11] < 1)
{
    global.HurtHealth -= 0.25;
}
if (sleep_timer)
{
    sleep_timer--;
    if (!sleep_timer)
    {
        for (i = 0; i < ds_list_size(sleep_deactivated_list); i++)
        {
            var curobj = ds_list_find_value(sleep_deactivated_list, i);
            instance_activate_object(curobj.parent_id);
            with (curobj)
            {
                instance_destroy();
            }
        }
        ds_list_clear(GlobalVariables.sleep_deactivated_list);
    }
}
if (switched_rooms_climbing > 0)
{
    switched_rooms_climbing--;
    if (!switched_rooms_climbing)
    {
        with (obj_player)
        {
            var pathpoint = instance_nearest(x, y, obj_pathpoint);
            if (pathpoint == -4)
            {
                exit;
            }
            if (pathpoint.latch_type == 1)
            {
                var closest_pathpoint = collision_rectangle(bbox_left, bbox_bottom - 2, bbox_right, bbox_bottom + 2, obj_pathpoint, 1, 1);
                if (closest_pathpoint != -4)
                {
                    if (closest_pathpoint.latch_type == 1)
                    {
                        if (instance_exists(obj_playerclimb))
                        {
                            with (obj_playerclimb)
                            {
                                instance_destroy();
                            }
                        }
                        var newclimber = instance_create(x, y, obj_playerclimb);
                        newclimber.created_from_player = 1;
                        newclimber.climb_until_buttonreleased = true;
                        newclimber.kneeling_down = 1;
                        newclimber.closest_pathpoint = closest_pathpoint;
                        newclimber.created_from_player = 1;
                        with (newclimber)
                        {
                            if (!place_meeting(x, y, obj_pathpoint))
                            {
                                scr_pathpoint_collision_event();
                            }
                            newclimber.visible = 0;
                        }
                        path_climbing = 1;
                        exit;
                    }
                }
            }
            else
            {
                var closest_pathpoint = instance_nearest(x, y, obj_pathpoint);
                x = closest_pathpoint.x;
                if (instance_exists(obj_playerclimb))
                {
                    with (obj_playerclimb)
                    {
                        instance_destroy();
                    }
                }
                var newclimber = instance_create(x, y, obj_playerclimb);
                newclimber.created_from_player = 1;
                newclimber.climb_until_buttonreleased = true;
                newclimber.closest_pathpoint = closest_pathpoint;
                path_climbing = 1;
                exit;
            }
        }
    }
}

enum UnknownEnum
{
    Value_3 = 3,
    Value_33 = 33
}

enum e__BG
{
    Visible,
    Foreground,
    Index,
    X,
    Y,
    Width,
    Height,
    HTiled,
    VTiled,
    XScale,
    YScale,
    HSpeed,
    VSpeed,
    Blend,
    Alpha
}
