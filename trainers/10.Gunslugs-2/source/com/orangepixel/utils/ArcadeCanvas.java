/*
 * Decompiled with CFR 0.152.
 */
package com.orangepixel.utils;

import com.badlogic.gdx.ApplicationListener;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Graphics;
import com.badlogic.gdx.InputProcessor;
import com.badlogic.gdx.controllers.Controller;
import com.badlogic.gdx.controllers.ControllerListener;
import com.badlogic.gdx.controllers.Controllers;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.graphics.glutils.FrameBuffer;
import com.badlogic.gdx.math.Vector3;
import com.orangepixel.adverts.Advertising;
import com.orangepixel.controller.ControllerMapping;
import com.orangepixel.controller.Gamepad;
import com.orangepixel.controller.SDLgamepad;
import com.orangepixel.gunslugs2.Audio;
import com.orangepixel.gunslugs2.Render;
import com.orangepixel.social.Social;
import com.orangepixel.utils.FakeLight;
import java.util.Random;

public class ArcadeCanvas
implements ApplicationListener {
    public static final boolean IS_MAC = System.getProperty("os.name").toLowerCase().contains("mac");
    public static final boolean IS_WINDOWS = System.getProperty("os.name").toLowerCase().contains("windows");
    public static final boolean IS_LINUX = System.getProperty("os.name").toLowerCase().contains("linux");
    public boolean argument_forceWindowed = false;
    public boolean argument_noController = false;
    public static boolean isDesktop = false;
    public static boolean isAndroid = false;
    public static boolean isIOS = false;
    public static boolean isAndroidTV = false;
    public boolean isFullScreen = false;
    public boolean isGooglePlayLicence = false;
    public boolean touchReleased = true;
    public float touchX = -1.0f;
    public float touchY = -1.0f;
    public int[] mTouchX = new int[6];
    public int[] mTouchY = new int[6];
    public static final int ININIT = 40;
    public static final int INSPLASH = 41;
    public static final int INMENU = 42;
    public static final int INGAME = 43;
    public static final int INLOADER = 44;
    public static int GameState;
    public int worldTicks;
    long loopStart;
    long loopEnd;
    long loopPause;
    public boolean secondPassed;
    int fpsSleep;
    int hideMouse;
    public boolean paused;
    public static int displayW;
    public static int displayH;
    public static Texture[] sprites;
    public static FakeLight[] myFakeLights;
    public boolean isLightRendering;
    public Color ambientColor = new Color();
    FrameBuffer lightBuffer;
    TextureRegion lightBufferRegion;
    public Social mySocial = null;
    public Advertising myAds = null;
    public boolean keyBoardOut = false;
    public boolean controllersAllowUnknown = true;
    public int controllersFound = 0;
    public Gamepad controller1 = new Gamepad();
    public Gamepad controller2 = new Gamepad();
    public boolean switchFullScreen;
    public boolean switchFullScreenLocked;
    FrameBuffer m_fbo;
    TextureRegion m_fboRegion = null;
    FrameBuffer m_fboTop;
    TextureRegion m_fboTopRegion = null;
    ControllerMapping pad = null;
    int firstdevice = -1;
    long endTime;
    long dt;
    long startTime;
    public Graphics.DisplayMode[] modes;
    public int currentModeID = -1;
    private int fallbackModeID;
    public static Random randomGenerator;

    @Override
    public void create() {
        float w = Gdx.graphics.getWidth();
        float h = Gdx.graphics.getHeight();
        isDesktop = false;
        isAndroid = false;
        isIOS = false;
        switch (Gdx.app.getType()) {
            case Android: {
                isAndroid = true;
                this.controller1.isTouchscreen();
                break;
            }
            case iOS: {
                isIOS = true;
                this.controller1.isTouchscreen();
                break;
            }
            default: {
                isDesktop = true;
            }
        }
        displayW = (int)w;
        displayH = (int)h;
        Audio.initSounds();
        Render.initRender();
        Render.height = (int)((double)displayH / Math.floor(displayH / 160));
        Render.width = (int)((double)displayW / ((double)displayH / ((double)displayH / Math.floor(displayH / 160))));
        sprites = new Texture[32];
        randomGenerator = new Random();
        this.loopPause = System.currentTimeMillis();
        Gdx.app.getInput().setInputProcessor(new InputProcessor(){

            @Override
            public boolean touchUp(int screenX, int screenY, int pointer, int button) {
                if (pointer < 5) {
                    ArcadeCanvas.this.mTouchX[pointer] = -1;
                    ArcadeCanvas.this.mTouchY[pointer] = -1;
                    ArcadeCanvas.this.touchReleased = true;
                }
                return false;
            }

            @Override
            public boolean touchCancelled(int screenX, int screenY, int pointer, int button) {
                return this.touchUp(screenX, screenY, pointer, button);
            }

            @Override
            public boolean touchDragged(int screenX, int screenY, int pointer) {
                ArcadeCanvas.this.controller1.isTouchscreen = true;
                if (pointer < 5) {
                    ArcadeCanvas.this.mTouchX[pointer] = screenX;
                    ArcadeCanvas.this.mTouchY[pointer] = screenY;
                    ArcadeCanvas.this.touchX = screenX;
                    ArcadeCanvas.this.touchY = screenY;
                }
                return false;
            }

            @Override
            public boolean touchDown(int screenX, int screenY, int pointer, int button) {
                ArcadeCanvas.this.controller1.isTouchscreen = true;
                if (pointer < 5) {
                    ArcadeCanvas.this.mTouchX[pointer] = screenX;
                    ArcadeCanvas.this.mTouchY[pointer] = screenY;
                    ArcadeCanvas.this.touchX = screenX;
                    ArcadeCanvas.this.touchY = screenY;
                }
                return false;
            }

            @Override
            public boolean scrolled(float scrollX, float scrollY) {
                return false;
            }

            @Override
            public boolean mouseMoved(int screenX, int screenY) {
                Gdx.input.setCursorCatched(false);
                ArcadeCanvas.this.hideMouse = 48;
                return false;
            }

            @Override
            public boolean keyUp(int keycode) {
                switch (keycode) {
                    case 111: {
                        ArcadeCanvas.this.controller1.backPressed = false;
                        ArcadeCanvas.this.controller1.backLocked = false;
                        return true;
                    }
                    case 21: {
                        ArcadeCanvas.this.controller1.leftPressed = false;
                        ArcadeCanvas.this.controller1.leftLocked = false;
                        return true;
                    }
                    case 22: {
                        ArcadeCanvas.this.controller1.rightPressed = false;
                        ArcadeCanvas.this.controller1.rightLocked = false;
                        return true;
                    }
                    case 19: {
                        ArcadeCanvas.this.controller1.upPressed = false;
                        ArcadeCanvas.this.controller1.upLocked = false;
                        return true;
                    }
                    case 20: {
                        ArcadeCanvas.this.controller1.downPressed = false;
                        ArcadeCanvas.this.controller1.downLocked = false;
                        return true;
                    }
                    case 52: {
                        ArcadeCanvas.this.controller1.BUTTON_X = false;
                        ArcadeCanvas.this.controller1.BUTTON_Xlocked = false;
                        return true;
                    }
                    case 54: {
                        ArcadeCanvas.this.controller1.BUTTON_A = false;
                        ArcadeCanvas.this.controller1.BUTTON_Alocked = false;
                        return true;
                    }
                    case 43: {
                        ArcadeCanvas.this.controller1.BUTTON_A = false;
                        ArcadeCanvas.this.controller1.BUTTON_Alocked = false;
                        return true;
                    }
                    case 29: {
                        ArcadeCanvas.this.controller1.leftPressed = false;
                        ArcadeCanvas.this.controller1.leftLocked = false;
                        return true;
                    }
                    case 32: {
                        ArcadeCanvas.this.controller1.rightPressed = false;
                        ArcadeCanvas.this.controller1.rightLocked = false;
                        return true;
                    }
                    case 51: {
                        ArcadeCanvas.this.controller1.upPressed = false;
                        ArcadeCanvas.this.controller1.upLocked = false;
                        return true;
                    }
                    case 47: {
                        ArcadeCanvas.this.controller1.downPressed = false;
                        ArcadeCanvas.this.controller1.downLocked = false;
                        return true;
                    }
                    case 62: {
                        ArcadeCanvas.this.controller1.BUTTON_X = false;
                        ArcadeCanvas.this.controller1.BUTTON_Xlocked = false;
                        return true;
                    }
                }
                return false;
            }

            @Override
            public boolean keyTyped(char character) {
                return false;
            }

            @Override
            public boolean keyDown(int keycode) {
                ArcadeCanvas.this.controller1.isKeyboard();
                switch (keycode) {
                    case 111: {
                        ArcadeCanvas.this.controller1.backPressed = true;
                        return true;
                    }
                    case 21: {
                        ArcadeCanvas.this.controller1.leftPressed = true;
                        return true;
                    }
                    case 22: {
                        ArcadeCanvas.this.controller1.rightPressed = true;
                        return true;
                    }
                    case 19: {
                        ArcadeCanvas.this.controller1.upPressed = true;
                        return true;
                    }
                    case 20: {
                        ArcadeCanvas.this.controller1.downPressed = true;
                        return true;
                    }
                    case 52: {
                        ArcadeCanvas.this.controller1.BUTTON_X = true;
                        return true;
                    }
                    case 54: {
                        ArcadeCanvas.this.controller1.BUTTON_A = true;
                        return true;
                    }
                    case 29: {
                        ArcadeCanvas.this.controller1.leftPressed = true;
                        return true;
                    }
                    case 32: {
                        ArcadeCanvas.this.controller1.rightPressed = true;
                        return true;
                    }
                    case 51: {
                        ArcadeCanvas.this.controller1.upPressed = true;
                        return true;
                    }
                    case 47: {
                        ArcadeCanvas.this.controller1.downPressed = true;
                        return true;
                    }
                    case 43: {
                        ArcadeCanvas.this.controller1.BUTTON_A = true;
                        return true;
                    }
                    case 62: {
                        ArcadeCanvas.this.controller1.BUTTON_X = true;
                        return true;
                    }
                }
                return false;
            }
        });
        this.initControllers();
        GameState = 40;
    }

    public void initControllers() {
        this.controllersFound = 0;
        this.controller1.hashcode = -1;
        this.firstdevice = -1;
        for (Controller controller : Controllers.getControllers()) {
            if (!controller.getName().isEmpty()) {
                this.pad = new SDLgamepad();
            }
            if (this.pad == null) continue;
            if (this.controller1.hashcode < 0) {
                this.controller1.hashcode = controller.hashCode();
                this.controller1.mapping = this.pad;
                this.controller1.name = controller.getName();
            } else {
                this.controller2.hashcode = controller.hashCode();
                this.controller2.mapping = this.pad;
                this.controller2.name = controller.getName();
            }
            ++this.controllersFound;
            controller.addListener(new ControllerListener(){

                @Override
                public void disconnected(Controller arg0) {
                }

                @Override
                public void connected(Controller arg0) {
                }

                public boolean accelerometerMoved(Controller arg0, int arg1, Vector3 arg2) {
                    return false;
                }

                @Override
                public boolean buttonUp(Controller arg0, int arg1) {
                    if (arg0 == null) {
                        return false;
                    }
                    int tmpGamepad = arg0.hashCode();
                    if (tmpGamepad < 0) {
                        return false;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_X) {
                        ArcadeCanvas.this.controller1.BUTTON_X = false;
                        ArcadeCanvas.this.controller1.BUTTON_Xlocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_A) {
                        ArcadeCanvas.this.controller1.BUTTON_A = false;
                        ArcadeCanvas.this.controller1.BUTTON_Alocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_B) {
                        ArcadeCanvas.this.controller1.BUTTON_B = false;
                        ArcadeCanvas.this.controller1.BUTTON_Blocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_Y) {
                        ArcadeCanvas.this.controller1.BUTTON_Y = false;
                        ArcadeCanvas.this.controller1.BUTTON_Ylocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_LB) {
                        ArcadeCanvas.this.controller1.BUTTON_LB = false;
                        ArcadeCanvas.this.controller1.BUTTON_LBlocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_RB) {
                        ArcadeCanvas.this.controller1.BUTTON_RB = false;
                        ArcadeCanvas.this.controller1.BUTTON_RBlocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_START) {
                        ArcadeCanvas.this.controller1.BUTTON_SPECIAL2 = false;
                        ArcadeCanvas.this.controller1.BUTTON_SPECIAL2locked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_BACK) {
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_DPAD_UP) {
                        ArcadeCanvas.this.controller1.upPressed = false;
                        ArcadeCanvas.this.controller1.upLocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_DPAD_DOWN) {
                        ArcadeCanvas.this.controller1.downPressed = false;
                        ArcadeCanvas.this.controller1.downLocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_DPAD_RIGHT) {
                        ArcadeCanvas.this.controller1.rightPressed = false;
                        ArcadeCanvas.this.controller1.rightLocked = false;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_DPAD_LEFT) {
                        ArcadeCanvas.this.controller1.leftPressed = false;
                        ArcadeCanvas.this.controller1.leftLocked = false;
                        return true;
                    }
                    return false;
                }

                @Override
                public boolean buttonDown(Controller arg0, int arg1) {
                    if (arg0 == null) {
                        return false;
                    }
                    int tmpGamepad = arg0.hashCode();
                    if (tmpGamepad < 0) {
                        return false;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_X) {
                        ArcadeCanvas.this.controller1.BUTTON_X = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_A) {
                        ArcadeCanvas.this.controller1.BUTTON_A = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_B) {
                        ArcadeCanvas.this.controller1.BUTTON_B = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_START) {
                        ArcadeCanvas.this.controller1.BUTTON_SPECIAL2 = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_BACK) {
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_Y) {
                        ArcadeCanvas.this.controller1.BUTTON_Y = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_LB) {
                        ArcadeCanvas.this.controller1.BUTTON_LB = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_RB) {
                        ArcadeCanvas.this.controller1.BUTTON_RB = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_DPAD_UP) {
                        ArcadeCanvas.this.controller1.upPressed = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_DPAD_DOWN) {
                        ArcadeCanvas.this.controller1.downPressed = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_DPAD_RIGHT) {
                        ArcadeCanvas.this.controller1.rightPressed = true;
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.BUTTON_DPAD_LEFT) {
                        ArcadeCanvas.this.controller1.leftPressed = true;
                        return true;
                    }
                    return false;
                }

                @Override
                public boolean axisMoved(Controller arg0, int arg1, float arg2) {
                    if (arg0 == null) {
                        return false;
                    }
                    int tmpGamepad = arg0.hashCode();
                    if (tmpGamepad < 0) {
                        return false;
                    }
                    arg2 *= 128.0f;
                    if (isAndroid && ArcadeCanvas.this.controller1.name != "moga") {
                        if (arg1 == 8 || arg1 == 4) {
                            if (arg2 > 0.0f) {
                                ArcadeCanvas.this.controller1.DPAD_RIGHT = true;
                                ArcadeCanvas.this.controller1.rightPressed = true;
                            } else {
                                ArcadeCanvas.this.controller1.DPAD_RIGHT = false;
                                ArcadeCanvas.this.controller1.BUTTON_DPADRightLocked = false;
                                ArcadeCanvas.this.controller1.rightPressed = false;
                                ArcadeCanvas.this.controller1.rightLocked = false;
                            }
                            if (arg2 < 0.0f) {
                                ArcadeCanvas.this.controller1.DPAD_LEFT = true;
                                ArcadeCanvas.this.controller1.leftPressed = true;
                            } else {
                                ArcadeCanvas.this.controller1.DPAD_LEFT = false;
                                ArcadeCanvas.this.controller1.BUTTON_DPADLeftLocked = false;
                                ArcadeCanvas.this.controller1.leftPressed = false;
                                ArcadeCanvas.this.controller1.leftLocked = false;
                            }
                        }
                        if (arg1 == 9 || arg1 == 5) {
                            if (arg2 > 0.0f) {
                                ArcadeCanvas.this.controller1.DPAD_DOWN = true;
                                ArcadeCanvas.this.controller1.downPressed = true;
                            } else {
                                ArcadeCanvas.this.controller1.DPAD_DOWN = false;
                                ArcadeCanvas.this.controller1.BUTTON_DPADDownLocked = false;
                                ArcadeCanvas.this.controller1.downPressed = false;
                                ArcadeCanvas.this.controller1.downLocked = false;
                            }
                            if (arg2 < 0.0f) {
                                ArcadeCanvas.this.controller1.DPAD_UP = true;
                                ArcadeCanvas.this.controller1.upPressed = true;
                            } else {
                                ArcadeCanvas.this.controller1.DPAD_UP = false;
                                ArcadeCanvas.this.controller1.BUTTON_DPADUpLocked = false;
                                ArcadeCanvas.this.controller1.upLocked = false;
                                ArcadeCanvas.this.controller1.upPressed = false;
                            }
                        }
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.AXIS_LX) {
                        ArcadeCanvas.this.controller1.AXIS_LX = arg2 > -40.0f && arg2 < 40.0f ? 0 : (int)arg2;
                        if (ArcadeCanvas.this.controller1.mapping.reverseXAxis) {
                            ArcadeCanvas.this.controller1.AXIS_LX = -ArcadeCanvas.this.controller1.AXIS_LX;
                        }
                        if (arg2 < -80.0f) {
                            ArcadeCanvas.this.controller1.leftPressed = true;
                        } else {
                            ArcadeCanvas.this.controller1.leftPressed = false;
                            ArcadeCanvas.this.controller1.leftLocked = false;
                        }
                        if (arg2 > 80.0f) {
                            ArcadeCanvas.this.controller1.rightPressed = true;
                        } else {
                            ArcadeCanvas.this.controller1.rightPressed = false;
                            ArcadeCanvas.this.controller1.rightLocked = false;
                        }
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.AXIS_LY) {
                        ArcadeCanvas.this.controller1.AXIS_LY = arg2 > -40.0f && arg2 < 40.0f ? 0 : (int)arg2;
                        if (ArcadeCanvas.this.controller1.mapping.reverseYAxis) {
                            ArcadeCanvas.this.controller1.AXIS_LY = -ArcadeCanvas.this.controller1.AXIS_LY;
                        }
                        if (arg2 < -80.0f) {
                            ArcadeCanvas.this.controller1.upPressed = true;
                        } else {
                            ArcadeCanvas.this.controller1.upPressed = false;
                            ArcadeCanvas.this.controller1.upLocked = false;
                        }
                        if (arg2 > 80.0f) {
                            ArcadeCanvas.this.controller1.downPressed = true;
                        } else {
                            ArcadeCanvas.this.controller1.downPressed = false;
                            ArcadeCanvas.this.controller1.downLocked = false;
                        }
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.AXIS_RX) {
                        ArcadeCanvas.this.controller1.AXIS_RX = arg2 > -40.0f && arg2 < 40.0f ? 0 : (int)arg2;
                        if (ArcadeCanvas.this.controller1.mapping.reverseXAxis) {
                            ArcadeCanvas.this.controller1.AXIS_RX = -ArcadeCanvas.this.controller1.AXIS_RX;
                        }
                        return true;
                    }
                    if (arg1 == ArcadeCanvas.this.controller1.mapping.AXIS_RY) {
                        ArcadeCanvas.this.controller1.AXIS_RY = arg2 > -40.0f && arg2 < 40.0f ? 0 : (int)arg2;
                        if (ArcadeCanvas.this.controller1.mapping.reverseYAxis) {
                            ArcadeCanvas.this.controller1.AXIS_RX = -ArcadeCanvas.this.controller1.AXIS_RX;
                        }
                        return true;
                    }
                    return false;
                }
            });
        }
    }

    @Override
    public void dispose() {
        if (this.mySocial != null) {
            this.mySocial.disposeSocial();
        }
        Render.batch.dispose();
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
        Render.height = (int)((double)displayH / Math.floor(displayH / 160));
        Render.width = (int)((double)displayW / ((double)displayH / ((double)displayH / Math.floor(displayH / 160))));
        Gdx.app.log("opdebug", "Display:" + displayW + "x" + displayH + "  -  pixels:" + Render.width + "x" + Render.height);
        if (this.m_fbo != null) {
            this.m_fbo.dispose();
        }
        this.m_fbo = new FrameBuffer(Pixmap.Format.RGB888, ArcadeCanvas.PowerOf2(Render.width), ArcadeCanvas.PowerOf2(Render.height), false);
        ((Texture)this.m_fbo.getColorBufferTexture()).setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        this.m_fboRegion = new TextureRegion((Texture)this.m_fbo.getColorBufferTexture(), 0, this.m_fbo.getHeight() - Render.height, Render.width, Render.height);
        this.m_fboRegion.getTexture().setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        this.m_fboRegion.flip(false, false);
        if (this.m_fboTop != null) {
            this.m_fboTop.dispose();
        }
        this.m_fboTop = new FrameBuffer(Pixmap.Format.RGBA8888, ArcadeCanvas.PowerOf2(Render.width), ArcadeCanvas.PowerOf2(Render.height), false);
        ((Texture)this.m_fboTop.getColorBufferTexture()).setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        this.m_fboTopRegion = new TextureRegion((Texture)this.m_fboTop.getColorBufferTexture(), 0, this.m_fboTop.getHeight() - Render.height, Render.width, Render.height);
        this.m_fboTopRegion.getTexture().setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        this.m_fboTopRegion.flip(false, false);
        if (this.lightBuffer != null) {
            this.lightBuffer.dispose();
        }
        this.lightBuffer = new FrameBuffer(Pixmap.Format.RGBA8888, ArcadeCanvas.PowerOf2(Render.width), ArcadeCanvas.PowerOf2(Render.height), false);
        ((Texture)this.lightBuffer.getColorBufferTexture()).setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        this.lightBufferRegion = new TextureRegion((Texture)this.lightBuffer.getColorBufferTexture(), 0, this.lightBuffer.getHeight() - Render.height, Render.width, Render.height);
        this.lightBufferRegion.getTexture().setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        this.lightBufferRegion.flip(false, false);
        Render.camera.setToOrtho(true, Render.width, Render.height);
        if (this.controllersFound > 0) {
            Controllers.clearListeners();
        }
        this.controllersFound = 0;
    }

    @Override
    public void pause() {
    }

    @Override
    public void resume() {
    }

    @Override
    public void render() {
        if (isAndroid) {
            this.endTime = System.currentTimeMillis();
            this.dt = this.endTime - this.startTime;
            if (this.dt < 16L) {
                try {
                    Thread.sleep(16L - this.dt);
                }
                catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
            this.startTime = System.currentTimeMillis();
        }
        if (Gdx.input.isKeyPressed(66) && (Gdx.input.isKeyPressed(57) || Gdx.input.isKeyPressed(58))) {
            if (!this.switchFullScreenLocked) {
                this.switchFullScreen = true;
                this.setDisplayMode(720, 480, !this.isFullScreen);
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
        this.m_fbo.begin();
        Gdx.gl.glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        Gdx.gl.glClear(16384);
        Render.camera.setToOrtho(true, this.m_fbo.getWidth(), this.m_fbo.getHeight());
        if (GameState == 43) {
            this.GameLoop();
        } else {
            this.LogicLoop();
        }
        if (Render.globalTexture != null) {
            Render.batch.end();
            Render.globalTexture = null;
        }
        this.m_fbo.end();
        if (this.isLightRendering) {
            this.renderLight();
        }
        this.m_fboTop.begin();
        Gdx.gl.glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        Gdx.gl.glClear(16384);
        Render.camera.setToOrtho(true, this.m_fboTop.getWidth(), this.m_fboTop.getHeight());
        Render.camera.update();
        Render.batch.setBlendFunction(770, 771);
        this.renderPostLights();
        com.orangepixel.gunslugs2.Trainer.onFrameEnd(this);
        if (Render.globalTexture != null) {
            Render.batch.end();
            Render.globalTexture = null;
        }
        this.m_fboTop.end();
        Render.camera.setToOrtho(true, displayW, displayH);
        Render.camera.update();
        Render.batch.setProjectionMatrix(Render.camera.combined);
        Render.batch.begin();
        Render.batch.setBlendFunction(770, 771);
        Render.batch.setColor(1.0f, 1.0f, 1.0f, 1.0f);
        Render.batch.draw(this.m_fboRegion, 0.0f, 0.0f, (float)displayW, (float)displayH);
        Render.batch.end();
        if (this.isLightRendering) {
            Render.batch.begin();
            Render.batch.setBlendFunction(774, 0);
            Render.batch.draw(this.lightBufferRegion, 0.0f, 0.0f, (float)displayW, (float)displayH);
            Render.batch.end();
        }
        Render.batch.begin();
        Render.batch.setBlendFunction(770, 771);
        Render.batch.setColor(1.0f, 1.0f, 1.0f, 1.0f);
        Render.batch.draw(this.m_fboTopRegion, 0.0f, 0.0f, (float)displayW, (float)displayH);
        Render.batch.end();
        com.orangepixel.gunslugs2.Trainer.onScreenPresent(displayW, displayH);
        if (this.loopEnd - this.loopPause > 1000L) {
            this.secondPassed = true;
            this.loopPause = this.loopEnd;
            if (this.controllersFound == 0) {
                this.initControllers();
            }
        }
        this.loopEnd = System.currentTimeMillis();
        if (this.hideMouse > 0) {
            --this.hideMouse;
        } else {
            Gdx.input.setCursorCatched(true);
        }
        if (this.mySocial != null) {
            this.mySocial.processInfo();
        }
    }

    public final void renderLight() {
        this.lightBuffer.begin();
        Gdx.gl.glClearColor(this.ambientColor.r, this.ambientColor.g, this.ambientColor.b, this.ambientColor.a);
        Gdx.gl.glClear(16384);
        Gdx.gl.glBlendFunc(770, 1);
        Gdx.gl.glEnable(3042);
        Render.batch.begin();
        Render.batch.setBlendFunction(770, -1);
        block7: for (int i = 0; i < myFakeLights.length; ++i) {
            if (!myFakeLights[i].isActive()) continue;
            Render.batch.setColor(myFakeLights[i].getColor());
            float tx = myFakeLights[i].getX();
            float ty = myFakeLights[i].getY();
            float tw = 1.28f * myFakeLights[i].getDistance();
            switch (myFakeLights[i].getLightType()) {
                case 0: {
                    Render.batch.draw(sprites[1], tx -= 1.28f * myFakeLights[i].getDistance() / 2.0f, ty -= 0.92f * myFakeLights[i].getDistance(), tw, tw, 0, 128, 128, 128, false, true);
                    continue block7;
                }
                case 1: {
                    Render.batch.draw(sprites[1], tx -= 1.28f * myFakeLights[i].getDistance() / 2.0f, ty -= 1.28f * myFakeLights[i].getDistance(), tw / 2.0f, tw, tw, tw, 1.0f, 1.0f, 90.0f, 0, 128, 128, 128, false, true);
                    continue block7;
                }
                case 2: {
                    Render.batch.draw(sprites[1], tx -= 1.28f * myFakeLights[i].getDistance() / 2.0f, ty += 1.28f * myFakeLights[i].getDistance(), tw / 2.0f, 0.0f, tw, tw, 1.0f, 1.0f, 180.0f, 0, 128, 128, 128, false, true);
                    continue block7;
                }
                case 3: {
                    Render.batch.draw(sprites[1], tx -= 1.28f * myFakeLights[i].getDistance() / 2.0f, ty -= 1.28f * myFakeLights[i].getDistance(), tw / 2.0f, tw, tw, tw, 1.0f, 1.0f, 270.0f, 0, 128, 128, 128, false, true);
                    continue block7;
                }
                case 4: {
                    Render.batch.draw(sprites[1], tx -= tw / 2.0f, ty -= tw / 2.0f, tw, tw, 256, 0, 128, 128, false, true);
                    continue block7;
                }
                default: {
                    Render.batch.draw(sprites[1], tx -= tw / 2.0f, ty -= tw / 2.0f, tw, tw, 0, 0, 128, 128, false, true);
                }
            }
        }
        Render.batch.end();
        this.lightBuffer.end();
    }

    public void setDisplayMode(int width, int height, boolean fullscreen) {
        if (this.argument_forceWindowed || com.orangepixel.gunslugs2.Trainer.isSelfTestRequested()) {
            fullscreen = false;
            if (com.orangepixel.gunslugs2.Trainer.isSelfTestRequested()) {
                width = 1280;
                height = 720;
            }
        }
        if (Gdx.app.getGraphics().getWidth() == width && Gdx.app.getGraphics().getHeight() == height && Gdx.app.getGraphics().isFullscreen() == fullscreen) {
            return;
        }
        if (fullscreen) {
            width = Gdx.app.getGraphics().getDisplayMode().width;
            height = Gdx.app.getGraphics().getDisplayMode().height;
        }
        Graphics.DisplayMode targetDisplayMode = null;
        Graphics.DisplayMode fallBackMode = null;
        float baseRatio = (float)width / (float)height;
        this.modes = Gdx.app.getGraphics().getDisplayModes();
        if (fullscreen) {
            int freq = 0;
            for (int i = 0; i < this.modes.length; ++i) {
                Graphics.DisplayMode current = this.modes[i];
                float currentRatio = (float)current.width / (float)current.height;
                if (current.width >= width && current.height >= height && currentRatio >= baseRatio) {
                    if (current.refreshRate < freq || current.bitsPerPixel < Gdx.app.getGraphics().getDisplayMode().bitsPerPixel) continue;
                    targetDisplayMode = current;
                    this.currentModeID = i;
                    freq = targetDisplayMode.refreshRate;
                    continue;
                }
                if (current.bitsPerPixel != Gdx.app.getGraphics().getDisplayMode().bitsPerPixel || current.refreshRate != Gdx.app.getGraphics().getDisplayMode().refreshRate) continue;
                fallBackMode = current;
                this.fallbackModeID = i;
            }
            if (targetDisplayMode != null) {
                Gdx.app.getGraphics().setFullscreenMode(targetDisplayMode);
            } else if (fallBackMode != null) {
                Gdx.app.getGraphics().setFullscreenMode(fallBackMode);
                this.currentModeID = this.fallbackModeID;
            }
        } else {
            Gdx.app.getGraphics().setWindowedMode(width, height);
        }
        this.isFullScreen = fullscreen;
        if (this.isFullScreen) {
            Gdx.input.setCursorPosition(displayW >> 1, displayH >> 1);
            Gdx.input.setCursorCatched(true);
        } else {
            Gdx.input.setCursorPosition(displayW >> 1, displayH >> 1);
            Gdx.input.setCursorCatched(true);
        }
        this.controllersFound = 0;
    }

    public void LogicLoop() {
    }

    public void GameLoop() {
    }

    public void renderPostLights() {
    }

    static {
        myFakeLights = new FakeLight[256];
    }
}

