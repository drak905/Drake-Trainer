// 9 Years of Shadows - Offline Trainer (BepInEx 5 + Harmony, Unity 2022.3.28 Mono x64)
// Single-player / offline use only. No anti-cheat, DRM or online service is touched.
//
// Evidence (decompiled Assembly-CSharp.dll, see nys-src/ and artifacts/nys/subtasks/ev_*.json):
//   COMBAT    PlayerController.invincible (getter) is the single i-frame gate checked by EVERY damage source
//             (EnemySlash, ContactHazard, HitboxAlternate, PooledEnemyAttack, HurtableObject contact, ...).
//             PlayerHealth.Hurt(float) / CheckDie() are the HP sink / death test.
//   ECONOMY   CurrencyInventory.AddCurrency / SubtractCurrency(type,int) / GetCurrency; saved as "Money" by SessionManager.
//   MOVEMENT  Move_Block.MoveForce(float xmultispeed) multiplies WalkSpeed * ... * xmultispeed into rb velocity.
//   JUMP      JumpV2_Block.SpawnJumpFX() runs at the end of every successful jump; the game itself re-arms an air jump
//             with FXSpawned=1; JUMPnumber=1; alreadydoublejumped=false (EuropaHeatAbility / GroundBallSkill_Block).
//   DAMAGE    DamageTable.CalculateDamage = damage dealt BY Europa to anything hurtable (enemies, bosses, breakables).
//   MAGIC     PlayerHealth.ChangeMagic(float) / FillMagic() (Magic = the shield bar that absorbs hits before HP).
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using BepInEx;
using BepInEx.Configuration;
using HarmonyLib;
using UnityEngine;
using UnityEngine.InputSystem;
using _9YoS.Scripts.Europa.Neutral.Central;
using _9YoS.Scripts.Europa.Neutral.Health;
using _9YoS.Scripts.Europa.Neutral.Jump;
using _9YoS.Scripts.Gameplay.BaseObject;
using _9YoS.Scripts.Gameplay.Data;
using _9YoS.Scripts.BossFights;
using _9YoS.Scripts.EnemiesAI.Components;
using _9YoS.Scripts.BossFights.Bubble;
using _9YoS.Scripts.BossFights.Core;
using _9YoS.Scripts.BossFights.Shared;
using _9YoS.Scripts.Environment;
using _9YoS.Scripts.Gameplay.Environment.Breakables;
using _9YoS.Scripts.MidBoss.Assistants;
using _9YoS.Scripts.MidBoss.Core;
using _9YoS.Scripts.Gameplay.Environment.Blocker;
using _9YoS.Scripts.Gameplay.Environment.Gates;
using _9YoS.Scripts.Interactuable_Objects.Collectables;
using _9YoS.Scripts.Interactuable_Objects.Items.Currency;
using _9YoS.Scripts.Managers;
using _9YoS.Scripts.UI;
using _9YoS.Scripts.UI.Map;
using UnityEngine.UI;

namespace NysTrainer
{
    public static class State
    {
        public static bool GodMode;
        public static bool InfiniteMoney;
        public static bool UnlimitedJump;
        public static bool SpeedBoost;
        public static bool OneHitKill;
        public static bool InfiniteMagic;
        public static bool RevealMap;
        public static bool ShowItems;
        public static bool UnlimitedItems;
        public static bool GateGhost;
        public static bool OhkBosses;
        public static bool BlockerGhost;
        public static int ItemFill = 99;
        public static float SpeedMultiplier = 2f;
    }

    [BepInPlugin("com.research.nystrainer", "9 Years of Shadows Offline Trainer", "1.2.2")]
    public class NysTrainerPlugin : BaseUnityPlugin
    {
        internal static NysTrainerPlugin Instance;
        internal static Harmony HarmonyInst;
        internal static void Log(string s) { if (Instance != null) Instance.Logger.LogInfo(s); }

        ConfigEntry<Key> keyGod, keyAddMoney, keyInfMoney, keyJump, keySpeed, keyOneHit, keyMagic, keyHeal, keyHud, keyMap, keyItemsOnMap, keyUnlimItems, keyGates, keyBlockers, keyDiag, keyUnstick;
        ConfigEntry<int> cfgAddMoney, cfgItemFill;
        ConfigEntry<float> cfgSpeed;
        ConfigEntry<bool> cfgShowHud, cfgOhkBosses;

        bool showHud = true;
        string toast = "";
        float toastUntil;
        bool selfTest;
        bool selfTestRan;
        float playerSeenAt = -1f;
        float nextMagicTick;
        bool trace;          // TRAINER_TRACE=1: log player position / jump state every 50 ms (diagnostics only)
        float nextTrace;
        float nextGhostTick;
        int patchedMethodCount;
        readonly List<string> patchErrors = new List<string>();

        void Awake()
        {
            Instance = this;
            gameObject.hideFlags = HideFlags.HideAndDontSave;
            DontDestroyOnLoad(gameObject);

            keyGod = Config.Bind("Hotkeys", "GodMode", Key.F1, "Toggle God Mode (no damage, no knock-back, cannot die from hits)");
            keyAddMoney = Config.Bind("Hotkeys", "AddMoney", Key.F2, "Add coins (amount in [Values] AddMoneyAmount, capped by the game's coin cap)");
            keyInfMoney = Config.Bind("Hotkeys", "InfiniteMoney", Key.F3, "Toggle Infinite Money (coins are never spent; refilled to cap when switched on)");
            keyJump = Config.Bind("Hotkeys", "UnlimitedJump", Key.F4, "Toggle unlimited air jumps");
            keySpeed = Config.Bind("Hotkeys", "SpeedBoost", Key.F5, "Toggle movement speed multiplier");
            keyOneHit = Config.Bind("Hotkeys", "OneHitKill", Key.F6, "Toggle one-hit kill (every landed hit deals 99999)");
            keyMagic = Config.Bind("Hotkeys", "InfiniteMagic", Key.F7, "Toggle infinite magic / shield bar");
            keyHeal = Config.Bind("Hotkeys", "FullHeal", Key.F8, "Restore full health and magic once");
            keyHud = Config.Bind("Hotkeys", "ToggleHud", Key.F9, "Show/hide the trainer overlay");
            keyMap = Config.Bind("Hotkeys", "RevealMap", Key.F10, "Toggle: reveal every known room on the pause map (and auto-reveal each area when you enter it)");
            keyItemsOnMap = Config.Bind("Hotkeys", "ShowItemsOnMap", Key.F11, "Toggle: mark uncollected items (item crystals, armor pickups) on the pause map");
            keyUnlimItems = Config.Bind("Hotkeys", "UnlimitedItems", Key.F12, "Toggle unlimited items: no currency/material is ever spent; notes and armor/light pieces are topped up when switched on");
            keyGates = Config.Bind("Hotkeys", "WalkThroughGates", Key.Home, "Toggle: walk straight through closed gates (switch / enemy / arena gates). The gates themselves stay closed and your save is not changed");
            keyDiag = Config.Bind("Hotkeys", "SaveDiagnostics", Key.Insert, "Write NysTrainer_diag.txt (what is touching / blocking the character, nearby gates, door ramps) next to the game exe - for troubleshooting");
            keyUnstick = Config.Bind("Hotkeys", "Unstick", Key.Delete, "Emergency: give control back if a cutscene / boss outro left the character unable to act");
            cfgOhkBosses = Config.Bind("Values", "OneHitKillAffectsBosses", false, "If true, One-Hit Kill also hits bosses, mid-bosses and their parts. DANGEROUS: boss fights are scripted in phases and a one-shot kill can skip them and leave the game stuck");
            keyBlockers = Config.Bind("Hotkeys", "WalkThroughBlockers", Key.End, "Toggle: walk through destructible crystal walls and fake walls without breaking them");
            cfgItemFill = Config.Bind("Values", "ItemFillAmount", 99, "Amount blue/red notes, armor pieces and light pieces are topped up to when Unlimited Items is switched on (UI shows 2 digits)");
            cfgAddMoney = Config.Bind("Values", "AddMoneyAmount", 1000, "Coins added by the Add Money key");
            cfgSpeed = Config.Bind("Values", "SpeedMultiplier", 2f, "Walk/run speed multiplier while SpeedBoost is on");
            cfgShowHud = Config.Bind("UI", "ShowHud", true, "Show overlay at start");
            showHud = cfgShowHud.Value;
            State.SpeedMultiplier = Mathf.Clamp(cfgSpeed.Value, 0.1f, 10f);
            State.ItemFill = Mathf.Clamp(cfgItemFill.Value, 1, 9999);
            State.OhkBosses = cfgOhkBosses.Value;

            selfTest = Environment.GetEnvironmentVariable("TRAINER_SELFTEST") == "1";
            trace = Environment.GetEnvironmentVariable("TRAINER_TRACE") == "1";

            HarmonyInst = new Harmony("com.research.nystrainer");
            try
            {
                HarmonyInst.PatchAll(typeof(NysTrainerPlugin).Assembly);
            }
            catch (Exception e)
            {
                patchErrors.Add(e.ToString());
                Logger.LogError("PatchAll failed: " + e);
            }
            foreach (MethodBase m in HarmonyInst.GetPatchedMethods())
            {
                patchedMethodCount++;
                Logger.LogInfo("Patched: " + m.DeclaringType.Name + "." + m.Name);
            }
            try { int n = ReceiverTrack.PatchAll(HarmonyInst); Logger.LogInfo("Hit-receiver tracking installed on " + n + " ProcessHit methods"); }
            catch (Exception e) { patchErrors.Add(e.ToString()); Logger.LogError("ReceiverTrack failed: " + e); }
            if (trace)
            {
                try
                {
                    HarmonyInst.Patch(AccessTools.Method(typeof(JumpV2_Block), "InputtedAJump"), prefix: new HarmonyMethod(typeof(TraceHooks), "InputtedAJump"));
                    HarmonyInst.Patch(AccessTools.Method(typeof(JumpV2_Block), "CheckDoJump"), prefix: new HarmonyMethod(typeof(TraceHooks), "CheckDoJump"));
                }
                catch (Exception e) { Logger.LogWarning("trace hooks failed: " + e.Message); }
            }
            Logger.LogInfo("9YoS Offline Trainer ready. Patched methods: " + patchedMethodCount + (selfTest ? " [SELFTEST]" : ""));
            if (selfTest) WriteReport(false, "starting");
        }

        static bool Pressed(ConfigEntry<Key> k)
        {
            Keyboard kb = Keyboard.current;
            if (kb == null) return false;
            try { return kb[k.Value].wasPressedThisFrame; }
            catch { return false; }
        }

        static void TryAnimCache(PlayerController pc)
        {
            if (animFields != null) return;
            object ca = pc.europaanims != null ? (object)pc.europaanims.CommonAnimations : null;
            List<KeyValuePair<string, string>> l = new List<KeyValuePair<string, string>>();
            l.Add(new KeyValuePair<string, string>("jump", "jump"));
            if (ca != null)
                foreach (FieldInfo f in ca.GetType().GetFields(BindingFlags.Public | BindingFlags.Instance))
                    if (f.FieldType == typeof(string)) { string v = f.GetValue(ca) as string; if (!string.IsNullOrEmpty(v)) l.Add(new KeyValuePair<string, string>(f.Name, v)); }
            animFields = l;
        }
        static List<KeyValuePair<string, string>> animFields;
        static string AnimName(PlayerController pc)
        {
            try
            {
                TryAnimCache(pc);
                AnimatorStateInfo si = pc.animator.GetCurrentAnimatorStateInfo(0);
                foreach (KeyValuePair<string, string> kv in animFields) if (si.IsName(kv.Value)) return kv.Key;
                return "?" + si.shortNameHash;
            }
            catch { return "err"; }
        }

        static PlayerController PC
        {
            get
            {
                PlayerController p = PlayerController.Instance;
                if (p == null) return null;
                if (p.Europa == null || p.europaobjects == null) return null;
                return p;
            }
        }

        void Toast(string s)
        {
            toast = s;
            toastUntil = Time.unscaledTime + 2.5f;
            Logger.LogInfo(s);
        }

        static string OnOff(bool b) { return b ? "ON" : "OFF"; }

        void Update()
        {
            if (Pressed(keyHud)) { showHud = !showHud; }
            if (Pressed(keyGod)) { State.GodMode = !State.GodMode; Toast("God Mode " + OnOff(State.GodMode)); }
            if (Pressed(keyJump)) { State.UnlimitedJump = !State.UnlimitedJump; Toast("Unlimited Jump " + OnOff(State.UnlimitedJump)); }
            if (Pressed(keySpeed)) { State.SpeedBoost = !State.SpeedBoost; Toast("Speed x" + State.SpeedMultiplier.ToString("0.#") + " " + OnOff(State.SpeedBoost)); }
            if (Pressed(keyOneHit)) { State.OneHitKill = !State.OneHitKill; Toast("One-Hit Kill " + OnOff(State.OneHitKill) + (State.OhkBosses ? " (bosses too)" : " (regular enemies only; bosses are protected)")); }
            if (Pressed(keyMap)) { State.RevealMap = !State.RevealMap; Toast("Reveal Map " + OnOff(State.RevealMap) + (State.RevealMap ? " (open the map)" : "")); }
            if (Pressed(keyItemsOnMap)) { State.ShowItems = !State.ShowItems; Toast("Items on Map " + OnOff(State.ShowItems) + (State.ShowItems ? " (open the map)" : "")); }
            if (trace && Keyboard.current != null && Keyboard.current[Key.Insert].wasPressedThisFrame && PC != null) StartCoroutine(GateProbe());
            if (Pressed(keyDiag)) { Diag.Write(PC, Toast); }
            if (Pressed(keyUnstick)) { Toast(Unstick.Run()); }
            if (State.GateGhost && PC != null) { Move_Block mv = PC.europaobjects.mover; if (mv != null) { mv.allowedtomoveleft = true; mv.allowedtomoveright = true; } }
            if (Pressed(keyGates)) { if (trace && PC != null) GhostTools.Dump(PC); State.GateGhost = !State.GateGhost; if (!State.GateGhost) GhostTools.Release(true, false); Toast("Walk Through Gates " + OnOff(State.GateGhost)); }
            if (Pressed(keyBlockers)) { State.BlockerGhost = !State.BlockerGhost; if (!State.BlockerGhost) GhostTools.Release(false, true); Toast("Walk Through Blockers " + OnOff(State.BlockerGhost)); }
            if (Pressed(keyMagic)) { State.InfiniteMagic = !State.InfiniteMagic; Toast("Infinite Magic " + OnOff(State.InfiniteMagic)); }

            PlayerController pc = PC;
            if (pc == null) { playerSeenAt = -1f; return; }
            if (playerSeenAt < 0f) playerSeenAt = Time.unscaledTime;

            if (trace && Time.unscaledTime >= nextTrace)
            {
                nextTrace = Time.unscaledTime + 0.05f;
                try
                {
                    JumpV2_Block tj = pc.europaobjects.jump2;
                    Logger.LogInfo("TRACE t=" + Time.unscaledTime.ToString("0.00") + " y=" + pc.transform.position.y.ToString("0.000") + " x=" + pc.transform.position.x.ToString("0.000") +
                        " grounded=" + pc.isGrounded + " fx=" + tj.FXSpawned + " jn=" + tj.JUMPnumber + " dj=" + tj.alreadydoublejumped +
                        " god=" + State.GodMode + " jump=" + State.UnlimitedJump + " speed=" + State.SpeedBoost + " vx=" + pc.PlayerVelocity.x.ToString("0.00") +
                        " anim=" + AnimName(pc) + " jumping=" + pc.jumping + " canjump=" + pc.canjump + " free=" + pc.freetojump + " cij=" + tj.canJumpInAir + " coy=" + tj.coyote + " lj=" + tj.lastjumpframe);
                }
                catch { }
            }

            try
            {
                CurrencyInventory inv = pc.Europa.CurrencyInventory;
                if (Pressed(keyInfMoney))
                {
                    State.InfiniteMoney = !State.InfiniteMoney;
                    if (State.InfiniteMoney && inv != null) TopUpCoins(inv, pc);
                    Toast("Infinite Money " + OnOff(State.InfiniteMoney));
                }
                if (Pressed(keyUnlimItems))
                {
                    State.UnlimitedItems = !State.UnlimitedItems;
                    if (State.UnlimitedItems && inv != null) TopUpItems(inv, pc);
                    Toast("Unlimited Items " + OnOff(State.UnlimitedItems));
                }
                if (Pressed(keyAddMoney) && inv != null)
                {
                    int before = inv.GetCurrency(CurrencyInventory.CurrencyType.Coin);
                    inv.AddCurrency(CurrencyInventory.CurrencyType.Coin, cfgAddMoney.Value);
                    int after = inv.GetCurrency(CurrencyInventory.CurrencyType.Coin);
                    Toast("Coins +" + (after - before) + " (now " + after + ")");
                }
                PlayerHealth ph = pc.europaobjects.healthObject;
                if ((State.GateGhost || State.BlockerGhost) && Time.unscaledTime >= nextGhostTick)
                {
                    nextGhostTick = Time.unscaledTime + 0.25f;
                    GhostTools.Refresh(pc, State.GateGhost, State.BlockerGhost);
                }
                if (Pressed(keyHeal) && ph != null && !pc.dead)
                {
                    ph.FillHealth();
                    ph.FillMagic();
                    Toast("Health & magic restored");
                }
                if (State.UnlimitedJump && !pc.isGrounded)
                {
                    JumpV2_Block jb = pc.europaobjects.jump2;
                    if (jb != null) jb.alreadydoublejumped = false;
                }
                if (State.InfiniteMagic && ph != null && !pc.dead && ph.health > 0f && Time.unscaledTime >= nextMagicTick)
                {
                    nextMagicTick = Time.unscaledTime + 0.1f;
                    if (ph.Magic < (float)pc.Europa.MaxMagic) ph.FillMagic();
                }
            }
            catch (Exception e)
            {
                Logger.LogWarning("Update error: " + e.Message);
            }

            if (selfTest && !selfTestRan && Time.unscaledTime - playerSeenAt > 3f)
            {
                selfTestRan = true;
                try { RunSelfTest(pc); }
                catch (Exception e) { Logger.LogError("SelfTest exception: " + e); WriteReport(true, "exception: " + e.Message); }
            }
        }

        internal static void TopUpItems(CurrencyInventory inv, PlayerController pc)
        {
            int max = pc.Europa.BaseStats.MaxCurrency;
            int want = Math.Min(State.ItemFill, max);
            CurrencyInventory.CurrencyType[] t = new CurrencyInventory.CurrencyType[] { CurrencyInventory.CurrencyType.BlueNote, CurrencyInventory.CurrencyType.RedNote, CurrencyInventory.CurrencyType.ArmorPiece, CurrencyInventory.CurrencyType.LightPiece };
            foreach (CurrencyInventory.CurrencyType x in t)
            {
                int cur = inv.GetCurrency(x);
                if (cur < want) inv.AddCurrency(x, want - cur);
            }
        }

        static void TopUpCoins(CurrencyInventory inv, PlayerController pc)
        {
            int max = pc.Europa.BaseStats.MaxCurrency;
            int cur = inv.GetCurrency(CurrencyInventory.CurrencyType.Coin);
            if (max > cur) inv.AddCurrency(CurrencyInventory.CurrencyType.Coin, max - cur);
        }

        // TRAINER_TRACE=1 + Insert only: closes the nearest gate in memory, drops the player into its barrier with
        // walk-through OFF and ON and reports whether the physics engine pushes the player out. Everything is restored.
        System.Collections.IEnumerator GateProbe()
        {
            PlayerController pc = PC;
            GateController best = null; float bd = 1e9f;
            foreach (GateController g in UnityEngine.Object.FindObjectsOfType<GateController>())
            {
                if (!g.gameObject.activeInHierarchy) continue;
                float d = (g.transform.position - pc.transform.position).magnitude;
                if (d < bd) { bd = d; best = g; }
            }
            if (best == null) { Logger.LogInfo("PROBE no gate"); yield break; }
            bool wasOpen = best.isOpen;
            bool g0 = State.GateGhost;
            Vector3 home = pc.transform.position;
            Rigidbody2D rb = pc.GetComponent<Rigidbody2D>();
            Logger.LogInfo("PROBE gate=" + best.name + " track=" + best.TrackingInfo.id + " wasOpen=" + wasOpen + " dist=" + bd.ToString("0.0"));
            best.CloseGate(false);
            yield return new WaitForSecondsRealtime(2.0f);
            Collider2D barrier = null; float bestArea = 0f;
            foreach (Collider2D c in best.GetComponentsInChildren<Collider2D>(true))
            {
                if (c.isTrigger || !c.enabled || !c.gameObject.activeInHierarchy) continue;
                if (c.name.Contains("Cap")) continue;
                float a = c.bounds.size.x * c.bounds.size.y;
                if (a > bestArea) { bestArea = a; barrier = c; }
            }
            Logger.LogInfo("PROBE closed isOpen=" + best.isOpen + " barrier=" + (barrier != null ? barrier.name + " center=" + barrier.bounds.center.ToString("0.00") + " size=" + barrier.bounds.size.ToString("0.00") : "none"));
            if (barrier != null)
            {
                for (int phase = 0; phase < 2; phase++)
                {
                    State.GateGhost = (phase == 1);
                    if (phase == 0) GhostTools.Release(true, false); else GhostTools.Refresh(pc, true, false);
                    pc.transform.position = new Vector3(barrier.bounds.center.x, barrier.bounds.center.y, home.z);
                    if (rb != null) rb.velocity = Vector2.zero;
                    yield return new WaitForSecondsRealtime(0.8f);
                    Collider2D pcol = pc.GetComponent<Collider2D>();
                    bool overlap = pcol != null && pcol.bounds.Intersects(barrier.bounds);
                    Logger.LogInfo("PROBE phase=" + (phase == 0 ? "ghost OFF" : "ghost ON") + " player=" + pc.transform.position.ToString("0.00") + " barrierCenter=" + barrier.bounds.center.ToString("0.00") + " movedX=" + Mathf.Abs(pc.transform.position.x - barrier.bounds.center.x).ToString("0.00") + " movedY=" + Mathf.Abs(pc.transform.position.y - barrier.bounds.center.y).ToString("0.00") + " stillInsideBarrier=" + overlap);
                }
            }
            // --- blocker probe: nearest DestructibleBlocker (intact or not), force its physical barrier on and test ghost OFF/ON
            DestructibleBlocker bl = null; float bld = 1e9f;
            int nBl = 0, nSolid = 0;
            foreach (DestructibleBlocker b in UnityEngine.Object.FindObjectsOfType<DestructibleBlocker>())
            {
                nBl++;
                bool solid = false; foreach (Collider2D c0 in GhostTools.BlockerSolids(b)) if (!c0.isTrigger) solid = true;
                if (solid) nSolid++;
                if (!solid) continue;
                float d = (b.transform.position - pc.transform.position).magnitude;
                if (d < bld) { bld = d; bl = b; }
            }
            Logger.LogInfo("PROBE blockers loaded=" + nBl + " with_solid_collider=" + nSolid);
            if (bl == null) Logger.LogInfo("PROBE no blocker");
            else
            {
                Collider2D pb = null;
                foreach (Collider2D c in GhostTools.BlockerSolids(bl))
                {
                    if (c.isTrigger) continue;
                    pb = c; break;
                }
                if (pb == null) Logger.LogInfo("PROBE blocker " + bl.name + " has no solid collider");
                else
                {
                    bool pbWas = pb.enabled; bool goWas = pb.gameObject.activeSelf;
                    pb.gameObject.SetActive(true); pb.enabled = true;
                    Logger.LogInfo("PROBE blocker=" + bl.name + " destroyed=" + bl.Destroyed + " collider=" + pb.name + " center=" + pb.bounds.center.ToString("0.00") + " size=" + pb.bounds.size.ToString("0.00"));
                    for (int phase = 0; phase < 2; phase++)
                    {
                        State.BlockerGhost = (phase == 1);
                        if (phase == 0) GhostTools.Release(false, true); else GhostTools.Refresh(pc, false, true);
                        pc.transform.position = new Vector3(pb.bounds.center.x, pb.bounds.center.y, home.z);
                        if (rb != null) rb.velocity = Vector2.zero;
                        yield return new WaitForSecondsRealtime(0.8f);
                        Collider2D pcol = pc.GetComponent<Collider2D>();
                        bool overlap = pcol != null && pcol.bounds.Intersects(pb.bounds);
                        Logger.LogInfo("PROBE blocker phase=" + (phase == 0 ? "ghost OFF" : "ghost ON") + " movedX=" + Mathf.Abs(pc.transform.position.x - pb.bounds.center.x).ToString("0.00") + " movedY=" + Mathf.Abs(pc.transform.position.y - pb.bounds.center.y).ToString("0.00") + " stillInsideBarrier=" + overlap);
                    }
                    State.BlockerGhost = false; GhostTools.Release(false, true);
                    pb.enabled = pbWas; pb.gameObject.SetActive(goWas);
                }
            }            State.GateGhost = g0;
            if (!g0) GhostTools.Release(true, false);
            pc.transform.position = home;
            if (rb != null) rb.velocity = Vector2.zero;
            if (wasOpen) best.OpenGate(false);
            yield return new WaitForSecondsRealtime(1.5f);
            Logger.LogInfo("PROBE restored isOpen=" + best.isOpen + " player=" + pc.transform.position.ToString("0.00"));
        }

        void OnGUI()
        {
            if (!showHud) return;
            GUI.depth = 0;
            float sc = Mathf.Max(1f, Screen.height / 720f);
            GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(sc, sc, 1f));
            string[] lines = new string[]
            {
                "9 YEARS TRAINER (offline)  [" + keyHud.Value + "] hide",
                "[" + keyGod.Value + "] God Mode ........ " + OnOff(State.GodMode),
                "[" + keyAddMoney.Value + "] Add Coins +" + cfgAddMoney.Value,
                "[" + keyInfMoney.Value + "] Infinite Money .. " + OnOff(State.InfiniteMoney),
                "[" + keyJump.Value + "] Unlimited Jump . " + OnOff(State.UnlimitedJump),
                "[" + keySpeed.Value + "] Speed x" + State.SpeedMultiplier.ToString("0.#") + " ....... " + OnOff(State.SpeedBoost),
                "[" + keyOneHit.Value + "] One-Hit Kill ..... " + OnOff(State.OneHitKill) + (State.OhkBosses ? " (bosses too!)" : " (not bosses)"),
                "[" + keyMagic.Value + "] Infinite Magic .. " + OnOff(State.InfiniteMagic),
                "[" + keyHeal.Value + "] Full Heal",
                "[" + keyMap.Value + "] Reveal Map ..... " + OnOff(State.RevealMap),
                "[" + keyItemsOnMap.Value + "] Items on Map ... " + OnOff(State.ShowItems),
                "[" + keyUnlimItems.Value + "] Unlimited Items . " + OnOff(State.UnlimitedItems),
                "[" + keyGates.Value + "] Walk thru Gates . " + OnOff(State.GateGhost),
                "[" + keyBlockers.Value + "] Walk thru Walls . " + OnOff(State.BlockerGhost),
                "[" + keyDiag.Value + "] Save diagnostics",
                "[" + keyUnstick.Value + "] Unstick (if stuck after boss)"
            };
            float h = 8 + lines.Length * 18 + (Time.unscaledTime < toastUntil ? 22 : 0);
            GUI.Box(new Rect(8, 8, 290, h), GUIContent.none);
            for (int i = 0; i < lines.Length; i++)
                GUI.Label(new Rect(14, 10 + i * 18, 280, 20), lines[i]);
            if (Time.unscaledTime < toastUntil)
                GUI.Label(new Rect(14, 10 + lines.Length * 18, 280, 20), ">> " + toast);
        }

        // ---------------- Self-test (TRAINER_SELFTEST=1) ----------------
        class FeatureResult
        {
            public string Branch, Name, HookStatus = "UNKNOWN", Status = "PENDING", Detail = "";
        }
        readonly List<FeatureResult> results = new List<FeatureResult>();

        static bool IsPatched(MethodBase mb)
        {
            try
            {
                if (mb == null) return false;
                Patches info = Harmony.GetPatchInfo(mb);
                return info != null && (info.Prefixes.Count + info.Postfixes.Count) > 0;
            }
            catch { return false; }
        }
        static bool IsPatched(Type t, string name)
        {
            return IsPatched(AccessTools.Method(t, name));
        }
        static bool IsPatchedGetter(Type t, string name)
        {
            return IsPatched(AccessTools.PropertyGetter(t, name));
        }

        FeatureResult Add(string branch, string name, bool hooked)
        {
            FeatureResult r = new FeatureResult();
            r.Branch = branch; r.Name = name;
            r.HookStatus = hooked ? "HOOKED" : "HOOK_MISSING";
            results.Add(r);
            return r;
        }

        void RunSelfTest(PlayerController pc)
        {
            results.Clear();
            bool sgg = State.GateGhost, sbg = State.BlockerGhost; bool sg = State.GodMode, si = State.InfiniteMoney, sj = State.UnlimitedJump, ss = State.SpeedBoost, so = State.OneHitKill, sm = State.InfiniteMagic, sr = State.RevealMap, sx = State.ShowItems, su = State.UnlimitedItems;
            PlayerHealth ph = pc.europaobjects.healthObject;
            CurrencyInventory inv = pc.Europa.CurrencyInventory;
            CurrencyInventory.CurrencyType coin = CurrencyInventory.CurrencyType.Coin;

            // ---- COMBAT: God Mode ----
            FeatureResult rg = Add("SUBAGENT-COMBAT-01", "God Mode",
                IsPatchedGetter(typeof(PlayerController), "invincible") && IsPatched(typeof(PlayerHealth), "Hurt") && IsPatched(typeof(PlayerHealth), "CheckDie"));
            try
            {
                float hp = ph.health, mg = ph.Magic;
                int maxHp = pc.Europa.MaxHealth;
                bool inv0 = !float.IsNaN(hp) && !float.IsInfinity(hp) && maxHp > 0 && maxHp < 1000 && hp >= 0f && hp <= maxHp * 2f;
                State.GodMode = false;
                bool invOff = pc.invincible;
                State.GodMode = true;
                bool invOn = pc.invincible;
                ph.Hurt(1f);
                bool unchanged = Math.Abs(ph.health - hp) < 0.001f && Math.Abs(ph.Magic - mg) < 0.001f;
                float h2 = ph.health;
                ph.health = 0f;
                bool deadBlocked = !ph.CheckDie();
                ph.health = h2;
                State.GodMode = sg;
                bool ok = rg.HookStatus == "HOOKED" && inv0 && invOn && unchanged && deadBlocked;
                rg.Status = ok ? "PASS" : "FAIL";
                rg.Detail = "hp=" + hp + "/" + maxHp + " magic=" + mg + " invariant=" + inv0 + " invincible(off=" + invOff + ",on=" + invOn + ") Hurt_no_change=" + unchanged + " CheckDie_blocked=" + deadBlocked;
            }
            catch (Exception e) { rg.Status = "FAIL"; rg.Detail = e.Message; State.GodMode = sg; }

            // ---- COMBAT: One-Hit Kill (regular enemies only; bosses protected) ----
            FeatureResult ro = Add("SUBAGENT-COMBAT-01", "One-Hit Kill", IsPatched(typeof(DamageTable), "CalculateDamage") && IsPatched(typeof(HurtableObject), "ProcessHit") && IsPatched(typeof(BossBase), "ProcessHit") && ReceiverTrack.Patched >= 10);
            try
            {
                DamageTable[] tables = Resources.FindObjectsOfTypeAll<DamageTable>();
                if (tables != null && tables.Length > 0)
                {
                    HittableObject.HitParameters hp = new HittableObject.HitParameters();
                    hp.BaseDamage = 1f;
                    hp.DamagingElement = ConstantsManager.Gameplay.Element.Neutral;
                    DamageTable dt = tables[0];
                    Type keep = ReceiverTrack.CurrentType; bool ob = State.OhkBosses;
                    State.OneHitKill = false; ReceiverTrack.CurrentType = typeof(EnemyHealth); State.OhkBosses = false;
                    float d0 = dt.CalculateDamage(ConstantsManager.Gameplay.Element.Neutral, hp);
                    State.OneHitKill = true;
                    ReceiverTrack.CurrentType = null;
                    float dOutside = dt.CalculateDamage(ConstantsManager.Gameplay.Element.Neutral, hp);
                    ReceiverTrack.CurrentType = typeof(EnemyHealth);
                    float dEnemy = dt.CalculateDamage(ConstantsManager.Gameplay.Element.Neutral, hp);
                    ReceiverTrack.CurrentType = typeof(TalosHeart_StateControl);
                    float dBoss = dt.CalculateDamage(ConstantsManager.Gameplay.Element.Neutral, hp);
                    ReceiverTrack.CurrentType = typeof(BossBase);
                    float dBoss2 = dt.CalculateDamage(ConstantsManager.Gameplay.Element.Neutral, hp);
                    State.OhkBosses = true;
                    float dBossOpt = dt.CalculateDamage(ConstantsManager.Gameplay.Element.Neutral, hp);
                    State.OhkBosses = ob; ReceiverTrack.CurrentType = keep; State.OneHitKill = so;
                    bool protectedBoss = ReceiverTrack.IsProtected(typeof(TalosHeart_StateControl)) && ReceiverTrack.IsProtected(typeof(BossFramework)) && ReceiverTrack.IsProtected(typeof(MidBossBase)) && !ReceiverTrack.IsProtected(typeof(EnemyHealth));
                    bool ok = d0 > 0f && dEnemy >= 99999f && dOutside == d0 && dBoss == d0 && dBoss2 == d0 && dBossOpt >= 99999f && protectedBoss;
                    ro.Status = (ro.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                    ro.Detail = "normal=" + d0 + " enemy+OHK=" + dEnemy + " outsideHit=" + dOutside + " TalosHeart+OHK=" + dBoss + " BossBase+OHK=" + dBoss2 + " boss_opt_in=" + dBossOpt + " tracked_ProcessHit_methods=" + ReceiverTrack.Patched;
                }
                else
                {
                    ro.Status = ro.HookStatus == "HOOKED" ? "PASS" : "FAIL";
                    ro.Detail = "hook only (no DamageTable asset loaded yet)";
                }
            }
            catch (Exception e) { ro.Status = "FAIL"; ro.Detail = e.Message; State.OneHitKill = so; }
            // ---- ECONOMY: Add Money (delta) ----
            FeatureResult re = Add("SUBAGENT-ECONOMY-02", "Add Money", inv != null);
            int coinBefore = 0;
            try
            {
                coinBefore = inv.GetCurrency(coin);
                int max = pc.Europa.BaseStats.MaxCurrency;
                int d = Math.Min(10, max - coinBefore);
                if (d > 0)
                {
                    inv.AddCurrency(coin, d);
                    bool plus = inv.GetCurrency(coin) == coinBefore + d;
                    State.InfiniteMoney = false;
                    inv.SubtractCurrency(coin, d);
                    bool back = inv.GetCurrency(coin) == coinBefore;
                    re.Status = (plus && back) ? "PASS" : "FAIL";
                    re.Detail = "coins_before=" + coinBefore + " +" + d + "=>" + (coinBefore + d) + " restored=" + back + " cap=" + max;
                }
                else { re.Status = "PASS"; re.Detail = "coins at cap (" + max + "); AddCurrency clamps"; }
            }
            catch (Exception e) { re.Status = "FAIL"; re.Detail = e.Message; }
            State.InfiniteMoney = si;

            // ---- ECONOMY: Infinite Money ----
            Type[] subSig = new Type[] { typeof(CurrencyInventory.CurrencyType), typeof(int) };
            FeatureResult ri = Add("SUBAGENT-ECONOMY-02", "Infinite Money", IsPatched(AccessTools.Method(typeof(CurrencyInventory), "SubtractCurrency", subSig)));
            try
            {
                int max = pc.Europa.BaseStats.MaxCurrency;
                int b = inv.GetCurrency(coin);
                int added = 0;
                if (b < 10 && max - b >= 10) { inv.AddCurrency(coin, 10); added = 10; b = inv.GetCurrency(coin); }
                State.InfiniteMoney = true;
                inv.SubtractCurrency(coin, 1);
                bool kept = inv.GetCurrency(coin) == b;
                State.InfiniteMoney = false;
                if (added > 0) inv.SubtractCurrency(coin, added);
                State.InfiniteMoney = si;
                ri.Status = (ri.HookStatus == "HOOKED" && kept) ? "PASS" : "FAIL";
                ri.Detail = "SubtractCurrency(Coin,1) with toggle on left coins unchanged=" + kept + " (coins=" + b + ")";
            }
            catch (Exception e) { ri.Status = "FAIL"; ri.Detail = e.Message; State.InfiniteMoney = si; }
            try
            {
                int now = inv.GetCurrency(coin);
                if (now > coinBefore) { State.InfiniteMoney = false; inv.SubtractCurrency(coin, now - coinBefore); State.InfiniteMoney = si; }
            }
            catch { }

            // ---- MOVEMENT: Speed multiplier ----
            FeatureResult rs = Add("SUBAGENT-MOVEMENT-04", "Speed Multiplier", IsPatched(typeof(Move_Block), "MoveForce"));
            try
            {
                Move_Block mb = pc.europaobjects.mover;
                float x0 = 1f, x1 = 1f;
                State.SpeedBoost = false; Patch_Move_MoveForce.Prefix(mb, ref x0);
                State.SpeedBoost = true; Patch_Move_MoveForce.Prefix(mb, ref x1);
                State.SpeedBoost = ss;
                bool ok = Math.Abs(x0 - 1f) < 0.0001f && Math.Abs(x1 - State.SpeedMultiplier) < 0.0001f;
                rs.Status = (rs.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                rs.Detail = "MoveForce multiplier off=" + x0 + " on=" + x1 + " mult=" + State.SpeedMultiplier + " WalkSpeed=" + mb.WalkSpeed;
            }
            catch (Exception e) { rs.Status = "FAIL"; rs.Detail = e.Message; State.SpeedBoost = ss; }

            // ---- JUMP: Unlimited jump (re-arm logic) ----
            FeatureResult rj = Add("SUBAGENT-JUMP-05", "Unlimited Jump", IsPatched(typeof(JumpV2_Block), "SpawnJumpFX") && IsPatched(typeof(JumpV2_Block), "CheckDoJump"));
            try
            {
                JumpV2_Block jb = pc.europaobjects.jump2;
                int f0 = jb.FXSpawned, n0 = jb.JUMPnumber, mx0 = jb.MAXJump; bool a0 = jb.alreadydoublejumped;
                jb.FXSpawned = 2; jb.JUMPnumber = 2; jb.alreadydoublejumped = true; jb.MAXJump = 1;
                State.UnlimitedJump = true;
                Patch_Jump_SpawnJumpFX.Postfix(jb);
                Patch_Jump_CheckDoJump.Prefix(jb);
                bool rearmed = jb.FXSpawned == 1 && jb.JUMPnumber == 1 && !jb.alreadydoublejumped && jb.MAXJump >= 2;
                State.UnlimitedJump = false;
                jb.FXSpawned = 2; jb.JUMPnumber = 2; jb.alreadydoublejumped = true; jb.MAXJump = 1;
                Patch_Jump_SpawnJumpFX.Postfix(jb);
                Patch_Jump_CheckDoJump.Prefix(jb);
                bool untouched = jb.FXSpawned == 2 && jb.JUMPnumber == 2 && jb.alreadydoublejumped && jb.MAXJump == 1;
                jb.FXSpawned = f0; jb.JUMPnumber = n0; jb.alreadydoublejumped = a0; jb.MAXJump = mx0;
                State.UnlimitedJump = sj;
                rj.Status = (rj.HookStatus == "HOOKED" && rearmed && untouched) ? "PASS" : "FAIL";
                rj.Detail = "rearm_on=" + rearmed + " untouched_off=" + untouched + " MAXJump=" + jb.MAXJump;
            }
            catch (Exception e) { rj.Status = "FAIL"; rj.Detail = e.Message; State.UnlimitedJump = sj; }

            // ---- MAGIC: Infinite magic ----
            FeatureResult rm = Add("SUBAGENT-MAGIC-06", "Infinite Magic", IsPatched(typeof(PlayerHealth), "ChangeMagic"));
            try
            {
                float m0 = ph.Magic;
                State.InfiniteMagic = true;
                ph.ChangeMagic(-0.5f);
                bool kept = Math.Abs(ph.Magic - m0) < 0.001f;
                State.InfiniteMagic = false;
                State.InfiniteMagic = sm;
                rm.Status = (rm.HookStatus == "HOOKED" && kept) ? "PASS" : "FAIL";
                rm.Detail = "ChangeMagic(-0.5) with toggle on left magic unchanged=" + kept + " (magic=" + m0 + "/" + pc.Europa.MaxMagic + ")";
            }
            catch (Exception e) { rm.Status = "FAIL"; rm.Detail = e.Message; State.InfiniteMagic = sm; }

            // ---- ECONOMY: Unlimited Items (materials never spent, top-up) ----
            FeatureResult ru = Add("SUBAGENT-ECONOMY-02", "Unlimited Items", IsPatched(AccessTools.Method(typeof(CurrencyInventory), "SubtractCurrency", subSig)));
            try
            {
                CurrencyInventory.CurrencyType[] mats = new CurrencyInventory.CurrencyType[] { CurrencyInventory.CurrencyType.BlueNote, CurrencyInventory.CurrencyType.RedNote, CurrencyInventory.CurrencyType.ArmorPiece, CurrencyInventory.CurrencyType.LightPiece };
                int max = pc.Europa.BaseStats.MaxCurrency;
                int[] before = new int[mats.Length];
                for (int k = 0; k < mats.Length; k++) before[k] = inv.GetCurrency(mats[k]);
                bool allKept = true, topped = true;
                State.UnlimitedItems = true;
                TopUpItems(inv, pc);
                int want = Math.Min(State.ItemFill, max);
                int[] afterTop = new int[mats.Length];
                for (int k = 0; k < mats.Length; k++)
                {
                    afterTop[k] = inv.GetCurrency(mats[k]);
                    if (afterTop[k] < want) topped = false;
                    inv.SubtractCurrency(mats[k], 3);
                    if (inv.GetCurrency(mats[k]) != afterTop[k]) allKept = false;
                }
                State.UnlimitedItems = false;
                for (int k = 0; k < mats.Length; k++)
                {
                    int now = inv.GetCurrency(mats[k]);
                    if (now > before[k]) inv.SubtractCurrency(mats[k], now - before[k]);
                }
                State.UnlimitedItems = su;
                ru.Status = (ru.HookStatus == "HOOKED" && allKept && topped) ? "PASS" : "FAIL";
                ru.Detail = "topped_to>=" + want + "=" + topped + " Subtract(3) on notes/pieces left unchanged=" + allKept + " (before=" + string.Join(",", Array.ConvertAll(before, x => x.ToString())) + ")";
            }
            catch (Exception e) { ru.Status = "FAIL"; ru.Detail = e.Message; State.UnlimitedItems = su; }

            // ---- MAP: Reveal Map ----
            FeatureResult rv = Add("SUBAGENT-MAP-07", "Reveal Map", IsPatched(typeof(MapGeneratorUI), "ShowMap") && IsPatched(typeof(MapAreaManager), "GetRoomsIndividualInfo"));
            try
            {
                List<MapGeneratorUI.MapCellInformation> recs = GameplayManager.Instance.SessionManager.CurrentSession.MapCellInformationRecords;
                List<MapGeneratorUI.MapCellInformation> backup = new List<MapGeneratorUI.MapCellInformation>(recs);
                int u0 = MapTools.CountUndiscovered();
                int changed = MapTools.RevealAll();
                int u1 = MapTools.CountUndiscovered();
                // restore the in-memory map state exactly as it was
                if (recs.Count >= backup.Count) for (int k = 0; k < backup.Count; k++) recs[k] = backup[k];
                int u2 = MapTools.CountUndiscovered();
                bool ok = (u0 == 0 || u1 < u0) && changed <= u0 - u1 && u2 == u0;
                rv.Status = (rv.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                rv.Detail = "cells=" + recs.Count + " undiscovered before=" + u0 + " after_reveal=" + u1 + " changed=" + changed + " restored=" + (u2 == u0);
            }
            catch (Exception e) { rv.Status = "FAIL"; rv.Detail = e.Message; }

            // ---- MAP: Items on map (database + collected state) ----
            FeatureResult rx = Add("SUBAGENT-MAP-07", "Items on Map", IsPatched(typeof(MapGeneratorUI), "ShowMap"));
            try
            {
                int total = ItemDb.All().Count;
                List<ItemDb.Row> todo = ItemDb.Uncollected();
                // cross-check against the live scene: every loaded ItemHolder must be in the database and agree on collected state
                int live = 0, inDb = 0, agree = 0;
                foreach (ItemHolder h in UnityEngine.Object.FindObjectsOfType<ItemHolder>())
                {
                    if (h == null || string.IsNullOrEmpty(h.TrackingInfo.id)) continue;
                    live++;
                    foreach (ItemDb.Row r in ItemDb.All())
                        if (r.TrackId == h.TrackingInfo.id) { inDb++; if (ItemDb.Collected(r) == !h.IsAlive) agree++; break; }
                }
                MapGeneratorUI ui = GameplayManager.Instance.UI.Pause.mapUI;
                State.ShowItems = true;
                int made = MapTools.BuildItemMarkers(ui);
                MapTools.ClearMarkers();
                State.ShowItems = sx;
                bool ok = total > 0 && made == todo.Count && inDb == live && agree == live;
                rx.Status = (rx.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                rx.Detail = "db_items=" + total + " uncollected=" + todo.Count + " markers_built=" + made + " live_holders=" + live + " in_db=" + inDb + " state_agrees=" + agree;
            }
            catch (Exception e) { rx.Status = "FAIL"; rx.Detail = e.Message; State.ShowItems = sx; }
            // ---- WORLD: Walk through gates / blockers ----
            FeatureResult rgt = Add("SUBAGENT-GATE-08", "Walk Through Gates", IsPatched(typeof(GateController), "UpdateInstantBarrier"));
            FeatureResult rbl = Add("SUBAGENT-GATE-08", "Walk Through Blockers", true);
            try
            {
                List<Collider2D> player = GhostTools.PlayerSolids(pc);
                // gates / blockers present in the loaded rooms (may be zero in a save room)
                List<Collider2D> gcols = new List<Collider2D>(), bcols = new List<Collider2D>();
                foreach (GateController g in UnityEngine.Object.FindObjectsOfType<GateController>())
                    foreach (Collider2D c in GhostTools.GateSolids(g)) if (!c.isTrigger && c.enabled && c.gameObject.activeInHierarchy) gcols.Add(c);
                foreach (DestructibleBlocker b in UnityEngine.Object.FindObjectsOfType<DestructibleBlocker>())
                    foreach (Collider2D c in GhostTools.BlockerSolids(b)) if (!c.isTrigger && c.enabled && c.gameObject.activeInHierarchy) bcols.Add(c);
                GhostTools.Refresh(pc, true, false);
                int gIgn = 0; foreach (Collider2D c in gcols) { bool all = true; foreach (Collider2D p in player) if (!Physics2D.GetIgnoreCollision(p, c)) all = false; if (all) gIgn++; }
                GhostTools.Release(true, false);
                int gAfter = 0; foreach (Collider2D c in gcols) { bool any = false; foreach (Collider2D p in player) if (Physics2D.GetIgnoreCollision(p, c)) any = true; if (any) gAfter++; }
                rgt.Status = (rgt.HookStatus == "HOOKED" && player.Count > 0 && gIgn == gcols.Count && gAfter == 0) ? "PASS" : "FAIL";
                rgt.Detail = "player_solid_colliders=" + player.Count + " gate_colliders_in_loaded_rooms=" + gcols.Count + " ignored_when_on=" + gIgn + " still_ignored_after_off=" + gAfter;
                GhostTools.Refresh(pc, false, true);
                int bIgn = 0; foreach (Collider2D c in bcols) { bool all = true; foreach (Collider2D p in player) if (!Physics2D.GetIgnoreCollision(p, c)) all = false; if (all) bIgn++; }
                GhostTools.Release(false, true);
                int bAfter = 0; foreach (Collider2D c in bcols) { bool any = false; foreach (Collider2D p in player) if (Physics2D.GetIgnoreCollision(p, c)) any = true; if (any) bAfter++; }
                rbl.Status = (player.Count > 0 && bIgn == bcols.Count && bAfter == 0) ? "PASS" : "FAIL";
                rbl.Detail = "blocker_colliders_in_loaded_rooms=" + bcols.Count + " ignored_when_on=" + bIgn + " still_ignored_after_off=" + bAfter;
                if (State.GateGhost || State.BlockerGhost) GhostTools.Refresh(pc, State.GateGhost, State.BlockerGhost);
            }
            catch (Exception e) { rgt.Status = "FAIL"; rgt.Detail = e.Message; rbl.Status = "FAIL"; rbl.Detail = e.Message; }
            State.GodMode = sg; State.InfiniteMoney = si; State.UnlimitedJump = sj; State.SpeedBoost = ss; State.OneHitKill = so; State.InfiniteMagic = sm; State.RevealMap = sr; State.ShowItems = sx; State.UnlimitedItems = su; State.GateGhost = sgg; State.BlockerGhost = sbg;
            WriteReport(true, "done");
        }

        void WriteReport(bool runtime, string note)
        {
            try
            {
                bool all = runtime && results.Count > 0;
                foreach (FeatureResult r in results) if (r.Status != "PASS") all = false;
                StringBuilder sb = new StringBuilder();
                sb.Append("{\n");
                sb.Append("  \"overall_status\": \"" + (!runtime ? "PLAYER_NOT_LOADED_YET" : (all ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL")) + "\",\n");
                sb.Append("  \"note\": \"" + Esc(note) + "\",\n");
                sb.Append("  \"patched_method_count\": " + patchedMethodCount + ",\n");
                sb.Append("  \"patch_errors\": " + patchErrors.Count + ",\n");
                sb.Append("  \"feature_results\": [\n");
                for (int i = 0; i < results.Count; i++)
                {
                    FeatureResult r = results[i];
                    sb.Append("    {\"subagent_branch_id\": \"" + r.Branch + "\", \"feature\": \"" + Esc(r.Name) + "\", \"hook_status\": \"" + r.HookStatus + "\", \"status\": \"" + r.Status + "\", \"detail\": \"" + Esc(r.Detail) + "\"}");
                    sb.Append(i < results.Count - 1 ? ",\n" : "\n");
                }
                sb.Append("  ]\n}\n");
                File.WriteAllText(Path.Combine(Paths.GameRootPath, "trainer_selftest_report.json"), sb.ToString());
            }
            catch (Exception e) { Logger.LogError("report write failed: " + e.Message); }
        }

        static string Esc(string s)
        {
            return (s ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", " ").Replace("\n", " ");
        }
    }

    // ================= Harmony patches =================

    // Diagnostics only: applied manually when TRAINER_TRACE=1 (not part of PatchAll).
    public static class TraceHooks
    {
        public static void InputtedAJump(JumpV2_Block __instance)
        {
            NysTrainerPlugin.Log("TRACEEV InputtedAJump grounded=" + __instance.pc.isGrounded + " fx=" + __instance.FXSpawned + " dj=" + __instance.alreadydoublejumped + " allowed=" + __instance.JumpAllowed());
        }
        public static void CheckDoJump(JumpV2_Block __instance)
        {
            NysTrainerPlugin.Log("TRACEEV CheckDoJump fx=" + __instance.FXSpawned + " jn=" + __instance.JUMPnumber + " dj=" + __instance.alreadydoublejumped + " max=" + __instance.MAXJump);
        }
    }

    // COMBAT: every damage source checks !PlayerController.invincible before hurting Europa.
    [HarmonyPatch(typeof(PlayerController), "invincible", MethodType.Getter)]
    public static class Patch_PlayerController_invincible
    {
        static void Postfix(ref bool __result)
        {
            if (State.GodMode) __result = true;
        }
    }

    // COMBAT: backstop for callers that reach Hurt() without the invincible check.
    [HarmonyPatch(typeof(PlayerHealth), "Hurt")]
    public static class Patch_PlayerHealth_Hurt
    {
        static bool Prefix()
        {
            return !State.GodMode;
        }
    }

    // COMBAT: never report death while God Mode is on.
    [HarmonyPatch(typeof(PlayerHealth), "CheckDie")]
    public static class Patch_PlayerHealth_CheckDie
    {
        static void Postfix(ref bool __result)
        {
            if (State.GodMode) __result = false;
        }
    }

    // COMBAT: damage dealt by Europa (enemies, bosses, breakables). Only positive results are raised, so
    // resisted / shielded hits stay resisted.
    [HarmonyPatch(typeof(DamageTable), "CalculateDamage")]
    public static class Patch_DamageTable_CalculateDamage
    {
        static void Postfix(ref float __result)
        {
            if (State.OneHitKill && __result > 0f && ReceiverTrack.OhkAllowed()) __result = 99999f;
        }
    }

    // ECONOMY: spending coins becomes free. (The Cost / Cost[] overloads route through this one.)
    [HarmonyPatch(typeof(CurrencyInventory), "SubtractCurrency", new Type[] { typeof(CurrencyInventory.CurrencyType), typeof(int) })]
    public static class Patch_CurrencyInventory_SubtractCurrency
    {
        static bool Prefix(CurrencyInventory.CurrencyType type)
        {
            if (State.UnlimitedItems) return false;
            if (State.InfiniteMoney && type == CurrencyInventory.CurrencyType.Coin) return false;
            return true;
        }
    }

    // MOVEMENT: scale the ground/air walk force. Scripted auto-pilot moves are left untouched.
    [HarmonyPatch(typeof(Move_Block), "MoveForce")]
    public static class Patch_Move_MoveForce
    {
        public static void Prefix(Move_Block __instance, ref float xmultispeed)
        {
            if (!State.SpeedBoost) return;
            if (__instance != null && __instance.autopilot) return;
            xmultispeed *= State.SpeedMultiplier;
        }
    }

    // JUMP: the force is only applied when JUMPnumber <= MAXJump, and MAXJump is reset by the game to
    // ProgressionData.MaxJumpCount (1 until Double Jump is unlocked). Keep the cap at >= 2 while the toggle is on.
    [HarmonyPatch(typeof(JumpV2_Block), "CheckDoJump")]
    public static class Patch_Jump_CheckDoJump
    {
        public static void Prefix(JumpV2_Block __instance)
        {
            if (State.UnlimitedJump && __instance != null && __instance.MAXJump < 2) __instance.MAXJump = 2;
        }
    }

    // JUMP: after every successful jump put the jump state back to "one jump used" (the game's own re-arm values).
    [HarmonyPatch(typeof(JumpV2_Block), "SpawnJumpFX")]
    public static class Patch_Jump_SpawnJumpFX
    {
        public static void Postfix(JumpV2_Block __instance)
        {
            if (!State.UnlimitedJump || __instance == null) return;
            __instance.FXSpawned = 1;
            __instance.JUMPnumber = 1;
            __instance.alreadydoublejumped = false;
        }
    }

    // MAGIC: spending magic (Apino shots, abilities) is free.
    [HarmonyPatch(typeof(PlayerHealth), "ChangeMagic")]
    public static class Patch_PlayerHealth_ChangeMagic
    {
        static bool Prefix(float amount)
        {
            if (State.InfiniteMagic && amount < 0f) return false;
            return true;
        }
    }

    // GATES: door-type (slope) gates also block through code, not only through colliders:
    // 1) NoMoveTrigger zones switch off walking in one direction while the owner gate is closed
    [HarmonyPatch(typeof(NoMoveTrigger), "OnTriggerEnter2D")]
    public static class Patch_NoMoveTrigger_Enter
    {
        static bool Prefix()
        {
            return !State.GateGhost;
        }
    }

    // 2) the rail system that carries Europa over a slope door is switched off while the door is closed
    //    (Ramp_LDTK.fullyopen mirrors gate.isOpen every frame). Treat the ramp as open for the player only;
    //    the gate itself (state, graphics, save data) is untouched.
    [HarmonyPatch(typeof(Ramp_LDTK), "Update")]
    public static class Patch_Ramp_Update
    {
        static void Postfix(Ramp_LDTK __instance)
        {
            if (State.GateGhost && __instance._isDoor && __instance.ownergate != null) __instance.fullyopen = true;
        }
    }

    // 3) Move() refuses to walk while allowedtomoveleft/right are false
    [HarmonyPatch(typeof(Move_Block), "Move")]
    public static class Patch_Move_Move
    {
        static void Prefix(Move_Block __instance)
        {
            if (!State.GateGhost) return;
            __instance.allowedtomoveleft = true;
            __instance.allowedtomoveright = true;
        }
    }

    // GATES: when a gate (re)enables its instant barrier, make sure the player ignores it immediately.
    [HarmonyPatch(typeof(GateController), "UpdateInstantBarrier")]
    public static class Patch_GateController_UpdateInstantBarrier
    {
        static void Postfix(GateController __instance)
        {
            if (!State.GateGhost) return;
            try { GhostTools.ApplyGate(__instance); } catch { }
        }
    }

    // MAP: reveal every known room right before the pause map is built, and (re)build the item markers right after.
    [HarmonyPatch(typeof(MapGeneratorUI), "ShowMap")]
    public static class Patch_MapGeneratorUI_ShowMap
    {
        static void Prefix()
        {
            if (!State.RevealMap) return;
            try { MapTools.RevealAll(); }
            catch (Exception e) { NysTrainerPlugin.Log("RevealAll failed: " + e.Message); }
        }
        static void Postfix(MapGeneratorUI __instance)
        {
            try { MapTools.BuildItemMarkers(__instance); }
            catch (Exception e) { NysTrainerPlugin.Log("BuildItemMarkers failed: " + e.Message); }
        }
    }

    // MAP: with Reveal Map on, every area is revealed as soon as it is loaded (rooms/cells exist from that moment on).
    [HarmonyPatch(typeof(MapAreaManager), "GetRoomsIndividualInfo")]
    public static class Patch_MapAreaManager_GetRoomsIndividualInfo
    {
        static void Postfix()
        {
            if (!State.RevealMap) return;
            try { MapTools.RevealAll(); }
            catch (Exception e) { NysTrainerPlugin.Log("RevealAll(area) failed: " + e.Message); }
        }
    }

    // Walk-through: the player's solid colliders are told to ignore the solid colliders of gates / destructible walls.
    // Nothing about the gates themselves changes (state, animation, save data), only physics collision with the player.
    public static class GhostTools
    {
        static readonly Dictionary<int, Collider2D> gateCols = new Dictionary<int, Collider2D>();
        static readonly Dictionary<int, Collider2D> blockCols = new Dictionary<int, Collider2D>();
        static readonly FieldInfo fPhysical = AccessTools.Field(typeof(DestructibleBlocker), "physicalBarrier");
        static readonly FieldInfo fInstant = AccessTools.Field(typeof(GateController), "instantBarrier");
        static readonly FieldInfo fSliders = AccessTools.Field(typeof(GateController), "gateSliders");

        // Every collider that can stop the player at a gate: children of the gate, its instant barrier and the barrier of each slider
        // (the game references these through fields, they are not guaranteed to be children of the gate object).
        public static List<Collider2D> GateSolids(GateController g)
        {
            List<Collider2D> l = new List<Collider2D>();
            foreach (Collider2D c in g.GetComponentsInChildren<Collider2D>(true)) if (!l.Contains(c)) l.Add(c);
            try { Collider2D ib = fInstant != null ? (Collider2D)fInstant.GetValue(g) : null; if (ib != null && !l.Contains(ib)) l.Add(ib); } catch { }
            try
            {
                List<GateSlider> sl = fSliders != null ? (List<GateSlider>)fSliders.GetValue(g) : null;
                if (sl != null)
                    foreach (GateSlider s in sl)
                    {
                        if (s == null) continue;
                        foreach (Collider2D c in s.GetComponentsInChildren<Collider2D>(true)) if (!l.Contains(c)) l.Add(c);
                        try { Transform bt = s.BarrierTransform; if (bt != null) foreach (Collider2D c in bt.GetComponentsInChildren<Collider2D>(true)) if (!l.Contains(c)) l.Add(c); } catch { }
                    }
            }
            catch { }
            return l;
        }
        public static int GateColliders { get { return gateCols.Count; } }

        // A blocker's solid collider ("Physical Barrier") is a separate object, so it is read from the blocker's own field.
        public static List<Collider2D> BlockerSolids(DestructibleBlocker b)
        {
            List<Collider2D> l = new List<Collider2D>();
            try { Collider2D pb = fPhysical != null ? (Collider2D)fPhysical.GetValue(b) : null; if (pb != null) l.Add(pb); } catch { }
            foreach (Collider2D c in b.GetComponentsInChildren<Collider2D>(true)) if (!l.Contains(c)) l.Add(c);
            return l;
        }
        public static int BlockerColliders { get { return blockCols.Count; } }

        public static List<Collider2D> PlayerSolids(PlayerController pc)
        {
            List<Collider2D> l = new List<Collider2D>();
            foreach (Collider2D c in pc.GetComponentsInChildren<Collider2D>(true))
                if (c != null && !c.isTrigger) l.Add(c);
            return l;
        }

        static bool Usable(Collider2D c)
        {
            return c != null && !c.isTrigger && c.enabled && c.gameObject.activeInHierarchy;
        }

        public static int Apply(List<Collider2D> player, Collider2D c, Dictionary<int, Collider2D> reg)
        {
            if (!Usable(c)) return 0;
            foreach (Collider2D p in player)
                if (!Physics2D.GetIgnoreCollision(p, c)) Physics2D.IgnoreCollision(p, c, true);
            reg[c.GetInstanceID()] = c;
            return 1;
        }

        // Called the instant a gate switches its InstantBarrier collider on/off (re-enabling a collider clears Unity's ignore pair).
        public static void ApplyGate(GateController g)
        {
            PlayerController pc = PlayerController.Instance;
            if (pc == null || g == null) return;
            List<Collider2D> player = PlayerSolids(pc);
            foreach (Collider2D c in GateSolids(g)) Apply(player, c, gateCols);
        }

        public static void Refresh(PlayerController pc, bool gates, bool blockers)
        {
            List<Collider2D> player = PlayerSolids(pc);
            if (player.Count == 0) return;
            if (gates)
                foreach (GateController g in UnityEngine.Object.FindObjectsOfType<GateController>())
                    foreach (Collider2D c in GateSolids(g)) Apply(player, c, gateCols);
            if (blockers)
                foreach (DestructibleBlocker b in UnityEngine.Object.FindObjectsOfType<DestructibleBlocker>())
                    foreach (Collider2D c in BlockerSolids(b)) Apply(player, c, blockCols);
        }

        // TRAINER_TRACE=1 only: list gates/blockers of the loaded rooms with their distance to the player.
        public static void Dump(PlayerController pc)
        {
            Vector3 pp = pc.transform.position;
            List<string> l = new List<string>();
            foreach (GateController g in UnityEngine.Object.FindObjectsOfType<GateController>())
            {
                if (!g.gameObject.activeInHierarchy) continue;
                Vector3 p = g.transform.position;
                l.Add(((p - pp).magnitude).ToString("000.0") + " GATE " + g.name + " pos=" + p.ToString("0.0") + " open=" + g.isOpen + " track=" + g.TrackingInfo.id);
            }
            foreach (DestructibleBlocker b in UnityEngine.Object.FindObjectsOfType<DestructibleBlocker>())
            {
                if (!b.gameObject.activeInHierarchy) continue;
                Vector3 p = b.transform.position;
                l.Add(((p - pp).magnitude).ToString("000.0") + " BLOCKER " + b.name + " pos=" + p.ToString("0.0") + " destroyed=" + b.Destroyed + " track=" + b.TrackingInfo.id);
            }
            l.Sort();
            NysTrainerPlugin.Log("PLAYER pos=" + pp.ToString("0.0") + " grounded=" + pc.isGrounded);
            for (int i = 0; i < l.Count && i < 12; i++) NysTrainerPlugin.Log("NEAR " + l[i]);
            for (int i = 0; i < l.Count; i++) if (l[i].Contains("open=False") || l[i].Contains("destroyed=False")) NysTrainerPlugin.Log("CLOSED " + l[i]);
        }

        public static void Release(bool gates, bool blockers)
        {
            PlayerController pc = PlayerController.Instance;
            List<Collider2D> player = pc != null ? PlayerSolids(pc) : new List<Collider2D>();
            if (gates) ReleaseSet(player, gateCols);
            if (blockers) ReleaseSet(player, blockCols);
        }

        static void ReleaseSet(List<Collider2D> player, Dictionary<int, Collider2D> reg)
        {
            foreach (Collider2D c in reg.Values)
            {
                if (c == null) continue;
                foreach (Collider2D p in player)
                    if (p != null && Physics2D.GetIgnoreCollision(p, c)) Physics2D.IgnoreCollision(p, c, false);
            }
            reg.Clear();
        }
    }

    // Knows which object is currently being hit (ProcessHit scope) so One-Hit Kill can leave scripted bosses alone.
    // Boss fights are phase scripts (health thresholds, intro/outro coroutines); a 99999 hit skips the whole chain.
    public static class ReceiverTrack
    {
        [ThreadStatic] public static Type CurrentType;
        public static int Patched;

        public static bool IsProtected(Type t)
        {
            if (t == null) return false;
            return typeof(BossBase).IsAssignableFrom(t) || typeof(BossFramework).IsAssignableFrom(t) || typeof(MidBossBase).IsAssignableFrom(t)
                || typeof(BossProjectileBase).IsAssignableFrom(t) || typeof(BubbleBossCrystal).IsAssignableFrom(t) || typeof(LynxCrystal).IsAssignableFrom(t)
                || typeof(LinkClone).IsAssignableFrom(t) || typeof(Cornucopia).IsAssignableFrom(t);
        }

        // One-Hit Kill applies only while a hit on a known, non-boss receiver is being processed.
        public static bool OhkAllowed()
        {
            if (State.OhkBosses) return true;
            Type t = CurrentType;
            if (t == null) return false;
            return !IsProtected(t);
        }

        public static void Enter(HittableObject __instance, out Type __state)
        {
            __state = CurrentType;
            CurrentType = __instance != null ? __instance.GetType() : null;
        }
        public static Exception Leave(Exception __exception, Type __state)
        {
            CurrentType = __state;
            return __exception;
        }

        public static int PatchAll(Harmony h)
        {
            int n = 0;
            HarmonyMethod pre = new HarmonyMethod(typeof(ReceiverTrack).GetMethod("Enter"));
            HarmonyMethod fin = new HarmonyMethod(typeof(ReceiverTrack).GetMethod("Leave"));
            foreach (Type t in typeof(HittableObject).Assembly.GetTypes())
            {
                if (!typeof(HittableObject).IsAssignableFrom(t)) continue;
                MethodInfo m = t.GetMethod("ProcessHit", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly, null, new Type[] { typeof(HittableObject.HitParameters) }, null);
                if (m == null || m.IsAbstract) continue;
                try { h.Patch(m, prefix: pre, finalizer: fin); n++; }
                catch (Exception e) { NysTrainerPlugin.Log("ReceiverTrack skip " + t.Name + ": " + e.Message); }
            }
            Patched = n;
            return n;
        }
    }

    // Emergency recovery: gives control back after a cutscene / boss outro that never finished (input locked, frozen time...).
    // Only touches things a finished cutscene would reset anyway; a pause menu you opened yourself is left alone.
    public static class Unstick
    {
        public static string Run()
        {
            List<string> done = new List<string>();
            PlayerController pc = PlayerController.Instance;
            if (pc == null) return "Unstick: no player loaded";
            try { if (GameplayManager.Instance.UI.Pause.isPaused) return "Unstick: the pause menu is open - close it first"; } catch { }
            try { MainManager mm = MainManager.Instance; if (mm != null && mm.GameplayInputState != null) { mm.ChangeInputState(mm.GameplayInputState); done.Add("input"); } } catch { }
            try { GameplayManager.Instance.UI.Pause.DisablePause(false); done.Add("pause"); } catch { }
            try { if (Time.timeScale < 0.01f) { MainManager.Instance.TimeControlManager.UnFreeze(); MainManager.Instance.TimeControlManager.ChangeTimeScale(1f); done.Add("time"); } } catch { }
            try { pc.EnablePlayerInput(true); done.Add("player-input"); } catch { }
            try { pc.playerblock.KILLINPUT = false; pc.playerblock.artificiallycontrolled = false; pc.playerblock.enabled = true; done.Add("controls"); } catch { }
            try { Move_Block mv = pc.europaobjects.mover; mv.enabled = true; mv.cinemfrozen = false; mv.autopilot = false; mv.ignorefreezes = false; done.Add("mover"); } catch { }
            try { pc.canmove = true; pc.unabletomove = false; pc.freetojump = true; pc.europaobjects.apinomove.unabletomove = false; done.Add("flags"); } catch { }
            try { pc.SetRigidbodyConstraints(RigidbodyConstraints2D.FreezeRotation); done.Add("physics"); } catch { }
            try { pc.europaobjects.lightautopilot.cutsceneOn = false; } catch { }
            try { NotificationManager.TriggerEvent("Notification.UI.HealthBarShow"); } catch { }
            try { GameplayManager.Instance.UI.DialogueRunner.Clear(); done.Add("dialogue"); } catch { }
            NysTrainerPlugin.Log("Unstick ran: " + string.Join(", ", done.ToArray()));
            return "Unstick: control restored (" + done.Count + " steps)";
        }
    }

    // One-key troubleshooting report: what is touching the character and what the nearby gates / door ramps are doing.
    public static class Diag
    {
        static string Path(Transform t)
        {
            string p = t.name; int n = 0;
            while (t.parent != null && n++ < 6) { t = t.parent; p = t.name + "/" + p; }
            return p;
        }
        static string Comps(GameObject g)
        {
            List<string> l = new List<string>();
            foreach (Component c in g.GetComponents<Component>()) if (c != null && !(c is Transform)) l.Add(c.GetType().Name);
            return string.Join(",", l.ToArray());
        }
        static bool Ignored(List<Collider2D> player, Collider2D c)
        {
            foreach (Collider2D p in player) if (!Physics2D.GetIgnoreCollision(p, c)) return false;
            return player.Count > 0;
        }

        public static void Write(PlayerController pc, Action<string> toast)
        {
            try
            {
                StringBuilder sb = new StringBuilder();
                sb.AppendLine("NysTrainer diagnostics  " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  plugin 1.2.2");
                if (pc == null) { sb.AppendLine("no player loaded"); File.WriteAllText(Path2(), sb.ToString()); toast("Diagnostics saved (no player)"); return; }
                Move_Block mv = pc.europaobjects.mover;
                sb.AppendLine("toggles: gates=" + State.GateGhost + " walls=" + State.BlockerGhost);
                sb.AppendLine("player pos=" + pc.transform.position.ToString("0.00") + " grounded=" + pc.isGrounded + " vel=" + pc.PlayerVelocity.ToString("0.00") + " canmove=" + pc.canmove + " unabletomove=" + pc.unabletomove + " dead=" + pc.dead);
                sb.AppendLine("mover: allowedLeft=" + mv.allowedtomoveleft + " allowedRight=" + mv.allowedtomoveright + " xmultiTotal=" + mv.xmultiTotal + " autopilot=" + mv.autopilot + " nearwallinslope=" + mv.nearwallinslope);
                List<Collider2D> player = GhostTools.PlayerSolids(pc);
                sb.AppendLine("player solid colliders: " + player.Count);
                foreach (Collider2D p in player) sb.AppendLine("   " + Path(p.transform) + " layer=" + LayerMask.LayerToName(p.gameObject.layer) + " bounds=" + p.bounds.center.ToString("0.00") + "/" + p.bounds.size.ToString("0.00"));

                sb.AppendLine();
                sb.AppendLine("== solid colliders touching / next to the player (3.0 x 2.0 box) ==");
                Collider2D main = pc.GetComponent<Collider2D>();
                Vector2 center = main != null ? (Vector2)main.bounds.center : (Vector2)pc.transform.position;
                Collider2D[] hits = Physics2D.OverlapBoxAll(center, new Vector2(3.0f, 2.0f), 0f);
                foreach (Collider2D c in hits)
                {
                    if (c == null || c.isTrigger || player.Contains(c)) continue;
                    sb.AppendLine("   " + Path(c.transform) + " | layer=" + LayerMask.LayerToName(c.gameObject.layer) + " tag=" + c.tag + " | " + c.GetType().Name + " enabled=" + c.enabled + " | comps=" + Comps(c.gameObject) + " | ignoredByPlayer=" + Ignored(player, c) + " dx=" + (c.bounds.center.x - center.x).ToString("0.00"));
                }
                sb.AppendLine("== trigger zones on the player (could set movement flags) ==");
                foreach (Collider2D c in hits)
                {
                    if (c == null || !c.isTrigger) continue;
                    NoMoveTrigger nm = c.GetComponent<NoMoveTrigger>();
                    if (nm != null) sb.AppendLine("   NoMoveTrigger " + Path(c.transform) + " isOn=" + nm.isOn + " inside=" + nm.inside + " ownerGateOpen=" + (nm.ownergate != null ? nm.ownergate.isOpen.ToString() : "null") + " isRight=" + nm.isright);
                }

                sb.AppendLine();
                sb.AppendLine("== nearest gates ==");
                List<KeyValuePair<float, GateController>> gs = new List<KeyValuePair<float, GateController>>();
                foreach (GateController g in UnityEngine.Object.FindObjectsOfType<GateController>())
                    if (g.gameObject.activeInHierarchy) gs.Add(new KeyValuePair<float, GateController>((g.transform.position - pc.transform.position).magnitude, g));
                gs.Sort(delegate (KeyValuePair<float, GateController> a, KeyValuePair<float, GateController> b) { return a.Key.CompareTo(b.Key); });
                for (int i = 0; i < gs.Count && i < 5; i++)
                {
                    GateController g = gs[i].Value;
                    sb.AppendLine("   dist=" + gs[i].Key.ToString("0.0") + " " + Path(g.transform) + " open=" + g.isOpen + " trapped=" + g.TrappedShut + " track=" + g.TrackingInfo.id);
                    foreach (Collider2D c in GhostTools.GateSolids(g))
                        sb.AppendLine("      col " + c.name + " layer=" + LayerMask.LayerToName(c.gameObject.layer) + " trigger=" + c.isTrigger + " enabled=" + c.enabled + " active=" + c.gameObject.activeInHierarchy + " ignoredByPlayer=" + Ignored(player, c));
                }
                sb.AppendLine();
                sb.AppendLine("== nearest door ramps (slope doors) ==");
                List<KeyValuePair<float, Ramp_LDTK>> rs = new List<KeyValuePair<float, Ramp_LDTK>>();
                foreach (Ramp_LDTK r in UnityEngine.Object.FindObjectsOfType<Ramp_LDTK>())
                    if (r._isDoor) rs.Add(new KeyValuePair<float, Ramp_LDTK>((r.transform.position - pc.transform.position).magnitude, r));
                rs.Sort(delegate (KeyValuePair<float, Ramp_LDTK> a, KeyValuePair<float, Ramp_LDTK> b) { return a.Key.CompareTo(b.Key); });
                for (int i = 0; i < rs.Count && i < 3; i++)
                    sb.AppendLine("   dist=" + rs[i].Key.ToString("0.0") + " " + Path(rs[i].Value.transform) + " fullyopen=" + rs[i].Value.fullyopen + " ownerGate=" + (rs[i].Value.ownergate != null ? rs[i].Value.ownergate.name + " open=" + rs[i].Value.ownergate.isOpen : "null"));
                if (rs.Count == 0) sb.AppendLine("   (none loaded)");
                sb.AppendLine();
                sb.AppendLine("== bosses / mid-bosses in the loaded rooms ==");
                int nb = 0;
                foreach (BossBase b in UnityEngine.Object.FindObjectsOfType<BossBase>()) { nb++; sb.AppendLine("   BossBase " + b.GetType().Name + " " + Path(b.transform) + " hp=" + b.CurrentHealth + "/" + b.MaxHealth + " alive=" + b.IsAlive + " defeatedTimes=" + b.NumberOfTimesDefeated + " active=" + b.gameObject.activeInHierarchy); }
                foreach (BossFramework b in UnityEngine.Object.FindObjectsOfType<BossFramework>()) { nb++; sb.AppendLine("   BossFramework " + b.GetType().Name + " " + Path(b.transform) + " hp=" + b.CurrentHealth + "/" + b.MaxHealth + " alive=" + b.IsAlive + " defeatedTimes=" + b.NumberOfTimesDefeated); }
                foreach (MidBossBase b in UnityEngine.Object.FindObjectsOfType<MidBossBase>()) { nb++; sb.AppendLine("   MidBoss " + b.GetType().Name + " " + Path(b.transform) + " hp=" + b.CurrentHealth + "/" + b.MaxHealth + " alive=" + b.IsAlive + " defeatedTimes=" + b.NumberOfTimesDefeated); }
                if (nb == 0) sb.AppendLine("   (none loaded)");
                try { sb.AppendLine("   timeScale=" + Time.timeScale + " paused=" + GameplayManager.Instance.UI.Pause.isPaused + " dialogueRunning=" + GameplayManager.Instance.UI.DialogueRunner.IsDialogueRunning + " playerKillInput=" + pc.playerblock.KILLINPUT + " artificiallyControlled=" + pc.playerblock.artificiallycontrolled + " cinemFrozen=" + mv.cinemfrozen + " OHK=" + State.OneHitKill + " OHKbosses=" + State.OhkBosses + " god=" + State.GodMode); } catch { }
                sb.AppendLine();
                sb.AppendLine("== nearest destructible blockers ==");
                List<KeyValuePair<float, DestructibleBlocker>> bs = new List<KeyValuePair<float, DestructibleBlocker>>();
                foreach (DestructibleBlocker b in UnityEngine.Object.FindObjectsOfType<DestructibleBlocker>())
                    if (b.gameObject.activeInHierarchy) bs.Add(new KeyValuePair<float, DestructibleBlocker>((b.transform.position - pc.transform.position).magnitude, b));
                bs.Sort(delegate (KeyValuePair<float, DestructibleBlocker> a, KeyValuePair<float, DestructibleBlocker> b) { return a.Key.CompareTo(b.Key); });
                for (int i = 0; i < bs.Count && i < 4; i++)
                {
                    sb.AppendLine("   dist=" + bs[i].Key.ToString("0.0") + " " + Path(bs[i].Value.transform) + " type=" + bs[i].Value.GetType().Name + " destroyed=" + bs[i].Value.Destroyed);
                    foreach (Collider2D c in GhostTools.BlockerSolids(bs[i].Value))
                        sb.AppendLine("      col " + c.name + " layer=" + LayerMask.LayerToName(c.gameObject.layer) + " trigger=" + c.isTrigger + " enabled=" + c.enabled + " ignoredByPlayer=" + Ignored(player, c));
                }
                File.WriteAllText(Path2(), sb.ToString());
                toast("Diagnostics saved: NysTrainer_diag.txt");
            }
            catch (Exception e) { toast("Diagnostics failed: " + e.Message); }
        }
        static string Path2() { return System.IO.Path.Combine(Paths.GameRootPath, "NysTrainer_diag.txt"); }
    }

    // Item database generated offline from the game's scene bundles (tools/nys/extract_items.py + make_items_tsv.py)
    // and embedded as a resource. One row per collectible item holder / armor altar in every area.
    public static class ItemDb
    {
        public class Row
        {
            public int Area; public string AreaName; public float Cx, Cy; public string Kind, TrackId, Label; public float Wx, Wy;
        }
        static List<Row> rows;

        public static List<Row> All()
        {
            if (rows != null) return rows;
            rows = new List<Row>();
            try
            {
                Assembly asm = typeof(ItemDb).Assembly;
                using (Stream st = asm.GetManifestResourceStream("NysTrainer.items.tsv"))
                {
                    if (st == null) { NysTrainerPlugin.Log("items.tsv resource missing"); return rows; }
                    using (StreamReader sr = new StreamReader(st, Encoding.UTF8))
                    {
                        string line;
                        while ((line = sr.ReadLine()) != null)
                        {
                            if (line.Length == 0 || line[0] == '#') continue;
                            string[] p = line.Split('\t');
                            if (p.Length < 9) continue;
                            Row r = new Row();
                            r.Area = int.Parse(p[0]); r.AreaName = p[1];
                            r.Cx = float.Parse(p[2], System.Globalization.CultureInfo.InvariantCulture);
                            r.Cy = float.Parse(p[3], System.Globalization.CultureInfo.InvariantCulture);
                            r.Kind = p[4]; r.TrackId = p[5]; r.Label = p[6];
                            r.Wx = float.Parse(p[7], System.Globalization.CultureInfo.InvariantCulture);
                            r.Wy = float.Parse(p[8], System.Globalization.CultureInfo.InvariantCulture);
                            rows.Add(r);
                        }
                    }
                }
            }
            catch (Exception e) { NysTrainerPlugin.Log("items.tsv load failed: " + e.Message); }
            return rows;
        }

        // Has the player already taken this item? Item holders are tracked by id (NumberOfTimesDefeated, saved in the session);
        // armor altars are gone once that element's armor is unlocked.
        public static bool Collected(Row r)
        {
            try
            {
                if (r.Kind.StartsWith("ArmorAltar:"))
                {
                    int el = int.Parse(r.Kind.Substring(11));
                    var u = PlayerController.Instance.Europa.ProgressionData.GetUnlocksFromElement((ConstantsManager.Gameplay.Element)el);
                    return u != null && u.ArmorUnlocked;
                }
                if (string.IsNullOrEmpty(r.TrackId)) return false;
                TrackedMonoBehaviour.TrackingData td = new TrackedMonoBehaviour.TrackingData();
                td.id = r.TrackId;
                td.objectType = TrackedMonoBehaviour.TrackingType.Interactable;
                TrackedMonoBehaviour live = TrackedMonoBehaviour.GetTrackedMonoBehaviourFromTrackingData(td);
                string s = live != null ? live.GetSaveData() : GameplayManager.Instance.SessionManager.CurrentSession.GetTrackedDataString(td);
                int n;
                return !string.IsNullOrEmpty(s) && int.TryParse(s, out n) && n > 0;
            }
            catch { return false; }
        }

        public static List<Row> Uncollected()
        {
            List<Row> l = new List<Row>();
            foreach (Row r in All()) if (!Collected(r)) l.Add(r);
            return l;
        }
    }

    public static class MapTools
    {
        static readonly FieldInfo fParent = AccessTools.Field(typeof(MapGeneratorUI), "mapCellParentTransform");
        static readonly FieldInfo fSpacing = AccessTools.Field(typeof(MapGeneratorUI), "gridSpacing");
        static readonly FieldInfo fSecret = AccessTools.Field(typeof(MapRoomInfo), "isSecretRoom");
        static readonly List<GameObject> markers = new List<GameObject>();

        static List<MapRoomInfo> SceneRooms()
        {
            List<MapRoomInfo> l = new List<MapRoomInfo>();
            foreach (MapRoomInfo r in Resources.FindObjectsOfTypeAll<MapRoomInfo>())
                if (r != null && r.gameObject.scene.IsValid()) l.Add(r);
            return l;
        }

        // Marks every not-yet-discovered cell as "Mapped" (secret rooms of loaded areas are left alone). Returns changed cells.
        public static int RevealAll()
        {
            HashSet<string> secret = new HashSet<string>();
            foreach (MapRoomInfo r in SceneRooms())
            {
                bool sec = false;
                try { sec = fSecret != null && (bool)fSecret.GetValue(r); } catch { }
                if (sec) { try { secret.Add(r.ComponentLevel.Identifier); } catch { } continue; }
                try { r.IsMapped(); } catch { }
            }
            List<MapGeneratorUI.MapCellInformation> recs = GameplayManager.Instance.SessionManager.CurrentSession.MapCellInformationRecords;
            int changed = 0;
            for (int i = 0; i < recs.Count; i++)
            {
                MapGeneratorUI.MapCellInformation c = recs[i];
                if (c.roomStatus != MapCellSpriteLibrary.RoomStatus.Undiscovered) continue;
                if (c.roomId != null && secret.Contains(c.roomId)) continue;
                c.roomStatus = MapCellSpriteLibrary.RoomStatus.Mapped;
                recs[i] = c;
                changed++;
            }
            return changed;
        }

        public static int CountUndiscovered()
        {
            int n = 0;
            foreach (MapGeneratorUI.MapCellInformation c in GameplayManager.Instance.SessionManager.CurrentSession.MapCellInformationRecords)
                if (c.roomStatus == MapCellSpriteLibrary.RoomStatus.Undiscovered) n++;
            return n;
        }

        public static void ClearMarkers()
        {
            foreach (GameObject g in markers) if (g != null) UnityEngine.Object.Destroy(g);
            markers.Clear();
        }

        static Color KindColor(string kind, out float scale)
        {
            scale = 1f;
            if (kind == "BlueNote") return new Color(0.35f, 0.55f, 1f, 1f);
            if (kind == "RedNote") return new Color(1f, 0.25f, 0.25f, 1f);
            if (kind == "ArmorPiece") return new Color(1f, 0.6f, 0.1f, 1f);
            if (kind == "MapPiece") return new Color(0.3f, 1f, 0.4f, 1f);
            if (kind == "Upgrade") { scale = 1.35f; return new Color(1f, 0.9f, 0.2f, 1f); }
            scale = 1.35f; return new Color(0.4f, 1f, 1f, 1f);   // armor altar
        }

        static GameObject Box(Transform parent, string name, float size, Color col)
        {
            GameObject g = new GameObject(name, typeof(RectTransform));
            g.transform.SetParent(parent, false);
            RectTransform rt = g.GetComponent<RectTransform>();
            rt.sizeDelta = new Vector2(size, size);
            rt.localRotation = Quaternion.Euler(0f, 0f, 45f);
            Image im = g.AddComponent<Image>();
            im.color = col;
            im.raycastTarget = false;
            return g;
        }

        // Draws a diamond for every uncollected item of every area on the pause map. Returns the number of markers.
        public static int BuildItemMarkers(MapGeneratorUI ui)
        {
            ClearMarkers();
            if (!State.ShowItems || ui == null) return 0;
            Transform parent = fParent != null ? (Transform)fParent.GetValue(ui) : null;
            if (parent == null) return 0;
            Vector2 spacing = fSpacing != null ? (Vector2)fSpacing.GetValue(ui) : new Vector2(20f, 12f);
            Vector2 grid = ui.GridOffset;
            float size = Mathf.Max(7f, Mathf.Min(spacing.x, spacing.y) * 0.5f);
            List<ItemDb.Row> todo = ItemDb.Uncollected();
            foreach (ItemDb.Row r in todo)
            {
                float fx = Mathf.Floor(r.Cx), fy = Mathf.Floor(r.Cy);
                Vector2 pos = new Vector2(fx * grid.x + (r.Cx - fx - 0.5f) * spacing.x, fy * grid.y + (r.Cy - fy - 0.5f) * spacing.y);
                float sc;
                Color col = KindColor(r.Kind.StartsWith("ArmorAltar") ? "Altar" : r.Kind, out sc);
                GameObject root = new GameObject("NysItemMarker", typeof(RectTransform));
                root.transform.SetParent(parent, false);
                root.GetComponent<RectTransform>().anchoredPosition = pos;
                Box(root.transform, "border", size * sc + 4f, Color.black);
                Box(root.transform, "fill", size * sc, col);
                root.transform.SetAsLastSibling();
                markers.Add(root);
                if (Environment.GetEnvironmentVariable("TRAINER_TRACE") == "1") NysTrainerPlugin.Log("MARKER " + r.AreaName + " " + r.Kind + " " + r.Label + " cell=(" + r.Cx.ToString("0.00") + "," + r.Cy.ToString("0.00") + ") anchored=" + pos.ToString("0.0"));
            }
            if (Environment.GetEnvironmentVariable("TRAINER_TRACE") == "1") { try { NysTrainerPlugin.Log("PLAYERMARK anchored=" + ui.europaMaker.anchoredPosition.ToString("0.0") + " areaOffset=" + ui.CurrentAreaOffset.ToString("0.00") + " grid=" + grid.ToString("0.0") + " spacing=" + spacing.ToString("0.0") + " playerWorld=" + PlayerController.Instance.transform.position.ToString("0.0")); } catch { } }
            NysTrainerPlugin.Log("Items on map: " + markers.Count + " of " + ItemDb.All().Count + " (rest already collected)");
            return markers.Count;
        }
    }
}






















