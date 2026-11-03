/*
 * Decompiled with CFR 0.152.
 */
package com.orangepixel.gunslugs3.ai;

import com.badlogic.gdx.graphics.Texture;
import com.orangepixel.controller.GameInput;
import com.orangepixel.gunslugs3.Globals;
import com.orangepixel.gunslugs3.InventoryItem;
import com.orangepixel.gunslugs3.Trainer;
import com.orangepixel.gunslugs3.World;
import com.orangepixel.gunslugs3.ai.BulletEntityList;
import com.orangepixel.gunslugs3.ai.EntitySprite;
import com.orangepixel.gunslugs3.ai.FXEntityList;
import com.orangepixel.gunslugs3.ai.MonsterEntityList;
import com.orangepixel.gunslugs3.myCanvas;
import com.orangepixel.gunslugs3.ui.uigameover;
import com.orangepixel.gunslugs3.ui.uiinventory;
import com.orangepixel.gunslugs3.ui.uiskills;
import com.orangepixel.utils.Audio;
import com.orangepixel.utils.Light;
import com.orangepixel.utils.Render;
import com.orangepixel.utils.Sprite;
import com.orangepixel.utils.SpriteList;

public class PlayerEntity
extends EntitySprite {
    public static final int propCharHP = 0;
    public static final int propCharBaseweapon = 1;
    public static final int propCharMeleeWeapon = 2;
    public static final int propCharBulletMax = 3;
    public static final int propCharExplosivesMax = 4;
    public static final int propCharEnergyMax = 5;
    public static final int propCharRunSpeed = 6;
    public static final int propCharJumpSpeed = 7;
    public static final int propCharSlowdownScale = 8;
    public static final int propMeleeReach = 9;
    public static final int propMeleeAttack = 10;
    public static final int propMagicLevel = 11;
    public static final int propComputerSkills = 12;
    public static final int propHackSignal = 13;
    public static final int propSabotage = 14;
    public static final int propBackpackSize = 15;
    public static final int propCharMax = 16;
    public static int[] myCharacterSpecs;
    public boolean upPressed;
    public boolean upLocked;
    public boolean rightPressed;
    public boolean downPressed;
    public boolean leftPressed;
    public boolean actionPressed;
    public boolean actionLocked;
    public boolean altActionPressed;
    public boolean altActionLocked;
    public boolean weaponSwapPressed;
    public boolean weaponSwapLocked;
    public boolean hideLocked;
    public int stick2OffsetX;
    public int stick2OffsetY;
    public int stickOffsetX;
    public int stickOffsetY;
    public boolean mouseAim;
    public boolean twinStick;
    public boolean autoAim;
    public int blockMovementCountDown;
    public int pushCountdown;
    public boolean isPushing;
    public boolean isOnRope;
    public boolean onParachute;
    public boolean inStealthAction;
    public int inStealthActionEntityUID;
    public int hasAltAction;
    public int onRopeDelay;
    public int idleHidingTimer;
    public boolean isCrouchModeActivated;
    public int currentXP;
    public int targetXP;
    public int levelXP;
    public int skillPoints;
    public int lives;
    public int maxLives;
    public int extendedLives;
    public int visualLives;
    public int livesHitCountdown;
    public int shield;
    public int maxShield;
    public int shieldType;
    public int maxHelmet;
    public int helmet;
    public int helmetType;
    public int shoeType;
    public int invincableCount;
    public int invisibilityCount;
    public int DoubleJumpCountDown;
    public boolean hasDoubleJump;
    public boolean hasSilentShoes;
    public boolean hasEagleVision;
    public boolean hasEliteSkills;
    public boolean hasMasterWeapon;
    public boolean hasWeaponExpert;
    public boolean hasAmmoDoubler;
    public int hasScavenger;
    public int hasStealthSkills;
    public boolean hasDisguise;
    public int maxReapedSouls;
    public int reapedSouls;
    public int[] ammoTypes;
    public int[] ammoTypesMax;
    public int myBaseWeapon;
    public EntitySprite myElevator;
    public int weaponSwapActionDuration;
    public int maxInventorySize;
    public InventoryItem[] inventory;
    public InventoryItem activeItem;
    private InventoryItem[] backPackItems;
    public int[] weaponSlots;
    public int swapWeaponNotification;
    public int weaponSlotID;
    public int holdingInventoryItem;
    public int holdingInventoryItemCountdown;
    public boolean onLedge;
    public boolean onLedgeDelay;
    public int onLedgeCountdown;
    public boolean onEntity;
    public boolean doPowerDrop;
    public int hitComboCount;
    public int hitComboResetDelay;
    public int inDangerDelay;
    public int breathSpeed;
    public static final int animationBreath = 0;
    public static final int animationWalk = 1;
    public static final int animationJumpUp = 2;
    public static final int animationDropdown = 3;
    public static final int animationBack = 4;
    public static final int aiDefault = 0;
    public static final int aiLedge = 1;
    public static final int aiLedgeDelay = 2;
    public static final int aiExitDoor = 3;
    public static final int aiParachuting = 4;
    public static final int aiInChopper = 5;
    public static final int aiClimbOutOfVent = 6;
    public static final int aiControlled = 7;
    public static final int aiOperating = 8;
    public static final int aiUppercut = 900;
    public static final int aiKilled = 901;
    public static final int[] animationHeadYoffset;
    public static final int[] verticalOffsetPerFrame;
    public Sprite myHead;
    public Sprite myWeapon;
    public Sprite myAltWeapon;
    private Sprite myParachute;
    public Sprite myShield;
    private Sprite myBackpack;
    public Sprite myItem;
    private int jumpOffCountdown;
    private int weaponOffsetXKickback;
    public float weaponSlowDown;
    public int autoFaceEnemyTurnCountdown;
    public int runningSpeedMax;
    public int jumpingSpeedMax;
    public boolean walkBackwards;
    private int EyeBlinkCountdown;
    private int lastRenderHandleCount;
    private int firstHandleID;
    private int firstHandleImportance;
    public static final int handleWeak = 0;
    public static final int handleNormal = 1;
    public static final int handlePickup = 2;
    public static final int handleGrabEnemy = 3;

    public PlayerEntity() {
        this.x = Render.width >> 1;
        this.y = Render.height >> 1;
        this.floatX = this.x << 4;
        this.floatY = this.y << 4;
        this.w = 12;
        this.h = 5;
        this.spriteSet = 0;
        this.alpha = 255;
        this.depth = 0;
        this.renderPass = 6;
        this.name = "Hero";
        this.myHead = new Sprite();
        this.myHead.xOffset = 0;
        this.myHead.yOffset = 208;
        this.myHead.w = 12;
        this.myHead.h = 11;
        this.myHead.renderPass = this.renderPass;
        this.myItem = new Sprite();
        this.myItem.renderPass = this.renderPass;
        this.myWeapon = new Sprite();
        this.myWeapon.xOffset = 108;
        this.myWeapon.yOffset = 1;
        this.myWeapon.w = 12;
        this.myWeapon.h = 7;
        this.myWeapon.rotate = -90;
        this.myWeapon.pivotX = 0;
        this.myWeapon.pivotY = 3;
        this.weaponOffsetXKickback = 0;
        this.myWeapon.renderPass = this.renderPass;
        this.myAltWeapon = new Sprite();
        this.myAltWeapon.clone(this.myWeapon);
        this.myAltWeapon.rotate = -90;
        this.myAltWeapon.pivotY = 3;
        this.myAltWeapon.renderPass = this.renderPass;
        this.myParachute = new Sprite();
        this.myParachute.xOffset = 0;
        this.myParachute.yOffset = 85;
        this.myParachute.w = 37;
        this.myParachute.pivotY = this.myParachute.h = 32;
        this.myParachute.renderPass = this.renderPass;
        this.myShield = null;
        this.myBackpack = null;
        this.animationFrames = new int[][]{{3, 16, 1, 0, 5, 4}, {4, 4, 1, 1, 2, 3, 0}, {1, 16, 3, 1}, {0, 8, 3, 3}, {1, 16, 3, 6}};
        this.ammoTypes = new int[3];
        this.ammoTypesMax = new int[3];
        this.myType = 1;
        this.inventory = new InventoryItem[512];
    }

    public void initNewGame(int playerCharacter) {
        int i;
        this.myType = playerCharacter;
        myCharacterSpecs = new int[16];
        for (i = 0; i < 16; ++i) {
            PlayerEntity.myCharacterSpecs[i] = myCanvas.mySaveGame.charSpecs[this.myType][i];
        }
        this.EyeBlinkCountdown = 0;
        this.energy = 1000;
        this.breathSpeed = 0;
        this.hitComboCount = 0;
        this.hitComboResetDelay = 0;
        this.aiState = 0;
        this.died = false;
        this.invisibilityCount = 0;
        this.invisible = false;
        this.doPowerDrop = false;
        this.mouseAim = false;
        this.autoAim = true;
        this.twinStick = false;
        this.blockMovementCountDown = 0;
        this.leftPressed = false;
        this.rightPressed = false;
        this.downPressed = false;
        this.upPressed = false;
        this.altActionPressed = false;
        this.actionPressed = false;
        this.hideLocked = false;
        this.weaponSwapPressed = false;
        this.weaponSwapLocked = false;
        this.weaponSwapActionDuration = 0;
        this.stickOffsetX = 0;
        this.stickOffsetY = 0;
        this.stick2OffsetX = 0;
        this.stick2OffsetY = 0;
        this.maxLives = myCanvas.mySaveGame.charMaxLives[this.myType];
        this.lives = myCanvas.mySaveGame.charLives[this.myType];
        this.extendedLives = 0;
        this.visualLives = this.lives;
        if (this.lives == 0) {
            Globals.debug(" ERROR!  starting with 0 lives - playerID: " + this.myType);
        }
        this.ammoTypesMax[0] = myCharacterSpecs[3] + myCanvas.mySaveGame.difficulty * 5;
        this.ammoTypesMax[1] = myCharacterSpecs[4] + myCanvas.mySaveGame.difficulty * 5;
        this.ammoTypesMax[2] = myCharacterSpecs[5] + myCanvas.mySaveGame.difficulty * 5;
        this.ammoTypes[0] = myCanvas.mySaveGame.charBullets[this.myType][0];
        this.ammoTypes[1] = myCanvas.mySaveGame.charBullets[this.myType][1];
        this.ammoTypes[2] = myCanvas.mySaveGame.charBullets[this.myType][2];
        this.maxInventorySize = myCharacterSpecs[15];
        this.myBaseWeapon = myCharacterSpecs[1];
        this.activeItem = new InventoryItem();
        this.activeItem.itemIDX = -1;
        this.activeItem.itemUsageCount = 0;
        this.holdingInventoryItem = -1;
        for (i = 0; i < this.inventory.length; ++i) {
            int oldIdx = this.hasActiveItemByType(5);
            if (oldIdx >= 0) {
                this.deleteInventoryItem(this.inventory[oldIdx].itemIDX);
            }
            if ((oldIdx = this.hasActiveItemByType(4)) >= 0) {
                this.deleteInventoryItem(this.inventory[oldIdx].itemIDX);
            }
            if ((oldIdx = this.hasActiveItemByType(3)) < 0) continue;
            this.deleteInventoryItem(this.inventory[oldIdx].itemIDX);
        }
        this.weaponSlots = new int[3];
        this.weaponSlots[0] = myCanvas.mySaveGame.meleeWeaponID[this.myType];
        this.weaponSlots[1] = myCanvas.mySaveGame.attackWeaponID[this.myType];
        if (Globals.weapons[this.weaponSlots[1]][13] >= 0 && this.ammoTypes[Globals.weapons[this.weaponSlots[1]][13]] < Globals.weapons[this.weaponSlots[1]][14]) {
            this.ammoTypes[Globals.weapons[this.weaponSlots[1]][13]] = Globals.weapons[this.weaponSlots[1]][14];
        }
        this.myWeaponStrength = Globals.weapons[this.weaponSlots[0]][14];
        this.weaponSlotID = 0;
        this.myWeaponID = this.weaponSlots[this.weaponSlotID];
        this.myShield = null;
        if (this.myType == 0) {
            this.setBodyType(10);
        } else {
            this.setBodyType(this.myType - 1);
        }
        this.setHead(this.myHead, this.myType - 1);
        this.myHead.rotate = 0;
        this.rotate = 0;
        this.nearBy = 65535;
        this.nearByDangerLevel = -1;
        this.nearMonsterX = -1;
        this.nearMonsterY = -1;
        this.currentXP = myCanvas.mySaveGame.charXP[this.myType];
        this.levelXP = myCanvas.mySaveGame.charXPLevel[this.myType];
        this.skillPoints = myCanvas.mySaveGame.charXPPoints[this.myType];
        this.calculateTargetXP();
        this.reapedSouls = 0;
        this.shoeType = myCanvas.mySaveGame.shoeType[this.myType];
        if (this.shoeType > 0) {
            this.giveItem(this.shoeType);
        }
        this.helmetType = myCanvas.mySaveGame.helmetType[this.myType];
        this.shieldType = myCanvas.mySaveGame.shieldType[this.myType];
        this.shield = myCanvas.mySaveGame.shield[this.myType];
        this.maxShield = myCanvas.mySaveGame.maxShield[this.myType];
        this.helmet = myCanvas.mySaveGame.helmet[this.myType];
        this.maxHelmet = myCanvas.mySaveGame.maxHelmet[this.myType];
        if (this.myType == 0) {
            this.giveWeapon(8, -1);
        }
        this.prepWeaponSprite();
        this.beAlert = false;
        this.walkBackwards = false;
    }

    public void init(int aX, int aY) {
        super.init(0, 0, 0, 0, null, null);
        this.entityType = 1;
        this.isPlayer = true;
        this.initNewLevel(aX, aY);
    }

    public final void setPosition(int aX, int aY) {
        if (this.inHiding) {
            this.inHiding = false;
        }
        this.idleHidingTimer = 0;
        this.x = aX;
        this.y = aY;
        this.floatX = this.x << 4;
        this.floatY = this.y << 4;
        this.startX = this.floatX;
        this.startY = this.floatY;
    }

    public final void initNewLevel(int aX, int aY) {
        this.setPosition(aX, aY);
        this.jumpOffCountdown = 0;
        this.w = 15;
        this.h = 13;
        this.collisionBoxWidthOffset = 0;
        this.collisionBoxTopOffset = 0;
        this.isClimbing = false;
        this.isOnRope = false;
        this.isPushing = false;
        this.isCrouching = false;
        this.isCrouchModeActivated = false;
        this.xOffset = 240;
        this.baseXOffset = 240;
        this.myDirection = 1;
        this.myOwnerEntity = null;
        this.backOfHead = false;
        this.myHead.renderPass = 6;
        this.inOperating = false;
        this.setAnimation(0);
        this.xSpeed = 64;
        this.ySpeed = 64;
        if (!World.inDoors) {
            this.aiState = 4;
            this.aiCountdown = 128;
            this.ySpeed = 8;
        } else {
            this.aiState = 0;
        }
        this.shotCount = 0;
        this.fireDelay = 0;
        this.reloadDelay = 0;
        this.invincableCount = 0;
        if (this.holdingInventoryItem == 20) {
            int m = MonsterEntityList.add(46, this.x - 8, this.y, 26, this);
            MonsterEntityList.myList[m].aiState = 3;
            MonsterEntityList.myList[m].fireDelay = 1;
            World.hasGeneralOutdoors = true;
            this.holdingInventoryItem = -1;
        }
    }

    public void update(World myWorld) {
        Trainer.onPlayerPreUpdate(this, myWorld);
        this.onScreen = true;
        if (this.inOperating) {
            this.aiState = 8;
        }
        this.decreaseInventoryItemFlash();
        if (this.lives > 0) {
            this.visible = true;
        }
        if (this.aiState != 6) {
            this.alpha = 255;
        }
        if (this.kickBackDelay > 0) {
            --this.kickBackDelay;
        }
        if (this.swapWeaponNotification > 0) {
            --this.swapWeaponNotification;
        }
        if (this.invincableCount > 0) {
            --this.invincableCount;
        }
        if (this.invisibilityCount > 0) {
            this.invisible = true;
            --this.invisibilityCount;
        } else {
            this.invisible = false;
        }
        if (World.CameraTakeOver && this.invincableCount < 4) {
            this.invincableCount = 4;
        }
        if (this.helmet > 0 && this.helmetType == 3) {
            this.invisible = true;
            if (this.alpha > 100) {
                this.alpha = 100;
            }
            --this.helmet;
            if (this.helmet <= 0) {
                this.setHead(this.myHead, this.myType - 1);
                this.invisible = false;
                this.invisibilityCount = 0;
                this.alpha = 255;
                this.deleteInventoryItem(this.helmetType);
                this.helmetType = -1;
            }
        }
        this.myHead.alpha = this.alpha;
        if (!this.altActionPressed) {
            this.altActionLocked = false;
        }
        if (!this.weaponSwapPressed) {
            this.weaponSwapLocked = false;
        }
        if (this.died) {
            return;
        }
        if (this.livesHitCountdown > 0) {
            --this.livesHitCountdown;
        }
        if (this.hitCountdown > 0) {
            --this.hitCountdown;
        }
        if (this.aiState == 7) {
            if (!this.invisible) {
                SpriteList.addSprite(this.myHead);
            }
            return;
        }
        if ((this.mouseAim || this.twinStick) && this.weaponAmmoType != -1) {
            this.nearMonsterX = this.x + this.stick2OffsetX;
            this.nearMonsterY = this.y + this.stick2OffsetY;
            this.nearBy = 14;
        }
        if (this.reloadDelay > 0) {
            --this.reloadDelay;
        } else if (this.fireDelay > 0) {
            --this.fireDelay;
        } else if (this.shotCount > 0) {
            if (this.ammoTypes[this.weaponAmmoType] > 0) {
                this.doShoot(this.myWeapon, 0, true, true);
                World.setScreenshake(1);
                int n = this.weaponAmmoType;
                this.ammoTypes[n] = this.ammoTypes[n] - 1;
                if (this.ammoTypes[this.weaponAmmoType] <= 0) {
                    this.ammoTypes[this.weaponAmmoType] = 0;
                }
                this.weaponOffsetXKickback = 2;
            } else {
                this.shotCount = 0;
            }
        } else if (this.weaponAmmoType >= 0 && this.ammoTypes[this.weaponAmmoType] <= 0) {
            if (this.myWeaponID != this.myBaseWeapon) {
                this.throwWeapon(true);
            }
            this.setActiveWeapon(0, false);
        }
        if (this.fireDelay < 3 && this.weaponOffsetXKickback > 0) {
            --this.weaponOffsetXKickback;
        }
        if (!this.actionPressed) {
            this.actionLocked = false;
        }
        if (this.onRopeDelay > 0) {
            --this.onRopeDelay;
        }
        this.onParachute = false;
        this.inCover = false;
        int oldSlowMo = World.slowmotion;
        int maxSpeed = this.runningSpeedMax;
        this.walkBackwards = false;
        this.inStealthAction = false;
        this.inStealthActionEntityUID = -1;
        if (this.holdingInventoryItem < 0 && this.nearMonsterX != -1 && this.nearByDirection == this.myDirection && this.nearByXAbs < 26 && this.nearByYAbs < 16 && this.onGround && (this.myDirection == 1 && this.nearMonsterX > this.x || this.myDirection == 3 && this.nearMonsterX < this.x)) {
            if (!(this.inHiding || this.inCover || this.inOperating || this.myOwnerEntity != null)) {
                this.inStealthAction = true;
                this.inStealthActionEntityUID = this.nearMonsterID;
            }
            if (this.weaponAmmoType == -1) {
                maxSpeed = this.runningSpeedMax >> 1;
                World.setZoom(0.8f);
            }
        } else if (this.holdingInventoryItem == 19 || this.holdingInventoryItem == 20) {
            maxSpeed = this.runningSpeedMax >> 1;
            this.walkBackwards = true;
        } else if (this.shieldType == 19) {
            maxSpeed = 2 + (this.runningSpeedMax >> 2);
        }
        if (this.isCrouching || this.isCrouchModeActivated) {
            maxSpeed = this.runningSpeedMax >> 2;
        }
        int accelStep = 4;
        if (Trainer.moveSpeed2x) {
            maxSpeed <<= 1;
            accelStep = 8;
        }
        this.isCrouchModeActivated = false;
        switch (this.aiState) {
            case 0: {
                this.rotate = 0;
                this.myHead.rotate = 0;
                if (this.leftPressed) {
                    if (this.xSpeed > -maxSpeed) {
                        this.xSpeed -= accelStep;
                    } else if (this.xSpeed < -maxSpeed) {
                        this.xSpeed += accelStep;
                    }
                    this.myDirection = 3;
                    World.doFoliage(this.x >> 4, this.y >> 4, this.xSpeed);
                } else if (this.rightPressed) {
                    if (this.xSpeed < maxSpeed) {
                        this.xSpeed += accelStep;
                    } else if (this.xSpeed > maxSpeed) {
                        this.xSpeed -= accelStep;
                    }
                    this.myDirection = 1;
                    World.doFoliage(this.x >> 4, this.y >> 4, this.xSpeed);
                } else if (this.kickBackDelay == 0) {
                    if (this.pushCountdown > 0) {
                        --this.pushCountdown;
                    }
                    this.xSpeed = 0;
                }
                if (this.doHorizontalPlatform(myWorld, true, true, true, true)) {
                    if (!this.inOperating && this.myDirection == 3 && !World.isSolidTile((this.x >> 4) - 1, (this.y >> 4) - 1, true) && this.leftPressed || this.myDirection == 1 && !World.isSolidTile((this.x >> 4) + 1, (this.y >> 4) - 1, true) && this.rightPressed) {
                        this.inCover = true;
                    }
                    if (this.pushCountdown < 24) {
                        ++this.pushCountdown;
                    }
                } else {
                    if (this.pushCountdown > 0) {
                        --this.pushCountdown;
                    }
                    if (this.onGround && World.worldAge % this.hasStealthSkills == 0 && this.xSpeed != 0 && !this.hasSilentShoes && !this.invisible) {
                        if (this.isCrouching) {
                            BulletEntityList.add(19, this.x + (this.w >> 1), this.y + this.h, 0, 0, 48, this);
                        } else {
                            BulletEntityList.add(19, this.x + (this.w >> 1), this.y + this.h, 0, 0, 128, this);
                        }
                    }
                }
                this.isPushing = this.pushCountdown > 16;
                if (Trainer.unlimitedJump) {
                    this.hasDoubleJump = true;
                    this.DoubleJumpCountDown = 99;
                }
                if (this.upPressed && (!this.upLocked || this.isClimbing)) {
                    if (this.isClimbing) {
                        this.ySpeed = -8;
                    } else if (this.onGround || this.onEntity || this.jumpOffCountdown > 0 || this.DoubleJumpCountDown > 0) {
                        if (!this.onGround && !this.onEntity) {
                            --this.DoubleJumpCountDown;
                        }
                        this.ySpeed = -this.jumpingSpeedMax;
                        this.jumpOffCountdown = 0;
                    }
                    this.upLocked = true;
                } else if (this.downPressed) {
                    if (this.isClimbing) {
                        this.ySpeed = 8;
                    } else {
                        this.isCrouchModeActivated = true;
                    }
                } else if (this.isClimbing) {
                    if (GameInput.isTouchscreen) {
                        this.ySpeed = 8;
                    }
                    this.ySpeed = 0;
                }
                if (!this.upPressed) {
                    this.upLocked = false;
                }
                if (this.myDirection == 1) {
                    this.flipX = false;
                } else if (this.myDirection == 3) {
                    this.flipX = true;
                }
                if (this.walkBackwards) {
                    this.flipX = !this.flipX;
                }
                this.onGround = false;
                this.doVerticalPlatform(myWorld, true, !this.hasSilentShoes && !this.isCrouchModeActivated, !this.isClimbing && this.downPressed, true);
                if (this.onGround) {
                    if (this.onLedgeCountdown > 0) {
                        --this.onLedgeCountdown;
                    } else {
                        this.onLedgeDelay = false;
                    }
                    this.gravityMax = 64;
                    if (this.doPowerDrop) {
                        this.doPowerDrop = false;
                        World.setScreenshake(2);
                        for (int i = 0; i < 4; ++i) {
                            FXEntityList.add(1, this.x + this.getMyRandomValue(this.w), this.y + this.getMyRandomValue(8), 0, this);
                            FXEntityList.add(7, this.x + this.getMyRandomValue(this.w), this.y + this.getMyRandomValue(8), 16 + this.getMyRandomValue(8), this);
                        }
                        Audio.playSoundPitched(Audio.FX_DROPLANDING);
                    }
                }
                if (this.onEntity) {
                    this.onGround = true;
                }
                if (this.onGround) {
                    this.DoubleJumpCountDown = this.hasDoubleJump ? 1 : 0;
                    this.jumpOffCountdown = 8;
                } else if (this.jumpOffCountdown > 0) {
                    --this.jumpOffCountdown;
                }
                if (this.onGround || this.ySpeed < 0 || this.onLedgeDelay) break;
                this.startX = this.myDirection == 1 ? this.x + this.w + 4 >> 4 : this.x - 4 >> 4;
                this.startY = this.y >> 4;
                this.onLedge = false;
                if (this.rightPressed) {
                    if (!World.isSolid(this.startX - 1, this.startY, false)) {
                        if (!World.isSolid(this.startX - 1, this.startY - 1, false)) {
                            if (!World.isSolid(this.startX - 1, this.startY + 1, false)) {
                                if (World.isSolid(this.startX, this.startY, false)) {
                                    this.onLedge = true;
                                    this.xSpeedAdd = 1;
                                    this.x = (this.startX << 4) - this.w - this.collisionBoxWidthOffset;
                                    this.floatX = this.x << 4;
                                    FXEntityList.add(28, this.x + this.w - this.getMyRandomValue(4), this.y + this.getMyRandomValue(this.h), 0, this);
                                }
                            }
                        }
                    }
                }
                if (this.leftPressed) {
                    if (!World.isSolid(this.startX + 1, this.startY, false)) {
                        if (!World.isSolid(this.startX + 1, this.startY - 1, false)) {
                            if (!World.isSolid(this.startX + 1, this.startY + 1, false)) {
                                if (World.isSolid(this.startX, this.startY, false)) {
                                    this.onLedge = true;
                                    this.xSpeedAdd = -1;
                                    this.x = (this.startX + 1 << 4) - this.collisionBoxWidthOffset;
                                    this.floatX = this.x << 4;
                                    FXEntityList.add(28, this.x + this.getMyRandomValue(4), this.y + this.getMyRandomValue(this.h), 0, this);
                                }
                            }
                        }
                    }
                }
                if (!this.onLedge) break;
                this.aiState = 1;
                this.aiCountdown = 72;
                this.y = (this.startY << 4) + 4;
                this.floatY = this.y << 4;
                this.ySpeed = 0;
                this.startX = this.x;
                this.startY = this.y;
                break;
            }
            case 1: {
                ++this.onLedgeCountdown;
                if (this.aiCountdown > 0) {
                    --this.aiCountdown;
                }
                if (this.weaponSlots[0] != 13) {
                    if (this.aiCountdown == 0) {
                        ++this.ySpeed;
                        if (this.ySpeed > 12) {
                            this.ySpeed = 12;
                        }
                        this.doVerticalPlatform(myWorld, true, false, true, true);
                    }
                    if (this.aiCountdown == 0 || this.onLedgeCountdown >= 16) {
                        this.aiState = 0;
                        this.onLedgeDelay = true;
                        this.onLedge = false;
                    }
                }
                this.pivotX = this.w >> 1;
                this.pivotY = 0;
                this.rotate += this.xSpeedAdd;
                if (this.rotate > 4) {
                    this.xSpeedAdd = -1;
                } else if (this.rotate <= -4) {
                    this.xSpeedAdd = 1;
                }
                if (this.leftPressed && this.myDirection == 3 || this.rightPressed && this.myDirection == 1) {
                    --this.animDelay;
                    if (this.upPressed) {
                        if (this.animDelay <= 0) {
                            this.y -= 8;
                            this.floatY = this.y << 4;
                            this.ySpeed = -32;
                            if (this.rightPressed) {
                                this.xSpeed = -16;
                            } else if (this.leftPressed) {
                                this.xSpeed = 16;
                            }
                            this.floatX = this.x << 4;
                            Audio.playSoundPitched(Audio.FX_MALEEFFORT);
                            this.onLedge = false;
                            this.aiState = 0;
                        }
                        if (World.worldAge % 3 != 0) break;
                        break;
                    }
                    this.x = this.startX;
                    this.floatX = this.x << 4;
                    break;
                }
                this.aiState = 0;
                break;
            }
            case 3: {
                this.alpha -= 8;
                if (this.alpha <= 0) {
                    this.alpha = 0;
                    World.exitLevel = true;
                    break;
                }
                --this.floatY;
                this.y = this.floatY >> 4;
                break;
            }
            case 4: {
                World.lockCameraY = 2080 - Render.height;
                this.invincableCount = 2;
                this.onParachute = true;
                this.gravityMax = 128;
                if (this.leftPressed) {
                    if (this.xSpeed > -64) {
                        this.xSpeed -= 2;
                    }
                    this.myDirection = 3;
                } else if (this.rightPressed) {
                    if (this.xSpeed < 64) {
                        this.xSpeed += 2;
                    }
                    this.myDirection = 1;
                }
                if (this.myDirection == 1) {
                    this.flipX = false;
                } else if (this.myDirection == 3) {
                    this.flipX = true;
                }
                if (this.ySpeed > -64 && this.y > 1920) {
                    this.ySpeed -= 12;
                }
                if (this.ySpeed <= 4 && this.xSpeed > 0) {
                    this.xSpeed -= 2;
                    if (this.xSpeed <= 0) {
                        this.xSpeed = 0;
                    }
                }
                this.doHorizontalPlatform(myWorld, true, true, true, true);
                if (this.doVerticalPlatform(myWorld, true, false, true, true)) {
                    this.aiState = 0;
                    World.lockCameraY = -1;
                }
                this.myParachute.x = this.x - 13 - (this.xSpeed >> 2);
                this.myParachute.y = this.y - 34;
                this.myParachute.rotate = -this.xSpeed;
                if (this.visible) {
                    SpriteList.addSprite(this.myParachute);
                }
                if (this.aiCountdown > 0) {
                    --this.aiCountdown;
                }
                if ((World.doSlowmotion != 0 || this.ySpeed >= -64) && this.aiCountdown > 0) break;
                this.actionLocked = true;
                this.doPowerDrop = true;
                World.lockCameraY = -1;
                this.aiState = 0;
                this.ySpeed = -14;
                int f = FXEntityList.add(12, this.myParachute.x, this.myParachute.y, 0, this);
                if (f < 0) break;
                FXEntityList.myList[f].rotate = this.myParachute.rotate;
                break;
            }
            case 5: {
                this.xSpeed = 0;
                this.ySpeed = 0;
                this.x = this.myOwnerEntity.x + 30;
                this.y = this.myOwnerEntity.y + 16;
                this.myDirection = 3;
                this.flipX = true;
                this.onGround = false;
                this.invincableCount = 4;
                break;
            }
            case 6: {
                World.setInstructions(0, 13);
                if (World.inVents) {
                    if (this.aiCountdown > 0) {
                        this.visible = false;
                        --this.aiCountdown;
                        break;
                    }
                    this.visible = true;
                    this.aiState = 0;
                    break;
                }
                this.myOwnerEntity = this;
                this.visible = false;
                this.invisible = true;
                --this.aiCountdown;
                if (this.aiCountdown > 0) break;
                this.visible = true;
                this.invisible = false;
                this.myOwnerEntity = null;
                this.aiState = 0;
                break;
            }
            case 900: {
                this.myHead.rotate += this.xSpeed >> World.slowmotion;
                if (this.doVerticalPlatform(myWorld, true, true, true, true)) {
                    this.ySpeed = this.ySpeedAdd;
                    if (this.ySpeedAdd > 0) {
                        if (this.died) {
                            this.aiState = 901;
                            this.aiCountdown = 32;
                            this.died = true;
                            FXEntityList.add(1, this.x, this.y, 4, this);
                            FXEntityList.add(8, this.x, this.y, 0, this);
                        } else {
                            this.xSpeed = 0;
                            this.ySpeed = 0;
                            this.aiState = 0;
                            this.rotate = 0;
                            this.myHead.rotate = 0;
                        }
                    }
                    this.ySpeedAdd += 16;
                }
                this.doHorizontalPlatform(myWorld, true, true, false, true);
                FXEntityList.add(8, this.x, this.y, 0, this);
                break;
            }
            case 901: {
                if (this.xSpeed < 0) {
                    this.xSpeed += 2;
                    if (this.xSpeed > 0) {
                        this.xSpeed = 0;
                    }
                } else if (this.xSpeed > 0) {
                    this.xSpeed -= 2;
                    if (this.xSpeed <= 0) {
                        this.xSpeed = 0;
                    }
                }
                if (this.aiCountdown > 0) {
                    --this.aiCountdown;
                } else {
                    this.died = true;
                    FXEntityList.add(1, this.x, this.y, 4, this);
                    FXEntityList.add(8, this.x, this.y, 0, this);
                    World.securityAlarmLevel = 0;
                    World.isSecurityAlarm = false;
                }
                this.doHorizontalPlatform(myWorld, true, true, false, true);
                this.doVerticalPlatform(myWorld, true, true, true, true);
                break;
            }
            case 8: {
                this.rotate = 0;
                this.myHead.rotate = 0;
                this.doHorizontalPlatform(myWorld, true, true, true, true);
                this.doVerticalPlatform(myWorld, true, true, false, true);
                if (this.inOperating) break;
                this.aiState = 0;
                this.backOfHead = false;
                this.myHead.renderPass = 6;
            }
        }
        World.slowmotion = oldSlowMo;
        this.y -= 9;
        this.h += 9;
        if (!this.died && this.invincableCount == 0 && !this.onParachute && !this.invisible && this.aiState != 6 && this.collisionDetectionBulletsIgnore(0) && this.hitCountdown == 0) {
            if (this.lastCollidedWith.myType >= 15) {
                this.initUppercut();
            }
            this.lastCollidedWith.die();
            this.hitMe(this.lastCollidedWith);
        }
        this.y += 9;
        this.h -= 9;
        if (!World.inDoors && this.y > 2128) {
            if (Trainer.godMode) {
                this.y = 1900;
                this.ySpeed = -32;
                this.lives = Math.max(this.lives, this.maxLives);
            } else {
                World.hasBriefcase = false;
                this.lives = -1;
            }
        }
        if (this.lives <= 0 && !Trainer.godMode) {
            this.lives = 0;
            World.doSlowmotion = 16;
            this.inOperating = false;
            this.myOwnerEntity = null;
            this.backOfHead = false;
            this.myHead.renderPass = 6;
            this.die();
            FXEntityList.add(1, this.x, this.y, 4, this);
            this.visible = false;
            myCanvas.mySaveGame.charDied[this.myType] = true;
            this.backPackItems = new InventoryItem[this.inventory.length];
            int b = 0;
            for (int i = 0; i < this.inventory.length; ++i) {
                if (this.inventory[i].itemIDX < 0 || this.inventory[i].itemType != 0) continue;
                this.backPackItems[b] = new InventoryItem();
                this.backPackItems[b].clone(this.inventory[i]);
                ++b;
            }
            MonsterEntityList.add(12, this.x, this.y, 21, this);
            if (this.weaponSlots[0] == 18) {
                MonsterEntityList.add(13, this.x, this.y, 18, this);
                this.weaponSlots[0] = 10;
            }
            uigameover.init();
            return;
        }
        if (this.onGround && !this.inOperating && this.xSpeed == 0 && this.ySpeed == 0 && !this.actionPressed && !this.actionLocked) {
            if (this.idleHidingTimer >= 48) {
                this.isCrouching = true;
            } else {
                ++this.idleHidingTimer;
            }
        } else {
            this.idleHidingTimer = 0;
            this.isCrouching = false;
        }
        if (this.isCrouchModeActivated) {
            this.isCrouching = true;
        }
        if (!this.inHiding && this.childUID >= 0) {
            this.childUID = FXEntityList.getEntityListIDX(this.childUID);
            FXEntityList.myList[this.childUID].myOwnerEntity = null;
            FXEntityList.myList[this.childUID].aiState = 1;
            FXEntityList.myList[this.childUID].xSpeed = this.myDirection == 1 ? -FXEntityList.myList[this.childUID].getMyRandomValue(32) : FXEntityList.myList[this.childUID].getMyRandomValue(32);
            this.childUID = -1;
        }
        if (this.aiState == 4) {
            this.xOffset = this.baseXOffset + 8 * this.w;
        }
        if (this.backOfHead && this.inOperating) {
            this.setAnimation(4);
        } else if (this.inCover) {
            this.setAnimationFrame(5);
        } else if (this.ySpeed < 0) {
            this.setAnimation(2);
        } else if (!this.onGround) {
            this.setAnimation(3);
        } else if (this.xSpeed == 0) {
            this.setAnimation(0);
        } else if (!this.inHiding) {
            this.setAnimation(1);
            if (this.shoeType != 11 && !this.isCrouching) {
                World.doFootstepsSound = true;
            }
        }
        if (!(this.onLedge || this.inCover || this.isClimbing && this.ySpeed == 0)) {
            this.animateMe();
        }
        if (this.flipX) {
            this.myAltWeapon.x = this.x + this.w - 3;
            this.myAltWeapon.y = this.myHead.y + 6;
            this.myAltWeapon.rotate = -84;
        } else {
            this.myAltWeapon.x = this.x + 3;
            this.myAltWeapon.y = this.myHead.y + 6;
            this.myAltWeapon.rotate = -96;
        }
        if (this.visible && !this.inHiding && !this.backOfHead) {
            SpriteList.addSprite(this.myAltWeapon);
        }
        if (this.myBackpack != null) {
            this.myBackpack.flipX = this.flipX;
            if (this.flipX) {
                this.myBackpack.x = this.x + 7;
                this.myBackpack.y = this.myHead.y;
            } else {
                this.myBackpack.x = this.x - 4;
                this.myBackpack.y = this.myHead.y;
            }
            if (this.visible && !this.inHiding && !this.backOfHead) {
                SpriteList.addSprite(this.myBackpack);
            }
        }
        if (this.onGround && this.y > 0 && this.y < 132) {
            this.y += World.yOffsetMap[(this.x + 4 >> 4) + (this.y + this.h >> 4) * 196];
        }
        this.y += verticalOffsetPerFrame[this.animationFrames[this.animationCycle][3 + this.animationFrame]];
        if (this.visible && !this.inHiding) {
            SpriteList.addSprite(this);
        }
        this.y -= verticalOffsetPerFrame[this.animationFrames[this.animationCycle][3 + this.animationFrame]];
        this.myWeapon.rotate = this.weaponRotateAttack;
        this.myHead.flipX = this.flipX;
        if (this.nearBy != 65535 && this.aiState != 1) {
            if (this.nearMonsterX < this.x && !this.flipX) {
                this.myHead.flipX = true;
            } else if (this.nearMonsterX > this.x && this.flipX) {
                this.myHead.flipX = false;
            }
            double theta = !this.myHead.flipX ? Math.atan2(this.nearMonsterY - this.y, this.nearMonsterX - this.x) : Math.atan2(this.nearMonsterY - this.y, this.x - this.nearMonsterX);
            this.myHead.rotate = (int)Math.toDegrees(theta);
            if (this.myHead.rotate > 180) {
                this.myHead.rotate -= 360;
            }
            this.myWeapon.rotate = this.myHead.rotate;
            if (this.myHead.rotate > 32) {
                this.myHead.rotate = 32;
            } else if (this.myHead.rotate < -32) {
                this.myHead.rotate = -32;
            }
            if (this.myHead.flipX) {
                this.myHead.rotate = -this.myHead.rotate;
                this.myWeapon.rotate = -this.myWeapon.rotate;
            }
            if (this.xSpeed == 0 && !this.walkBackwards) {
                ++this.autoFaceEnemyTurnCountdown;
                if (this.autoFaceEnemyTurnCountdown > 32 && this.flipX != this.myHead.flipX) {
                    this.flipX = this.myHead.flipX;
                    this.myDirection = this.flipX ? 3 : 1;
                }
            } else {
                this.autoFaceEnemyTurnCountdown = 0;
            }
        } else {
            this.myHead.rotate = 0;
        }
        this.myHead.alpha = this.alpha;
        if (this.backOfHead) {
            this.myHead.rotate = 0;
            this.myHead.renderPass = 5;
            if (World.worldAge % 16 == 0) {
                this.myHead.y = this.y - (2 + this.getMyRandomValue(2));
                this.myHead.x = this.x + this.getMyRandomValue(2);
                this.myHead.flipX = false;
            }
            this.myHead.flipX = false;
            this.flipX = false;
            this.myHead.yOffset = 468;
        } else {
            this.myHead.x = this.flipX ? (this.myHead.flipX != this.flipX ? this.x + 1 : this.x - 3) : (this.myHead.flipX != this.flipX ? this.x + 2 : this.x + 6);
            this.myHead.y = this.y - 4 - animationHeadYoffset[this.animationFrames[this.animationCycle][3 + this.animationFrame]];
            this.myHead.y += verticalOffsetPerFrame[this.animationFrames[this.animationCycle][3 + this.animationFrame]];
            if (this.inHiding || this.inCover || this.isCrouching) {
                this.myHead.y += 4;
            } else if (this.weaponAmmoType == -1) {
                ++this.myHead.y;
            }
            if (this.hitCountdown > 0) {
                this.myHead.yOffset = 501;
            } else if (this.fireDelay > 0 || this.shotCount > 0 || this.reloadDelay > 0) {
                this.myHead.yOffset = 490;
            } else if (this.EyeBlinkCountdown > 0) {
                --this.EyeBlinkCountdown;
                this.myHead.yOffset = 479;
            } else {
                this.myHead.yOffset = 457;
                if (this.getMyRandomValue(100) > 90) {
                    this.EyeBlinkCountdown = 4;
                }
            }
        }
        this.myWeapon.flipX = this.myHead.flipX;
        if (this.myWeapon.flipX) {
            this.myWeapon.pivotX = this.myWeapon.w;
            this.myWeapon.pivotY = this.myWeapon.h >> 1;
        } else {
            this.myWeapon.pivotX = 0;
            this.myWeapon.pivotY = this.myWeapon.h >> 1;
        }
        if (this.weaponAmmoType == -1) {
            if (this.fireDelay == 0 && !this.onLedge) {
                if (this.myWeapon.flipX) {
                    this.myWeapon.rotate = -this.weaponRotateIdle;
                    this.myWeapon.x = this.x - this.weaponOffsetX;
                } else {
                    this.myWeapon.rotate = this.weaponRotateIdle;
                    this.myWeapon.x = this.x + this.weaponOffsetX + this.weaponOffsetXKickback;
                }
            } else {
                this.myWeapon.x = this.myWeapon.flipX ? this.x + 6 - this.weaponOffsetX - this.w + this.weaponOffsetXKickback : this.x + this.weaponOffsetX + this.weaponOffsetXKickback;
            }
            this.myWeapon.y = this.y + 6 + this.weaponOffsetY;
        } else {
            this.myWeapon.y = this.inCover || this.aiState == 1 ? this.y + this.weaponOffsetY - 8 : this.y + 6 + this.weaponOffsetY;
            this.myWeapon.x = !this.myWeapon.flipX ? this.x + this.weaponOffsetX - this.weaponOffsetXKickback : this.x - this.weaponOffsetX + this.weaponOffsetXKickback;
        }
        if (this.visible && !this.inHiding) {
            SpriteList.addSprite(this.myHead);
            if (!this.backOfHead || this.holdingInventoryItem == 19 || this.holdingInventoryItem == 20) {
                if (this.holdingInventoryItem < 0) {
                    SpriteList.addSprite(this.myWeapon);
                } else {
                    this.myItem.x = this.myDirection == 1 && !this.walkBackwards || this.myDirection == 3 && this.walkBackwards ? this.x + this.w - 4 : this.x - this.myItem.w + 4;
                    this.myItem.y = this.myHead.y + 8;
                    this.myItem.flipX = this.myWeapon.flipX;
                    this.myItem.renderPass = this.renderPass;
                    if (this.holdingInventoryItem == 19 || this.holdingInventoryItem == 20) {
                        this.myItem.y -= 8;
                        this.myItem.flipX = this.flipX;
                    } else {
                        this.myItem.flipX = this.myWeapon.flipX;
                    }
                    SpriteList.addSprite(this.myItem);
                }
            }
        }
        if (this.holdingInventoryItemCountdown > 0) {
            --this.holdingInventoryItemCountdown;
            if (this.holdingInventoryItemCountdown == 0 && this.holdingInventoryItem >= 0) {
                this.holdingInventoryItem = -1;
                this.holdingInventoryItemCountdown = -1;
                this.setActiveWeapon(1, false);
                Audio.playSoundPitched(Audio.FX_WHOOSH);
            }
        }
        if (this.actionPressed && !this.actionLocked && !World.doLevelDone && !this.inOperating) {
            if (this.holdingInventoryItem == 19 || this.holdingInventoryItem == 20) {
                this.holdingInventoryItem = -1;
            }
            if (this.holdingInventoryItem >= 0) {
                this.actionLocked = true;
                int b = -1;
                if (this.holdingInventoryItem == 29) {
                    b = BulletEntityList.add(3, this.x, this.y, -1, -1, 0, this);
                } else if (this.holdingInventoryItem == 33) {
                    b = BulletEntityList.add(13, this.x, this.y, -1, -1, 0, this);
                } else if (this.holdingInventoryItem == 37) {
                    MonsterEntityList.add(35, this.x, this.y + this.h, 0, this);
                } else {
                    b = BulletEntityList.add(12, this.x, this.y, -1, -1, this.holdingInventoryItem, this);
                }
                if (b >= 0) {
                    BulletEntityList.myList[b].isInVent = true;
                }
                this.holdingInventoryItem = -1;
                this.setActiveWeapon(1, false);
                Audio.playSoundPitched(Audio.FX_WHOOSH);
            } else if (this.weaponWarmUpCountdown > 0) {
                --this.weaponWarmUpCountdown;
            } else {
                this.actionLocked = true;
                if (Globals.weapons[this.myWeaponID][1] == 0) {
                    this.actionLocked = false;
                }
                if (this.weaponAmmoType < 0 || this.ammoTypes[this.weaponAmmoType] > 0) {
                    if (this.nearByDangerLevel > 1 && this.weaponAmmoType == -1 && this.nearByDirection == this.myDirection && this.nearByXAbs < this.myWeaponReach && this.nearByYAbs < 16 && (this.myDirection == 1 && this.nearMonsterX > this.x || this.myDirection == 3 && this.nearMonsterX < this.x)) {
                        if (this.myDirection == 1) {
                            this.setPosition(this.nearMonsterX - 8, this.nearMonsterY);
                        } else {
                            this.setPosition(this.nearMonsterX, this.nearMonsterY);
                        }
                    } else if (this.weaponAmmoType == -1 && this.onGround) {
                        Audio.playSoundPitched(Audio.FX_MELEEWHOOSH);
                        this.xSpeed = this.myDirection == 1 ? 48 : -48;
                        this.ySpeed = -24;
                    }
                    if (this.myWeaponID == 5) {
                        myCanvas.unlockAchievement(19);
                    }
                    this.doShoot(this.myWeapon, 0, true, false);
                    World.setScreenshake(1);
                    if (this.weaponAmmoType >= 0) {
                        int n = this.weaponAmmoType;
                        this.ammoTypes[n] = this.ammoTypes[n] - 1;
                        if (this.ammoTypes[this.weaponAmmoType] < 0) {
                            this.ammoTypes[this.weaponAmmoType] = 0;
                        }
                    }
                    this.weaponOffsetXKickback = 2;
                }
            }
        } else if (!this.actionPressed && this.myWeaponID >= 0) {
            this.weaponWarmUpCountdown = Globals.weapons[this.myWeaponID][0];
        }
        if (this.myShield != null) {
            this.myShield.flipX = this.myHead.flipX;
            this.myShield.y = this.y + 3 - animationHeadYoffset[this.animationFrames[this.animationCycle][3 + this.animationFrame]];
            if (this.shieldType == 19) {
                this.myShield.y -= 3;
            }
            this.myShield.x = !this.myShield.flipX ? (this.shieldType == 19 ? this.x + 8 : this.x + 8) : (this.shieldType == 19 ? this.x - 8 : this.x - 2);
            if (this.visible && !this.inHiding && !this.backOfHead) {
                SpriteList.addSprite(this.myShield);
            }
        }
        this.onEntity = false;
        this.isOnRope = false;
        if (!this.inOperating) {
            if (this.weaponSwapPressed && !this.weaponSwapLocked) {
                ++this.weaponSwapActionDuration;
                if (this.weaponSwapActionDuration > 16) {
                    this.weaponSwapActionDuration = 0;
                    this.weaponSwapLocked = true;
                    uiinventory.init(this);
                }
            } else if (!this.weaponSwapPressed && !this.weaponSwapLocked && this.weaponSwapActionDuration > 0) {
                this.weaponSwapLocked = true;
                this.weaponSwapActionDuration = 0;
                if (this.holdingInventoryItem >= 0) {
                    this.setActiveWeapon(0, true);
                } else if (this.weaponSlotID == 1) {
                    this.setActiveWeapon(0, true);
                } else if (this.ammoTypes[Globals.weapons[this.weaponSlots[1]][13]] > 0) {
                    this.setActiveWeapon(1, true);
                }
            }
        }
        if (this.holdingInventoryItem == 18) {
            BulletEntityList.add(21, this.x, this.y, -1, -1, 128, this);
        }
        if (this.hasAltAction > 0) {
            --this.hasAltAction;
        } else {
            this.firstHandleImportance = -1;
        }
        if (World.inDoors) {
            Light.addLight(this.x + 8, this.y + 2, 48.0f, 5, 0.8f, 0.8f, 1.0f, 0.8f, false);
        }
        this.beAlert = false;
        this.lastRenderHandleCount = this.firstHandleID;
        this.firstHandleID = -1;
        this.inOperating = false;
        this.nearMonsterID = -1;
    }

    @Override
    public final void animateCycleEnd() {
        switch (this.animationCycle) {
            case 0: {
                this.animDelay -= this.breathSpeed;
                if (this.animDelay < 0) {
                    this.animDelay = 0;
                }
                if (this.breathSpeed <= 0 || this.xSpeed != 0) break;
                --this.breathSpeed;
                break;
            }
            case 1: {
                if (this.breathSpeed < 16) {
                    ++this.breathSpeed;
                }
                FXEntityList.add(0, this.x + 7 - this.getMyRandomValue(3), this.y + this.h - this.getMyRandomValue(2), 0, null);
                break;
            }
            case 2: {
                if (this.onGround) break;
                this.animationFrame = this.animationFrames[this.animationCycle][0] - 1;
            }
        }
    }

    public final void increaseDanger(int dangerAdd) {
        this.dangerLevel += dangerAdd;
        if (this.dangerLevel > 200) {
            this.dangerLevel = 200;
        }
        if (dangerAdd > 200) {
            this.inDangerDelay = 0;
        }
    }

    public final boolean monsterNear(EntitySprite tmpMonster, World myWorld, int distanceTrigger) {
        if (tmpMonster.dangerLevel == 0 || this.died) {
            return false;
        }
        if (tmpMonster.dangerLevel < 3 && this.holdingInventoryItem > 0) {
            return false;
        }
        int cmx = tmpMonster.x + (tmpMonster.w >> 1);
        int cmy = tmpMonster.y + (tmpMonster.h >> 1);
        double distance = Math.sqrt((this.x - cmx) * (this.x - cmx) + (this.y - cmy) * (this.y - cmy));
        int stepX = this.x >> 4;
        int stepY = this.y >> 4;
        int mx = Math.abs(cmx - this.x) >> 4;
        int my = Math.abs(cmy - this.y) >> 4;
        if (my > 5 || mx > 10 || distance > 160.0) {
            return false;
        }
        int sx = this.x < cmx ? 1 : (this.x > cmx ? -1 : 0);
        int sy = this.y < cmy ? 1 : (this.y > cmy ? -1 : 0);
        int err = mx - my;
        boolean isBlocked = false;
        int itterateCount = 4;
        if (cmy > this.y - 16 && cmy < this.y + 16 && this.nearByDangerLevel < 5) {
            itterateCount = 0;
        }
        cmx >>= 4;
        cmy >>= 4;
        while (!(isBlocked || itterateCount <= 0 || stepX == cmx && stepY == cmy)) {
            if (World.isSolid(stepX, stepY, true)) {
                return false;
            }
            int e2 = err * 2;
            if (e2 > -my) {
                err -= my;
                stepX += sx;
            }
            if (e2 < mx) {
                err += mx;
                stepY += sy;
            }
            --itterateCount;
        }
        if (this.myDirection == 1 && tmpMonster.x < this.x && (distance > 70.0 || tmpMonster.dangerLevel < 2)) {
            distance += 24.0;
        }
        if (this.myDirection == 3 && tmpMonster.x > this.x && (distance > 70.0 || tmpMonster.dangerLevel < 2)) {
            distance += 24.0;
        }
        if ((distance -= (double)(tmpMonster.dangerLevel * 8)) < 0.0) {
            distance = 0.0;
        }
        if (this.weaponAmmoType == -1 && distance > 32.0 || this.weaponAmmoType != -1 && distance > 96.0) {
            return false;
        }
        if (distance < (double)this.nearBy && cmy <= this.nearMonsterY || distance - (double)(tmpMonster.dangerLevel * 2) < (double)this.nearBy && tmpMonster.dangerLevel > this.nearByDangerLevel) {
            this.nearByYAbs = my << 4;
            this.nearByXAbs = mx << 4;
            this.nearMonsterX = tmpMonster.x + (tmpMonster.w >> 1);
            this.nearMonsterY = tmpMonster.y + (tmpMonster.h >> 1);
            this.nearByDangerLevel = tmpMonster.dangerLevel;
            this.nearByDirection = tmpMonster.myDirection;
            this.nearBy = (int)distance;
            this.nearMonsterID = tmpMonster.getUID();
            this.nearByAlerted = tmpMonster.aiState == 4 || tmpMonster.aiState == 2;
            this.beAlert = true;
            this.lastNear = this.nearBy;
        }
        return distance < (double)distanceTrigger;
    }

    public final void setOnElevator(EntitySprite source, World myWorld) {
        if (this.died) {
            return;
        }
        this.y = source.y - this.h;
        this.floatY = this.y << 4;
        this.ySpeed = 0;
        if (this.myElevator == source && this.xSpeed == 0) {
            this.x = source.x + source.xSpeedAdd;
            this.floatX = this.x << 4;
        } else {
            this.myElevator = source;
            source.xSpeedAdd = this.x - source.x;
        }
        if (this.xSpeed != 0) {
            this.myElevator = null;
        }
        this.onGround = true;
    }

    public final boolean canHandleMe(EntitySprite source, int mImportance) {
        if (this.myOwnerEntity != null && this.myOwnerEntity != source || this.inOperating && this.myOwnerEntity != source) {
            return false;
        }
        if (this.firstHandleID >= 0 && this.firstHandleID != source.getUID() && mImportance < this.firstHandleImportance) {
            return false;
        }
        if (mImportance > this.firstHandleImportance || this.firstHandleImportance < 0 || this.firstHandleID == source.getUID()) {
            this.firstHandleID = source.getUID();
            this.firstHandleImportance = mImportance;
            return true;
        }
        return false;
    }

    public final boolean handleMe(EntitySprite source, boolean IfNoOtherHandles, boolean skipActionLockCheck, int mImportance) {
        if (this.lives < 0 || this.myOwnerEntity != null && this.myOwnerEntity != source || this.inOperating && this.myOwnerEntity != source) {
            return false;
        }
        if (IfNoOtherHandles && this.firstHandleImportance >= 0 && this.firstHandleID != source.getUID()) {
            return false;
        }
        if (mImportance > this.firstHandleImportance || this.firstHandleImportance < 0 || this.firstHandleID == source.getUID()) {
            this.firstHandleID = source.getUID();
            this.firstHandleImportance = mImportance;
        }
        if (this.lastRenderHandleCount == source.getUID() && this.altActionPressed && (skipActionLockCheck || !this.altActionLocked)) {
            this.firstHandleID = this.lastRenderHandleCount;
            this.altActionLocked = true;
            this.hasAltAction = 4;
            return true;
        }
        return false;
    }

    public final void setControllingEntity(EntitySprite source) {
        this.myOwnerEntity = source;
        source.myOwnerEntity = this;
        this.aiState = 7;
        this.myHead.rotate = 0;
    }

    public final void removeControllingEntity() {
        if (this.myOwnerEntity != null) {
            this.myOwnerEntity.myOwnerEntity = null;
        }
        this.myOwnerEntity = null;
        this.aiState = 0;
    }

    public final void exitLevel() {
        this.aiState = 3;
    }

    @Override
    public final void die() {
        if (Trainer.godMode) {
            this.lives = Math.max(this.lives, this.maxLives);
            this.died = false;
            this.visible = true;
            return;
        }
        if (this.died) {
            return;
        }
        this.died = true;
        this.myHead.rotate = this.rotate;
        this.visible = false;
        this.initUppercut();
        World.securityAlarmLevel = 0;
        World.isSecurityAlarm = false;
        Audio.playSoundPitched(Audio.FX_GORESPLAT);
        for (int i = 0; i < 1 + this.getMyRandomValue(3); ++i) {
            MonsterEntityList.add(9, this.x + this.getMyRandomValue(this.w), this.y + this.getMyRandomValue(2), 0, this);
        }
    }

    public final void initUppercut() {
        if (this.myDirection == 3) {
            this.xSpeed = -48;
        } else if (this.myDirection == 1) {
            this.xSpeed = 48;
        }
        if (this.lastCollidedWith != null) {
            if (this.lastCollidedWith.myDirection == 3) {
                this.xSpeed = -48;
            } else if (this.lastCollidedWith.myDirection == 1) {
                this.xSpeed = 48;
            }
        }
        this.rotate = this.xSpeed < 0 ? (this.myDirection == 3 ? 90 : -90) : (this.myDirection == 1 ? 90 : -90);
        this.ySpeed = -48;
        this.ySpeedAdd = -24;
        this.xSpeedAdd = this.xSpeed;
        this.aiState = 900;
    }

    public final void giveWeapon(int newWeaponID, int ammoLeft) {
        int m;
        if (newWeaponID == this.weaponSlots[0] || newWeaponID == this.weaponSlots[1] || this.shotCount > 0) {
            return;
        }
        World.lastPickupItemDelay = 196;
        World.lastPickupItem = newWeaponID + 500;
        if (Globals.weapons[newWeaponID][13] == -1) {
            if (this.weaponSlots[0] == 18) {
                return;
            }
            MonsterEntityList.add(13, this.x, this.y - 16, this.weaponSlots[0], this);
            this.weaponSlots[0] = newWeaponID;
            this.setActiveWeapon(0, true);
            return;
        }
        if (this.weaponSlots[1] >= 0 && newWeaponID != 10 && this.weaponSlots[1] != this.myBaseWeapon && Globals.weapons[this.weaponSlots[1]][14] > 1 && (m = MonsterEntityList.add(13, this.x, this.y - 16, this.weaponSlots[1], this)) >= 0) {
            MonsterEntityList.myList[m].ySpeed = -48;
            MonsterEntityList.myList[m].energy = this.ammoTypes[Globals.weapons[newWeaponID][13]];
            MonsterEntityList.myList[m].xSpeed = this.myDirection == 1 ? -32 : 32;
        }
        this.weaponSlots[1] = newWeaponID;
        if (Globals.weapons[newWeaponID][13] >= 0) {
            int setAmmo = Globals.weapons[this.weaponSlots[1]][14];
            if (ammoLeft > 0) {
                setAmmo = ammoLeft;
            }
            if (Globals.weapons[this.weaponSlots[1]][14] >= 0 && this.ammoTypes[Globals.weapons[newWeaponID][13]] < setAmmo) {
                this.ammoTypes[Globals.weapons[newWeaponID][13]] = this.hasWeaponExpert && Globals.weapons[newWeaponID][13] != 0 ? setAmmo << 1 : setAmmo;
            }
        } else {
            this.myWeaponStrength = Globals.weapons[this.myWeaponID][14];
        }
        this.setActiveWeapon(1, true);
    }

    public final void throwWeapon(boolean dumpEmpty) {
        int m;
        Audio.playSoundPitched(Audio.FX_WHOOSH);
        if (this.weaponSlots[1] != this.myBaseWeapon && this.weaponSlots[1] != 6 && Globals.weapons[this.weaponSlots[1]][14] > 1 && (m = MonsterEntityList.add(13, this.x, this.y - 16, this.weaponSlots[1], this)) >= 0) {
            MonsterEntityList.myList[m].ySpeed = -48;
            MonsterEntityList.myList[m].energy = this.ammoTypes[Globals.weapons[this.weaponSlots[1]][13]];
            MonsterEntityList.myList[m].xSpeed = this.myDirection == 1 ? -32 : 32;
            if (dumpEmpty) {
                MonsterEntityList.myList[m].aiState = 903;
                MonsterEntityList.myList[m].aiCountdown = 64;
            }
        }
        this.weaponSlots[1] = this.myBaseWeapon;
    }

    public final void setActiveWeapon(int slot, boolean playMountSound) {
        if (this.holdingInventoryItem >= 0 && this.holdingInventoryItem != 19 && this.holdingInventoryItem != 20) {
            if (Globals.pickups[this.holdingInventoryItem][8] == 1) {
                MonsterEntityList.add(12, this.x, this.y, this.holdingInventoryItem, this);
                this.holdingInventoryItem = -1;
            } else if (!this.inventorySpaceFor(this.holdingInventoryItem)) {
                MonsterEntityList.add(12, this.x, this.y, this.holdingInventoryItem, this);
            } else {
                this.increaseInventoryCount(this.holdingInventoryItem, 1);
            }
        }
        this.holdingInventoryItem = -1;
        if (this.weaponSlots[slot] < 0) {
            return;
        }
        if (slot > 0 && this.ammoTypes[Globals.weapons[this.weaponSlots[slot]][13]] <= 0 && this.weaponSlots[slot] != this.myBaseWeapon) {
            this.throwWeapon(true);
            if (slot == 1) {
                return;
            }
            slot = 1;
            playMountSound = false;
        }
        this.weaponSlotID = slot;
        if (playMountSound) {
            Audio.playSoundPitched(Audio.FX_GUNMOUNT);
        }
        this.myWeaponID = this.weaponSlots[slot];
        this.swapWeaponNotification = 64;
        this.prepWeaponSprite();
    }

    public final void setCharacterStats() {
        this.hasDoubleJump = false;
        this.hasSilentShoes = false;
        this.hasScavenger = 0;
        if (myCanvas.mySaveGame.characterSkillTree[this.myType][9]) {
            this.hasScavenger = 32;
        }
        this.hasEagleVision = myCanvas.mySaveGame.characterSkillTree[this.myType][7];
        this.hasEliteSkills = myCanvas.mySaveGame.characterSkillTree[this.myType][10];
        this.hasMasterWeapon = myCanvas.mySaveGame.characterSkillTree[this.myType][11];
        this.hasAmmoDoubler = myCanvas.mySaveGame.characterSkillTree[this.myType][13];
        this.hasWeaponExpert = myCanvas.mySaveGame.characterSkillTree[this.myType][6];
        this.hasStealthSkills = 12;
        if (GameInput.isTouchscreen) {
            this.hasStealthSkills += 16;
        }
        if (myCanvas.mySaveGame.characterSkillTree[this.myType][8]) {
            this.hasStealthSkills += 40;
        }
        this.runningSpeedMax = myCharacterSpecs[6];
        this.jumpingSpeedMax = myCharacterSpecs[7];
        this.maxInventorySize = myCharacterSpecs[15];
        this.maxReapedSouls = 80;
        if (this.ammoTypes[0] > this.ammoTypesMax[0]) {
            this.ammoTypes[0] = this.ammoTypesMax[0];
        }
        if (this.hasInventoryItem(9)) {
            this.runningSpeedMax += 12;
        }
        if (this.hasInventoryItem(10)) {
            this.hasDoubleJump = true;
        }
        if (this.hasInventoryItem(11)) {
            this.hasSilentShoes = true;
        }
        this.runningSpeedMax = (int)((float)this.runningSpeedMax / 100.0f * this.weaponSlowDown);
        this.jumpingSpeedMax = (int)((float)this.jumpingSpeedMax / 100.0f * this.weaponSlowDown);
        this.myWeaponStrength = Globals.weapons[this.weaponSlots[0]][14];
        this.myWeaponStrength += myCharacterSpecs[10];
        this.myWeaponReach = Globals.weapons[this.myWeaponID][18];
        this.myWeaponReach += myCharacterSpecs[9];
        if (this.helmetType == 4) {
            this.myWeaponStrength += this.myWeaponStrength;
            this.myWeaponReach += myCharacterSpecs[9];
        }
        if (this.helmetType >= 0) {
            this.myHead.xOffset = 0 + Globals.pickups[this.helmetType][7] * 12;
        }
        if (this.shieldType >= 0 && this.shield > 0) {
            this.myShield = new Sprite();
            this.myShield.clone(this);
            this.myShield.xOffset = Globals.pickups[this.shieldType][0];
            this.myShield.yOffset = Globals.pickups[this.shieldType][1];
            this.myShield.w = Globals.pickups[this.shieldType][2];
            this.myShield.h = Globals.pickups[this.shieldType][3];
            this.myShield.rotate = 0;
        }
    }

    public final void prepWeaponSprite() {
        int weaponID = this.myWeaponID;
        this.myWeapon.xOffset = Globals.weapons[weaponID][5];
        this.myWeapon.yOffset = Globals.weapons[weaponID][6];
        this.myWeapon.w = Globals.weapons[weaponID][7];
        this.myWeapon.h = Globals.weapons[weaponID][8];
        this.myWeapon.pivotX = 0;
        this.myWeapon.pivotY = this.myWeapon.h >> 1;
        this.weaponOffsetX = Globals.weapons[weaponID][9];
        this.weaponOffsetY = Globals.weapons[weaponID][10];
        this.weaponRotateIdle = Globals.weapons[weaponID][11];
        this.weaponRotateAttack = Globals.weapons[weaponID][12];
        this.weaponWarmUpCountdown = Globals.weapons[weaponID][0];
        this.weaponAmmoType = Globals.weapons[weaponID][13];
        this.weaponSlowDown = 100.0f - (float)Globals.weapons[weaponID][17];
        this.setCharacterStats();
        this.myAltWeapon.xOffset = Globals.weapons[this.weaponSlots[1 - this.weaponSlotID]][5];
        this.myAltWeapon.yOffset = Globals.weapons[this.weaponSlots[1 - this.weaponSlotID]][6];
        this.myAltWeapon.w = Globals.weapons[this.weaponSlots[1 - this.weaponSlotID]][7];
        this.myAltWeapon.h = Globals.weapons[this.weaponSlots[1 - this.weaponSlotID]][8];
        this.myAltWeapon.pivotY = this.myAltWeapon.h >> 1;
        this.myBackpack = null;
        if (weaponID == 9) {
            this.myBackpack = new Sprite();
            this.myBackpack.xOffset = 39;
            this.myBackpack.yOffset = 265;
            this.myBackpack.w = 9;
            this.myBackpack.h = 11;
            this.myBackpack.renderPass = 1;
        }
        this.shotCount = 0;
        this.fireDelay = 0;
        this.reloadDelay = 0;
    }

    public final void prepItemSprite() {
        this.myItem.xOffset = Globals.pickups[this.holdingInventoryItem][0];
        this.myItem.yOffset = Globals.pickups[this.holdingInventoryItem][1];
        this.myItem.w = Globals.pickups[this.holdingInventoryItem][2];
        this.myItem.h = Globals.pickups[this.holdingInventoryItem][3];
    }

    public final void setBodyType(int myType) {
        this.hasDisguise = false;
        this.baseYOffset = this.yOffset = 288 + Globals.bodyType[myType] * this.h;
        if (myType == 7) {
            this.hasDisguise = true;
        }
    }

    public final void addHealth(int hpAmount) {
        if (this.lives > this.maxLives) {
            return;
        }
        this.lives += hpAmount;
        if (this.lives > this.maxLives + this.extendedLives) {
            this.lives = this.maxLives + this.extendedLives;
        }
    }

    public final void inChopper(EntitySprite source) {
        this.myOwnerEntity = source;
        this.aiState = 5;
        this.invincableCount = 4;
    }

    public final boolean giveItem(int itemType) {
        myCanvas.mySaveGame.increaseStat(3, 1);
        if (itemType >= 500) {
            this.giveWeapon(itemType - 500, -1);
            return true;
        }
        switch (Globals.pickups[itemType][8]) {
            case 3: 
            case 4: 
            case 5: {
                int oldIdx = this.hasActiveItemByType(Globals.pickups[itemType][8]);
                if (oldIdx >= 0) {
                    int m;
                    if (this.inventory[oldIdx].itemIDX != itemType && itemType != 19 && (m = MonsterEntityList.add(12, this.x, this.y - 16, this.inventory[oldIdx].itemIDX, this)) >= 0) {
                        MonsterEntityList.myList[m].ySpeed = -48;
                        MonsterEntityList.myList[m].xSpeed = this.myDirection == 1 ? -32 : 32;
                    }
                    this.deleteInventoryItem(this.inventory[oldIdx].itemIDX);
                }
                switch (Globals.pickups[itemType][8]) {
                    case 5: {
                        this.helmetType = itemType;
                        this.helmet = this.maxHelmet = Globals.pickups[itemType][6];
                        this.myHead.xOffset = 0 + Globals.pickups[this.helmetType][7] * 12;
                        break;
                    }
                    case 3: {
                        this.maxShield = Globals.pickups[itemType][6];
                        this.shieldType = itemType;
                        this.shield = this.maxShield;
                        this.myShield = new Sprite();
                        this.myShield.clone(this);
                        this.myShield.xOffset = Globals.pickups[this.shieldType][0];
                        this.myShield.yOffset = Globals.pickups[this.shieldType][1];
                        this.myShield.w = Globals.pickups[this.shieldType][2];
                        this.myShield.h = Globals.pickups[this.shieldType][3];
                        this.myShield.rotate = 0;
                        break;
                    }
                    case 4: {
                        this.shoeType = itemType;
                    }
                }
                this.increaseInventoryCount(itemType, 1);
                break;
            }
            case 0: {
                if (!this.inventorySpaceFor(itemType)) {
                    World.setPlayerTalk(0);
                    return false;
                }
                this.increaseInventoryCount(itemType, 1);
                break;
            }
            case 1: {
                if (this.holdingInventoryItem >= 0 && this.holdingInventoryItem != 19) {
                    if (Globals.pickups[this.holdingInventoryItem][8] == 1) {
                        MonsterEntityList.add(12, this.x, this.y, this.holdingInventoryItem, this);
                        this.holdingInventoryItem = -1;
                    } else {
                        if (!this.inventorySpaceFor(itemType)) {
                            World.setPlayerTalk(0);
                            return false;
                        }
                        this.increaseInventoryCount(this.holdingInventoryItem, 1);
                        this.holdingInventoryItem = -1;
                    }
                }
                this.holdingInventoryItem = itemType;
                this.prepItemSprite();
                break;
            }
            case 2: {
                switch (itemType) {
                    case 21: {
                        if (this.backPackItems != null && this.backPackItems.length > 0) {
                            for (int bb = 0; bb < this.backPackItems.length; ++bb) {
                                if (this.backPackItems[bb] == null || this.backPackItems[bb].itemIDX <= 0) continue;
                                this.giveItem(this.backPackItems[bb].itemIDX);
                            }
                            World.setPlayerTalk(2);
                            break;
                        }
                        World.setPlayerTalk(1);
                        break;
                    }
                    case 24: {
                        myCanvas.mySaveGame.charXPPoints[this.myType] = ++this.skillPoints;
                        uiskills.init();
                        break;
                    }
                    case 26: {
                        this.setBodyType(7);
                        World.setPlayerTalk(10);
                        break;
                    }
                    case 28: {
                        World.addCoin(20);
                        break;
                    }
                    case 27: {
                        if (this.hasAmmoDoubler) {
                            this.ammoTypes[0] = this.ammoTypes[0] + (5 + myCanvas.mySaveGame.difficulty * 2) * 2;
                            break;
                        }
                        this.ammoTypes[0] = this.ammoTypes[0] + (5 + myCanvas.mySaveGame.difficulty * 2);
                        break;
                    }
                    case 30: {
                        this.increaseInventoryCount(29, 5);
                        break;
                    }
                    case 31: {
                        this.increaseInventoryCount(29, 10);
                        break;
                    }
                    case 32: {
                        this.increaseInventoryCount(29, 20);
                        break;
                    }
                    case 34: {
                        this.increaseInventoryCount(33, 5);
                        break;
                    }
                    case 35: {
                        this.increaseInventoryCount(33, 10);
                        break;
                    }
                    case 36: {
                        this.increaseInventoryCount(33, 20);
                    }
                }
                break;
            }
            case 6: {
                this.increaseInventoryCount(itemType, 1);
                if (itemType == 13) {
                    this.reapedSouls = 0;
                }
                if (itemType == 12) {
                    this.doVoodooMask();
                }
                if (itemType < 39 || itemType > 42) break;
                myCanvas.unlockAchievement(12);
            }
        }
        if (itemType == 25) {
            World.forceNextStore = 15;
        } else if (itemType == 23) {
            World.forceNextStore = 1;
        } else if (itemType == 22 && !this.hasInventoryItem(13)) {
            World.forceNextStore = 10;
        }
        this.setCharacterStats();
        World.lastPickupItemDelay = 196;
        World.lastPickupItem = itemType;
        World.triggerMissionComplete(4, 1, itemType);
        return true;
    }

    public final void renderTarget(Texture mySprite) {
        if ((Globals.weapons[this.myWeaponID][4] == 1 || this.twinStick || this.mouseAim) && this.nearBy != 65535) {
            int tx = this.nearMonsterX - 3 - World.offsetX;
            int ty = this.nearMonsterY - 3 - World.offsetY;
            Render.dest.set(tx, ty, tx + 7, ty + 7);
            Render.src.set(131, 100, 138, 107);
            Render.drawBitmap(mySprite, false);
        }
        this.nearMonsterX = -1;
        this.nearMonsterY = -1;
        this.nearBy = 65535;
        this.nearByDangerLevel = -1;
    }

    public final void initOutVentCrawl(int newX, int newY) {
        if (this.holdingInventoryItem == 20 || this.holdingInventoryItem == 19) {
            this.holdingInventoryItem = -1;
        }
        this.aiState = 6;
        this.aiCountdown = World.inVents ? 48 : 72;
        this.targetX = newX;
        this.targetY = newY;
        if (World.isSolid((newX >> 4) + 1, newY >> 4, true)) {
            this.targetX -= 4;
        }
        if (World.isSolid((newX >> 4) - 1, newY >> 4, true)) {
            this.targetX += 4;
        }
    }

    public int getInventoryItemFlash(int idx) {
        return this.inventory[idx].flashInStatusbar;
    }

    public final void decreaseInventoryItemFlash() {
        int i = this.inventory.length;
        while (--i >= 0) {
            this.inventory[i].flashInStatusbar -= 4;
            if (this.inventory[i].flashInStatusbar >= 0) continue;
            this.inventory[i].flashInStatusbar = 0;
        }
    }

    public int getInventoryItemIDX(int itemIDX) {
        for (int i = 0; i < this.inventory.length; ++i) {
            if (this.inventory[i].itemIDX != itemIDX) continue;
            return i;
        }
        return -1;
    }

    public void deleteInventoryItem(int itemIDX) {
        int del = this.getInventoryItemIDX(itemIDX);
        if (del < 0) {
            return;
        }
        if (Trainer.unlimitedMoneyItems) {
            if (this.inventory[del].itemUsageCount < 9) {
                this.inventory[del].itemUsageCount = 9;
            }
            return;
        }
        if (this.inventory[del].itemUsageCount > 1) {
            --this.inventory[del].itemUsageCount;
            return;
        }
        for (int i = del; i < this.inventory.length - 1; ++i) {
            this.inventory[i].clone(this.inventory[i + 1]);
        }
        this.inventory[this.inventory.length - 1].itemIDX = -1;
        this.inventory[this.inventory.length - 1].itemUsageCount = -1;
        this.inventory[this.inventory.length - 1].itemType = -1;
        this.inventory[this.inventory.length - 1].flashInStatusbar = 0;
    }

    public boolean hasInventoryItem(int itemIDX) {
        if (this.activeItem.itemIDX == itemIDX) {
            return true;
        }
        return this.getInventoryItemIDX(itemIDX) >= 0;
    }

    public boolean isHoldingItem(int itemIDX) {
        return this.holdingInventoryItem == itemIDX;
    }

    public void useInventoryItem(int itemIDX) {
        if (this.activeItem.itemIDX == itemIDX) {
            if (!Trainer.unlimitedMoneyItems) {
                this.activeItem.itemIDX = -1;
            }
            return;
        }
        int inv = this.getInventoryItemIDX(itemIDX);
        if (inv >= 0) {
            if (Trainer.unlimitedMoneyItems) {
                if (this.inventory[inv].itemUsageCount < 9) {
                    this.inventory[inv].itemUsageCount = 9;
                }
                return;
            }
            --this.inventory[inv].itemUsageCount;
            if (this.inventory[inv].itemUsageCount <= 0) {
                this.deleteInventoryItem(itemIDX);
            }
        }
    }

    public int hasActiveItemByType(int itemType) {
        for (int i = 0; i < this.inventory.length; ++i) {
            if (this.inventory[i].itemType != itemType) continue;
            return i;
        }
        return -1;
    }

    public int getInventoryItemUsageCount(int itemIDX) {
        int inv = this.getInventoryItemIDX(itemIDX);
        if (inv >= 0) {
            return this.inventory[inv].itemUsageCount;
        }
        return 0;
    }

    public void addInventoryItem(int itemType, int count) {
        int i;
        for (i = 0; this.inventory[i].itemIDX >= 0 && i < this.inventory.length; ++i) {
        }
        if (i < this.inventory.length) {
            this.inventory[i].itemIDX = itemType;
            this.inventory[i].itemUsageCount = count;
            this.inventory[i].itemType = Globals.pickups[itemType][8];
        }
    }

    public boolean inventorySpaceFor(int item) {
        if (this.getInventoryItemIDX(item) >= 0) {
            return true;
        }
        int i = 0;
        int bagItemCount = 0;
        while (this.inventory[i].itemIDX >= 0 && bagItemCount < this.maxInventorySize) {
            if (this.inventory[i].itemType == 0 || this.inventory[i].itemType == 1) {
                ++bagItemCount;
            }
            ++i;
        }
        return bagItemCount < this.maxInventorySize;
    }

    public void increaseInventoryCount(int itemType, int count) {
        int inv = this.getInventoryItemIDX(itemType);
        if (inv < 0) {
            this.addInventoryItem(itemType, count);
        } else {
            this.inventory[inv].itemUsageCount += count;
        }
    }

    public final void resetInventory() {
        for (int i = 0; i < this.inventory.length; ++i) {
            this.inventory[i] = new InventoryItem();
            this.inventory[i].itemIDX = -1;
            this.inventory[i].itemUsageCount = 0;
            this.inventory[i].itemType = 0;
            this.inventory[i].flashInStatusbar = 0;
        }
    }

    public void increaseXP(int amount, boolean extraStealthPoints, EntitySprite source) {
        if (extraStealthPoints) {
            World.addPickupMessage(10, amount, source);
        } else if (amount > 1) {
            World.addPickupMessage(9, amount, source);
        } else {
            World.addPickupMessage(9, amount, source);
        }
        this.currentXP += amount;
        if (this.currentXP >= this.targetXP) {
            this.currentXP = this.targetXP;
            ++this.levelXP;
            this.targetXP += this.targetXP + (this.targetXP >> 1);
            myCanvas.mySaveGame.charXPPoints[this.myType] = ++this.skillPoints;
        }
    }

    private void calculateTargetXP() {
        this.targetXP = 400;
        while (this.targetXP < this.currentXP) {
            this.targetXP += this.targetXP + (this.targetXP >> 1);
        }
    }

    @Override
    public void hitMe(EntitySprite target) {
        if (Trainer.godMode) {
            this.lives = Math.max(this.lives, this.maxLives);
            this.invincableCount = 8;
            return;
        }
        this.hitCountdown = 3;
        this.livesHitCountdown = 16;
        this.invincableCount = 8;
        if (this.holdingInventoryItem == 19 && target != null && (target.xSpeed < 0 && this.myDirection == 3 || target.xSpeed > 0 && this.myDirection == 1)) {
            for (int i = 0; i < 3; ++i) {
                FXEntityList.add(8, this.x, this.y, 0, this);
                FXEntityList.add(8, this.x, this.y, 0, this);
                FXEntityList.add(8, this.x, this.y, 0, this);
            }
            return;
        }
        if (this.holdingInventoryItem == 20) {
            this.holdingInventoryItem = -1;
            World.setAnnouncement(9, 128, null);
        } else if (this.shield > 0) {
            --this.shield;
            Audio.playSound(Audio.FX_RICOCHET);
            if (this.shield <= 0) {
                this.deleteInventoryItem(this.getInventoryItemIDX(this.shieldType));
                this.shieldType = -1;
                this.myShield = null;
                this.setHead(this.myHead, this.myType - 1);
            }
        } else if (this.helmetType == 2 && this.helmet > 0) {
            --this.helmet;
            Audio.playSound(Audio.FX_RICOCHET);
            if (this.helmet <= 0) {
                this.deleteInventoryItem(this.helmetType);
                this.helmetType = -1;
                this.setHead(this.myHead, this.myType - 1);
            }
        } else {
            --this.lives;
        }
        if (this.lives > 0 && this.lastCollidedWith != null && (this.lastCollidedWith.myType == 16 || this.lastCollidedWith.myType == 1)) {
            this.initUppercut();
        }
        if (this.lives <= this.maxLives) {
            this.extendedLives = 0;
        }
        FXEntityList.add(1, this.x + this.getMyRandomValue(this.w), this.y + this.getMyRandomValue(this.h), 0, this);
        for (int i = 0; i < 3; ++i) {
            FXEntityList.add(8, this.x, this.y, 0, this);
            FXEntityList.add(8, this.x, this.y, 0, this);
            FXEntityList.add(8, this.x, this.y, 0, this);
        }
    }

    public final void setRenderpass(int newPass) {
        this.renderPass = newPass;
        if (this.myWeapon != null) {
            this.myWeapon.renderPass = this.renderPass;
        }
        if (this.myAltWeapon != null) {
            this.myAltWeapon.renderPass = this.renderPass;
        }
        if (this.myBackpack != null) {
            this.myBackpack.renderPass = this.renderPass;
        }
        if (this.myHead != null) {
            this.myHead.renderPass = this.renderPass;
        }
        if (this.myShield != null) {
            this.myShield.renderPass = this.renderPass;
        }
    }

    public final void doHide() {
        if (this.holdingInventoryItem == 19) {
            this.holdingInventoryItem = -999;
            this.increaseXP(10, true, this);
        }
    }

    public final void addSoul() {
        int i = this.getInventoryItemIDX(13);
        if (i < 0) {
            return;
        }
        this.inventory[i].flashInStatusbar = 255;
        ++this.reapedSouls;
        if (this.reapedSouls >= this.maxReapedSouls) {
            this.reapedSouls = 0;
            ++this.maxLives;
            World.setPlayerTalk(7);
        }
    }

    public final void dropImportantStuff() {
        if (this.weaponSlots[0] == 18) {
            MonsterEntityList.add(13, this.x, this.y, 18, this);
            this.weaponSlots[0] = 10;
        }
        if (this.holdingInventoryItem == 20) {
            int m = MonsterEntityList.add(46, this.x - 8, this.y, 26, this);
            MonsterEntityList.myList[m].aiState = 0;
            this.holdingInventoryItem = -1;
        }
    }

    public final void storeCharacter() {
        myCanvas.mySaveGame.charXP[this.myType] = this.currentXP;
        myCanvas.mySaveGame.charXPLevel[this.myType] = this.levelXP;
        myCanvas.mySaveGame.shoeType[this.myType] = this.shoeType;
        myCanvas.mySaveGame.helmetType[this.myType] = this.helmetType;
        myCanvas.mySaveGame.shieldType[this.myType] = this.shieldType;
        myCanvas.mySaveGame.shield[this.myType] = this.shield;
        myCanvas.mySaveGame.maxShield[this.myType] = this.maxShield;
        myCanvas.mySaveGame.helmet[this.myType] = this.helmet;
        myCanvas.mySaveGame.maxHelmet[this.myType] = this.maxHelmet;
        myCanvas.mySaveGame.charLives[this.myType] = this.lives;
        myCanvas.mySaveGame.charMaxLives[this.myType] = this.maxLives;
        myCanvas.mySaveGame.meleeWeaponID[this.myType] = this.weaponSlots[0];
        myCanvas.mySaveGame.attackWeaponID[this.myType] = this.weaponSlots[1];
        myCanvas.mySaveGame.charBullets[this.myType][0] = this.ammoTypes[0];
        myCanvas.mySaveGame.charBullets[this.myType][1] = this.ammoTypes[1];
        myCanvas.mySaveGame.charBullets[this.myType][2] = this.ammoTypes[2];
    }

    public final void doVoodooMask() {
        boolean voodooDone = false;
        for (int i = 1; i < myCanvas.mySaveGame.charUnlocked.length; ++i) {
            if (voodooDone || !myCanvas.mySaveGame.charUnlocked[i] || !myCanvas.mySaveGame.charDied[i]) continue;
            myCanvas.mySaveGame.charDied[i] = false;
            this.useInventoryItem(12);
            voodooDone = true;
            Audio.playSoundPitched(Audio.FX_UI_POPUP);
            myCanvas.initUnlockUsage(12);
            int m = MonsterEntityList.add(24, this.x, this.y, 6, null);
            if (m < 0) continue;
            MonsterEntityList.myList[m].setHead(MonsterEntityList.myList[m].extraSprites[0], i - 1);
            MonsterEntityList.myList[m].subType = 9;
            MonsterEntityList.myList[m].aiState = 6;
            MonsterEntityList.myList[m].aiCountdown = 64;
            World.itemTextSlowtickerLength = 0;
            World.setAnnouncement(10, 128, null);
        }
    }

    static {
        animationHeadYoffset = new int[]{0, 1, 2, 1, 1, 0, -1};
        verticalOffsetPerFrame = new int[]{0, -1, 0, -1, 0, 0, 0};
    }
}

