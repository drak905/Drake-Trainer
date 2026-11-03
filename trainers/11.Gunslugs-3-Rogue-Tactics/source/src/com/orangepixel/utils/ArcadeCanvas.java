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
import com.orangepixel.controller.GameInput;
import com.orangepixel.controller.MFIController;
import com.orangepixel.gunslugs3.Globals;
import com.orangepixel.plugins.NewsletterPopup;
import com.orangepixel.plugins.ScriptConsole;
import com.orangepixel.plugins.Social;
import com.orangepixel.utils.Audio;
import com.orangepixel.utils.Light;
import com.orangepixel.utils.Render;

public class ArcadeCanvas
implements ApplicationListener {
    public static final boolean IS_MAC = System.getProperty("os.name").toLowerCase().contains("mac");
    public static final boolean IS_WINDOWS = System.getProperty("os.name").toLowerCase().contains("windows");
    public static final boolean IS_LINUX = System.getProperty("os.name").toLowerCase().contains("linux");
    public static boolean argument_noController = false;
    public static boolean argument_forceWindowed = false;
    public static boolean argument_hasConsole = false;
    public static boolean isFullScreen = false;
    public static final int ININIT = 1;
    public static final int INLOADER = 2;
    public static final int INSPLASH = 3;
    public static final int INSTARTSCREEN = 4;
    public static final int INMENU = 5;
    public static final int INPAUSE = 6;
    public static final int INGAME = 7;
    public static boolean isLightRendering;
    public static final int propWinID = 0;
    public static final int propWinWidth = 1;
    public static final int propWinHeight = 2;
    public static final int[][] windowedModes;
    public static int windowedModeID;
    public static Texture[] sprites;
    public static Social mySocial;
    public NewsletterPopup myNewsLetter = null;
    public static ScriptConsole myConsole;
    public MFIController myMFIController = null;
    public static int GameState;
    public static int worldTicks;
    public static boolean secondPassed;
    public static boolean worldTickUpdate;
    public static boolean paused;
    public boolean switchFullScreen;
    public boolean switchFullScreenLocked;
    public static boolean triggerFullScreenSwitch;
    public static boolean triggerPixelSizeSwitch;
    public static int newPixelSize;
    private int fpsCount;
    private long loopEnd;
    private long loopPause;
    private long loopTickUpdate;
    private static FrameBuffer gameCanvasBuffer;
    private static TextureRegion gameCanvasBufferRegion;
    private static FrameBuffer lightBuffer;
    private static TextureRegion lightBufferRegion;
    private static FrameBuffer fullScreenBuffer;
    private static TextureRegion fullScreenBufferRegion;
    public static Graphics.DisplayMode[] modes;
    public static int currentModeID;
    private static int fallbackModeID;

    @Override
    public void create() {
        Globals.isDesktop = false;
        Globals.isAndroid = false;
        Globals.isIOS = false;
        switch (Gdx.app.getType()) {
            case Android: {
                Globals.isAndroid = true;
                GameInput.IS_ANDROID = true;
                GameInput.isTouchscreen = true;
                break;
            }
            case iOS: {
                Globals.isIOS = true;
                GameInput.IS_IOS = true;
                GameInput.isTouchscreen = true;
                break;
            }
            default: {
                GameInput.isDesktop = true;
                GameInput.isKeyboard = true;
                Globals.isDesktop = true;
            }
        }
        this.setConsoleInfo();
        Render.initRender();
        Render.fullScreenWidth = Gdx.graphics.getWidth();
        Render.fullScreenHeight = Gdx.graphics.getHeight();
        Render.reinitShaders();
        Render.maxVertical = 640;
        if (Render.maxVertical > Render.fullScreenHeight) {
            Render.maxVertical = Render.fullScreenHeight;
        }
        Render.currentVertical = -1;
        if (Globals.isDesktop) {
            ArcadeCanvas.setPixelSize(180);
        } else {
            ArcadeCanvas.setPixelSize(180);
        }
        sprites = new Texture[32];
        Gdx.app.getInput().setInputProcessor(GameInput.myProcessor);
        Gdx.input.setCatchBackKey(true);
        Gdx.input.setCatchMenuKey(true);
        Gdx.input.setCursorCatched(true);
        if (argument_noController) {
            GameInput.ARGUMENT_NOCONTROLLERS = true;
        }
        this.loopPause = System.currentTimeMillis();
        this.loopTickUpdate = System.currentTimeMillis();
        GameState = 1;
    }

    @Override
    public void dispose() {
        if (mySocial != null) {
            mySocial.disposeSocial();
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

    public static void askPixelSize(int newSize) {
        triggerPixelSizeSwitch = true;
        newPixelSize = newSize;
    }

    public static void setPixelSize(int verticalSize) {
        if (verticalSize == Render.currentVertical) {
            return;
        }
        if (verticalSize > Render.maxVertical) {
            verticalSize = Render.maxVertical;
        }
        Render.currentVertical = verticalSize;
        Render.height = (int)((double)Render.fullScreenHeight / Math.floor(Render.fullScreenHeight / verticalSize));
        Render.width = (int)((double)Render.fullScreenWidth / ((double)Render.fullScreenHeight / ((double)Render.fullScreenHeight / Math.floor(Render.fullScreenHeight / Render.height))));
        Globals.debug("__display:" + Render.fullScreenWidth + "x" + Render.fullScreenHeight + "  -  pixels:" + Render.width + "x" + Render.height);
        gameCanvasBufferRegion = null;
        ArcadeCanvas.setPixelFrameBuffers();
    }

    public static void setPixelFrameBuffers() {
        if (gameCanvasBuffer == null) {
            return;
        }
        gameCanvasBufferRegion = new TextureRegion((Texture)gameCanvasBuffer.getColorBufferTexture(), 0, gameCanvasBuffer.getHeight() - Render.height, Render.width, Render.height);
        gameCanvasBufferRegion.flip(false, false);
        lightBufferRegion = new TextureRegion((Texture)lightBuffer.getColorBufferTexture(), 0, lightBuffer.getHeight() - Render.height, Render.width, Render.height);
        lightBufferRegion.flip(false, false);
        fullScreenBufferRegion = new TextureRegion((Texture)fullScreenBuffer.getColorBufferTexture(), 0, fullScreenBuffer.getHeight() - Render.fullScreenHeight, Render.width, Render.height);
        fullScreenBufferRegion.flip(false, false);
    }

    @Override
    public void resize(int width, int height) {
        Render.fullScreenWidth = width;
        Render.fullScreenHeight = height;
        Render.reinitShaders();
        ArcadeCanvas.setPixelSize(Render.currentVertical);
        if (gameCanvasBuffer != null) {
            gameCanvasBuffer.dispose();
            gameCanvasBuffer = null;
        }
        if (lightBuffer != null) {
            lightBuffer.dispose();
            lightBuffer = null;
        }
        if (GameInput.controllersFound > 0) {
            Controllers.clearListeners();
        }
        GameInput.controllersFound = 0;
    }

    public final void generateFrameBuffers() {
        int fbheight = (int)((double)Render.fullScreenHeight / Math.floor(Render.fullScreenHeight / Render.maxVertical));
        int fbwidth = (int)((double)Render.fullScreenWidth / ((double)Render.fullScreenHeight / ((double)Render.fullScreenHeight / Math.floor(Render.fullScreenHeight / Render.maxVertical))));
        if (gameCanvasBuffer != null) {
            gameCanvasBuffer.dispose();
        }
        if (lightBuffer != null) {
            lightBuffer.dispose();
        }
        if (fullScreenBuffer != null) {
            fullScreenBuffer.dispose();
        }
        gameCanvasBuffer = new FrameBuffer(Pixmap.Format.RGB888, ArcadeCanvas.PowerOf2(fbwidth), ArcadeCanvas.PowerOf2(fbheight), false);
        ((Texture)gameCanvasBuffer.getColorBufferTexture()).setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        lightBuffer = new FrameBuffer(Pixmap.Format.RGBA8888, ArcadeCanvas.PowerOf2(fbwidth), ArcadeCanvas.PowerOf2(fbheight), false);
        ((Texture)lightBuffer.getColorBufferTexture()).setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        fullScreenBuffer = new FrameBuffer(Pixmap.Format.RGB888, ArcadeCanvas.PowerOf2(Render.fullScreenWidth), ArcadeCanvas.PowerOf2(Render.fullScreenHeight), false);
        ((Texture)fullScreenBuffer.getColorBufferTexture()).setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        ArcadeCanvas.setPixelFrameBuffers();
    }

    @Override
    public void render() {
        if (gameCanvasBuffer == null) {
            this.generateFrameBuffers();
        }
        if (Gdx.input.isKeyPressed(66) && (Gdx.input.isKeyPressed(57) || Gdx.input.isKeyPressed(58))) {
            if (!this.switchFullScreenLocked) {
                this.switchFullScreen = true;
                this.switchFullScreenLocked = true;
                triggerFullScreenSwitch = true;
            }
        } else {
            this.switchFullScreen = false;
            this.switchFullScreenLocked = false;
        }
        if (triggerPixelSizeSwitch) {
            ArcadeCanvas.setPixelSize(newPixelSize);
            triggerPixelSizeSwitch = false;
        }
        if (triggerFullScreenSwitch) {
            ArcadeCanvas.setDisplayMode(1080, 720, !isFullScreen);
            triggerFullScreenSwitch = false;
        }
        GameInput.catchCursor = Gdx.app.getGraphics().isFullscreen() || GameState == 7 || !GameInput.isMouse;
        if (++worldTicks > 1000) {
            worldTicks = 0;
        }
        GameInput.convertMouseToScreenCoords();
        GameInput.convertTouchToScreenCoords();
        gameCanvasBuffer.begin();
        Gdx.gl.glDisable(3042);
        Gdx.gl.glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        Gdx.gl.glClear(16384);
        Render.camera.setToOrtho(true, gameCanvasBuffer.getWidth(), gameCanvasBuffer.getHeight());
        Render.camera.update();
        Render.batch.setBlendFunction(770, 771);
        Render.setAlpha(255);
        if (GameState == 7) {
            this.GameLoop();
        } else {
            this.LogicLoop();
        }
        if (Render.globalTexture != null) {
            Render.batch.end();
            Render.globalTexture = null;
        }
        Light.render(true);
        gameCanvasBuffer.end();
        if (isLightRendering) {
            lightBuffer.begin();
            Gdx.gl.glClearColor(Light.ambientColor.r + Light.gamma, Light.ambientColor.g + Light.gamma, Light.ambientColor.b + Light.gamma, Light.ambientColor.a + Light.gamma);
            Gdx.gl.glClear(16384);
            Light.render(false);
            lightBuffer.end();
            gameCanvasBuffer.begin();
            Render.batch.begin();
            Render.batch.setBlendFunction(774, 0);
            Render.batch.setColor(1.0f, 1.0f, 1.0f, 1.0f);
            Render.batch.draw(lightBufferRegion, 0.0f, 0.0f, (float)Render.width, (float)Render.height);
            Render.batch.end();
            gameCanvasBuffer.end();
        }
        gameCanvasBuffer.begin();
        Render.batch.setBlendFunction(770, 771);
        this.renderPostLights();
        if (Render.globalTexture != null) {
            Render.batch.end();
            Render.globalTexture = null;
        }
        Light.renderFlares();
        gameCanvasBuffer.end();
        Gdx.gl.glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        Gdx.gl.glClear(16384);
        Render.camera.setToOrtho(true, Render.fullScreenWidth, Render.fullScreenHeight);
        if (Render.tiltedCamera) {
            Render.camera.rotate(Render.cameraTilt);
        }
        Render.camera.zoom = Render.zoom;
        Render.camera.update();
        Render.batch.setProjectionMatrix(Render.camera.combined);
        Render.batch.begin();
        Render.batch.setBlendFunction(770, 771);
        Render.batch.setColor(1.0f, 1.0f, 1.0f, 1.0f);
        Render.batch.draw(gameCanvasBufferRegion, 0.0f, 0.0f, (float)Render.fullScreenWidth, (float)Render.fullScreenHeight);
        Render.batch.end();
        Render.camera.zoom = 1.0f;
        Render.camera.update();
        int height = Render.height;
        int width = Render.width;
        if (Globals.isDesktop || Globals.isAndroidTV) {
            Render.height = (int)((double)Render.fullScreenHeight / Math.floor(Render.fullScreenHeight / 320));
            Render.width = (int)((double)Render.fullScreenWidth / ((double)Render.fullScreenHeight / ((double)Render.fullScreenHeight / Math.floor(Render.fullScreenHeight / 320))));
        } else {
            Render.height = (int)((double)Render.fullScreenHeight / Math.floor(Render.fullScreenHeight / 220));
            Render.width = (int)((double)Render.fullScreenWidth / ((double)Render.fullScreenHeight / ((double)Render.fullScreenHeight / Math.floor(Render.fullScreenHeight / 220))));
        }
        Render.camera.setToOrtho(true, Render.width, Render.height);
        Render.batch.setProjectionMatrix(Render.camera.combined);
        GameInput.convertMouseToScreenCoords();
        GameInput.convertTouchToScreenCoords();
        this.renderStatusbar();
        if (Render.globalTexture != null) {
            Render.batch.end();
            Render.globalTexture = null;
        }
        if (argument_hasConsole && myConsole != null) {
            boolean toggle;
            Render.camera.setToOrtho(true, Render.width, Render.height);
            Render.batch.setProjectionMatrix(Render.camera.combined);
            boolean bl = toggle = (GameInput.lastKeyCode == 75 || GameInput.lastKeyCode == 68) && !GameInput.lastKeyLocked;
            if (toggle) {
                GameInput.lastKeyLocked = true;
            }
            myConsole.update(toggle, Render.myFramerate);
            if (Render.globalTexture != null) {
                Render.batch.end();
                Render.globalTexture = null;
            }
        }
        Render.height = height;
        Render.width = width;
        ++this.fpsCount;
        if (this.loopEnd - this.loopPause > 1000L) {
            secondPassed = true;
            this.loopPause = this.loopEnd;
            if (GameInput.controllersFound == 0) {
                GameInput.initControllers();
            }
            Render.myFramerate = this.fpsCount;
            this.fpsCount = 0;
        }
        if (this.loopEnd - this.loopTickUpdate > 300L) {
            worldTickUpdate = true;
            this.loopTickUpdate = this.loopEnd;
        }
        this.loopEnd = System.currentTimeMillis();
        if (!GameInput.isMouse && GameInput.hideMouse == 999) {
            GameInput.hideMouse = 128;
        }
        if (GameInput.hideMouse > 0 && GameInput.hideMouse != 999) {
            --GameInput.hideMouse;
        }
        if (mySocial != null) {
            mySocial.processInfo();
        }
        Audio.processTriggersTick();
    }

    public static void setDisplayMode(int width, int height, boolean fullscreen) {
        if (argument_forceWindowed || "1".equals(System.getenv("TRAINER_SELFTEST"))) {
            fullscreen = false;
        }
        try {
            if (fullscreen) {
                width = Gdx.app.getGraphics().getDisplayMode().width;
                height = Gdx.app.getGraphics().getDisplayMode().height;
            } else if (width <= 0 || width > 4096 || height <= 0 || height > 4096) {
                width = 1280;
                height = 720;
            }
            if (Gdx.app.getGraphics().getWidth() == width && Gdx.app.getGraphics().getHeight() == height && isFullScreen == fullscreen) {
                return;
            }
            System.setProperty("org.lwjgl.opengl.Window.undecorated", fullscreen ? "true" : "false");
            Gdx.app.getGraphics().setWindowedMode(width, height);
            isFullScreen = fullscreen;
            if (isFullScreen) {
                Gdx.input.setCursorCatched(true);
            } else {
                Gdx.input.setCursorCatched(false);
            }
        } catch (Throwable ignored) {
        }
        GameInput.controllersFound = 0;
    }

    public static final int fetchWindowMode(int myID) {
        for (int i = 0; i < windowedModes.length; ++i) {
            if (windowedModes[i][0] != myID) continue;
            return i;
        }
        return windowedModes.length - 1;
    }

    public static float clamp(float value, float min, float max) {
        if (value < min) {
            return min;
        }
        if (value > max) {
            return max;
        }
        return value;
    }

    @Override
    public void pause() {
    }

    @Override
    public void resume() {
    }

    public void LogicLoop() {
    }

    public void GameLoop() {
    }

    public void renderPostLights() {
    }

    public void renderStatusbar() {
    }

    public void setConsoleInfo() {
    }

    static {
        windowedModes = new int[][]{{0, 1024, 640}, {1, 1024, 768}, {2, 1080, 720}, {3, 1152, 720}, {4, 1280, 720}, {5, 1280, 800}, {6, 1440, 900}, {7, 1600, 900}, {8, 1680, 1050}, {9, 1920, 1200}, {999, 9999, 9999}};
        windowedModeID = 1;
        mySocial = null;
        myConsole = null;
        triggerFullScreenSwitch = false;
        triggerPixelSizeSwitch = false;
        gameCanvasBufferRegion = null;
        currentModeID = -1;
    }
}

