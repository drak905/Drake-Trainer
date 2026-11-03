/*
 * Decompiled with CFR 0.152.
 */
package com.orangepixel.utils;

import com.badlogic.gdx.ApplicationListener;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Graphics;
import com.badlogic.gdx.controllers.Controllers;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.graphics.glutils.FrameBuffer;
import com.orangepixel.adverts.Advertising;
import com.orangepixel.controller.GameInput;
import com.orangepixel.controller.MFIController;
import com.orangepixel.gunslugs.Render;
import com.orangepixel.social.NewsletterPopup;
import com.orangepixel.social.Social;
import java.util.Random;

public class ArcadeCanvas
implements ApplicationListener {
    public static final boolean IS_MAC = System.getProperty("os.name").toLowerCase().contains("mac");
    public static final boolean IS_WINDOWS = System.getProperty("os.name").toLowerCase().contains("windows");
    public static final boolean IS_LINUX = System.getProperty("os.name").toLowerCase().contains("linux");
    public boolean argument_noController = false;
    public boolean isDesktop = false;
    public boolean isAndroid = false;
    public boolean isIOS = false;
    public static boolean isAndroidTV = false;
    public static boolean isFullScreen = false;
    public static final int ININIT = 40;
    public static final int INSPLASH = 41;
    public static final int INMENU = 42;
    public static final int INGAME = 43;
    public static final int INLOADER = 44;
    public Social mySocial = null;
    public Advertising myAds = null;
    public NewsletterPopup myNewsLetter = null;
    public MFIController myMFIController = null;
    public int GameState;
    public int worldTicks;
    long loopStart;
    long loopEnd;
    long loopPause;
    public long loopControllerDetect;
    public boolean secondPassed;
    int fpsSleep;
    public int hideMouse;
    public boolean paused;
    public static int displayW;
    public static int displayH;
    public boolean switchFullScreen;
    public boolean switchFullScreenLocked;
    FrameBuffer m_fbo;
    TextureRegion m_fboRegion = null;
    public static Graphics.DisplayMode[] modes;
    public static int currentModeID;
    private static int fallbackModeID;
    public static Random randomGenerator;

    @Override
    public void create() {
        displayW = Gdx.graphics.getWidth();
        displayH = Gdx.graphics.getHeight();
        this.isDesktop = false;
        this.isAndroid = false;
        this.isIOS = false;
        switch (Gdx.app.getType()) {
            case Android: {
                this.isAndroid = true;
                GameInput.IS_ANDROID = true;
                GameInput.controller1.isTouchscreen();
                break;
            }
            case iOS: {
                this.isIOS = true;
                GameInput.IS_IOS = true;
                GameInput.controller1.isTouchscreen();
                break;
            }
            default: {
                GameInput.isDesktop = true;
                this.isDesktop = true;
            }
        }
        Render.initRender();
        Render.width = displayW / (displayH / 160);
        Render.height = 160;
        randomGenerator = new Random();
        this.engineInit();
        this.loopControllerDetect = this.loopPause = System.currentTimeMillis();
        Gdx.app.getInput().setInputProcessor(GameInput.myProcessor);
    }

    @Override
    public void dispose() {
        if (this.mySocial != null) {
            this.mySocial.disposeSocial();
        }
        Render.batch.dispose();
        if (this.myNewsLetter != null) {
            this.myNewsLetter.handlePopup();
        }
    }

    public static int PowerOf2(int n) {
        int k;
        for (k = 1; k < n; k *= 2) {
        }
        return k;
    }

    @Override
    public void resize(int width, int height) {
        displayW = width;
        displayH = height;
        Render.fullScreenWidth = width;
        Render.fullScreenHeight = height;
        Render.height = (int)((double)displayH / Math.floor(displayH / 160));
        Render.width = (int)((double)displayW / ((double)displayH / ((double)displayH / Math.floor(displayH / 160))));
        if (this.m_fbo != null) {
            this.m_fbo.dispose();
        }
        this.m_fbo = new FrameBuffer(Pixmap.Format.RGB888, ArcadeCanvas.PowerOf2(Render.width), ArcadeCanvas.PowerOf2(Render.height), false);
        ((Texture)this.m_fbo.getColorBufferTexture()).setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        this.m_fboRegion = new TextureRegion((Texture)this.m_fbo.getColorBufferTexture(), 0, this.m_fbo.getHeight() - Render.height, Render.width, Render.height);
        this.m_fboRegion.flip(false, false);
        if (GameInput.controllersFound > 0) {
            Controllers.clearListeners();
        }
        GameInput.controllersFound = 0;
    }

    @Override
    public void pause() {
    }

    @Override
    public void resume() {
    }

    @Override
    public void render() {
        if (Gdx.input.isKeyPressed(66) && (Gdx.input.isKeyPressed(57) || Gdx.input.isKeyPressed(58))) {
            if (!this.switchFullScreenLocked) {
                this.switchFullScreen = true;
                ArcadeCanvas.setDisplayMode(720, 480, !isFullScreen);
                this.switchFullScreenLocked = true;
            }
        } else {
            this.switchFullScreen = false;
            this.switchFullScreenLocked = false;
        }
        this.loopStart = System.currentTimeMillis();
        ++this.worldTicks;
        if (this.worldTicks > 1000) {
            this.worldTicks = 0;
        }
        Render.camera.setToOrtho(true, this.m_fbo.getWidth(), this.m_fbo.getHeight());
        Render.camera.update();
        Gdx.gl.glBlendFunc(770, 1);
        this.m_fbo.begin();
        Gdx.gl.glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        Gdx.gl.glClear(16384);
        if (this.GameState == 43) {
            this.GameLoop();
        } else {
            this.LogicLoop();
        }
        com.orangepixel.gunslugs.Trainer.onFrameEnd(this);
        if (Render.globalTexture != null) {
            Render.batch.end();
            Render.globalTexture = null;
        }
        this.m_fbo.end();
        Render.camera.setToOrtho(true, displayW, displayH);
        Render.camera.update();
        Render.batch.setProjectionMatrix(Render.camera.combined);
        Render.batch.begin();
        Render.batch.setBlendFunction(770, 771);
        Render.batch.setColor(1.0f, 1.0f, 1.0f, 1.0f);
        Render.batch.draw(this.m_fboRegion, 0.0f, 0.0f, (float)displayW, (float)displayH);
        Render.batch.end();
        com.orangepixel.gunslugs.Trainer.onScreenPresent(displayW, displayH);
        if (this.loopEnd - this.loopPause > 1000L) {
            this.secondPassed = true;
            this.loopPause = this.loopEnd;
            if (GameInput.controllersFound == 0) {
                GameInput.initControllers();
            }
        }
        this.loopEnd = System.currentTimeMillis();
        this.fpsSleep = this.loopEnd - this.loopStart < 24L ? 24 - (int)(this.loopEnd - this.loopStart) : 2;
        if (this.hideMouse > 0) {
            --this.hideMouse;
        } else {
            GameInput.cursorX = -1.0f;
            GameInput.cursorY = -1.0f;
            try {
                Gdx.input.setCursorCatched(true);
            } catch (Throwable ignored) {
            }
        }
        if (this.mySocial != null) {
            this.mySocial.processInfo();
        }
        if (this.isAndroid || this.isIOS) {
            try {
                Thread.sleep(this.fpsSleep);
            }
            catch (InterruptedException interruptedException) {
                // empty catch block
            }
        }
    }

    public static void setDisplayMode(int width, int height, boolean fullscreen) {
        if ("1".equals(System.getenv("TRAINER_SELFTEST"))) {
            fullscreen = false;
        }
        if (fullscreen) {
            width = Gdx.app.getGraphics().getDisplayMode().width;
            height = Gdx.app.getGraphics().getDisplayMode().height;
        } else if (width <= 0 || width > 4096 || height <= 0 || height > 4096) {
            width = 1080;
            height = 720;
        }
        if (Gdx.app.getGraphics().getWidth() == width && Gdx.app.getGraphics().getHeight() == height && isFullScreen == fullscreen) {
            return;
        }
        try {
            System.setProperty("org.lwjgl.opengl.Window.undecorated", fullscreen ? "true" : "false");
            Gdx.app.getGraphics().setWindowedMode(width, height);
        } catch (Throwable ignored) {
        }
        isFullScreen = fullscreen;
        try {
            if (isFullScreen) {
                Gdx.input.setCursorPosition(displayW >> 1, displayH >> 1);
                Gdx.input.setCursorCatched(true);
            } else {
                Gdx.input.setCursorPosition(displayW >> 1, displayH >> 1);
                Gdx.input.setCursorCatched(false);
            }
        } catch (Throwable ignored) {
        }
        GameInput.controllersFound = 0;
    }

    public static final int getRandom(int digit1) {
        return randomGenerator.nextInt(digit1);
    }

    public void engineInit() {
    }

    public void LogicLoop() {
    }

    public void GameLoop() {
    }

    static {
        currentModeID = -1;
    }
}
