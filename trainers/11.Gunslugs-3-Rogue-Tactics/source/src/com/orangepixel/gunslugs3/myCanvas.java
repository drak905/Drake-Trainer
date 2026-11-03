/*
 * Decompiled with CFR 0.152.
 */
package com.orangepixel.gunslugs3;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.assets.AssetManager;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.utils.Json;
import com.orangepixel.controller.GameInput;
import com.orangepixel.controller.GameInputGamepadListener;
import com.orangepixel.gunslugs3.Globals;
import com.orangepixel.gunslugs3.PlayerProfile;
import com.orangepixel.gunslugs3.PlayerSavegame;
import com.orangepixel.gunslugs3.World;
import com.orangepixel.gunslugs3.ai.BossEntityList;
import com.orangepixel.gunslugs3.ai.BulletEntityList;
import com.orangepixel.gunslugs3.ai.EntitySprite;
import com.orangepixel.gunslugs3.ai.FXEntityList;
import com.orangepixel.gunslugs3.ai.MonsterEntity;
import com.orangepixel.gunslugs3.ai.MonsterEntityList;
import com.orangepixel.gunslugs3.ai.PlayerEntity;
import com.orangepixel.gunslugs3.ai.SceneryEntity;
import com.orangepixel.gunslugs3.ai.SceneryEntityList;
import com.orangepixel.gunslugs3.ai.SceneryIndoorEntityList;
import com.orangepixel.gunslugs3.animations.animalien;
import com.orangepixel.gunslugs3.animations.animarctic;
import com.orangepixel.gunslugs3.animations.animcore;
import com.orangepixel.gunslugs3.animations.animdone;
import com.orangepixel.gunslugs3.animations.animegypt;
import com.orangepixel.gunslugs3.animations.animintro;
import com.orangepixel.gunslugs3.animations.animphatt;
import com.orangepixel.gunslugs3.editor.leveleditor;
import com.orangepixel.gunslugs3.overlayanims;
import com.orangepixel.gunslugs3.ui.uibossintro;
import com.orangepixel.gunslugs3.ui.uicharselect;
import com.orangepixel.gunslugs3.ui.uicontrollersetup;
import com.orangepixel.gunslugs3.ui.uicore;
import com.orangepixel.gunslugs3.ui.uidifficulty;
import com.orangepixel.gunslugs3.ui.uigameover;
import com.orangepixel.gunslugs3.ui.uigamestats;
import com.orangepixel.gunslugs3.ui.uiinventory;
import com.orangepixel.gunslugs3.ui.uimenu;
import com.orangepixel.gunslugs3.ui.uimissionselect;
import com.orangepixel.gunslugs3.ui.uisettings;
import com.orangepixel.gunslugs3.ui.uiskills;
import com.orangepixel.gunslugs3.ui.uisplash;
import com.orangepixel.gunslugs3.ui.uitouchsetup;
import com.orangepixel.gunslugs3.ui.uiworldintro;
import com.orangepixel.gunslugs3.worldgenerator.WGCell;
import com.orangepixel.gunslugs3.worldgenerator.WorldGenerator;
import com.orangepixel.plugins.ConsoleListener;
import com.orangepixel.utils.ArcadeCanvas;
import com.orangepixel.utils.Audio;
import com.orangepixel.utils.Fader;
import com.orangepixel.utils.FaderListener;
import com.orangepixel.utils.GUI;
import com.orangepixel.utils.GUIListener;
import com.orangepixel.utils.Light;
import com.orangepixel.utils.Local;
import com.orangepixel.utils.Render;
import com.orangepixel.utils.SpriteList;

public class myCanvas
extends ArcadeCanvas {
    private static boolean isCheatOn = false;
    public static final String PROFILEID = "Gunslugs3";
    public static final int LEVEL_GENERATION_TIME_FAKER = 65;
    public static final int INOPTIONS = 10;
    public static final int INSETTINGS = 11;
    public static final int INCONTROLLERSETUPPC = 12;
    public static final int INCONTROLLERSETUPPCSET = 13;
    public static final int INGAMEPADSETUP = 14;
    public static final int INGAMEPADSETUPSET = 15;
    public static final int INTOUCHSETUP = 16;
    public static final int INITMAP = 20;
    public static final int INCHARSELECT = 21;
    public static final int INBOSSINTRO = 22;
    public static final int INWORLDINTRO = 23;
    public static final int ININVENTORY = 24;
    public static final int INMISSIONSELECT = 25;
    public static final int INSKILLS = 26;
    public static final int INANIMATIONS = 27;
    public static final int INDEVTHANKS = 28;
    public static final int INUNLOCKUSAGE = 29;
    public static final int INGAMESTATS = 30;
    public static final int INRETRYCHECKPOINT = 31;
    public static final int INDIFFICULTY = 32;
    public static final int INEDIT = 99;
    private static Fader myFader = new Fader();
    public static int initMapDelay;
    public static animcore myAnimation;
    public static World myWorld;
    public static PlayerEntity myPlayer;
    public static PlayerProfile activePlayer;
    public static PlayerSavegame mySaveGame;
    private AssetManager manager = new AssetManager();
    public static int unlockX;
    public static int unlockXSpeed;
    public static int unlockDelay;
    public static int unlockID;
    public static float unlockScale;
    public static int unlockAlpha;
    private static int tx;
    private static int ty;
    private static int tx2;
    private static int ty2;
    private static int tile;
    public static int currentHint;
    private boolean done;
    private boolean foundFirst;
    private float percent;
    private static int pointerArrowFrame;
    private static int pointerArrowDelay;
    private static int PrePauseGamestate;
    private static int statusX;
    private static int statusY;
    private static int statusBelowY;
    private static int statusBelowYTarget;
    private static int commandRemap;
    private static int commandEdit;
    private static int commandCrate;
    private static int commandBarrel;
    private static int commandSoldier;
    private static int commandChopper;
    private static int commandWorld;
    private static int commandRetro;
    private static int commandWeapon;
    private static int commandPickup;
    private static int commandSpawn;
    private static int commandSpawnEnemy;
    private static int commandSpawnWeapon;
    private static int commandBoss;
    private static int commandEscape;
    private static int commandTower;
    private static int commandShop;
    private static int commandCamera;
    private static int commandPixelsize;
    private static int commandSkills;
    private static int commandCoins;
    private static int commandAnim;
    private static int commandGamma;
    private static int commandTestUnlock;
    private static int commandTestOverlay;
    private static int commandGod;
    private static int commandStats;
    private static int commandCheckpoint;
    private static int commandSetXY;
    private static int avatarHeadOffset;
    public static boolean hadMissions;

    @Override
    public void setConsoleInfo() {
        Globals.debug("Orangepixel framework - code version:1.0.10b");
        Globals.debug("LibGDX :1.9.10");
        if (myConsole != null) {
            Globals.debug(myConsole.VERSION());
        }
        Globals.debug("-----------------");
    }

    private void init() {
        uisplash.initSplash();
        uicore.init("uilogo.png");
        Local.init();
        if (Globals.isDesktop) {
            leveleditor.init();
        }
        activePlayer = new PlayerProfile();
        activePlayer.loadSettings(PROFILEID);
        ++myCanvas.activePlayer.pref_Starts;
        mySaveGame = new PlayerSavegame();
        if (myCanvas.activePlayer.highRes) {
            myCanvas.setPixelSize(240);
        }
        if ((windowedModeID = myCanvas.activePlayer.storedWindowedModeID) < 0) {
            myCanvas.activePlayer.storedWindowedModeID = windowedModeID = 2;
            activePlayer.saveSettings();
        } else {
            activePlayer.saveSettings();
        }
        GUI.initGui("uipcfont.png");
        GUI.loadFont("piXelize.ttf", Color.WHITE, 10, false, true);
        GUI.loadFont("piXelize.ttf", Color.WHITE, 20, true, true);
        GUI.loadFont("piXelize.ttf", Color.BLACK, 10, false, false);
        GUI.loadFont("piXelize.ttf", new Color(1.0f, 0.9f, 0.8f, 1.0f), 10, false, false);
        overlayanims.initAnimations();
        Audio.preLoadassets(this.manager);
        Audio.MusicVolume = myCanvas.activePlayer.musicVolume;
        Audio.SoundVolume = myCanvas.activePlayer.soundVolume;
        Audio.useSFX = true;
        Audio.useMusic = true;
        GameInput.initGameInput();
        if (Globals.isIOS && this.myMFIController != null) {
            this.myMFIController.linkController(GameInput.gamepads[0]);
        }
        GameInput.kbSwap = GameInput.bindKey("Swap weapon", 54, 54);
        GameInput.kbUse = GameInput.bindKey("Use", 29, 29);
        GameInput.kbPause = GameInput.bindKey("Pause", 61, 61);
        for (int i = 0; i <= GameInput.boundKeys; ++i) {
            if (myCanvas.activePlayer.keyboardSettings[i] < 0) {
                myCanvas.activePlayer.keyboardSettings[i] = GameInput.keyboardConfigDefaults[i];
            }
            GameInput.keyboardConfig[i] = myCanvas.activePlayer.keyboardSettings[i];
        }
        GameInput.setListener(new GameInputGamepadListener(){

            @Override
            public void onNewGamepadMapping() {
                super.onNewGamepadMapping();
                for (int i = GameInput.gbGUIEND; i < GameInput.boundButtons; ++i) {
                    if (myCanvas.activePlayer.controller1[i - GameInput.gbGUIEND] < 0) continue;
                    GameInput.gamepadConfig[0][i] = myCanvas.activePlayer.controller1[i - GameInput.gbGUIEND];
                }
            }
        });
        if (myConsole != null) {
            myConsole.initConsole();
            this.setupConsole();
        }
        myPlayer = new PlayerEntity();
        FXEntityList.initList();
        BulletEntityList.initList();
        MonsterEntityList.initList();
        SceneryEntityList.initList();
        SceneryIndoorEntityList.initList();
        BossEntityList.initList();
        SpriteList.initList();
        myWorld = new World();
        myCanvas.sprites[0] = new Texture(Gdx.files.internal("spriteset01.png"), true);
        myCanvas.sprites[1] = new Texture(Gdx.files.internal("back02.png"), true);
        myCanvas.sprites[2] = new Texture(Gdx.files.internal("uimap.png"), true);
        myCanvas.sprites[3] = new Texture(Gdx.files.internal("devthanks.png"), true);
        myCanvas.sprites[4] = new Texture(Gdx.files.internal("phatt.png"), true);
        isLightRendering = true;
        Light.initLights("lights.png");
        Light.setGamma(myCanvas.activePlayer.gamma);
        Globals.initGlobals();
        worldTicks = 0;
        currentHint = Globals.getRandomForcedUnseeded(Globals.gameHints.length);
        GameState = 2;
        pointerArrowFrame = 382;
        pointerArrowDelay = 0;
    }

    @Override
    public final void LogicLoop() {
        Trainer.onFrameUpdate(this);
        GameInput.convertMouseToScreenCoords();
        if (uicore.menuAlpha < 255 && (uicore.menuAlpha += 32) >= 255) {
            uicore.menuAlpha = 255;
        }
        switch (GameState) {
            case 1: {
                this.init();
                int setID = myCanvas.fetchWindowMode(windowedModeID);
                myCanvas.setDisplayMode(windowedModes[setID][1], windowedModes[setID][2], myCanvas.activePlayer.useFullscreen);
                break;
            }
            case 20: {
                Fader.setFadeOff();
                if (initMapDelay > 0) {
                    SpriteList.resetList();
                    Light.resetLights();
                    Light.setAmbientLight(0.6f, 0.62f, 0.63f, 1.0f);
                    Render.drawPaint(255, 36, 42, 38);
                    this.percent = 1.5384616f * (float)(65 - --initMapDelay);
                    tx = (Render.width >> 1) - 52 + (int)(this.percent / 4.0f);
                    ty = 24;
                    myCanvas.renderChopper(tx, ty);
                    Render.setAlpha(255);
                    ty = (Render.height >> 1) - 24;
                    GUI.setCentered(true);
                    GUI.renderText(Globals.gameUIText[0] + (int)this.percent + "%", 0, 0, ty, Render.width, 1, 0);
                    GUI.setCentered(false);
                    tx = (Render.width >> 1) - 100;
                    ty = (Render.height >> 1) + 16;
                    GUI.setCentered(true);
                    GUI.renderText(Globals.gameHints[currentHint], 0, 0, ty, Render.width, 2, 0);
                    GUI.setCentered(false);
                    myCanvas.myPlayer.lives = myCanvas.myPlayer.maxLives;
                    break;
                }
                FXEntityList.resetList();
                if (!World.doContinue) {
                    BulletEntityList.resetList();
                    MonsterEntityList.resetList();
                    SceneryEntityList.resetList();
                    SceneryIndoorEntityList.resetList();
                    myWorld.initNewLevel();
                    World.myTowerID = 0;
                    if (World.world == 6) {
                        myCanvas.createBossBattle();
                    } else {
                        myCanvas.createOverworld();
                    }
                    myWorld.loadWorld(World.world);
                }
                World.doContinue = false;
                World.setChaptername(Globals.WORLD_CHAPTERNAMES[World.world]);
                myPlayer.initNewLevel(24, 1824);
                for (int i = 0; i < MonsterEntityList.myListMax; ++i) {
                    if (MonsterEntityList.myList[i].myType != 17) continue;
                    MonsterEntityList.myList[i].died = true;
                }
                MonsterEntityList.add(17, 6, myCanvas.myPlayer.y, 0, null);
                World.focusCameraOnPlayer(myPlayer);
                Fader.fadeToWhite = false;
                Fader.initFadeIn(null);
                Audio.playBackgroundMusic(0, 80);
                GameState = 7;
                if (myCanvas.myPlayer.skillPoints <= 0) break;
                uiskills.init();
                break;
            }
            case 4: 
            case 5: 
            case 28: {
                World.offsetX = 0;
                World.offsetY = 0;
            }
            case 6: 
            case 10: 
            case 11: 
            case 12: 
            case 13: 
            case 14: 
            case 15: 
            case 16: 
            case 26: 
            case 31: 
            case 32: {
                if (paused) {
                    myCanvas.renderScene();
                    Render.drawPaint(80, 32, 83, 100);
                    Light.resetLights();
                    Light.addLight(World.offsetX + (Render.width >> 1), World.offsetY + (Render.height >> 1), 240.0f, 5, 0.3f, 0.6f, 1.0f, 0.5f, false);
                    break;
                }
                SpriteList.resetList();
                Light.resetLights();
                Light.setAmbientLight(0.4f, 0.42f, 0.4f, 1.0f);
                FXEntityList.update(myPlayer, myWorld);
                myWorld.update(myPlayer);
                Render.drawPaint(255, 36, 42, 38);
                SpriteList.renderList(1, myWorld, sprites);
                SpriteList.renderList(5, myWorld, sprites);
                SpriteList.renderList(6, myWorld, sprites);
                if (GameState == 32) {
                    uicore.renderJustThePlane();
                    break;
                }
                uimenu.render(mySaveGame, worldTicks);
                break;
            }
            case 27: {
                myAnimation.update(myWorld, myPlayer);
                break;
            }
            case 21: {
                SpriteList.resetList();
                Light.resetLights();
                Light.setAmbientLight(0.3f, 0.32f, 0.3f, 1.0f);
                FXEntityList.update(myPlayer, myWorld);
                myWorld.update(myPlayer);
                Render.drawPaint(255, 36, 42, 38);
                uicharselect.render(worldTicks);
                SpriteList.renderList(1, myWorld, sprites);
                SpriteList.renderList(5, myWorld, sprites);
                SpriteList.renderList(6, myWorld, sprites);
                break;
            }
            case 22: {
                SpriteList.resetList();
                Light.resetLights();
                Light.setAmbientLight(0.6f, 0.62f, 0.63f, 1.0f);
                myCanvas.renderScene();
                break;
            }
            case 23: {
                myCanvas.renderScene();
                SpriteList.renderList(1, myWorld, sprites);
                SpriteList.renderList(5, myWorld, sprites);
                SpriteList.renderList(6, myWorld, sprites);
                SpriteList.renderList(10, myWorld, sprites);
                uiworldintro.render(worldTicks);
                break;
            }
            case 30: {
                myCanvas.renderScene();
                SpriteList.renderList(1, myWorld, sprites);
                uigamestats.render(worldTicks);
                break;
            }
            case 24: 
            case 29: {
                myCanvas.renderScene();
                break;
            }
            case 25: {
                Light.resetLights();
                Light.setAmbientLight(0.04f, 0.04f, 0.12f, 1.0f);
                Render.drawPaint(255, 36, 42, 38);
                uicore.renderPlayerPlane(worldTicks, false, false);
                uimissionselect.render(sprites[2], worldTicks);
                break;
            }
            case 99: {
                SpriteList.resetList();
                Light.resetLights();
                leveleditor.update();
            }
        }
        if (worldTicks % 16 == 0 && mySocial != null) {
            mySocial.updateSocial();
        }
    }

    @Override
    public final void renderPostLights() {
        GameInput.convertMouseToScreenCoords();
        switch (GameState) {
            case 2: {
                Render.drawPaint(255, 0, 0, 0);
                Render.setAlpha(255);
                tx = (Render.width >> 1) - 44;
                ty = (Render.height >> 1) - 8;
                Render.dest.set(tx, ty, tx + 84, ty + 16);
                Render.src.set(255, 215, 339, 231);
                Render.drawBitmap(GUI.guiImage, false);
                this.percent = 6.4f * (float)((int)(this.manager.getProgress() * 10.0f));
                Render.dest.set(tx + 10, ty + 9, tx + 10 + (int)this.percent, ty + 13);
                Render.src.set(265, 232, 265 + (int)this.percent, 236);
                Render.drawBitmap(GUI.guiImage, false);
                if (!Globals.fetchedLocale) {
                    Globals.fetchLocalization();
                }
                if (!this.manager.update() || Fader.inFade()) break;
                Fader.initFadeOut(new FaderListener(){

                    @Override
                    public void onDone() {
                        Audio.initSounds(myCanvas.this.manager, true);
                        Audio.playSound(Audio.FX_SPLASH);
                        ArcadeCanvas.GameState = 3;
                        ArcadeCanvas.worldTicks = 0;
                        Fader.setFadeOff();
                    }
                });
                break;
            }
            case 3: {
                uisplash.tickSplash(worldTicks);
                if (worldTicks <= 48 || !uisplash.splashDone) break;
                if (mySocial != null) {
                    mySocial.initSocial();
                    mySocial.loginSocial();
                }
                mySaveGame.generateNewgame(1);
                uimenu.init();
                break;
            }
            case 7: 
            case 24: 
            case 27: {
                SpriteList.renderList(5, myWorld, sprites);
                SpriteList.renderList(6, myWorld, sprites);
                SpriteList.renderList(10, myWorld, sprites);
                Render.setAlpha(255);
                tx = 0;
                tx2 = -World.offsetX;
                if (World.world == 2 && !World.inDoors) {
                    Render.setARGB(255, 0, 0, 0);
                    ty = 464 - World.offsetY / 4;
                    for (tx = -World.offsetX % 96; tx < Render.width; tx += 96) {
                        Render.dest.set(tx, ty, tx + 96, ty + 31);
                        Render.src.set(416, 0, 512, 31);
                        Render.drawBitmap(sprites[1], false);
                    }
                    if (ty > 0) {
                        Render.fillRect(0, 0, Render.width, ty);
                    }
                }
                SpriteList.renderList(7, myWorld, sprites);
                myPlayer.renderTarget(sprites[0]);
                if (GameState != 24 || Globals.isDesktop || Globals.isAndroidTV) break;
                uiinventory.tickSettings(sprites[0], worldTicks, myPlayer);
                break;
            }
            case 23: {
                uiworldintro.renderPostlight(worldTicks);
                break;
            }
            case 30: {
                SpriteList.renderList(5, myWorld, sprites);
                SpriteList.renderList(6, myWorld, sprites);
                SpriteList.renderList(10, myWorld, sprites);
                uigamestats.renderPostlight(worldTicks);
                break;
            }
            case 99: {
                GameInput.convertMouseToScreenCoords();
                SpriteList.renderList(10, myWorld, sprites);
                leveleditor.render();
                break;
            }
            case 22: {
                uibossintro.renderPostlight(worldTicks);
            }
        }
        myFader.updateFade();
        myFader.renderFader();
    }

    @Override
    public final void GameLoop() {
        Trainer.onFrameUpdate(this);
        GameInput.convertMouseToScreenCoords();
        if (secondPassed) {
            mySaveGame.increasePlaytime();
            secondPassed = false;
        }
        if (GameInput.isMouse && !myCanvas.activePlayer.ignoreMouseAim && GameInput.cursorX > 0.0f && GameInput.cursorY > 0.0f) {
            tx = myCanvas.myPlayer.x - World.offsetX;
            ty = myCanvas.myPlayer.y - World.offsetY;
            myCanvas.myPlayer.mouseAim = true;
            myCanvas.myPlayer.autoAim = false;
            myCanvas.myPlayer.stick2OffsetX = (int)(GameInput.cursorX - (float)tx);
            myCanvas.myPlayer.stick2OffsetY = (int)(GameInput.cursorY - (float)ty);
        }
        SpriteList.resetList();
        Light.resetLights();
        myWorld.update(myPlayer);
        if (World.moveThroughDoor && !Fader.inFade() && !myCanvas.myPlayer.died) {
            myCanvas.moveThroughDoorHandling();
        }
        FXEntityList.update(myPlayer, myWorld);
        if (!World.inDoors) {
            if (World.hasRain) {
                World.doRain = true;
                if (Globals.getRandomForcedUnseeded(16) > 4) {
                    int i = 4;
                    while (--i >= 0) {
                        FXEntityList.add(18, World.offsetX + Globals.getRandomForcedUnseeded(Render.width), World.offsetY - (11 + Globals.getRandomForcedUnseeded(16)), 0, null);
                    }
                }
            } else if (World.world == 3 && Globals.getRandomForcedUnseeded(16) > 4 && World.worldAge % 4 == 0) {
                int i = 2;
                while (--i >= 0) {
                    FXEntityList.add(18, World.offsetX + Globals.getRandomForcedUnseeded(Render.width), World.offsetY - (11 + Globals.getRandomForcedUnseeded(16)), 1, null);
                    FXEntityList.add(18, World.offsetX + Render.width, World.offsetY + Globals.getRandomForcedUnseeded(Render.height), 1, null);
                }
            } else if (World.world == 2 && Globals.getRandomForcedUnseeded(16) > 4 && World.worldAge % 16 == 0) {
                FXEntityList.add(18, World.offsetX + Globals.getRandomForcedUnseeded(Render.width), World.offsetY - (11 + Globals.getRandomForcedUnseeded(16)), 2, null);
            }
        }
        if (World.inDoors) {
            SceneryIndoorEntityList.update(myPlayer, myWorld);
        } else {
            SceneryEntityList.update(myPlayer, myWorld);
        }
        MonsterEntityList.update(myPlayer, myWorld);
        if (World.inBossfight) {
            BossEntityList.update(myPlayer, myWorld);
        }
        BulletEntityList.update(myPlayer, myWorld);
        myPlayer.update(myWorld);
        myWorld.handleCamera(myPlayer);
        myCanvas.setAmbientLight();
        myCanvas.renderScene();
        if (worldTicks % 16 == 0 && mySocial != null) {
            mySocial.updateSocial();
        }
    }

    public static void renderScene() {
        int rTile;
        int y;
        int x;
        block33: {
            block32: {
                if (World.inDoors || World.inVents) break block32;
                ty = 232 - World.offsetY / 8;
                for (tx = -(World.offsetX / 6) % 128; tx < Render.width; tx += 128) {
                    Render.dest.set(tx, ty, tx + 128, ty + 256);
                    Render.src.set(0, 0, 128, 256);
                    Render.drawBitmap(sprites[1], false);
                    if (ty <= 0) continue;
                    Render.dest.set(tx, ty - 32, tx + 128, ty);
                    Render.src.set(288, 177, 416, 209);
                    Render.drawBitmap(sprites[1], false);
                }
                ty = 346 - World.offsetY / 6;
                for (tx = -(World.offsetX / 4) % 272; tx < Render.width; tx += 272) {
                    Render.dest.set(tx, ty, tx + 272, ty + 128);
                    Render.src.set(0, 256, 272, 384);
                    Render.drawBitmap(sprites[1], false);
                }
                myCanvas.renderClouds();
                ty = 504 - World.offsetY / 4;
                for (tx = -(World.offsetX / 3) % 240; tx < Render.width; tx += 240) {
                    Render.dest.set(tx, ty, tx + 240, ty + 160);
                    Render.src.set(272, 224, 512, 384);
                    Render.drawBitmap(sprites[1], false);
                }
                block0 : switch (World.world) {
                    default: {
                        ty = 1024 - World.offsetY / 2;
                        for (tx = -(World.offsetX / 2) % 512; tx < Render.width; tx += 512) {
                            Render.dest.set(tx, ty, tx + 512, ty + 128);
                            Render.src.set(0, 384, 512, 512);
                            Render.drawBitmap(sprites[1], false);
                        }
                        break block33;
                    }
                    case 2: {
                        ty = 1024 - World.offsetY / 2;
                        for (tx = -(World.offsetX / 2) % 512; tx < Render.width; tx += 512) {
                            Render.dest.set(tx, ty, tx + 512, ty + 89);
                            Render.src.set(0, 384, 512, 473);
                            Render.drawBitmap(sprites[1], false);
                            Render.dest.set(tx, ty + 119, tx + 512, ty + 128);
                            Render.src.set(0, 503, 512, 512);
                            Render.drawBitmap(sprites[1], false);
                        }
                        for (tx = -(World.offsetX / 2 % 512) + World.waterStreams[0]; tx < Render.width; tx += 512) {
                            Render.dest.set(tx, ty + 89, tx + 512, ty + 89 + 10);
                            Render.src.set(0, 473, 512, 483);
                            Render.drawBitmap(sprites[1], false);
                        }
                        for (tx = -(World.offsetX / 2 % 512) + World.waterStreams[1]; tx < Render.width; tx += 512) {
                            Render.dest.set(tx, ty + 89 + 10, tx + 512, ty + 89 + 20);
                            Render.src.set(0, 483, 512, 493);
                            Render.drawBitmap(sprites[1], false);
                        }
                        tx = -(World.offsetX / 2 % 512) + World.waterStreams[2];
                        while (tx < Render.width) {
                            Render.dest.set(tx, ty + 89 + 20, tx + 512, ty + 89 + 30);
                            Render.src.set(0, 493, 512, 503);
                            Render.drawBitmap(sprites[1], false);
                            tx += 512;
                        }
                        break block33;
                    }
                }
            }
            if (World.inVents) {
                for (tx = -World.offsetX % 64; tx < Render.width; tx += 32) {
                    for (ty = -World.offsetY % 64; ty < Render.height; ty += 32) {
                        Render.dest.set(tx, ty, tx + 32, ty + 32);
                        Render.src.set(384, 336, 416, 368);
                        Render.drawBitmap(sprites[0], false);
                    }
                }
            } else if (World.inPopup && !World.inPopupOwnBackground) {
                for (tx = -World.offsetX % 64; tx < Render.width; tx += 64) {
                    for (ty = -World.offsetY % 64; ty < Render.height; ty += 64) {
                        Render.dest.set(tx, ty, tx + 64, ty + 64);
                        Render.src.set(384, 272, 448, 336);
                        Render.drawBitmap(sprites[0], false);
                    }
                }
            } else {
                for (tx = -World.offsetX % 64; tx < Render.width; tx += 64) {
                    for (ty = -World.offsetY % 64; ty < Render.height; ty += 64) {
                        Render.dest.set(tx, ty, tx + 64, ty + 64);
                        Render.src.set(288, 48, 352, 112);
                        Render.drawBitmap(sprites[1], false);
                    }
                }
            }
        }
        if (!World.inVents) {
            Render.setAlpha(255);
            tx = 0;
            tx2 = -World.offsetX;
            for (x = 0; x < 196; ++x) {
                ty2 = -World.offsetY;
                for (y = 0; y < 132; ++y) {
                    tile = World.tileMap[x + y * 196];
                    rTile = World.renderMap[x + y * 196];
                    if (tx2 > -16 && ty2 > -16 && rTile >= 0) {
                        Render.dest.set(tx2, ty2, tx2 + 16, ty2 + 16);
                        Render.src.set(128 + (rTile % 10 << 4), 48 + (rTile / 10 << 4), 144 + (rTile % 10 << 4), 64 + (rTile / 10 << 4));
                        Render.drawBitmap(sprites[1], false);
                    }
                    if ((ty2 += 16) > Render.height) break;
                }
                if ((tx2 += 16) > Render.width) break;
            }
        }
        SpriteList.renderList(4, myWorld, sprites);
        SpriteList.renderList(0, myWorld, sprites);
        SpriteList.renderList(1, myWorld, sprites);
        Render.setAlpha(255);
        if (World.hasFoliage && !World.inVents) {
            tx = 0;
            tx2 = -World.offsetX;
            for (int x2 = 0; x2 < 196; ++x2) {
                ty2 = -World.offsetY;
                for (int y2 = 0; y2 < 132; ++y2) {
                    rTile = World.foliageMap[x2 + y2 * 196];
                    if (tx2 > -32 && ty2 > -32 && rTile > 0) {
                        int rotate = World.foliageRotateMap[x2 + y2 * 196];
                        Render.dest.set(tx2, (ty2 += World.yOffsetMap[x2 + (y2 + 1) * 196]) + 2, tx2 + 16, ty2 + 18);
                        Render.src.set(128 + (rTile % 10 << 4), 48 + (rTile / 10 << 4), 144 + (rTile % 10 << 4), 64 + (rTile / 10 << 4));
                        Render.drawBitmapRotated(sprites[1], Render.src, Render.dest, rotate, 8, 16, false);
                        ty2 -= World.yOffsetMap[x2 + (y2 + 1) * 196];
                    }
                    if ((ty2 += 16) > Render.height) break;
                }
                if ((tx2 += 16) > Render.width) break;
            }
        }
        Render.setAlpha(255);
        tx = 0;
        tx2 = -World.offsetX;
        for (x = 0; x < 196; ++x) {
            ty2 = -World.offsetY;
            for (y = 0; y < 132; ++y) {
                tile = World.tileMap[x + y * 196];
                rTile = World.renderMap[x + y * 196];
                if (tx2 > -16 && ty2 > -16 && rTile >= 0 && tile >= 2 && tile <= 4) {
                    Render.dest.set(tx2, ty2, tx2 + 16, ty2 + 16);
                    Render.src.set(128 + (rTile % 10 << 4), 48 + (rTile / 10 << 4), 144 + (rTile % 10 << 4), 64 + (rTile / 10 << 4));
                    Render.drawBitmap(sprites[1], false);
                }
                if ((ty2 += 16) > Render.height) break;
            }
            if ((tx2 += 16) > Render.width) break;
        }
    }

    public static final void renderClouds() {
        block8: {
            block7: {
                if (World.world == 5) break block7;
                if (World.world != 6) break block8;
            }
            return;
        }
        for (int i = 3; i >= 0; --i) {
            if (!paused) {
                int n = i;
                World.cloudX[n] = World.cloudX[n] - (1 + i);
                if (World.cloudX[i] / 32 < -64) {
                    World.cloudX[i] = 0;
                }
            }
            ty = (2112 - (360 - i * 76)) / 11 - World.offsetY / 11;
            for (tx = World.cloudX[i] / 32 - World.offsetX / (10 - i) % 64; tx < Render.width; tx += 64) {
                Render.dest.set(tx, ty, tx + 64, ty + 8);
                Render.src.set(128, i * 8, 192, i * 8 + 8);
                Render.drawBitmap(sprites[1], false);
                if (i != 0 || ty <= 0) continue;
                Render.dest.set(tx, ty - 8, tx + 64, ty);
                Render.src.set(128, 32, 192, 40);
                Render.drawBitmap(sprites[1], false);
            }
        }
    }

    public final void renderPickupmessages() {
        int i;
        Render.setAlpha(255);
        for (i = 0; i < World.pickupMessages.length; ++i) {
            if (World.pickupMessages[i].unused) continue;
            if (World.pickupMessages[i].itemDelay > 16 || World.pickupMessages[i].itemDelay % 4 < 2) {
                tx = World.pickupMessages[i].x - World.offsetX;
                ty = World.pickupMessages[i].y - World.offsetY;
                tx = Render.width * tx / World.gameloopW;
                ty = Render.height * ty / World.gameloopH;
                if (World.pickupMessages[i].itemType == 10) {
                    GUI.renderText(World.pickupMessages[i].myText, 0, tx, ty, 200, 1, 1);
                } else if (World.pickupMessages[i].itemType == 11) {
                    GUI.setCentered(true);
                    GUI.renderText("" + World.pickupMessages[i].itemAmount, 0, 0, ty, Render.width, 1);
                    GUI.renderText(World.pickupMessages[i].myText, 0, 0, ty += GUI.getLastTextHeight(), Render.width, 1, 0);
                    GUI.setCentered(false);
                } else {
                    GUI.renderText(World.pickupMessages[i].myText, 0, tx, ty, 200, 1, 0);
                }
            }
            World.pickupMessages[i].update();
        }
        Render.setARGB(255, 255, 255, 255);
        for (i = 0; i < World.pickupNameHover.length; ++i) {
            if (World.pickupNameHover[i].unused) continue;
            if (World.pickupNameHover[i].itemDelay > 16 || World.pickupNameHover[i].itemDelay % 4 < 2) {
                World.pickupNameHover[i].update();
                tx = World.pickupNameHover[i].x - World.offsetX;
                ty = World.pickupNameHover[i].y - World.offsetY;
                tx = Render.width * tx / World.gameloopW;
                ty = Render.height * ty / World.gameloopH;
                GUI.renderText(World.pickupNameHover[i].myText, 0, tx + 16, ty, 200, 1, 0);
                Render.fillRect(tx + 16 + (World.pickupNameHover[i].w >> 1), ty + 16, 1, 8);
            }
            World.pickupNameHover[i].unused = true;
        }
        if (World.lastPickupItemDelay > 0) {
            tile = World.lastPickupItem;
            if (World.lastPickupItem >= 500) {
                tx2 = Globals.weapons[tile -= 500][7];
                ty2 = Globals.weapons[tile][8];
                tx = (Render.width >> 1) - (tx2 >> 1);
                ty = (Render.height >> 1) - 24;
                Render.dest.set(tx, ty, tx + tx2, ty + ty2);
                Render.src.set(Globals.weapons[tile][5], Globals.weapons[tile][6], Globals.weapons[tile][5] + tx2, Globals.weapons[tile][6] + ty2);
                Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
                GUI.setCentered(true);
                GUI.renderText(Globals.weaponNames[tile * 2], 0, 0, ty += ty2 << 1, Render.width, 0);
                GUI.setCentered(false);
            } else {
                tx2 = Globals.pickups[tile][2];
                ty2 = Globals.pickups[tile][3];
                tx = (Render.width >> 1) - (tx2 >> 1);
                ty = (Render.height >> 1) - 24;
                Render.dest.set(tx, ty, tx + tx2, ty + ty2);
                Render.src.set(Globals.pickups[tile][0], Globals.pickups[tile][1], Globals.pickups[tile][0] + tx2, Globals.pickups[tile][1] + ty2);
                Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
                GUI.setCentered(true);
                GUI.renderText(Globals.itemInfo[tile * 2], 0, 0, ty += ty2 << 1, Render.width, 0);
                GUI.setCentered(false);
            }
        }
    }

    public final void renderEnergyBars() {
        Render.setAlpha(255);
        for (int i = 0; i < World.enemyEnemybars.length; ++i) {
            if (World.enemyEnemybars[i].unused) continue;
            this.percent = World.enemyEnemybars[i].calculateWidth(10);
            int val = World.enemyEnemybars[i].value;
            World.enemyEnemybars[i].update();
            tx = World.enemyEnemybars[i].x - World.offsetX;
            ty = World.enemyEnemybars[i].y - World.offsetY;
            tx = Render.width * tx / World.gameloopW;
            ty = Render.height * ty / World.gameloopH;
            Render.dest.set(tx, ty, tx + 13, ty + 6);
            Render.src.set(548, 72, 561, 78);
            Render.drawBitmap(sprites[0], false);
            Render.dest.set(++tx, ++ty, tx + (int)this.percent, ty + 4);
            if (val < 3) {
                Render.src.set(549, 86, 549 + (int)this.percent, 90);
            } else if (this.percent < 5.0f) {
                Render.src.set(549, 82, 549 + (int)this.percent, 86);
            } else {
                Render.src.set(549, 78, 549 + (int)this.percent, 82);
            }
            Render.drawBitmap(sprites[0], false);
        }
    }

    public final void renderSignals() {
        for (int i = 0; i < World.uisignals.length; ++i) {
            World.uisignals[i].update(sprites[0]);
        }
    }

    public final void renderFrontScenery() {
        if (World.inDoors) {
            return;
        }
        Render.setAlpha(255);
        for (int i = 0; i < World.frontX.length; ++i) {
            tx = World.frontX[i] - (World.offsetX << 1);
            ty = World.frontY[i] - World.offsetY * 2;
            Render.dest.set(tx, ty, tx + 96, ty + 64);
            Render.src.set(416, 0, 512, 64);
            Render.drawBitmapRotated(sprites[1], Render.src, Render.dest, World.frontRotate[i], World.frontFlipX[i]);
            if (tx >= -80 && tx <= Render.width + 48) continue;
            World.frontX[i] = tx < 0 ? Render.width + Globals.getRandomForcedUnseeded(32) : -(96 + Globals.getRandomForcedUnseeded(32));
            int n = i;
            World.frontX[n] = World.frontX[n] + (World.offsetX << 1);
            World.frontY[i] = 1024 - World.offsetY * 2 + Globals.getRandomForcedUnseeded(64);
            if (World.frontY[i] < Render.height - 64) {
                World.frontY[i] = Render.height - 64;
            }
            World.frontRotate[i] = Globals.getRandomForcedUnseeded(16) - 8;
            World.frontFlipX[i] = Globals.getRandomForcedUnseeded(100) < 50;
        }
    }

    public static final void renderChopper(int tx, int ty) {
        Render.setAlpha(255);
        if (worldTicks % 8 < 4) {
            Render.dest.set(tx, ty, tx + 64, ty + 32);
            Render.src.set(159, 81, 223, 113);
            Render.drawBitmapRotated(sprites[0], Render.src, Render.dest, 16.0f, false);
        } else {
            Render.dest.set(tx, ty, tx + 64, ty + 32);
            Render.src.set(223, 81, 287, 113);
            Render.drawBitmapRotated(sprites[0], Render.src, Render.dest, 16.0f, false);
        }
        Light.addLightRotate(tx + 60, ty + 24, 74.0f, 132.0f, 0.7f, 0.9f, 1.0f, 1.0f, true);
        Render.dest.set(tx + 28, ty + 10, tx + 28 + 12, ty + 10 + 11);
        Render.src.set(myCanvas.myPlayer.myHead.xOffset, 457, myCanvas.myPlayer.myHead.xOffset + 12, 468);
        Render.drawBitmap(sprites[0], false);
    }

    /*
     * Enabled aggressive block sorting
     */
    @Override
    public final void renderStatusbar() {
        switch (GameState) {
            case 4: {
                uimenu.renderPostLightStartscreen(worldTicks);
                if (myCanvas.activePlayer.stickX[0] >= -8) break;
                activePlayer.resetControls(Render.width, Render.height);
                break;
            }
            case 5: {
                uimenu.renderPostLight(mySaveGame, worldTicks);
                break;
            }
            case 28: {
                Render.drawPaint(80, 32, 83, 100);
                Render.setARGB(110, 35, 49, 100);
                for (int x = 0; x < Render.width; x += 48) {
                    Render.drawRect(x, 0, 24, Render.height);
                }
                for (int y = 0; y < Render.height; y += 48) {
                    Render.drawRect(0, y, Render.width, 24);
                }
                Render.setAlpha(255);
                ty = (Render.height << 1) - 120 - GUI.getLastTextHeight();
                if (ty < 0) {
                    ty = 0;
                }
                GUI.setCentered(true);
                GUI.renderText("DEVELOPER NOTE", 0, 0, ty, Render.width, 1, 1);
                GUI.setCentered(false);
                Render.setAlpha(255);
                tx = (Render.width >> 1) - 180;
                ty = (Render.height >> 1) - 120;
                myCanvas.renderDialog(tx, ty, 110, false);
                Render.dest.set(tx, ty, tx + 114, ty + 101);
                Render.src.set(0, 0, 228, 202);
                Render.drawBitmap(sprites[3], false);
                ty = (Render.height >> 1) - 120;
                myCanvas.renderDialog(tx += 114, ty, 240, false);
                GUI.renderText("Hi! I'm Pascal the solo developer of Gunslugs:Rogue Tactics.\n\nWith this game my idea was to make a game which mixes action with stealth and tactics, giving you the freedom to take down the enemy the way you prefer!\n\nI really hope you enjoy it!", 0, tx, ty, 192, 0);
                GUI.renderText("\n\nif you do, or if you don't,  come tell me in discord.gg/orangepixel and we can talk about it!", 0, tx, ty += GUI.getLastTextHeight(), 192, 0);
                GUI.renderText("Enjoy!", 0, tx, ty += GUI.getLastTextHeight() << 1, Render.width - (tx + 32), 0);
                if (worldTicks % 48 < 24) {
                    ty += GUI.getLastTextHeight() << 1;
                    if (GameInput.isTouchscreen) {
                        GUI.renderText("touch to start", 0, tx, ty, Render.width, 0, 0);
                        GUI.fontScale = 1;
                    } else if (GameInput.isGamepad) {
                        GUI.renderText("" + GameInput.gamepads[0].mapping.visualKeyMapping[GameInput.gamepads[0].mapping.BUTTON_A] + " Okay!", 0, tx, ty, Render.width, 0, 0);
                    } else {
                        GUI.renderText("~4 Okay!", 0, tx, ty, Render.width, 0, 0);
                    }
                }
                if (!GameInput.anyButtonX(true, true)) break;
                Audio.playSound(Audio.FX_UI_POPUP);
                myCanvas.LoadGame(PROFILEID);
                GameState = 5;
                break;
            }
            case 20: {
                uicore.renderLogo(worldTicks, (Render.height >> 1) - 49, false);
                if (!(uicore.logoScale < 3.0f)) break;
                uicore.updateSlowType();
                break;
            }
            case 21: {
                uicharselect.renderPostlight(worldTicks);
                break;
            }
            case 26: {
                uiskills.renderPostlight(sprites[0], worldTicks);
                break;
            }
            case 32: {
                uidifficulty.renderPostlight(sprites[0], worldTicks);
                break;
            }
            case 31: {
                uigameover.renderContinueGame(sprites[0], worldTicks);
                break;
            }
            case 6: {
                int selectedChar;
                Render.setARGB(110, 35, 49, 100);
                for (int x = 0; x < Render.width; x += 48) {
                    Render.drawRect(x, 0, 24, Render.height);
                }
                for (int y = 0; y < Render.height; y += 48) {
                    Render.drawRect(0, y, Render.width, 24);
                }
                Render.setAlpha(255);
                ty = 24;
                GUI.setCentered(true);
                GUI.renderText(Globals.gameUIText[5], 0, 0, ty, Render.width, 1, 1);
                GUI.setCentered(false);
                Render.setAlpha(120);
                if (mySaveGame != null && myCanvas.mySaveGame.hasRandomSEED) {
                    tx = Render.width - 24 - GUI.calculateWidth("Seed:" + mySaveGame.getSeedValue(), 0);
                    ty = 24;
                    GUI.renderText("Seed:" + mySaveGame.getSeedValue(), 0, tx, ty, 320, 0);
                    GUI.renderText("Difficulty:" + Globals.difficulty[myCanvas.mySaveGame.difficulty], 0, tx, ty -= GUI.getLastTextHeight() + 4, 320, 0);
                    Render.setAlpha(255);
                }
                tx2 = tx = 32;
                ty = 50;
                GUI.renderText("Characters", 0, tx, ty, 192, 0);
                ty += GUI.getLastTextHeight();
                int oldChar = selectedChar = myCanvas.myPlayer.myType;
                for (int i = 0; i < myCanvas.mySaveGame.charUnlocked.length; ++i) {
                    if ((i != 0 || !myCanvas.activePlayer.hasGeneralUnlocked) && !myCanvas.mySaveGame.charUnlocked[i]) continue;
                    if (myCanvas.myPlayer.myType != i) {
                        Render.setAlpha(120);
                    } else {
                        Render.setAlpha(255);
                        Render.dest.set(tx + 7, ty - 16 - (pointerArrowFrame - 382) / 7, tx + 7 + 14, ty - 16 + 9 - (pointerArrowFrame - 382) / 7);
                        Render.src.set(pointerArrowFrame, 131, pointerArrowFrame + 14, 140);
                        Render.drawBitmap(sprites[0], false);
                        if (pointerArrowDelay > 0) {
                            --pointerArrowDelay;
                        } else {
                            pointerArrowDelay = 4;
                            if ((pointerArrowFrame += 14) > 467) {
                                pointerArrowFrame = 382;
                            }
                        }
                    }
                    if (myCanvas.mySaveGame.charDied[i]) {
                        myCanvas.renderAvatar(tx, ty, i - 1);
                        Render.dest.set(tx + 2, ty + 2, tx + 28, ty + 27);
                        Render.src.set(714, 125, 740, 150);
                        Render.drawBitmap(sprites[0], false);
                        GUI.renderText(Globals.gameUIText[15], 0, tx, ty + 28, 64, 0);
                    } else {
                        avatarHeadOffset = 457;
                        myCanvas.renderAvatar(tx, ty, i - 1);
                        if (GameInput.isTouchscreen && GameInput.touchReleased && GameInput.touchX >= (float)tx && GameInput.touchX <= (float)(tx + 28) && GameInput.touchY >= (float)ty && GameInput.touchY <= (float)(ty + 27) || GameInput.isMouse && GameInput.mbLeft && !GameInput.mbLeftLocked && GameInput.cursorX >= (float)tx && GameInput.cursorX <= (float)(tx + 28) && GameInput.cursorY >= (float)ty && GameInput.cursorY < (float)(ty + 28)) {
                            if (GameInput.isMouse) {
                                GameInput.mbLeftLocked = true;
                            } else {
                                GameInput.touchReleased = false;
                            }
                            Audio.playUISelect();
                            selectedChar = i;
                        }
                        GUI.renderText(Integer.toString(myCanvas.mySaveGame.charLives[i]), 0, tx + 10, ty + 28 - GUI.getLastTextHeight(), 64, 0);
                        GUI.renderText(Globals.gameUIText[16] + " " + myCanvas.mySaveGame.charXPLevel[i], 0, tx, ty + 28, 64, 0);
                        GUI.renderText(Globals.gameUIText[17] + " " + myCanvas.mySaveGame.charXP[i], 0, tx, ty + 28 + GUI.getLastTextHeight(), 64, 0);
                        Render.dest.set(tx + 2, ty + 22, tx + 2 + 6, ty + 22 + 6);
                        Render.src.set(88, 180, 94, 186);
                        Render.drawBitmap(sprites[0], false);
                        Render.setAlpha(255);
                    }
                    tx += 32;
                }
                int firstCharacter = 1;
                if (myCanvas.activePlayer.hasGeneralUnlocked) {
                    firstCharacter = 0;
                }
                if (GameInput.anyLeftPressed(true, true)) {
                    --selectedChar;
                    Audio.playUISelect();
                    while (selectedChar < firstCharacter || !myCanvas.mySaveGame.charUnlocked[selectedChar] || myCanvas.mySaveGame.charDied[selectedChar]) {
                        if (selectedChar < firstCharacter) {
                            selectedChar = 7;
                            continue;
                        }
                        --selectedChar;
                    }
                }
                if (GameInput.anyRightPressed(true, true)) {
                    ++selectedChar;
                    Audio.playUISelect();
                    while (selectedChar >= 8 || !myCanvas.mySaveGame.charUnlocked[selectedChar] || myCanvas.mySaveGame.charDied[selectedChar]) {
                        if (selectedChar >= 8) {
                            selectedChar = firstCharacter;
                            continue;
                        }
                        ++selectedChar;
                    }
                }
                if (oldChar != selectedChar) {
                    myPlayer.dropImportantStuff();
                    myPlayer.storeCharacter();
                    myPlayer.initNewGame(selectedChar);
                }
                tx = 32;
                ty = 160;
                uiworldintro.objectiveY = 24 + (GUI.getLastTextHeight() << 1);
                int snap = uiworldintro.renderMissionDialog(tx, ty, false);
                if (GameInput.isTouchscreen) {
                    ty = Render.height - 64;
                    tx = Render.width - 120;
                } else {
                    ty = Render.height - 64;
                    tx = (Render.width >> 1) - 46;
                }
                if (--snap >= 0 && snap * 3 + 1 < uiworldintro.snapshots.length) {
                    Render.dest.set(tx - 24, ty, tx + 95 - 24, ty + 41);
                    Render.src.set(708, 24, 803, 65);
                    Render.drawBitmap(sprites[0], false);
                }
                GUI.menuSelectedItem2 = 0;
                Render.setAlpha(255);
                if (!GameInput.isTouchscreen) {
                    ty = 50;
                    tx = Render.width - 192;
                    if (tx < 260) {
                        tx = 260;
                    }
                    myCanvas.renderDialog(tx, ty, 96, false);
                    GUI.renderText("Menu", 0, tx + 4, ty - 4, 192, 0);
                    ty += GUI.getLastTextHeight();
                    GUI.renderMenuOptionThin(Globals.gameUIText[1], tx += 8, ty += 4, new GUIListener(){

                        @Override
                        public void onSelected() {
                            GUI.setDefaultSelected(0);
                            ArcadeCanvas.GameState = PrePauseGamestate;
                            Audio.hardenVolumes();
                        }
                    });
                    ty = Globals.isDesktop ? (ty += 16) : (ty += 28);
                    GUI.renderMenuOptionThin(Globals.gameUIText[2], tx, ty, new GUIListener(){

                        @Override
                        public void onSelected() {
                            GUI.setDefaultSelected(0);
                            ArcadeCanvas.GameState = 11;
                        }
                    });
                    ty = Globals.isDesktop ? (ty += 16) : (ty += 28);
                    GUI.renderMenuOptionThin(Globals.gameUIText[3], tx, ty, new GUIListener(){

                        @Override
                        public void onSelected() {
                            GUI.setDefaultSelected(0);
                            uimenu.init();
                        }
                    });
                    GUI.handleMenuSelection();
                } else {
                    ty = 50;
                    tx = Render.width - 50;
                    Render.dest.set(tx, ty, tx + 40, ty + 32);
                    Render.src.set(720, 153, 760, 185);
                    Render.drawBitmap(sprites[0], false);
                    Render.dest.set(tx + 8, ty + 8, tx + 24, ty + 24);
                    Render.src.set(792, 153, 816, 177);
                    Render.drawBitmap(sprites[0], false);
                    GUI.setCentered(true);
                    GUI.renderText("continue", 0, tx - 10, ty + 32, 60, 0);
                    GUI.setCentered(false);
                    if (GameInput.touchReleased && GameInput.touchX >= (float)tx && GameInput.touchY >= (float)ty && GameInput.touchX <= (float)(tx + 48) && GameInput.touchY <= (float)(ty + 40)) {
                        GameInput.touchReleased = false;
                        GameState = PrePauseGamestate;
                        Audio.hardenVolumes();
                    }
                    Render.dest.set(tx, ty += 50, tx + 40, ty + 32);
                    Render.src.set(720, 153, 760, 185);
                    Render.drawBitmap(sprites[0], false);
                    Render.dest.set(tx + 7, ty + 7, tx + 26, ty + 26);
                    Render.src.set(762, 153, 788, 179);
                    Render.drawBitmap(sprites[0], false);
                    GUI.setCentered(true);
                    GUI.renderText("settings", 0, tx - 10, ty + 32, 60, 0);
                    GUI.setCentered(false);
                    if (GameInput.touchReleased && GameInput.touchX >= (float)tx && GameInput.touchY >= (float)ty && GameInput.touchX <= (float)(tx + 48) && GameInput.touchY <= (float)(ty + 40)) {
                        GameInput.touchReleased = false;
                        Audio.playUISelect();
                        GameState = 11;
                    }
                    Render.dest.set(tx, ty += 50, tx + 40, ty + 32);
                    Render.src.set(720, 153, 760, 185);
                    Render.drawBitmap(sprites[0], false);
                    Render.dest.set(tx + 8, ty + 7, tx + 23, ty + 27);
                    Render.src.set(872, 153, 895, 180);
                    Render.drawBitmap(sprites[0], false);
                    GUI.setCentered(true);
                    GUI.renderText("quit", 0, tx - 10, ty + 32, 60, 0);
                    GUI.setCentered(false);
                    if (GameInput.touchReleased && GameInput.touchX >= (float)tx && GameInput.touchY >= (float)ty && GameInput.touchX <= (float)(tx + 48) && GameInput.touchY <= (float)(ty + 40)) {
                        GameInput.touchReleased = false;
                        Audio.playUISelect();
                        uimenu.init();
                    }
                }
                if (!GameInput.keyboardPressed[GameInput.kbPause] || GameInput.keyboardLocked[GameInput.kbPause]) break;
                GameInput.keyboardLocked[GameInput.kbPause] = true;
                GameState = PrePauseGamestate;
                Audio.hardenVolumes();
                break;
            }
            case 10: {
                GUI.menuSelectedItem2 = 0;
                Render.drawPaint(180, 0, 0, 0);
                for (int i = 0; i < 16; ++i) {
                    if (i < 8) {
                        Render.setARGB(255, 36, 42, 38);
                    } else {
                        Render.setARGB(255 - (i - 4) * 16, 36, 42, 38);
                    }
                    Render.fillRect(0, i * 4, Render.width, 4);
                    Render.fillRect(0, Render.height - i * 4, Render.width, 4);
                }
                Render.setAlpha(uicore.menuAlpha);
                ty = 24;
                GUI.setCentered(true);
                GUI.renderText(Globals.gameUIText[6], 0, 0, ty, Render.width, 1, 1);
                GUI.setCentered(false);
                tx = (Render.width >> 1) - 108;
                ty = Render.height >> 1;
                GUI.renderMenuOptionThin(Globals.gameUIText[8], tx, ty, new GUIListener(){

                    @Override
                    public void onSelected() {
                        GUI.setDefaultSelected(0);
                    }
                });
                ty = Globals.isDesktop ? (ty += 16) : (ty += 20);
                GUI.renderMenuOptionThin(Globals.gameUIText[2], tx, ty, new GUIListener(){

                    @Override
                    public void onSelected() {
                        GUI.setDefaultSelected(0);
                        uisettings.initSettings();
                    }
                });
                ty = Globals.isDesktop ? (ty += 16) : (ty += 20);
                GUI.renderMenuOptionThin(Globals.gameUIText[7], tx, ty, new GUIListener(){

                    @Override
                    public void onSelected() {
                        GUI.setDefaultSelected(0);
                        ArcadeCanvas.GameState = 5;
                    }
                });
                GUI.handleMenuSelection();
                GUI.renderNavigateInstructions(true, true, true, Globals.gameUIText[4], Globals.gameUIText[7], new GUIListener(){

                    @Override
                    public void onCancel() {
                        super.onCancel();
                        GUI.setDefaultSelected(0);
                        ArcadeCanvas.GameState = 5;
                    }
                });
                break;
            }
            case 11: {
                Render.setAlpha(255);
                uisettings.tickSettings(worldTicks);
                break;
            }
            case 12: 
            case 13: {
                uicontrollersetup.tickControllerSetup(worldTicks);
                break;
            }
            case 14: 
            case 15: {
                uicontrollersetup.tickGamepadsetup(worldTicks);
                break;
            }
            case 16: {
                uitouchsetup.tickTouchsetup();
                break;
            }
            case 7: 
            case 27: {
                if (!World.showCodeOfConduct) {
                    this.handleInput();
                } else {
                    myCanvas.myPlayer.leftPressed = false;
                    myCanvas.myPlayer.rightPressed = false;
                    myCanvas.myPlayer.downPressed = false;
                    myCanvas.myPlayer.upPressed = false;
                }
                this.renderPickupmessages();
                this.renderEnergyBars();
                this.renderSignals();
                if (!World.doGameOver) {
                    int dialogHeight;
                    if (World.inPlayerTalk >= 0) {
                        dialogHeight = GUI.calculateHeight(Globals.playerTalk[World.inPlayerTalk], 180, 2);
                        tx = (Render.width >> 1) - 100;
                        ty = myCanvas.myPlayer.y - ((dialogHeight += 16) + 16) - World.offsetY;
                        ty = Render.height * ty / World.gameloopH;
                        Render.setAlpha(200);
                        myCanvas.renderAvatar(tx - 32, ty - 8, myCanvas.myPlayer.myType - 1);
                        myCanvas.renderDialog(tx, ty, dialogHeight, false);
                        Render.setAlpha(255);
                        GUI.slowTick(Globals.playerTalk[World.inPlayerTalk], World.playerTalkSlowtickerLength, tx, ty, 195, 0);
                        if (World.playerTalkSlowtickerLength < World.playerTalkLength && World.worldAge % 2 == 0) {
                            ++World.playerTalkSlowtickerLength;
                        }
                    } else if (World.inInstructions) {
                        Render.setAlpha(220);
                        tx = (Render.width >> 1) - 64;
                        ty = (Render.height >> 1) + 64;
                        Render.dest.set(tx, ty + 2, tx + 128, ty + 14);
                        Render.src.set(255, 202, 382, 214);
                        Render.drawBitmap(GUI.guiImage, false);
                        Render.setAlpha(255);
                        tx2 = GUI.calculateWidth(World.instructionText, 0);
                        if (World.instructionButtonID >= 0) {
                            tx2 += 8;
                        }
                        tx = (Render.width >> 1) - (tx2 >> 1);
                        if (World.instructionButtonID >= 0) {
                            if (World.worldAge % 64 < 32) {
                                ++ty;
                            }
                            int buttonSpacing = GUI.renderButton(tx, ty, World.instructionButtonID, true, 0);
                            if (World.worldAge % 64 < 32) {
                                --ty;
                            }
                            tx += buttonSpacing;
                        }
                        GUI.renderText(World.instructionText, 0, tx, ty, Render.width, 0);
                        if (World.lastInstructionID == 3 || World.lastInstructionID == 1) {
                            tx = (Render.width >> 1) - (Globals.pickups[0][2] + 4);
                            Render.dest.set(tx, ty += GUI.getLastTextHeight() + 8, tx + Globals.pickups[0][2], ty + Globals.pickups[0][3]);
                            Render.src.set(Globals.pickups[0][0], Globals.pickups[0][1], Globals.pickups[0][0] + Globals.pickups[0][2], Globals.pickups[0][1] + Globals.pickups[0][3]);
                            Render.drawBitmap(sprites[0], false);
                            GUI.renderText(Integer.toString(World.lastInstructionVar), 0, tx += Globals.pickups[0][2] + 4, ty -= 4, 128, 0);
                        }
                        if (World.instructionShowDelay > 0) {
                            --World.instructionShowDelay;
                        } else {
                            World.inInstructions = false;
                            World.instructionButtonID = -1;
                        }
                        Render.setAlpha(255);
                    }
                    if (World.announceMessage >= 0) {
                        dialogHeight = GUI.calculateHeight(Globals.announcements[World.announceMessage], 180, 2);
                        tx = (Render.width >> 1) - 100;
                        ty = 24;
                        ty = Render.height * ty / World.gameloopH;
                        myCanvas.renderAvatar(tx - 32, ty - 8, 10);
                        myCanvas.renderDialog(tx, ty, dialogHeight += 16, false);
                        GUI.slowTick(World.announceText, World.announceTextSlowtickerLength, tx, ty, 195, 0);
                        if (World.announceTextSlowtickerLength < World.announceTextLength && World.worldAge % 2 == 0) {
                            ++World.announceTextSlowtickerLength;
                        }
                    }
                    if (World.itemAlpha > 0) {
                        Render.setAlpha(World.itemAlpha);
                        if (World.itemAvatar != null) {
                            dialogHeight = GUI.calculateHeight(World.itemText, 180, 2);
                            tx = (Render.width >> 1) - 100;
                            ty = World.itemAvatar.y - ((dialogHeight += 16) + 16) - World.offsetY;
                            if ((ty = Render.height * ty / World.gameloopH) < 32) {
                                ty = 32;
                            }
                            myCanvas.renderAvatar(tx - 32, (ty += 255 - World.itemAlpha >> 5) - 8, World.itemAvatar.parentUID);
                            myCanvas.renderDialog(tx, ty, dialogHeight, true);
                            tx = (Render.width >> 1) - 100;
                            GUI.slowTick(World.itemText, World.itemTextSlowtickerLength, tx, ty, 195, 0);
                            if (World.itemTextSlowtickerLength < World.itemTextLength && World.worldAge % 2 == 0) {
                                ++World.itemTextSlowtickerLength;
                            }
                        }
                        Render.setAlpha(255);
                    }
                }
                tx = 16;
                ty = 64;
                if (World.didObjectivePopup && (!World.isCinematic || World.inAnimation)) {
                    myCanvas.renderObjective(tx, false);
                }
                if (uicore.actionHeroShow) {
                    uicore.renderActionHero((Render.height >> 1) - 49);
                }
                if (World.doLevelDone) {
                    ty = (Render.height >> 1) - 24;
                    Render.setAlpha(255);
                    if (World.gameOverdelay <= 0) {
                        Audio.stopAllLoops();
                        myPlayer.storeCharacter();
                        myCanvas.SaveGame(PROFILEID);
                        myCanvas.initNextMissionScreenOrAnimation();
                        Trainer.onRenderOverlay(this);
                        return;
                    }
                    --World.gameOverdelay;
                } else if (World.doGameOver) {
                    ty = (Render.height >> 1) - 24;
                    uigameover.render(worldTicks);
                }
                if (!World.doGameOver && World.announceMessage < 0 && World.inPlayerTalk < 0) {
                    if (GameState != 27) {
                        this.renderHud();
                    }
                    if (World.chapterAlpha > 0) {
                        Render.setAlpha(World.chapterAlpha);
                        tx = 24;
                        ty = (Render.height >> 1) - 24;
                        GUI.setCentered(true);
                        GUI.renderText(World.chapterName, 0, 0, ty, Render.width, 1, 1);
                        GUI.setCentered(false);
                        Render.setAlpha(255);
                    } else if (World.inDoors && World.inDoorName != null) {
                        ty = 36;
                        GUI.setCentered(true);
                        GUI.renderText(World.inDoorName, 0, 0, ty, Render.width, 1, 1);
                        GUI.setCentered(false);
                    }
                }
                if (GameState == 27 && myCanvas.myAnimation.doProgress) {
                    myAnimation.progress();
                }
                if (!overlayanims.playingAnimation) break;
                overlayanims.update();
                break;
            }
            case 23: {
                uiworldintro.renderStatusbar(worldTicks, true);
                break;
            }
            case 30: {
                uigamestats.renderStatusbar(worldTicks);
                break;
            }
            case 24: {
                if (!Globals.isDesktop && !Globals.isAndroidTV) break;
                uiinventory.tickSettings(sprites[0], worldTicks, myPlayer);
                break;
            }
            case 25: {
                uimissionselect.renderStatus(sprites[2], worldTicks);
                break;
            }
            case 99: {
                leveleditor.renderStatusbar();
                break;
            }
            case 29: {
                Render.setAlpha(128);
                int i = 12;
                while (--i >= 0) {
                    tx = Globals.getRandomForcedUnseeded(Render.width) - 32;
                    ty = (Render.height >> 1) - 24 + Globals.getRandomForcedUnseeded(54);
                    tx2 = 16 + Globals.getRandomForcedUnseeded(32);
                    Render.dest.set(tx, ty, tx + tx2, ty + 1);
                    Render.src.set(382, 0, 382 + tx2, 1);
                    Render.drawBitmap(sprites[0], false);
                }
                Render.setAlpha(255);
                tx = (Render.width >> 1) - 27;
                ty = (Render.height >> 1) - 24;
                GUI.setCentered(true);
                GUI.renderText(Globals.itemInfo[unlockID * 2], 0, 0, ty, Render.width, 1);
                GUI.setCentered(false);
                tx = (Render.width >> 1) - Globals.pickups[unlockID][2];
                ty = (Render.height >> 1) - Globals.pickups[unlockID][3];
                Render.dest.set(tx, ty, tx + Globals.pickups[unlockID][2], ty + Globals.pickups[unlockID][3]);
                Render.src.set(Globals.pickups[unlockID][0], Globals.pickups[unlockID][1], Globals.pickups[unlockID][0] + Globals.pickups[unlockID][2], Globals.pickups[unlockID][1] + Globals.pickups[unlockID][3]);
                Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
                if (unlockDelay > 0) {
                    --unlockDelay;
                    break;
                }
                GameState = 7;
                break;
            }
        }
        if (GameInput.cursorX > 0.0f && GameInput.cursorY > 0.0f) {
            Render.setAlpha(255);
            tx = (int)GameInput.cursorX;
            ty = (int)GameInput.cursorY;
            if (sprites != null && sprites[0] != null && GameState != 7) {
                Render.dest.set(tx, ty, tx + 7, ty + 7);
                Render.src.set(131, 107, 138, 114);
                Render.drawBitmap(sprites[0], false);
            }
        }
        if (GameState == 7 || GameState == 27 || GameState == 23 || GameState == 30) {
            World.updateCinematicBars();
            World.renderCinematicBars();
            if (World.showCodeOfConduct) {
                tx = (Render.width >> 1) - 104;
                ty = (Render.height >> 1) - 120;
                myCanvas.renderCodeOfConduct(tx, ty, 240);
                Render.dest.set(tx + 24, ty += 8, tx + 24 + 160, ty + 50);
                Render.src.set(761, 99, 921, 149);
                Render.drawBitmap(sprites[0], false);
                GUI.setCentered(true);
                GUI.renderText("Gunslugs Code of Conduct:", 0, tx += 8, ty += 54, 192, 2);
                GUI.setCentered(false);
                GUI.renderText("Article I", 0, tx += 8, ty += GUI.getLastTextHeight() + 4, 192, 2);
                Render.setAlpha(180);
                GUI.renderText("I shall play it smart, and not rush.", 0, tx + 8, ty += GUI.getLastTextHeight() + 4, 192, 2);
                Render.setAlpha(255);
                GUI.renderText("Article II", 0, tx, ty += GUI.getLastTextHeight() + 4, 192, 2);
                Render.setAlpha(180);
                GUI.renderText("I shall open inventory by holding ", 0, tx + 8, ty += GUI.getLastTextHeight() + 4, 192, 2);
                GUI.renderButton(tx + GUI.getLastTextWidth() + 8, ty + 4, GameInput.kbSwap, true);
                Render.setAlpha(255);
                GUI.renderText("Article III", 0, tx, ty += GUI.getLastTextHeight() + 4, 192, 2);
                Render.setAlpha(180);
                GUI.renderText("I shall gain more XP using stealth.", 0, tx + 8, ty += GUI.getLastTextHeight() + 4, 192, 2);
                Render.setAlpha(255);
                GUI.renderText("Article IV", 0, tx, ty += GUI.getLastTextHeight() + 4, 192, 2);
                Render.setAlpha(180);
                GUI.renderText("I shall complete missions before I progress.", 0, tx + 8, ty += GUI.getLastTextHeight() + 4, 192, 2);
                Render.setAlpha(255);
                GUI.renderText("Article V", 0, tx, ty += GUI.getLastTextHeight() + 4, 192, 2);
                Render.setAlpha(180);
                GUI.renderText("I shall write a good review.", 0, tx + 8, ty += GUI.getLastTextHeight() + 4, 192, 2);
                ty += GUI.getLastTextHeight() + 10;
                tx = Render.width >> 1;
                if (GameInput.isTouchscreen) {
                    GUI.renderText("tap!", 0, tx -= GUI.calculateWidth("tap!", 0) >> 1, ty, Render.width, 0, 0);
                    GUI.fontScale = 1;
                } else if (GameInput.isGamepad) {
                    GUI.renderText("" + GameInput.gamepads[0].mapping.visualKeyMapping[GameInput.gamepads[0].mapping.BUTTON_A] + " Okay!", 0, tx -= GUI.calculateWidth("~2 Okay!", 0) >> 1, ty, Render.width, 0, 0);
                } else {
                    GUI.renderText("~4 Okay!", 0, tx -= GUI.calculateWidth("~4 Okay!", 0) >> 1, ty, Render.width, 0, 0);
                }
                if (GameInput.anyButtonX(true, true)) {
                    World.showCodeOfConduct = false;
                    World.triggerMissionComplete(15, 1, -1);
                }
            }
            if (!World.doGameOver && GameState != 30) {
                this.renderControls();
            }
        }
        Trainer.onRenderOverlay(this);
    }

    private void renderHud() {
        int i;
        Render.setAlpha(255);
        if (World.isCinematic) {
            return;
        }
        tx = statusX;
        ty = statusY + statusBelowY + 5;
        if (myCanvas.myPlayer.lives > 3 || World.worldAge % 64 < 32) {
            Render.dest.set(tx, ty, tx + 13, ty + 12);
            Render.src.set(64, 179, 77, 191);
            Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
        }
        GUI.renderText("" + myCanvas.myPlayer.lives, 0, tx + 20, ty, 32, 1);
        GUI.renderText("/" + myCanvas.myPlayer.maxLives, 0, tx + 20 + GUI.getLastTextWidth(), ty, 32, 0);
        if (myCanvas.myPlayer.shield > 0) {
            Render.dest.set(tx + 64, ty, tx + 64 + Globals.pickups[myCanvas.myPlayer.shieldType][2], ty + Globals.pickups[myCanvas.myPlayer.shieldType][3]);
            Render.src.set(Globals.pickups[myCanvas.myPlayer.shieldType][0], Globals.pickups[myCanvas.myPlayer.shieldType][1], Globals.pickups[myCanvas.myPlayer.shieldType][0] + Globals.pickups[myCanvas.myPlayer.shieldType][2], Globals.pickups[myCanvas.myPlayer.shieldType][1] + Globals.pickups[myCanvas.myPlayer.shieldType][3]);
            Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
            GUI.renderText(Integer.toString(myCanvas.myPlayer.shield), 0, tx + 72, ty, 64, 0, 1);
        }
        tx = (Render.width >> 1) - 12;
        ty = statusY + statusBelowY;
        Render.dest.set(tx, ty, tx + 18, ty + 32);
        Render.src.set(512, 138, 530, 170);
        Render.drawBitmap(sprites[0], false);
        Render.dest.set(tx + 18, ty, tx + 36, ty + 32);
        Render.src.set(694, 138, 712, 170);
        Render.drawBitmap(sprites[0], false);
        tx += 18;
        ty += 16;
        int weapon = myCanvas.myPlayer.myWeaponID;
        if (myCanvas.myPlayer.holdingInventoryItem >= 0) {
            tx2 = Globals.pickups[weapon][2];
            ty2 = Globals.pickups[weapon][3];
            weapon = myCanvas.myPlayer.holdingInventoryItem;
            Render.dest.set(tx - (tx2 >> 1), ty - (ty2 >> 1), tx + (tx2 >> 1), ty + (ty2 >> 1));
            Render.src.set(Globals.pickups[weapon][0], Globals.pickups[weapon][1], Globals.pickups[weapon][0] + Globals.pickups[weapon][2], Globals.pickups[weapon][1] + Globals.pickups[weapon][3]);
            Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
        } else {
            tx2 = Globals.weapons[weapon][7];
            ty2 = Globals.weapons[weapon][8];
            Render.dest.set(tx - (tx2 >> 1), ty - (ty2 >> 1), tx + (tx2 >> 1), ty + (ty2 >> 1));
            Render.src.set(Globals.weapons[weapon][5], Globals.weapons[weapon][6] + Globals.weapons[weapon][8], Globals.weapons[weapon][5] + Globals.weapons[weapon][7], Globals.weapons[weapon][6] + Globals.weapons[weapon][8] * 2);
            Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
            Render.dest.set(tx - (tx2 >> 1), ty - (ty2 >> 1), tx + (tx2 >> 1), ty + (ty2 >> 1));
            Render.src.set(Globals.weapons[weapon][5], Globals.weapons[weapon][6], Globals.weapons[weapon][5] + Globals.weapons[weapon][7], Globals.weapons[weapon][6] + Globals.weapons[weapon][8]);
            Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
            if (myCanvas.myPlayer.weaponSlotID == 1 && myCanvas.myPlayer.weaponAmmoType >= 0) {
                int w = Globals.ammoPickupsStatusbar[0][2];
                int h = Globals.ammoPickupsStatusbar[0][3];
                int ammoType = Globals.weapons[weapon][13];
                ty = statusY + statusBelowY;
                if (myCanvas.myPlayer.ammoTypes[ammoType] > 0) {
                    GUI.renderText("" + myCanvas.myPlayer.ammoTypes[ammoType], 0, tx + 16, ty, 64, 1);
                }
            }
        }
        if (World.inDoors && !World.inPopup && World.securityAlarmLevel > 0) {
            tx = (Render.width >> 1) - 32;
            ty = statusY + statusBelowY + 70;
            this.percent = 0.62f * (float)World.securityAlarmLevel;
            Render.dest.set(tx, ty, tx + 64, ty + 6);
            Render.src.set(592, 77, 656, 83);
            Render.drawBitmap(sprites[0], false);
            Render.dest.set(++tx, ++ty, tx + (int)this.percent, ty + 4);
            if (World.securityAlarmLevel > 75) {
                Render.src.set(593, 91, 593 + (int)this.percent, 95);
            } else if (World.securityAlarmLevel > 40) {
                Render.src.set(593, 87, 593 + (int)this.percent, 91);
            } else {
                Render.src.set(593, 83, 593 + (int)this.percent, 87);
            }
            Render.drawBitmap(sprites[0], false);
        }
        tx = (Render.width >> 1) + 76;
        ty = statusY + statusBelowY + 5;
        Render.dest.set(tx, ty, tx + 10, ty + 11);
        Render.src.set(78, 180, 88, 191);
        Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
        GUI.renderText("" + World.coins, 0, tx + 18, ty, 96, 1);
        tx = statusX + 10;
        ty = statusY + statusBelowY + 20;
        int item = myCanvas.myPlayer.shoeType;
        if (item > 0) {
            Render.dest.set(tx, ty, tx + Globals.pickups[item][2], ty + Globals.pickups[item][3]);
            Render.src.set(Globals.pickups[item][0], Globals.pickups[item][1], Globals.pickups[item][0] + Globals.pickups[item][2], Globals.pickups[item][1] + Globals.pickups[item][3]);
            Render.drawBitmap(sprites[0], false);
            tx += Globals.pickups[item][2] + 4;
        }
        for (i = 1; i < 44; ++i) {
            if (Globals.pickups[i][8] >= 3 || !myPlayer.hasInventoryItem(i)) continue;
            Render.dest.set(tx, ty, tx + Globals.pickups[i][2], ty + Globals.pickups[i][3]);
            Render.src.set(Globals.pickups[i][0], Globals.pickups[i][1], Globals.pickups[i][0] + Globals.pickups[i][2], Globals.pickups[i][1] + Globals.pickups[i][3]);
            Render.drawBitmap(sprites[0], false);
            if (myPlayer.getInventoryItemUsageCount(i) > 1) {
                GUI.renderText(Integer.toString(myPlayer.getInventoryItemUsageCount(i)), 0, tx, ty, 64, 0);
            }
            tx += Globals.pickups[i][2] + 4;
        }
        tx = Render.width - 16;
        ty = statusY + statusBelowY + 16;
        for (i = 1; i < 44; ++i) {
            if (Globals.pickups[i][8] != 6 || !myPlayer.hasInventoryItem(i)) continue;
            Render.dest.set(tx -= Globals.pickups[i][2] + 4, ty, tx + Globals.pickups[i][2], ty + Globals.pickups[i][3]);
            Render.src.set(Globals.pickups[i][0], Globals.pickups[i][1], Globals.pickups[i][0] + Globals.pickups[i][2], Globals.pickups[i][1] + Globals.pickups[i][3]);
            Render.drawBitmap(sprites[0], false);
            if (myPlayer.getInventoryItemUsageCount(i) > 1) {
                GUI.renderText(Integer.toString(myPlayer.getInventoryItemUsageCount(i)), 0, tx, ty, 64, 0);
            }
            if (i == 13) {
                this.percent = (float)Globals.pickups[i][3] / ((float)myCanvas.myPlayer.maxReapedSouls * 1.0f) * (float)myCanvas.myPlayer.reapedSouls;
                Render.dest.set(tx, ty + Globals.pickups[i][3] - (int)this.percent, tx + Globals.pickups[i][2], ty + Globals.pickups[i][3]);
                Render.src.set(Globals.pickups[i][0] + Globals.pickups[i][2], Globals.pickups[i][1] + Globals.pickups[i][3] - (int)this.percent, Globals.pickups[i][0] + Globals.pickups[i][2] + Globals.pickups[i][2], Globals.pickups[i][1] + Globals.pickups[i][3]);
                Render.drawBitmap(sprites[0], false);
            }
            if ((tx2 = myPlayer.getInventoryItemFlash(myPlayer.getInventoryItemIDX(i))) <= 0) continue;
            Render.setAlpha(tx2);
            Render.dest.set(tx, ty, tx + Globals.pickups[i][2], ty + Globals.pickups[i][3]);
            Render.src.set(Globals.pickups[i][0], Globals.pickups[i][1] + Globals.pickups[i][3], Globals.pickups[i][0] + Globals.pickups[i][2], Globals.pickups[i][1] + Globals.pickups[i][3] + Globals.pickups[i][3]);
            Render.drawBitmap(sprites[0], false);
            Render.setAlpha(255);
        }
        if (World.currentBossenergy > 0) {
            tx = (Render.width >> 1) - 32;
            ty = statusY + statusBelowY + 40;
            this.percent = 62.0f / (float)World.maxBossenergy * (float)World.currentBossenergy;
            Render.dest.set(tx, ty, tx + 64, ty + 6);
            Render.src.set(592, 77, 656, 83);
            Render.drawBitmap(sprites[0], false);
            Render.dest.set(++tx, ++ty, tx + (int)this.percent, ty + 4);
            if (this.percent > 75.0f) {
                Render.src.set(593, 91, 593 + (int)this.percent, 95);
            } else if (this.percent > 40.0f) {
                Render.src.set(593, 87, 593 + (int)this.percent, 91);
            } else {
                Render.src.set(593, 83, 593 + (int)this.percent, 87);
            }
            Render.drawBitmap(sprites[0], false);
        }
        tx = Render.width - 116;
        ty = statusY + statusBelowY;
        Render.dest.set(tx, ty, tx + 100, ty + 3);
        Render.src.set(566, 74, 666, 77);
        Render.drawBitmap(sprites[0], false);
        this.percent = 100.0f / (float)myCanvas.myPlayer.targetXP * (float)myCanvas.myPlayer.currentXP;
        Render.dest.set(tx, ty, tx + (int)this.percent, ty + 3);
        Render.src.set(566, 69, 566 + (int)this.percent, 72);
        Render.drawBitmap(sprites[0], false);
        if (myCanvas.myPlayer.skillPoints > 0) {
            GUI.renderText(Globals.gameUIText[28] + myCanvas.myPlayer.skillPoints, 0, tx, ty, 100, 0);
        }
        GUI.rightAlign = true;
        GUI.renderText(myCanvas.myPlayer.currentXP + "/" + myCanvas.myPlayer.targetXP, 0, tx, ty, 100, 0);
        GUI.rightAlign = false;
        ty += GUI.getLastTextHeight();
        if (World.isSystemsDisabledCountdown > 0 && World.isSystemsDisabledCountdown <= 180 && World.inDoors) {
            GUI.setCentered(true);
            ty = (Render.height >> 1) + 24;
            GUI.renderText(Globals.gameUIText[29], 0, 0, ty, Render.width, 1);
            GUI.renderText(Integer.toString(World.isSystemsDisabledCountdown / 60), 0, 0, ty += GUI.getLastTextHeight() + 8, Render.width, 1);
            GUI.setCentered(false);
        }
    }

    private void renderControls() {
        if (GameInput.isTouchscreen) {
            float scale;
            if (World.announceMessage < 0 && World.inPlayerTalk < 0 && GameState != 23 && GameState != 30) {
                Render.setAlpha(myCanvas.activePlayer.controlsAlpha);
            } else {
                Render.setAlpha(myCanvas.activePlayer.controlsAlpha / 3);
            }
            switch (myCanvas.activePlayer.dpadScale) {
                case 0: {
                    scale = 0.7f;
                    break;
                }
                default: {
                    scale = 1.0f;
                    break;
                }
                case 2: {
                    scale = 1.3f;
                }
            }
            tx = myCanvas.activePlayer.stickX[0];
            ty = myCanvas.activePlayer.stickY[0];
            Render.dest.set(tx, ty, tx + (int)(30.0f * scale), ty + (int)(30.0f * scale));
            Render.src.set(315, 152, 345, 182);
            Render.drawBitmap(GUI.guiImage, false);
            Render.dest.set(tx + (int)(12.0f * scale), ty + (int)(10.0f * scale), tx + (int)(12.0f * scale) + (int)(6.0f * scale), ty + (int)(10.0f * scale) + (int)(10.0f * scale));
            Render.src.set(346, 152, 352, 162);
            Render.drawBitmap(GUI.guiImage, false);
            tx = myCanvas.activePlayer.stickX[1];
            ty = myCanvas.activePlayer.stickY[1];
            Render.dest.set(tx, ty, tx + (int)(30.0f * scale), ty + (int)(30.0f * scale));
            Render.src.set(315, 152, 345, 182);
            Render.drawBitmap(GUI.guiImage, false);
            Render.dest.set(tx + (int)(12.0f * scale), ty + (int)(10.0f * scale), tx + (int)(12.0f * scale) + (int)(6.0f * scale), ty + (int)(10.0f * scale) + (int)(10.0f * scale));
            Render.src.set(346, 152, 352, 162);
            Render.drawBitmap(GUI.guiImage, true);
            tx = myCanvas.activePlayer.stickX[2];
            ty = myCanvas.activePlayer.stickY[2];
            Render.dest.set(tx, ty, tx + (int)(30.0f * scale), ty + (int)(30.0f * scale));
            Render.src.set(339, 120, 369, 150);
            Render.drawBitmap(GUI.guiImage, false);
            tx = myCanvas.activePlayer.stickX[3];
            ty = myCanvas.activePlayer.stickY[3];
            Render.dest.set(tx, ty, tx + (int)(30.0f * scale), ty + (int)(30.0f * scale));
            Render.src.set(308, 120, 338, 150);
            Render.drawBitmap(GUI.guiImage, false);
            tx = myCanvas.activePlayer.stickX[4];
            ty = myCanvas.activePlayer.stickY[4];
            Render.dest.set(tx, ty, tx + (int)(30.0f * scale), ty + (int)(30.0f * scale));
            Render.src.set(370, 120, 400, 150);
            Render.drawBitmap(GUI.guiImage, false);
            tx = myCanvas.activePlayer.stickX[5];
            ty = myCanvas.activePlayer.stickY[5];
            Render.dest.set(tx, ty, tx + (int)(30.0f * scale), ty + (int)(30.0f * scale));
            Render.src.set(370, 151, 400, 181);
            Render.drawBitmap(GUI.guiImage, false);
            tx = myCanvas.activePlayer.stickX[6];
            ty = myCanvas.activePlayer.stickY[6];
            Render.dest.set(tx, ty, tx + (int)(30.0f * scale), ty + (int)(30.0f * scale));
            Render.src.set(315, 152, 345, 182);
            Render.drawBitmap(GUI.guiImage, false);
            Render.dest.set(tx + (int)(10.0f * scale), ty + (int)(12.0f * scale), tx + (int)(10.0f * scale) + (int)(10.0f * scale), ty + (int)(12.0f * scale) + (int)(6.0f * scale));
            Render.src.set(346, 163, 356, 169);
            Render.drawBitmap(GUI.guiImage, true);
            tx = (Render.width >> 1) - 7;
            ty = Render.height - 48;
            Render.dest.set(tx, ty, tx + (int)(13.0f * scale), ty + (int)(24.0f * scale));
            Render.src.set(300, 152, 313, 176);
            Render.drawBitmap(GUI.guiImage, false);
            Render.setAlpha(255);
        }
    }

    private void setDebugMode(boolean on) {
        if (isCheatOn == on) {
            return;
        }
        isCheatOn = on;
        if (isCheatOn) {
            Globals.debug("^5DEBUG MODE^0 : ON");
            Globals.debug("you are now playing in debug mode. This mode is used for testing.");
            Globals.debug("no game progress will be saved in debug mode.");
            Globals.debug("you have to quit and restart the game to undo this.");
        }
    }

    private void setupConsole() {
        commandRemap = myConsole.registerCommand("remap", "", "generates a new level", null);
        commandEdit = myConsole.registerCommand("edit", "", "start template editor", null);
        commandCrate = myConsole.registerCommand("crate", "", "drop object near player", null);
        commandBarrel = myConsole.registerCommand("barrel", "", "drop object near player", null);
        commandSoldier = myConsole.registerCommand("soldier", "", "drop object near player", null);
        commandChopper = myConsole.registerCommand("chopper", "", "drop object near player", null);
        commandWorld = myConsole.registerCommand("world", "[1-10]", "set world scenery", null);
        myConsole.setCommandRange(commandWorld, 0, 1, 10);
        commandRetro = myConsole.registerCommand("retro", "", "toggle retro effect", null);
        commandWeapon = myConsole.registerCommand("setweapon", "x", "set weapon X for player", null);
        myConsole.setCommandRange(commandWeapon, 0, 0, 19);
        commandPickup = myConsole.registerCommand("pickup", "x", "spawn pickup item near player", null);
        myConsole.setCommandRange(commandPickup, 0, 0, 44);
        commandSpawn = myConsole.registerCommand("spawn", "x", "spawns item X near player", null);
        commandSpawnEnemy = myConsole.registerCommand("spawnenemy", "", "spawns a (hard-coded)creature near player", null);
        commandSpawnWeapon = myConsole.registerCommand("spawngun", "x", "spawns gun X near player", null);
        commandBoss = myConsole.registerCommand("boss", "", "Trigger boss batle", null);
        commandEscape = myConsole.registerCommand("escape", "", "Trigger an escape chopper", null);
        commandTower = myConsole.registerCommand("tower", "", "Transports you to first tower", null);
        commandShop = myConsole.registerCommand("shop", "", "Transports you to first shop", null);
        commandCamera = myConsole.registerCommand("camera", "", "Spawn Camera above player", null);
        commandPixelsize = myConsole.registerCommand("setpixelsize", "x", "Specify vertical size for render resolution.", null);
        commandSkills = myConsole.registerCommand("skills", "", "Open skill screen.", null);
        commandCheckpoint = myConsole.registerCommand("checkpoint", "", "Reload checkpoint?", null);
        commandStats = myConsole.registerCommand("stats", "", "Open stats screen.", null);
        commandCoins = myConsole.registerCommand("coins", "", "Adds 100 coins to player inventory.", null);
        commandAnim = myConsole.registerCommand("anim", "", "triggers animation code", null);
        commandGamma = myConsole.registerCommand("gamma", "x", "set gamma value", null);
        commandTestUnlock = myConsole.registerCommand("testunlock", "x", "test unlock effect with specified item", null);
        commandTestOverlay = myConsole.registerCommand("overlay", "x", "trigger overlay animation", null);
        commandGod = myConsole.registerCommand("god", "", "completes all open missions, and gives you all health.", null);
        commandSetXY = myConsole.registerCommand("setxy", "x y", "moves player to specified tile offset.", null);
        myConsole.registerCommandListener(new ConsoleListener(){

            @Override
            public void onProcessCommand(String[] tokens) {
                boolean done;
                int m;
                int i;
                int wID;
                int itemid;
                super.onProcessCommand(tokens);
                int commandFound = ArcadeCanvas.myConsole.getCommandID(tokens[0]);
                if (commandFound == commandRemap) {
                    myCanvas.this.setDebugMode(true);
                    if (World.inDoors) {
                        BulletEntityList.resetList();
                        FXEntityList.resetList();
                        SceneryIndoorEntityList.resetList();
                        World.prepareBuilding();
                        myCanvas.createIndoor();
                    } else {
                        int curWorld = World.world;
                        myCanvas.initNewLevel(curWorld, 1);
                    }
                    ArcadeCanvas.myConsole.closeConsole();
                }
                if (commandFound == commandEdit) {
                    myCanvas.this.setDebugMode(true);
                    ArcadeCanvas.GameState = 99;
                }
                if (commandFound == commandCrate) {
                    MonsterEntityList.add(10, myCanvas.myPlayer.x + 48, myCanvas.myPlayer.y - 64, -1, null);
                }
                if (commandFound == commandBarrel) {
                    MonsterEntityList.add(5, myCanvas.myPlayer.x + 48, myCanvas.myPlayer.y - 64, 0, null);
                }
                if (commandFound == commandSoldier) {
                    MonsterEntityList.add(6, myCanvas.myPlayer.x + 48, myCanvas.myPlayer.y - 64, -1, null);
                }
                if (commandFound == commandChopper) {
                    MonsterEntityList.add(8, myCanvas.myPlayer.x + 48, myCanvas.myPlayer.y - 64, 0, null);
                }
                if (commandFound == commandWorld) {
                    int world = ArcadeCanvas.myConsole.getInteger(tokens[1]);
                    myWorld.loadWorld(world);
                }
                if (commandFound == commandGamma) {
                    int gam = ArcadeCanvas.myConsole.getInteger(tokens[1]);
                    Light.gamma = (float)gam / 50.0f;
                }
                if (commandFound == commandTestUnlock && (itemid = ArcadeCanvas.myConsole.getInteger(tokens[1])) >= 0 && itemid <= 44) {
                    myCanvas.initUnlockUsage(itemid);
                    ArcadeCanvas.myConsole.closeConsole();
                }
                if (commandFound == commandTestOverlay) {
                    ArcadeCanvas.myConsole.closeConsole();
                }
                if (commandFound == commandRetro) {
                    boolean bl = Globals.USEPOSTPROCESSING = !Globals.USEPOSTPROCESSING;
                }
                if (commandFound == commandWeapon) {
                    wID = ArcadeCanvas.myConsole.getInteger(tokens[1]);
                    myPlayer.giveWeapon(wID, -1);
                }
                if (commandFound == commandPickup) {
                    wID = ArcadeCanvas.myConsole.getInteger(tokens[1]);
                    MonsterEntityList.add(18, myCanvas.myPlayer.x + 64, myCanvas.myPlayer.y - 2, wID, null);
                }
                if (commandFound == commandSpawnEnemy) {
                    MonsterEntityList.add(34, myCanvas.myPlayer.x + 96, myCanvas.myPlayer.y + myCanvas.myPlayer.h - 32, 0, null);
                }
                if (commandFound == commandSkills) {
                    myCanvas.myPlayer.skillPoints += 2;
                    myCanvas.mySaveGame.charXPPoints[myCanvas.myPlayer.myType] = myCanvas.myPlayer.skillPoints;
                    uiskills.init();
                }
                if (commandFound == commandCheckpoint) {
                    paused = true;
                    ArcadeCanvas.GameState = 31;
                }
                if (commandFound == commandStats) {
                    uigamestats.init();
                }
                if (commandFound == commandCoins) {
                    World.coins += 100;
                }
                if (commandFound == commandSpawn && tokens.length > 0 && tokens[1] != null) {
                    wID = ArcadeCanvas.myConsole.getInteger(tokens[1]);
                    if (wID >= 44) {
                        wID = 44;
                    }
                    MonsterEntityList.add(12, myCanvas.myPlayer.x + 48, myCanvas.myPlayer.y - 80, wID, null);
                }
                if (commandFound == commandSpawnWeapon && tokens != null && tokens.length > 1) {
                    wID = ArcadeCanvas.myConsole.getInteger(tokens[1]);
                    if (wID >= 19) {
                        wID = 18;
                    }
                    MonsterEntityList.add(13, myCanvas.myPlayer.x + 48, myCanvas.myPlayer.y - 64, wID, null);
                }
                if (commandFound == commandSetXY) {
                    tx = ArcadeCanvas.myConsole.getInteger(tokens[1]);
                    ty = ArcadeCanvas.myConsole.getInteger(tokens[2]);
                    myPlayer.resetMyXY(tx << 4, ty << 4);
                }
                if (commandFound == commandPixelsize && tokens != null && tokens.length > 1) {
                    wID = ArcadeCanvas.myConsole.getInteger(tokens[1]);
                    ArcadeCanvas.setPixelSize(wID);
                }
                if (commandFound == commandBoss) {
                    myWorld.initNewLevel();
                    World.myTowerID = 0;
                    myCanvas.createBossBattle();
                    myWorld.loadWorld(World.world);
                    World.doContinue = false;
                    World.setChaptername(Globals.WORLD_CHAPTERNAMES[World.world]);
                    myPlayer.initNewLevel(24, 1824);
                    for (i = 0; i < MonsterEntityList.myListMax; ++i) {
                        if (MonsterEntityList.myList[i].myType != 17) continue;
                        MonsterEntityList.myList[i].died = true;
                    }
                    MonsterEntityList.add(17, 6, myCanvas.myPlayer.y, 0, null);
                    World.focusCameraOnPlayer(myPlayer);
                    Fader.fadeToWhite = false;
                    Fader.initFadeIn(null);
                    Audio.playBackgroundMusic(0, 80);
                    ArcadeCanvas.GameState = 7;
                }
                if (commandFound == commandEscape) {
                    m = MonsterEntityList.add(17, myCanvas.myPlayer.x + 64, myCanvas.myPlayer.y - 32, 0, null);
                    MonsterEntityList.myList[m].aiState = 2;
                    World.towerCompleted = World.totalTowers;
                }
                if (commandFound == commandTower && !World.inDoors) {
                    done = false;
                    for (m = 0; m < MonsterEntityList.myList.length && !done; ++m) {
                        if (MonsterEntityList.myList[m].deleted || MonsterEntityList.myList[m].died || MonsterEntityList.myList[m].myType != 0 || MonsterEntityList.myList[m].subType != 1) continue;
                        myPlayer.setPosition(MonsterEntityList.myList[m].x, MonsterEntityList.myList[m].y);
                        World.focusCameraOnPlayer(myPlayer);
                        done = true;
                    }
                }
                if (commandFound == commandShop && !World.inDoors) {
                    done = false;
                    for (m = 0; m < MonsterEntityList.myList.length && !done; ++m) {
                        if (MonsterEntityList.myList[m].deleted || MonsterEntityList.myList[m].died || MonsterEntityList.myList[m].myType != 0 || MonsterEntityList.myList[m].subType != 2) continue;
                        myPlayer.setPosition(MonsterEntityList.myList[m].x, MonsterEntityList.myList[m].y - 20);
                        World.focusCameraOnPlayer(myPlayer);
                        done = true;
                    }
                    if (!done) {
                        MonsterEntityList.add(0, myCanvas.myPlayer.x + 16, myCanvas.myPlayer.y + myCanvas.myPlayer.h - 8, 6, null);
                    }
                }
                if (commandFound == commandCamera) {
                    MonsterEntityList.add(49, myCanvas.myPlayer.x, myCanvas.myPlayer.y - 48, 0, null);
                }
                if (commandFound == commandAnim) {
                    myAnimation = new animdone(7);
                    myAnimation.init(myWorld, myPlayer);
                }
                if (commandFound == commandGod) {
                    myCanvas.myPlayer.maxLives = 99;
                    myCanvas.myPlayer.lives = 99;
                    for (i = 0; i < myCanvas.mySaveGame.gameMissions[World.world].length && myCanvas.mySaveGame.gameMissions[World.world][i] != null; ++i) {
                        if (!myCanvas.mySaveGame.gameMissions[World.world][i].inUse) continue;
                        myCanvas.mySaveGame.gameMissions[World.world][i].updated = true;
                        myCanvas.mySaveGame.gameMissions[World.world][i].propMissionCount = myCanvas.mySaveGame.gameMissions[World.world][i].propMissionMax;
                        myCanvas.mySaveGame.gameMissions[World.world][i].completed = true;
                        myPlayer.increaseXP(5, false, myPlayer);
                        Audio.playSound(Audio.FX_UISELECT);
                        World.missionAlphaFadeTarget = 255;
                        World.missionAlphaDelay = 128;
                        myCanvas.mySaveGame.gameMissions[World.world][i].setDescription();
                    }
                }
            }
        });
    }

    public static void initNewLevel(int missionWorld, int currentMissionTier) {
        int newMusic = Globals.getRandomForcedUnseeded(3);
        while (newMusic == Audio.lastMusicID) {
            newMusic = Globals.getRandomForcedUnseeded(3);
        }
        Audio.getMusic(newMusic);
        currentHint = Globals.getRandomForcedUnseeded(Globals.gameHints.length);
        initMapDelay = 65;
        Fader.setFadeOff();
        myWorld.initNewLevel();
        World.world = -1;
        myWorld.loadWorld(missionWorld);
        World.missionTier = currentMissionTier;
        World.missionAlphaFadeTarget = 0;
        World.showCinematicBars();
    }

    public static void initPauseMenu() {
        if (GameState == 6) {
            return;
        }
        PrePauseGamestate = GameState;
        GameState = 6;
        uicore.menuAlpha = 0;
        Light.setAmbientLight(0.1f, 0.1f, 0.12f, 1.0f);
        paused = true;
        Audio.softenVolumes();
    }

    public static void stopAllSounds() {
        Audio.stopBackgroundMusic();
        Audio.stopAllSounds();
    }

    private void handleInput() {
        myCanvas.myPlayer.mouseAim = false;
        myCanvas.myPlayer.autoAim = true;
        myCanvas.myPlayer.twinStick = false;
        myCanvas.myPlayer.leftPressed = false;
        myCanvas.myPlayer.rightPressed = false;
        myCanvas.myPlayer.downPressed = false;
        myCanvas.myPlayer.upPressed = false;
        myCanvas.myPlayer.altActionPressed = false;
        myCanvas.myPlayer.actionPressed = false;
        myCanvas.myPlayer.weaponSwapPressed = false;
        myCanvas.myPlayer.stickOffsetX = 0;
        myCanvas.myPlayer.stickOffsetY = 0;
        myCanvas.myPlayer.stick2OffsetX = 0;
        myCanvas.myPlayer.stick2OffsetY = 0;
        if (Fader.inFade() || myCanvas.myPlayer.died || World.doGameOver || myConsole != null && myConsole.isConsoleActive()) {
            return;
        }
        this.handleKeyboardMouseInput(myPlayer);
        this.handleGamepadInput(myPlayer, 0);
        this.handleTouchInput(myPlayer);
    }

    private void handleKeyboardMouseInput(PlayerEntity tmpPlayer) {
        if (GameInput.keyboardPressed[GameInput.kbPause] && !GameInput.keyboardLocked[GameInput.kbPause] || GameInput.keyboardPressed[GameInput.kbCancel] && !GameInput.keyboardLocked[GameInput.kbCancel]) {
            if (GameInput.keyboardPressed[GameInput.kbPause]) {
                GameInput.keyboardLocked[GameInput.kbPause] = true;
            }
            if (GameInput.keyboardPressed[GameInput.kbCancel]) {
                GameInput.keyboardLocked[GameInput.kbCancel] = true;
            }
            myCanvas.initPauseMenu();
        }
        if (GameInput.keyboardPressed[GameInput.kbUse] && !GameInput.keyboardLocked[GameInput.kbUse]) {
            myCanvas.myPlayer.altActionPressed = true;
        }
        if (GameInput.keyboardPressed[GameInput.kbSwap]) {
            GameInput.keyboardLocked[GameInput.kbSwap] = true;
            myCanvas.myPlayer.weaponSwapPressed = true;
        }
        if (GameInput.scrollWheelUp) {
            if (myCanvas.myPlayer.weaponSlotID != 0) {
                myCanvas.myPlayer.weaponSwapPressed = true;
            }
            GameInput.scrollWheelUp = false;
        }
        if (GameInput.scrollWheelDown) {
            if (myCanvas.myPlayer.weaponSlotID != 1) {
                myCanvas.myPlayer.weaponSwapPressed = true;
            }
            GameInput.scrollWheelDown = false;
        }
        if (GameInput.keyboardPressed[GameInput.kbAction] && !GameInput.keyboardLocked[GameInput.kbAction] || GameInput.mbLeft) {
            tmpPlayer.actionPressed = true;
        }
        if (GameInput.keyboardPressed[GameInput.kbLeft]) {
            GameInput.keyboardLocked[GameInput.kbLeft] = true;
            tmpPlayer.stickOffsetX = -16;
            tmpPlayer.leftPressed = true;
        }
        if (GameInput.keyboardPressed[GameInput.kbRight]) {
            GameInput.keyboardLocked[GameInput.kbRight] = true;
            tmpPlayer.stickOffsetX = 16;
            tmpPlayer.rightPressed = true;
        }
        if (GameInput.keyboardPressed[GameInput.kbUp]) {
            GameInput.keyboardLocked[GameInput.kbUp] = true;
            tmpPlayer.stickOffsetY = -16;
            tmpPlayer.upPressed = true;
        }
        if (GameInput.keyboardPressed[GameInput.kbDown]) {
            GameInput.keyboardLocked[GameInput.kbDown] = true;
            tmpPlayer.stickOffsetY = 16;
            tmpPlayer.downPressed = true;
        }
    }

    private void handleGamepadInput(PlayerEntity tmpPlayer, int gamepadID) {
        if (!GameInput.isGamepad) {
            return;
        }
        tmpPlayer.mouseAim = false;
        tmpPlayer.autoAim = false;
        tmpPlayer.twinStick = false;
        tmpPlayer.stickOffsetX = 0;
        tmpPlayer.stickOffsetY = 0;
        if (GameInput.gamepads[gamepadID].axis[GameInput.gpAxisX2] != tmpPlayer.stick2OffsetX || GameInput.gamepads[gamepadID].axis[GameInput.gpAxisY2] != tmpPlayer.stick2OffsetY) {
            tmpPlayer.stick2OffsetX = GameInput.gamepads[gamepadID].axisRaw[GameInput.gpAxisX2] / 4;
            tmpPlayer.stick2OffsetY = GameInput.gamepads[gamepadID].axisRaw[GameInput.gpAxisY2] / 4;
            tmpPlayer.twinStick = true;
            tmpPlayer.autoAim = false;
        }
        tmpPlayer.actionPressed = false;
        tmpPlayer.leftPressed = GameInput.anyLeftPressed(false, true);
        tmpPlayer.rightPressed = GameInput.anyRightPressed(false, true);
        tmpPlayer.downPressed = GameInput.anyDownPressed(false, true);
        if (tmpPlayer.leftPressed) {
            tmpPlayer.stickOffsetX = -16;
        }
        if (tmpPlayer.rightPressed) {
            tmpPlayer.stickOffsetX = 16;
        }
        if (tmpPlayer.downPressed) {
            tmpPlayer.stickOffsetY = 16;
        }
        if (GameInput.gamepads[gamepadID].buttonPressed[GameInput.gpButtonA] && !GameInput.gamepads[gamepadID].buttonLocked[GameInput.gpButtonA]) {
            myCanvas.myPlayer.upPressed = true;
            tmpPlayer.stickOffsetY = -16;
        }
        if (GameInput.gamepads[gamepadID].buttonPressed[GameInput.gpButtonY]) {
            GameInput.gamepads[gamepadID].buttonLocked[GameInput.gpButtonY] = true;
            tmpPlayer.altActionPressed = true;
        }
        if (GameInput.gamepads[gamepadID].buttonPressed[GameInput.gpButtonRT]) {
            GameInput.gamepads[gamepadID].buttonLocked[GameInput.gpButtonRT] = true;
            tmpPlayer.actionPressed = true;
        }
        if (GameInput.gamepads[gamepadID].buttonPressed[GameInput.gpButtonFireAlt]) {
            GameInput.gamepads[gamepadID].buttonLocked[GameInput.gpButtonFireAlt] = true;
            tmpPlayer.actionPressed = true;
        }
        if (GameInput.gamepads[gamepadID].buttonPressed[GameInput.gpButtonX]) {
            GameInput.gamepads[gamepadID].buttonLocked[GameInput.gpButtonX] = true;
            tmpPlayer.weaponSwapPressed = true;
        }
        if (GameInput.gamepads[gamepadID].buttonPressed[GameInput.gpButtonB] && !GameInput.gamepads[gamepadID].buttonLocked[GameInput.gpButtonB]) {
            GameInput.gamepads[gamepadID].buttonLocked[GameInput.gpButtonB] = true;
            myCanvas.initPauseMenu();
        }
    }

    private void handleTouchInput(PlayerEntity tmpPlayer) {
        float scale;
        if (!GameInput.isTouchscreen) {
            return;
        }
        switch (myCanvas.activePlayer.dpadScale) {
            case 0: {
                scale = 0.7f;
                break;
            }
            default: {
                scale = 1.0f;
                break;
            }
            case 2: {
                scale = 1.3f;
            }
        }
        int buttonSize = (int)(38.0f * scale);
        tmpPlayer.mouseAim = false;
        tmpPlayer.autoAim = true;
        tmpPlayer.twinStick = false;
        int tmpX = GameInput.mTouchX[0];
        int tmpY = GameInput.mTouchY[0];
        tx = (Render.width >> 1) - 7;
        ty = Render.height - 48;
        Render.dest.set(tx, ty, tx + (int)(13.0f * scale), ty + (int)(24.0f * scale));
        Render.src.set(300, 152, 313, 176);
        if (tmpX > tx - 4 && (float)tmpX < (float)tx + 18.0f * scale && tmpY > ty - 4 && (float)tmpY < (float)ty + 24.0f * scale && GameInput.touchReleased) {
            paused = true;
            myCanvas.initPauseMenu();
            GameInput.touchReleased = false;
            return;
        }
        for (int j = 0; j < GameInput.mTouchX.length; ++j) {
            if (GameInput.mTouchX[j] <= 0 || GameInput.mTouchY[j] <= 0) continue;
            tmpX = GameInput.mTouchX[j];
            tmpY = GameInput.mTouchY[j];
            if (tmpX >= myCanvas.activePlayer.stickX[0] - 8 && tmpX <= myCanvas.activePlayer.stickX[0] + buttonSize && tmpY > myCanvas.activePlayer.stickY[0] - 8 && tmpY < myCanvas.activePlayer.stickY[0] + buttonSize) {
                tmpPlayer.leftPressed = true;
                GameInput.touchReleased = false;
            }
            if (tmpX > myCanvas.activePlayer.stickX[1] - 8 && tmpX < myCanvas.activePlayer.stickX[1] + buttonSize && tmpY > myCanvas.activePlayer.stickY[1] - 8 && tmpY < myCanvas.activePlayer.stickY[1] + buttonSize) {
                tmpPlayer.rightPressed = true;
                GameInput.touchReleased = false;
            }
            if (tmpX > myCanvas.activePlayer.stickX[2] - 8 && tmpX < myCanvas.activePlayer.stickX[2] + buttonSize && tmpY > myCanvas.activePlayer.stickY[2] - 8 && tmpY < myCanvas.activePlayer.stickY[2] + buttonSize) {
                tmpPlayer.actionPressed = true;
                GameInput.touchReleased = false;
            }
            if (tmpX > myCanvas.activePlayer.stickX[3] - 8 && tmpX < myCanvas.activePlayer.stickX[3] + buttonSize && tmpY > myCanvas.activePlayer.stickY[3] - 8 && tmpY < myCanvas.activePlayer.stickY[3] + buttonSize) {
                tmpPlayer.upPressed = true;
                GameInput.touchReleased = false;
            }
            if (tmpX > myCanvas.activePlayer.stickX[4] - 8 && tmpX < myCanvas.activePlayer.stickX[4] + buttonSize && tmpY > myCanvas.activePlayer.stickY[4] - 8 && tmpY < myCanvas.activePlayer.stickY[4] + buttonSize) {
                myCanvas.myPlayer.altActionPressed = true;
                GameInput.touchReleased = false;
            }
            if (tmpX > myCanvas.activePlayer.stickX[5] - 8 && tmpX < myCanvas.activePlayer.stickX[5] + buttonSize && tmpY > myCanvas.activePlayer.stickY[5] - 8 && tmpY < myCanvas.activePlayer.stickY[5] + buttonSize) {
                myCanvas.myPlayer.weaponSwapPressed = true;
                GameInput.touchReleased = false;
            }
            if (tmpX <= myCanvas.activePlayer.stickX[6] - 8 || tmpX >= myCanvas.activePlayer.stickX[6] + buttonSize || tmpY <= myCanvas.activePlayer.stickY[6] - 8 || tmpY >= myCanvas.activePlayer.stickY[6] + buttonSize) continue;
            myCanvas.myPlayer.downPressed = true;
            GameInput.touchReleased = false;
        }
    }

    public static final void renderAvatar(int tx, int ty, int avatarID) {
        if (avatarHeadOffset < 457) {
            avatarHeadOffset = 457;
        }
        Render.dest.set(tx, ty, tx + 24, ty + 32);
        Render.src.set(512, 96, 540, 128);
        Render.drawBitmap(sprites[0], false);
        Render.dest.set(tx + 24, ty, tx + 32, ty + 32);
        Render.src.set(694, 96, 702, 128);
        Render.drawBitmap(sprites[0], false);
        Render.dest.set(tx + 8, ty + 8, tx + 8 + 12, ty + 8 + 11);
        if (avatarID == -1) {
            Render.src.set(120, avatarHeadOffset, 132, avatarHeadOffset + 11);
        } else {
            Render.src.set(avatarID * 12, avatarHeadOffset, avatarID * 12 + 12, avatarHeadOffset + 11);
        }
        if (World.worldAge % 24 == 0 && !paused) {
            avatarHeadOffset = avatarHeadOffset == 457 ? 490 : 457;
        }
        Render.drawBitmapScaled(sprites[0], Render.src, Render.dest, 2.0f, false);
    }

    public static final int renderDialog(int tx, int ty, int dialogHeight, boolean includeChatBubble) {
        int dialogTop = ty - 8;
        if (dialogHeight < 32) {
            Render.dest.set(tx - 4, dialogTop, tx + 196, dialogTop + dialogHeight - 5);
            Render.src.set(512, 139, 712, 139 + dialogHeight - 5);
            Render.drawBitmap(sprites[0], false);
            Render.dest.set(tx - 4, dialogTop += dialogHeight - 5, tx + 196, dialogTop + 5);
            Render.src.set(512, 166, 712, 171);
            Render.drawBitmap(sprites[0], false);
            dialogTop += 5;
        } else {
            Render.dest.set(tx - 4, dialogTop, tx + 196, dialogTop + 16);
            Render.src.set(512, 139, 712, 155);
            Render.drawBitmap(sprites[0], false);
            dialogTop += 16;
            for (ty2 = dialogHeight - 16; ty2 > 0; ty2 -= 8) {
                Render.dest.set(tx - 4, dialogTop, tx + 196, dialogTop + 8);
                Render.src.set(512, 147, 712, 155);
                Render.drawBitmap(sprites[0], false);
                dialogTop += 8;
            }
            Render.dest.set(tx - 4, dialogTop, tx + 196, dialogTop + 4);
            Render.src.set(512, 167, 712, 171);
            Render.drawBitmap(sprites[0], false);
            dialogTop += 4;
        }
        if (includeChatBubble) {
            tx = World.itemAvatar.x - World.offsetX;
            tx = Render.width * tx / World.gameloopW;
            Render.dest.set(tx, dialogTop - 2, tx + 8, dialogTop + 2);
            Render.src.set(512, 171, 520, 175);
            Render.drawBitmap(sprites[0], false);
        }
        return dialogTop;
    }

    public static final void renderCodeOfConduct(int tx, int ty, int dialogHeight) {
        int dialogTop = ty;
        Render.dest.set(tx, dialogTop, tx + 208, dialogTop + 16);
        Render.src.set(678, 201, 886, 217);
        Render.drawBitmap(sprites[0], false);
        dialogTop += 16;
        for (ty2 = dialogHeight - 16; ty2 > 0; ty2 -= 8) {
            Render.dest.set(tx, dialogTop, tx + 208, dialogTop + 8);
            Render.src.set(678, 210, 886, 218);
            Render.drawBitmap(sprites[0], false);
            dialogTop += 8;
        }
        Render.dest.set(tx, dialogTop, tx + 208, dialogTop + 8);
        Render.src.set(678, 225, 886, 233);
        Render.drawBitmap(sprites[0], false);
    }

    public static final int calculateObjectiveHeight() {
        int height = 0;
        for (int i = 0; i < myCanvas.mySaveGame.gameMissions[World.world].length; ++i) {
            if (!myCanvas.mySaveGame.gameMissions[World.world][i].inUse) continue;
            height += GUI.getLastTextHeight();
        }
        return height;
    }

    public static final void renderObjective(int mtx, boolean includingNonUpdated) {
        tx2 = mtx;
        if (World.missionAlphaFade <= 0) {
            return;
        }
        Render.setAlpha(World.missionAlphaFade);
        if (hadMissions && World.missionAlphaFade > 0) {
            GUI.renderText(Globals.gameUIText[12] + "[]", 0, mtx, ty, Render.width, 0);
        }
        ty += GUI.getLastTextHeight();
        tx2 += 12;
        boolean isIndoorMission = false;
        hadMissions = false;
        for (int i = 0; i < myCanvas.mySaveGame.gameMissions[World.world].length; ++i) {
            mtx = tx2;
            if (!myCanvas.mySaveGame.gameMissions[World.world][i].inUse || !myCanvas.mySaveGame.gameMissions[World.world][i].updated && !includingNonUpdated) continue;
            if (myCanvas.mySaveGame.gameMissions[World.world][i].propMissionIndoors && !isIndoorMission) {
                isIndoorMission = true;
            }
            Render.setAlpha(World.missionAlphaFade >> 1);
            hadMissions = true;
            if (myCanvas.mySaveGame.gameMissions[World.world][i].completed && myCanvas.mySaveGame.gameMissions[World.world][i].updated) {
                Render.setAlpha(World.missionAlphaFade >> 1);
                if (World.missionAlphaFade < 65) {
                    mtx -= 96 - World.missionAlphaFade;
                }
            } else if (myCanvas.mySaveGame.gameMissions[World.world][i].updated) {
                Render.setAlpha(World.missionAlphaFade);
            }
            GUI.renderText(myCanvas.mySaveGame.gameMissions[World.world][i].description, 0, mtx, ty, Render.width, 0);
            if (myCanvas.mySaveGame.gameMissions[World.world][i].completed) {
                ty2 = GUI.getLastTextWidth();
                if (ty2 > 160) {
                    ty2 = 160;
                }
                Render.dest.set(mtx, ty + 8, mtx + ty2, ty + 9);
                Render.src.set(256, 239, 256 + ty2, 240);
                Render.drawBitmap(GUI.guiImage, false);
            }
            Render.setAlpha(World.missionAlphaFade);
            ty += GUI.getLastTextHeight();
        }
        mtx -= 12;
        ty += GUI.getLastTextHeight();
        Render.setAlpha(255);
    }

    public static final void createOverworld() {
        EntitySprite myEntityForRandomGenerator;
        World.lastDoor = myEntityForRandomGenerator = new EntitySprite();
        boolean bl = World.hasRain = World.WorldHasFeature(17) && World.lastDoor.getMyRandomValue(100) > 50;
        if (World.lastDoor.getMyRandomValue(100) > 75) {
            World.hasDaylight = true;
        }
        World.putarea(0, 0, 196, 132, 0);
        World.putarea(0, 126, 196, 6, 2);
        tx = 16;
        World.totalTowers = 0;
        int maxTowers = 0;
        if (World.hasMissionsRequireBuildings()) {
            maxTowers = 2;
        } else {
            Globals.debug("no towers needed");
        }
        if (World.hasActiveMission(0, -1)) {
            maxTowers = myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionMax - myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionCount;
        }
        World.cranesRequired = 0;
        if (World.hasActiveMission(14, -1)) {
            World.cranesRequired = 1 + (myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionMax - myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionCount);
        }
        if ((World.overWorldMaxWidth = 16 + (1 + (maxTowers + World.cranesRequired / 2)) * 10 * 3 + 20) > 196) {
            World.overWorldMaxWidth = 196;
        }
        World.needWatchtowers = 0;
        if (World.hasActiveMission(19, -1)) {
            World.needWatchtowers = myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionMax;
        }
        World.needTanks = 0;
        if (World.hasActiveMission(7, 53)) {
            World.needTanks = 1 + (myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionMax - myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionCount);
        }
        int towerIntervall = (World.overWorldMaxWidth - 32) / 10;
        if (maxTowers > 0) {
            towerIntervall /= maxTowers;
        }
        boolean requestAShop = false;
        while (tx < World.overWorldMaxWidth - 20) {
            boolean requireBuilding = maxTowers > 0 && tx / 10 % towerIntervall == 0;
            int template = Globals.getRandom(WGCell.ROOM6.data.length);
            while (requireBuilding && !WorldGenerator.doesTemplateHaveBuilding(WGCell.ROOM6.data[template], 12)) {
                template = Globals.getRandom(WGCell.ROOM6.data.length);
            }
            if (!requireBuilding) {
                if (requestAShop) {
                    template = Globals.getRandom(WGCell.ROOM6.data.length);
                    while (requireBuilding && !WorldGenerator.doesTemplateHaveBuilding(WGCell.ROOM6.data[template], 35)) {
                        template = Globals.getRandom(WGCell.ROOM6.data.length);
                    }
                    requestAShop = false;
                } else if (World.needWatchtowers > 0 && tx / 10 % 2 == 0) {
                    while (!WorldGenerator.doesTemplateHaveBuilding(WGCell.ROOM6.data[template], 58)) {
                        template = Globals.getRandom(WGCell.ROOM6.data.length);
                    }
                    World.needWatchtowers -= WorldGenerator.countTemplateHasItemType(WGCell.ROOM6.data[template], 58);
                } else if (World.cranesRequired > 0 && (maxTowers == 0 && tx / 10 % 2 == 0 || maxTowers > 0 && tx / 10 % 3 == 0)) {
                    while (!WorldGenerator.doesTemplateHaveBuilding(WGCell.ROOM6.data[template], 41)) {
                        template = Globals.getRandom(WGCell.ROOM6.data.length);
                    }
                    World.cranesRequired -= WorldGenerator.countTemplateHasItemType(WGCell.ROOM6.data[template], 41);
                } else if (World.needTanks > 0 && (maxTowers == 0 || maxTowers > 0 && tx / 10 % 2 == 0)) {
                    while (!WorldGenerator.doesTemplateHaveBuilding(WGCell.ROOM6.data[template], 41)) {
                        template = Globals.getRandom(WGCell.ROOM6.data.length);
                    }
                    World.needTanks -= WorldGenerator.countTemplateHasItemType(WGCell.ROOM6.data[template], 41);
                }
            }
            WorldGenerator.overWorldTemplates[myCanvas.tx / 10] = template;
            WorldGenerator.copyTemplateToOverWorld(tx, 118, WGCell.ROOM6.data[template], myWorld, requireBuilding);
            if ((tx += 10) >= World.overWorldMaxWidth - 20 && World.overWorldMaxWidth < 196 && maxTowers == 0 && (World.needTanks > 0 || World.cranesRequired > 0 || World.needWatchtowers > 0) && (World.overWorldMaxWidth += 20) > 196) {
                World.overWorldMaxWidth = 196;
            }
            if (requireBuilding) {
                ++World.totalTowers;
                --maxTowers;
                requestAShop = true;
                continue;
            }
            if (Globals.getRandom(100) <= 70) continue;
            requestAShop = true;
        }
        World.towerHellDoorID = -1;
        if (World.hasActiveMission(9, 1)) {
            World.towerHellDoorID = World.totalTowers - 1;
        }
        World.probability();
        myWorld.createMonsterEntities(true, myPlayer);
        World.skinIt();
        MonsterEntityList.updateCount();
        if ((World.cranesRequired -= MonsterEntityList.getCountOfType(36)) > 0) {
            ty = 118;
            tx = World.overWorldMaxWidth - 8;
            while (tx > 20 && World.cranesRequired > 0) {
                if (!World.isAreaDense(tx, ty + 8, 6, 6)) {
                    MonsterEntityList.add(36, tx << 4, ty << 4, 0, null);
                    --World.cranesRequired;
                    tx -= (1 + Globals.getRandom(3)) * 10;
                    continue;
                }
                tx -= 1 + Globals.getRandom(3);
            }
        }
        if (World.world == 1) {
            for (tx = 4 + Globals.getRandomForcedUnseeded(16); tx < 196; tx += 20 + Globals.getRandomForcedUnseeded(48)) {
                if (!World.isSolidTile(tx, 131, true) || !World.isSolidTile(tx + 1, 131, true) || !World.isSolidTile(tx + 2, 131, true) || !World.isSolidTile(tx + 3, 131, true) || !World.isSolidTile(tx + 4, 131, true) || !World.isSolidTile(tx + 5, 131, true) || !World.isSolidTile(tx + 6, 131, true) || !World.isSolidTile(tx + 7, 131, true)) continue;
                SceneryEntityList.add(3, tx << 4, 0, 0, myPlayer);
            }
            for (tx = 4 + Globals.getRandomForcedUnseeded(16); tx < 196; tx += 5 + Globals.getRandomForcedUnseeded(24)) {
                if (!World.isSolidTile(tx, 131, true) || !World.isSolidTile(tx + 1, 131, true) || !World.isSolidTile(tx + 2, 131, true) || !World.isSolidTile(tx + 3, 131, true) || !World.isSolidTile(tx + 4, 131, true)) continue;
                SceneryEntityList.add(8, tx << 4, 0, 0, myPlayer);
            }
            for (tx = 2 + Globals.getRandomForcedUnseeded(8); tx < 196; tx += 8) {
                for (ty = 131; World.isSolidTile(tx, ty, false) && ty > 116; --ty) {
                }
                if (!World.isSolidTile(tx, ty + 1, true) || !World.isSolidTile(tx + 2, ty + 2, true) || World.isSolidTile(tx + 1, ty, true)) continue;
                MonsterEntityList.add(3, tx << 4, ty << 4, -1, null);
            }
        } else if (World.world == 2) {
            for (tx = 2 + Globals.getRandomForcedUnseeded(8); tx < 196; tx += 12 + Globals.getRandomForcedUnseeded(8)) {
                ty = -(Globals.getRandomForcedUnseeded(6) << 4);
                SceneryEntityList.add(9, tx << 4, ty, 0, null);
            }
            for (tx = 4 + Globals.getRandomForcedUnseeded(16); tx < 196; tx += 5 + Globals.getRandomForcedUnseeded(24)) {
                if (!World.isSolidTile(tx, 131, true) || !World.isSolidTile(tx + 1, 131, true) || !World.isSolidTile(tx + 2, 131, true) || !World.isSolidTile(tx + 3, 131, true) || !World.isSolidTile(tx + 4, 131, true) || (tx2 = SceneryEntityList.add(8, tx << 4, 0, 0, myPlayer)) < 0) continue;
                ty = SceneryEntityList.myList[myCanvas.tx2].y;
                SceneryEntityList.add(10, tx << 4, ty, 0, myPlayer);
            }
        }
        MonsterEntityList.doPreLevelPass(myPlayer, myWorld);
        SceneryEntityList.doPreLevelPass(myPlayer, myWorld);
        MonsterEntityList.logicSortBacktoFront();
    }

    public static final void createBossBattle() {
        EntitySprite myEntityForRandomGenerator;
        World.lastDoor = myEntityForRandomGenerator = new EntitySprite();
        boolean bl = World.hasRain = World.WorldHasFeature(17) && World.lastDoor.getMyRandomValue(100) > 50;
        if (World.lastDoor.getMyRandomValue(100) > 75) {
            World.hasDaylight = true;
        }
        World.overWorldMaxWidth = 80;
        World.inBossfight = true;
        World.putarea(0, 0, 196, 132, 0);
        World.putarea(0, 126, 196, 6, 2);
        World.putarea(World.overWorldMaxWidth, 0, 2, 132, 2);
        for (tx = 20; tx < World.overWorldMaxWidth - 26; tx += 7) {
            World.putarea(tx, 126, 2, 1, 0);
        }
        for (tx = 18 + World.lastDoor.getMyRandomValue(8); tx < World.overWorldMaxWidth - 26; tx += 12) {
            World.putarea(tx, 123, 2, 1, 4);
        }
        for (tx = World.lastDoor.getMyRandomValue(8); tx < World.overWorldMaxWidth; tx += 3 + World.lastDoor.getMyRandomValue(8)) {
            ty = 132 - (8 + World.lastDoor.getMyRandomValue(8));
            World.put(tx, ty, 27);
        }
        for (tx = World.lastDoor.getMyRandomValue(20); tx < World.overWorldMaxWidth; tx += 3 + World.lastDoor.getMyRandomValue(16)) {
            ty = 127;
            while (World.isSolid(tx, ty, true)) {
                --ty;
            }
            World.put(tx, ty, 16);
        }
        tx = 40;
        ty = 120;
        MonsterEntityList.add(56, tx << 4, ty << 4, 0, null);
        World.probability();
        myWorld.createMonsterEntities(true, myPlayer);
        World.skinIt();
        MonsterEntityList.doPreLevelPass(myPlayer, myWorld);
        SceneryEntityList.doPreLevelPass(myPlayer, myWorld);
        MonsterEntityList.logicSortBacktoFront();
    }

    public static final void createIndoor() {
        MonsterEntityList.resetList();
        World.inPopup = false;
        World.inDoorName = null;
        World.needSabotage = 0;
        World.needControlRoom = false;
        World.needHostage = false;
        World.needPrison = false;
        World.needHANGARDOORS = true;
        if (World.hasActiveMission(5, -1)) {
            World.needSabotage = myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionMax - myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionCount;
        }
        if (World.hasActiveMission(2, -1)) {
            World.needHostage = true;
        }
        if (World.hasActiveMission(3, -1)) {
            if (myCanvas.mySaveGame.gameMissions[World.world][World.foundMissionID].propMissionMax > 3) {
                World.needPrison = true;
            }
            World.needHostage = true;
        }
        if (World.hasActiveMission(12, -1)) {
            World.needControlRoom = true;
        }
        WorldGenerator.GenerateWorld();
        MonsterEntityList.doPreLevelPass(myPlayer, myWorld);
        MonsterEntityList.logicSortBacktoFront();
        myPlayer.initNewLevel(World.playerStartX, World.playerStartY + 8);
        World.focusCameraOnPlayer(myPlayer);
    }

    public static final void restoreOutdoors(boolean killDoor) {
        World.inDoors = false;
        World.inDoorName = null;
        myWorld.restoreOverworld();
        MonsterEntityList.resetList();
        MonsterEntityList.myListMax = World.monsterEntityListCopy.length;
        for (int i = 0; i < World.monsterEntityListCopy.length; ++i) {
            MonsterEntityList.myList[i].clone(World.monsterEntityListCopy[i]);
        }
        World.skinIt();
        myPlayer.initNewLevel(World.overWorldPlayerX, World.overWorldPlayerY);
        World.focusCameraOnPlayer(myPlayer);
        if (World.inDoorsTrigger) {
            MonsterEntity myDoor;
            if (killDoor && (myDoor = (MonsterEntity)MonsterEntityList.getEntityByUID(World.lastDoor.getUID())) != null) {
                myDoor.resetRandomValue();
                myDoor.targetX = 0;
                myDoor.xSpeedAdd = 0;
                myDoor.xSpeed = 0;
                myDoor.aiState = 900;
            }
            World.inDoorsTrigger = false;
        }
    }

    public static final void LoadGame(String profileFileName) {
        mySaveGame = new PlayerSavegame();
        Json myJson = new Json();
        Preferences prefs = Gdx.app.getPreferences(profileFileName + "svg1");
        if (!prefs.contains("svgame")) {
            Globals.debug("...no save game");
            myCanvas.mySaveGame.hasSavegame = false;
            return;
        }
        try {
            mySaveGame = myJson.fromJson(PlayerSavegame.class, prefs.getString("json", null));
            if (!mySaveGame.isCorrectVersion()) {
                Globals.debug("..error - save file is from older version");
                mySaveGame = new PlayerSavegame();
                myCanvas.mySaveGame.hasSavegame = false;
                return;
            }
            myCanvas.mySaveGame.hasSavegame = true;
        }
        catch (Exception e) {
            Globals.debug(e.getMessage());
            return;
        }
    }

    public static final void SaveGame(String profileFileName) {
        mySaveGame.grabGameState();
        Preferences prefsEditor = Gdx.app.getPreferences(profileFileName + "svg1");
        prefsEditor.putBoolean("svgame", true);
        prefsEditor.putString("json", mySaveGame.toString());
        prefsEditor.flush();
        Globals.debug("savegame(): done");
    }

    public static final void DeleteGame(String profileFileName) {
        mySaveGame.grabGameState();
        Preferences prefsEditor = Gdx.app.getPreferences(profileFileName + "svg1");
        prefsEditor.clear();
        prefsEditor.putBoolean("empty", true);
        prefsEditor.flush();
    }

    public static final void continueGame() {
        GameState = 7;
        if (World.inDoors) {
            myPlayer.setPosition(World.playerStartX, World.playerStartY + 8);
            World.focusCameraOnPlayer(myPlayer);
        } else {
            myPlayer.setPosition(World.offsetX, World.offsetY - 100);
            myCanvas.myPlayer.aiState = 4;
            myCanvas.myPlayer.aiCountdown = 128;
            myCanvas.myPlayer.ySpeed = -32;
            myCanvas.myPlayer.xSpeed = 64;
            World.focusCameraOnPlayer(myPlayer);
            for (int i = 0; i < MonsterEntityList.myListMax; ++i) {
                if (MonsterEntityList.myList[i].myType != 17) continue;
                MonsterEntityList.myList[i].died = true;
            }
            MonsterEntityList.add(17, myCanvas.myPlayer.x, myCanvas.myPlayer.y, 0, null);
        }
    }

    public static final void moveThroughDoorHandling() {
        Fader.initFadeOut(new FaderListener(){

            @Override
            public void onDone() {
                super.onDone();
                BulletEntityList.resetList();
                FXEntityList.resetList();
                SceneryIndoorEntityList.resetList();
                World.prepareBuilding();
                if (World.restoreOnNextDoor >= 0) {
                    myWorld.loadWorld(World.restoreOnNextDoor);
                    World.restoreOnNextDoor = -1;
                }
                Fader.initFadeIn(new FaderListener(){

                    @Override
                    public void onDone() {
                        super.onDone();
                        World.moveThroughDoor = false;
                    }
                });
                World.inPopup = false;
                if (World.moveThroughDoorType == 4) {
                    MonsterEntityList.resetList();
                    World.GenerateBossroom();
                    World.inDoors = true;
                    myPlayer.initNewLevel(World.playerStartX, World.playerStartY + 8);
                    World.focusCameraOnPlayer(myPlayer);
                    World.inBossfight = true;
                } else {
                    if (World.moveThroughDoorType == 8) {
                        World.restoreOnNextDoor = World.world;
                        myWorld.loadWorld(7);
                        MonsterEntityList.resetList();
                        World.GenerateSpecialBuilding(18);
                        myPlayer.initNewLevel(World.playerStartX, World.playerStartY + 8);
                        World.focusCameraOnPlayer(myPlayer);
                        return;
                    }
                    if (World.moveThroughDoorType == 9) {
                        World.restoreOnNextDoor = World.world;
                        myWorld.loadWorld(8);
                        Audio.getMusic(100);
                        Audio.playBackgroundMusic(0, 80);
                        myCanvas.unlockAchievement(18);
                        MonsterEntityList.resetList();
                        World.GenerateSpecialBuilding(21);
                        myPlayer.initNewLevel(World.playerStartX, World.playerStartY + 8);
                        World.focusCameraOnPlayer(myPlayer);
                        return;
                    }
                    if (World.moveThroughDoorType == 6) {
                        World.lastDoor.resetRandomValue();
                        World.inDoors = true;
                        myWorld.storeOverworld();
                        World.monsterEntityListCopy = new MonsterEntity[MonsterEntityList.myListMax + 1];
                        for (int i = 0; i <= MonsterEntityList.myListMax; ++i) {
                            World.monsterEntityListCopy[i] = new MonsterEntity();
                            World.monsterEntityListCopy[i].clone(MonsterEntityList.myList[i]);
                        }
                        MonsterEntityList.resetList();
                        World.overWorldPlayerX = myCanvas.myPlayer.x;
                        World.overWorldPlayerY = myCanvas.myPlayer.y;
                        World.GenerateSpecialBuilding(World.getBestStore(myPlayer));
                        myPlayer.initNewLevel(World.playerStartX, World.playerStartY + 8);
                        World.focusCameraOnPlayer(myPlayer);
                        return;
                    }
                    if (!World.inDoors) {
                        World.inDoors = true;
                        myWorld.storeOverworld();
                        World.monsterEntityListCopy = new MonsterEntity[MonsterEntityList.myListMax + 1];
                        for (int i = 0; i <= MonsterEntityList.myListMax; ++i) {
                            World.monsterEntityListCopy[i] = new MonsterEntity();
                            World.monsterEntityListCopy[i].clone(MonsterEntityList.myList[i]);
                        }
                        World.overWorldPlayerX = myCanvas.myPlayer.x;
                        World.overWorldPlayerY = myCanvas.myPlayer.y;
                        myCanvas.createIndoor();
                        World.setAnnouncement(4, 128, null);
                        return;
                    }
                    if (World.moveThroughDoorType == 7) {
                        if (Audio.lastMusicID == 100) {
                            Audio.getMusic(Globals.getRandomForcedUnseeded(2));
                            Audio.playBackgroundMusic(0, 80);
                        }
                        myCanvas.restoreOutdoors(true);
                        return;
                    }
                    if (World.moveThroughDoorType == 0 || World.moveThroughDoorType == 5) {
                        mySaveGame.removeIndoorMissions();
                        World.inDoors = false;
                        myWorld.restoreOverworld();
                        MonsterEntityList.resetList();
                        MonsterEntityList.myListMax = World.monsterEntityListCopy.length;
                        for (int i = 0; i < World.monsterEntityListCopy.length; ++i) {
                            MonsterEntityList.myList[i].clone(World.monsterEntityListCopy[i]);
                        }
                        MonsterEntity myDoor = (MonsterEntity)MonsterEntityList.getEntityByUID(World.lastDoor.getUID());
                        SceneryEntity myBuilding = (SceneryEntity)SceneryEntityList.getEntityByUID(World.lastDoor.parentUID);
                        if (myBuilding != null && !myBuilding.died) {
                            myBuilding.activate();
                        }
                        BulletEntityList.add(15, myDoor.x + 12, myDoor.y - 24, -1, -1, 200, myPlayer);
                        Globals.debug(" door type:" + myDoor.myType + "  uid:" + myDoor.getUID() + " aistate:" + myDoor.aiState);
                        Globals.debug(" last type:" + World.lastDoor.myType + "  uid:" + World.lastDoor.getUID() + " aistate:" + World.lastDoor.aiState);
                        myDoor.died = true;
                        World.lastDoor.died = true;
                        World.monsterEntityListCopy = null;
                        World.skinIt();
                        myPlayer.initNewLevel(World.overWorldPlayerX, World.overWorldPlayerY - 70);
                        myCanvas.myPlayer.aiState = 4;
                        myCanvas.myPlayer.aiCountdown = 128;
                        myCanvas.myPlayer.ySpeed = -32;
                        myCanvas.myPlayer.xSpeed = 64;
                        World.focusCameraOnPlayer(myPlayer);
                        if (!World.securityAlarmTriggedAtLeastOnce) {
                            myPlayer.increaseXP(100, true, myPlayer);
                            World.triggerMissionComplete(18, 1, 0);
                            myCanvas.unlockAchievement(15);
                        }
                        myPlayer.initNewLevel(World.overWorldPlayerX, World.overWorldPlayerY - 120);
                        return;
                    }
                    if (World.moveThroughDoorType == 3) {
                        myPlayer.setPosition(World.lastPlayerX, World.lastPlayerY);
                        World.focusCameraOnPlayer(myPlayer);
                    } else {
                        World.lastPlayerX = myCanvas.myPlayer.x;
                        World.lastPlayerY = myCanvas.myPlayer.y;
                        myPlayer.setPosition(World.specialRoomX, World.specialRoomY);
                        World.focusCameraOnPlayer(myPlayer);
                    }
                }
            }
        });
    }

    public static final void setAmbientLight() {
        if (World.inVents) {
            Light.setAmbientLight(0.2f, 0.22f, 0.2f, 1.0f);
        } else if (World.inPopup) {
            switch (World.inDoorType) {
                case 10: 
                case 13: {
                    Light.setAmbientLight(0.1f, 0.14f, 0.4f, 1.0f);
                    break;
                }
                case 21: {
                    Light.setAmbientLight(0.28f, 0.34f, 0.6f, 1.0f);
                    break;
                }
                case 15: {
                    Light.setAmbientLight(0.21f, 0.21f, 0.26f, 1.0f);
                    break;
                }
                default: {
                    Light.setAmbientLight(0.2f, 0.26f, 0.3f, 1.0f);
                    break;
                }
            }
        } else if (World.inDoors) {
            if (World.isSecurityAlarm) {
                Light.setAmbientLight(0.4f, 0.0f, 0.0f, 1.0f);
            } else {
                switch (World.world) {
                    default: {
                        Light.setAmbientLight(0.4f, 0.54f, 0.6f, 1.0f);
                        break;
                    }
                    case 1: {
                        Light.setAmbientLight(0.1f, 0.24f, 0.3f, 1.0f);
                        break;
                    }
                    case 2: {
                        Light.setAmbientLight(0.24f, 0.3f, 0.34f, 1.0f);
                        break;
                    }
                    case 3: {
                        Light.setAmbientLight(0.0f, 0.18f, 0.38f, 1.0f);
                        break;
                    }
                    case 4: {
                        Light.setAmbientLight(0.24f, 0.1f, 0.3f, 1.0f);
                        break;
                    }
                    case 5: 
                    case 6: {
                        Light.setAmbientLight(0.32f, 0.2f, 0.22f, 1.0f);
                        break;
                    }
                    case 8: {
                        Light.setAmbientLight(0.12f, 0.2f, 0.44f, 1.0f);
                        break;
                    }
                }
            }
        } else {
            switch (World.world) {
                case 1: {
                    if (World.hasDaylight) {
                        Light.setAmbientLight(0.58f, 0.64f, 0.7f, 1.0f);
                        break;
                    }
                    Light.setAmbientLight(0.48f, 0.54f, 0.5f, 1.0f);
                    break;
                }
                case 2: {
                    Light.setAmbientLight(0.24f, 0.26f, 0.28f, 1.0f);
                    Light.addLight(World.offsetX + (World.gameloopW >> 1), World.offsetY + 32, World.gameloopH << 1, 6, 0.78f, 0.77f, 0.94f, 1.0f, true);
                    break;
                }
                case 3: {
                    Light.setAmbientLight(0.34f, 0.46f, 0.54f, 1.0f);
                    Light.addLight(World.offsetX + (World.gameloopW >> 1), World.offsetY + 64, World.gameloopH, 5, 0.88f, 0.97f, 0.94f, 1.0f, true);
                    break;
                }
                case 4: {
                    Light.setAmbientLight(0.45f, 0.44f, 0.87f, 1.0f);
                    Light.addLight(World.offsetX + (World.gameloopW >> 1), World.offsetY + 32, World.gameloopH, 6, 0.92f, 0.82f, 0.64f, 1.0f, false);
                    break;
                }
                case 5: 
                case 6: {
                    Light.setAmbientLight(0.32f, 0.53f, 0.44f, 0.5f);
                    Light.addLight(World.offsetX + (World.gameloopW >> 1), World.offsetY + 64, World.gameloopH, 6, 0.92f, 0.82f, 0.52f, 1.0f, false);
                }
            }
        }
    }

    public static final void initNextMissionScreenOrAnimation() {
        if (World.world == 6) {
            PlayerProfile.increaseStat(0, 1);
            myCanvas.DeleteGame(PROFILEID);
            myAnimation = new animdone(7);
            myAnimation.init(myWorld, myPlayer);
        } else if (World.hasUncompletedMission()) {
            myCanvas.initNewLevel(World.world, 0);
            myPlayer.initNewGame(myCanvas.myPlayer.myType);
            World.doContinue = false;
            GameState = 20;
            initMapDelay = 0;
            World.showIntro = true;
            ++World.level;
        } else if (World.world == 1 && !myCanvas.activePlayer.animationScenesSeen[1]) {
            myAnimation = new animintro(1);
            myAnimation.init(myWorld, myPlayer);
        } else if (World.world == 2 && !myCanvas.activePlayer.animationScenesSeen[3]) {
            myAnimation = new animarctic(3);
            myAnimation.init(myWorld, myPlayer);
        } else if (World.world == 3 && !myCanvas.activePlayer.animationScenesSeen[4]) {
            myAnimation = new animegypt(4);
            myAnimation.init(myWorld, myPlayer);
        } else if (World.world == 4 && !myCanvas.activePlayer.animationScenesSeen[5]) {
            myAnimation = new animalien(5);
            myAnimation.init(myWorld, myPlayer);
        } else if (World.world == 5 && !myCanvas.activePlayer.animationScenesSeen[6]) {
            myAnimation = new animphatt(6);
            myAnimation.init(myWorld, myPlayer);
        } else {
            switch (World.world) {
                case 1: {
                    myCanvas.unlockAchievement(0);
                    break;
                }
                case 2: {
                    myCanvas.unlockAchievement(1);
                    break;
                }
                case 3: {
                    myCanvas.unlockAchievement(2);
                    break;
                }
                case 4: {
                    myCanvas.unlockAchievement(3);
                    break;
                }
                case 5: {
                    myCanvas.unlockAchievement(4);
                }
            }
            World.level = 1;
            World.doContinue = false;
            World.showIntro = true;
            myCanvas.initNewLevel(++World.world, 0);
            myPlayer.initNewGame(myCanvas.myPlayer.myType);
            GameState = 20;
            initMapDelay = 65;
        }
    }

    public static final void startNewGame() {
        myWorld.initNewGame();
        World.showIntro = true;
        World.inAnimation = false;
        World.world = 1;
        World.level = 1;
        myCanvas.initNewLevel(1, 1);
        myPlayer.initNewGame(myCanvas.mySaveGame.characterSequence[0]);
        myPlayer.resetInventory();
        uicharselect.init();
    }

    public static final void initUnlockUsage(int myItem) {
        World.addPickupMessage(6, myItem, null);
    }

    public static final void unlockAchievement(int achieveID) {
        if (mySocial == null || !mySocial.isConnected()) {
            return;
        }
        mySocial.uploadAchievement(achieveID);
    }

    static {
        myAnimation = new animcore();
        statusX = 24;
        statusY = 8;
        statusBelowY = 0;
        statusBelowYTarget = 23;
        hadMissions = true;
    }
}

