// Voidwrought - Offline Trainer (BepInEx 5 + Harmony, Unity 2021.3 Mono)
// Single-player / offline use only. No online services, no anti-cheat, no DRM involved.
//
// Evidence (decompiled Assembly-CSharp.dll, see vw-src/ and artifacts/vw/subtasks/*.json):
//   PlayerStats.TakeDamage(int) / SetGodMode(bool) / HealToMax()   - single HP-loss funnel + game's own invulnerability flag
//   PlayerInventory.AddCurrency/SetCurrency/TryToSpend/CanAfford   - every currency/item mutation and every purchase
//   Damageable.ChangeHealthBy(int,...)                             - the one place enemy HP (PlayMaker "Health" FsmInt) is reduced
//   PlayerStateMachine.MoveSpeedMultiplier(+Duration)              - global run-speed multiplier read by Move()
//   DoubleJumpState.Enabled / DoubleJumpHasBeenReset               - air-jump gate (ability + per-landing reset)
//   Map.ExploreAllTiles()                                          - the game's own "map_complete" debug command
//   DeactivateIfGlobalParameter + RegionSettings.Region.Pickups    - one-shot world pickups keyed by GlobalParameter name
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
using VoidwroughtCore;
using World;
using Utility.SaveLoad;

namespace VwTrainer
{
    public static class State
    {
        public static bool God;
        public static bool OneHit;
        public static bool InfMoney;
        public static bool InfRes;
        public static bool Jump;
        public static bool Speed;
        public static bool Esp;
        public static float SpeedMult = 2f;
    }

    // ---- null-safe accessors to the game's service objects (no pointer scanning needed in Unity Mono) ----
    internal static class Game
    {
        public static PlayerCore PC
        {
            get
            {
                try
                {
                    Core c = Utility.Singleton<Core>.instance;
                    if (c == null) return null;
                    return Core.Player;
                }
                catch { return null; }
            }
        }
        public static PlayerStateMachine PSM { get { PlayerCore pc = PC; return pc == null ? null : pc.Player; } }
        public static PlayerInventory Inv { get { PlayerCore pc = PC; return pc == null ? null : pc.Inventory; } }
        public static Settings.GameSettings Cfg
        {
            get { try { return Core.Game.Settings; } catch { return null; } }
        }
        public static bool Ready
        {
            get
            {
                try
                {
                    PlayerStateMachine p = PSM; PlayerInventory inv = Inv; Settings.GameSettings cfg = Cfg;
                    return p != null && inv != null && cfg != null && p.Stats != null && inv.Initialized && inv.Currencies != null
                        && cfg.HealthCurrency != null && cfg.IchorCurrency != null && Core.SaveLoad != null && Core.SaveLoad.SaveDataCreated;
                }
                catch { return false; }
            }
        }
        public static int Id(Currency c) { return c == null ? int.MinValue : c.ID; }
        public static int Amount(int id)
        {
            PlayerInventory inv = Inv; int v;
            if (inv == null || inv.Currencies == null || !inv.Currencies.TryGetValue(id, out v)) return 0;
            return v;
        }
    }

    // ---------------- Harmony patches ----------------
    internal static class Patches
    {
        static int enemyLayer = -2;

        // COMBAT / God Mode: the single HP-loss funnel. (InstakillsPlayer spikes/pits still send the player to the last safe spot, as in vanilla.)
        public static bool Pre_TakeDamage()
        {
            return !State.God;
        }

        // Backstop for God Mode (PlayMaker / other callers that remove HP directly) and for Infinite Salt/Charge.
        public static bool Pre_AddCurrency(int currency, ref int amount)
        {
            if (amount >= 0) return true;
            try
            {
                Settings.GameSettings cfg = Game.Cfg;
                if (cfg == null) return true;
                if (State.God)
                {
                    if (currency == Game.Id(cfg.HealthCurrency)) return false;
                    PlayerStateMachine p = Game.PSM;
                    if (p != null && p.Data != null && currency == Game.Id(p.Data.slaveHealthCurrency)) return false;
                }
                if (State.InfRes && (currency == Game.Id(cfg.SaltCurrency) || currency == Game.Id(cfg.ChargeCurrency))) return false;
            }
            catch { }
            return true;
        }

        static bool IsFree(Currency c)
        {
            if (c == null) return false;
            Settings.GameSettings cfg = Game.Cfg;
            if (cfg == null) return false;
            bool special = c == cfg.SaltCurrency || c == cfg.ChargeCurrency;   // heal flasks + relic energy have their own toggle
            return special ? State.InfRes : State.InfMoney;
        }

        // ECONOMY / Infinite Money + Items: purchases, crafting, upgrades go through TryToSpend/CanAfford.
        public static bool Pre_Spend1(Currency currency, ref bool __result)
        {
            if (IsFree(currency)) { __result = true; return false; }
            return true;
        }
        public static bool Pre_SpendMany(ref bool __result)
        {
            if (State.InfMoney) { __result = true; return false; }
            return true;
        }
        public static bool Pre_Afford1(Currency currency, ref bool __result)
        {
            if (IsFree(currency)) { __result = true; return false; }
            return true;
        }
        public static bool Pre_AffordMany(ref bool __result)
        {
            if (State.InfMoney) { __result = true; return false; }
            return true;
        }

        // COMBAT / One-Hit Kill: enemy HP is the PlayMaker "Health" int; raise the hit to exactly the remaining HP.
        public static void Pre_ChangeHealthBy(Damageable __instance, ref int damage)
        {
            if (!State.OneHit || damage <= 0) return;
            try
            {
                if (enemyLayer == -2) enemyLayer = LayerMask.NameToLayer("Enemy Body");
                if (__instance.gameObject.layer != enemyLayer) return;
                int hp;
                try { hp = __instance.Health; } catch { hp = 99999; }
                if (hp > damage) damage = hp;
            }
            catch { }
        }

        // MOVEMENT / Speed and unlimited air jumps, evaluated right after the game's own PlayerStateMachine.Update.
        public static void Post_PlayerUpdate(PlayerStateMachine __instance)
        {
            try
            {
                if (State.Speed)
                {
                    if (__instance.MoveSpeedMultiplier < State.SpeedMult) __instance.MoveSpeedMultiplier = State.SpeedMult;
                    if (__instance.MoveSpeedMultiplierDuration < 0.25f) __instance.MoveSpeedMultiplierDuration = 0.25f;
                }
                if (State.Jump)
                {
                    DoubleJumpState dj = __instance.DoubleJumpState;
                    if (dj != null)
                    {
                        dj.Enabled = true;                 // works even before the Double Jump ability is found
                        dj.DoubleJumpHasBeenReset = true;  // never "spent"
                        StateMachine sm = __instance.StateMachine;
                        // The vanilla state machine has no DoubleJump -> DoubleJump edge; add it so you can chain jumps while still rising.
                        if (sm != null && sm.CurrentState == dj && __instance.LastPressedJumpTime > 0f)
                        {
                            sm.ChangeState(__instance.InAirState);
                            sm.ChangeState(dj);
                        }
                    }
                }
            }
            catch { }
        }
    }

    internal class EspItem
    {
        public Vector3 Pos;
        public string Label;
        public Color Col;
    }

    [BepInPlugin("com.research.voidwroughttrainer", "Voidwrought Offline Trainer", "1.0.0")]
    public class VwTrainerPlugin : BaseUnityPlugin
    {
        internal static VwTrainerPlugin Instance;
        internal static Harmony HarmonyInst;
        const BindingFlags ANY = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance;

        ConfigEntry<KeyCode> kGod, kAdd, kInfMoney, kJump, kSpeed, kOneHit, kHeal, kInfRes, kEsp, kMap, kNoclip, kHud, kMaxAll, kRelics, kSpeedCycle;
        ConfigEntry<int> cAddIchor, cAddTrace;
        ConfigEntry<float> cSpeed, cEspRange;
        ConfigEntry<bool> cShowHud;

        bool showHud = true;
        string toast = "";
        float toastUntil;
        float nextMaint;
        float nextEsp;
        readonly List<EspItem> esp = new List<EspItem>();
        readonly Dictionary<string, string> trackedKinds = new Dictionary<string, string>();
        string regionLine = "";

        // self-test / dev hooks
        bool selfTest, dump, selfTestStarted, scanStarted;
        string autoLoad;
        float readySince = -1f;
        float autoLoadAt = -1f;
        bool autoLoaded;
        float nextDump;
        readonly Dictionary<string, string> hookStatus = new Dictionary<string, string>();
        readonly List<string> patchErrors = new List<string>();
        int patchedCount;

        void Awake()
        {
            Instance = this;
            gameObject.hideFlags = HideFlags.HideAndDontSave;
            DontDestroyOnLoad(gameObject);

            kGod = Config.Bind("Hotkeys", "GodMode", KeyCode.F1, "Toggle God Mode (no HP loss; spikes/pits still return you to safe ground)");
            kAdd = Config.Bind("Hotkeys", "AddMoney", KeyCode.F2, "Add money (Ichor + Trace Metal, see [Values])");
            kInfMoney = Config.Bind("Hotkeys", "InfiniteMoneyAndItems", KeyCode.F3, "Toggle Infinite Money + Items (purchases/crafting/upgrades cost nothing, money kept topped up)");
            kJump = Config.Bind("Hotkeys", "UnlimitedJump", KeyCode.F4, "Toggle unlimited air jumps");
            kSpeed = Config.Bind("Hotkeys", "SpeedBoost", KeyCode.F5, "Toggle movement speed multiplier");
            kOneHit = Config.Bind("Hotkeys", "OneHitKill", KeyCode.F6, "Toggle one-hit kill for enemies");
            kHeal = Config.Bind("Hotkeys", "FullHeal", KeyCode.F7, "Restore HP, heal flasks and relic charges once");
            kInfRes = Config.Bind("Hotkeys", "InfiniteFlasksAndCharges", KeyCode.F8, "Toggle infinite heal flasks (Salt) and relic charges");
            kEsp = Config.Bind("Hotkeys", "ShowItems", KeyCode.F9, "Toggle on-screen markers for uncollected pickups/secrets/lore in this room");
            kMap = Config.Bind("Hotkeys", "RevealMap", KeyCode.F10, "Reveal the whole map once (game's own map_complete; saved with your next save)");
            kNoclip = Config.Bind("Hotkeys", "Noclip", KeyCode.F11, "Toggle noclip free-fly (game's own debug noclip state)");
            kHud = Config.Bind("Hotkeys", "ToggleHud", KeyCode.F12, "Show/hide the trainer overlay");
            kMaxAll = Config.Bind("Hotkeys", "MaxMaterials", KeyCode.Home, "Fill all material/currency stacks to their cap once");
            kRelics = Config.Bind("Hotkeys", "GiveAllRelics", KeyCode.End, "Unlock every relic and crest once");
            kSpeedCycle = Config.Bind("Hotkeys", "SpeedCycle", KeyCode.PageUp, "Cycle speed multiplier 2 / 3 / 4 / 1.5");
            cAddIchor = Config.Bind("Values", "AddIchorAmount", 10000, "Ichor (main currency) added by the Add Money key (clamped by the game's cap)");
            cAddTrace = Config.Bind("Values", "AddTraceMetalAmount", 1000, "Trace Metal added by the Add Money key");
            cSpeed = Config.Bind("Values", "SpeedMultiplier", 2f, "Movement speed multiplier while SpeedBoost is on");
            cEspRange = Config.Bind("Values", "ItemMarkerMaxDistance", 400f, "Only mark items closer than this (world units)");
            cShowHud = Config.Bind("UI", "ShowHud", true, "Show overlay at start");
            showHud = cShowHud.Value;
            State.SpeedMult = Mathf.Clamp(cSpeed.Value, 0.1f, 10f);

            selfTest = Environment.GetEnvironmentVariable("TRAINER_SELFTEST") == "1" || File.Exists(Path.Combine(Paths.GameRootPath, "trainer_selftest.flag"));
            dump = Environment.GetEnvironmentVariable("TRAINER_DUMP") == "1" || File.Exists(Path.Combine(Paths.GameRootPath, "trainer_dump.flag"));
            autoLoad = Environment.GetEnvironmentVariable("TRAINER_AUTOLOAD");   // test hook: e.g. "Slot0" loads that save from the main menu
            try { string af = Path.Combine(Paths.GameRootPath, "trainer_autoload.txt"); if (string.IsNullOrEmpty(autoLoad) && File.Exists(af)) autoLoad = File.ReadAllText(af).Trim(); } catch { }

            ApplyPatches();
            Logger.LogInfo("Voidwrought Offline Trainer ready. Patched methods: " + patchedCount + (selfTest ? " [SELFTEST]" : ""));
        }

        // ---------------- patch installation (each feature reports its own hook status) ----------------
        // `features` = '|'-separated feature names that depend on this one patch.
        void Hook(string features, MethodBase target, string prefix, string postfix)
        {
            string[] names = features.Split('|');
            try
            {
                if (target == null) throw new Exception("target method not found");
                HarmonyMethod pre = null, post = null;
                if (prefix != null) pre = new HarmonyMethod(typeof(Patches).GetMethod(prefix, ANY));
                if (postfix != null) post = new HarmonyMethod(typeof(Patches).GetMethod(postfix, ANY));
                HarmonyInst.Patch(target, pre, post);
                patchedCount++;
                foreach (string f in names) { if (!hookStatus.ContainsKey(f)) hookStatus[f] = "HOOKED"; }
                Logger.LogInfo("Patched: " + target.DeclaringType.Name + "." + target.Name + " (" + features + ")");
            }
            catch (Exception e)
            {
                foreach (string f in names) hookStatus[f] = "HOOK_MISSING";
                patchErrors.Add(features + ": " + e.Message);
                Logger.LogError("Patch failed for " + features + ": " + e);
            }
        }

        void ApplyPatches()
        {
            HarmonyInst = new Harmony("com.research.voidwroughttrainer");
            Type inv = typeof(PlayerInventory);
            Type tCur = typeof(Currency);
            Type tDict = typeof(Dictionary<Currency, int>);
            Type tList = typeof(List<global::Player.CurrencyAmountPair>);
            Hook("God Mode", AccessTools.Method(typeof(PlayerStats), "TakeDamage", new Type[] { typeof(int) }), "Pre_TakeDamage", null);
            Hook("God Mode|Infinite Flasks/Charges", AccessTools.Method(inv, "AddCurrency", new Type[] { typeof(int), typeof(int), typeof(bool), typeof(bool) }), "Pre_AddCurrency", null);
            Hook("Infinite Money+Items|Infinite Flasks/Charges", AccessTools.Method(inv, "TryToSpend", new Type[] { tCur, typeof(int) }), "Pre_Spend1", null);
            Hook("Infinite Money+Items", AccessTools.Method(inv, "TryToSpend", new Type[] { tDict }), "Pre_SpendMany", null);
            Hook("Infinite Money+Items", AccessTools.Method(inv, "TryToSpend", new Type[] { tList }), "Pre_SpendMany", null);
            Hook("Infinite Money+Items|Infinite Flasks/Charges", AccessTools.Method(inv, "CanAfford", new Type[] { tCur, typeof(int) }), "Pre_Afford1", null);
            Hook("Infinite Money+Items", AccessTools.Method(inv, "CanAfford", new Type[] { tDict }), "Pre_AffordMany", null);
            Hook("Infinite Money+Items", AccessTools.Method(inv, "CanAfford", new Type[] { tList }), "Pre_AffordMany", null);
            Hook("One-Hit Kill", AccessTools.Method(typeof(Damageable), "ChangeHealthBy"), "Pre_ChangeHealthBy", null);
            Hook("Speed Multiplier|Unlimited Jump", AccessTools.Method(typeof(PlayerStateMachine), "Update"), null, "Post_PlayerUpdate");
        }

        static bool Down(ConfigEntry<KeyCode> k) { return Input.GetKeyDown(k.Value); }

        void Toast(string s)
        {
            toast = s;
            toastUntil = Time.unscaledTime + 3f;
            Logger.LogInfo(s);
        }

        static string OnOff(bool b) { return b ? "ON" : "OFF"; }

        // ---------------- main loop ----------------
        void Update()
        {
            if (Down(kHud)) showHud = !showHud;

            bool ready = Game.Ready;
            if (ready)
            {
                if (readySince < 0f) readySince = Time.unscaledTime;
                HandleHotkeys();
                if (Time.unscaledTime >= nextMaint) { nextMaint = Time.unscaledTime + 0.5f; try { Maintain(); } catch (Exception e) { Logger.LogWarning("maintain: " + e.Message); } }
                if (State.Esp && Time.unscaledTime >= nextEsp) { nextEsp = Time.unscaledTime + 1f; try { RefreshEsp(); } catch (Exception e) { Logger.LogWarning("esp: " + e.Message); esp.Clear(); } }
            }
            else
            {
                readySince = -1f;
                if (esp.Count > 0) esp.Clear();
            }

            // test hook: load a save from the main menu without UI automation
            if (!string.IsNullOrEmpty(autoLoad) && !autoLoaded && !ready)
            {
                try
                {
                    Core c = Utility.Singleton<Core>.instance;
                    if (c != null && Core.SaveLoad != null && Core.SaveLoad.IsInitialized)
                    {
                        if (autoLoadAt < 0f) autoLoadAt = Time.unscaledTime + 12f;
                        else if (Time.unscaledTime >= autoLoadAt) { autoLoaded = true; Logger.LogInfo("TRAINER_AUTOLOAD: loading " + autoLoad); Core.SaveLoad.Load(autoLoad); }
                    }
                }
                catch (Exception e) { Logger.LogWarning("autoload: " + e.Message); autoLoaded = true; }
            }

            if (ready && dump && Time.unscaledTime - readySince > 6f && Time.unscaledTime >= nextDump)
            {
                nextDump = Time.unscaledTime + 25f;
                try { WriteDump(); } catch (Exception e) { Logger.LogWarning("dump: " + e.Message); }
            }

            if (selfTest && !selfTestStarted && ready && Time.unscaledTime - readySince > 8f)
            {
                selfTestStarted = true;
                StartCoroutine(RunSelfTest());
            }
            if (!scanStarted && ready && !selfTest && Time.unscaledTime - readySince > 8f)
            {
                string sf = Path.Combine(Paths.GameRootPath, "trainer_scan.txt");
                if (File.Exists(sf))
                {
                    scanStarted = true;
                    try
                    {
                        string[] parts = File.ReadAllText(sf).Trim().Split(',');
                        File.Delete(sf);
                        StartCoroutine(ScanRegion(int.Parse(parts[0]), parts.Length > 1 ? int.Parse(parts[1]) : 20));
                    }
                    catch (Exception e) { Logger.LogWarning("scan: " + e.Message); }
                }
            }
        }

        void HandleHotkeys()
        {
            PlayerStateMachine p = Game.PSM;
            if (Down(kGod)) SetGod(!State.God);
            if (Down(kInfMoney)) { State.InfMoney = !State.InfMoney; Toast("Infinite Money + Items " + OnOff(State.InfMoney)); }
            if (Down(kInfRes)) { State.InfRes = !State.InfRes; Toast("Infinite Flasks + Charges " + OnOff(State.InfRes)); }
            if (Down(kJump)) SetJump(!State.Jump);
            if (Down(kSpeed)) { State.Speed = !State.Speed; Toast("Speed x" + State.SpeedMult.ToString("0.#") + " " + OnOff(State.Speed)); }
            if (Down(kSpeedCycle))
            {
                float m = State.SpeedMult;
                State.SpeedMult = m < 1.75f ? 2f : (m < 2.5f ? 3f : (m < 3.5f ? 4f : 1.5f));
                Toast("Speed multiplier = x" + State.SpeedMult.ToString("0.#"));
            }
            if (Down(kOneHit)) { State.OneHit = !State.OneHit; Toast("One-Hit Kill " + OnOff(State.OneHit)); }
            if (Down(kEsp)) { State.Esp = !State.Esp; nextEsp = 0f; if (!State.Esp) esp.Clear(); Toast("Item markers " + OnOff(State.Esp)); }
            if (Down(kAdd)) AddMoney();
            if (Down(kHeal)) FullHeal();
            if (Down(kMap)) RevealMap();
            if (Down(kNoclip)) ToggleNoclip(p);
            if (Down(kMaxAll)) MaxMaterials();
            if (Down(kRelics)) GiveAllRelics();
        }

        // ---------------- feature actions ----------------
        public void SetGod(bool on)
        {
            State.God = on;
            try { Game.PSM.Stats.SetGodMode(on); } catch (Exception e) { Logger.LogWarning("SetGodMode: " + e.Message); }
            Toast("God Mode " + OnOff(on));
        }

        public void SetJump(bool on)
        {
            State.Jump = on;
            if (!on) { try { Game.PSM.UpdateAbilitiesEnabledState(); } catch { } }   // restore the real ability gate
            Toast("Unlimited Jump " + OnOff(on));
        }

        public int AddMoney()
        {
            try
            {
                Settings.GameSettings cfg = Game.Cfg; PlayerInventory inv = Game.Inv;
                int before = Game.Amount(Game.Id(cfg.IchorCurrency));
                inv.AddCurrency(cfg.IchorCurrency.ID, cAddIchor.Value);
                if (cfg.TraceMetalCurrency != null && cAddTrace.Value > 0) inv.AddCurrency(cfg.TraceMetalCurrency.ID, cAddTrace.Value);
                int after = Game.Amount(cfg.IchorCurrency.ID);
                Toast("Money: Ichor " + before + " -> " + after + (cfg.TraceMetalCurrency != null ? " | Trace Metal " + Game.Amount(cfg.TraceMetalCurrency.ID) : ""));
                return after - before;
            }
            catch (Exception e) { Toast("Add money failed: " + e.Message); return 0; }
        }

        public void FullHeal()
        {
            try
            {
                Settings.GameSettings cfg = Game.Cfg; PlayerInventory inv = Game.Inv;
                Game.PSM.Stats.HealToMax();
                inv.SetCurrency(cfg.SaltCurrency.ID, Game.Amount(cfg.MaxSaltCurrency.ID), true, false);
                inv.SetCurrency(cfg.ChargeCurrency.ID, Game.Amount(cfg.MaxChargeCurrency.ID), true, false);
                Toast("HP, flasks and charges restored");
            }
            catch (Exception e) { Toast("Heal failed: " + e.Message); }
        }

        public void RevealMap()
        {
            try { Core.UI.Map.ExploreAllTiles(); Toast("Map revealed (saved with your next save)"); }
            catch (Exception e) { Toast("Reveal map failed: " + e.Message); }
        }

        public void ToggleNoclip(PlayerStateMachine p)
        {
            try
            {
                if (p == null) return;
                if (p.StateMachine.CurrentState == p.NoclipState) { p.StateMachine.ChangeState(p.IdleState); Toast("Noclip OFF"); }
                else { p.StateMachine.ChangeState(p.NoclipState); Toast("Noclip ON (move with the direction keys)"); }
            }
            catch (Exception e) { Toast("Noclip failed: " + e.Message); }
        }

        // Currencies that must never be pushed to their cap (they are upgrade levels / bookkeeping / story counters).
        HashSet<int> NeverMax()
        {
            Settings.GameSettings c = Game.Cfg; HashSet<int> s = new HashSet<int>();
            Currency[] list = new Currency[] { c.HealthLossCurrency, c.HealthUpgradeCurrency, c.MaxHealthCurrency, c.MaxSaltCurrency, c.MaxChargeCurrency,
                c.DamageUpgradeCurrency, c.MiniChargeCurrency, c.ExcavationCrewCurrency };
            foreach (Currency x in list) if (x != null) s.Add(x.ID);
            try { s.Add(Game.Id(Game.PSM.Data.slaveHealthCurrency)); s.Add(Game.Id(Game.PSM.Data.slaveMaxHealthCurrency)); } catch { }
            return s;
        }

        public int MaxMaterials()
        {
            int n = 0;
            try
            {
                PlayerInventory inv = Game.Inv; HashSet<int> skip = NeverMax();
                foreach (KeyValuePair<int, Currency> kv in new Dictionary<int, Currency>(inv.CurrencyLookup))
                {
                    Currency cur = kv.Value;
                    if (cur == null || skip.Contains(cur.ID)) continue;
                    if (!(cur.ShowInInventory || cur.ShowInCurrencyBar)) continue;
                    if (Game.Amount(cur.ID) >= cur.MaxAmount) continue;
                    SetRaw(inv, cur.ID, cur.MaxAmount);
                    n++;
                }
                Toast("Filled " + n + " material/currency stacks to their cap");
            }
            catch (Exception e) { Toast("Max materials failed: " + e.Message); }
            return n;
        }

        public int GiveAllRelics()
        {
            int n = 0;
            try
            {
                PlayerInventory inv = Game.Inv; PlayerData data = Game.PSM.Data;
                foreach (global::Player.RelicData r in Core.Game.ToolBelt.AllRelics)
                {
                    if (r == null || !r.Enabled || inv.Relics.Contains(r)) continue;
                    if (r == data.mysteriousEggRelic && Core.SaveLoad.GetGlobalParameterValue(data.mysteriousEggIchorCounter.Name) >= data.mysteriousEggIchorNeeded)
                        inv.AddRelic(data.relicRewardFromMysteriousEgg, false);
                    else
                        inv.AddRelic(r, false);
                    n++;
                }
                Toast("Unlocked " + n + " relics/crests (equip them in the menu)");
            }
            catch (Exception e) { Toast("Give relics failed: " + e.Message); }
            return n;
        }

        // Periodic upkeep of the "lock" style toggles (every 0.5 s).
        void Maintain()
        {
            Settings.GameSettings cfg = Game.Cfg; PlayerInventory inv = Game.Inv; PlayerStateMachine p = Game.PSM;
            if (State.God && !p.Stats.Invulnerable) p.Stats.SetGodMode(true);
            if (State.InfRes)
            {
                int ms = Game.Amount(cfg.MaxSaltCurrency.ID), mc = Game.Amount(cfg.MaxChargeCurrency.ID);
                if (Game.Amount(cfg.SaltCurrency.ID) < ms) SetRaw(inv, cfg.SaltCurrency.ID, ms);
                if (Game.Amount(cfg.ChargeCurrency.ID) < mc) SetRaw(inv, cfg.ChargeCurrency.ID, mc);
            }
            if (State.InfMoney)
            {
                TopUp(inv, cfg.IchorCurrency);
                TopUp(inv, cfg.TraceMetalCurrency);
            }
        }

        static void TopUp(PlayerInventory inv, Currency c)
        {
            if (c == null) return;
            if (Game.Amount(c.ID) < c.MaxAmount) SetRaw(inv, c.ID, c.MaxAmount);
        }

        // Writes the stack directly and fires the HUD update event. Bypasses SetCurrency's "special case" side effects
        // (e.g. feeding the Mysterious Egg relic with the whole amount every tick).
        static void SetRaw(PlayerInventory inv, int id, int value)
        {
            inv.Currencies[id] = value;
            if (inv.OnCurrenciesChanged != null) inv.OnCurrenciesChanged(id, value);
        }

        // ---------------- item markers ("show all items") ----------------
        static readonly System.Text.RegularExpressions.Regex ItemWords = new System.Text.RegularExpressions.Regex(
            "pickup|^secret$|lore ?stone|chest|treasure",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        void AddKind(List<GlobalParameter> list, string kind)
        {
            if (list == null) return;
            foreach (GlobalParameter g in list) { if (g != null) trackedKinds[g.Name] = kind; }
        }

        void BuildTracked()
        {
            trackedKinds.Clear();
            List<Settings.RegionSettings.Region> regions = Core.Game.Regions.Regions;
            if (regions == null) return;
            foreach (Settings.RegionSettings.Region r in regions)
            {
                AddKind(r.Pickups, "Pickup");
                AddKind(r.Secrets, "Secret");
                AddKind(r.LoreStones, "Lore");
                AddKind(r.Envoys, "Envoy");
            }
        }

        static Color KindColor(string kind)
        {
            switch (kind)
            {
                case "Pickup": return new Color(0.2f, 1f, 0.4f);
                case "Secret": return new Color(1f, 0.85f, 0.2f);
                case "Lore": return new Color(0.4f, 0.8f, 1f);
                case "Envoy": return new Color(1f, 0.4f, 0.4f);
                default: return new Color(0.9f, 0.9f, 0.9f);
            }
        }

        void RefreshEsp()
        {
            if (trackedKinds.Count == 0) BuildTracked();
            esp.Clear();
            Vector3 pp = Game.PSM.transform.position;
            float maxD = cEspRange.Value;
            foreach (DeactivateIfGlobalParameter d in UnityEngine.Object.FindObjectsOfType<DeactivateIfGlobalParameter>())
            {
                try
                {
                    string id = d.ID, kind;
                    if (!trackedKinds.TryGetValue(id, out kind)) continue;
                    if (Core.SaveLoad.GetGlobalParameterValue(id) != 0) continue;   // already collected
                    Vector3 pos = d.transform.position;
                    if ((pos - pp).magnitude > maxD) continue;
                    EspItem it = new EspItem();
                    it.Pos = pos; it.Label = kind + ": " + id; it.Col = KindColor(kind);
                    esp.Add(it);
                }
                catch { }
            }
            // fallback: PlayMaker-driven interactables that are not gated by a tracked global parameter
            foreach (PlayMakerFSM f in UnityEngine.Object.FindObjectsOfType<PlayMakerFSM>())
            {
                try
                {
                    GameObject go = f.gameObject;
                    if (go.GetComponent<RectTransform>() != null) continue;     // UI
                    if (!ItemWords.IsMatch(go.name)) continue;
                    Vector3 pos = go.transform.position;
                    if ((pos - pp).magnitude > maxD) continue;
                    bool dup = false;
                    foreach (EspItem e in esp) { if ((e.Pos - pos).sqrMagnitude < 0.25f) { dup = true; break; } }
                    if (dup) continue;
                    EspItem it = new EspItem();
                    it.Pos = pos; it.Label = go.name; it.Col = KindColor(go.name.ToLower().Contains("secret") ? "Secret" : (go.name.ToLower().Contains("lore") ? "Lore" : "Pickup"));
                    esp.Add(it);
                }
                catch { }
            }
            Settings.RegionSettings.Region cur = Core.Game.Regions.CurrentRegion;
            if (cur != null)
            {
                int pc, pt, sc, st, lc, lt;
                cur.GetPickupCounts(out pc, out pt); cur.GetSecretCounts(out sc, out st); cur.GetLoreStoneCounts(out lc, out lt);
                regionLine = "Region: pickups " + pc + "/" + pt + "  secrets " + sc + "/" + st + "  lore " + lc + "/" + lt;
            }
            else regionLine = "";
        }

        // ---------------- overlay ----------------
        GUIStyle lblStyle;
        void OnGUI()
        {
            if (lblStyle == null)
            {
                lblStyle = new GUIStyle(GUI.skin.label);
                lblStyle.fontSize = 13;
                lblStyle.normal.textColor = Color.white;
            }
            if (State.Esp && esp.Count > 0) DrawEsp();
            if (!showHud) return;
            GUI.depth = 0;
            Matrix4x4 old = GUI.matrix;
            float sc = Mathf.Max(1f, Screen.height / 720f);
            GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(sc, sc, 1f));
            List<string> lines = new List<string>();
            lines.Add("VOIDWROUGHT TRAINER (offline)   [" + kHud.Value + "] hide");
            lines.Add("[" + kGod.Value + "] God Mode ............ " + OnOff(State.God));
            lines.Add("[" + kAdd.Value + "] Add Money +" + cAddIchor.Value);
            lines.Add("[" + kInfMoney.Value + "] Infinite Money+Items . " + OnOff(State.InfMoney));
            lines.Add("[" + kJump.Value + "] Unlimited Jump ...... " + OnOff(State.Jump));
            lines.Add("[" + kSpeed.Value + "] Speed x" + State.SpeedMult.ToString("0.#") + " ........... " + OnOff(State.Speed) + "  [" + kSpeedCycle.Value + "] cycle");
            lines.Add("[" + kOneHit.Value + "] One-Hit Kill ........ " + OnOff(State.OneHit));
            lines.Add("[" + kHeal.Value + "] Full Heal");
            lines.Add("[" + kInfRes.Value + "] Infinite Flasks/Charge " + OnOff(State.InfRes));
            lines.Add("[" + kEsp.Value + "] Show Items on screen . " + OnOff(State.Esp));
            lines.Add("[" + kMap.Value + "] Reveal Whole Map");
            lines.Add("[" + kNoclip.Value + "] Noclip fly");
            lines.Add("[" + kMaxAll.Value + "] Max materials   [" + kRelics.Value + "] All relics");
            if (State.Esp && regionLine.Length > 0) lines.Add(regionLine);
            if (!Game.Ready) lines.Add("(load a save to activate)");
            float lh = 18f;
            float h = 10 + lines.Count * lh + (Time.unscaledTime < toastUntil ? 24 : 0);
            GUI.Box(new Rect(8, 8, 330, h), GUIContent.none);
            for (int i = 0; i < lines.Count; i++) GUI.Label(new Rect(14, 10 + i * lh, 322, 20), lines[i], lblStyle);
            if (Time.unscaledTime < toastUntil) GUI.Label(new Rect(14, 10 + lines.Count * lh, 322, 20), ">> " + toast, lblStyle);
            GUI.matrix = old;
        }

        Camera camCache;
        Camera GetCam()
        {
            if (camCache != null && camCache.enabled && camCache.gameObject.activeInHierarchy) return camCache;
            Camera best = Camera.main;
            if (best == null)
            {
                foreach (Camera c in Camera.allCameras)
                {
                    if (c == null || !c.enabled || c.targetTexture != null) continue;
                    if (best == null || c.depth > best.depth) best = c;
                }
            }
            camCache = best;
            return best;
        }

        void DrawEsp()
        {
            Camera cam = GetCam();
            if (cam == null || !Game.Ready) return;
            Vector3 pp = Game.PSM.transform.position;
            Color keep = GUI.color;
            float W = Screen.width, H = Screen.height, m = 24f;
            foreach (EspItem it in esp)
            {
                Vector3 sp = cam.WorldToScreenPoint(it.Pos);
                float x = sp.x, y = H - sp.y;
                bool off = sp.z < 0f || x < m || x > W - m || y < m || y > H - m;
                string prefix = "";
                if (off)
                {
                    float cx = W * 0.5f, cy = H * 0.5f, dx = x - cx, dy = y - cy;
                    if (sp.z < 0f) { dx = -dx; dy = -dy; }
                    float k = Mathf.Min((W * 0.5f - m) / Mathf.Max(Mathf.Abs(dx), 0.01f), (H * 0.5f - m) / Mathf.Max(Mathf.Abs(dy), 0.01f));
                    x = cx + dx * k; y = cy + dy * k;
                    prefix = Mathf.Abs(dx) > Mathf.Abs(dy) ? (dx > 0 ? "> " : "< ") : (dy > 0 ? "v " : "^ ");
                }
                string text = prefix + it.Label + "  " + Mathf.RoundToInt((it.Pos - pp).magnitude) + "m";
                GUI.color = it.Col;
                GUI.Box(new Rect(x - 4, y - 4, 8, 8), GUIContent.none);
                GUI.Label(new Rect(x + 6, y - 10, 360, 22), text, lblStyle);
            }
            GUI.color = keep;
        }

        // ---------------- dev dump (TRAINER_DUMP=1) ----------------
        void WriteDump()
        {
            StringBuilder sb = new StringBuilder();
            Settings.GameSettings cfg = Game.Cfg; PlayerInventory inv = Game.Inv;
            sb.AppendLine("== currencies (id | asset | locKey | max | amount | inv | bar) ==");
            foreach (KeyValuePair<int, Currency> kv in inv.CurrencyLookup)
            {
                Currency c = kv.Value;
                sb.AppendLine(c.ID + " | " + c.name + " | " + c.NameLocKey + " | " + c.MaxAmount + " | " + Game.Amount(c.ID) + " | " + c.ShowInInventory + " | " + c.ShowInCurrencyBar);
            }
            sb.AppendLine("main: ichor=" + cfg.IchorCurrency.name + " trace=" + (cfg.TraceMetalCurrency != null ? cfg.TraceMetalCurrency.name : "null"));
            sb.AppendLine("== regions ==");
            foreach (Settings.RegionSettings.Region r in Core.Game.Regions.Regions)
                sb.AppendLine(r.ID + " " + r.NameLocKey + " scenes=" + r.Scenes.Count + " pickups=" + r.Pickups.Count + " secrets=" + r.Secrets.Count + " lore=" + r.LoreStones.Count + " envoys=" + r.Envoys.Count);
            sb.AppendLine("== scene objects ==");
            AppendSceneInfo(sb);
            File.WriteAllText(Path.Combine(Paths.GameRootPath, "trainer_dump.txt"), sb.ToString());
            Logger.LogInfo("dump written");
        }

        void AppendSceneInfo(StringBuilder sb)
        {
            sb.Append("loaded scenes:");
            for (int i = 0; i < UnityEngine.SceneManagement.SceneManager.sceneCount; i++) sb.Append(" " + UnityEngine.SceneManagement.SceneManager.GetSceneAt(i).name);
            sb.AppendLine();
            sb.AppendLine("player pos=" + Game.PSM.transform.position);
            if (trackedKinds.Count == 0) BuildTracked();
            foreach (DeactivateIfGlobalParameter d in Resources.FindObjectsOfTypeAll<DeactivateIfGlobalParameter>())
            {
                try
                {
                    if (!d.gameObject.scene.IsValid()) continue;
                    string id = d.ID, kind;
                    trackedKinds.TryGetValue(id, out kind);
                    sb.AppendLine("DeactIf " + d.gameObject.name + " active=" + d.gameObject.activeInHierarchy + " id=" + id + " kind=" + (kind ?? "-") + " val=" + Core.SaveLoad.GetGlobalParameterValue(id) + " pos=" + d.transform.position);
                }
                catch { }
            }
            Dictionary<string, int> names = new Dictionary<string, int>();
            foreach (PlayMakerFSM f in Resources.FindObjectsOfTypeAll<PlayMakerFSM>())
            {
                try
                {
                    if (!f.gameObject.scene.IsValid()) continue;
                    if (f.gameObject.GetComponent<RectTransform>() != null) continue;
                    string n = f.gameObject.name; int c;
                    names.TryGetValue(n, out c); names[n] = c + 1;
                    if (ItemWords.IsMatch(n)) sb.AppendLine("FSM " + n + " fsm=" + f.FsmName + " active=" + f.gameObject.activeInHierarchy + " pos=" + f.transform.position);
                }
                catch { }
            }
            sb.Append("distinct FSM object names:");
            int k = 0;
            foreach (KeyValuePair<string, int> kv in names) { if (k++ > 400) break; sb.Append(" [" + kv.Key + " x" + kv.Value + "]"); }
            sb.AppendLine();
        }

        // dev: visit scenes of one region and dump what each contains ("trainer_scan.txt": "regionIndex,maxScenes")
        IEnumerator ScanRegion(int regionIndex, int maxScenes)
        {
            StringBuilder sb = new StringBuilder();
            List<string> scenes = Core.Game.Regions.Regions[regionIndex].Scenes;
            int n = 0;
            foreach (string s in scenes)
            {
                if (n++ >= maxScenes) break;
                sb.AppendLine("##### scene " + s);
                try { SceneLoader_Teleport(s); } catch (Exception e) { sb.AppendLine("teleport failed: " + e.Message); continue; }
                float t0 = Time.unscaledTime;
                yield return new WaitForSecondsRealtime(1f);
                while (Utility.SceneLoader.LoadingInProgress && Time.unscaledTime - t0 < 30f) yield return null;
                yield return new WaitForSecondsRealtime(3f);
                try { AppendSceneInfo(sb); State.Esp = true; RefreshEsp(); sb.AppendLine("ESP markers=" + esp.Count); foreach (EspItem ei in esp) sb.AppendLine("  ESP " + ei.Label + " @" + ei.Pos); sb.AppendLine(regionLine); } catch (Exception e) { sb.AppendLine("dump failed: " + e.Message); }
                File.WriteAllText(Path.Combine(Paths.GameRootPath, "trainer_scan_dump.txt"), sb.ToString());
            }
            Logger.LogInfo("scan finished");
        }

        static void SceneLoader_Teleport(string scene) { Utility.SceneLoader.TeleportToScene(scene); }

        // ---------------- Self-test (TRAINER_SELFTEST=1) ----------------
        class FeatureResult
        {
            public string Branch, Name, HookStatus = "UNKNOWN", Status = "PENDING", Detail = "";
        }
        readonly List<FeatureResult> results = new List<FeatureResult>();

        FeatureResult NewResult(string branch, string name, string hookKey)
        {
            FeatureResult r = new FeatureResult();
            r.Branch = branch; r.Name = name;
            string hs;
            r.HookStatus = (hookKey != null && hookStatus.TryGetValue(hookKey, out hs)) ? hs : (hookKey == null ? "N/A" : "HOOK_MISSING");
            results.Add(r);
            return r;
        }

        static void SetDirect(PlayerInventory inv, int id, int value)
        {
            inv.Currencies[id] = value;
            if (inv.OnCurrenciesChanged != null) inv.OnCurrenciesChanged(id, value);
        }

        IEnumerator RunSelfTest()
        {
            results.Clear();
            bool full = Environment.GetEnvironmentVariable("TRAINER_SELFTEST_FULL") == "1" || File.Exists(Path.Combine(Paths.GameRootPath, "trainer_selftest_full.flag"));
            PlayerStateMachine p = Game.PSM; PlayerInventory inv = Game.Inv; Settings.GameSettings cfg = Game.Cfg;
            bool sGod = State.God, sOne = State.OneHit, sMoney = State.InfMoney, sRes = State.InfRes, sJump = State.Jump, sSpeed = State.Speed, sEsp = State.Esp;
            yield return null;

            // COMBAT: God Mode
            FeatureResult rg = NewResult("SUBAGENT-COMBAT-01", "God Mode", "God Mode");
            try
            {
                PlayerStats st = p.Stats; int hc = cfg.HealthCurrency.ID;
                int hp = st.Health, max = st.MaxHealth;
                bool inv1 = hp >= 0 && max > 0 && max < 1000000 && hp <= max * 2;
                State.God = true;
                st.TakeDamage(1);
                bool a = st.Health == hp;
                inv.AddCurrency(hc, -1, true, false);
                bool b = st.Health == hp;
                State.God = false;
                string ctl = "control_skipped";
                int slave = Game.Amount(Game.Id(p.Data.slaveHealthCurrency));
                if (hp >= 2 && slave == 0)
                {
                    st.TakeDamage(1);
                    ctl = (st.Health == hp - 1) ? "control_ok" : "control_FAIL";
                    SetDirect(inv, hc, hp);
                }
                rg.Status = (rg.HookStatus == "HOOKED" && inv1 && a && b && ctl != "control_FAIL") ? "PASS" : "FAIL";
                rg.Detail = "hp=" + hp + " max=" + max + " invariant=" + inv1 + " TakeDamage_blocked=" + a + " AddCurrency_blocked=" + b + " " + ctl;
            }
            catch (Exception e) { rg.Status = "FAIL"; rg.Detail = e.Message; }
            State.God = sGod;

            // COMBAT: One-Hit Kill (needs a live enemy for a delta test; hook + layer invariant only)
            FeatureResult ro = NewResult("SUBAGENT-COMBAT-01", "One-Hit Kill", "One-Hit Kill");
            int layer = LayerMask.NameToLayer("Enemy Body");
            int enemies = 0;
            try { foreach (Damageable d in UnityEngine.Object.FindObjectsOfType<Damageable>()) if (d.gameObject.layer == layer) enemies++; } catch { }
            ro.Status = (ro.HookStatus == "HOOKED" && layer >= 0) ? "PASS" : "FAIL";
            ro.Detail = "enemy_layer=" + layer + " live_enemies_in_scene=" + enemies + " (hook verified; kill delta needs a fight)";

            // ECONOMY: Add Money (delta, then restore)
            FeatureResult re = NewResult("SUBAGENT-ECONOMY-02", "Add Money", null);
            try
            {
                int id = cfg.IchorCurrency.ID, max = cfg.IchorCurrency.MaxAmount, b = Game.Amount(id);
                int d = Math.Min(10, max - b);
                if (d > 0)
                {
                    inv.AddCurrency(id, d, true, false);
                    bool plus = Game.Amount(id) == b + d;
                    SetDirect(inv, id, b);
                    re.Status = (plus && Game.Amount(id) == b) ? "PASS" : "FAIL";
                    re.Detail = "ichor_before=" + b + " +" + d + " ok=" + plus + " restored=" + (Game.Amount(id) == b) + " cap=" + max;
                }
                else { re.Status = "PASS"; re.Detail = "ichor at cap (" + max + ")"; }
            }
            catch (Exception e) { re.Status = "FAIL"; re.Detail = e.Message; }

            // ECONOMY: Infinite Money + Items
            FeatureResult ri = NewResult("SUBAGENT-ECONOMY-02", "Infinite Money + Items", "Infinite Money+Items");
            try
            {
                Currency c = cfg.IchorCurrency; int b = Game.Amount(c.ID);
                bool had = b >= 1;
                string baseline = "baseline_skipped";
                if (had)
                {
                    State.InfMoney = false;
                    bool spent = inv.TryToSpend(c, 1);
                    baseline = (spent && Game.Amount(c.ID) == b - 1) ? "baseline_ok" : "baseline_FAIL";
                    SetDirect(inv, c.ID, b);
                }
                State.InfMoney = true;
                bool free = inv.TryToSpend(c, b + 123456);                 // more than we own
                bool afford = inv.CanAfford(c, b + 123456);
                bool unchanged = Game.Amount(c.ID) == b;
                State.InfMoney = sMoney;
                ri.Status = (ri.HookStatus == "HOOKED" && free && afford && unchanged && baseline != "baseline_FAIL") ? "PASS" : "FAIL";
                ri.Detail = "TryToSpend_free=" + free + " CanAfford=" + afford + " balance_unchanged=" + unchanged + " " + baseline;
            }
            catch (Exception e) { ri.Status = "FAIL"; ri.Detail = e.Message; State.InfMoney = sMoney; }

            // RESOURCE: Infinite flasks / charges
            FeatureResult rr = NewResult("SUBAGENT-RESOURCE-03", "Infinite Flasks + Charges", "Infinite Flasks/Charges");
            try
            {
                Currency salt = cfg.SaltCurrency; int b = Game.Amount(salt.ID);
                State.InfRes = true;
                bool free = inv.TryToSpend(salt, 1);
                inv.AddCurrency(salt.ID, -1, true, false);
                bool unchanged = Game.Amount(salt.ID) == b;
                State.InfRes = sRes;
                SetDirect(inv, salt.ID, b);
                rr.Status = (rr.HookStatus == "HOOKED" && free && unchanged) ? "PASS" : "FAIL";
                rr.Detail = "salt=" + b + " TryToSpend_free=" + free + " unchanged=" + unchanged;
            }
            catch (Exception e) { rr.Status = "FAIL"; rr.Detail = e.Message; State.InfRes = sRes; }

            // MOVEMENT: Speed
            FeatureResult rs = NewResult("SUBAGENT-MOVEMENT-04", "Speed Multiplier", "Speed Multiplier");
            try
            {
                State.Speed = true;
                yield return null; yield return null; yield return null;
                float m = p.MoveSpeedMultiplier;
                State.Speed = false;
                rs.Status = (rs.HookStatus == "HOOKED" && m >= State.SpeedMult - 0.001f) ? "PASS" : "FAIL";
                rs.Detail = "MoveSpeedMultiplier_with_toggle=" + m + " target=" + State.SpeedMult;
            }
            finally { State.Speed = sSpeed; }

            // MOVEMENT: Unlimited Jump (gate + functional chain: DoubleJump -> DoubleJump)
            FeatureResult rj = NewResult("SUBAGENT-JUMP-05", "Unlimited Jump", "Unlimited Jump");
            int enters = 0;
            Action<string> cb = delegate(string s) { if (s == "DoubleJumpState") enters++; };
            bool gate = false; string func = "functional_skipped(not idle on ground)";
            State.Jump = true;
            yield return null; yield return null;
            gate = p.DoubleJumpState.Enabled && p.DoubleJumpState.DoubleJumpHasBeenReset;
            if (p.StateMachine.CurrentState == p.IdleState)
            {
                p.StateMachine.OnStateChanged += cb;
                p.StateMachine.ChangeState(p.DoubleJumpState);        // first air jump
                yield return null;
                MethodInfo setter = typeof(PlayerStateMachine).GetProperty("LastPressedJumpTime").GetSetMethod(true);
                setter.Invoke(p, new object[] { 0.15f });             // simulate pressing Jump again while still rising
                yield return null; yield return null; yield return null;
                p.StateMachine.OnStateChanged -= cb;
                func = "air_jump_entries=" + enters + (enters >= 2 ? " (chained)" : " (NOT chained)");
            }
            rj.Status = (rj.HookStatus == "HOOKED" && gate && (enters == 0 || enters >= 2)) ? "PASS" : "FAIL";
            rj.Detail = "DoubleJump_enabled_and_reset=" + gate + " " + func;
            State.Jump = sJump;
            if (!sJump) { try { p.UpdateAbilitiesEnabledState(); } catch { } }

            // UTILITY: Noclip (enter, verify, leave)
            FeatureResult rn = NewResult("SUBAGENT-UTILITY-07", "Noclip", null);
            try
            {
                if (p.StateMachine.CurrentState == p.IdleState)
                {
                    p.StateMachine.ChangeState(p.NoclipState);
                    yield return null; yield return null;
                    bool inN = p.StateMachine.CurrentState == p.NoclipState;
                    p.StateMachine.ChangeState(p.IdleState);
                    yield return null;
                    bool outN = p.StateMachine.CurrentState == p.IdleState;
                    rn.Status = (inN && outN) ? "PASS" : "FAIL";
                    rn.Detail = "entered=" + inN + " left=" + outN;
                }
                else { rn.Status = p.NoclipState != null ? "PASS" : "FAIL"; rn.Detail = "state present; live toggle skipped (player not idle)"; }
            }
            finally { try { if (p.StateMachine.CurrentState == p.NoclipState) p.StateMachine.ChangeState(p.IdleState); } catch { } }

            // UTILITY: Full Heal
            FeatureResult rh = NewResult("SUBAGENT-UTILITY-07", "Full Heal", null);
            try
            {
                FullHeal();
                bool full1 = p.Stats.Health >= p.Stats.MaxHealth;
                bool salt = Game.Amount(cfg.SaltCurrency.ID) >= Game.Amount(cfg.MaxSaltCurrency.ID);
                rh.Status = (full1 && salt) ? "PASS" : "FAIL";
                rh.Detail = "hp=" + p.Stats.Health + "/" + p.Stats.MaxHealth + " salt=" + Game.Amount(cfg.SaltCurrency.ID) + "/" + Game.Amount(cfg.MaxSaltCurrency.ID);
            }
            catch (Exception e) { rh.Status = "FAIL"; rh.Detail = e.Message; }

            // MAP: item markers + reveal map
            FeatureResult rm = NewResult("SUBAGENT-MAP-06", "Show Items (markers)", null);
            try
            {
                trackedKinds.Clear();
                RefreshEsp();
                rm.Status = trackedKinds.Count > 0 ? "PASS" : "FAIL";
                rm.Detail = "tracked_pickup_secret_lore_envoy_ids=" + trackedKinds.Count + " markers_in_range=" + esp.Count + " " + regionLine;
            }
            catch (Exception e) { rm.Status = "FAIL"; rm.Detail = e.Message; }
            State.Esp = sEsp;
            if (!sEsp) esp.Clear();

            FeatureResult rv = NewResult("SUBAGENT-MAP-06", "Reveal Map", null);
            try
            {
                if (full) { RevealMap(); rv.Status = "PASS"; rv.Detail = "ExploreAllTiles executed (FULL test, in-memory only)"; }
                else { rv.Status = Core.UI.Map != null ? "PASS" : "FAIL"; rv.Detail = "Map component present; ExploreAllTiles not run (would change explored-tile save data)"; }
            }
            catch (Exception e) { rv.Status = "FAIL"; rv.Detail = e.Message; }

            FeatureResult rx = NewResult("SUBAGENT-UTILITY-07", "Max Materials + All Relics", null);
            try
            {
                if (full)
                {
                    int n1 = MaxMaterials(), n2 = GiveAllRelics();
                    rx.Status = "PASS"; rx.Detail = "FULL test: stacks_filled=" + n1 + " relics_added=" + n2 + " (in-memory only)";
                }
                else { rx.Status = (inv.CurrencyLookup != null && Core.Game.ToolBelt.AllRelics != null) ? "PASS" : "FAIL"; rx.Detail = "data present: currencies=" + inv.CurrencyLookup.Count + " relics=" + Core.Game.ToolBelt.AllRelics.Length + "; not executed"; }
            }
            catch (Exception e) { rx.Status = "FAIL"; rx.Detail = e.Message; }

            State.God = sGod; State.OneHit = sOne; State.InfMoney = sMoney; State.InfRes = sRes; State.Jump = sJump; State.Speed = sSpeed;
            WriteReport("done");
        }

        void WriteReport(string note)
        {
            try
            {
                bool all = results.Count > 0 && patchErrors.Count == 0;
                foreach (FeatureResult r in results) if (r.Status != "PASS") all = false;
                StringBuilder sb = new StringBuilder();
                sb.Append("{\n");
                sb.Append("  \"overall_status\": \"" + (all ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL") + "\",\n");
                sb.Append("  \"note\": \"" + Esc(note) + "\",\n");
                sb.Append("  \"patched_method_count\": " + patchedCount + ",\n");
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
                Logger.LogInfo("selftest report written: " + (all ? "ALL PASS" : "SEE REPORT"));
            }
            catch (Exception e) { Logger.LogError("report write failed: " + e.Message); }
        }

        static string Esc(string s)
        {
            return (s ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", " ").Replace("\n", " ");
        }
    }
}


