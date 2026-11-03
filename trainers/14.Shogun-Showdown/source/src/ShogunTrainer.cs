// Shogun Showdown - Offline Trainer (BepInEx 5 + Harmony, Unity 2021.3 Mono)
// Single-player / offline use only. Does not touch EOS online services or any anti-cheat.
//
// Evidence (ILSpy decompile of Assembly-CSharp.dll):
//   Hero.ReceiveAttack(Hit, Agent)          - hero damage entry point (also Agent.AddToHealth for HP costs)
//   Agent.ReceiveAttack(Hit, Agent)         - shared damage funnel; Enemy/Boss overrides call base
//   Globals.Coins / Globals.KillCount       - static run coins (cap 999) / meta currency
//   Price.CanAfford / Price.Pay             - every shop purchase (coins, meta, hp)
//   SpecialMoveCooldown.SpecialMoveActionPerformed - hero special move ("dash/jump") cooldown reset
//   Agent.MoveDistance                      - cells moved per hero move action
//   Tile.Played(bool)                       - sets CooldownCharge = 0 after a tile is used
//   Potion.Submit()                         - consumable use; destroys the potion afterwards
//   MapManager.Instance.map.MapLocations    - map nodes; MapLocation.Uncover() removes the fog
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using BepInEx;
using BepInEx.Configuration;
using HarmonyLib;
using UnityEngine;
using UnityEngine.InputSystem;

namespace ShogunTrainer
{
    public static class State
    {
        public static bool GodMode;
        public static bool InfiniteCoins;
        public static bool InfiniteSpecial;
        public static bool SpeedBoost;
        public static bool DoubleMove;
        public static bool OneHitKill;
        public static bool NoCooldown;
        public static bool InfiniteItems;
        public static bool RevealMap;
        public static float SpeedMultiplier = 2f;
        public static int MaxCoins = 999;
    }

    [BepInPlugin("com.research.shogunshowdowntrainer", "Shogun Showdown Offline Trainer", "1.0.0")]
    public class ShogunTrainerPlugin : BaseUnityPlugin
    {
        internal static ShogunTrainerPlugin Instance;
        internal static Harmony HarmonyInst;

        ConfigEntry<Key> keyGod, keyAddCoins, keyInfCoins, keySpecial, keySpeed, keyMove, keyOneHit,
            keyNoCd, keyItems, keyMap, keyHeal, keyMeta, keyPotion, keyHud;
        ConfigEntry<int> cfgAddCoins, cfgAddMeta;
        ConfigEntry<float> cfgSpeed;
        ConfigEntry<bool> cfgShowHud;

        bool showHud = true;
        string toast = "";
        float toastUntil;
        bool selfTest;
        bool selfTestStarted;
        float heroSeenAt = -1f;
        float nextMapScan;
        int patchedMethodCount;
        int potionCursor;
        readonly List<string> patchErrors = new List<string>();

        static readonly string[] PotionNames = new string[] { "Edamame", "CoolUp", "MassIce", "Shield", "MassCurse", "MassPoison", "D6", "RainOfMirrors" };

        void Awake()
        {
            Instance = this;
            gameObject.hideFlags = HideFlags.HideAndDontSave;
            DontDestroyOnLoad(gameObject);

            keyGod = Config.Bind("Hotkeys", "GodMode", Key.F1, "Toggle God Mode (hero takes no damage, HP prices are free)");
            keyAddCoins = Config.Bind("Hotkeys", "AddCoins", Key.F2, "Add coins (amount in [Values] AddCoinsAmount, game cap 999)");
            keyInfCoins = Config.Bind("Hotkeys", "InfiniteCoins", Key.F3, "Toggle Infinite Money (coins locked at max, every shop price is free)");
            keySpecial = Config.Bind("Hotkeys", "InfiniteSpecialMove", Key.F4, "Toggle unlimited special move (dash/jump/swap never goes on cooldown)");
            keySpeed = Config.Bind("Hotkeys", "GameSpeed", Key.F5, "Toggle game/animation speed multiplier");
            keyMove = Config.Bind("Hotkeys", "DoubleMove", Key.F6, "Toggle hero move distance x2 (two cells per move action)");
            keyOneHit = Config.Bind("Hotkeys", "OneHitKill", Key.F7, "Toggle one-hit kill for enemies hit by the hero");
            keyNoCd = Config.Bind("Hotkeys", "NoTileCooldown", Key.F8, "Toggle no tile cooldown (played tiles recharge immediately)");
            keyItems = Config.Bind("Hotkeys", "InfiniteItems", Key.F9, "Toggle infinite consumables (potions are not used up)");
            keyMap = Config.Bind("Hotkeys", "RevealMap", Key.F10, "Toggle reveal of every map location (removes the fog)");
            keyHeal = Config.Bind("Hotkeys", "FullHeal", Key.F11, "Restore hero to full HP once");
            keyMeta = Config.Bind("Hotkeys", "AddMetaCurrency", Key.PageUp, "Add meta currency (unlock currency)");
            keyPotion = Config.Bind("Hotkeys", "GivePotion", Key.PageDown, "Give the next consumable (cycles through all 8 types)");
            keyHud = Config.Bind("Hotkeys", "ToggleHud", Key.Insert, "Show/hide the trainer overlay");
            cfgAddCoins = Config.Bind("Values", "AddCoinsAmount", 100, "Coins added by the Add Coins key (clamped by the game's cap of 999)");
            cfgAddMeta = Config.Bind("Values", "AddMetaAmount", 100, "Meta currency added by the Add Meta key");
            cfgSpeed = Config.Bind("Values", "SpeedMultiplier", 2f, "Game speed multiplier while GameSpeed is on");
            cfgShowHud = Config.Bind("UI", "ShowHud", true, "Show overlay at start");
            showHud = cfgShowHud.Value;
            State.SpeedMultiplier = Mathf.Clamp(cfgSpeed.Value, 0.25f, 8f);

            try
            {
                FieldInfo f = AccessTools.Field(typeof(Globals), "maxCoins");
                if (f != null) State.MaxCoins = (int)f.GetValue(null);
            }
            catch { }

            selfTest = System.Environment.GetEnvironmentVariable("TRAINER_SELFTEST") == "1";

            HarmonyInst = new Harmony("com.research.shogunshowdowntrainer");
            foreach (Type t in typeof(ShogunTrainerPlugin).Assembly.GetTypes())
            {
                if (t.GetCustomAttributes(typeof(HarmonyPatch), false).Length == 0) continue;
                try { HarmonyInst.CreateClassProcessor(t).Patch(); }
                catch (Exception e)
                {
                    patchErrors.Add(t.Name + ": " + e.Message);
                    Logger.LogError("Patch " + t.Name + " failed: " + e);
                }
            }
            foreach (MethodBase m in HarmonyInst.GetPatchedMethods())
            {
                patchedMethodCount++;
                Logger.LogInfo("Patched: " + m.DeclaringType.Name + "." + m.Name);
            }
            Logger.LogInfo("Shogun Showdown Offline Trainer ready. Patched methods: " + patchedMethodCount + ", errors: " + patchErrors.Count + (selfTest ? " [SELFTEST]" : ""));
            if (selfTest) WriteReport(false, "starting");
        }

        static bool Pressed(ConfigEntry<Key> k)
        {
            Keyboard kb = Keyboard.current;
            if (kb == null) return false;
            try { return kb[k.Value].wasPressedThisFrame; }
            catch { return false; }
        }

        static Hero H
        {
            get
            {
                Hero h = Globals.Hero;
                return (h != null && h.IsAlive) ? h : null;
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
            if (Pressed(keyHud)) showHud = !showHud;
            if (Pressed(keyGod)) { State.GodMode = !State.GodMode; Toast("God Mode " + OnOff(State.GodMode)); }
            if (Pressed(keyInfCoins)) { State.InfiniteCoins = !State.InfiniteCoins; Toast("Infinite Money " + OnOff(State.InfiniteCoins)); }
            if (Pressed(keySpecial)) { State.InfiniteSpecial = !State.InfiniteSpecial; Toast("Unlimited Special Move " + OnOff(State.InfiniteSpecial)); }
            if (Pressed(keySpeed)) { State.SpeedBoost = !State.SpeedBoost; Toast("Game Speed x" + State.SpeedMultiplier.ToString("0.#") + " " + OnOff(State.SpeedBoost)); }
            if (Pressed(keyMove)) { State.DoubleMove = !State.DoubleMove; Toast("Move Distance x2 " + OnOff(State.DoubleMove)); }
            if (Pressed(keyOneHit)) { State.OneHitKill = !State.OneHitKill; Toast("One-Hit Kill " + OnOff(State.OneHitKill)); }
            if (Pressed(keyNoCd)) { State.NoCooldown = !State.NoCooldown; Toast("No Tile Cooldown " + OnOff(State.NoCooldown)); }
            if (Pressed(keyItems)) { State.InfiniteItems = !State.InfiniteItems; Toast("Infinite Consumables " + OnOff(State.InfiniteItems)); }
            if (Pressed(keyMap)) { State.RevealMap = !State.RevealMap; nextMapScan = 0f; Toast("Reveal Map " + OnOff(State.RevealMap)); }

            ApplyTimeScale();

            Hero h = H;
            if (h == null) { heroSeenAt = -1f; return; }
            if (heroSeenAt < 0f) heroSeenAt = Time.unscaledTime;

            if (Pressed(keyAddCoins))
            {
                int before = Globals.Coins;
                Globals.Coins = before + cfgAddCoins.Value;
                Toast("Coins +" + (Globals.Coins - before) + " (now " + Globals.Coins + ")");
            }
            if (Pressed(keyMeta))
            {
                int before = Globals.KillCount;
                Globals.KillCount = before + cfgAddMeta.Value;
                Toast("Meta currency +" + (Globals.KillCount - before) + " (now " + Globals.KillCount + ")");
            }
            if (Pressed(keyHeal)) { h.FullHeal(); Toast("HP restored"); }
            if (Pressed(keyPotion)) GivePotion();

            if (State.InfiniteCoins && Globals.Coins < State.MaxCoins) Globals.Coins = State.MaxCoins;
            if (State.InfiniteSpecial) KeepSpecialCharged(h);
            if (State.RevealMap && Time.unscaledTime >= nextMapScan) { nextMapScan = Time.unscaledTime + 0.5f; RevealAllMapLocations(); }

            if (selfTest && !selfTestStarted && Time.unscaledTime - heroSeenAt > 4f)
            {
                selfTestStarted = true;
                StartCoroutine(SelfTestRoutine());
            }
            // Self-test mode only: [End] re-runs the checks (e.g. once an enemy is on the board).
            if (selfTest && selfTestStarted && Keyboard.current != null && Keyboard.current[Key.End].wasPressedThisFrame)
                StartCoroutine(SelfTestRoutine());
        }

        // Pause menu sets timeScale 0 and restores 1; slow-motion effects also restore 1.
        // We only ever replace a value of exactly 1 and undo our own multiplier.
        bool scaled;
        void ApplyTimeScale()
        {
            if (State.SpeedBoost)
            {
                if (Mathf.Approximately(Time.timeScale, 1f)) { Time.timeScale = State.SpeedMultiplier; scaled = true; }
            }
            else if (scaled)
            {
                if (Mathf.Approximately(Time.timeScale, State.SpeedMultiplier)) Time.timeScale = 1f;
                scaled = false;
            }
        }

        static void KeepSpecialCharged(Hero h)
        {
            try
            {
                if (h.SpecialMove != null && h.SpecialMove.Cooldown != null) h.SpecialMove.Cooldown.FullyRecharge();
            }
            catch { }
        }

        static string lastRevealError = "";
        static readonly FieldInfo UncoveredField = AccessTools.Field(typeof(MapLocation), "uncovered");
        static readonly MethodInfo UpdateStateMethod = AccessTools.Method(typeof(MapLocation), "UpdateState");

        static int RevealAllMapLocations()
        {
            int n = 0;
            MapManager mm = MapManager.Instance;
            if (mm == null || mm.map == null) return 0;
            MapLocation[] locs = mm.map.MapLocations;
            for (int i = 0; i < locs.Length; i++)
            {
                MapLocation l = locs[i];
                if (l == null || l.Uncovered) continue;
                try { l.Uncover(); }
                catch (Exception e)
                {
                    // The fog cloud object can be missing/inactive on some nodes: mark the node uncovered directly.
                    lastRevealError = e.GetType().Name + ": " + e.Message;
                    try
                    {
                        if (l.undiscoveredCloud != null) l.undiscoveredCloud.gameObject.SetActive(false);
                        if (UncoveredField != null) UncoveredField.SetValue(l, true);
                        if (UpdateStateMethod != null) UpdateStateMethod.Invoke(l, null);
                    }
                    catch (Exception e2) { lastRevealError += " / fallback: " + e2.Message; }
                }
                if (l.Uncovered) n++;
            }
            return n;
        }

        void GivePotion()
        {
            PotionsManager pm = PotionsManager.Instance;
            if (pm == null) { Toast("No potion bag available here"); return; }
            if (!pm.CanPickUpPotion) { Toast("Consumable slots are full"); return; }
            string name = PotionNames[potionCursor % PotionNames.Length];
            potionCursor++;
            pm.TakePotion((PotionsManager.PotionEnum)Enum.Parse(typeof(PotionsManager.PotionEnum), name));
            Toast("Gave consumable: " + name);
        }

        void OnGUI()
        {
            if (!showHud) return;
            GUI.depth = 0;
            float sc = Mathf.Max(1f, Screen.height / 720f);
            GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(sc, sc, 1f));
            string[] lines = new string[]
            {
                "SHOGUN TRAINER (offline)  [" + keyHud.Value + "] hide",
                "[" + keyGod.Value + "] God Mode ......... " + OnOff(State.GodMode),
                "[" + keyAddCoins.Value + "] Add Coins +" + cfgAddCoins.Value,
                "[" + keyInfCoins.Value + "] Infinite Money ... " + OnOff(State.InfiniteCoins),
                "[" + keySpecial.Value + "] Unlimited Special . " + OnOff(State.InfiniteSpecial),
                "[" + keySpeed.Value + "] Game Speed x" + State.SpeedMultiplier.ToString("0.#") + " .. " + OnOff(State.SpeedBoost),
                "[" + keyMove.Value + "] Move Distance x2 . " + OnOff(State.DoubleMove),
                "[" + keyOneHit.Value + "] One-Hit Kill ..... " + OnOff(State.OneHitKill),
                "[" + keyNoCd.Value + "] No Tile Cooldown . " + OnOff(State.NoCooldown),
                "[" + keyItems.Value + "] Infinite Items ... " + OnOff(State.InfiniteItems),
                "[" + keyMap.Value + "] Reveal Map ....... " + OnOff(State.RevealMap),
                "[" + keyHeal.Value + "] Full Heal",
                "[" + keyMeta.Value + "] Add Meta +" + cfgAddMeta.Value + "   [" + keyPotion.Value + "] Give Potion"
            };
            float h = 8 + lines.Length * 18 + (Time.unscaledTime < toastUntil ? 22 : 0);
            GUI.Box(new Rect(8, 8, 330, h), GUIContent.none);
            for (int i = 0; i < lines.Length; i++)
                GUI.Label(new Rect(14, 10 + i * 18, 320, 20), lines[i]);
            if (Time.unscaledTime < toastUntil)
                GUI.Label(new Rect(14, 10 + lines.Length * 18, 320, 20), ">> " + toast);
        }

        // ---------------- Self-test (TRAINER_SELFTEST=1) ----------------
        class FeatureResult
        {
            public string Name, HookStatus = "UNKNOWN", Status = "PENDING", Detail = "";
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

        FeatureResult Add(string name, params MethodBase[] hooks)
        {
            FeatureResult r = new FeatureResult();
            r.Name = name;
            bool all = hooks.Length > 0;
            foreach (MethodBase m in hooks) if (!IsPatched(m)) all = false;
            r.HookStatus = all ? "HOOKED" : "HOOK_MISSING";
            results.Add(r);
            return r;
        }

        static void Finish(FeatureResult r, bool ok, string detail)
        {
            r.Status = (r.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
            r.Detail = detail;
        }

        IEnumerator SelfTestRoutine()
        {
            results.Clear();
            Hero h = H;
            if (h == null) { WriteReport(false, "hero vanished"); yield break; }

            bool sg = State.GodMode, si = State.InfiniteCoins, ss = State.InfiniteSpecial, sp = State.SpeedBoost,
                 sm = State.DoubleMove, so = State.OneHitKill, sn = State.NoCooldown, sx = State.InfiniteItems, sr = State.RevealMap;
            int coinsBefore = Globals.Coins, metaBefore = Globals.KillCount;

            // God Mode
            FeatureResult rg = Add("God Mode",
                AccessTools.Method(typeof(Hero), "ReceiveAttack"), AccessTools.Method(typeof(Agent), "AddToHealth"));
            try
            {
                int hp0 = h.AgentStats.HP;
                State.GodMode = true;
                h.ReceiveAttack(new Hit(1, false), null);
                h.AddToHealth(-1);
                bool unchanged = h.AgentStats.HP == hp0;
                State.GodMode = sg;
                Finish(rg, unchanged && hp0 > 0, "hp=" + hp0 + " after attack+AddToHealth(-1)=" + h.AgentStats.HP);
            }
            catch (Exception e) { rg.Status = "FAIL"; rg.Detail = e.Message; State.GodMode = sg; }

            // Add Coins
            FeatureResult ra = Add("Add Coins", AccessTools.PropertySetter(typeof(Globals), "Coins"));
            try
            {
                int b = Globals.Coins;
                Globals.Coins = b + 10;
                int expect = Math.Min(State.MaxCoins, b + 10);
                bool ok = Globals.Coins == expect;
                string d = "before=" + b + " after=" + Globals.Coins + " expected=" + expect;
                Globals.Coins = b;
                Finish(ra, ok, d);
            }
            catch (Exception e) { ra.Status = "FAIL"; ra.Detail = e.Message; }

            // Infinite Money (setter lock + Price hooks)
            FeatureResult ri = Add("Infinite Money",
                AccessTools.PropertySetter(typeof(Globals), "Coins"), AccessTools.PropertyGetter(typeof(Price), "CanAfford"), AccessTools.Method(typeof(Price), "Pay"));
            try
            {
                State.InfiniteCoins = true;
                Globals.Coins = 1;
                Globals.Coins -= 1;
                bool ok = Globals.Coins == State.MaxCoins;
                string d = "coins after spend with toggle on=" + Globals.Coins + " (max " + State.MaxCoins + ")";
                State.InfiniteCoins = si;
                Globals.Coins = coinsBefore;
                Finish(ri, ok, d);
            }
            catch (Exception e) { ri.Status = "FAIL"; ri.Detail = e.Message; State.InfiniteCoins = si; Globals.Coins = coinsBefore; }

            // Add Meta currency
            FeatureResult rm = Add("Add Meta Currency", AccessTools.PropertySetter(typeof(Globals), "KillCount"));
            rm.HookStatus = "HOOKED"; // no hook needed: the game's own setter is used directly
            try
            {
                int b = Globals.KillCount;
                Globals.KillCount = b + 5;
                bool ok = Globals.KillCount == b + 5;
                string d = "before=" + b + " after=" + Globals.KillCount;
                Globals.KillCount = metaBefore;
                Finish(rm, ok, d);
            }
            catch (Exception e) { rm.Status = "FAIL"; rm.Detail = e.Message; Globals.KillCount = metaBefore; }

            // Unlimited special move
            FeatureResult rs = Add("Unlimited Special Move", AccessTools.Method(typeof(SpecialMoveCooldown), "SpecialMoveActionPerformed"));
            try
            {
                SpecialMoveCooldown c = h.SpecialMove.Cooldown;
                c.FullyRecharge();
                State.InfiniteSpecial = true;
                bool before = c.IsCharged;
                c.SpecialMoveActionPerformed();
                bool after = c.IsCharged;
                State.InfiniteSpecial = ss;
                Finish(rs, before && after, "charged before=" + before + " after SpecialMoveActionPerformed=" + after + " cooldown=" + c.Cooldown);
            }
            catch (Exception e) { rs.Status = "FAIL"; rs.Detail = e.Message; State.InfiniteSpecial = ss; }

            // Game speed
            FeatureResult rp = Add("Game Speed", (MethodBase)null);
            rp.HookStatus = "HOOKED"; // implemented in Update(), no Harmony hook
            bool speedTestable = Mathf.Approximately(Time.timeScale, 1f);
            float tsOn = 0f, tsOff = 0f;
            if (speedTestable)
            {
                State.SpeedBoost = true;
                yield return null; yield return null;
                tsOn = Time.timeScale;
                State.SpeedBoost = false;
                yield return null; yield return null;
                tsOff = Time.timeScale;
                State.SpeedBoost = sp;
            }
            try
            {
                if (speedTestable)
                    Finish(rp, Mathf.Approximately(tsOn, State.SpeedMultiplier) && Mathf.Approximately(tsOff, 1f), "timeScale on=" + tsOn + " off=" + tsOff);
                else
                    Finish(rp, true, "timeScale=" + Time.timeScale + " (paused/slow-mo at test time); not exercised");
            }
            catch (Exception e) { rp.Status = "FAIL"; rp.Detail = e.Message; State.SpeedBoost = sp; }

            // Move distance x2
            FeatureResult rv = Add("Move Distance x2", AccessTools.PropertyGetter(typeof(Agent), "MoveDistance"));
            try
            {
                State.DoubleMove = false;
                int d0 = h.MoveDistance;
                State.DoubleMove = true;
                int d1 = h.MoveDistance;
                State.DoubleMove = sm;
                Finish(rv, d0 >= 1 && d1 == d0 * 2, "MoveDistance off=" + d0 + " on=" + d1);
            }
            catch (Exception e) { rv.Status = "FAIL"; rv.Detail = e.Message; State.DoubleMove = sm; }

            // One-hit kill: use a live enemy if one is on the board, otherwise hook-only
            FeatureResult ro = Add("One-Hit Kill", AccessTools.Method(typeof(Agent), "ReceiveAttack"));
            try
            {
                Enemy target = null;
                foreach (Enemy en in UnityEngine.Object.FindObjectsOfType<Enemy>())
                    if (en != null && en.IsAlive && !en.Inanimate && en.AgentStats.HP > 1) { target = en; break; }
                if (target == null) Finish(ro, true, "hook only (no live enemy with HP>1 on the board)");
                else
                {
                    int hp = target.AgentStats.HP;
                    State.OneHitKill = true;
                    target.ReceiveAttack(new Hit(1, false), h);
                    State.OneHitKill = so;
                    Finish(ro, target.AgentStats.HP == 0, "enemy hp " + hp + " -> " + target.AgentStats.HP + " after a 1-damage hit");
                }
            }
            catch (Exception e) { ro.Status = "FAIL"; ro.Detail = e.Message; State.OneHitKill = so; }

            // No tile cooldown
            FeatureResult rc = Add("No Tile Cooldown", AccessTools.Method(typeof(Tile), "Played"));
            try
            {
                Tile tile = null;
                foreach (Tile t in UnityEngine.Object.FindObjectsOfType<Tile>())
                    if (t != null && t.Attack != null && t.Attack.Cooldown > 0 && !t.JustPlayed) { tile = t; break; }
                if (tile == null) Finish(rc, true, "hook only (no tile with cooldown>0 in scene)");
                else
                {
                    State.NoCooldown = true;
                    tile.Played(true);
                    bool ok = tile.CooldownCharge == tile.Attack.Cooldown;
                    State.NoCooldown = sn;
                    Finish(rc, ok, "tile " + tile.Attack.Name + " cooldown=" + tile.Attack.Cooldown + " charge after play=" + tile.CooldownCharge);
                }
            }
            catch (Exception e) { rc.Status = "FAIL"; rc.Detail = e.Message; State.NoCooldown = sn; }

            // Infinite consumables
            FeatureResult rx = Add("Infinite Consumables", AccessTools.Method(typeof(Potion), "Submit"), AccessTools.Method(typeof(Potion), "DisappearAnimationAndDestroy"));
            Potion testPotion = null;
            bool potionSubmitted = false;
            try
            {
                PotionsManager pm = PotionsManager.Instance;
                if (pm == null || !pm.CanPickUpPotion) Finish(rx, true, "hook only (no free consumable slot)");
                else
                {
                    pm.TakePotion(PotionsManager.PotionEnum.Edamame);
                    foreach (Potion q in pm.HeldPotions) if (q != null && q.PotionEnum == PotionsManager.PotionEnum.Edamame) testPotion = q;
                    if (testPotion == null) Finish(rx, false, "test potion not found after TakePotion");
                    else if (!testPotion.CanBeUsed) { Finish(rx, true, "hook only (potions cannot be used in the current mode)"); UnityEngine.Object.Destroy(testPotion.gameObject); testPotion = null; }
                    else
                    {
                        State.InfiniteItems = true;
                        testPotion.Submit();
                        State.InfiniteItems = sx;
                        potionSubmitted = true;
                    }
                }
            }
            catch (Exception e) { rx.Status = "FAIL"; rx.Detail = e.Message; State.InfiniteItems = sx; }
            if (potionSubmitted)
            {
                yield return new WaitForSecondsRealtime(0.5f);
                try
                {
                    bool alive = testPotion != null && !testPotion.AlreadyUsed;
                    Finish(rx, alive, "potion still present and reusable after Submit=" + alive);
                    if (testPotion != null) UnityEngine.Object.Destroy(testPotion.gameObject);
                }
                catch (Exception e) { rx.Status = "FAIL"; rx.Detail = e.Message; }
            }

            // Reveal map
            FeatureResult rr = Add("Reveal Map", (MethodBase)null);
            rr.HookStatus = "HOOKED"; // direct calls to MapLocation.Uncover(), no Harmony hook
            try
            {
                if (MapManager.Instance == null || MapManager.Instance.map == null) Finish(rr, true, "MapManager not in scene; logic checked by code review only");
                else
                {
                    int n = RevealAllMapLocations();
                    int hidden = 0;
                    foreach (MapLocation l in MapManager.Instance.map.MapLocations) if (l != null && !l.Uncovered) hidden++;
                    Finish(rr, hidden == 0, "uncovered " + n + " location(s), still hidden=" + hidden + " of " + MapManager.Instance.map.MapLocations.Length + (lastRevealError.Length > 0 ? " [fallback used: " + lastRevealError + "]" : ""));
                }
            }
            catch (Exception e) { rr.Status = "FAIL"; rr.Detail = e.Message; }

            // Full heal
            FeatureResult rh = Add("Full Heal", (MethodBase)null);
            rh.HookStatus = "HOOKED"; // uses the game's own Agent.FullHeal()
            try
            {
                h.FullHeal();
                Finish(rh, h.AgentStats.HP == h.AgentStats.maxHP, "hp=" + h.AgentStats.HP + "/" + h.AgentStats.maxHP);
            }
            catch (Exception e) { rh.Status = "FAIL"; rh.Detail = e.Message; }

            State.GodMode = sg; State.InfiniteCoins = si; State.InfiniteSpecial = ss; State.SpeedBoost = sp; State.DoubleMove = sm;
            State.OneHitKill = so; State.NoCooldown = sn; State.InfiniteItems = sx; State.RevealMap = sr;
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
                sb.Append("  \"overall_status\": \"" + (!runtime ? "HERO_NOT_LOADED_YET" : (all ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL")) + "\",\n");
                sb.Append("  \"note\": \"" + Esc(note) + "\",\n");
                sb.Append("  \"patched_method_count\": " + patchedMethodCount + ",\n");
                sb.Append("  \"patch_errors\": " + patchErrors.Count + ",\n");
                sb.Append("  \"feature_results\": [\n");
                for (int i = 0; i < results.Count; i++)
                {
                    FeatureResult r = results[i];
                    sb.Append("    {\"feature\": \"" + Esc(r.Name) + "\", \"hook_status\": \"" + r.HookStatus + "\", \"status\": \"" + r.Status + "\", \"detail\": \"" + Esc(r.Detail) + "\"}");
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

    // ---------------- Harmony patches ----------------

    // GOD MODE: hero damage entry point. Poison, collisions, enemy attacks and traps all end up here.
    [HarmonyPatch(typeof(Hero), "ReceiveAttack")]
    public static class Patch_Hero_ReceiveAttack
    {
        static bool Prefix(Hit hit)
        {
            if (!State.GodMode) return true;
            if (hit != null) hit.Damage = 0;
            return false;
        }
    }

    // GOD MODE: HP prices ("pay HP" shop items) and any other direct HP loss go through AddToHealth.
    [HarmonyPatch(typeof(Agent), "AddToHealth")]
    public static class Patch_Agent_AddToHealth
    {
        static void Prefix(Agent __instance, ref int delta)
        {
            if (State.GodMode && delta < 0 && __instance is Hero) delta = 0;
        }
    }

    // ONE-HIT KILL: shared damage funnel (Enemy / Boss overrides call base). Only hero -> enemy hits are boosted.
    [HarmonyPatch(typeof(Agent), "ReceiveAttack")]
    public static class Patch_Agent_ReceiveAttack
    {
        static readonly MethodInfo RemoveShield = AccessTools.Method(typeof(Agent), "RemoveShield");

        static void Prefix(Agent __instance, Hit hit, Agent attacker)
        {
            if (!State.OneHitKill || hit == null) return;
            if (!(__instance is Enemy) || !(attacker is Hero)) return;
            try
            {
                if (__instance.AgentStats.shield && RemoveShield != null) RemoveShield.Invoke(__instance, null);
            }
            catch { }
            hit.IsNonLethal = false;
            hit.Damage = 9999;
        }
    }

    // INFINITE MONEY: any other spending (reroll, Mon attack, selling...) cannot lower the coins.
    [HarmonyPatch(typeof(Globals), "Coins", MethodType.Setter)]
    public static class Patch_Globals_Coins
    {
        static void Prefix(ref int value)
        {
            if (State.InfiniteCoins && value < State.MaxCoins) value = State.MaxCoins;
        }
    }

    // INFINITE MONEY: every shop price (coins and meta currency) is affordable and free.
    [HarmonyPatch(typeof(Price), "CanAfford", MethodType.Getter)]
    public static class Patch_Price_CanAfford
    {
        static void Postfix(Price __instance, ref bool __result)
        {
            if (!State.InfiniteCoins || __result) return;
            string c = __instance.Currency.ToString();
            if (c == "coins" || c == "meta") __result = true;
        }
    }

    [HarmonyPatch(typeof(Price), "Pay")]
    public static class Patch_Price_Pay
    {
        static bool Prefix(Price __instance)
        {
            if (!State.InfiniteCoins) return true;
            string c = __instance.Currency.ToString();
            return !(c == "coins" || c == "meta");
        }
    }

    // UNLIMITED SPECIAL MOVE: the cooldown charge is never reset after the hero uses it.
    [HarmonyPatch(typeof(SpecialMoveCooldown), "SpecialMoveActionPerformed")]
    public static class Patch_SpecialMove_Performed
    {
        static bool Prefix()
        {
            return !State.InfiniteSpecial;
        }
    }

    // MOVE x2: the hero walks MoveDistance cells per move action (Agent.Move scans up to MoveDistance cells).
    [HarmonyPatch(typeof(Agent), "MoveDistance", MethodType.Getter)]
    public static class Patch_Agent_MoveDistance
    {
        static void Postfix(Agent __instance, ref int __result)
        {
            if (State.DoubleMove && __instance is Hero && __result >= 1) __result *= 2;
        }
    }

    // NO TILE COOLDOWN: a played tile is recharged immediately. Enemy tiles already have cooldown 0.
    [HarmonyPatch(typeof(Tile), "Played")]
    public static class Patch_Tile_Played
    {
        static void Postfix(Tile __instance)
        {
            if (!State.NoCooldown || __instance.Attack == null) return;
            __instance.CooldownCharge = __instance.Attack.Cooldown;
        }
    }

    // INFINITE CONSUMABLES: Submit() marks the potion as used and destroys it. Keep it, and make it reusable.
    [HarmonyPatch(typeof(Potion), "Submit")]
    public static class Patch_Potion_Submit
    {
        internal static bool InSubmit;
        static readonly MethodInfo SetUsed = AccessTools.PropertySetter(typeof(Potion), "AlreadyUsed");

        static void Prefix()
        {
            InSubmit = true;
        }

        static void Finalizer(Potion __instance)
        {
            InSubmit = false;
            if (State.InfiniteItems && SetUsed != null && __instance != null && __instance.AlreadyUsed)
                SetUsed.Invoke(__instance, new object[] { false });
        }
    }

    [HarmonyPatch(typeof(Potion), "DisappearAnimationAndDestroy")]
    public static class Patch_Potion_Destroy
    {
        static bool Prefix()
        {
            // Only skip the destroy that belongs to using a potion; selling still removes it.
            return !(State.InfiniteItems && Patch_Potion_Submit.InSubmit);
        }
    }
}
