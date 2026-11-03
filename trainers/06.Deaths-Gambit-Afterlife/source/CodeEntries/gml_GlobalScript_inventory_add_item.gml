function inventory_add_item(arg0, arg1)
{
    var newno = 0;
    var itemno = arg0;
    var number = arg1;
    if (itemno == 85 && GlobalVariables.envsaves[122] == 0)
    {
        GlobalVariables.envsaves[122] = 1;
        aud_play_sound(964, 0, 0);
        global.PotionRealMaxNotDead += 1;
        global.PotionRealMax += 1;
        global.PotionMax += 1;
        global.PotionUse += 1;
        announcement = instance_create(x, y, obj_announcement);
        with (announcement)
        {
            alarm[3] = 1;
        }
        chatbox = instance_create(x, y, obj_subtitle_text);
        chatbox.timeleft = 300;
        chatbox.subtitletext = scr_loc(UnknownEnum.Value_2288);
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
        exit;
    }
    if (itemno == 218 && GlobalVariables.envsaves[397] == 0 && room == Blightlands1_edit && obj_player.x > 3000 && instance_exists(obj_merchant_ui))
    {
        GlobalVariables.envsaves[397] = 1;
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
    }
    if (itemno == 91 && instance_exists(obj_merchant_ui))
    {
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
    }
    if (itemno == 218 && GlobalVariables.envsaves[604] == 0 && room == Blightlands1_edit && obj_player.x < 3000 && instance_exists(obj_merchant_ui))
    {
        GlobalVariables.envsaves[604] = 1;
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
    }
    if (itemno == 114 && GlobalVariables.envsaves[628] == 0)
    {
        GlobalVariables.envsaves[628] = 1;
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
    }
    if (itemno == 226 && GlobalVariables.envsaves[259] == 0)
    {
        GlobalVariables.envsaves[259] = 1;
        with (obj_ui_notice)
        {
            instance_destroy();
        }
        if (GlobalVariables.envsaves[258] == 1)
        {
            with (instance_create(x, y, obj_journalpage_ui))
            {
                boss = 4;
                page = 1;
            }
            GlobalVariables.bosshint[4][1] = 1;
        }
        else
        {
            with (instance_create(x, y, obj_journalpage_ui))
            {
                boss = 4;
                page = 0;
            }
            GlobalVariables.bosshint[4][0] = 1;
        }
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
        if (GlobalVariables.envsaves[269] == 1 && GlobalVariables.envsaves[268] == 1 && GlobalVariables.envsaves[267] == 1 && GlobalVariables.envsaves[266] == 1 && GlobalVariables.envsaves[265] == 1 && GlobalVariables.envsaves[264] == 1 && GlobalVariables.envsaves[263] == 1 && GlobalVariables.envsaves[262] == 1 && GlobalVariables.envsaves[261] == 1 && GlobalVariables.envsaves[260] == 1 && GlobalVariables.envsaves[259] == 1 && GlobalVariables.envsaves[258] == 1 && GlobalVariables.envsaves[257] == 1 && GlobalVariables.envsaves[256] == 1 && GlobalVariables.envsaves[255] == 1 && GlobalVariables.envsaves[254] == 1 && GlobalVariables.envsaves[253] == 1 && GlobalVariables.envsaves[252] == 1 && GlobalVariables.envsaves[251] == 1 && GlobalVariables.envsaves[250] == 1 && GlobalVariables.envsaves[462] == 1 && GlobalVariables.envsaves[463] == 1 && GlobalVariables.envsaves[464] == 1 && GlobalVariables.envsaves[465] == 1 && GlobalVariables.envsaves[466] == 1 && GlobalVariables.envsaves[467] == 1 && GlobalVariables.envsaves[468] == 1 && GlobalVariables.envsaves[469] == 1 && GlobalVariables.envsaves[470] == 1 && GlobalVariables.envsaves[471] == 1 && GlobalVariables.envsaves[472] == 1 && GlobalVariables.envsaves[473] == 1 && GlobalVariables.envsaves[474] == 1 && GlobalVariables.envsaves[475] == 1 && GlobalVariables.envsaves[476] == 1 && GlobalVariables.envsaves[477] == 1 && GlobalVariables.envsaves[478] == 1 && GlobalVariables.envsaves[479] == 1)
        {
            GlobalVariables.envsaves[307] = 1;
            madach_complete(UnknownEnum.Value_15);
            if (!steam_get_achievement("the_bookkeeper"))
            {
                steam_set_achievement("the_bookkeeper");
            }
        }
        exit;
    }
    if (itemno == 227 && GlobalVariables.envsaves[467] == 0)
    {
        GlobalVariables.envsaves[467] = 1;
        with (obj_ui_notice)
        {
            instance_destroy();
        }
        if (GlobalVariables.envsaves[466] == 1)
        {
            with (instance_create(x, y, obj_journalpage_ui))
            {
                boss = 13;
                page = 1;
            }
            GlobalVariables.bosshint[13][1] = 1;
        }
        else
        {
            with (instance_create(x, y, obj_journalpage_ui))
            {
                boss = 13;
                page = 0;
            }
            GlobalVariables.bosshint[13][0] = 1;
        }
        if (GlobalVariables.envsaves[269] == 1 && GlobalVariables.envsaves[268] == 1 && GlobalVariables.envsaves[267] == 1 && GlobalVariables.envsaves[266] == 1 && GlobalVariables.envsaves[265] == 1 && GlobalVariables.envsaves[264] == 1 && GlobalVariables.envsaves[263] == 1 && GlobalVariables.envsaves[262] == 1 && GlobalVariables.envsaves[261] == 1 && GlobalVariables.envsaves[260] == 1 && GlobalVariables.envsaves[259] == 1 && GlobalVariables.envsaves[258] == 1 && GlobalVariables.envsaves[257] == 1 && GlobalVariables.envsaves[256] == 1 && GlobalVariables.envsaves[255] == 1 && GlobalVariables.envsaves[254] == 1 && GlobalVariables.envsaves[253] == 1 && GlobalVariables.envsaves[252] == 1 && GlobalVariables.envsaves[251] == 1 && GlobalVariables.envsaves[250] == 1 && GlobalVariables.envsaves[462] == 1 && GlobalVariables.envsaves[463] == 1 && GlobalVariables.envsaves[464] == 1 && GlobalVariables.envsaves[465] == 1 && GlobalVariables.envsaves[466] == 1 && GlobalVariables.envsaves[467] == 1 && GlobalVariables.envsaves[468] == 1 && GlobalVariables.envsaves[469] == 1 && GlobalVariables.envsaves[470] == 1 && GlobalVariables.envsaves[471] == 1 && GlobalVariables.envsaves[472] == 1 && GlobalVariables.envsaves[473] == 1 && GlobalVariables.envsaves[474] == 1 && GlobalVariables.envsaves[475] == 1 && GlobalVariables.envsaves[476] == 1 && GlobalVariables.envsaves[477] == 1 && GlobalVariables.envsaves[478] == 1 && GlobalVariables.envsaves[479] == 1)
        {
            GlobalVariables.envsaves[307] = 1;
            madach_complete(UnknownEnum.Value_15);
            if (!steam_get_achievement("the_bookkeeper"))
            {
                steam_set_achievement("the_bookkeeper");
            }
        }
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
        exit;
    }
    if (itemno == 228 && GlobalVariables.envsaves[463] == 0)
    {
        GlobalVariables.envsaves[463] = 1;
        with (obj_ui_notice)
        {
            instance_destroy();
        }
        if (GlobalVariables.envsaves[462] == 1)
        {
            with (instance_create(x, y, obj_journalpage_ui))
            {
                boss = 15;
                page = 1;
            }
            GlobalVariables.bosshint[15][1] = 1;
        }
        else
        {
            with (instance_create(x, y, obj_journalpage_ui))
            {
                boss = 15;
                page = 0;
            }
            GlobalVariables.bosshint[15][0] = 1;
        }
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
        if (GlobalVariables.envsaves[269] == 1 && GlobalVariables.envsaves[268] == 1 && GlobalVariables.envsaves[267] == 1 && GlobalVariables.envsaves[266] == 1 && GlobalVariables.envsaves[265] == 1 && GlobalVariables.envsaves[264] == 1 && GlobalVariables.envsaves[263] == 1 && GlobalVariables.envsaves[262] == 1 && GlobalVariables.envsaves[261] == 1 && GlobalVariables.envsaves[260] == 1 && GlobalVariables.envsaves[259] == 1 && GlobalVariables.envsaves[258] == 1 && GlobalVariables.envsaves[257] == 1 && GlobalVariables.envsaves[256] == 1 && GlobalVariables.envsaves[255] == 1 && GlobalVariables.envsaves[254] == 1 && GlobalVariables.envsaves[253] == 1 && GlobalVariables.envsaves[252] == 1 && GlobalVariables.envsaves[251] == 1 && GlobalVariables.envsaves[250] == 1 && GlobalVariables.envsaves[462] == 1 && GlobalVariables.envsaves[463] == 1 && GlobalVariables.envsaves[464] == 1 && GlobalVariables.envsaves[465] == 1 && GlobalVariables.envsaves[466] == 1 && GlobalVariables.envsaves[467] == 1 && GlobalVariables.envsaves[468] == 1 && GlobalVariables.envsaves[469] == 1 && GlobalVariables.envsaves[470] == 1 && GlobalVariables.envsaves[471] == 1 && GlobalVariables.envsaves[472] == 1 && GlobalVariables.envsaves[473] == 1 && GlobalVariables.envsaves[474] == 1 && GlobalVariables.envsaves[475] == 1 && GlobalVariables.envsaves[476] == 1 && GlobalVariables.envsaves[477] == 1 && GlobalVariables.envsaves[478] == 1 && GlobalVariables.envsaves[479] == 1)
        {
            GlobalVariables.envsaves[307] = 1;
            madach_complete(UnknownEnum.Value_15);
            if (!steam_get_achievement("the_bookkeeper"))
            {
                steam_set_achievement("the_bookkeeper");
            }
        }
        exit;
    }
    if (item_type(itemno) == "item")
    {
        if (global.inv_item_item1 == itemno)
        {
            global.equip_select_item1_number += number;
            exit;
        }
        if (global.inv_item_item2 == itemno)
        {
            global.equip_select_item2_number += number;
            exit;
        }
        if (global.inv_item_item3 == itemno)
        {
            global.equip_select_item3_number += number;
            exit;
        }
        if (global.inv_item_item4 == itemno)
        {
            global.equip_select_item4_number += number;
            exit;
        }
    }
    if (item_type(itemno) != "weapon" && item_stackable(itemno) == 1)
    {
        for (var a = 1; a <= 167; a += 1)
        {
            if (global.inv_item[a][0] == itemno && item_type(global.inv_item[a][0]) == "item")
            {
                newno = a;
                global.inv_item[a][1] += number;
                a = 168;
            }
        }
        if (newno == 0)
        {
            var lastno = 0;
            for (var b = 1; b <= 167; b += 1)
            {
                if (global.inv_item[b][0] == 0)
                {
                    lastno = b;
                    b = 168;
                }
            }
            if (lastno == 0)
            {
                return 1;
            }
            else
            {
                global.inv_item[lastno][0] = itemno;
                global.inv_item[lastno][1] = number;
            }
        }
    }
    else
    {
        var lastno = 0;
        var n = 0;
        repeat (number)
        {
            n += 1;
            for (var a = 1; a <= 167; a += 1)
            {
                if (global.inv_item[a][0] == 0)
                {
                    lastno = a;
                    a = 168;
                }
            }
            if (lastno == 0)
            {
                return number - n;
            }
            else
            {
                global.inv_item[lastno][0] = itemno;
                global.inv_item[lastno][1] = 1;
            }
        }
    }
    if (itemno == 114 && GlobalVariables.envsaves[361] == 0)
    {
        GlobalVariables.envsaves[361] = 1;
        with (obj_merchant_ui)
        {
            instance_destroy();
        }
    }
    return 0;
}

enum UnknownEnum
{
    Value_15 = 15,
    Value_2288 = 2288
}
