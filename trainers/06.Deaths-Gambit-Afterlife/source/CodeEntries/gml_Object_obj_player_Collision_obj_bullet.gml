if (other.damage_player == false)
{
    exit;
}
if (scr_block_paffect == 1)
{
}
else
{
    if (instance_exists(obj_player_knockback))
    {
        exit;
    }
    if (instance_exists(obj_whitemage_Paffect))
    {
        exit;
    }
    if (Deactivate != 0)
    {
        exit;
    }
    if (justgotup > 0)
    {
        exit;
    }
    if (dodgeroll_invincibility != 0)
    {
        scr_dodgerolled_through_attack();
        exit;
    }
    if (scr_invincibility_sprite() == 1)
    {
        exit;
    }
    if (other.Paffect != 0)
    {
        exit;
    }
    if (sprite_index == scr_shield_broken_sprite() && image_index <= 6)
    {
        exit;
    }
    if (scr_is_talent_owned(107) == 1 && sprite_index == sPlayerJumpDbl && image_index < 5.1)
    {
        exit;
    }
    if (scr_is_talent_owned(108) == 1 && sprite_index == spr_crashdown1)
    {
        exit;
    }
    if ((sprite_index == player_roll_right && image_index < roll_index) || (sprite_index == player_roll_left && image_index < roll_index))
    {
        scr_dodgerolled_through_attack();
        exit;
    }
}
damagetaken = ceil(-220 * damagetakenbuff);
damagetaken += scr_newgameplus_damage(damagetaken);
if (other.weapontype == 20611 && scr_is_talent_owned(133) == 1)
{
    damagetaken = ceil(damagetaken * 0.9);
}
if (other.weapontype != 20611 && scr_is_talent_owned(134) == 1)
{
    damagetaken = ceil(damagetaken * 0.9);
}
if (scr_has_parried())
{
    with (other)
    {
        idd = instance_create(x, y, obj_whitemage_spell2_bullet_parry);
        if (obj_player.dir == -1)
        {
            instance_create(obj_player.x - 30, obj_player.y, obj_parry_effect);
        }
        if (obj_player.dir == 1)
        {
            instance_create(obj_player.x + 30, obj_player.y, obj_parry_effect);
            with (obj_parry_effect)
            {
                image_xscale = -1;
            }
        }
        with (obj_mouse)
        {
            shake = 3;
        }
        instance_destroy();
        exit;
    }
}
if (obj_player.megastunned != 0)
{
    with (obj_player)
    {
        megastunned = 0;
        stunned = 0;
    }
}
instance_create(x, y, obj_whitemage_Paffect);
if (shielded == 1)
{
    perfect_block_let_retaliate = 0;
    scr_turtle_block();
    perfect_block_let_retaliate = 1;
    if (global.inv_item_shield == 72)
    {
        if (global.Endurance < ((damagetaken / 2) * -1 * ((100 - global.shielddef) / 100)))
        {
            damagetaken += global.Endurance;
            global.Endurance = 0;
        }
        else
        {
            exit;
        }
    }
    if (global.Endurance > ((damagetaken / 2) * -1 * ((100 - global.shielddef) / 100)) && dir == 1)
    {
        scr_shield_block_sound();
        global.Endurance += ceil((damagetaken / 2) * ((100 - global.shielddef) / 100));
        with (obj_endurancebar)
        {
            alarm[0] = 60;
        }
        alarm[9] = 13;
        abilityalarm = 1012;
        image_index = 0;
        for (yup = 0; yup < 10; yup += 1)
        {
            if (place_free(x - 8, y - yup))
            {
                x -= 8;
                y -= yup;
                break;
            }
        }
        exit;
    }
    else if (global.Endurance > ((damagetaken / 2) * -1 * ((100 - global.shielddef) / 100)) && dir == -1)
    {
        scr_shield_block_sound();
        global.Endurance += ceil((damagetaken / 2) * ((100 - global.shielddef) / 100));
        global.ProHealth += 0;
        alarm[9] = 13;
        abilityalarm = 1012;
        image_index = 0;
        with (obj_endurancebar)
        {
            alarm[0] = 60;
        }
        for (yup = 0; yup < 10; yup += 1)
        {
            if (place_free(x + 8, y - yup))
            {
                x += 8;
                y -= yup;
                break;
            }
        }
        exit;
    }
    else
    {
        damagetaken = 0;
        global.Endurance = 0;
    }
}
if (shielded == 0 || (shielded == 1 && dir == 1 && x > other.x && global.inv_item_shield != 72) || (shielded == 1 && dir == -1 && x < other.x && global.inv_item_shield != 72))
{
    if (scr_check_poise() == true)
    {
    }
    else
    {
        stunned = 0;
    }
    scr_player_hurt();
    scr_onhurt();
    scr_pl_hurt();
}
else if (shielded == 1 && global.Endurance == 0 && !instance_exists(obj_perfectblock))
{
    shielded = 0;
    stunned = 1;
    megastunned = 2;
    abilityalarm = 0;
    alarm[9] = 156;
    global.casttimecurrent = 0;
    instance_create(x, y, obj_player_shield_broken_ui);
}
with (other)
{
    instance_destroy();
}
if (instance_exists(obj_fleetingprotection))
{
    damagetaken = 0;
    with (obj_fleetingprotection)
    {
        instance_destroy();
    }
}
global.ProHealth += damagetaken;
OB = instance_create(x, y - 50, obj_player_takes_damage_text);
OB.countershow = ceil(damagetaken * -1);
