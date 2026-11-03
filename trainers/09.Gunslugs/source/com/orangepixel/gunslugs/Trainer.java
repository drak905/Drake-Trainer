package com.orangepixel.gunslugs;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.PixmapIO;
import com.badlogic.gdx.utils.ScreenUtils;
import com.orangepixel.utils.ArcadeCanvas;
import java.io.FileWriter;
import java.io.PrintWriter;

public class Trainer {
    public static final String VERSION = "1.0.0";

    // Feature toggles
    public static boolean godMode = false;
    public static boolean unlimitedMoneyItems = false;
    public static boolean unlimitedJump = false;
    public static boolean speedX2 = false;
    public static boolean showAllItems = false;
    public static boolean oneHitKill = false;
    public static boolean menuVisible = true;

    // Input edge detection
    private static final boolean[] prevKeys = new boolean[260];

    // Toast notification state
    private static String toastText = "TRAINER LOADED - F9 MENU";
    private static int toastTimer = 150;

    // Weapon names (1..9)
    private static final String[] WEAPON_NAMES = new String[]{
        "NONE",
        "PISTOL",
        "FLAMETHROWER",
        "ELECTRO GUN",
        "JETPACK",
        "SKULL GUN",
        "GRENADE LAUNCHER",
        "CHICKEN GUN",
        "DUAL PISTOLS",
        "HELL TANK GUN"
    };

    private static final String[] PICKUP_NAMES = new String[]{
        "HP",
        "AMMO",
        "FLAME",
        "ELECTRO",
        "JETPACK",
        "GRENADE",
        "CHICKEN",
        "DUAL",
        "TANKGUN"
    };

    // Automated self-test state (TRAINER_SELFTEST=1)
    private static boolean selfTestChecked = false;
    private static boolean selfTestDone = false;
    private static int selfTestTicks = 0;

    private static boolean isKeyJustTriggered(int keyCode) {
        if (Gdx.input == null || keyCode < 0 || keyCode >= prevKeys.length) {
            return false;
        }
        boolean down = Gdx.input.isKeyPressed(keyCode);
        boolean just = down && !prevKeys[keyCode];
        prevKeys[keyCode] = down;
        return just;
    }

    public static void showToast(String msg) {
        toastText = msg;
        toastTimer = 90;
    }

    public static void pollKeys() {
        if (isKeyJustTriggered(Input.Keys.F1)) {
            godMode = !godMode;
            if (godMode && myCanvas.myPlayer != null) {
                if (myCanvas.myPlayer.maxLives <= 0) {
                    myCanvas.myPlayer.maxLives = 256;
                }
                myCanvas.myPlayer.lives = myCanvas.myPlayer.maxLives;
                myCanvas.myPlayer.Died = false;
            }
            showToast("F1 GOD MODE: " + (godMode ? "ON" : "OFF"));
        }
        if (isKeyJustTriggered(Input.Keys.F2)) {
            addMoneyNow(500);
            showToast("F2 +500 COINS (TOTAL " + (myCanvas.myPlayer != null ? myCanvas.myPlayer.coins : 0) + ")");
        }
        if (isKeyJustTriggered(Input.Keys.F3)) {
            unlimitedMoneyItems = !unlimitedMoneyItems;
            if (unlimitedMoneyItems) {
                applyUnlimitedMoneyItems(myCanvas.myPlayer);
            }
            showToast("F3 INF MONEY+ITEMS: " + (unlimitedMoneyItems ? "ON" : "OFF"));
        }
        if (isKeyJustTriggered(Input.Keys.F4)) {
            unlimitedJump = !unlimitedJump;
            showToast("F4 UNLIMITED JUMP: " + (unlimitedJump ? "ON" : "OFF"));
        }
        if (isKeyJustTriggered(Input.Keys.F5)) {
            speedX2 = !speedX2;
            if (myCanvas.myPlayer != null) {
                myCanvas.myPlayer.maxSpeed = speedX2 ? 128 : 64;
            }
            if (myCanvas.myPlayer2 != null) {
                myCanvas.myPlayer2.maxSpeed = speedX2 ? 128 : 64;
            }
            showToast("F5 MOVE SPEED X2: " + (speedX2 ? "ON" : "OFF"));
        }
        if (isKeyJustTriggered(Input.Keys.F6)) {
            showAllItems = !showAllItems;
            showToast("F6 SHOW MAP ITEMS: " + (showAllItems ? "ON" : "OFF"));
        }
        if (isKeyJustTriggered(Input.Keys.F7)) {
            oneHitKill = !oneHitKill;
            showToast("F7 ONE-HIT KILL: " + (oneHitKill ? "ON" : "OFF"));
        }
        if (isKeyJustTriggered(Input.Keys.F8)) {
            cycleWeapon();
        }
        if (isKeyJustTriggered(Input.Keys.F9) || isKeyJustTriggered(Input.Keys.F10) || isKeyJustTriggered(Input.Keys.INSERT)) {
            menuVisible = !menuVisible;
            showToast("TRAINER MENU: " + (menuVisible ? "SHOWN" : "HIDDEN"));
        }
    }

    public static void addMoneyNow(int amount) {
        if (myCanvas.myPlayer != null) {
            myCanvas.myPlayer.addCoin(amount);
            if (myCanvas.myPlayer.coins > 99999) {
                myCanvas.myPlayer.coins = 99999;
            }
            myCanvas.myPlayer.doGrabSound = true;
        }
    }

    public static void cycleWeapon() {
        if (myCanvas.myPlayer != null) {
            int nextW = myCanvas.myPlayer.weapon + 1;
            if (nextW < 1 || nextW > 9) {
                nextW = 1;
            }
            if (myCanvas.myPlayer.maxAmmo <= 0) {
                myCanvas.myPlayer.maxAmmo = 128;
            }
            myCanvas.myPlayer.setWeapon(nextW);
            myCanvas.myPlayer.ammo = myCanvas.myPlayer.maxAmmo;
            myCanvas.myPlayer.doGrabSound = true;
            showToast("F8 WEAPON: " + WEAPON_NAMES[nextW]);
        }
    }

    public static void applyUnlimitedMoneyItems(Player p) {
        if (p == null) {
            return;
        }
        if (p.maxLives <= 0) {
            p.maxLives = 256;
        }
        if (p.maxAmmo <= 0) {
            p.maxAmmo = 128;
        }
        if (p.coins < 999) {
            p.coins = 999;
        }
        p.ammo = p.maxAmmo;
        p.hasContinue = true;
        p.hasArmor = true;
        p.armorCounter = 256;
        if (p.beacon > -1 && p.beacon < 48) {
            p.beacon = 48;
        }
        if (myCanvas.activePlayer != null && myCanvas.activePlayer.unlockedCharacters != null) {
            for (int i = 0; i < myCanvas.activePlayer.unlockedCharacters.length; ++i) {
                myCanvas.activePlayer.unlockedCharacters[i] = true;
            }
        }
    }

    public static void onPlayerUpdate(Player p, TileMap myWorld) {
        if (p == null) {
            return;
        }
        if (godMode) {
            if (p.maxLives <= 0) {
                p.maxLives = 256;
            }
            p.lives = p.maxLives;
            p.Died = false;
            p.diedCounter = 0;
            p.hasArmor = true;
            if (p.armorCounter < 256) {
                p.armorCounter = 256;
            }
            // Rescue player from bottomless pits before y > 148 triggers death
            if (p.y > 142) {
                p.y = 32;
                p.floatY = p.y << 4;
                p.ySpeed = -80;
                p.onGround = true;
                p.onGroundCountdown = 2;
            }
        }
        if (unlimitedMoneyItems) {
            applyUnlimitedMoneyItems(p);
        }
        if (unlimitedJump && !p.inDoor) {
            p.onGroundCountdown = 2;
        }
        if (speedX2) {
            p.maxSpeed = 128;
            if (!p.transport && !p.blockPlayerMovement && p.noMoveCount == 0 && !p.inDoor) {
                if (p.leftPressed) {
                    p.xSpeed -= 8;
                    if (p.xSpeed < -p.maxSpeed) {
                        p.xSpeed = -p.maxSpeed;
                    }
                } else if (p.rightPressed) {
                    p.xSpeed += 8;
                    if (p.xSpeed > p.maxSpeed) {
                        p.xSpeed = p.maxSpeed;
                    }
                }
            }
        } else {
            p.maxSpeed = 64;
        }
        if (showAllItems && myCanvas.monsterList != null) {
            for (int i = 0; i < myCanvas.monsterList.length; ++i) {
                Monster m = myCanvas.monsterList[i];
                if (m == null || m.deleted || m.died) {
                    continue;
                }
                // Prevent dropped pickups and coins from despawning
                if ((m.myType == 0 || m.myType == 6) && m.aiCountDown > 0 && m.aiCountDown < 200) {
                    m.aiCountDown = 200;
                }
            }
        }
        if (oneHitKill && myCanvas.monsterList != null) {
            applyOneHitKill();
        }
    }

    public static void applyOneHitKill() {
        if (myCanvas.monsterList == null) {
            return;
        }
        for (int i = 0; i < myCanvas.monsterList.length; ++i) {
            Monster m = myCanvas.monsterList[i];
            if (m == null || m.deleted || m.died || m.aiState >= 900) {
                continue;
            }
            int t = m.myType;
            // Boss 7 has multi-phase parts & threshold at energy == 8
            if (t == 32) {
                if (m.aiState < 6 && m.myParts != null) {
                    if (m.myParts[0] > 1) {
                        m.myParts[0] = 1;
                    }
                    if (m.myParts[1] > 1) {
                        m.myParts[1] = 1;
                    }
                } else if (m.aiState == 6) {
                    if (m.energy > 8) {
                        m.energy = 8;
                    }
                } else if (m.energy > 1) {
                    m.energy = 1;
                }
                continue;
            }
            // Tank: aiState < 10 is enemy tank; aiState >= 10 is player-drivable tank
            if (t == 18) {
                if (m.aiState < 10 && m.energy > 1) {
                    m.energy = 1;
                }
                continue;
            }
            // Supply crate: subType >= 0 uses aiCountDown, subType < 0 uses energy
            if (t == 14) {
                if (m.subType < 0 && m.subType > -99 && m.energy > 1) {
                    m.energy = 1;
                }
                continue;
            }
            // Hostile monster & boss types
            if (t == 1 || t == 2 || t == 4 || t == 7 || t == 8 || t == 9 || t == 10 || t == 11 || t == 12 || t == 13 || t == 17 || t == 19 || t == 20 || t == 21 || (t >= 26 && t <= 31)) {
                if (m.energy > 1) {
                    m.energy = 1;
                }
            }
        }
    }

    public static void onFrameEnd(ArcadeCanvas canvas) {
        try {
            pollKeys();
            if (GUI.guiImage != null) {
                if (canvas != null && canvas.GameState == 43 && showAllItems) {
                    drawItemESP();
                }
                drawOverlay(canvas);
                Render.setARGB(255, 255, 255, 255);
                if (Render.globalTexture != null) {
                    Render.batch.end();
                    Render.globalTexture = null;
                }
            }
            checkSelfTest(canvas);
        } catch (Throwable t) {
            // Never crash the render loop
        }
    }

    private static void drawItemESP() {
        if (myCanvas.monsterList == null || myCanvas.myWorld == null) {
            return;
        }
        int worldOffX = myCanvas.myWorld.worldOffset;
        int worldOffY = myCanvas.myWorld.worldOffsetY;

        // Top-center mini radar bar showing the entire level (0..3120)
        int radarW = 84;
        int radarH = 6;
        int radarX = menuVisible ? Math.max(52, (Render.width - 114 - radarW) >> 1) : ((Render.width - radarW) >> 1);
        int radarY = 2;
        Render.setARGB(180, 12, 16, 24);
        Render.fillRect(radarX - 1, radarY - 1, radarW + 2, radarH + 2);
        Render.setARGB(200, 70, 90, 120);
        Render.drawRect(radarX - 1, radarY - 1, radarW + 2, radarH + 2);

        if (myCanvas.myPlayer != null) {
            int px = radarX + Math.max(0, Math.min(radarW - 2, (myCanvas.myPlayer.x * radarW) / 3120));
            Render.setARGB(255, 255, 255, 255);
            Render.fillRect(px, radarY, 2, radarH);
        }

        int leftArrowCount = 0;
        int rightArrowCount = 0;

        for (int i = 0; i < myCanvas.monsterList.length; ++i) {
            Monster m = myCanvas.monsterList[i];
            if (m == null || m.deleted || m.died || m.aiState >= 900) {
                continue;
            }
            int t = m.myType;
            String label = null;
            int r = 0;
            int g = 255;
            int b = 120;
            int boxX = m.x;
            int boxY = m.y;
            int boxW = m.w > 0 ? m.w : 12;
            int boxH = m.h > 0 ? m.h : 12;

            if (t == 0) {
                int st = m.subType;
                label = (st >= 0 && st < PICKUP_NAMES.length) ? PICKUP_NAMES[st] : "ITEM";
                r = 40;
                g = 255;
                b = 100;
            } else if (t == 6) {
                label = "COIN";
                r = 255;
                g = 215;
                b = 40;
            } else if (t == 14 && m.xOffset <= 64) {
                label = "CRATE";
                r = 255;
                g = 150;
                b = 40;
            } else if (t == 15 && m.aiState < 2) {
                label = "DOOR";
                r = 235;
                g = 90;
                b = 255;
                boxX = m.x + 24;
                boxY = m.y + 42;
                boxW = 24;
                boxH = 24;
            } else if (t == 18 && m.aiState >= 10) {
                label = "TANK";
                r = 60;
                g = 220;
                b = 255;
            } else if (t == 22) {
                label = "SHOP";
                r = 255;
                g = 230;
                b = 60;
            } else if (t == 4 && m.aiState < 2) {
                label = "BEACON";
                r = 255;
                g = 70;
                b = 70;
            }

            if (label == null) {
                continue;
            }

            // Plot on radar bar
            int rx = radarX + Math.max(0, Math.min(radarW - 2, (boxX * radarW) / 3120));
            Render.setARGB(255, r, g, b);
            Render.fillRect(rx, radarY + 1, 2, radarH - 2);

            int sx = boxX - worldOffX;
            int sy = boxY - worldOffY;

            if (sx + boxW >= 0 && sx <= Render.width) {
                int drawX = Math.max(1, Math.min(Render.width - boxW - 1, sx));
                int drawY = Math.max(10, Math.min(Render.height - boxH - 1, sy));
                Render.setARGB(220, r, g, b);
                Render.drawRect(drawX, drawY, boxW, boxH);
                if (!"COIN".equals(label)) {
                    int textW = label.length() * 4 + 2;
                    int labelX = Math.max(1, Math.min(Render.width - textW - 1, drawX));
                    int labelY = Math.max(10, drawY - 8);
                    Render.setARGB(190, 10, 14, 20);
                    Render.fillRect(labelX - 1, labelY - 1, textW, 8);
                    GUI.renderText(label, 0, labelX, labelY, 120, 1, 0);
                }
            } else if (!"COIN".equals(label)) {
                // Off-screen indicator for important items/crates/doors/beacons
                if (sx < 0 && leftArrowCount < 5) {
                    int ay = 26 + leftArrowCount * 10;
                    String ind = "< " + label;
                    int tw = ind.length() * 4 + 5;
                    Render.setARGB(185, 12, 16, 24);
                    Render.fillRect(1, ay - 1, tw, 8);
                    Render.setARGB(230, r, g, b);
                    Render.fillRect(1, ay - 1, 2, 8);
                    GUI.renderText(ind, 0, 4, ay, 90, 1, 0);
                    ++leftArrowCount;
                } else if (sx > Render.width && rightArrowCount < 5) {
                    int ay = 98 + rightArrowCount * 10;
                    String ind = label + " >";
                    int tw = ind.length() * 4 + 5;
                    int ax = Render.width - tw - 1;
                    Render.setARGB(185, 12, 16, 24);
                    Render.fillRect(ax, ay - 1, tw, 8);
                    Render.setARGB(230, r, g, b);
                    Render.fillRect(ax + tw - 2, ay - 1, 2, 8);
                    GUI.renderText(ind, 0, ax + 2, ay, 90, 1, 0);
                    ++rightArrowCount;
                }
            }
        }
    }

    private static void drawOverlay(ArcadeCanvas canvas) {
        if (toastTimer > 0) {
            --toastTimer;
            if (toastText != null && toastText.length() > 0) {
                int tw = toastText.length() * 4 + 14;
                int tx = menuVisible ? Math.max(2, ((Render.width - 112) - tw) >> 1) : ((Render.width - tw) >> 1);
                int ty = Render.height - 13;
                Render.setARGB(225, 14, 22, 34);
                Render.fillRect(tx, ty, tw, 9);
                Render.setARGB(245, 60, 200, 110);
                Render.drawRect(tx, ty, tw, 9);
                GUI.renderText(toastText, 0, tx + 4, ty + 1, tw + 20, 1, 0);
            }
        }

        if (!menuVisible) {
            int bw = 46;
            int bh = 9;
            int bx = Render.width - bw - 2;
            int by = 2;
            Render.setARGB(185, 14, 18, 26);
            Render.fillRect(bx, by, bw, bh);
            Render.setARGB(210, 70, 130, 210);
            Render.drawRect(bx, by, bw, bh);
            GUI.renderText("F9 TRAINER", 0, bx + 3, by + 1, bw + 10, 1, 0);
            return;
        }

        int panelW = 110;
        int panelH = 87;
        int panelX = Render.width - panelW - 2;
        int panelY = 2;

        // Panel background & border
        Render.setARGB(215, 12, 16, 24);
        Render.fillRect(panelX, panelY, panelW, panelH);
        Render.setARGB(240, 56, 130, 220);
        Render.drawRect(panelX, panelY, panelW, panelH);

        // Header bar
        Render.setARGB(235, 26, 56, 105);
        Render.fillRect(panelX + 1, panelY + 1, panelW - 2, 9);
        GUI.renderText("GUNSLUGS TRAINER", 0, panelX + 4, panelY + 2, panelW, 1, 0);

        int rowY = panelY + 12;
        drawToggleRow(panelX, rowY, "F1 GOD MODE", godMode);
        rowY += 8;
        drawActionRow(panelX, rowY, "F2 ADD +500 COINS", "+500");
        rowY += 8;
        drawToggleRow(panelX, rowY, "F3 INF MONEY+ITEM", unlimitedMoneyItems);
        rowY += 8;
        drawToggleRow(panelX, rowY, "F4 UNLIMITED JUMP", unlimitedJump);
        rowY += 8;
        drawToggleRow(panelX, rowY, "F5 MOVE SPEED X2", speedX2);
        rowY += 8;
        drawToggleRow(panelX, rowY, "F6 MAP ITEM ESP", showAllItems);
        rowY += 8;
        drawToggleRow(panelX, rowY, "F7 ONE-HIT KILL", oneHitKill);
        rowY += 8;
        String curWep = "W1";
        if (myCanvas.myPlayer != null && myCanvas.myPlayer.weapon >= 1 && myCanvas.myPlayer.weapon <= 9) {
            curWep = "W" + myCanvas.myPlayer.weapon;
        }
        drawActionRow(panelX, rowY, "F8 CYCLE WEAPON", curWep);
        rowY += 8;
        GUI.renderText("F9 HIDE MENU", 0, panelX + 4, rowY + 1, panelW, 1, 0);
    }

    private static void drawToggleRow(int panelX, int y, String label, boolean state) {
        GUI.renderText(label, 0, panelX + 4, y + 1, 88, 1, 0);
        int pillX = panelX + 86;
        int pillW = 21;
        if (state) {
            Render.setARGB(235, 28, 165, 75);
            Render.fillRect(pillX, y, pillW, 7);
            GUI.renderText("ON", 0, pillX + 6, y, 30, 1, 0);
        } else {
            Render.setARGB(210, 65, 70, 82);
            Render.fillRect(pillX, y, pillW, 7);
            GUI.renderText("OFF", 0, pillX + 4, y, 30, 1, 0);
        }
    }

    private static void drawActionRow(int panelX, int y, String label, String badge) {
        GUI.renderText(label, 0, panelX + 4, y + 1, 88, 1, 0);
        int pillX = panelX + 86;
        int pillW = 21;
        Render.setARGB(225, 45, 105, 180);
        Render.fillRect(pillX, y, pillW, 7);
        int offset = badge.length() <= 2 ? 6 : 2;
        GUI.renderText(badge, 0, pillX + offset, y, 30, 1, 0);
    }

    private static void checkSelfTest(ArcadeCanvas canvas) {
        if (selfTestDone) {
            return;
        }
        if (!selfTestChecked) {
            selfTestChecked = true;
            String env = System.getenv("TRAINER_SELFTEST");
            if (!"1".equals(env)) {
                selfTestDone = true;
                return;
            }
        }
        ++selfTestTicks;
        if (selfTestTicks == 15 && canvas instanceof myCanvas) {
            myCanvas mc = (myCanvas)canvas;
            mc.initGame(1, 1);
            mc.GameState = 52;
            godMode = true;
            unlimitedMoneyItems = true;
            unlimitedJump = true;
            speedX2 = true;
            showAllItems = true;
            oneHitKill = true;
            menuVisible = true;
            showToast("SELFTEST: ALL CHEATS ACTIVE");
            return;
        }
        if (selfTestTicks == 64 && myCanvas.myPlayer != null && myCanvas.myWorld != null) {
            runSelfTest();
        }
    }

    public static void onScreenPresent(int w, int h) {
        if (selfTestDone || !selfTestChecked || selfTestTicks < 66) {
            return;
        }
        selfTestDone = true;
        try {
            Pixmap pm = ScreenUtils.getFrameBufferPixmap(0, 0, w, h);
            Pixmap flipped = new Pixmap(w, h, pm.getFormat());
            for (int y = 0; y < h; ++y) {
                for (int x = 0; x < w; ++x) {
                    flipped.drawPixel(x, y, pm.getPixel(x, h - 1 - y));
                }
            }
            PixmapIO.writePNG(Gdx.files.absolute(new java.io.File("trainer_selftest_screenshot.png").getAbsolutePath()), flipped);
            flipped.dispose();
            pm.dispose();
        } catch (Throwable ignored) {
        }
    }

    private static void runSelfTest() {
        Player p = myCanvas.myPlayer;
        TileMap w = myCanvas.myWorld;
        int origCoins = p.coins;
        int origLives = p.lives;
        int origMaxLives = p.maxLives;
        int origAmmo = p.ammo;
        int origMaxAmmo = p.maxAmmo;
        int origWeapon = p.weapon;

        boolean passGod = false;
        boolean passAddMoney = false;
        boolean passInfMoneyItems = false;
        boolean passInfJump = false;
        boolean passSpeedX2 = false;
        boolean passItemESP = false;
        boolean passOneHitKill = false;
        boolean passWeaponCycle = false;

        try {
            // 1. Test God Mode
            p.gameReset();
            godMode = true;
            Bullets dummyBullet = new Bullets();
            dummyBullet.energy = 100;
            p.die(dummyBullet);
            p.initDie();
            onPlayerUpdate(p, w);
            passGod = (p.lives == p.maxLives && !p.Died && p.hasArmor);
            godMode = false;

            // 2. Test Add Money (+500)
            int beforeCoins = p.coins;
            addMoneyNow(500);
            passAddMoney = (p.coins == beforeCoins + 500);

            // 3. Test Unlimited Money & Items
            p.coins = 10;
            p.ammo = 1;
            p.hasContinue = false;
            unlimitedMoneyItems = true;
            onPlayerUpdate(p, w);
            passInfMoneyItems = (p.coins >= 999 && p.ammo == p.maxAmmo && p.hasContinue && p.hasArmor);
            unlimitedMoneyItems = false;

            // 4. Test Unlimited Jump
            p.onGround = false;
            p.onGroundCountdown = 0;
            unlimitedJump = true;
            onPlayerUpdate(p, w);
            passInfJump = (p.onGroundCountdown >= 2);
            unlimitedJump = false;

            // 5. Test Speed x2
            speedX2 = true;
            onPlayerUpdate(p, w);
            int speedOn = p.maxSpeed;
            speedX2 = false;
            onPlayerUpdate(p, w);
            int speedOff = p.maxSpeed;
            passSpeedX2 = (speedOn == 128 && speedOff == 64);

            // 6. Test Show All Items ESP
            if (myCanvas.monsterList != null && myCanvas.monsterList[0] != null) {
                Monster m0 = myCanvas.monsterList[0];
                boolean oldDel = m0.deleted;
                int oldType = m0.myType;
                int oldCd = m0.aiCountDown;
                m0.deleted = false;
                m0.died = false;
                m0.myType = 0;
                m0.aiCountDown = 10;
                showAllItems = true;
                onPlayerUpdate(p, w);
                passItemESP = (m0.aiCountDown == 200);
                showAllItems = false;
                m0.deleted = oldDel;
                m0.myType = oldType;
                m0.aiCountDown = oldCd;
            }

            // 7. Test One-Hit Kill
            if (myCanvas.monsterList != null && myCanvas.monsterList[0] != null) {
                Monster m0 = myCanvas.monsterList[0];
                boolean oldDel = m0.deleted;
                int oldType = m0.myType;
                int oldEnergy = m0.energy;
                int oldAi = m0.aiState;
                m0.deleted = false;
                m0.died = false;
                m0.myType = 2; // mSOLDIER
                m0.aiState = 0;
                m0.energy = 50;
                oneHitKill = true;
                onPlayerUpdate(p, w);
                passOneHitKill = (m0.energy == 1);
                oneHitKill = false;
                m0.deleted = oldDel;
                m0.myType = oldType;
                m0.energy = oldEnergy;
                m0.aiState = oldAi;
            }

            // 8. Test Weapon Cycle
            p.setWeapon(1);
            cycleWeapon();
            passWeaponCycle = (p.weapon == 2 && p.ammo == p.maxAmmo);

            // Restore player state
            p.coins = origCoins;
            p.lives = origLives;
            p.maxLives = origMaxLives;
            p.ammo = origAmmo;
            p.maxAmmo = origMaxAmmo;
            p.weapon = origWeapon;
        } catch (Throwable t) {
            // keep partial results
        }

        boolean allPass = passGod && passAddMoney && passInfMoneyItems && passInfJump && passSpeedX2 && passItemESP && passOneHitKill && passWeaponCycle;
        // Leave all toggles ON for screenshot verification during self-test
        godMode = true;
        unlimitedMoneyItems = true;
        unlimitedJump = true;
        speedX2 = true;
        showAllItems = true;
        oneHitKill = true;
        menuVisible = true;
        try {
            PrintWriter out = new PrintWriter(new FileWriter("trainer_selftest_report.json"));
            out.println("{");
            out.println("  \"game\": \"Gunslugs\",");
            out.println("  \"version\": \"" + VERSION + "\",");
            out.println("  \"overall\": \"" + (allPass ? "PASS" : "FAIL") + "\",");
            out.println("  \"features\": {");
            out.println("    \"F1_GodMode\": \"" + (passGod ? "PASS" : "FAIL") + "\",");
            out.println("    \"F2_AddMoney\": \"" + (passAddMoney ? "PASS" : "FAIL") + "\",");
            out.println("    \"F3_UnlimitedMoneyAndItems\": \"" + (passInfMoneyItems ? "PASS" : "FAIL") + "\",");
            out.println("    \"F4_UnlimitedJump\": \"" + (passInfJump ? "PASS" : "FAIL") + "\",");
            out.println("    \"F5_MoveSpeedX2\": \"" + (passSpeedX2 ? "PASS" : "FAIL") + "\",");
            out.println("    \"F6_ShowAllItemsOnMap\": \"" + (passItemESP ? "PASS" : "FAIL") + "\",");
            out.println("    \"F7_OneHitKill\": \"" + (passOneHitKill ? "PASS" : "FAIL") + "\",");
            out.println("    \"F8_CycleWeapon\": \"" + (passWeaponCycle ? "PASS" : "FAIL") + "\"");
            out.println("  }");
            out.println("}");
            out.close();
        } catch (Throwable ignored) {
        }
    }
}
