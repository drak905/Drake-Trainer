/*
 * Decompiled with CFR 0.152.
 */
package com.orangepixel.gunslugs2;

import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.orangepixel.gunslugs2.Bullets;
import com.orangepixel.gunslugs2.TileMap;
import com.orangepixel.gunslugs2.myCanvas;
import com.orangepixel.utils.Rect;

public class Player {
    public static final int PL_WIDTH = 14;
    public static final int PL_HEIGHT = 13;
    public static final int i_KNIFE = 0;
    public static final int i_DEFAULT = 1;
    public static final int i_DOUBLER = 2;
    public static final int i_ROCKETLAUNCHER = 3;
    public static final int i_FLAMETHROWER = 4;
    public static final int i_GRENADES = 5;
    public static final int i_DOUBLEGUN = 6;
    public static final int i_ELECTRO = 7;
    public static final int i_MACHINEGUN = 8;
    public static final int i_ITEMS = 9;
    public static final int i_TANK = 11;
    public static final int i_JETPACK = 12;
    int playerid;
    int floatX;
    int floatY;
    int x;
    int y;
    int xSpeed;
    int ySpeed;
    int maxSpeed = 40;
    int yIncrease;
    int idle;
    int idleFrame;
    int idleFrameDelay;
    boolean onGround;
    int onGroundCountdown;
    boolean onElevator;
    boolean onChute;
    boolean onChopper;
    boolean inCover;
    int coverShout;
    boolean inVehicle;
    boolean killedVehicle;
    int openMouth;
    boolean inDropIn;
    int noMoveCount;
    boolean leftPressed;
    boolean rightPressed;
    boolean jumpPressed;
    boolean jumpReleased;
    boolean upPressed;
    boolean downPressed;
    boolean actionPressed;
    boolean actionReleased;
    int actionDelay;
    int actionBlocked;
    boolean blockPlayerMovement;
    boolean doHitSound;
    boolean doDieSound;
    boolean doJumpSound;
    boolean doLandSound;
    boolean doShootSound;
    boolean doGrabSound;
    boolean doChatSound;
    boolean doLoseShield;
    boolean doSwapShield;
    int armorCounterMax;
    int armorCounter;
    int shieldType;
    boolean atStairs;
    int atStairsCount;
    boolean atDoor;
    boolean inDoor;
    int doorAlpha;
    int doorAlphaTarget;
    int doorTargetX;
    int doorTargetY;
    int doorTargetID;
    boolean doorLoadRoom;
    int prevScore = 0;
    boolean doScoreCheck;
    int score = 0;
    int coins = 0;
    int flashStatus;
    int ammoExtender;
    int ammo;
    int beacon;
    boolean showBeacon;
    boolean isBeacon;
    int lives;
    int maxLives;
    int maxAmmo;
    int extraLife;
    boolean hasContinue;
    boolean hasSpecialDrink;
    int specialDrinkCounter;
    int Frame;
    int FrameDelay;
    int FrameStep;
    int MirrorFrame;
    int myDirection;
    int SpriteSet;
    int level;
    int weapon;
    int oldWeapon;
    int invincableCounter;
    int hitCounter;
    int diedCounter;
    boolean Died;
    boolean transport;
    boolean Dropped;
    boolean visible;
    int prevCharacterID;
    int characterID = -1;
    int stFaceY;
    int stFaceDelay;
    int stFaceYSpeed;
    int stBoxY;
    int stBoxYSpeed;
    int stInfoID;
    int stAlpha;
    Rect dest = new Rect();
    Rect src = new Rect();

    public Player(int myId) {
        this.playerid = myId;
        this.visible = true;
        this.idleFrame = 42 + myId * 14;
        this.idleFrameDelay = 16;
        this.idle = 0;
    }

    public void gameReset(TileMap myWorld) {
        this.maxLives = 32;
        this.maxAmmo = 128;
        if (myWorld.isHardMode) {
            this.maxLives = 24;
        }
        this.extraLife = 0;
        this.lives = this.maxLives;
        this.ammo = this.maxAmmo;
        this.ammoExtender = 0;
        this.visible = true;
        this.onChute = false;
        this.inDropIn = false;
        this.weapon = 1;
        this.setSpeed();
        this.setBaseWeapon();
        this.coverShout = 0;
        this.Died = false;
        this.diedCounter = 0;
        this.flashStatus = 0;
    }

    public void setPlayer(int aX, int aY) {
        this.x = aX;
        this.y = aY;
        this.floatX = this.x << 4;
        this.floatY = this.y << 4;
        this.xSpeed = 0;
        this.ySpeed = 0;
    }

    public void gameInit(int aX, int aY) {
        this.x = aX << 4;
        this.y = aY << 4;
        this.floatX = this.x << 4;
        this.floatY = this.y << 4;
        this.xSpeed = 1;
        this.ySpeed = 0;
        this.yIncrease = 0;
        this.onGround = true;
        this.onElevator = false;
        this.onGroundCountdown = 0;
        this.Frame = 0;
        this.FrameDelay = 0;
        if (this.x > 240) {
            this.MirrorFrame = 13;
            this.myDirection = 1;
        } else {
            this.MirrorFrame = 0;
            this.myDirection = 1;
        }
        this.invincableCounter = 0;
        this.hitCounter = 0;
        this.resetMovement();
        this.actionReleased = true;
        this.actionBlocked = 0;
        this.doHitSound = false;
        this.doDieSound = false;
        this.doLandSound = false;
        this.doShootSound = false;
        this.doJumpSound = false;
        this.doGrabSound = false;
        this.doChatSound = false;
        this.blockPlayerMovement = false;
        this.transport = false;
        this.noMoveCount = 8;
        this.actionDelay = 0;
        this.Dropped = false;
        this.inDoor = false;
        this.atDoor = false;
        this.inVehicle = false;
        this.killedVehicle = false;
        this.openMouth = 0;
        this.doorAlpha = 255;
        this.doorAlphaTarget = 255;
        this.doorLoadRoom = false;
        this.beacon = -1;
        this.showBeacon = false;
        this.isBeacon = false;
        this.onChopper = false;
        this.inDoor = false;
        this.atDoor = false;
        this.doorLoadRoom = false;
        this.inDropIn = false;
        this.hasSpecialDrink = false;
    }

    public final void setShield(int newShield) {
        this.shieldType = newShield;
        this.doSwapShield = true;
        switch (this.shieldType) {
            case 0: {
                this.armorCounter = 0;
                this.doLoseShield = true;
                break;
            }
            case 1: {
                this.armorCounter = 16;
                this.armorCounterMax = 16;
                break;
            }
            case 2: {
                this.armorCounter = 96;
                this.armorCounterMax = 96;
            }
        }
    }

    public void hit(int energy, int direction) {
        if (Trainer.onPlayerHit(this)) {
            return;
        }
        if (this.invincableCounter > 0 || this.Died || this.hitCounter > 0) {
            return;
        }
        if (direction < 0) {
            myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 10, -1);
        } else {
            myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 10, 1);
        }
        myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 2, myCanvas.getRandom(2));
        this.hitCounter = 3;
        this.invincableCounter = 16;
        float percent = Math.round((float)this.maxLives / 100.0f * (float)energy);
        if (percent < 1.0f) {
            percent = 1.0f;
        }
        if (this.armorCounter > 0) {
            this.armorCounter = (int)((float)this.armorCounter - percent);
            if (this.armorCounter <= 0) {
                this.armorCounter = 0;
                this.setShield(0);
            }
        } else if (this.extraLife > 0) {
            this.extraLife = (int)((float)this.extraLife - percent);
            if (this.extraLife < 0) {
                this.lives -= -this.extraLife;
            }
        } else {
            this.lives = (int)((float)this.lives - percent);
        }
        this.doHitSound = true;
        if (this.lives < 1 && this.inVehicle) {
            this.lives = this.maxLives;
            this.inVehicle = false;
            this.killedVehicle = true;
            this.setWeapon(1, false);
        }
        if (this.lives <= 0) {
            this.lives = 0;
            this.initDie();
            int i = 10;
            while (--i >= 0) {
                if (direction < 0) {
                    myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 10, -1);
                    continue;
                }
                myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 10, 1);
            }
            if (this.myDirection > 0) {
                if (direction < 0) {
                    this.Frame = 70;
                    this.xSpeed = -64;
                } else {
                    this.Frame = 84;
                    this.xSpeed = 64;
                }
            } else if (direction > 0) {
                this.Frame = 70;
                this.xSpeed = 64;
            } else {
                this.Frame = 84;
                this.xSpeed = -64;
            }
        }
    }

    public void die(Bullets myBullet) {
        if (Trainer.onPlayerDie(this)) {
            return;
        }
        if (myBullet.xSpeed > 0) {
            this.hit(myBullet.energy, 1);
        } else {
            this.hit(myBullet.energy, -1);
        }
    }

    public void initDie() {
        if (Trainer.onPlayerDie(this)) {
            return;
        }
        if (this.Died) {
            return;
        }
        this.Died = true;
        this.diedCounter = 200;
        this.doDieSound = true;
        this.yIncrease = -80;
        this.ySpeed = -80;
        this.hasSpecialDrink = false;
    }

    public void initFakeDie(int speedDirection) {
        if (Trainer.onPlayerFakeDie(this)) {
            return;
        }
        if (this.y < 80 && this.diedCounter > 0) {
            return;
        }
        this.yIncrease = -80;
        this.ySpeed = -80;
        this.hasSpecialDrink = false;
        this.Dropped = true;
        this.diedCounter = 64;
        if (this.myDirection > 0) {
            this.Frame = speedDirection < 0 ? 70 : 84;
            this.xSpeed = 64 * speedDirection;
        } else {
            this.Frame = speedDirection > 0 ? 84 : 70;
            this.xSpeed = 64 * speedDirection;
        }
    }

    public void teleport() {
        if (this.transport) {
            return;
        }
        this.transport = true;
    }

    public void resetMovement() {
        this.leftPressed = false;
        this.rightPressed = false;
        this.jumpPressed = false;
        this.actionPressed = false;
        this.jumpReleased = true;
    }

    public final void addScore(int value) {
        this.score += value;
        this.doScoreCheck = true;
    }

    public final void addCoin(int value) {
        this.coins += value;
    }

    public final void setSpeed() {
        this.maxSpeed = 40;
    }

    public final void setAdrenaline() {
        this.lives = this.maxLives;
        this.extraLife = 16;
    }

    public final void setWeapon(int weaponID, boolean doThrow) {
        if (doThrow && this.weapon != 0 && this.weapon != weaponID) {
            this.doGrabSound = true;
            this.oldWeapon = this.weapon;
        }
        switch (weaponID) {
            case 0: {
                this.ammo = 0;
                break;
            }
            case 1: {
                this.maxAmmo = 128;
                break;
            }
            case 2: {
                if (this.characterID > 0 && this.characterID < 3) {
                    this.maxAmmo = 80;
                    break;
                }
                this.maxAmmo = 64;
                break;
            }
            case 3: {
                if (this.characterID == 3) {
                    this.maxAmmo = 32;
                    break;
                }
                this.maxAmmo = 16;
                break;
            }
            case 4: {
                if (this.characterID == 0) {
                    this.maxAmmo = 128;
                    break;
                }
                this.maxAmmo = 64;
                break;
            }
            case 5: {
                if (this.characterID == 5) {
                    this.maxAmmo = 24;
                    break;
                }
                this.maxAmmo = 12;
                break;
            }
            case 6: {
                if (this.characterID == 4) {
                    this.maxAmmo = 40;
                    break;
                }
                this.maxAmmo = 24;
                break;
            }
            case 7: {
                if (this.characterID == 2) {
                    this.maxAmmo = 32;
                    break;
                }
                this.maxAmmo = 24;
                break;
            }
            case 8: {
                this.maxAmmo = this.characterID == 6 ? 128 : 96;
            }
        }
        this.maxAmmo += this.ammoExtender;
        this.ammo = this.maxAmmo;
        this.weapon = weaponID;
    }

    public final void setBaseWeapon() {
        switch (this.characterID) {
            case 0: {
                this.setWeapon(4, false);
                break;
            }
            case 1: {
                this.setWeapon(1, false);
                break;
            }
            case 2: {
                this.setWeapon(7, false);
                break;
            }
            case 3: {
                this.setWeapon(3, false);
                break;
            }
            case 4: {
                this.setWeapon(6, false);
                break;
            }
            case 5: {
                this.setWeapon(5, false);
                break;
            }
            case 6: {
                this.setWeapon(8, false);
            }
        }
    }

    public final void shoot(TileMap myWorld) {
        int coverOffset = 0;
        if (this.atStairs) {
            return;
        }
        int owner = 0;
        if (this.playerid == 2) {
            owner = 1;
        }
        if (this.inCover) {
            coverOffset = -8;
        }
        coverOffset += myWorld.heightMap[this.x >> 4];
        this.openMouth = 8;
        if (this.weapon != 0 && this.weapon != 4) {
            if (this.myDirection < 0) {
                myCanvas.fxAdd(this.x - 8, this.y + coverOffset, 7, this.myDirection);
            } else {
                myCanvas.fxAdd(this.x + 13, this.y + coverOffset, 7, this.myDirection);
            }
            if (this.weapon == 6 && !this.inCover) {
                if (this.myDirection > 0) {
                    myCanvas.fxAdd(this.x - 8, this.y + coverOffset, 7, -this.myDirection);
                } else {
                    myCanvas.fxAdd(this.x + 13, this.y + coverOffset, 7, -this.myDirection);
                }
            }
        }
        switch (this.weapon) {
            case 0: {
                if (this.myDirection > 0) {
                    myCanvas.bulletAdd(owner, 6, this.x + 18, this.y, 8);
                } else {
                    myCanvas.bulletAdd(owner, 6, this.x - 4, this.y, 8);
                }
                this.actionDelay = 80;
                this.doShootSound = true;
                break;
            }
            case 1: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(owner, 1, this.x, this.y + 7 + coverOffset, this.myDirection);
                    this.xSpeed += 4;
                } else {
                    myCanvas.bulletAdd(owner, 1, this.x + 7, this.y + 7 + coverOffset, this.myDirection);
                    this.xSpeed -= 4;
                }
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12), this.y + 8, 9, this.myDirection);
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 64;
                break;
            }
            case 2: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(owner, 1, this.x, this.y + 7 + coverOffset, this.myDirection);
                    myCanvas.bulletAdd(owner, 1, this.x, this.y + 5 + coverOffset, this.myDirection);
                    this.xSpeed += 4;
                } else {
                    myCanvas.bulletAdd(owner, 1, this.x + 7, this.y + 7 + coverOffset, this.myDirection);
                    myCanvas.bulletAdd(owner, 1, this.x + 7, this.y + 5 + coverOffset, this.myDirection);
                    this.xSpeed -= 4;
                }
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12), this.y + 8, 9, this.myDirection);
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12), this.y + 8, 9, this.myDirection);
                this.doShootSound = true;
                this.ammo -= 2;
                this.actionDelay = 128;
                break;
            }
            case 3: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(owner, 2, this.x, this.y + coverOffset, this.myDirection);
                    this.xSpeed = 16;
                } else {
                    myCanvas.bulletAdd(owner, 2, this.x + 7, this.y + coverOffset, this.myDirection);
                    this.xSpeed = -16;
                }
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 192;
                break;
            }
            case 4: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(owner, 7, this.x, this.y + 4, this.myDirection);
                } else {
                    myCanvas.bulletAdd(owner, 7, this.x + 7, this.y + 4, this.myDirection);
                }
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 16;
                break;
            }
            case 5: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(owner, 4, this.x, this.y + 8, this.myDirection);
                    if (this.onGround) {
                        this.ySpeed = -16;
                    }
                    this.onGround = false;
                    this.xSpeed = 8;
                }
                if (this.myDirection > 0) {
                    myCanvas.bulletAdd(owner, 4, this.x, this.y + 8, this.myDirection);
                    if (this.onGround) {
                        this.ySpeed = -16;
                    }
                    this.onGround = false;
                    this.xSpeed = -8;
                }
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 192;
                break;
            }
            case 6: {
                if (this.inCover) {
                    if (this.myDirection < 0) {
                        myCanvas.bulletAdd(owner, 1, this.x, this.y + 7 + coverOffset, this.myDirection);
                        myCanvas.bulletAdd(owner, 1, this.x, this.y + 5 + coverOffset, this.myDirection);
                        this.xSpeed += 4;
                    } else {
                        myCanvas.bulletAdd(owner, 1, this.x + 7, this.y + 7 + coverOffset, this.myDirection);
                        myCanvas.bulletAdd(owner, 1, this.x + 7, this.y + 5 + coverOffset, this.myDirection);
                        this.xSpeed -= 4;
                    }
                } else if (this.ammo % 2 == 0) {
                    myCanvas.bulletAdd(owner, 1, this.x, this.y + 7, -this.myDirection);
                } else {
                    myCanvas.bulletAdd(owner, 1, this.x + 7, this.y + 7, this.myDirection);
                }
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12), this.y + 8, 9, this.myDirection);
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 64;
                break;
            }
            case 7: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(owner, 13, this.x, this.y + 4 + coverOffset, this.myDirection);
                    this.xSpeed += 4;
                } else {
                    myCanvas.bulletAdd(owner, 13, this.x + 7, this.y + 4 + coverOffset, this.myDirection);
                    this.xSpeed -= 4;
                }
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 384;
                break;
            }
            case 8: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(owner, 14, this.x, this.y + 5 + coverOffset + myCanvas.getRandom(4), this.myDirection);
                    this.xSpeed += 4;
                } else {
                    myCanvas.bulletAdd(owner, 14, this.x + 7, this.y + 5 + coverOffset + myCanvas.getRandom(4), this.myDirection);
                    this.xSpeed -= 4;
                }
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12), this.y + 8, 9, this.myDirection);
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 32;
            }
        }
        if (this.ammo <= 0 && this.weapon > 1) {
            this.setWeapon(1, true);
        } else if (this.ammo <= 0 && this.weapon == 1) {
            this.setWeapon(0, true);
        }
    }

    public final void regenerate() {
        this.lives = this.maxLives;
        this.ammo = this.maxAmmo;
        this.Died = false;
    }

    public final void addLife(int amount) {
        this.lives += amount;
        if (this.lives > this.maxLives) {
            this.lives = this.maxLives;
        }
        this.flashStatus = 255;
    }

    public final void addAmmo(int amount) {
        if (this.weapon == 9) {
            return;
        }
        this.ammo += amount;
        if (this.ammo > this.maxAmmo) {
            this.ammo = this.maxAmmo;
        }
        if (this.weapon == 0) {
            this.setWeapon(1, false);
        }
    }

    public final void addBeacon() {
        ++this.beacon;
    }

    public void update(TileMap myWorld) {
        Trainer.onPlayerUpdate(this, myWorld);
        if (this.flashStatus > 0) {
            this.flashStatus -= 8;
            if (this.flashStatus < 0) {
                this.flashStatus = 0;
            }
        }
        if (!this.visible) {
            return;
        }
        if (this.hitCounter > 0) {
            --this.hitCounter;
        }
        this.atStairs = false;
        int tx = this.x + 7 >> 4;
        int tx2 = this.x + 12 >> 4;
        int ty = this.y + 6 >> 4;
        if (ty > 0 && myWorld.get(tx, ty) == 4) {
            this.atStairs = true;
        }
        tx = this.x + 7 >> 4;
        ty = this.y + 8 >> 4;
        if (this.onGround && ty > 0 && myWorld.get(tx, ty) == 3) {
            if (this.myDirection > 0) {
                this.hit(1, 1);
            } else {
                this.hit(1, -1);
            }
        }
        this.showBeacon = false;
        this.isBeacon = false;
        this.inCover = false;
        if (this.openMouth > 0) {
            --this.openMouth;
        }
        if (this.Died || this.Dropped) {
            if (this.Died && myWorld.worldAge % 6 == 0 && (this.xSpeed < -16 || this.xSpeed > 16)) {
                if (this.xSpeed > 0) {
                    myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 10, -1);
                } else {
                    myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 10, 1);
                }
            }
            this.floatY += this.ySpeed >> myWorld.slowMoFactor;
            this.y = this.floatY >> 4;
            this.floatX += this.xSpeed >> myWorld.slowMoFactor;
            this.x = this.floatX >> 4;
            if (this.ySpeed < 240 && this.yIncrease != 0) {
                this.ySpeed += 16;
            }
            if (this.ySpeed > 0) {
                tx = this.x + 7 >> 4;
                ty = this.y + 13 >> 4;
                if ((myWorld.inBuilding || this.y < 170) && myWorld.isSolidBelow(tx, ty)) {
                    this.y = (ty << 4) - 13;
                    this.floatY = this.y << 4;
                    this.doLandSound = true;
                    if (this.xSpeed > 0) {
                        this.xSpeed -= 16;
                        if (this.xSpeed < 0) {
                            this.xSpeed = 0;
                        }
                    } else if (this.xSpeed < 0) {
                        this.xSpeed += 16;
                        if (this.xSpeed > 0) {
                            this.xSpeed = 0;
                        }
                    }
                    if (this.yIncrease < 0) {
                        this.yIncrease += 16;
                    }
                    this.ySpeed = this.yIncrease;
                }
            }
            if (this.onGround && this.y >= 80 && this.x > 0 && this.x < 5120) {
                this.y = (this.floatY >> 4) + myWorld.heightMap[this.x >> 4];
            }
            if (this.diedCounter > 0) {
                --this.diedCounter;
            }
            if (this.diedCounter == 0) {
                this.Dropped = false;
                this.ySpeed = 0;
            }
            ty = this.y + 2 >> 4;
            int ty2 = this.y + 13 - 2 >> 4;
            if (this.xSpeed < 0) {
                tx = this.x >> 4;
                if (myWorld.isSolidBelow(tx, ty) || myWorld.isSolidBelow(tx, ty2)) {
                    this.x = (tx << 4) + 16;
                    this.xSpeed = 0;
                    this.floatX = this.x << 4;
                    if (this.leftPressed && !myWorld.isSolidBelow(tx, ty - 1)) {
                        this.inCover = true;
                    }
                }
            } else if (this.xSpeed > 0 && (myWorld.isSolidBelow(tx = this.x + 14 >> 4, ty) || myWorld.isSolidBelow(tx, ty2))) {
                this.x = (tx << 4) - 14;
                this.xSpeed = 0;
                this.floatX = this.x << 4;
                if (this.rightPressed && !myWorld.isSolidBelow(tx, ty - 1)) {
                    this.inCover = true;
                }
            }
            if (myWorld.lockScreen > 0 && (this.x < myWorld.lockScreen || this.x > myWorld.lockScreen + myWorld.displayW - 12)) {
                if (this.x < myWorld.lockScreen) {
                    this.x = myWorld.lockScreen;
                } else if (this.x > myWorld.lockScreen + myWorld.displayW - 12) {
                    this.x = myWorld.lockScreen + myWorld.displayW - 12;
                }
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            }
            return;
        }
        if (this.invincableCounter > 0) {
            --this.invincableCounter;
        }
        if (this.inDoor) {
            if (this.doorAlpha > this.doorAlphaTarget) {
                this.doorAlpha -= 32;
                if (this.doorAlpha <= this.doorAlphaTarget) {
                    this.doorAlpha = this.doorAlphaTarget;
                    this.doorAlphaTarget = 255;
                    if (this.doorTargetY < 0 && this.doorTargetX < 0) {
                        this.doorLoadRoom = true;
                        this.doorAlpha = this.doorAlphaTarget + 1;
                    } else {
                        this.x = this.doorTargetX;
                        this.y = this.doorTargetY;
                        this.floatX = this.x << 4;
                        this.floatY = this.y << 4;
                    }
                }
            } else if (this.doorAlpha < this.doorAlphaTarget) {
                this.doorAlpha += 32;
                if (this.doorAlpha >= this.doorAlphaTarget) {
                    this.doorAlpha = this.doorAlphaTarget;
                    this.inDoor = false;
                }
            }
            return;
        }
        int originalSlowMoFactor = myWorld.slowMoFactor;
        if (this.noMoveCount > 0) {
            --this.noMoveCount;
        }
        ++this.idle;
        if (this.jumpPressed || this.actionPressed || this.leftPressed || this.rightPressed) {
            this.idle = 0;
        }
        this.idleFrameDelay -= 16 >> myWorld.slowMoFactor;
        if (this.idleFrameDelay <= 0) {
            this.idleFrameDelay = 128;
            this.idleFrame += 14;
            if (this.idleFrame > 70) {
                this.idleFrame = 42;
            }
        }
        if (!this.transport && !this.blockPlayerMovement && this.noMoveCount == 0) {
            if (this.inDropIn) {
                this.ySpeed = 128;
            } else {
                if (this.inVehicle) {
                    this.xSpeed = 0;
                    this.ySpeed = 0;
                    if (this.jumpPressed && this.jumpReleased) {
                        this.inVehicle = false;
                        this.ySpeed = -64;
                        this.doJumpSound = true;
                        this.onGroundCountdown = 0;
                        this.onGround = false;
                    } else if (!this.jumpPressed) {
                        this.jumpReleased = true;
                    }
                    return;
                }
                if (this.leftPressed) {
                    if (this.xSpeed > 0) {
                        this.xSpeed = 0;
                    }
                    this.xSpeed -= 4;
                    if (this.xSpeed < -this.maxSpeed) {
                        this.xSpeed = -this.maxSpeed;
                    }
                    this.myDirection = -1;
                } else if (this.rightPressed) {
                    if (this.xSpeed < 0) {
                        this.xSpeed = 0;
                    }
                    this.xSpeed += 4;
                    if (this.xSpeed > this.maxSpeed) {
                        this.xSpeed = this.maxSpeed;
                    }
                    this.myDirection = 1;
                } else if (this.actionDelay > 0) {
                    if (this.xSpeed > 0) {
                        --this.xSpeed;
                    } else if (this.xSpeed < 0) {
                        ++this.xSpeed;
                    }
                } else {
                    this.xSpeed = 0;
                }
                if (this.weapon == 12 && this.actionPressed) {
                    this.jumpPressed = true;
                }
                if (this.jumpPressed && (this.jumpReleased || this.atStairs) || this.upPressed && this.atStairs) {
                    if (this.weapon == 12) {
                        if (this.ySpeed > -32) {
                            this.ySpeed -= 16 >> myWorld.slowMoFactor;
                        }
                        this.jumpReleased = true;
                    } else if (this.atStairs) {
                        this.ySpeed = -32;
                        this.onGround = false;
                        this.onGroundCountdown = 0;
                        this.atStairsCount = 16;
                    } else if (this.onGroundCountdown > 0 || this.onGround) {
                        this.jumpReleased = false;
                        if (this.atDoor) {
                            this.inDoor = true;
                            this.doorAlpha = 255;
                            this.doorAlphaTarget = 0;
                            this.atDoor = false;
                        } else {
                            myCanvas.fxAdd(this.x + 4, this.y + 5 + myWorld.heightMap[this.x >> 4], 1, 0);
                            this.ySpeed = -72;
                            this.doJumpSound = true;
                            this.onGroundCountdown = 0;
                            this.onGround = false;
                        }
                    }
                } else if (!this.jumpPressed) {
                    this.jumpReleased = true;
                }
            }
        }
        this.atDoor = false;
        if (this.myDirection > 0) {
            this.MirrorFrame = 0;
        } else if (this.myDirection < 0) {
            this.MirrorFrame = 13;
        }
        if (this.FrameStep > 0) {
            --this.FrameStep;
        } else if (this.atStairs) {
            this.Frame = 98;
            if (this.ySpeed != 0 && myWorld.worldAge % 16 < 8) {
                this.Frame = 112;
            }
            this.MirrorFrame = 0;
        } else if (this.ySpeed < 0) {
            this.Frame = 42;
        } else if (this.ySpeed > 16 && !this.onElevator) {
            this.Frame = 56;
        } else if (!this.onGround) {
            this.Frame = 14;
        } else if (this.xSpeed != 0) {
            if (this.FrameDelay > 16 || this.Frame > 28) {
                this.FrameDelay = 16;
                this.Frame = 14;
            }
            if (this.FrameDelay > 0) {
                --this.FrameDelay;
            } else {
                this.Frame = this.Frame < 28 ? 28 : (myCanvas.getRandom(16) < 4 ? 0 : 14);
                this.FrameDelay = 8;
            }
        } else {
            this.Frame = myCanvas.getRandom(96) < 16 ? 0 : 14;
        }
        this.floatY += this.ySpeed >> myWorld.slowMoFactor;
        if (this.onGroundCountdown > 0) {
            --this.onGroundCountdown;
        }
        if (this.atStairs) {
            if (!this.jumpPressed && this.ySpeed < 8) {
                ++this.ySpeed;
            }
            if (this.downPressed) {
                this.ySpeed = 32;
            }
        } else if (this.inDropIn) {
            if (this.ySpeed < 80) {
                this.ySpeed += 32;
            }
            myCanvas.fxAdd(this.x + myCanvas.getRandom(8) - 4, this.y + myCanvas.getRandom(8), 11, 0);
        } else if (this.onChute) {
            if (this.ySpeed < 32) {
                this.ySpeed += 16;
            }
        } else if (this.weapon == 12) {
            if (!this.jumpPressed && this.ySpeed < 96) {
                this.ySpeed += 4;
            }
        } else if (this.ySpeed < 240) {
            this.ySpeed += 4;
        }
        this.y = this.floatY >> 4;
        if (this.ySpeed < -96 && this.y % 2 == 0 && this.weapon != 4) {
            myCanvas.fxAdd(this.x + 4, this.y + 13, 1, 0);
        }
        if (this.y > 160 && !myWorld.inBuilding) {
            if (!this.Died) {
                this.floatY = this.y << 4;
                this.ySpeed = 0;
                this.xSpeed = 0;
                this.diedCounter = 48;
                this.Died = true;
            }
            this.y = 320;
            this.floatY = this.y << 4;
        }
        if (this.xSpeed == 0 && this.ySpeed == 0 && this.atStairsCount > 0) {
            --this.atStairsCount;
        }
        if (this.ySpeed <= 0) {
            tx = this.x + 1 >> 4;
            tx2 = this.x + 14 - 1 >> 4;
            ty = this.y >> 4;
            if (tx >= 0 && tx2 <= 320) {
                if (myWorld.isSolidBelow(tx, ty) || myWorld.isSolidBelow(tx2, ty)) {
                    this.ySpeed = 0;
                    this.y = (ty << 4) + 16 + 2;
                    this.floatY = this.y << 4;
                } else if (!this.onElevator) {
                    this.onGround = false;
                    if (this.ySpeed < 96) {
                        this.ySpeed += this.yIncrease;
                    }
                }
            } else if (tx2 > 320) {
                this.y = (ty << 4) + 13 + 1;
                this.floatY = this.y << 4;
                this.setOnGround(myWorld);
                this.ySpeed = 0;
            } else if (!this.onElevator) {
                this.onGround = false;
                if (this.ySpeed < 96) {
                    this.ySpeed += this.yIncrease;
                }
            }
        } else {
            tx = this.x + 1 >> 4;
            tx2 = this.x + 14 - 1 >> 4;
            ty = this.y + 13 >> 4;
            if (ty >= 0 && (myWorld.isSolid(tx, ty) || myWorld.isSolid(tx2, ty))) {
                this.yIncrease = 2;
                this.y = (ty << 4) - 13;
                this.floatY = this.y << 4;
                this.setOnGround(myWorld);
                if (this.atStairs && this.atStairsCount == 0) {
                    this.atStairsCount = 32;
                }
                this.ySpeed = 0;
            } else if (myWorld.get(tx, ty) == 4 && this.atStairsCount > 0 && !this.downPressed) {
                --this.atStairsCount;
                this.yIncrease = 2;
                this.floatY -= this.ySpeed >> myWorld.slowMoFactor;
                this.y = this.floatY >> 4;
                this.setOnGround(myWorld);
                this.ySpeed = 0;
            } else if (!this.onElevator) {
                this.onGround = false;
                if (this.ySpeed < 96) {
                    this.ySpeed += this.yIncrease;
                }
            }
        }
        this.floatX += this.xSpeed >> myWorld.slowMoFactor;
        this.x = this.floatX >> 4;
        if (this.x < 0) {
            this.x = 0;
            this.floatX = this.x << 4;
            this.xSpeed = 0;
        }
        if (myWorld.lockScreen > -1 && this.x < myWorld.lockScreen) {
            this.x = myWorld.lockScreen;
            this.floatX = this.x << 4;
            this.xSpeed = 0;
        }
        if (this.x >= myWorld.worldOffsetX + myWorld.displayW - 12 && !this.onChopper) {
            this.x = myWorld.worldOffsetX + myWorld.displayW - 12;
            this.floatX = this.x << 4;
            this.xSpeed = 0;
        }
        if (myWorld.CameraIsView) {
            if (this.x < myWorld.lockScreen) {
                this.x = myWorld.lockScreen;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            }
            if (this.x < myWorld.worldOffsetX + 12) {
                this.x = myWorld.worldOffsetX + 12;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            } else if (this.x > myWorld.worldOffsetX + myWorld.displayW - 14) {
                this.x = myWorld.worldOffsetX + myWorld.displayW - 14;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            } else if (myWorld.lockScreen >= 0 && this.x > myWorld.lockScreen + myWorld.displayW - 14) {
                this.x = myWorld.lockScreen + myWorld.displayW - 14;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            } else if (myWorld.softLock > 0 && this.x > myWorld.softLock + myWorld.displayW - 14) {
                this.x = myWorld.softLock + myWorld.displayW - 14;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            }
        }
        ty = this.y + 2 >> 4;
        int ty2 = this.y + 13 - 2 >> 4;
        if (this.xSpeed < 0) {
            tx = this.x >> 4;
            if (myWorld.isSolidBelow(tx, ty) || myWorld.isSolidBelow(tx, ty2)) {
                this.x = (tx << 4) + 16;
                this.xSpeed = 0;
                this.floatX = this.x << 4;
                if (this.leftPressed && !myWorld.isSolidBelow(tx, ty - 1)) {
                    this.inCover = true;
                }
            }
        } else if (this.xSpeed > 0 && (myWorld.isSolidBelow(tx = this.x + 14 >> 4, ty) || myWorld.isSolidBelow(tx, ty2))) {
            this.x = (tx << 4) - 14;
            this.xSpeed = 0;
            this.floatX = this.x << 4;
            if (this.rightPressed && !myWorld.isSolidBelow(tx, ty - 1)) {
                this.inCover = true;
            }
        }
        if (this.actionDelay > 0) {
            this.actionDelay -= 16 >> myWorld.slowMoFactor;
        } else if (this.ammo > 0 && this.actionPressed || this.weapon == 12 && !this.onGround && !this.onChute || this.weapon == 0 && this.actionPressed) {
            this.actionPressed = false;
            ++this.actionBlocked;
            this.shoot(myWorld);
        }
        if (this.inCover && this.actionPressed) {
            if (this.coverShout <= 0) {
                --this.coverShout;
            }
            if (this.coverShout == -16) {
                myCanvas.fxAdd(this.x - 8, this.y - 10, 2, 17);
                this.doChatSound = true;
                this.coverShout = 16;
            }
        } else if (this.coverShout > 0) {
            --this.coverShout;
        }
        this.onElevator = false;
        this.blockPlayerMovement = false;
        myWorld.slowMoFactor = originalSlowMoFactor;
        if (this.onGround && this.y >= 80 && this.x > 0 && this.x < 5120) {
            this.y = (this.floatY >> 4) + myWorld.heightMap[this.x >> 4];
        }
    }

    public void setOnGround(TileMap myWorld) {
        if (!this.onGround && !this.onElevator && this.ySpeed > 24) {
            this.doLandSound = true;
            myCanvas.fxAdd(this.x - 10, this.y + 4 + myWorld.heightMap[this.x >> 4], 1, 1);
            myCanvas.fxAdd(this.x + 10, this.y + 4 + myWorld.heightMap[this.x >> 4], 1, 2);
        }
        if (this.inDropIn) {
            int i = 8;
            while (--i >= 0) {
                myCanvas.fxAdd(this.x + myCanvas.getRandom(8), this.y - myCanvas.getRandom(4), 5, myCanvas.getRandom(10));
            }
            myWorld.worldShake = 32;
            this.inDropIn = false;
        }
        if (this.onChute) {
            myCanvas.fxAdd(this.x, this.y, 6, this.myDirection);
        }
        this.onChute = false;
        this.onGround = true;
        this.onGroundCountdown = 4;
    }

    public void Paint(Texture mySprite, Texture weaponSprite, TileMap myWorld, SpriteBatch batch) {
        int spriteOffset = 0;
        if (this.hitCounter > 0) {
            spriteOffset = 61;
        }
        if (!this.visible || this.inVehicle) {
            return;
        }
        if (this.Died && this.diedCounter < 16 && this.diedCounter % 4 < 2) {
            return;
        }
        batch.begin();
        batch.setColor(1.0f, 1.0f, 1.0f, 1.0f);
        int tx = this.x - myWorld.worldOffsetX;
        int ty = this.y - myWorld.worldOffsetY;
        batch.setColor(1.0f, 1.0f, 1.0f, (float)this.doorAlpha / 255.0f);
        if (this.onGround && this.hitCounter == 0 && !this.Died && !this.Dropped) {
            this.dest.set(tx, ty, tx + 14, ty + 13);
            this.src.set(this.idleFrame, 26 + this.MirrorFrame + spriteOffset, this.idleFrame + 14, 26 + this.MirrorFrame + 13 + spriteOffset);
            batch.draw(mySprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
        } else {
            this.dest.set(tx, ty, tx + 14, ty + 13);
            this.src.set(this.Frame, this.MirrorFrame + spriteOffset, this.Frame + 14, this.MirrorFrame + 13 + spriteOffset);
            batch.draw(mySprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
        }
        if (this.openMouth > 0) {
            if (this.myDirection < 0) {
                this.dest.set(tx + 3, ty + 7, tx + 9, ty + 9);
            } else {
                this.dest.set(tx + 5, ty + 7, tx + 11, ty + 9);
            }
            this.src.set(0, 65, 6, 67);
            batch.draw(mySprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
        }
        if (!(this.Died || this.atStairs || this.Dropped || myWorld.inControlCenter)) {
            if (this.Frame == 24) {
                ++ty;
            }
            switch (this.weapon) {
                case 0: {
                    if (this.actionDelay > 32) {
                        ty += 8;
                        if (this.myDirection > 0) {
                            this.dest.set(tx += 6, ty, tx + 15, ty + 4);
                            this.src.set(45, 22, 60, 26);
                            batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                            tx -= 6;
                        } else {
                            this.dest.set(tx -= 6, ty, tx + 15, ty + 4);
                            this.src.set(45, 27, 60, 31);
                            batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                            tx += 6;
                        }
                        ty -= 8;
                        break;
                    }
                    if (this.myDirection > 0) {
                        this.dest.set(tx, ty, tx + 4, ty + 12);
                        this.src.set(45, 48, 49, 60);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        break;
                    }
                    this.dest.set(tx += 10, ty, tx + 4, ty + 12);
                    this.src.set(52, 48, 56, 60);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    break;
                }
                default: {
                    if (this.idle > 32) {
                        if (this.myDirection < 0) {
                            this.dest.set(tx + 10, ty, tx + 15, ty + 10);
                            this.src.set(32, 10, 37, 20);
                            batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                            break;
                        }
                        this.dest.set(tx, ty, tx + 5, ty + 10);
                        this.src.set(37, 10, 42, 20);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        break;
                    }
                    if (this.myDirection < 0) {
                        ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 7);
                        this.dest.set(tx -= 3, ty, tx + 10, ty + 5);
                        this.src.set(10, 18, 20, 23);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        tx += 3;
                        if (this.inCover || this.ySpeed < 0) {
                            ty += 2;
                            break;
                        }
                        ty -= 7;
                        break;
                    }
                    ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 7);
                    this.dest.set(tx += 7, ty, tx + 10, ty + 5);
                    this.src.set(0, 18, 10, 23);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    tx -= 7;
                    if (this.inCover || this.ySpeed < 0) {
                        ty += 2;
                        break;
                    }
                    ty -= 7;
                    break;
                }
                case 2: {
                    if (this.idle > 32) {
                        if (this.myDirection < 0) {
                            this.dest.set(tx + 10, ty, tx + 15, ty + 12);
                            this.src.set(38, 32, 43, 44);
                            batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                            break;
                        }
                        this.dest.set(tx, ty, tx + 5, ty + 12);
                        this.src.set(32, 32, 37, 44);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        break;
                    }
                    if (this.myDirection < 0) {
                        ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 6);
                        this.dest.set(tx -= 5, ty, tx + 12, ty + 5);
                        this.src.set(12, 23, 24, 28);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        tx += 5;
                        if (this.inCover || this.ySpeed < 0) {
                            ty += 2;
                            break;
                        }
                        ty -= 6;
                        break;
                    }
                    ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 6);
                    this.dest.set(tx += 6, ty, tx + 12, ty + 5);
                    this.src.set(0, 23, 12, 28);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    tx -= 6;
                    if (this.inCover || this.ySpeed < 0) {
                        ty += 2;
                        break;
                    }
                    ty -= 6;
                    break;
                }
                case 3: {
                    if (this.myDirection < 0) {
                        ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 4);
                        this.dest.set(tx -= 2, ty, tx + 15, ty + 6);
                        this.src.set(15, 35, 30, 41);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        tx += 2;
                        if (this.inCover || this.ySpeed < 0) {
                            ty += 2;
                            break;
                        }
                        ty -= 4;
                        break;
                    }
                    ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 4);
                    this.dest.set(tx += 2, ty, tx + 15, ty + 6);
                    this.src.set(0, 35, 15, 41);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    tx -= 2;
                    if (this.inCover || this.ySpeed < 0) {
                        ty += 2;
                        break;
                    }
                    ty -= 4;
                    break;
                }
                case 4: {
                    if (this.myDirection < 0) {
                        this.dest.set(--tx, ty += 7, tx + 15, ty + 6);
                        this.src.set(15, 29, 30, 35);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        ++tx;
                        ty -= 7;
                        break;
                    }
                    this.dest.set(tx, ty += 7, tx + 15, ty + 6);
                    this.src.set(0, 29, 15, 35);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    ty -= 7;
                    break;
                }
                case 5: {
                    if (this.myDirection < 0) {
                        this.dest.set(tx += 5, ty += 4, tx + 8, ty + 8);
                        this.src.set(8, 41, 16, 49);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        tx -= 5;
                        ty -= 4;
                        break;
                    }
                    this.dest.set(++tx, ty += 4, tx + 8, ty + 8);
                    this.src.set(0, 41, 8, 49);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    --tx;
                    ty -= 4;
                    break;
                }
                case 6: {
                    if (this.idle > 32) {
                        if (this.myDirection < 0) {
                            this.dest.set(tx + 10, ty, tx + 15, ty + 10);
                            this.src.set(32, 10, 37, 20);
                            batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                            break;
                        }
                        this.dest.set(tx, ty, tx + 5, ty + 10);
                        this.src.set(37, 10, 42, 20);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        break;
                    }
                    if (this.inCover) {
                        if (this.myDirection < 0) {
                            ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 7);
                            this.dest.set(tx -= 3, ty, tx + 10, ty + 5);
                            this.src.set(10, 18, 20, 23);
                            batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                            tx += 3;
                            if (this.inCover || this.ySpeed < 0) {
                                ty += 2;
                                break;
                            }
                            ty -= 7;
                            break;
                        }
                        ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 7);
                        this.dest.set(tx += 7, ty, tx + 10, ty + 5);
                        this.src.set(0, 18, 10, 23);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        tx -= 7;
                        if (this.inCover || this.ySpeed < 0) {
                            ty += 2;
                            break;
                        }
                        ty -= 7;
                        break;
                    }
                    this.dest.set(tx -= 4, ty += 7, tx + 21, ty + 4);
                    this.src.set(0, 56, 21, 60);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    tx += 4;
                    ty -= 7;
                    break;
                }
                case 12: {
                    if (this.myDirection < 0) {
                        this.dest.set(tx += 9, ty += 6, tx + 7, ty + 7);
                        this.src.set(66, 24 + spriteOffset, 73, 31 + spriteOffset);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        tx -= 9;
                        ty -= 6;
                        break;
                    }
                    this.dest.set(tx -= 3, ty += 6, tx + 7, ty + 7);
                    this.src.set(59, 24 + spriteOffset, 66, 31 + spriteOffset);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    tx += 3;
                    ty -= 6;
                    break;
                }
                case 7: {
                    if (this.idle > 32) {
                        if (this.myDirection < 0) {
                            this.dest.set(tx + 10, ty - 3, tx + 16, ty + 12);
                            this.src.set(43, 0, 49, 15);
                            batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                            break;
                        }
                        this.dest.set(tx - 1, ty - 3, tx + 5, ty + 12);
                        this.src.set(49, 0, 55, 15);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        break;
                    }
                    if (this.myDirection < 0) {
                        ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 6);
                        this.dest.set(tx -= 3, ty, tx + 15, ty + 7);
                        this.src.set(15, 49, 30, 56);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        tx += 3;
                        if (this.inCover || this.ySpeed < 0) {
                            ty += 2;
                            break;
                        }
                        ty -= 6;
                        break;
                    }
                    ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 6);
                    this.dest.set(tx += 2, ty, tx + 15, ty + 7);
                    this.src.set(0, 49, 15, 56);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    tx -= 2;
                    if (this.inCover || this.ySpeed < 0) {
                        ty += 2;
                        break;
                    }
                    ty -= 6;
                    break;
                }
                case 8: {
                    if (this.idle > 32) {
                        if (this.myDirection < 0) {
                            this.dest.set(tx + 10, ty - 5, tx + 16, ty + 10);
                            this.src.set(52, 32, 58, 47);
                            batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                            break;
                        }
                        this.dest.set(tx, ty - 5, tx + 6, ty + 10);
                        this.src.set(45, 32, 51, 47);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        break;
                    }
                    if (this.myDirection < 0) {
                        ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 6);
                        this.dest.set(tx -= 5, ty, tx + 15, ty + 6);
                        this.src.set(15, 61, 30, 67);
                        batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                        tx += 5;
                        if (this.inCover || this.ySpeed < 0) {
                            ty += 2;
                            break;
                        }
                        ty -= 6;
                        break;
                    }
                    ty = this.inCover || this.ySpeed < 0 ? (ty -= 2) : (ty += 6);
                    this.dest.set(tx += 6, ty, tx + 15, ty + 6);
                    this.src.set(0, 61, 15, 67);
                    batch.draw(weaponSprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
                    tx -= 6;
                    if (this.inCover || this.ySpeed < 0) {
                        ty += 2;
                        break;
                    }
                    ty -= 6;
                }
            }
        }
        if (this.onChute) {
            this.dest.set(tx -= 13, ty -= 30, tx + 37, ty + 32);
            this.src.set(0, 29 + spriteOffset, 37, 61 + spriteOffset);
            if (this.xSpeed != 0) {
                TextureRegion region = new TextureRegion(mySprite, this.src.left, this.src.top, this.src.width, this.src.height);
                region.flip(false, true);
                batch.draw(region, this.dest.left, this.dest.top, 19.0f, 32.0f, this.dest.width, this.dest.height, 1.0f, 1.0f, -(this.xSpeed >> 3));
                region = null;
            } else {
                batch.draw(mySprite, (float)this.dest.left, (float)this.dest.top, (float)this.dest.width, (float)this.dest.height, this.src.left, this.src.top, this.src.width, this.src.height, false, true);
            }
        }
        batch.end();
    }
}

