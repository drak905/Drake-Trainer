/*
 * Decompiled with CFR 0.152.
 */
package com.orangepixel.gunslugs;

import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.orangepixel.gunslugs.Bullets;
import com.orangepixel.gunslugs.TileMap;
import com.orangepixel.gunslugs.myCanvas;
import com.orangepixel.utils.Rect;

public class Player {
    public static final int PL_WIDTH = 12;
    public static final int PL_HEIGHT = 12;
    public static final int i_FLAMETHROWER = 1;
    public static final int i_ELECTRO = 2;
    public static final int i_JETPACK = 3;
    public static final int i_GRENADES = 4;
    public static final int i_SKULLGUN = 5;
    public static final int i_DOUBLEGUN = 6;
    public static final int i_CHICKENGUN = 7;
    public static final int i_ITEMS = 8;
    public static final int i_TANK = 9;
    int id;
    int floatX;
    int floatY;
    int x;
    int y;
    int xSpeed;
    int ySpeed;
    int maxSpeed = 64;
    int yIncrease;
    boolean onGround;
    int onGroundCountdown;
    boolean onElevator;
    boolean onChute;
    boolean onChopper;
    boolean inCover;
    boolean inTank;
    int openMouth;
    int noMoveCount;
    boolean leftPressed;
    boolean rightPressed;
    boolean jumpPressed;
    boolean jumpReleased;
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
    boolean atDoor;
    boolean inDoor;
    int doorAlpha;
    int doorAlphaTarget;
    int doorTargetX;
    int doorTargetY;
    int doorTargetID;
    boolean doorLoadRoom;
    int score = 0;
    int distance = 0;
    int coins = 0;
    int killCount;
    int coverKillCount;
    int grenadeKillCount;
    int chainKill;
    int chainDelay;
    int mechBallCount;
    int crashCount;
    int driveCount;
    int wormCount;
    int skullCount;
    int hellTankCount;
    int ammo;
    int beacon;
    boolean showBeacon;
    boolean isBeacon;
    int lives;
    int maxLives;
    int maxAmmo;
    boolean hasContinue;
    boolean hasSpecialDrink;
    int specialDrinkCounter;
    boolean hasArmor;
    int armorCounter;
    int Frame;
    int FrameDelay;
    int FrameStep;
    int MirrorFrame;
    int myDirection;
    int SpriteSet;
    int level;
    int weapon;
    int invincableCounter;
    int hitCounter;
    int diedCounter;
    boolean Died;
    boolean transport;
    boolean Dropped;
    int characterID;
    int stFaceY;
    int stFaceDelay;
    int stFaceYSpeed;
    int stBoxY;
    int stBoxYSpeed;
    int stInfoID;
    int stAlpha;
    static Rect dest = new Rect();
    static Rect src = new Rect();

    public Player(int myId) {
        this.id = myId;
        this.characterID = -1;
    }

    public void gameReset() {
        this.maxLives = 256;
        this.maxAmmo = 128;
        this.weapon = 1;
        this.inDoor = false;
        this.atDoor = false;
        this.doorLoadRoom = false;
        this.onChute = true;
        this.lives = this.maxLives;
        this.ammo = this.maxAmmo;
        this.hasArmor = false;
        this.Died = false;
        this.diedCounter = 0;
        this.hasSpecialDrink = false;
        this.skullCount = 0;
        this.hellTankCount = 0;
    }

    public void resetForLevel() {
        this.killCount = 0;
        this.mechBallCount = 0;
        this.grenadeKillCount = 0;
        this.coverKillCount = 0;
        this.crashCount = 0;
        this.chainKill = 0;
        this.chainDelay = 0;
        this.driveCount = 0;
        this.wormCount = 0;
        this.specialDrinkCounter = 0;
    }

    public void init(int aX, int aY) {
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
            this.MirrorFrame = 12;
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
        this.blockPlayerMovement = false;
        this.transport = false;
        this.noMoveCount = 8;
        this.actionDelay = 0;
        this.Dropped = false;
        this.inDoor = false;
        this.atDoor = false;
        this.inTank = false;
        this.openMouth = 0;
        this.doorAlpha = 255;
        this.doorAlphaTarget = 255;
        this.doorLoadRoom = false;
        this.beacon = -1;
        this.showBeacon = false;
        this.isBeacon = false;
        this.onChopper = false;
        this.setInfo(-1);
    }

    public final void setInfo(int nInfoID) {
        this.stInfoID = nInfoID;
        this.stFaceY = 32;
        this.stFaceDelay = 48;
        this.stFaceYSpeed = -4;
        this.stBoxY = 48;
        this.stBoxYSpeed = -4;
        this.stAlpha = 255;
    }

    public void die(Bullets myBullet) {
        if (Trainer.godMode) {
            this.lives = this.maxLives;
            return;
        }
        if (this.invincableCounter > 0 || this.Died) {
            return;
        }
        if (myBullet.xSpeed < 0) {
            myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 6, -1);
        } else {
            myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 6, 1);
        }
        if (this.armorCounter > 0) {
            this.armorCounter -= myBullet.energy;
            if (this.armorCounter <= 0) {
                this.armorCounter = 0;
                myCanvas.fxAdd(this.x, this.y + 4, 17, 0);
                myCanvas.fxAdd(this.x + 8, this.y, 17, 0);
                this.hasArmor = false;
            }
        } else {
            this.lives -= myBullet.energy;
        }
        this.doHitSound = true;
        if (this.lives < 1 && this.inTank) {
            this.lives = this.maxLives;
            this.inTank = false;
            this.setWeapon(1);
        }
        if (this.lives < 0) {
            this.lives = 0;
            this.initDie();
            int i = 10;
            while (--i >= 0) {
                if (myBullet.xSpeed < 0) {
                    myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 6, -1);
                    continue;
                }
                myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 6, 1);
            }
            if (this.myDirection > 0) {
                if (myBullet.xSpeed < 0) {
                    this.Frame = 60;
                    this.xSpeed = -64;
                } else {
                    this.Frame = 72;
                    this.xSpeed = 64;
                }
            } else if (myBullet.xSpeed > 0) {
                this.Frame = 60;
                this.xSpeed = 64;
            } else {
                this.Frame = 72;
                this.xSpeed = -64;
            }
        }
    }

    public void setDieFrame() {
        this.Frame = 72;
        this.xSpeed = 0;
    }

    public void initDie() {
        if (Trainer.godMode) {
            this.lives = this.maxLives;
            this.Died = false;
            return;
        }
        if (this.Died) {
            return;
        }
        this.Died = true;
        this.diedCounter = 96;
        this.doDieSound = true;
        this.yIncrease = -64;
        this.ySpeed = -112;
        this.hasSpecialDrink = false;
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
    }

    public final void addCoin(int value) {
        this.coins += value;
    }

    public final void setWeapon(int weaponID) {
        switch (weaponID) {
            case 1: {
                this.ammo = this.maxAmmo;
                break;
            }
            case 2: {
                this.ammo = 96;
                if (this.weapon == 2) break;
                this.setInfo(1);
                break;
            }
            case 3: {
                this.ammo = this.maxAmmo;
                if (this.weapon == 3) break;
                this.setInfo(2);
                break;
            }
            case 4: {
                this.ammo = this.maxAmmo;
                if (this.weapon == 4) break;
                this.setInfo(3);
                break;
            }
            case 5: {
                this.ammo = this.maxAmmo;
                if (this.weapon == 5) break;
                this.setInfo(9);
                break;
            }
            case 6: {
                this.ammo = this.maxAmmo >> 2;
                if (this.weapon == 6) break;
                this.setInfo(4);
                break;
            }
            case 7: {
                this.ammo = this.maxAmmo >> 1;
                if (this.weapon == 7) break;
                this.setInfo(5);
                break;
            }
            case 8: {
                this.ammo = this.maxAmmo;
                if (this.weapon == 8) break;
                this.setInfo(6);
                break;
            }
            case 9: {
                this.ammo = this.maxAmmo >> 2;
                if (this.weapon == 9) break;
                this.setInfo(7);
            }
        }
        this.weapon = weaponID;
    }

    public final void shoot(TileMap myWorld) {
        int coverOffset = 0;
        if (this.inCover) {
            coverOffset = -8;
        }
        this.openMouth = 8;
        switch (this.weapon) {
            case 1: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(0, 1, this.x, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                    myCanvas.fxAdd(this.x - 4, this.y + 8, 4, 1);
                    this.xSpeed += 8;
                    if (this.onGround) {
                        this.ySpeed -= 4;
                    }
                    this.onGround = false;
                } else {
                    myCanvas.bulletAdd(0, 1, this.x + 12, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                    myCanvas.fxAdd(this.x + 12, this.y + 8, 4, 1);
                    this.xSpeed -= 8;
                    if (this.onGround) {
                        this.ySpeed -= 4;
                    }
                    this.onGround = false;
                }
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12), this.y + 8, 10, -this.myDirection);
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 64;
                break;
            }
            case 2: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(0, 7, this.x - 8, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                } else {
                    myCanvas.bulletAdd(0, 7, this.x + 12, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                }
                if (myWorld.worldAge % 6 == 0) {
                    this.doShootSound = true;
                }
                this.ammo -= 2;
                if (this.ammo < 0) {
                    this.ammo = 0;
                }
                this.actionDelay = 32;
                break;
            }
            case 3: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(0, 9, this.x - 8, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                } else {
                    myCanvas.bulletAdd(0, 9, this.x + 12, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                }
                this.ammo -= 16;
                if (this.ammo < 0) {
                    this.ammo = 0;
                }
                this.doShootSound = true;
                this.actionDelay = 128;
                break;
            }
            case 4: {
                myCanvas.bulletAdd(0, 5, this.x + 4, this.y + 10, this.myDirection);
                this.ammo -= 4;
                this.actionDelay = 64;
                break;
            }
            case 5: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(0, 2, this.x + 1, this.y - 13, -2);
                    myCanvas.fxAdd(this.x + 1, this.y + 10, 3, 1);
                    this.ySpeed = -4;
                    this.doShootSound = true;
                    this.actionDelay = 128;
                    break;
                }
                if (this.myDirection <= 0) break;
                myCanvas.bulletAdd(0, 2, this.x + 8, this.y - 13, 2);
                myCanvas.fxAdd(this.x + 30, this.y + 10, 3, 1);
                this.ySpeed = -4;
                this.doShootSound = true;
                this.actionDelay = 128;
                break;
            }
            case 6: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(0, 3, this.x, this.y + 8, this.myDirection);
                    myCanvas.fxAdd(this.x - 4, this.y + 8, 4, 1);
                    if (this.onGround) {
                        this.ySpeed = -16;
                    }
                    this.onGround = false;
                    this.xSpeed = 8;
                }
                if (this.myDirection > 0) {
                    myCanvas.bulletAdd(0, 3, this.x, this.y + 8, this.myDirection);
                    myCanvas.fxAdd(this.x - 4, this.y + 8, 4, 1);
                    if (this.onGround) {
                        this.ySpeed = -16;
                    }
                    this.onGround = false;
                    this.xSpeed = -8;
                }
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 64;
                break;
            }
            case 7: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(0, 11, this.x - 8, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                } else {
                    myCanvas.bulletAdd(0, 11, this.x + 12, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                }
                --this.ammo;
                if (this.ammo < 0) {
                    this.ammo = 0;
                }
                this.doShootSound = true;
                this.actionDelay = 64;
                break;
            }
            case 8: {
                myCanvas.bulletAdd(0, 1, this.x, this.y + 4 + myCanvas.getRandom(3) + coverOffset, 2);
                myCanvas.fxAdd(this.x - 4, this.y + 8, 4, 1);
                myCanvas.bulletAdd(0, 1, this.x + 12, this.y + 4 + myCanvas.getRandom(3) + coverOffset, -2);
                myCanvas.fxAdd(this.x + 12, this.y + 8, 4, 1);
                if (this.onGround) {
                    this.ySpeed -= 4;
                }
                this.onGround = false;
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12), this.y + 8, 10, -this.myDirection);
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12), this.y + 8, 10, -this.myDirection);
                this.doShootSound = true;
                this.ammo -= 4;
                this.actionDelay = 80;
                break;
            }
            case 9: {
                if (this.myDirection < 0) {
                    myCanvas.bulletAdd(0, 19, this.x, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                    myCanvas.fxAdd(this.x - 4, this.y + 8, 4, 1);
                    this.xSpeed += 8;
                    if (this.onGround) {
                        this.ySpeed -= 4;
                    }
                    this.onGround = false;
                } else {
                    myCanvas.bulletAdd(0, 19, this.x + 12, this.y + 4 + myCanvas.getRandom(3) + coverOffset, this.myDirection);
                    myCanvas.fxAdd(this.x + 12, this.y + 8, 4, 1);
                    this.xSpeed -= 8;
                    if (this.onGround) {
                        this.ySpeed -= 4;
                    }
                    this.onGround = false;
                }
                myCanvas.fxAdd(this.x + myCanvas.getRandom(12) - 2, this.y + myCanvas.getRandom(12) - 4, 17, 5);
                this.doShootSound = true;
                --this.ammo;
                this.actionDelay = 64;
            }
        }
        if (this.ammo <= 0 && this.weapon > 1) {
            this.setWeapon(1);
        }
    }

    public final void regenerate() {
        this.lives = this.maxLives;
    }

    public final void addLife(int amount) {
        this.lives += amount;
        if (this.lives > this.maxLives) {
            this.lives = this.maxLives;
        }
    }

    public final void addAmmo(int amount) {
        if (this.weapon == 9) {
            return;
        }
        this.ammo += amount;
        if (this.ammo > this.maxAmmo) {
            this.ammo = this.maxAmmo;
        }
    }

    public final void addBeacon() {
        ++this.beacon;
    }

    public final void addChain() {
        ++this.chainKill;
        this.chainDelay = 128;
    }

    public void update(TileMap myWorld, int displayW) {
        Trainer.onPlayerUpdate(this, myWorld);
        int ty;
        int tx;
        if (this.chainDelay > 0) {
            --this.chainDelay;
        } else {
            this.chainKill = 0;
        }
        this.distance = this.x >> 3;
        if (!this.inCover) {
            this.coverKillCount = 0;
        }
        this.showBeacon = false;
        this.isBeacon = false;
        this.inCover = false;
        if (this.openMouth > 0) {
            --this.openMouth;
        }
        if (this.Died || this.Dropped) {
            int ty2;
            int tx2;
            if (this.Died && myWorld.worldAge % 6 == 0 && (this.xSpeed < -32 || this.xSpeed > 32)) {
                if (this.xSpeed > 0) {
                    myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 6, -1);
                } else {
                    myCanvas.fxAdd(this.x + myCanvas.getRandom(16), this.y + myCanvas.getRandom(16) - 8, 6, 1);
                }
            }
            this.floatY += this.ySpeed >> myWorld.slowMoFactor;
            this.y = this.floatY >> 4;
            if (this.y > 148) {
                this.xSpeed = 0;
            }
            this.floatX += this.xSpeed >> myWorld.slowMoFactor;
            this.x = this.floatX >> 4;
            if (this.ySpeed < 240 && this.yIncrease != 0) {
                this.ySpeed += 16 >> myWorld.slowMoFactor;
            }
            if (this.ySpeed > 0 && myWorld.isSolid(tx2 = this.x + 6 >> 4, ty2 = this.y + 12 + 3 >> 4)) {
                this.y = (ty2 << 4) - 12 + 3;
                this.floatY = this.y << 4;
                this.doLandSound = true;
                if (this.xSpeed > 0) {
                    this.xSpeed -= 16 >> myWorld.slowMoFactor;
                    if (this.xSpeed < 0) {
                        this.xSpeed = 0;
                    }
                } else if (this.xSpeed < 0) {
                    this.xSpeed += 16 >> myWorld.slowMoFactor;
                    if (this.xSpeed > 0) {
                        this.xSpeed = 0;
                    }
                }
                if (this.Died) {
                    if (this.yIncrease < 0) {
                        this.yIncrease += 16;
                    }
                    this.ySpeed = this.yIncrease;
                }
            }
            if (this.diedCounter > 0) {
                --this.diedCounter;
            } else {
                this.Dropped = false;
            }
            return;
        }
        if (this.invincableCounter > 0) {
            --this.invincableCounter;
        }
        if (this.inDoor) {
            this.inTank = false;
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
        if (this.hasSpecialDrink && !myWorld.isInDoor) {
            myWorld.slowMoFactor = 0;
            if (this.specialDrinkCounter > 0 && myWorld.worldAge % 3 == 0) {
                --this.specialDrinkCounter;
                if (this.specialDrinkCounter == 0) {
                    this.hasSpecialDrink = false;
                }
            }
            if (myWorld.worldAge % 2 == 0) {
                myCanvas.fxAdd(this.x, this.y, 23, this.myDirection * this.id);
            }
        }
        if (this.noMoveCount > 0) {
            --this.noMoveCount;
        }
        if (!this.transport && !this.blockPlayerMovement && this.noMoveCount == 0) {
            if (this.leftPressed) {
                if (this.xSpeed > 0) {
                    this.xSpeed = 0;
                }
                this.xSpeed -= 8;
                if (this.xSpeed < -this.maxSpeed) {
                    this.xSpeed = -this.maxSpeed;
                }
                this.myDirection = -1;
            } else if (this.rightPressed) {
                if (this.xSpeed < 0) {
                    this.xSpeed = 0;
                }
                this.xSpeed += 8;
                if (this.xSpeed > this.maxSpeed) {
                    this.xSpeed = this.maxSpeed;
                }
                this.myDirection = 1;
            } else {
                this.xSpeed = 0;
            }
            if (this.weapon == 4 && this.actionPressed) {
                this.jumpPressed = true;
            }
            if (this.jumpPressed && this.jumpReleased) {
                this.inTank = false;
                if (this.weapon == 4) {
                    if (this.ySpeed > -64) {
                        this.ySpeed -= 16 >> myWorld.slowMoFactor;
                    }
                    if (this.ammo % 2 == 0) {
                        myCanvas.fxAdd(this.x + 10, this.y + 5, 12, 0);
                        myCanvas.fxAdd(this.x, this.y + 5, 12, 0);
                        myCanvas.fxAdd(this.x, this.y + 5, 13, 0);
                        myCanvas.fxAdd(this.x + 10, this.y + 5, 13, 0);
                    }
                    this.jumpReleased = true;
                } else if (this.onGroundCountdown > 0 || this.onGround) {
                    this.jumpReleased = false;
                    if (this.atDoor) {
                        this.inTank = false;
                        this.inDoor = true;
                        this.doorAlpha = 255;
                        this.doorAlphaTarget = 0;
                        this.atDoor = false;
                    } else {
                        if (this.ySpeed > 24) {
                            myCanvas.fxAdd(this.x + 4, this.y + 4, 2, 0);
                        }
                        this.ySpeed = -120;
                        this.doJumpSound = true;
                        this.onGroundCountdown = 0;
                        this.onGround = false;
                    }
                }
            } else if (!this.jumpPressed) {
                this.jumpReleased = true;
            }
        }
        this.atDoor = false;
        if (this.myDirection > 0) {
            this.MirrorFrame = 0;
        } else if (this.myDirection < 0) {
            this.MirrorFrame = 12;
        }
        if (this.FrameStep > 0) {
            --this.FrameStep;
        } else if (this.ySpeed < 0) {
            this.Frame = 36;
        } else if (this.ySpeed > 16 && !this.onElevator) {
            this.Frame = 48;
        } else if (!this.onGround) {
            this.Frame = 0;
        } else if (this.xSpeed != 0) {
            if (this.FrameDelay > 4 || this.Frame > 24) {
                this.FrameDelay = 4;
                this.Frame = 12;
            }
            if (this.FrameDelay > 0) {
                --this.FrameDelay;
            } else {
                this.Frame = this.Frame < 24 ? 24 : (myCanvas.getRandom(8) < 4 ? 0 : 12);
                this.FrameDelay = 4;
            }
        } else {
            this.Frame = myCanvas.getRandom(96) < 8 ? 0 : 12;
        }
        this.floatY += this.ySpeed >> myWorld.slowMoFactor;
        if (this.onGroundCountdown > 0) {
            --this.onGroundCountdown;
        }
        if (this.onChute) {
            if (this.ySpeed < 32) {
                this.ySpeed += 16;
            }
        } else if (this.weapon == 4) {
            if (!this.jumpPressed && this.ySpeed < 96) {
                this.ySpeed += 8;
            }
        } else if (this.ySpeed < 240) {
            this.ySpeed += 8;
        }
        this.y = this.floatY >> 4;
        if (this.ySpeed < -96 && this.y % 2 == 0 && this.weapon != 4) {
            myCanvas.fxAdd(this.x + 4, this.y + 16, 1, 0);
        }
        if (this.y > 148) {
            if (!this.Died) {
                this.initDie();
                this.floatY = this.y << 4;
                this.ySpeed = 0;
                this.xSpeed = 0;
                this.diedCounter = 48;
            }
            this.y = 320;
        }
        if (this.ySpeed < 0) {
            tx = this.x + 1 >> 4;
            int tx2 = this.x + 12 - 1 >> 4;
            ty = this.y >> 4;
            if (ty >= 0 && ty <= 31 && tx >= 0 && tx2 <= 196) {
                if (myWorld.isSolidBelow(tx, ty) || myWorld.isSolidBelow(tx2, ty)) {
                    this.ySpeed = 0;
                    this.y = (ty << 4) + 12 + 2;
                    this.floatY = this.y << 4;
                } else if (!this.onElevator) {
                    this.onGround = false;
                    if (this.ySpeed < 96) {
                        this.ySpeed += this.yIncrease;
                    }
                }
            } else if (tx2 > 196) {
                this.y = (ty << 4) + 12 + 1;
                this.floatY = this.y << 4;
                this.setOnGround();
                this.ySpeed = 0;
            } else if (!this.onElevator) {
                this.onGround = false;
                if (this.ySpeed < 96) {
                    this.ySpeed += this.yIncrease;
                }
            }
        } else {
            tx = this.x + 1 >> 4;
            int tx2 = this.x + 12 - 1 >> 4;
            ty = this.y + 12 >> 4;
            if (ty >= 0 && ty < 11 && tx >= 0 && tx < 196) {
                if (myWorld.isSolid(tx, ty) || myWorld.isSolid(tx2, ty)) {
                    this.yIncrease = 8;
                    this.y = (ty << 4) - 12;
                    this.floatY = this.y << 4;
                    this.setOnGround();
                    this.ySpeed = 0;
                } else if (!this.onElevator) {
                    this.onGround = false;
                    if (this.ySpeed < 96) {
                        this.ySpeed += this.yIncrease;
                    }
                }
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
        if (this.x >= 3120) {
            this.x = 3120;
            this.floatX = this.x << 4;
            this.xSpeed = 0;
        }
        if (myWorld.CameraIsView) {
            if (this.x < myWorld.lockScreen) {
                this.x = myWorld.lockScreen;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            }
            if (this.x < myWorld.worldOffset + 12) {
                this.x = myWorld.worldOffset + 12;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            } else if (this.x > myWorld.worldOffset + displayW - 12) {
                this.x = myWorld.worldOffset + displayW - 12;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            } else if (myWorld.lockScreen >= 0 && this.x > myWorld.lockScreen + displayW - 12) {
                this.x = myWorld.lockScreen + displayW - 12;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            } else if (myWorld.softLock > 0 && this.x > myWorld.softLock + displayW - 12) {
                this.x = myWorld.softLock + displayW - 12;
                this.floatX = this.x << 4;
                this.xSpeed = 0;
            }
        }
        ty = this.y + 2 >> 4;
        int ty2 = this.y + 12 - 2 >> 4;
        if (this.myDirection < 0) {
            tx = this.x >> 4;
            if (myWorld.isSolidBelow(tx, ty) || myWorld.isSolidBelow(tx, ty2)) {
                this.x = (tx << 4) + 16;
                this.xSpeed = 0;
                this.floatX = this.x << 4;
                if (this.leftPressed && !myWorld.isSolidBelow(tx, ty - 1)) {
                    this.inCover = true;
                }
            }
        } else if (this.myDirection > 0 && (myWorld.isSolidBelow(tx = this.x + 12 >> 4, ty) || myWorld.isSolidBelow(tx, ty2))) {
            this.x = (tx << 4) - 12;
            this.xSpeed = 0;
            this.floatX = this.x << 4;
            if (this.rightPressed && !myWorld.isSolidBelow(tx, ty - 1)) {
                this.inCover = true;
            }
        }
        if (this.actionDelay > 0) {
            this.actionDelay -= 16 >> myWorld.slowMoFactor;
        } else if (this.ammo > 0 && this.actionPressed || this.weapon == 4 && !this.onGround && !this.onChute) {
            this.actionPressed = false;
            ++this.actionBlocked;
            this.shoot(myWorld);
        }
        this.onElevator = false;
        this.blockPlayerMovement = false;
        myWorld.slowMoFactor = originalSlowMoFactor;
    }

    public void setOnGround() {
        if (!this.onGround && !this.onElevator && this.ySpeed > 24) {
            this.doLandSound = true;
            myCanvas.fxAdd(this.x + 4, this.y + 4, 2, 0);
        }
        this.onChute = false;
        this.onGround = true;
        this.onGroundCountdown = 2;
    }

    public void Paint(Texture mySprite, TileMap myWorld, SpriteBatch batch) {
        if (this.Died && this.diedCounter < 16 && this.diedCounter % 4 < 2) {
            return;
        }
        batch.begin();
        batch.setColor(1.0f, 1.0f, 1.0f, 1.0f);
        if (this.invincableCounter % 4 < 2) {
            if (this.inTank) {
                int tx = this.x - myWorld.worldOffset;
                int ty = this.y - myWorld.worldOffsetY - 19;
                dest.set(tx, ty, tx + 12, ty + 12);
                src.set(this.Frame, this.MirrorFrame, this.Frame + 12, this.MirrorFrame + 12);
                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                if (this.myDirection < 0) {
                    dest.set(tx + 2, ty + 6, tx + 8, ty + 8);
                } else {
                    dest.set(tx + 4, ty + 6, tx + 10, ty + 8);
                }
                src.set(73, 24, 79, 26);
                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
            } else {
                int tx = this.x - myWorld.worldOffset;
                int ty = this.y - myWorld.worldOffsetY;
                batch.setColor(1.0f, 1.0f, 1.0f, (float)this.doorAlpha / 255.0f);
                dest.set(tx, ty, tx + 12, ty + 12);
                src.set(this.Frame, this.MirrorFrame, this.Frame + 12, this.MirrorFrame + 12);
                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                if (this.openMouth > 0) {
                    if (this.myDirection < 0) {
                        dest.set(tx + 2, ty + 6, tx + 8, ty + 8);
                    } else {
                        dest.set(tx + 4, ty + 6, tx + 10, ty + 8);
                    }
                    src.set(73, 24, 79, 26);
                    batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                }
                if (!this.Died) {
                    if (this.hasArmor) {
                        if (this.myDirection > 0) {
                            dest.set(tx, ty + 6, tx + 11, ty + 12);
                            src.set(37, 53, 48, 59);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                        } else {
                            dest.set(tx + 1, ty + 6, tx + 12, ty + 12);
                            src.set(48, 53, 59, 59);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                        }
                    }
                    if (this.Frame == 24) {
                        ++ty;
                    }
                    switch (this.weapon) {
                        case 1: {
                            if (this.myDirection < 0) {
                                ty = this.inCover ? (ty -= 2) : (ty += 8);
                                dest.set(tx, ty, tx + 9, ty + 3);
                                src.set(9, 24, 18, 27);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                if (this.inCover) {
                                    ty += 2;
                                    break;
                                }
                                ty -= 8;
                                break;
                            }
                            ty = this.inCover ? (ty -= 2) : (ty += 8);
                            dest.set(tx += 3, ty, tx + 9, ty + 3);
                            src.set(0, 24, 9, 27);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            tx -= 3;
                            if (this.inCover) {
                                ty += 2;
                                break;
                            }
                            ty -= 8;
                            break;
                        }
                        case 2: {
                            if (this.myDirection < 0) {
                                ty = this.inCover ? (ty -= 2) : (ty += 8);
                                dest.set(tx, ty, tx + 10, ty + 4);
                                src.set(48, 24, 58, 28);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                if (this.inCover) {
                                    ty += 2;
                                    break;
                                }
                                ty -= 8;
                                break;
                            }
                            ty = this.inCover ? (ty -= 2) : (ty += 8);
                            dest.set(tx += 2, ty, tx + 10, ty + 4);
                            src.set(37, 24, 47, 28);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            tx -= 2;
                            if (this.inCover) {
                                ty += 2;
                                break;
                            }
                            ty -= 8;
                            break;
                        }
                        case 3: {
                            if (this.myDirection < 0) {
                                ty = this.inCover ? (ty -= 2) : (ty += 6);
                                dest.set(tx, ty, tx + 11, ty + 6);
                                src.set(48, 28, 59, 34);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                if (this.inCover) {
                                    ty += 2;
                                    break;
                                }
                                ty -= 6;
                                break;
                            }
                            ty = this.inCover ? (ty -= 2) : (ty += 6);
                            dest.set(++tx, ty, tx + 11, ty + 6);
                            src.set(37, 28, 48, 34);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            --tx;
                            if (this.inCover) {
                                ty += 2;
                                break;
                            }
                            ty -= 6;
                            break;
                        }
                        case 4: {
                            if (this.myDirection < 0) {
                                dest.set(tx += 9, ty += 6, tx + 7, ty + 7);
                                src.set(66, 24, 73, 31);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                tx -= 9;
                                ty -= 6;
                                break;
                            }
                            dest.set(tx -= 3, ty += 6, tx + 7, ty + 7);
                            src.set(59, 24, 66, 31);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            tx += 3;
                            ty -= 6;
                            break;
                        }
                        case 6: {
                            if (this.myDirection < 0) {
                                dest.set(tx += 3, ty += 3, tx + 8, ty + 8);
                                src.set(45, 34, 53, 42);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                tx -= 3;
                                ty -= 3;
                                break;
                            }
                            dest.set(++tx, ty += 3, tx + 8, ty + 8);
                            src.set(37, 34, 45, 41);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            --tx;
                            ty -= 3;
                            break;
                        }
                        case 7: {
                            if (this.myDirection < 0) {
                                ty = this.inCover ? (ty -= 2) : (ty += 7);
                                dest.set(++tx, ty, tx + 10, ty + 4);
                                src.set(47, 41, 57, 45);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                --tx;
                                if (this.inCover) {
                                    ty += 2;
                                    break;
                                }
                                ty -= 7;
                                break;
                            }
                            ty = this.inCover ? (ty -= 2) : (ty += 7);
                            dest.set(++tx, ty, tx + 10, ty + 4);
                            src.set(37, 41, 47, 45);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            --tx;
                            if (this.inCover) {
                                ty += 2;
                                break;
                            }
                            ty -= 7;
                            break;
                        }
                        case 8: {
                            if (this.myDirection > 0) {
                                ty = this.inCover ? (ty -= 2) : (ty += 8);
                                dest.set(tx + 12, ty, tx + 17, ty + 3);
                                src.set(0, 24, 5, 27);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                dest.set(tx - 2, ty, tx + 3, ty + 3);
                                src.set(13, 24, 18, 27);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                if (this.inCover) {
                                    ty += 2;
                                    break;
                                }
                                ty -= 8;
                                break;
                            }
                            ty = this.inCover ? (ty -= 2) : (ty += 8);
                            dest.set(tx + 10, ty, tx + 15, ty + 3);
                            src.set(0, 24, 5, 27);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            dest.set(tx - 2, ty, tx + 3, ty + 3);
                            src.set(13, 24, 18, 27);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            if (this.inCover) {
                                ty += 2;
                                break;
                            }
                            ty -= 8;
                            break;
                        }
                        case 9: {
                            if (this.myDirection < 0) {
                                ty = this.inCover ? (ty -= 2) : (ty += 7);
                                dest.set(++tx, ty, tx + 11, ty + 6);
                                src.set(65, 34, 76, 40);
                                batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                                --tx;
                                if (this.inCover) {
                                    ty += 2;
                                    break;
                                }
                                ty -= 7;
                                break;
                            }
                            ty = this.inCover ? (ty -= 2) : (ty += 7);
                            dest.set(++tx, ty, tx + 11, ty + 6);
                            src.set(54, 34, 65, 40);
                            batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                            --tx;
                            if (this.inCover) {
                                ty += 2;
                                break;
                            }
                            ty -= 7;
                        }
                    }
                }
                if (this.onChute) {
                    dest.set(tx -= 13, ty -= 30, tx + 37, ty + 32);
                    src.set(0, 27, 37, 59);
                    if (this.xSpeed != 0) {
                        TextureRegion region = new TextureRegion(mySprite, Player.src.left, Player.src.top, Player.src.width, Player.src.height);
                        region.flip(false, true);
                        batch.draw(region, Player.dest.left, Player.dest.top, 19.0f, 32.0f, Player.dest.width, Player.dest.height, 1.0f, 1.0f, -(this.xSpeed >> 3));
                        region = null;
                    } else {
                        batch.draw(mySprite, (float)Player.dest.left, (float)Player.dest.top, (float)Player.dest.width, (float)Player.dest.height, Player.src.left, Player.src.top, Player.src.width, Player.src.height, false, true);
                    }
                }
            }
        }
        batch.end();
    }
}
