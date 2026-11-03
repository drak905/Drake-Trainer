-- AI_Trainer configuration (Afterimage, Steam build). Edit and restart the game.
-- Key names: any UE4SS Key enum name, e.g. "F1".."F12", "INS", "HOME", "END", "DEL", "NUM_ONE".
-- A modifier can be added with "SHIFT+", "CONTROL+" or "ALT+" (e.g. "SHIFT+F2").
-- Avoid CONTROL (it is the game's dash key) and ALT+F4 (closes the game).
return {
    keys = {
        god         = "F1",   -- toggle God Mode (HP locked at max + game's Invincible flag)
        items       = "F2",   -- add bag_item_amount to every consumable / material in the inventory bag
        jump        = "F3",   -- toggle Unlimited (air) Jump
        speed       = "F4",   -- toggle Move Speed multiplier
        mana        = "F5",   -- toggle Infinite Mana / Energy
        ohk         = "F6",   -- toggle One-Hit Kill (enemies drop to 1 HP)
        heal        = "F7",   -- instant full heal + full mana
        hud         = "F8",   -- collapse the panel to a small pill / expand it again
        speed_cycle = "F9",   -- cycle speed multiplier (speed_steps)
        money_big   = "F10",  -- add money_big
        map_items   = "PAGE_UP",   -- toggle: mark every uncollected chest / item / money stone on the map screen
        map_reveal  = "DEL",       -- toggle: reveal the whole map (removes the fog of war, display only)
        talent      = "PAGE_DOWN", -- add talent_points talent (skill) points
        dash        = "END",       -- toggle Infinite Dash (air dash refilled constantly)
        minimap     = "F12",       -- corner minimap: FOLLOW -> REGION -> OFF (cycles)
        mouse       = "INS",       -- toggle mouse mode: shows the cursor so panel rows can be clicked and the title dragged
        -- (F11 is not used: the engine itself toggles fullscreen on F11. F12 is free if Steam's screenshot key is
        --  moved off F12. PageUp/PageDown also scroll lists in the game's menus, so they fire there too.)
    },
    bag_item_amount = 100,   -- F2: added to the count of every bag item that passes the filters below
    bag_item_cap    = 999,   -- F2 never raises a count above this (0 = no limit)
    -- Which bag items F2 raises. Ids are tried from the game's item-icon names (Icon_<ItemId>) plus bag_extra_ids,
    -- kept when they start with one of bag_item_prefixes (or are listed in bag_item_ids) and do not contain a bag_exclude
    -- text, and are raised only if they are in the bag, in storage, or already listed in the inventory.
    -- Equipment (Weapon_ / Armor_ / Accessories_ / Makeup_) and story / progress items (Quest_*, Key_*, Num_*, Prop_*,
    -- Ability_*, Item_Collecton_*) are left alone on purpose; add an id to bag_item_ids to include one.
    bag_item_prefixes = { "Potion_", "Cook_", "Trade_", "Food_" },
    bag_item_ids      = { "Quest_RestPotion" },     -- Rest Potion (fast travel)
    bag_exclude       = { "Item_Collecton" },
    bag_extra_ids     = { "Potion_HPPotionSmall", "Potion_HPPotionMid", "Potion_HPPotionBig", "Potion_MPPotionSmall", "Potion_MPPotionMid",
                          "Potion_MPPotionBig", "Potion_EquipLevelUp_01", "Potion_EquipLevelUp_02", "Potion_EquipLevelUp_03",
                          "Potion_EquipLevelUp_04", "Potion_EquipLevelUp_05", "Potion_TalentReset", "Potion_TalentPointReward",
                          "Potion_TalentPointReward02" },   -- ids whose icon has a different name
    bag_icon_path     = "/Game/Assets/UMG/TextureAtlases/ItemIcon/Frames",
    money_big   = 100000,
    talent_points = 5,       -- talent points added per press of keys.talent
    speed_steps = { 2.0, 3.0, 4.0, 1.5 },   -- first entry is the default multiplier
    defaults    = { god = false, jump = false, speed = false, mana = false, ohk = false,
                    map_items = false, map_reveal = false, dash = false,
                    minimap = 1 },   -- minimap at start: 0 = off, 1 = follow the player, 2 = whole current region
    -- Corner minimap (bottom-right). Built from the game's own map art (all regions, full layout, no fog of war).
    -- FOLLOW keeps the player in the centre and scrolls the map every frame; REGION shows the whole current region
    -- with the player icon moving across it. Chest / item / money-crystal icons appear on it while Map Item Markers is ON.
    minimap = {
        width = 380.0, height = 230.0,      -- size in UI pixels (1920x1080 reference)
        margin_x = 30.0, margin_y = 30.0,   -- distance from the right / bottom screen edge
        zoom = 0.6,                         -- FOLLOW mode: screen pixels per map texel (1 texel = 25 world units)
        zoom_items = 0.3,                   -- FOLLOW zoom while Map Item Markers is ON (wider view so pickups are in range)
        player_icon_size = 30.0,
        hide_when_paused = true,            -- hide while a menu / the map screen pauses the game
        max_item_icons = 60,
    },
    -- Map item markers: which kinds of pickups to mark, and the map icon used for each kind.
    -- Collected / opened ones are skipped (the game's own "opened" flag is read for every item).
    map_item_types = {
        TreasureBoxHigh = true,    -- treasure chests
        DropActorAdv    = true,    -- items lying on the ground (keys, quest items, runes, talent rewards ...)
        MoneyStone      = true,    -- breakable money crystals
        NPC_Soul_Echo   = false,   -- soul echoes (lore NPCs; their "visited" state cannot be read, so all are shown)
    },
    map_icons = {
        TreasureBoxHigh = "/Game/Assets/UMG/TextureAtlases/Map/Sign/Icon_Explore.Icon_Explore",
        DropActorAdv    = "/Game/Assets/UMG/TextureAtlases/Map/Sign/Icon_Explore.Icon_Explore",
        MoneyStone      = "/Game/Assets/UMG/TextureAtlases/Map/Sign/Icon_Mark_01.Icon_Mark_01",
        NPC_Soul_Echo   = "/Game/Assets/UMG/TextureAtlases/Map/Sign/Icon_Thinker_01.Icon_Thinker_01",
    },
    debug       = false,   -- true = log every jump-key event / airborne change to ue4ss\UE4SS.log
    space_fallback = true, -- also listen to the raw Space key (the game-mapping poll already covers Space/pad A/rebinds)
    god_hook    = true,    -- God Mode: also rewrite lethal HP writes before the game stores them (the main protection; false = only the per-frame HP guard)
    startup_delay = 30.0,  -- seconds after game start before the trainer touches the game (avoids a UE4SS start-up race)
    show_hud    = true,    -- true = full panel at start, false = the small pill ("AFTERIMAGE TRAINER ... [F8 Show] (N Active)")
    hud_collapse_to_pill = true,  -- F8 collapses to the pill; false = F8 hides the panel completely
    hud_x       = 20.0,    -- panel position (UI pixels from the top-left). Dragging the title bar with the mouse saves a new
    hud_y       = 150.0,   -- position to hud_pos.txt next to this file, which takes priority; delete that file to reset.
    hud = { width = 380.0 },
    -- SProp (SPropertySystem) ids on the player's SPropComponent, recovered via reflection + live tests
    -- (names from TalentSkillFunctionLibrary.GetSPropTemplateName_DescMap + GetSPropertyEnumIntFromName)
    sprop = { hp = 1, max_hp = 2, mana = 3, max_mana = 4, money = 20, walk_speed = 36,
              object_open = 11,                 -- prop_status_object_open (per chest / item / money stone save id)
              dash_max = 37, dash_remain = 38,  -- prop_move_max_dash_count / prop_move_current_remain_dash_count
              talent_sum = 182, talent_used = 183,   -- prop_talent_point_sum / prop_talent_point_used
              actor_dead = 51 },                      -- prop_status_actor_dead (self-test only)
}
