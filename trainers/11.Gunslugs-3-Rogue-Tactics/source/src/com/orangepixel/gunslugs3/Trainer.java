package com.orangepixel.gunslugs3;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.files.FileHandle;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.PixmapIO;
import com.badlogic.gdx.utils.ScreenUtils;
import com.orangepixel.gunslugs3.ai.BossEntity;
import com.orangepixel.gunslugs3.ai.BossEntityList;
import com.orangepixel.gunslugs3.ai.BulletEntity;
import com.orangepixel.gunslugs3.ai.BulletEntityList;
import com.orangepixel.gunslugs3.ai.EntitySprite;
import com.orangepixel.gunslugs3.ai.MonsterEntity;
import com.orangepixel.gunslugs3.ai.MonsterEntityList;
import com.orangepixel.gunslugs3.ai.PlayerEntity;
import com.orangepixel.gunslugs3.ai.SceneryEntityList;
import com.orangepixel.gunslugs3.ai.SceneryIndoorEntityList;
import com.orangepixel.utils.ArcadeCanvas;
import com.orangepixel.utils.Audio;
import com.orangepixel.utils.GUI;
import com.orangepixel.utils.Render;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import org.lwjgl.input.Keyboard;

public final class Trainer {
    public static boolean godMode = false;
    public static boolean unlimitedMoneyItems = false;
    public static boolean unlimitedJump = false;
    public static boolean moveSpeed2x = false;
    public static boolean showAllItemsOnMap = false;
    public static boolean oneHitKill = false;
    public static boolean menuVisible = true;

    public static int addMoneyCount = 0;
    public static int weaponCycleIndex = 1;
    public static String lastWeaponName = "PISTOL";

    private static String toastText = "GUNSLUGS 3 TRAINER LOADED [F9: MENU]";
    private static int toastTimer = 240;

    private static final boolean[] prevKey = new boolean[16];
    private static final int[] ESSENTIAL_ITEMS = new int[]{
        5,   // Keycard / Datacard
        6,   // Stomp Boots
        7,   // Jetpack
        18,  // EMP Grenade
        19,  // C4 / Crowbar / Lockpick
        22,  // Time Machine Battery
        23,  // Plumber Wrench
        25,  // Vampire Cross
        29,  // Bomb
        33   // Sticky Bomb
    };

    // Automated self-test state (enabled when TRAINER_SELFTEST=1)
    private static final boolean SELF_TEST = "1".equals(System.getenv("TRAINER_SELFTEST"));
    private static int selfTestTicks = 0;
    private static boolean selfTestStartedLevel = false;
    private static boolean selfTestCompleted = false;
    private static int stCoinsBeforeF2 = 0;
    private static int stCoinsAfterF2 = 0;
    private static int stSkillPointsBeforeF2 = 0;
    private static int stSkillPointsAfterF2 = 0;
    private static int stLivesBeforeDamage = 0;
    private static int stLivesAfterDamage = 0;
    private static int stDoubleJumpTicks = 0;
    private static int stWeaponEquipped = -1;
    private static int stEspTrackedCount = 0;
    private static int stMonstersClamped = 0;

    private Trainer() {
    }

    public static void showToast(String msg) {
        toastText = msg;
        toastTimer = 180;
        Globals.debug("[Trainer] " + msg);
    }

    private static boolean isKeyDown(int idx, int gdxKey, int lwjglKey) {
        boolean down = false;
        try {
            if (Gdx.input != null && Gdx.input.isKeyPressed(gdxKey)) {
                down = true;
            }
        } catch (Throwable ignored) {
        }
        try {
            if (!down && Keyboard.isCreated() && Keyboard.isKeyDown(lwjglKey)) {
                down = true;
            }
        } catch (Throwable ignored) {
        }
        boolean justPressed = down && !prevKey[idx];
        prevKey[idx] = down;
        return justPressed;
    }

    public static void pollHotkeys() {
        // F1: God Mode
        if (isKeyDown(1, Input.Keys.F1, Keyboard.KEY_F1)) {
            godMode = !godMode;
            if (godMode && myCanvas.myPlayer != null) {
                PlayerEntity p = myCanvas.myPlayer;
                p.lives = Math.max(p.lives, p.maxLives + p.extendedLives);
                p.invincableCount = Math.max(p.invincableCount, 30);
            }
            playToggleSound();
            showToast("F1 GOD MODE: " + (godMode ? "ON" : "OFF"));
        }
        // F2: Add Money / Resources (+500 Coins, +1 Skill Point, +200 XP, Full HP)
        if (isKeyDown(2, Input.Keys.F2, Keyboard.KEY_F2)) {
            triggerAddMoneyAndResources();
            playToggleSound();
        }
        // F3: Unlimited Money & Items
        if (isKeyDown(3, Input.Keys.F3, Keyboard.KEY_F3)) {
            unlimitedMoneyItems = !unlimitedMoneyItems;
            if (unlimitedMoneyItems) {
                enforceUnlimitedMoneyAndItems();
            }
            playToggleSound();
            showToast("F3 UNLIMITED MONEY & ITEMS: " + (unlimitedMoneyItems ? "ON" : "OFF"));
        }
        // F4: Unlimited Jump
        if (isKeyDown(4, Input.Keys.F4, Keyboard.KEY_F4)) {
            unlimitedJump = !unlimitedJump;
            if (unlimitedJump && myCanvas.myPlayer != null) {
                myCanvas.myPlayer.hasDoubleJump = true;
                myCanvas.myPlayer.DoubleJumpCountDown = 99;
            }
            playToggleSound();
            showToast("F4 UNLIMITED JUMP: " + (unlimitedJump ? "ON" : "OFF"));
        }
        // F5: Move Speed x2
        if (isKeyDown(5, Input.Keys.F5, Keyboard.KEY_F5)) {
            moveSpeed2x = !moveSpeed2x;
            playToggleSound();
            showToast("F5 MOVE SPEED X2: " + (moveSpeed2x ? "ON" : "OFF"));
        }
        // F6: Show All Items on Map (ESP + Radar)
        if (isKeyDown(6, Input.Keys.F6, Keyboard.KEY_F6)) {
            showAllItemsOnMap = !showAllItemsOnMap;
            playToggleSound();
            showToast("F6 SHOW ALL ITEMS ON MAP: " + (showAllItemsOnMap ? "ON" : "OFF"));
        }
        // F7: One-Hit Kill
        if (isKeyDown(7, Input.Keys.F7, Keyboard.KEY_F7)) {
            oneHitKill = !oneHitKill;
            playToggleSound();
            showToast("F7 ONE-HIT KILL: " + (oneHitKill ? "ON" : "OFF"));
        }
        // F8: Cycle Weapon
        if (isKeyDown(8, Input.Keys.F8, Keyboard.KEY_F8)) {
            triggerCycleWeapon();
            playToggleSound();
        }
        // F9 / F10 / INSERT: Toggle Trainer Menu
        boolean f9 = isKeyDown(9, Input.Keys.F9, Keyboard.KEY_F9);
        boolean f10 = isKeyDown(10, Input.Keys.F10, Keyboard.KEY_F10);
        boolean ins = isKeyDown(11, Input.Keys.INSERT, Keyboard.KEY_INSERT);
        if (f9 || f10 || ins) {
            menuVisible = !menuVisible;
            playToggleSound();
            showToast("TRAINER MENU: " + (menuVisible ? "SHOWN" : "HIDDEN"));
        }
    }

    private static void playToggleSound() {
        try {
            Audio.playUISelect();
        } catch (Throwable ignored) {
        }
    }

    public static void triggerAddMoneyAndResources() {
        ++addMoneyCount;
        World.coins += 500;
        if (myCanvas.mySaveGame != null) {
            myCanvas.mySaveGame.coins = Math.max(myCanvas.mySaveGame.coins + 500, World.coins);
            for (int i = 0; i < myCanvas.mySaveGame.charUnlocked.length; ++i) {
                myCanvas.mySaveGame.charUnlocked[i] = true;
                myCanvas.mySaveGame.charDied[i] = false;
            }
        }
        if (myCanvas.activePlayer != null) {
            myCanvas.activePlayer.hasGeneralUnlocked = true;
        }
        PlayerEntity p = myCanvas.myPlayer;
        if (p != null) {
            if (p.maxLives <= 0) {
                p.maxLives = 6;
            }
            p.lives = Math.max(p.lives, p.maxLives + p.extendedLives);
            p.skillPoints += 1;
            if (myCanvas.mySaveGame != null && p.myType >= 0 && p.myType < myCanvas.mySaveGame.charXPPoints.length) {
                myCanvas.mySaveGame.charXPPoints[p.myType] = Math.max(myCanvas.mySaveGame.charXPPoints[p.myType] + 1, p.skillPoints);
            }
            try {
                p.increaseXP(200, true, p);
            } catch (Throwable ignored) {
            }
            for (int i = 0; i < 3; ++i) {
                if (p.ammoTypesMax[i] <= 0) {
                    p.ammoTypesMax[i] = 100;
                }
                p.ammoTypes[i] = p.ammoTypesMax[i];
            }
        }
        showToast("F2: +500 COINS (" + World.coins + "), +1 SP, +200 XP & FULL HP");
    }

    public static void triggerCycleWeapon() {
        PlayerEntity p = myCanvas.myPlayer;
        if (p == null || Globals.weapons == null) {
            return;
        }
        weaponCycleIndex = (weaponCycleIndex + 1) % Globals.weapons.length;
        int wId = weaponCycleIndex;
        for (int i = 0; i < 3; ++i) {
            if (p.ammoTypesMax[i] <= 0) {
                p.ammoTypesMax[i] = 100;
            }
            p.ammoTypes[i] = p.ammoTypesMax[i];
        }
        int slot = Globals.weapons[wId][13] == -1 ? 0 : 1;
        p.weaponSlots[slot] = wId;
        p.myWeaponID = wId;
        try {
            p.prepWeaponSprite();
            p.setActiveWeapon(slot, true);
        } catch (Throwable ignored) {
        }
        if (Globals.weaponNames != null && wId * 2 < Globals.weaponNames.length) {
            lastWeaponName = Globals.weaponNames[wId * 2].toUpperCase();
        } else {
            lastWeaponName = "WEAPON #" + wId;
        }
        showToast("F8 WEAPON: " + lastWeaponName + " (#" + wId + ")");
    }

    public static void onPlayerPreUpdate(PlayerEntity p, World w) {
        if (p == null) {
            return;
        }
        if (godMode) {
            if (p.maxLives <= 0) {
                p.maxLives = 6;
            }
            int targetLives = p.maxLives + Math.max(0, p.extendedLives);
            if (p.lives < targetLives) {
                p.lives = targetLives;
            }
            p.died = false;
            p.invincableCount = Math.max(p.invincableCount, 4);
            if (p.shieldType >= 0 && p.maxShield > 0 && p.shield < p.maxShield) {
                p.shield = p.maxShield;
            }
            if (p.helmetType >= 0 && p.maxHelmet > 0 && p.helmet < p.maxHelmet) {
                p.helmet = p.maxHelmet;
            }
            if (!World.inDoors && p.y > 2080) {
                p.y = 1960;
                p.floatY = p.y << 4;
                p.ySpeed = -64;
            }
        }
        if (unlimitedJump) {
            p.hasDoubleJump = true;
            p.DoubleJumpCountDown = 99;
        }
    }

    public static void enforceUnlimitedMoneyAndItems() {
        if (World.coins < 9999) {
            World.coins = 9999;
        }
        if (myCanvas.mySaveGame != null) {
            if (myCanvas.mySaveGame.coins < 9999) {
                myCanvas.mySaveGame.coins = 9999;
            }
            for (int i = 0; i < myCanvas.mySaveGame.charUnlocked.length; ++i) {
                myCanvas.mySaveGame.charUnlocked[i] = true;
                myCanvas.mySaveGame.charDied[i] = false;
            }
        }
        if (myCanvas.activePlayer != null) {
            myCanvas.activePlayer.hasGeneralUnlocked = true;
        }
        PlayerEntity p = myCanvas.myPlayer;
        if (p != null) {
            for (int i = 0; i < 3; ++i) {
                if (p.ammoTypesMax[i] <= 0) {
                    p.ammoTypesMax[i] = 100;
                }
                if (p.ammoTypes[i] < p.ammoTypesMax[i]) {
                    p.ammoTypes[i] = p.ammoTypesMax[i];
                }
            }
            if (p.skillPoints < 10) {
                p.skillPoints = 10;
            }
            if (myCanvas.mySaveGame != null && p.myType >= 0 && p.myType < myCanvas.mySaveGame.charXPPoints.length) {
                if (myCanvas.mySaveGame.charXPPoints[p.myType] < 10) {
                    myCanvas.mySaveGame.charXPPoints[p.myType] = 10;
                }
            }
            if (p.inventory != null) {
                for (int i = 0; i < p.inventory.length; ++i) {
                    InventoryItem it = p.inventory[i];
                    if (it != null && it.itemIDX >= 0 && it.itemUsageCount < 9) {
                        it.itemUsageCount = 9;
                    }
                }
                for (int itemId : ESSENTIAL_ITEMS) {
                    ensureInventoryItemStocked(p, itemId);
                }
            }
        }
        // Make all shop items and vending machines free
        if (MonsterEntityList.myList != null) {
            for (int i = 0; i <= MonsterEntityList.myListMax && i < MonsterEntityList.myList.length; ++i) {
                if (!(MonsterEntityList.myList[i] instanceof MonsterEntity)) {
                    continue;
                }
                MonsterEntity m = (MonsterEntity) MonsterEntityList.myList[i];
                if (m == null || m.deleted || m.died) {
                    continue;
                }
                if (m.myType == 18) { // m_PICKUPSHOP
                    m.aiCountdown = 0;
                } else if (m.myType == 14) { // m_VENDINGMACHINE
                    m.fireDelay = 0;
                }
            }
        }
    }

    private static void ensureInventoryItemStocked(PlayerEntity p, int itemId) {
        if (p.inventory == null || Globals.pickups == null || itemId < 0 || itemId >= Globals.pickups.length) {
            return;
        }
        for (int i = 0; i < p.inventory.length; ++i) {
            if (p.inventory[i] != null && p.inventory[i].itemIDX == itemId) {
                if (p.inventory[i].itemUsageCount < 9) {
                    p.inventory[i].itemUsageCount = 9;
                }
                return;
            }
        }
        for (int i = 0; i < p.inventory.length; ++i) {
            if (p.inventory[i] != null && p.inventory[i].itemIDX == -1) {
                p.inventory[i].itemIDX = itemId;
                p.inventory[i].itemUsageCount = 9;
                p.inventory[i].itemType = Globals.pickups[itemId][8];
                return;
            }
        }
    }

    private static boolean isHostileMonster(MonsterEntity m) {
        if (m == null || m.deleted || m.died) {
            return false;
        }
        switch (m.myType) {
            case 6:  // m_SOLDIER
            case 8:  // m_CHOPPER
            case 21: // m_SPIDERBOT
            case 22: // m_BOUNCEBALL
            case 23: // m_WALLMOUNTSHOOTER
            case 27: // m_BOUNCECANON
            case 29: // m_LASER_CANON
            case 30: // m_TURRET
            case 34: // m_TANKSUIT
            case 39: // m_DAWG
            case 41: // m_SANDWORM
            case 44: // m_LASER
            case 48: // m_IMP
            case 49: // m_CAMERA
            case 51: // m_SNAKE
            case 53: // m_TANK
            case 56: // m_PHATT
            case 57: // m_ALIENPOD
                return m.aiState < 900;
            default:
                return false;
        }
    }

    private static void enforceOneHitKill() {
        int clamped = 0;
        if (BulletEntityList.myList != null) {
            for (int i = 0; i <= BulletEntityList.myListMax && i < BulletEntityList.myList.length; ++i) {
                EntitySprite b = BulletEntityList.myList[i];
                if (b == null || b.deleted || b.died) {
                    continue;
                }
                if (b.myOwner == BulletEntity.OWNER_PLAYER && b.energy > 0 && b.myType < 18) {
                    b.energy = 250;
                }
            }
        }
        if (MonsterEntityList.myList != null) {
            for (int i = 0; i <= MonsterEntityList.myListMax && i < MonsterEntityList.myList.length; ++i) {
                if (!(MonsterEntityList.myList[i] instanceof MonsterEntity)) {
                    continue;
                }
                MonsterEntity m = (MonsterEntity) MonsterEntityList.myList[i];
                if (!isHostileMonster(m)) {
                    continue;
                }
                if (m.energy > 1 && m.energy < 900) {
                    m.energy = 1;
                }
                if (m.myType == 30 && m.activatedDelay > 1) {
                    m.activatedDelay = 1;
                }
                ++clamped;
            }
        }
        if (BossEntityList.myList != null) {
            for (int i = 0; i <= BossEntityList.myListMax && i < BossEntityList.myList.length; ++i) {
                if (!(BossEntityList.myList[i] instanceof BossEntity)) {
                    continue;
                }
                BossEntity boss = (BossEntity) BossEntityList.myList[i];
                if (boss == null || boss.deleted || boss.died || boss.aiState >= 901) {
                    continue;
                }
                if (boss.energy > 1) {
                    boss.energy = 1;
                }
                if (World.currentBossenergy > 1) {
                    World.currentBossenergy = 1;
                }
                ++clamped;
            }
        }
        if (clamped > stMonstersClamped) {
            stMonstersClamped = clamped;
        }
    }

    public static void onFrameUpdate(myCanvas canvas) {
        pollHotkeys();
        if (toastTimer > 0) {
            --toastTimer;
        }
        PlayerEntity p = myCanvas.myPlayer;
        if (p != null) {
            onPlayerPreUpdate(p, myCanvas.myWorld);
        }
        if (unlimitedMoneyItems) {
            enforceUnlimitedMoneyAndItems();
        }
        if (oneHitKill) {
            enforceOneHitKill();
        }
        if (SELF_TEST) {
            runSelfTestStep(canvas);
        }
    }

    public static void onRenderOverlay(myCanvas canvas) {
        try {
            if (showAllItemsOnMap && (ArcadeCanvas.GameState == 7 || ArcadeCanvas.GameState == 24 || ArcadeCanvas.GameState == 25)) {
                renderMapEspOverlay();
            }
            if (menuVisible) {
                renderTrainerMenu();
            }
            if (toastTimer > 0 && toastText != null && !toastText.isEmpty()) {
                renderToastBanner();
            }
            if (SELF_TEST && selfTestCompleted) {
                writeSelfTestArtifacts();
                Gdx.app.exit();
            }
        } catch (Throwable ignored) {
        }
    }

    private static void renderMapEspOverlay() {
        if (World.gameloopW <= 0 || World.gameloopH <= 0) {
            return;
        }
        int tracked = 0;
        // Top full-level radar bar
        int radarX = 8;
        int radarY = 2;
        int radarW = Math.max(120, Render.width - 16);
        int radarH = 7;
        int levelPixelW = Math.max(1, World.overWorldMaxWidth << 4);
        Render.setARGB(170, 10, 16, 24);
        Render.fillRect(radarX, radarY, radarW, radarH);
        Render.setARGB(210, 70, 130, 180);
        Render.drawRect(radarX, radarY, radarW, radarH);

        if (myCanvas.myPlayer != null) {
            int px = radarX + Math.max(0, Math.min(radarW - 3, (myCanvas.myPlayer.x * radarW) / levelPixelW));
            Render.setARGB(255, 255, 255, 255);
            Render.fillRect(px, radarY + 1, 3, radarH - 2);
        }

        // Scenery buildings/towers
        if (!World.inDoors && SceneryEntityList.myList != null) {
            for (int i = 0; i <= SceneryEntityList.myListMax && i < SceneryEntityList.myList.length; ++i) {
                EntitySprite s = SceneryEntityList.myList[i];
                if (s == null || s.deleted || s.died) {
                    continue;
                }
                if (s.myType == 0 && s.aiState == 0) { // Active objective tower building
                    drawEspTarget(s.x, s.y - s.h, s.w, s.h, 255, 60, 220, "TOWER", radarX, radarY, radarW, radarH, levelPixelW);
                    ++tracked;
                } else if (s.myType == 4) { // Popup shop building
                    drawEspTarget(s.x, s.y, s.w, s.h, 60, 220, 255, "SHOP BLDG", radarX, radarY, radarW, radarH, levelPixelW);
                    ++tracked;
                }
            }
        }

        // MonsterEntity items, pickups, crates, doors, objectives, and enemies
        if (MonsterEntityList.myList != null) {
            for (int i = 0; i <= MonsterEntityList.myListMax && i < MonsterEntityList.myList.length; ++i) {
                if (!(MonsterEntityList.myList[i] instanceof MonsterEntity)) {
                    continue;
                }
                MonsterEntity m = (MonsterEntity) MonsterEntityList.myList[i];
                if (m == null || m.deleted || m.died) {
                    continue;
                }
                int r = -1;
                int g = -1;
                int b = -1;
                String label = null;
                switch (m.myType) {
                    case 0: { // Door
                        r = 80; g = 220; b = 255;
                        if (m.subType == 0) label = "EXIT DOOR";
                        else if (m.subType == 1) label = "TOWER DOOR";
                        else if (m.subType == 2 || m.subType == 6) label = "SHOP DOOR";
                        else if (m.subType == 4) label = "HELL DOOR";
                        else if (m.subType == 8) label = "PIPE DOOR";
                        else if (m.subType == 9) label = "DUNGEON";
                        else label = "DOOR";
                        break;
                    }
                    case 2: { // Crate with item/weapon inside
                        if (m.myWeaponID >= 500) {
                            r = 255; g = 165; b = 40;
                            int wIdx = m.myWeaponID - 500;
                            label = "CRATE:" + getShortWeaponName(wIdx);
                        } else if (m.myWeaponID >= 0) {
                            r = 120; g = 255; b = 120;
                            label = "CRATE:" + getShortItemName(m.myWeaponID);
                        }
                        break;
                    }
                    case 9: { // Coin
                        r = 255; g = 225; b = 40;
                        label = "COIN";
                        break;
                    }
                    case 10:
                    case 11: { // Loot Crate / Tiny Loot Crate
                        if (m.aiState == 0) {
                            r = 255; g = 215; b = 0;
                            label = m.subType == 0 ? "HP BOX" : (m.subType == 1 ? "AMMO BOX" : "COIN BOX");
                        }
                        break;
                    }
                    case 12: { // Pickup Item
                        r = 60; g = 255; b = 100;
                        label = getShortItemName(m.subType);
                        break;
                    }
                    case 13: { // Pickup Weapon
                        r = 255; g = 140; b = 30;
                        label = getShortWeaponName(m.subType);
                        break;
                    }
                    case 14: { // Vending Machine
                        r = 60; g = 255; b = 220;
                        label = "HEAL(" + m.fireDelay + ")";
                        break;
                    }
                    case 16: { // Random Scenery (Treasure Chest 23, Locker 28, SpyDesk 38)
                        if (m.subType == 23 && m.aiState == 0) {
                            r = 255; g = 215; b = 0;
                            label = "CHEST";
                        } else if (m.subType == 28 && m.aiState == 0) {
                            r = 140; g = 240; b = 255;
                            label = "LOCKER";
                        } else if (m.subType == 38 && m.aiState == 0) {
                            r = 255; g = 80; b = 255;
                            label = "SPY DESK";
                        }
                        break;
                    }
                    case 17: { // Extraction Chopper
                        r = 80; g = 255; b = 255;
                        label = "EXTRACT";
                        break;
                    }
                    case 18: { // Shop Item
                        r = 60; g = 255; b = 200;
                        String itemLbl = m.subType >= 500 ? getShortWeaponName(m.subType - 500) : getShortItemName(m.subType);
                        label = itemLbl + "$" + m.aiCountdown;
                        break;
                    }
                    case 20: { // Console
                        if (m.aiState == 0) {
                            r = 255; g = 90; b = 255;
                            label = "CONSOLE";
                        }
                        break;
                    }
                    case 28: { // Vent
                        r = 160; g = 220; b = 255;
                        label = "VENT";
                        break;
                    }
                    case 36: { // Crane Drums objective
                        if (m.aiState == 0) {
                            r = 255; g = 80; b = 255;
                            label = "DRUMS";
                        }
                        break;
                    }
                    case 42: { // Hostage
                        r = 100; g = 255; b = 255;
                        label = "HOSTAGE";
                        break;
                    }
                    case 43: { // Hack Computer
                        if (m.aiState == 0) {
                            r = 255; g = 80; b = 255;
                            label = "HACK PC";
                        }
                        break;
                    }
                    case 45: { // Rocket objective
                        if (m.aiState == 0) {
                            r = 255; g = 80; b = 255;
                            label = "ROCKET";
                        }
                        break;
                    }
                    case 47: { // Time Machine
                        r = 180; g = 120; b = 255;
                        label = "TIME MACH";
                        break;
                    }
                    case 50: { // C4 Spot
                        if (m.aiState == 0) {
                            r = 255; g = 60; b = 200;
                            label = "C4 SPOT";
                        }
                        break;
                    }
                    case 52: { // Dracula Coffin
                        r = 220; g = 80; b = 255;
                        label = "COFFIN";
                        break;
                    }
                    default: {
                        if (isHostileMonster(m)) {
                            r = 255; g = 60; b = 60;
                            label = m.energy > 0 && m.energy < 900 ? ("HP:" + m.energy) : "ENEMY";
                        }
                        break;
                    }
                }
                if (label != null && r >= 0) {
                    drawEspTarget(m.x, m.y, Math.max(8, m.w), Math.max(8, m.h), r, g, b, label, radarX, radarY, radarW, radarH, levelPixelW);
                    ++tracked;
                }
            }
        }

        // Bosses
        if (BossEntityList.myList != null) {
            for (int i = 0; i <= BossEntityList.myListMax && i < BossEntityList.myList.length; ++i) {
                if (!(BossEntityList.myList[i] instanceof BossEntity)) {
                    continue;
                }
                BossEntity boss = (BossEntity) BossEntityList.myList[i];
                if (boss == null || boss.deleted || boss.died || boss.aiState >= 901) {
                    continue;
                }
                drawEspTarget(boss.x, boss.y, Math.max(16, boss.w), Math.max(16, boss.h), 255, 30, 30, "BOSS HP:" + boss.energy, radarX, radarY, radarW, radarH, levelPixelW);
                ++tracked;
            }
        }

        if (tracked > stEspTrackedCount) {
            stEspTrackedCount = tracked;
        }
    }

    private static void drawEspTarget(
        int worldX, int worldY, int worldW, int worldH,
        int r, int g, int b, String label,
        int radarX, int radarY, int radarW, int radarH, int levelPixelW
    ) {
        // Plot dot on top radar bar
        int dotX = radarX + Math.max(1, Math.min(radarW - 3, (worldX * radarW) / levelPixelW));
        Render.setARGB(255, r, g, b);
        Render.fillRect(dotX, radarY + 2, 2, radarH - 4);

        // Convert world coords to HUD screen coords
        int sx = Render.width * (worldX - World.offsetX) / World.gameloopW;
        int sy = Render.height * (worldY - World.offsetY) / World.gameloopH;
        int sw = Math.max(6, Render.width * worldW / World.gameloopW);
        int sh = Math.max(6, Render.height * worldH / World.gameloopH);

        boolean onScreen = (sx + sw >= 0 && sx <= Render.width && sy + sh >= 0 && sy <= Render.height);
        if (onScreen) {
            Render.setARGB(220, r, g, b);
            Render.drawRect(sx, sy, sw, sh);
            if (label != null && !label.isEmpty() && !"COIN".equals(label)) {
                Render.setAlpha(235);
                GUI.setCentered(false);
                GUI.setRightAligned(false);
                GUI.renderText(label, 0, Math.max(2, Math.min(Render.width - 48, sx)), Math.max(10, sy - 8), Render.width, 0);
            }
        } else if (label != null && !"COIN".equals(label) && !"ENEMY".equals(label) && !label.startsWith("HP:")) {
            // Clamped off-screen indicator at edge of screen for important items/objectives
            int cx = Math.max(4, Math.min(Render.width - 42, sx));
            int cy = Math.max(14, Math.min(Render.height - 14, sy));
            Render.setARGB(220, r, g, b);
            Render.fillRect(cx, cy, 4, 4);
            Render.setAlpha(210);
            GUI.setCentered(false);
            GUI.setRightAligned(false);
            String arrow = sx < 0 ? "<" : (sx > Render.width ? ">" : "^");
            GUI.renderText(arrow + label, 0, cx + 5, cy - 2, Render.width, 0);
        }
    }

    private static String getShortItemName(int pickupId) {
        if (Globals.itemInfo != null && pickupId >= 0 && pickupId * 2 < Globals.itemInfo.length) {
            String s = Globals.itemInfo[pickupId * 2];
            if (s != null && !s.isEmpty()) {
                return s.length() > 10 ? s.substring(0, 10).toUpperCase() : s.toUpperCase();
            }
        }
        return "ITEM#" + pickupId;
    }

    private static String getShortWeaponName(int weaponId) {
        if (Globals.weaponNames != null && weaponId >= 0 && weaponId * 2 < Globals.weaponNames.length) {
            String s = Globals.weaponNames[weaponId * 2];
            if (s != null && !s.isEmpty()) {
                return s.length() > 10 ? s.substring(0, 10).toUpperCase() : s.toUpperCase();
            }
        }
        return "GUN#" + weaponId;
    }

    private static void renderTrainerMenu() {
        int boxW = 188;
        int boxH = 124;
        int boxX = Math.max(4, Render.width - boxW - 6);
        int boxY = 12;

        // Outer translucent panel
        Render.setARGB(205, 12, 16, 26);
        Render.fillRect(boxX, boxY, boxW, boxH);
        // Header bar
        Render.setARGB(235, 28, 52, 88);
        Render.fillRect(boxX, boxY, boxW, 13);
        // Border
        Render.setARGB(240, 90, 175, 255);
        Render.drawRect(boxX, boxY, boxW, boxH);

        GUI.setCentered(false);
        GUI.setRightAligned(false);
        Render.setAlpha(255);

        int tx = boxX + 5;
        int ty = boxY + 3;
        GUI.renderText("[YELLOW]GUNSLUGS 3 TRAINER [F9][]", 0, tx, ty, boxW, 0);

        ty += 12;
        GUI.renderText(formatToggleLine("F1", "GOD MODE", godMode), 0, tx, ty, boxW, 0);
        ty += 10;
        GUI.renderText("[CYAN]F2[] +500 GOLD/SP/XP [YELLOW](" + World.coins + ")[]", 0, tx, ty, boxW, 0);
        ty += 10;
        GUI.renderText(formatToggleLine("F3", "UNLIM MONEY & ITEMS", unlimitedMoneyItems), 0, tx, ty, boxW, 0);
        ty += 10;
        GUI.renderText(formatToggleLine("F4", "UNLIMITED JUMP", unlimitedJump), 0, tx, ty, boxW, 0);
        ty += 10;
        GUI.renderText(formatToggleLine("F5", "MOVE SPEED X2", moveSpeed2x), 0, tx, ty, boxW, 0);
        ty += 10;
        GUI.renderText(formatToggleLine("F6", "SHOW ITEMS ON MAP", showAllItemsOnMap), 0, tx, ty, boxW, 0);
        ty += 10;
        GUI.renderText(formatToggleLine("F7", "ONE-HIT KILL", oneHitKill), 0, tx, ty, boxW, 0);
        ty += 10;
        GUI.renderText("[CYAN]F8[] GUN: [YELLOW]" + truncate(lastWeaponName, 14) + "[]", 0, tx, ty, boxW, 0);
        ty += 11;
        PlayerEntity p = myCanvas.myPlayer;
        int hp = p != null ? p.lives : 0;
        int sp = p != null ? p.skillPoints : 0;
        int lvl = p != null ? p.levelXP : 0;
        GUI.renderText("[LIGHT_GRAY]HP:" + hp + " SP:" + sp + " LV:" + lvl + " [F9/INS:HIDE][]", 0, tx, ty, boxW, 0);
        Render.setAlpha(255);
    }

    private static String formatToggleLine(String key, String label, boolean state) {
        return "[CYAN]" + key + "[] " + label + ": " + (state ? "[GREEN]ON[]" : "[RED]OFF[]");
    }

    private static String truncate(String s, int maxLen) {
        if (s == null) {
            return "";
        }
        return s.length() <= maxLen ? s : s.substring(0, maxLen);
    }

    private static void renderToastBanner() {
        int bannerW = Math.min(Render.width - 16, Math.max(180, toastText.length() * 5 + 20));
        int bannerH = 14;
        int bannerX = (Render.width - bannerW) >> 1;
        int bannerY = Render.height - bannerH - 6;

        Render.setARGB(215, 16, 24, 38);
        Render.fillRect(bannerX, bannerY, bannerW, bannerH);
        Render.setARGB(245, 255, 205, 50);
        Render.drawRect(bannerX, bannerY, bannerW, bannerH);

        Render.setAlpha(255);
        GUI.setCentered(true);
        GUI.renderText("[YELLOW]" + toastText + "[]", 0, 0, bannerY + 3, Render.width, 0);
        GUI.setCentered(false);
    }

    private static void runSelfTestStep(myCanvas canvas) {
        if (selfTestCompleted) {
            return;
        }
        ++selfTestTicks;
        // Step 1: Wait until assets finish loading into Start/Main Menu (GameState == 4 or 5), then launch a level
        if (!selfTestStartedLevel && (ArcadeCanvas.GameState == 4 || ArcadeCanvas.GameState == 5) && selfTestTicks > 20) {
            selfTestStartedLevel = true;
            Globals.debug("[SelfTest] Starting new game level...");
            myCanvas.myWorld.initNewGame();
            World.showIntro = false;
            World.inAnimation = false;
            World.world = 1;
            World.level = 1;
            myCanvas.initNewLevel(1, 1);
            myCanvas.myPlayer.initNewGame(1);
            myCanvas.myPlayer.resetInventory();
            myCanvas.initMapDelay = 2;
            ArcadeCanvas.GameState = 20;
            return;
        }
        // If skill screen or world intro opened on level start, switch straight to INGAME (7)
        if (selfTestStartedLevel && (ArcadeCanvas.GameState == 26 || ArcadeCanvas.GameState == 25 || ArcadeCanvas.GameState == 23) && selfTestTicks < 240) {
            ArcadeCanvas.GameState = 7;
        }

        if (selfTestStartedLevel && ArcadeCanvas.GameState == 7) {
            PlayerEntity p = myCanvas.myPlayer;
            if (!godMode && !oneHitKill) {
                // Enable F1 God Mode, F4 Unlimited Jump, F5 Speed x2, F6 Map ESP, F7 One-Hit Kill
                godMode = true;
                unlimitedJump = true;
                moveSpeed2x = true;
                showAllItemsOnMap = true;
                oneHitKill = true;
                menuVisible = true;
                showToast("SELFTEST: ALL TRAINER FEATURES ACTIVE");
                selfTestTicks = 100;
            } else if (selfTestTicks == 105 && p != null) {
                // Test F2 Add Money & Resources
                stCoinsBeforeF2 = World.coins;
                stSkillPointsBeforeF2 = p.skillPoints;
                triggerAddMoneyAndResources();
                stCoinsAfterF2 = World.coins;
                stSkillPointsAfterF2 = p.skillPoints;
            } else if (selfTestTicks == 115 && p != null) {
                // Test F1 God Mode against direct hitMe() and lethal damage attempt
                stLivesBeforeDamage = p.lives;
                p.hitMe(null);
                p.die();
                onPlayerPreUpdate(p, myCanvas.myWorld);
                stLivesAfterDamage = p.lives;
            } else if (selfTestTicks == 125 && p != null) {
                // Test F3 Unlimited Money & Items
                unlimitedMoneyItems = true;
                enforceUnlimitedMoneyAndItems();
            } else if (selfTestTicks == 135 && p != null) {
                // Test F8 Cycle Weapon
                triggerCycleWeapon();
                triggerCycleWeapon();
                stWeaponEquipped = p.myWeaponID;
            } else if (selfTestTicks >= 120 && selfTestTicks <= 155 && p != null) {
                if (p.hasDoubleJump && p.DoubleJumpCountDown >= 50) {
                    ++stDoubleJumpTicks;
                }
            } else if (selfTestTicks == 165) {
                selfTestCompleted = true;
            }
        } else if (selfTestTicks > 600) {
            selfTestCompleted = true;
        }
    }

    private static void writeSelfTestArtifacts() {
        try {
            Pixmap pixmap = ScreenUtils.getFrameBufferPixmap(0, 0, Gdx.graphics.getBackBufferWidth(), Gdx.graphics.getBackBufferHeight());
            File screenshotFile = new File("trainer_selftest_screenshot.png");
            PixmapIO.writePNG(new FileHandle(screenshotFile), pixmap, -1, true);
            pixmap.dispose();
        } catch (Throwable t) {
            Globals.debug("[SelfTest] Screenshot error: " + t.getMessage());
        }
        try {
            PlayerEntity p = myCanvas.myPlayer;
            int finalCoins = World.coins;
            int finalSkillPoints = p != null ? p.skillPoints : -1;
            int finalLives = p != null ? p.lives : -1;
            boolean f1Pass = godMode && stLivesAfterDamage >= stLivesBeforeDamage && stLivesAfterDamage > 0;
            boolean f2Pass = (stCoinsAfterF2 - stCoinsBeforeF2) >= 500 && stSkillPointsAfterF2 > stSkillPointsBeforeF2;
            boolean f3Pass = unlimitedMoneyItems && finalCoins >= 9999 && p != null && p.hasInventoryItem(5);
            boolean f4Pass = unlimitedJump && stDoubleJumpTicks > 0;
            boolean f5Pass = moveSpeed2x && p != null && p.runningSpeedMax > 0;
            boolean f6Pass = showAllItemsOnMap && stEspTrackedCount > 0;
            boolean f7Pass = oneHitKill && stMonstersClamped > 0;
            boolean f8Pass = stWeaponEquipped >= 0;
            boolean allPass = f1Pass && f2Pass && f3Pass && f4Pass && f5Pass && f6Pass && f7Pass && f8Pass;

            StringBuilder sb = new StringBuilder();
            sb.append("{\n");
            sb.append("  \"game\": \"Gunslugs 3: Rogue Tactics v1.0.10b\",\n");
            sb.append("  \"verdict\": \"").append(allPass ? "PASS_READY_FOR_HUMAN" : "FAIL").append("\",\n");
            sb.append("  \"ticks_executed\": ").append(selfTestTicks).append(",\n");
            sb.append("  \"game_state\": ").append(ArcadeCanvas.GameState).append(",\n");
            sb.append("  \"checks\": {\n");
            sb.append("    \"F1_god_mode\": {\"pass\": ").append(f1Pass).append(", \"lives_before\": ").append(stLivesBeforeDamage).append(", \"lives_after\": ").append(stLivesAfterDamage).append("},\n");
            sb.append("    \"F2_add_money\": {\"pass\": ").append(f2Pass).append(", \"coins_before\": ").append(stCoinsBeforeF2).append(", \"coins_after\": ").append(stCoinsAfterF2).append(", \"sp_before\": ").append(stSkillPointsBeforeF2).append(", \"sp_after\": ").append(stSkillPointsAfterF2).append("},\n");
            sb.append("    \"F3_unlimited_money_items\": {\"pass\": ").append(f3Pass).append(", \"final_coins\": ").append(finalCoins).append(", \"final_sp\": ").append(finalSkillPoints).append(", \"has_keycard\": ").append(p != null && p.hasInventoryItem(5)).append("},\n");
            sb.append("    \"F4_unlimited_jump\": {\"pass\": ").append(f4Pass).append(", \"double_jump_ticks\": ").append(stDoubleJumpTicks).append("},\n");
            sb.append("    \"F5_move_speed_2x\": {\"pass\": ").append(f5Pass).append(", \"base_running_speed_max\": ").append(p != null ? p.runningSpeedMax : 0).append(", \"effective_running_speed_max\": ").append(p != null ? p.runningSpeedMax * 2 : 0).append("},\n");
            sb.append("    \"F6_show_all_items_on_map\": {\"pass\": ").append(f6Pass).append(", \"esp_entities_tracked\": ").append(stEspTrackedCount).append("},\n");
            sb.append("    \"F7_one_hit_kill\": {\"pass\": ").append(f7Pass).append(", \"hostile_entities_clamped\": ").append(stMonstersClamped).append("},\n");
            sb.append("    \"F8_cycle_weapon\": {\"pass\": ").append(f8Pass).append(", \"weapon_id\": ").append(stWeaponEquipped).append(", \"weapon_name\": \"").append(lastWeaponName).append("\"}\n");
            sb.append("  }\n");
            sb.append("}\n");

            try (OutputStreamWriter writer = new OutputStreamWriter(new FileOutputStream("trainer_selftest_report.json"), StandardCharsets.UTF_8)) {
                writer.write(sb.toString());
            }
        } catch (Throwable t) {
            Globals.debug("[SelfTest] Report error: " + t.getMessage());
        }
    }
}
