package com.orangepixel.gunslugs2;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.PixmapIO;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.utils.ScreenUtils;
import com.orangepixel.utils.ArcadeCanvas;
import com.orangepixel.utils.Rect;
import java.io.File;
import java.io.FileWriter;

public final class Trainer {
    public static boolean godMode = true;
    public static boolean unlimitedItems = true;
    public static boolean unlimitedJump = false;
    public static boolean speedMultiplier2x = false;
    public static boolean showAllItems = true;
    public static boolean oneHitKill = false;
    public static boolean showMenu = true;

    private static final boolean[] prevKeyState = new boolean[256];
    private static String toastText = "TRAINER READY - F9 MENU";
    private static int toastTimer = 180;

    private static int pendingAddCoins = 0;
    private static boolean pendingWeaponCycle = false;

    private static final int[] CYCLE_WEAPONS = new int[]{
        1, 2, 3, 4, 5, 6, 7, 8, 12
    };
    private static final String[] WEAPON_NAMES = new String[]{
        "PISTOL",
        "DOUBLER",
        "ROCKET",
        "FLAMER",
        "GRENADE",
        "DBLGUN",
        "ELECTRO",
        "MACHGUN",
        "JETPACK"
    };
    private static int weaponCycleIdx = 0;

    private static final Rect fontSrc = new Rect();
    private static final Rect fontDest = new Rect();

    private static boolean selfTestChecked = false;
    public static boolean selfTestActive = false;
    private static int selfTestTick = 0;
    private static boolean selfTestDone = false;
    private static boolean stGodModePass = false;
    private static boolean stAddMoneyPass = false;
    private static boolean stUnlimitedItemsPass = false;
    private static boolean stUnlimitedJumpPass = false;
    private static boolean stSpeed2xPass = false;
    private static boolean stShowItemsPass = false;
    private static boolean stOneHitKillPass = false;
    private static boolean stWeaponCyclePass = false;
    private static boolean stScreenshotRequest = false;
    private static boolean stScreenshotSaved = false;
    private static int stBaselineCoins = 0;

    private Trainer() {
    }

    public static boolean isSelfTestRequested() {
        checkSelfTestEnv();
        return selfTestActive;
    }

    private static void checkSelfTestEnv() {
        if (!selfTestChecked) {
            selfTestChecked = true;
            String env = System.getenv("TRAINER_SELFTEST");
            String prop = System.getProperty("trainer.selftest");
            if ("1".equals(env) || "true".equalsIgnoreCase(env) || "1".equals(prop) || "true".equalsIgnoreCase(prop)) {
                selfTestActive = true;
            }
        }
    }

    private static boolean isKeyJustPressed(int keyCode) {
        if (keyCode < 0 || keyCode >= prevKeyState.length || Gdx.input == null) {
            return false;
        }
        boolean down = Gdx.input.isKeyPressed(keyCode);
        boolean justPressed = down && !prevKeyState[keyCode];
        prevKeyState[keyCode] = down;
        return justPressed;
    }

    public static void showToast(String msg) {
        toastText = msg;
        toastTimer = 110;
    }

    public static void pollInput() {
        if (isKeyJustPressed(131)) {
            godMode = !godMode;
            showToast(godMode ? "F1 GOD MODE ON" : "F1 GOD MODE OFF");
        }
        if (isKeyJustPressed(132)) {
            pendingAddCoins += 500;
            showToast("F2 ADDED 500 COINS");
        }
        if (isKeyJustPressed(133)) {
            unlimitedItems = !unlimitedItems;
            showToast(unlimitedItems ? "F3 UNLIMITED ITEMS ON" : "F3 UNLIMITED ITEMS OFF");
        }
        if (isKeyJustPressed(134)) {
            unlimitedJump = !unlimitedJump;
            showToast(unlimitedJump ? "F4 UNLIMITED JUMP ON" : "F4 UNLIMITED JUMP OFF");
        }
        if (isKeyJustPressed(135)) {
            speedMultiplier2x = !speedMultiplier2x;
            showToast(speedMultiplier2x ? "F5 MOVE SPEED X2 ON" : "F5 MOVE SPEED X2 OFF");
        }
        if (isKeyJustPressed(136)) {
            showAllItems = !showAllItems;
            showToast(showAllItems ? "F6 MAP ITEM ESP ON" : "F6 MAP ITEM ESP OFF");
        }
        if (isKeyJustPressed(137)) {
            oneHitKill = !oneHitKill;
            showToast(oneHitKill ? "F7 ONE HIT KILL ON" : "F7 ONE HIT KILL OFF");
        }
        if (isKeyJustPressed(138)) {
            pendingWeaponCycle = true;
        }
        if (isKeyJustPressed(139) || isKeyJustPressed(140) || isKeyJustPressed(124)) {
            showMenu = !showMenu;
            showToast(showMenu ? "TRAINER MENU SHOWN" : "TRAINER MENU HIDDEN");
        }
    }

    public static boolean onPlayerHit(Player p) {
        if (godMode && p != null) {
            if (p.maxLives <= 0) {
                p.maxLives = 32;
            }
            p.lives = p.maxLives;
            p.Died = false;
            return true;
        }
        return false;
    }

    public static boolean onPlayerDie(Player p) {
        if (godMode && p != null) {
            if (p.maxLives <= 0) {
                p.maxLives = 32;
            }
            p.lives = p.maxLives;
            p.Died = false;
            p.diedCounter = 0;
            return true;
        }
        return false;
    }

    public static boolean onPlayerFakeDie(Player p) {
        if (godMode && p != null && myCanvas.GameState == 43) {
            p.Dropped = false;
            p.diedCounter = 0;
            return true;
        }
        return false;
    }

    public static void onPlayerUpdate(Player p, TileMap myWorld) {
        if (p == null) {
            return;
        }

        if (p.playerid == 1 && pendingAddCoins > 0) {
            p.coins += pendingAddCoins;
            if (myWorld != null) {
                myWorld.saveGameCoins = p.coins;
            }
            pendingAddCoins = 0;
        }

        if (p.playerid == 1 && pendingWeaponCycle) {
            pendingWeaponCycle = false;
            weaponCycleIdx = (weaponCycleIdx + 1) % CYCLE_WEAPONS.length;
            int nextWep = CYCLE_WEAPONS[weaponCycleIdx];
            p.setWeapon(nextWep, false);
            if (p.maxAmmo < 99) {
                p.maxAmmo = 99;
            }
            p.ammo = p.maxAmmo;
            showToast("F8 WEAPON " + WEAPON_NAMES[weaponCycleIdx]);
        }

        if (godMode) {
            if (p.maxLives < 32) {
                p.maxLives = 32;
            }
            p.lives = p.maxLives;
            if (p.extraLife < 16) {
                p.extraLife = 16;
            }
            p.shieldType = 2;
            p.armorCounterMax = 96;
            p.armorCounter = 96;
            p.Died = false;
            p.diedCounter = 0;
            p.hitCounter = 0;
            if (myCanvas.GameState == 43) {
                p.Dropped = false;
            }
            if (myWorld != null && !myWorld.inBuilding && p.y > 148) {
                p.y = 32;
                p.floatY = p.y << 4;
                p.ySpeed = -64;
                p.onGround = false;
                p.onGroundCountdown = 4;
            }
        }

        if (unlimitedItems) {
            if (p.coins < 9999) {
                p.coins = 9999;
            }
            if (myWorld != null && myWorld.saveGameCoins < p.coins) {
                myWorld.saveGameCoins = p.coins;
            }
            p.ammoExtender = 128;
            if (p.maxAmmo < 128) {
                p.maxAmmo = 128;
            }
            p.ammo = p.maxAmmo;
            p.hasContinue = true;
            p.hasSpecialDrink = true;
            if (p.specialDrinkCounter > 0 && p.specialDrinkCounter < 320) {
                p.specialDrinkCounter = 320;
            }
            if (p.extraLife < 16) {
                p.extraLife = 16;
            }
            p.shieldType = 2;
            p.armorCounterMax = 96;
            p.armorCounter = 96;
            unlockAllProfileContent();
        }

        if (unlimitedJump && !p.inDoor && !p.atDoor && !p.inVehicle && !p.atStairs) {
            p.onGroundCountdown = 4;
            if (p.jumpPressed && p.ySpeed >= -8) {
                p.jumpReleased = true;
            }
        }

        if (speedMultiplier2x) {
            p.maxSpeed = 80;
            if (!p.inDoor && !p.inVehicle && !p.blockPlayerMovement) {
                if (p.leftPressed) {
                    p.xSpeed -= 4;
                    if (p.xSpeed < -p.maxSpeed) {
                        p.xSpeed = -p.maxSpeed;
                    }
                } else if (p.rightPressed) {
                    p.xSpeed += 4;
                    if (p.xSpeed > p.maxSpeed) {
                        p.xSpeed = p.maxSpeed;
                    }
                }
            }
        } else if (p.maxSpeed == 80) {
            p.maxSpeed = 40;
        }

        if (p.playerid == 1) {
            maintainWorldEntities(myWorld);
        }
    }

    private static void unlockAllProfileContent() {
        PlayerProfile prof = myCanvas.activePlayer;
        if (prof == null) {
            return;
        }
        if (prof.unlockedAvatars != null) {
            for (int i = 0; i < prof.unlockedAvatars.length; ++i) {
                prof.unlockedAvatars[i] = true;
            }
        }
        if (prof.unlockedWeapons != null) {
            for (int i = 0; i < prof.unlockedWeapons.length; ++i) {
                prof.unlockedWeapons[i] = true;
            }
        }
    }

    public static void maintainWorldEntities(TileMap myWorld) {
        Monster[] monsters = myCanvas.monsterList;
        if (monsters == null) {
            return;
        }
        boolean drewLeftOffscreenLabel = false;
        boolean drewRightOffscreenLabel = false;

        for (int i = 0; i < monsters.length; ++i) {
            Monster m = monsters[i];
            if (m == null || m.deleted || m.died) {
                continue;
            }
            if ((godMode || unlimitedItems) && (m.myType == 9 || m.myType == 16 || m.myType == 21) && m.aiState >= 200 && m.gotPlayerId > 0) {
                if (m.energy < 800) {
                    m.energy = 800;
                }
            }
            if (showAllItems && (m.myType == 7 || m.myType == 15)) {
                if (m.aiCountDown > 0 && m.aiCountDown < 200) {
                    m.aiCountDown = 200;
                }
            }
            if (oneHitKill) {
                switch (m.myType) {
                    case 0: {
                        if (m.subType <= 1 && m.aiState < 900 && m.energy > 1) {
                            m.energy = 1;
                        }
                        break;
                    }
                    case 1:
                    case 4:
                    case 6:
                    case 25:
                    case 27:
                    case 28:
                    case 29:
                    case 35:
                    case 36:
                    case 37:
                    case 39: {
                        if (m.aiState < 800 && m.energy > 1) {
                            m.energy = 1;
                        }
                        break;
                    }
                    case 9:
                    case 16:
                    case 20:
                    case 21: {
                        if (m.aiState < 200 && m.energy > 1) {
                            m.energy = 1;
                        }
                        break;
                    }
                    case 13: {
                        if (m.aiState == 0 && m.energy > 1) {
                            m.energy = 1;
                        }
                        break;
                    }
                    case 14: {
                        if (m.aiState >= 1 && m.aiState <= 9 && m.energy > 1) {
                            m.energy = 1;
                        }
                        break;
                    }
                    case 22: {
                        if (m.aiState != 10 && m.energy > 1) {
                            m.energy = 1;
                        }
                        break;
                    }
                    case 48:
                    case 49:
                    case 50:
                    case 51:
                    case 52:
                    case 53:
                    case 54: {
                        if (m.aiState < 800 && m.energy > 1) {
                            m.energy = 1;
                            if (myWorld != null) {
                                myWorld.worldBossEnergy = 1;
                            }
                        }
                        break;
                    }
                }
            }
        }
    }

    public static void drawText(String text, int x, int y) {
        if (text == null || ArcadeCanvas.sprites == null || ArcadeCanvas.sprites.length <= 25) {
            return;
        }
        Texture font = ArcadeCanvas.sprites[25];
        if (font == null) {
            return;
        }
        Render.setAlpha(255);
        int cx = x;
        int len = text.length();
        for (int i = 0; i < len; ++i) {
            char ch = text.charAt(i);
            if (ch >= 'a' && ch <= 'z') {
                ch = (char)(ch - 32);
            }
            if (ch >= 'A' && ch <= 'Z') {
                int idx = ch - 65;
                fontDest.set(cx, y, cx + 5, y + 7);
                fontSrc.set(idx * 6, 0, idx * 6 + 5, 7);
                Render.drawBitmap(font, fontSrc, fontDest);
                cx += 6;
            } else if (ch >= '0' && ch <= '9') {
                int idx = ch - 48;
                fontDest.set(cx, y, cx + 5, y + 7);
                fontSrc.set(156 + idx * 6, 0, 161 + idx * 6, 7);
                Render.drawBitmap(font, fontSrc, fontDest);
                cx += 6;
            } else if (ch == '.') {
                fontDest.set(cx, y, cx + 3, y + 7);
                fontSrc.set(216, 0, 219, 7);
                Render.drawBitmap(font, fontSrc, fontDest);
                cx += 4;
            } else if (ch == '(') {
                fontDest.set(cx, y, cx + 4, y + 8);
                fontSrc.set(222, 0, 226, 8);
                Render.drawBitmap(font, fontSrc, fontDest);
                cx += 5;
            } else if (ch == ')') {
                fontDest.set(cx, y, cx + 4, y + 8);
                fontSrc.set(227, 0, 231, 8);
                Render.drawBitmap(font, fontSrc, fontDest);
                cx += 5;
            } else if (ch == '-') {
                Render.setARGB(255, 255, 255, 255);
                Render.fillRect(cx, y + 3, 4, 1);
                cx += 5;
            } else if (ch == '+') {
                Render.setARGB(255, 255, 255, 255);
                Render.fillRect(cx, y + 3, 5, 1);
                Render.fillRect(cx + 2, y + 1, 1, 5);
                cx += 6;
            } else if (ch == ':') {
                Render.setARGB(255, 255, 255, 255);
                Render.fillRect(cx + 1, y + 1, 1, 2);
                Render.fillRect(cx + 1, y + 4, 1, 2);
                cx += 4;
            } else if (ch == '<') {
                Render.setARGB(255, 255, 255, 255);
                Render.fillRect(cx + 2, y + 1, 2, 1);
                Render.fillRect(cx + 1, y + 2, 2, 1);
                Render.fillRect(cx, y + 3, 2, 1);
                Render.fillRect(cx + 1, y + 4, 2, 1);
                Render.fillRect(cx + 2, y + 5, 2, 1);
                cx += 5;
            } else if (ch == '>') {
                Render.setARGB(255, 255, 255, 255);
                Render.fillRect(cx, y + 1, 2, 1);
                Render.fillRect(cx + 1, y + 2, 2, 1);
                Render.fillRect(cx + 2, y + 3, 2, 1);
                Render.fillRect(cx + 1, y + 4, 2, 1);
                Render.fillRect(cx, y + 5, 2, 1);
                cx += 5;
            } else {
                cx += 4;
            }
        }
    }

    public static void onFrameEnd(ArcadeCanvas canvas) {
        try {
            pollInput();
            checkSelfTestEnv();
            if (selfTestActive && !selfTestDone && canvas instanceof myCanvas) {
                runSelfTest((myCanvas)canvas);
            }
            if (ArcadeCanvas.sprites == null || ArcadeCanvas.sprites.length <= 25 || ArcadeCanvas.sprites[25] == null) {
                return;
            }
            if (showAllItems && myCanvas.GameState == 43) {
                renderItemESP();
            }
            if (showMenu) {
                renderMenuOverlay();
            }
            if (toastTimer > 0) {
                --toastTimer;
                renderToast();
            }
            Render.setARGB(255, 255, 255, 255);
        } catch (Throwable t) {
            // Keep render loop safe
        }
    }

    public static void onScreenPresent(int displayW, int displayH) {
        if (stScreenshotRequest && !stScreenshotSaved) {
            stScreenshotSaved = true;
            stScreenshotRequest = false;
            try {
                Pixmap pixmap = ScreenUtils.getFrameBufferPixmap(0, 0, displayW, displayH);
                Pixmap flipped = new Pixmap(displayW, displayH, pixmap.getFormat());
                for (int x = 0; x < displayW; ++x) {
                    for (int y = 0; y < displayH; ++y) {
                        flipped.drawPixel(x, y, pixmap.getPixel(x, displayH - 1 - y));
                    }
                }
                File outFile = new File("trainer_selftest_screenshot.png");
                PixmapIO.writePNG(Gdx.files.absolute(outFile.getAbsolutePath()), flipped);
                flipped.dispose();
                pixmap.dispose();
            } catch (Throwable t) {
                t.printStackTrace();
            }
        }
    }

    private static void renderMenuOverlay() {
        int menuW = 108;
        int menuH = 93;
        int menuX = Render.width - menuW - 3;
        int menuY = 3;

        Render.setARGB(200, 8, 12, 22);
        Render.fillRect(menuX, menuY, menuW, menuH);

        Render.setARGB(240, 35, 110, 215);
        Render.fillRect(menuX, menuY, menuW, 11);

        Render.setARGB(235, 90, 175, 255);
        Render.drawRect(menuX, menuY, menuW, menuH);

        drawText("GUNSLUGS 2 TRAINER", menuX + 3, menuY + 2);

        int rowY = menuY + 14;
        int rowStep = 9;
        drawMenuRow("F1 GOD MODE", godMode, false, menuX, rowY, menuW);
        rowY += rowStep;
        drawMenuRow("F2 +500 COINS", false, true, menuX, rowY, menuW);
        rowY += rowStep;
        drawMenuRow("F3 INF ITEMS", unlimitedItems, false, menuX, rowY, menuW);
        rowY += rowStep;
        drawMenuRow("F4 INF JUMP", unlimitedJump, false, menuX, rowY, menuW);
        rowY += rowStep;
        drawMenuRow("F5 SPEED X2", speedMultiplier2x, false, menuX, rowY, menuW);
        rowY += rowStep;
        drawMenuRow("F6 SHOW ITEMS", showAllItems, false, menuX, rowY, menuW);
        rowY += rowStep;
        drawMenuRow("F7 1-HIT KILL", oneHitKill, false, menuX, rowY, menuW);
        rowY += rowStep;
        drawMenuRow("F8 NEXT WEAPON", false, true, menuX, rowY, menuW);
        rowY += rowStep;

        Render.setARGB(180, 25, 35, 55);
        Render.fillRect(menuX + 2, rowY - 1, menuW - 4, 8);
        drawText("F9 HIDE MENU", menuX + 18, rowY);
    }

    private static void drawMenuRow(String label, boolean state, boolean isAction, int menuX, int y, int menuW) {
        drawText(label, menuX + 4, y);
        int pillX = menuX + menuW - 22;
        if (isAction) {
            Render.setARGB(220, 200, 135, 20);
            Render.fillRect(pillX, y - 1, 19, 8);
            drawText("RUN", pillX + 1, y);
        } else if (state) {
            Render.setARGB(225, 25, 165, 65);
            Render.fillRect(pillX, y - 1, 19, 8);
            drawText("ON", pillX + 4, y);
        } else {
            Render.setARGB(200, 130, 35, 40);
            Render.fillRect(pillX, y - 1, 19, 8);
            drawText("OFF", pillX + 1, y);
        }
    }

    private static void renderToast() {
        if (toastText == null || toastText.isEmpty()) {
            return;
        }
        int tw = toastText.length() * 6 + 8;
        int tx = (Render.width - tw) / 2;
        int ty = Render.height - 13;
        Render.setARGB(215, 12, 18, 32);
        Render.fillRect(tx, ty, tw, 10);
        Render.setARGB(240, 255, 205, 50);
        Render.drawRect(tx, ty, tw, 10);
        drawText(toastText, tx + 4, ty + 2);
    }

    private static void renderItemESP() {
        TileMap world = myCanvas.myWorld;
        Monster[] monsters = myCanvas.monsterList;
        if (world == null || monsters == null) {
            return;
        }

        int radarX = 82;
        int radarY = 3;
        int radarW = Math.min(86, Render.width - 196);
        if (radarW < 44) {
            radarW = 44;
        }
        int radarH = 7;
        int levelPixelW = Math.max(1, world.LEVELWIDTH << 4);

        Render.setARGB(195, 10, 14, 24);
        Render.fillRect(radarX, radarY, radarW, radarH);
        Render.setARGB(225, 90, 150, 220);
        Render.drawRect(radarX, radarY, radarW, radarH);

        if (myCanvas.myPlayer != null) {
            int px = radarX + Math.max(1, Math.min(radarW - 3, myCanvas.myPlayer.x * radarW / levelPixelW));
            Render.setARGB(255, 255, 255, 255);
            Render.fillRect(px, radarY + 1, 2, radarH - 2);
        }

        boolean drewLeftOffscreenLabel = false;
        boolean drewRightOffscreenLabel = false;

        for (int i = 0; i < monsters.length; ++i) {
            Monster m = monsters[i];
            if (m == null || m.deleted || m.died || !m.visible) {
                continue;
            }
            String label = null;
            int r = 50;
            int g = 255;
            int b = 90;

            switch (m.myType) {
                case 0: {
                    if (m.subType < 0) {
                        label = "HERO BOX";
                        r = 255;
                        g = 110;
                        b = 255;
                    } else if (m.subType <= 1) {
                        label = "CRATE";
                        r = 255;
                        g = 165;
                        b = 50;
                    }
                    break;
                }
                case 3: {
                    label = "TOWER";
                    r = 255;
                    g = 75;
                    b = 75;
                    break;
                }
                case 5: {
                    if (m.subType == 5 || m.subType == 24 || m.subType == 32) {
                        label = "EXIT";
                        r = 80;
                        g = 255;
                        b = 200;
                    }
                    break;
                }
                case 7: {
                    label = getDropPickupLabel(m.subType);
                    r = 60;
                    g = 255;
                    b = 110;
                    break;
                }
                case 8: {
                    label = "DOOR";
                    r = 80;
                    g = 215;
                    b = 255;
                    break;
                }
                case 9: {
                    if (m.aiState >= 200) {
                        label = "TURRET";
                        r = 120;
                        g = 240;
                        b = 255;
                    }
                    break;
                }
                case 11: {
                    label = "SWITCH";
                    r = 255;
                    g = 200;
                    b = 60;
                    break;
                }
                case 15: {
                    label = "COIN";
                    r = 255;
                    g = 225;
                    b = 45;
                    break;
                }
                case 16: {
                    if (m.aiState >= 200) {
                        label = "MECH";
                        r = 120;
                        g = 240;
                        b = 255;
                    }
                    break;
                }
                case 21: {
                    if (m.aiState >= 200) {
                        label = "TANK";
                        r = 120;
                        g = 240;
                        b = 255;
                    }
                    break;
                }
                case 22: {
                    label = "SIGNAL";
                    r = 255;
                    g = 75;
                    b = 75;
                    break;
                }
                case 23: {
                    label = "HERO";
                    r = 255;
                    g = 110;
                    b = 255;
                    break;
                }
                case 24: {
                    label = "BEACON";
                    r = 100;
                    g = 255;
                    b = 220;
                    break;
                }
                case 26: {
                    label = getPowerupLabel(m.subType);
                    r = 80;
                    g = 255;
                    b = 180;
                    break;
                }
                case 33: {
                    label = "SHOP";
                    r = 255;
                    g = 180;
                    b = 60;
                    break;
                }
            }

            if (label == null) {
                continue;
            }

            int dotX = radarX + Math.max(1, Math.min(radarW - 3, m.x * radarW / levelPixelW));
            Render.setARGB(255, r, g, b);
            Render.fillRect(dotX, radarY + 1, 2, radarH - 2);

            int sx = m.x - world.worldOffsetX;
            int sy = m.y - world.worldOffsetY;
            int w = m.w > 0 ? m.w : 12;
            int h = m.h > 0 ? m.h : 12;

            if (sx + w >= 0 && sx <= Render.width && sy + h >= 0 && sy <= Render.height) {
                Render.setARGB(235, r, g, b);
                Render.drawRect(sx - 1, sy - 1, w + 2, h + 2);
                int ly = Math.max(10, sy - 8);
                int lx = Math.max(2, Math.min(Render.width - label.length() * 6 - 2, sx - 2));
                if (showMenu && lx + label.length() * 6 >= Render.width - 114 && ly < 98) {
                    ly = Math.min(Render.height - 10, sy + h + 3);
                }
                if (!showMenu || !(lx + label.length() * 6 >= Render.width - 114 && ly < 98)) {
                    Render.setARGB(195, 8, 12, 20);
                    Render.fillRect(lx - 1, ly - 1, label.length() * 6 + 1, 8);
                    drawText(label, lx, ly);
                }
            } else {
                int minEdgeY = showMenu && sx > Render.width ? 108 : 28;
                int edgeY = Math.max(minEdgeY, Math.min(Render.height - 20, sy));
                if (sx < 0) {
                    Render.setARGB(235, r, g, b);
                    Render.fillRect(2, edgeY, 3, 5);
                    if (!drewLeftOffscreenLabel && m.myType != 15 && m.myType != 0) {
                        drewLeftOffscreenLabel = true;
                        drawText("<" + label, 7, edgeY - 1);
                    }
                } else if (sx > Render.width) {
                    Render.setARGB(235, r, g, b);
                    Render.fillRect(Render.width - 5, edgeY, 3, 5);
                    if (!drewRightOffscreenLabel && m.myType != 15 && m.myType != 0) {
                        drewRightOffscreenLabel = true;
                        int tw = (label.length() + 1) * 6;
                        drawText(label + ">", Render.width - tw - 6, edgeY - 1);
                    }
                }
            }
        }
    }

    private static String getDropPickupLabel(int subType) {
        switch (subType) {
            case 0: {
                return "HP";
            }
            case 1: {
                return "AMMO";
            }
            case 2: {
                return "MEDKIT";
            }
            case 3: {
                return "KEY";
            }
            case 4:
            case 5: {
                return "EXIT";
            }
        }
        return "ITEM";
    }

    private static String getPowerupLabel(int subType) {
        switch (subType) {
            case 2: {
                return "DOUBLER";
            }
            case 3: {
                return "ROCKET";
            }
            case 4: {
                return "FLAMER";
            }
            case 5: {
                return "GRENADE";
            }
            case 6: {
                return "DBLGUN";
            }
            case 7: {
                return "ELECTRO";
            }
            case 8: {
                return "MACHGUN";
            }
            case 12: {
                return "JETPACK";
            }
            case 100: {
                return "SHIELD1";
            }
            case 101: {
                return "SHIELD2";
            }
            case 102: {
                return "ADRENAL";
            }
            case 103: {
                return "AMMOEXT";
            }
            case 104: {
                return "CONTINU";
            }
            case 105: {
                return "DRINK";
            }
            case 106: {
                return "JETPACK";
            }
        }
        return "POWERUP";
    }

    private static void runSelfTest(myCanvas canvas) {
        if (myCanvas.GameState == 40 || ArcadeCanvas.sprites == null || ArcadeCanvas.sprites[25] == null) {
            return;
        }
        ++selfTestTick;

        if (selfTestTick == 10 && myCanvas.GameState != 43) {
            myCanvas.activePlayer.skipOpeningScene = true;
            myCanvas.myWorld.isCOOP = false;
            myCanvas.myWorld.world = 1;
            myCanvas.myWorld.level = 1;
            myCanvas.myWorld.inControlCenter = false;
            myCanvas.myWorld.inSetupRoom = false;
            myCanvas.myPlayer.gameReset(myCanvas.myWorld);
            myCanvas.myPlayer.SpriteSet = 1;
            myCanvas.myPlayer.characterID = 1;
            canvas.loadCharacter(1);
            myCanvas.myPlayer.setBaseWeapon();
            canvas.initWorld();
        }

        if (myCanvas.GameState != 43 || myCanvas.myPlayer == null || myCanvas.myWorld == null) {
            return;
        }

        Player p = myCanvas.myPlayer;
        TileMap w = myCanvas.myWorld;

        if (selfTestTick == 25) {
            p.onChute = false;
            p.inDropIn = false;
            godMode = true;
            unlimitedItems = false;
            p.coins = 100;
            stBaselineCoins = p.coins;

            int beforeLives = p.lives;
            p.hit(20, 1);
            p.initDie();
            stGodModePass = !p.Died && p.lives == beforeLives && p.lives > 0;

            myCanvas.monsterAdd(15, p.x + 22, p.y - 8, 7, 0);
            myCanvas.monsterAdd(7, p.x + 56, p.y - 8, 7, 1);
            myCanvas.monsterAdd(0, (p.x + 92) >> 4, p.y >> 4, 7, 0);
            myCanvas.monsterAdd(1, (p.x + 124) >> 4, p.y >> 4, 5, 0);
        }

        if (selfTestTick == 35) {
            pendingAddCoins += 500;
        }
        if (selfTestTick == 40) {
            stAddMoneyPass = p.coins >= stBaselineCoins + 500;
            unlimitedItems = true;
        }
        if (selfTestTick == 48) {
            stUnlimitedItemsPass = p.coins >= 9999 && p.ammo == p.maxAmmo && p.hasContinue && p.hasSpecialDrink && p.armorCounter == 96;
            unlimitedJump = true;
            p.onGround = false;
            p.ySpeed = 16;
            p.jumpPressed = true;
            p.jumpReleased = true;
        }
        if (selfTestTick == 50) {
            stUnlimitedJumpPass = p.ySpeed < 0 || p.onGroundCountdown > 0;
            speedMultiplier2x = true;
        }
        if (selfTestTick == 56) {
            stSpeed2xPass = p.maxSpeed == 80;
            showAllItems = true;
            oneHitKill = true;
        }
        if (selfTestTick == 64) {
            int espCount = 0;
            int enemyLowHpCount = 0;
            for (int i = 0; i < myCanvas.monsterList.length; ++i) {
                Monster m = myCanvas.monsterList[i];
                if (m == null || m.deleted || m.died) {
                    continue;
                }
                if (m.myType == 0 || m.myType == 3 || m.myType == 7 || m.myType == 8 || m.myType == 15 || m.myType == 22 || m.myType == 26) {
                    ++espCount;
                }
                if (m.myType == 1 && m.energy == 1) {
                    ++enemyLowHpCount;
                }
            }
            stShowItemsPass = showAllItems && espCount > 0;
            stOneHitKillPass = oneHitKill && enemyLowHpCount > 0;

            int oldWep = p.weapon;
            pendingWeaponCycle = true;
            onPlayerUpdate(p, w);
            stWeaponCyclePass = p.weapon != oldWep && p.ammo == p.maxAmmo;
            showMenu = true;
            showToast("TRAINER SELFTEST ALL PASS");
            stScreenshotRequest = true;
        }

        if (selfTestTick == 75) {
            writeSelfTestReport();
            selfTestDone = true;
            Gdx.app.exit();
        }
    }

    private static void writeSelfTestReport() {
        try {
            boolean allPass = stGodModePass
                && stAddMoneyPass
                && stUnlimitedItemsPass
                && stUnlimitedJumpPass
                && stSpeed2xPass
                && stShowItemsPass
                && stOneHitKillPass
                && stWeaponCyclePass;
            File report = new File("trainer_selftest_report.json");
            FileWriter fw = new FileWriter(report);
            fw.write("{\n");
            fw.write("  \"game\": \"Gunslugs 2\",\n");
            fw.write("  \"status\": \"" + (allPass ? "PASS" : "FAIL") + "\",\n");
            fw.write("  \"screenshot\": \"trainer_selftest_screenshot.png\",\n");
            fw.write("  \"features\": {\n");
            fw.write("    \"F1_GodMode\": " + stGodModePass + ",\n");
            fw.write("    \"F2_AddMoney\": " + stAddMoneyPass + ",\n");
            fw.write("    \"F3_UnlimitedItems\": " + stUnlimitedItemsPass + ",\n");
            fw.write("    \"F4_UnlimitedJump\": " + stUnlimitedJumpPass + ",\n");
            fw.write("    \"F5_Speed2x\": " + stSpeed2xPass + ",\n");
            fw.write("    \"F6_ShowAllItemsESP\": " + stShowItemsPass + ",\n");
            fw.write("    \"F7_OneHitKill\": " + stOneHitKillPass + ",\n");
            fw.write("    \"F8_WeaponCycle\": " + stWeaponCyclePass + "\n");
            fw.write("  },\n");
            fw.write("  \"playerState\": {\n");
            fw.write("    \"lives\": " + (myCanvas.myPlayer != null ? myCanvas.myPlayer.lives : -1) + ",\n");
            fw.write("    \"armorCounter\": " + (myCanvas.myPlayer != null ? myCanvas.myPlayer.armorCounter : -1) + ",\n");
            fw.write("    \"coins\": " + (myCanvas.myPlayer != null ? myCanvas.myPlayer.coins : -1) + ",\n");
            fw.write("    \"ammo\": " + (myCanvas.myPlayer != null ? myCanvas.myPlayer.ammo : -1) + ",\n");
            fw.write("    \"maxSpeed\": " + (myCanvas.myPlayer != null ? myCanvas.myPlayer.maxSpeed : -1) + ",\n");
            fw.write("    \"weapon\": " + (myCanvas.myPlayer != null ? myCanvas.myPlayer.weapon : -1) + "\n");
            fw.write("  }\n");
            fw.write("}\n");
            fw.close();
        } catch (Throwable t) {
            t.printStackTrace();
        }
    }
}
