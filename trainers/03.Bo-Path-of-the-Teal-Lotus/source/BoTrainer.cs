// Bo: Path of the Teal Lotus - Offline Trainer (BepInEx 5 + Harmony, Unity 2022.3 Mono x64)
// Single-player / offline use only. No anti-cheat, DRM or online service is touched.
//
// Evidence (decompiled Assembly-CSharp.dll, see bo-src/ and artifacts/bo/subtasks/ev_*.json):
//   COMBAT    NewPlayer.CanDamagePlayer() is the single gate every enemy / projectile / hazard collider asks before calling
//             NewPlayer.DamagePlayer*(); NewHealth.DamagePlayer(int,bool) is the HP sink (also used by killzones / spikes).
//   ECONOMY   All currencies live in the InventoryContainer ScriptableObject (GameManager.Instance.inventoryContainer):
//             Kitsunebi = fox-flame money, Bamboo / TealOre / VermillionCrystal / CrystalMumPetal / SpiderSilk /
//             PungentRoot / LotusSeeds / AwakeningInk = crafting + shop resources. HUD polls the fields each frame.
//   MOVEMENT  NewPlayer.CalculateMoveSpeed(float) feeds PhysicsObject.targetVelocity.x (velocity.x = targetVelocity.x);
//             Hover.HoverSpeed() is the glide speed.
//   JUMP      air jump = NewPlayer.canDoubleJump (granted by AbilityReset / JumpReset, consumed by PerformJumpReset,
//             cleared on landing). Keeping it true while airborne gives unlimited jumps.
//   DAMAGE    Attack.OnEnable() stores the staff damage in EnemiesManager.CurrentStaffDamage (read by Enemy / NewBoss / Boss);
//             Enemy.EnemyLoseHealth() subtracts the private currentStaffDamage (also for Daruma / bat hits).
//   TEA       GameManager.InfiniteMana is the game's own assist flag (NewMana.DrainMana / NewHealth / Daruma honour it).
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

namespace BoTrainer
{
    public static class State
    {
        public static bool GodMode;
        public static bool InfiniteMoney;
        public static bool InfiniteItems;
        public static bool UnlimitedJump;
        public static bool SpeedBoost;
        public static bool OneHitKill;
        public static bool InfiniteTea;
        public static bool FallIgnore = true;      // God Mode: kill zones / pits do nothing (you can fall to the bottom of the map)
        public static float SpeedMultiplier = 2f;
        public static float OneHitDamage = 9999f;
        public static int MoneyFloor = 99999;
        public static int ItemFloor = 99;

        public static float OhkDamage(float original)
        {
            if (OneHitKill && original > 0f) return Math.Max(original, OneHitDamage);
            return original;
        }
    }

    // Resource ints of InventoryContainer that the trainer can add / keep topped up (name -> discovered flag).
    public static class Resources2
    {
        public static readonly string[] Items = new string[]
        {
            "Bamboo", "TealOre", "VermillionCrystal", "CrystalMumPetal", "SpiderSilk", "PungentRoot", "LotusSeeds", "AwakeningInk"
        };
        static readonly Dictionary<string, PropertyInfo> props = new Dictionary<string, PropertyInfo>();
        static readonly Dictionary<string, PropertyInfo> disc = new Dictionary<string, PropertyInfo>();

        static PropertyInfo P(string name)
        {
            PropertyInfo p;
            if (!props.TryGetValue(name, out p))
            {
                p = typeof(InventoryContainer).GetProperty(name, BindingFlags.Public | BindingFlags.Instance);
                props[name] = p;
            }
            return p;
        }
        static PropertyInfo D(string name)
        {
            PropertyInfo p;
            if (!disc.TryGetValue(name, out p))
            {
                p = typeof(InventoryContainer).GetProperty("Discovered" + name, BindingFlags.Public | BindingFlags.Instance);
                disc[name] = p;
            }
            return p;
        }
        public static int Get(InventoryContainer inv, string name)
        {
            PropertyInfo p = P(name);
            return p == null ? 0 : (int)p.GetValue(inv, null);
        }
        public static void Set(InventoryContainer inv, string name, int v)
        {
            PropertyInfo p = P(name);
            if (p != null) p.SetValue(inv, v, null);
            PropertyInfo d = D(name);
            if (d != null && v > 0) d.SetValue(inv, true, null);
        }
    }

    [BepInPlugin("com.research.botrainer", "Bo Path of the Teal Lotus Offline Trainer", "1.1.0")]
    public class BoTrainerPlugin : BaseUnityPlugin
    {
        internal static BoTrainerPlugin Instance;
        internal static Harmony HarmonyInst;
        internal static void Log(string s) { if (Instance != null) Instance.Logger.LogInfo(s); }

        ConfigEntry<Key> keyGod, keyAddMoney, keyInfMoney, keyJump, keySpeed, keyOneHit, keyTea, keyHeal, keyInfItems, keyAddItems, keyHud, keySafe, keyMap;
        ConfigEntry<bool> cfgKodamaMap, cfgCollectMap;
        ConfigEntry<float> cfgTakenAlpha;
        ConfigEntry<string> cfgFall;
        ConfigEntry<int> cfgAddMoney, cfgAddItems, cfgMoneyFloor, cfgItemFloor;
        ConfigEntry<float> cfgSpeed, cfgOneHit;
        ConfigEntry<bool> cfgShowHud;

        bool showHud = true;
        string toast = "";
        float toastUntil;
        bool selfTest;
        bool selfTestRan;
        float playerSeenAt = -1f;
        bool trace;          // TRAINER_TRACE=1: diagnostics only
        float nextTrace;
        float nextZoneDump;
        readonly HashSet<int> dumped = new HashSet<int>();
        bool savedInfiniteMana;
        bool teaOverrideActive;
        int patchedMethodCount;
        readonly List<string> patchErrors = new List<string>();

        void Awake()
        {
            Instance = this;
            gameObject.hideFlags = HideFlags.HideAndDontSave;
            DontDestroyOnLoad(gameObject);

            // NOTE: F2 is a beta-only "bug report" key in the game (does nothing in the release build and is blocked below), so it is free for us.
            keyMap = Config.Bind("Hotkeys", "ToggleCollectibleMap", Key.F2, "Toggle showing EVERY collectible / quest item on the map (Kodama are always shown): chests, omamori, bamboo, ore, silk, roots, petals, crystals, lotus seeds, bunny blossoms. Taken ones are grey and faint.");
            cfgKodamaMap = Config.Bind("Map", "ShowKodamas", true, "Always show all 34 Kodama on the map; taken ones are faded, waiting ones are bright green");
            cfgCollectMap = Config.Bind("Map", "CollectibleMapAtStart", false, "Start with the collectible map (F2) already on");
            cfgTakenAlpha = Config.Bind("Map", "TakenIconOpacity", 0.30f, "Opacity (0.05-1) of icons that are already taken");
            MapTracker.KodamaOn = cfgKodamaMap.Value;
            MapTracker.AllOn = cfgCollectMap.Value;
            MapTracker.TakenAlpha = Mathf.Clamp(cfgTakenAlpha.Value, 0.05f, 1f);
            keyGod = Config.Bind("Hotkeys", "GodMode", Key.F1, "Toggle God Mode (no damage from enemies, projectiles, hazards; spikes/pits only teleport you back)");
            keyAddMoney = Config.Bind("Hotkeys", "AddMoney", Key.F3, "Add fox-flame money (amount in [Values] AddMoneyAmount)");
            keyInfMoney = Config.Bind("Hotkeys", "InfiniteMoney", Key.F4, "Toggle Infinite Money (money is refilled whenever spent)");
            keyJump = Config.Bind("Hotkeys", "UnlimitedJump", Key.F5, "Toggle unlimited air jumps");
            keySpeed = Config.Bind("Hotkeys", "SpeedBoost", Key.F6, "Toggle movement speed multiplier (run + glide)");
            keyOneHit = Config.Bind("Hotkeys", "OneHitKill", Key.F7, "Toggle one-hit kill (every landed hit deals OneHitDamage)");
            keyTea = Config.Bind("Hotkeys", "InfiniteTea", Key.F8, "Toggle infinite tea (healing / Daruma cost no tea)");
            keyHeal = Config.Bind("Hotkeys", "FullHeal", Key.F9, "Restore full health and tea once");
            keyInfItems = Config.Bind("Hotkeys", "InfiniteItems", Key.F10, "Toggle Infinite Items (crafting / shop resources are refilled whenever spent)");
            keyAddItems = Config.Bind("Hotkeys", "AddItems", Key.F11, "Add crafting / shop resources (amount in [Values] AddItemsAmount)");
            keyHud = Config.Bind("Hotkeys", "ToggleHud", Key.F12, "Show/hide the trainer overlay");
            keySafe = Config.Bind("Hotkeys", "ReturnToSafeGround", Key.Home, "Put the player back on the last solid ground he stood on (use if you fell somewhere you cannot climb out of)");
            cfgFall = Config.Bind("GodMode", "FallBehavior", "Ignore", "What God Mode does when you touch a pit / kill zone: Ignore = keep falling freely (default); Rescue = put you back on the last solid ground");
            State.FallIgnore = !string.Equals(cfgFall.Value, "Rescue", StringComparison.OrdinalIgnoreCase);
            cfgAddMoney = Config.Bind("Values", "AddMoneyAmount", 10000, "Money added by the Add Money key");
            cfgAddItems = Config.Bind("Values", "AddItemsAmount", 99, "Amount of each resource added by the Add Items key");
            cfgMoneyFloor = Config.Bind("Values", "InfiniteMoneyLevel", 99999, "Money level maintained while Infinite Money is on");
            cfgItemFloor = Config.Bind("Values", "InfiniteItemsLevel", 99, "Per-resource level maintained while Infinite Items is on");
            cfgSpeed = Config.Bind("Values", "SpeedMultiplier", 2f, "Run / glide speed multiplier while SpeedBoost is on");
            cfgOneHit = Config.Bind("Values", "OneHitDamage", 9999f, "Damage of each hit while One-Hit Kill is on");
            cfgShowHud = Config.Bind("UI", "ShowHud", true, "Show overlay at start");
            showHud = cfgShowHud.Value;
            State.SpeedMultiplier = Mathf.Clamp(cfgSpeed.Value, 0.1f, 10f);
            State.OneHitDamage = Mathf.Max(1f, cfgOneHit.Value);
            State.MoneyFloor = Mathf.Clamp(cfgMoneyFloor.Value, 1, 9999999);
            State.ItemFloor = Mathf.Clamp(cfgItemFloor.Value, 1, 999);

            selfTest = Environment.GetEnvironmentVariable("TRAINER_SELFTEST") == "1";
            trace = Environment.GetEnvironmentVariable("TRAINER_TRACE") == "1";

            HarmonyInst = new Harmony("com.research.botrainer");
            Type[] patches = new Type[]
            {
                typeof(Patch_NewPlayer_CanDamagePlayer), typeof(Patch_NewHealth_DamagePlayer),
                typeof(Patch_NewPlayer_CalculateMoveSpeed), typeof(Patch_Hover_HoverSpeed),
                typeof(Patch_NewPlayer_PerformJumpReset),
                typeof(Patch_Attack_OnEnable), typeof(Patch_Enemy_EnemyLoseHealth),
                typeof(Patch_KarasaDuo_CheckDefeatStatus), typeof(Patch_DuoBR_CheckDefeatStatus), typeof(Patch_Dai_CheckDefeatStatus_Lesser), typeof(Patch_Dai_CheckDefeatStatus),
                typeof(Patch_DaiBR_CheckDefeatStatus_Lesser), typeof(Patch_DaiBR_CheckDefeatStatus), typeof(Patch_IcyHazardTrigger_OnTriggerEnter2D), typeof(Patch_NewPlayer_DamagedFromHazard), typeof(Patch_NewPlayer_DamagedFromKillzone), typeof(Patch_KillZone_OnTriggerStay2D), typeof(Patch_DamagePlayerOnCollision_PerformDamage),
                typeof(Patch_Beta_CanEnterBugReport)
            };
            foreach (Type t in patches)
            {
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
            Logger.LogInfo("Bo Offline Trainer ready. Patched methods: " + patchedMethodCount + (selfTest ? " [SELFTEST]" : ""));
            if (selfTest) WriteReport(false, "starting");
        }

        static bool Pressed(ConfigEntry<Key> k)
        {
            Keyboard kb = Keyboard.current;
            if (kb == null) return false;
            try { return kb[k.Value].wasPressedThisFrame; }
            catch { return false; }
        }

        static NewPlayer PC
        {
            get
            {
                NewPlayer p;
                try { p = NewPlayer.Instance; } catch { return null; }
                if (p == null) return null;
                GameManager gm = null;
                try { gm = GameManager.Instance; } catch { }
                if (gm == null || gm.inventoryContainer == null) return null;
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

        static int AddMoney(InventoryContainer inv, int amount)
        {
            long v = (long)inv.Kitsunebi + amount;
            if (v > 9999999L) v = 9999999L;
            if (v < 0L) v = 0L;
            inv.Kitsunebi = (int)v;
            return inv.Kitsunebi;
        }

        static void AddItems(InventoryContainer inv, int amount)
        {
            foreach (string n in Resources2.Items)
            {
                int v = Resources2.Get(inv, n) + amount;
                if (v > 999) v = 999;
                Resources2.Set(inv, n, v);
            }
        }

        static FieldInfo hudCounterField;
        static float nextHudSync;

        // The in-game fox-flame counter ("x 123") is only rewritten when the game itself picks up / spends flames,
        // so after the trainer changes the value we write the same text the game would.
        internal static void SyncMoneyHud(InventoryContainer inv, bool force)
        {
            try
            {
                if (!force && Time.unscaledTime < nextHudSync) return;
                nextHudSync = Time.unscaledTime + 0.25f;
                UICache uc = UICache.Instance;
                KitsunebiHUDAnimation k = uc == null ? null : uc.KitsunebiWiggle;
                if (k == null) return;
                if (hudCounterField == null) hudCounterField = typeof(KitsunebiHUDAnimation).GetField("counterText", BindingFlags.NonPublic | BindingFlags.Instance);
                TMPro.TMP_Text t = hudCounterField == null ? null : (TMPro.TMP_Text)hudCounterField.GetValue(k);
                if (t == null) return;
                string want = "x " + inv.Kitsunebi;
                if (t.text != want) t.text = want;
            }
            catch (Exception) { }
        }

        // Called every frame while a player exists: keeps toggled features applied.
        internal static void ApplyContinuous(NewPlayer pc)
        {
            InventoryContainer inv = GameManager.Instance.inventoryContainer;
            if (State.InfiniteMoney && inv.Kitsunebi < State.MoneyFloor) inv.Kitsunebi = State.MoneyFloor;
            if (State.InfiniteItems)
                foreach (string n in Resources2.Items)
                    if (Resources2.Get(inv, n) < State.ItemFloor) Resources2.Set(inv, n, State.ItemFloor);
            if (State.UnlimitedJump && !pc.IsGrounded()) pc.canDoubleJump = true;
            SoftRescue.Record(pc);
            SyncMoneyHud(inv, false);
        }

        void ApplyTea()
        {
            GameManager gm = GameManager.Instance;
            if (gm == null) return;
            if (State.InfiniteTea)
            {
                if (!teaOverrideActive) { savedInfiniteMana = gm.InfiniteMana; teaOverrideActive = true; }
                gm.InfiniteMana = true;
            }
            else if (teaOverrideActive)
            {
                gm.InfiniteMana = savedInfiniteMana;
                teaOverrideActive = false;
            }
        }

        void Update()
        {
            if (Pressed(keyHud)) { showHud = !showHud; }
            if (Pressed(keyMap))
            {
                MapTracker.Toggle();
                Toast("Collectibles on map " + OnOff(MapTracker.AllOn) + (MapTracker.AllOn ? "  (" + MapTracker.OtherTaken + "/" + MapTracker.OtherTotal + " taken)" : ""));
            }
            if (Pressed(keyGod)) { State.GodMode = !State.GodMode; Toast("God Mode " + OnOff(State.GodMode)); }
            if (Pressed(keyJump)) { State.UnlimitedJump = !State.UnlimitedJump; Toast("Unlimited Jump " + OnOff(State.UnlimitedJump)); }
            if (Pressed(keySpeed)) { State.SpeedBoost = !State.SpeedBoost; Toast("Speed x" + State.SpeedMultiplier.ToString("0.#") + " " + OnOff(State.SpeedBoost)); }
            if (Pressed(keyOneHit)) { State.OneHitKill = !State.OneHitKill; Toast("One-Hit Kill " + OnOff(State.OneHitKill)); }
            if (Pressed(keyTea)) { State.InfiniteTea = !State.InfiniteTea; Toast("Infinite Tea " + OnOff(State.InfiniteTea)); }
            if (Pressed(keyInfMoney)) { State.InfiniteMoney = !State.InfiniteMoney; Toast("Infinite Money " + OnOff(State.InfiniteMoney)); }
            if (Pressed(keyInfItems)) { State.InfiniteItems = !State.InfiniteItems; Toast("Infinite Items " + OnOff(State.InfiniteItems)); }

            NewPlayer pc = PC;
            if (pc == null) { playerSeenAt = -1f; return; }
            if (playerSeenAt < 0f) playerSeenAt = Time.unscaledTime;

            if (trace && Time.unscaledTime >= nextTrace)
            {
                nextTrace = Time.unscaledTime + 0.1f;
                try
                {
                    Logger.LogInfo("TRACE t=" + Time.unscaledTime.ToString("0.00") + " x=" + pc.transform.position.x.ToString("0.00") + " y=" + pc.transform.position.y.ToString("0.00") +
                        " grounded=" + pc.IsGrounded() + " cdj=" + pc.canDoubleJump + " money=" + GameManager.Instance.inventoryContainer.Kitsunebi + " speed=" + State.SpeedBoost + " jump=" + State.UnlimitedJump +
                        " dying=" + pc.dying + " respawning=" + pc.respawning + " hp=" + GameManager.Instance.inventoryContainer.CurrentHealth +
                        " trail=" + SoftRescue.TrailCount + " cannotMove=" + pc.cannotMove + " hit=" + pc.PlayerHit + " hitKZ=" + pc.PlayerHitFromKillzone + " changing=" + GameManager.Instance.changingScene + " scene=" + SoftRescue.SceneName);
                }
                catch (Exception e) { Logger.LogWarning("trace: " + e.Message); }
                try
                {
                    string cmdPath = Path.Combine(Paths.GameRootPath, "trainer_cmd.txt");
                    if (File.Exists(cmdPath))
                    {
                        string[] w = File.ReadAllText(cmdPath).Trim().Split(' ');
                        File.Delete(cmdPath);
                        if (w.Length == 1 && w[0] == "kz") { Logger.LogInfo("TRACE cmd kz (DamagedFromKillzone)"); pc.DamagedFromKillzone(); }
                        if (w.Length == 3 && w[0] == "tp")
                        {
                            Rigidbody2D rb = pc.GetComponent<Rigidbody2D>();
                            Vector3 p = new Vector3(float.Parse(w[1], System.Globalization.CultureInfo.InvariantCulture), float.Parse(w[2], System.Globalization.CultureInfo.InvariantCulture), pc.transform.position.z);
                            pc.transform.position = p;
                            if (rb != null) { rb.position = p; rb.velocity = Vector2.zero; }
                            Logger.LogInfo("TRACE cmd tp " + p);
                        }
                    }
                }
                catch (Exception e) { Logger.LogWarning("cmd: " + e.Message); }
                if (Time.unscaledTime >= nextZoneDump)
                {
                    nextZoneDump = Time.unscaledTime + 3f;
                    try
                    {
                        foreach (KillZone kz in UnityEngine.Object.FindObjectsOfType<KillZone>())
                        {
                            int id = kz.GetInstanceID();
                            if (!dumped.Add(id)) continue;
                            FieldInfo tf = typeof(KillZone).GetField("type", BindingFlags.NonPublic | BindingFlags.Instance);
                            Collider2D cl = kz.GetComponent<Collider2D>();
                            Logger.LogInfo("ZONE KillZone name=" + kz.name + " parent=" + (kz.transform.parent == null ? "-" : kz.transform.parent.name) + " type=" + tf.GetValue(kz) +
                                " bounds=" + (cl == null ? "none" : cl.bounds.center.ToString("F1") + " size " + cl.bounds.size.ToString("F1")) + " scene=" + kz.gameObject.scene.name);
                        }
                        foreach (Collider2D cc in UnityEngine.Object.FindObjectsOfType<Collider2D>())
                        {
                            string nm = cc.name.ToLowerInvariant();
                            if (!(nm.Contains("crystal") || nm.Contains("shard") || nm.Contains("ice") || nm.Contains("white"))) continue;
                            int id = cc.GetInstanceID();
                            if (!dumped.Add(id)) continue;
                            StringBuilder cb = new StringBuilder();
                            foreach (Component co in cc.GetComponents<Component>()) cb.Append(co.GetType().Name + ",");
                            Logger.LogInfo("ZONE Collider name=" + cc.name + " trigger=" + cc.isTrigger + " comps=" + cb + " bounds=" + cc.bounds.center.ToString("F1") + " size " + cc.bounds.size.ToString("F1") + " scene=" + cc.gameObject.scene.name);
                        }
                        foreach (IcyHazardTrigger ih in UnityEngine.Object.FindObjectsOfType<IcyHazardTrigger>())
                        {
                            int id = ih.GetInstanceID();
                            if (!dumped.Add(id)) continue;
                            Collider2D cl = ih.GetComponent<Collider2D>();
                            Logger.LogInfo("ZONE IcyHazard name=" + ih.name + " bounds=" + (cl == null ? "none" : cl.bounds.center.ToString("F1") + " size " + cl.bounds.size.ToString("F1")) + " scene=" + ih.gameObject.scene.name);
                        }
                        foreach (DamagePlayerOnCollision d in UnityEngine.Object.FindObjectsOfType<DamagePlayerOnCollision>())
                        {
                            int id = d.GetInstanceID();
                            if (!dumped.Add(id)) continue;
                            FieldInfo sf = typeof(DamagePlayerOnCollision).GetField("specialCase", BindingFlags.NonPublic | BindingFlags.Instance);
                            if (sf.GetValue(d).ToString() != "InstantKill") continue;
                            Collider2D cl = d.GetComponent<Collider2D>();
                            Logger.LogInfo("ZONE InstantKill name=" + d.name + " parent=" + (d.transform.parent == null ? "-" : d.transform.parent.name) +
                                " bounds=" + (cl == null ? "none" : cl.bounds.center.ToString("F1") + " size " + cl.bounds.size.ToString("F1")) + " scene=" + d.gameObject.scene.name);
                        }
                    }
                    catch (Exception e) { Logger.LogWarning("zone dump: " + e.Message); }
                }
            }

            try
            {
                InventoryContainer inv = GameManager.Instance.inventoryContainer;
                if (Pressed(keyAddMoney))
                {
                    int before = inv.Kitsunebi;
                    int after = AddMoney(inv, cfgAddMoney.Value);
                    Toast("Money +" + (after - before) + " (now " + after.ToString("n0") + ")");
                }
                if (Pressed(keyAddItems))
                {
                    AddItems(inv, cfgAddItems.Value);
                    Toast("Items +" + cfgAddItems.Value + " each");
                }
                if (Pressed(keySafe))
                {
                    if (SoftRescue.TryRescue(pc, true)) Toast("Returned to safe ground");
                    else { pc.RespawnAtCheckpointNoDamage(); Toast("No safe ground recorded - sent to the last checkpoint"); }
                }
                if (Pressed(keyHeal))
                {
                    NewHealth h = pc.GetComponent<NewHealth>();
                    if (h != null && !pc.dying) h.AddAllHealth();
                    NewMana m = pc.GetComponent<NewMana>();
                    if (m != null) { try { m.AddAllMana(false); } catch (Exception) { } }
                    Toast("Health & tea restored");
                }
                ApplyContinuous(pc);
                ApplyTea();
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

        // The map icons are tracked after every other script has run this frame (the game re-hides secret icons when the map opens).
        void LateUpdate()
        {
            try { MapTracker.Tick(); }
            catch (Exception e) { MapTracker.LastError = e.Message; }
        }

        void OnGUI()
        {
            if (!showHud) return;
            GUI.depth = 0;
            float sc = Mathf.Max(1f, Screen.height / 720f);
            GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(sc, sc, 1f));
            List<string> lines = new List<string>(new string[]
            {
                "BO TRAINER (offline)  [" + keyHud.Value + "] hide",
                "[" + keyGod.Value + "] God Mode ......... " + OnOff(State.GodMode),
                "[" + keyAddMoney.Value + "] Add Money +" + cfgAddMoney.Value,
                "[" + keyInfMoney.Value + "] Infinite Money ... " + OnOff(State.InfiniteMoney),
                "[" + keyJump.Value + "] Unlimited Jump .. " + OnOff(State.UnlimitedJump),
                "[" + keySpeed.Value + "] Speed x" + State.SpeedMultiplier.ToString("0.#") + " ........ " + OnOff(State.SpeedBoost),
                "[" + keyOneHit.Value + "] One-Hit Kill ...... " + OnOff(State.OneHitKill),
                "[" + keyTea.Value + "] Infinite Tea ..... " + OnOff(State.InfiniteTea),
                "[" + keyHeal.Value + "] Full Heal + Tea",
                "[" + keyInfItems.Value + "] Infinite Items ... " + OnOff(State.InfiniteItems),
                "[" + keyAddItems.Value + "] Add Items +" + cfgAddItems.Value + " each",
                "[" + keySafe.Value + "] Return to safe ground",
                "[" + keyMap.Value + "] Collectibles on map " + OnOff(MapTracker.AllOn),
                "Kodama on map: " + MapTracker.KodamaTaken + "/" + MapTracker.KodamaTotal + " taken" + (MapTracker.KodamaTotal == 0 ? " (open a game)" : "")
            });
            if (MapTracker.AllOn) lines.Add("Items on map: " + MapTracker.OtherTaken + "/" + MapTracker.OtherTotal + " taken");
            float h = 8 + lines.Count * 18 + (Time.unscaledTime < toastUntil ? 22 : 0);
            GUI.Box(new Rect(8, 8, 270, h), GUIContent.none);
            for (int i = 0; i < lines.Count; i++)
                GUI.Label(new Rect(14, 10 + i * 18, 262, 20), lines[i]);
            if (Time.unscaledTime < toastUntil)
                GUI.Label(new Rect(14, 10 + lines.Count * 18, 262, 20), ">> " + toast);
        }

        // ---------------- Self-test (TRAINER_SELFTEST=1) ----------------
        class FeatureResult
        {
            public string Branch, Name, HookStatus = "UNKNOWN", Status = "PENDING", Detail = "";
        }
        readonly List<FeatureResult> results = new List<FeatureResult>();

        static bool IsPatched(Type t, string name)
        {
            return IsPatched(t, name, null);
        }
        static bool IsPatched(Type t, string name, Type[] sig)
        {
            try
            {
                // every overload of `name` declared on t must carry a patch
                List<MethodBase> ms = new List<MethodBase>();
                if (sig != null) ms.Add(AccessTools.Method(t, name, sig));
                else foreach (MethodInfo m in AccessTools.GetDeclaredMethods(t)) if (m.Name == name) ms.Add(m);
                if (ms.Count == 0) return false;
                foreach (MethodBase mb in ms)
                {
                    if (mb == null) return false;
                    Patches info = Harmony.GetPatchInfo(mb);
                    if (info == null || (info.Prefixes.Count + info.Postfixes.Count) == 0) return false;
                }
                return true;
            }
            catch { return false; }
        }

        FeatureResult Add(string branch, string name, bool hooked)
        {
            FeatureResult r = new FeatureResult();
            r.Branch = branch; r.Name = name;
            r.HookStatus = hooked ? "HOOKED" : "HOOK_MISSING";
            results.Add(r);
            return r;
        }

        // returns number of 9999-damage hits needed to defeat both tengu of a 300 HP shared pool, or -1 if the fight can never finish
        static int SimDuoHits(bool clamp)
        {
            float pool = 300f, first = 300f * 0.09f; bool a = false, b = false;
            for (int hit = 1; hit <= 5; hit++)
            {
                float dmg = 9999f;
                if (clamp && !a) dmg = Math.Min(dmg, PooledBoss.StageCap(pool, first));
                if (pool <= 0f) continue;                         // "NoHealth" early return of the game
                pool -= dmg;
                if (a) { if (pool <= 0f) b = true; }
                else if (pool <= first) a = true;
                if (a && b) return hit;
            }
            return -1;
        }

        void RunSelfTest(NewPlayer pc)
        {
            results.Clear();
            bool sg = State.GodMode, sm = State.InfiniteMoney, si = State.InfiniteItems, sj = State.UnlimitedJump,
                 ss = State.SpeedBoost, so = State.OneHitKill, st = State.InfiniteTea;
            GameManager gm = GameManager.Instance;
            InventoryContainer inv = gm.inventoryContainer;
            NewHealth nh = pc.GetComponent<NewHealth>();

            // ---- COMBAT: God Mode ----
            FeatureResult rg = Add("SUBAGENT-COMBAT-01", "God Mode",
                IsPatched(typeof(NewPlayer), "CanDamagePlayer") && IsPatched(typeof(NewHealth), "DamagePlayer") &&
                IsPatched(typeof(NewPlayer), "DamagedFromHazard") && IsPatched(typeof(NewPlayer), "DamagedFromKillzone") && IsPatched(typeof(IcyHazardTrigger), "OnTriggerEnter2D") && IsPatched(typeof(KillZone), "OnTriggerStay2D") && IsPatched(typeof(DamagePlayerOnCollision), "PerformDamage"));
            try
            {
                int hp = inv.CurrentHealth, maxHp = inv.CalculateMaxHealth();
                bool inv0 = maxHp >= 1 && maxHp <= 20 && hp >= 0 && hp <= maxHp;
                State.GodMode = true;
                bool canOn = pc.CanDamagePlayer();
                int hpBefore = inv.CurrentHealth;
                if (nh != null) nh.DamagePlayer(1, false);
                bool unchanged = inv.CurrentHealth == hpBefore;
                State.GodMode = sg;
                bool spikesSafe = !GodTrap.IsPitLike(null, "Spikes") && !GodTrap.IsPitLike(null, "PuzzleSpikes") && GodTrap.IsPitLike(null, "Autoscroller");
                bool ok = rg.HookStatus == "HOOKED" && inv0 && !canOn && unchanged && nh != null && spikesSafe;
                rg.Status = ok ? "PASS" : "FAIL";
                rg.Detail = "hp=" + hp + "/" + maxHp + " invariant=" + inv0 + " CanDamagePlayer(on)=" + canOn + " DamagePlayer_no_change=" + unchanged + " spike_zones_ignored=" + spikesSafe;
            }
            catch (Exception e) { rg.Status = "FAIL"; rg.Detail = e.Message; State.GodMode = sg; }

            // ---- COMBAT: One-Hit Kill ----
            FeatureResult ro = Add("SUBAGENT-COMBAT-01", "One-Hit Kill",
                IsPatched(typeof(Attack), "OnEnable") && IsPatched(typeof(Enemy), "EnemyLoseHealth") &&
                IsPatched(typeof(KarasaTenguDuoController), "CheckDefeatStatus") && IsPatched(typeof(DaiTenguController), "CheckDefeatStatus") &&
                IsPatched(typeof(TenguDuoControllerBR), "CheckDefeatStatus") && IsPatched(typeof(DaitenguBRController), "CheckDefeatStatus"));
            try
            {
                State.OneHitKill = false;
                float d0 = State.OhkDamage(1f);
                State.OneHitKill = true;
                float d1 = State.OhkDamage(1f);
                float d2 = State.OhkDamage(0f);
                State.OneHitKill = so;
                // replay of the Duo shared-pool logic (KarasaTenguDuoController.CheckDefeatStatus): with the clamp a 9999 hit must finish
                // the first tengu only, the second 9999 hit the fight; without the clamp the first hit strands the boss
                int hitsWith = SimDuoHits(true), hitsWithout = SimDuoHits(false);
                bool ok = Math.Abs(d0 - 1f) < 0.0001f && d1 >= State.OneHitDamage && d2 == 0f && hitsWith == 2 && hitsWithout == -1;
                ro.Status = (ro.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                ro.Detail = "damage off=" + d0 + " on=" + d1 + " zero_stays_zero=" + (d2 == 0f) + " duo_pool_hits_to_kill(clamped)=" + hitsWith + " (unclamped=" + (hitsWithout < 0 ? "never dies" : hitsWithout.ToString()) + ")";
            }
            catch (Exception e) { ro.Status = "FAIL"; ro.Detail = e.Message; State.OneHitKill = so; }

            // ---- ECONOMY: Add Money (delta) ----
            FeatureResult re = Add("SUBAGENT-ECONOMY-02", "Add Money", inv != null);
            int moneyOrig = inv.Kitsunebi;
            try
            {
                bool inv0 = moneyOrig >= 0 && moneyOrig <= 9999999;
                int after = AddMoney(inv, 10);
                bool plus = after == moneyOrig + 10 && inv.Kitsunebi == moneyOrig + 10;
                inv.Kitsunebi = moneyOrig;
                bool back = inv.Kitsunebi == moneyOrig;
                re.Status = (inv0 && plus && back) ? "PASS" : "FAIL";
                re.Detail = "money_before=" + moneyOrig + " +10=>" + after + " restored=" + back + " invariant=" + inv0;
            }
            catch (Exception e) { re.Status = "FAIL"; re.Detail = e.Message; inv.Kitsunebi = moneyOrig; }

            // ---- ECONOMY: Infinite Money ----
            FeatureResult rm = Add("SUBAGENT-ECONOMY-02", "Infinite Money", inv != null);
            try
            {
                inv.Kitsunebi = 3;
                State.InfiniteMoney = true;
                ApplyContinuous(pc);
                bool filled = inv.Kitsunebi >= State.MoneyFloor;
                inv.Kitsunebi -= 50;                     // simulate a purchase through the real setter
                ApplyContinuous(pc);
                bool refilled = inv.Kitsunebi >= State.MoneyFloor;
                State.InfiniteMoney = false;
                inv.Kitsunebi = 3;
                ApplyContinuous(pc);
                bool offLeavesAlone = inv.Kitsunebi == 3;
                inv.Kitsunebi = moneyOrig;
                State.InfiniteMoney = sm;
                rm.Status = (filled && refilled && offLeavesAlone) ? "PASS" : "FAIL";
                rm.Detail = "filled=" + filled + " refilled_after_spend=" + refilled + " off_leaves_alone=" + offLeavesAlone + " level=" + State.MoneyFloor;
            }
            catch (Exception e) { rm.Status = "FAIL"; rm.Detail = e.Message; inv.Kitsunebi = moneyOrig; State.InfiniteMoney = sm; }

            // ---- ECONOMY: Add Items / Infinite Items ----
            FeatureResult ra = Add("SUBAGENT-ECONOMY-02", "Add Items", inv != null);
            FeatureResult rit = Add("SUBAGENT-ECONOMY-02", "Infinite Items", inv != null);
            int[] origItems = new int[Resources2.Items.Length];
            for (int i = 0; i < origItems.Length; i++) origItems[i] = Resources2.Get(inv, Resources2.Items[i]);
            try
            {
                AddItems(inv, 5);
                bool plus = true;
                for (int i = 0; i < origItems.Length; i++) if (Resources2.Get(inv, Resources2.Items[i]) != Math.Min(999, origItems[i] + 5)) plus = false;
                for (int i = 0; i < origItems.Length; i++) Resources2.Set(inv, Resources2.Items[i], origItems[i]);
                bool back = true;
                for (int i = 0; i < origItems.Length; i++) if (Resources2.Get(inv, Resources2.Items[i]) != origItems[i]) back = false;
                ra.Status = (plus && back) ? "PASS" : "FAIL";
                ra.Detail = "resources=" + Resources2.Items.Length + " +5 each ok=" + plus + " restored=" + back;
            }
            catch (Exception e) { ra.Status = "FAIL"; ra.Detail = e.Message; }
            try
            {
                for (int i = 0; i < origItems.Length; i++) Resources2.Set(inv, Resources2.Items[i], 0);
                State.InfiniteItems = true;
                ApplyContinuous(pc);
                bool filled = true;
                for (int i = 0; i < origItems.Length; i++) if (Resources2.Get(inv, Resources2.Items[i]) < State.ItemFloor) filled = false;
                Resources2.Set(inv, "Bamboo", Resources2.Get(inv, "Bamboo") - 7);
                ApplyContinuous(pc);
                bool refilled = Resources2.Get(inv, "Bamboo") >= State.ItemFloor;
                State.InfiniteItems = si;
                rit.Status = (filled && refilled) ? "PASS" : "FAIL";
                rit.Detail = "filled=" + filled + " refilled_after_spend=" + refilled + " level=" + State.ItemFloor;
            }
            catch (Exception e) { rit.Status = "FAIL"; rit.Detail = e.Message; State.InfiniteItems = si; }
            for (int i = 0; i < origItems.Length; i++) { try { Resources2.Set(inv, Resources2.Items[i], origItems[i]); } catch (Exception) { } }

            // ---- MOVEMENT: Speed multiplier ----
            FeatureResult rs = Add("SUBAGENT-MOVEMENT-03", "Speed Multiplier",
                IsPatched(typeof(NewPlayer), "CalculateMoveSpeed") && IsPatched(typeof(Hover), "HoverSpeed"));
            try
            {
                State.SpeedBoost = false;
                float v0 = pc.CalculateMoveSpeed(20f);
                State.SpeedBoost = true;
                float v1 = pc.CalculateMoveSpeed(20f);
                State.SpeedBoost = ss;
                bool ok = v0 == 0f ? v1 == 0f : Math.Abs(v1 - v0 * State.SpeedMultiplier) < 0.001f;
                rs.Status = (rs.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                rs.Detail = "CalculateMoveSpeed(20) off=" + v0 + " on=" + v1 + " mult=" + State.SpeedMultiplier;
            }
            catch (Exception e) { rs.Status = "FAIL"; rs.Detail = e.Message; State.SpeedBoost = ss; }

            // ---- JUMP: Unlimited jump ----
            FeatureResult rj = Add("SUBAGENT-JUMP-04", "Unlimited Jump", IsPatched(typeof(NewPlayer), "PerformJumpReset"));
            try
            {
                bool c0 = pc.canDoubleJump;
                State.UnlimitedJump = true;
                pc.canDoubleJump = false;
                Patch_NewPlayer_PerformJumpReset.Postfix(pc);
                bool rearmed = pc.canDoubleJump;
                State.UnlimitedJump = false;
                pc.canDoubleJump = false;
                Patch_NewPlayer_PerformJumpReset.Postfix(pc);
                bool untouched = !pc.canDoubleJump;
                pc.canDoubleJump = c0;
                State.UnlimitedJump = sj;
                rj.Status = (rj.HookStatus == "HOOKED" && rearmed && untouched) ? "PASS" : "FAIL";
                rj.Detail = "rearm_after_air_jump=" + rearmed + " untouched_when_off=" + untouched;
            }
            catch (Exception e) { rj.Status = "FAIL"; rj.Detail = e.Message; State.UnlimitedJump = sj; }

            // ---- TEA: Infinite tea ----
            FeatureResult rt = Add("SUBAGENT-TEA-05", "Infinite Tea", gm != null);
            try
            {
                bool orig = gm.InfiniteMana;
                State.InfiniteTea = true;
                ApplyTea();
                bool on = gm.InfiniteMana;
                State.InfiniteTea = false;
                ApplyTea();
                bool restored = gm.InfiniteMana == orig;
                State.InfiniteTea = st;
                rt.Status = (on && restored) ? "PASS" : "FAIL";
                rt.Detail = "GameManager.InfiniteMana on=" + on + " restored_to_original=" + restored;
            }
            catch (Exception e) { rt.Status = "FAIL"; rt.Detail = e.Message; State.InfiniteTea = st; }

            // ---- MAP: Kodama tracker + collectible map ----
            FeatureResult rk = Add("SUBAGENT-MAP-06", "Kodama & Collectible Map", IsPatched(typeof(BetaPlayerDataManager), "CanEnterBugReport"));
            try
            {
                string md;
                bool mok = MapTracker.SelfTest(out md);
                rk.Status = (rk.HookStatus == "HOOKED" && mok) ? "PASS" : "FAIL";
                rk.Detail = md;
            }
            catch (Exception e) { rk.Status = "FAIL"; rk.Detail = e.Message; }

            State.GodMode = sg; State.InfiniteMoney = sm; State.InfiniteItems = si; State.UnlimitedJump = sj;
            State.SpeedBoost = ss; State.OneHitKill = so; State.InfiniteTea = st;
            WriteReport(true, "done");
        }

        void WriteReport(bool runtime, string note)
        {
            try
            {
                bool all = runtime && results.Count > 0 && patchErrors.Count == 0;
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

    // MAP: F2 is the beta-only "bug report" key (BetaPlayerDataManager.GoToBugReport opens a web form). It is already disabled in release
    // builds (!GM.IsRelease); this makes sure it can never open a browser while F2 is used for the collectible map.
    [HarmonyPatch(typeof(BetaPlayerDataManager), "CanEnterBugReport")]
    public static class Patch_Beta_CanEnterBugReport
    {
        static bool Prefix(ref bool __result)
        {
            __result = false;
            return false;
        }
    }

    // ================= Harmony patches =================

    // COMBAT: every enemy / projectile / hazard collider asks this before calling DamagePlayer*().
    [HarmonyPatch(typeof(NewPlayer), "CanDamagePlayer")]
    public static class Patch_NewPlayer_CanDamagePlayer
    {
        static void Postfix(ref bool __result)
        {
            if (State.GodMode) __result = false;
        }
    }

    // COMBAT: HP sink. Also reached from killzones / spikes (HazardOrKillzoneDamage): with God Mode the HP is kept
    // but the game still respawns the player at the checkpoint, so pits never trap you.
    [HarmonyPatch(typeof(NewHealth), "DamagePlayer", new Type[] { typeof(int), typeof(bool) })]
    public static class Patch_NewHealth_DamagePlayer
    {
        static bool Prefix()
        {
            return !State.GodMode;
        }
    }

    // MOVEMENT: ground / air run speed (PhysicsObject sets velocity.x = targetVelocity.x).
    [HarmonyPatch(typeof(NewPlayer), "CalculateMoveSpeed")]
    public static class Patch_NewPlayer_CalculateMoveSpeed
    {
        static void Postfix(ref float __result)
        {
            if (State.SpeedBoost) __result *= State.SpeedMultiplier;
        }
    }

    // MOVEMENT: glide (hover) speed.
    [HarmonyPatch(typeof(Hover), "HoverSpeed")]
    public static class Patch_Hover_HoverSpeed
    {
        static void Postfix(ref float __result)
        {
            if (State.SpeedBoost) __result *= State.SpeedMultiplier;
        }
    }

    // JUMP: PerformJumpReset consumes the air jump (canDoubleJump = false); give it straight back.
    [HarmonyPatch(typeof(NewPlayer), "PerformJumpReset")]
    public static class Patch_NewPlayer_PerformJumpReset
    {
        public static void Postfix(NewPlayer __instance)
        {
            if (State.UnlimitedJump && __instance != null) __instance.canDoubleJump = true;
        }
    }

    // DAMAGE: staff damage is cached into EnemiesManager.CurrentStaffDamage when the attack hitbox is enabled.
    [HarmonyPatch(typeof(Attack), "OnEnable")]
    public static class Patch_Attack_OnEnable
    {
        static void Postfix()
        {
            if (!State.OneHitKill) return;
            GameManager gm = GameManager.Instance;
            if (gm == null || gm.enemiesManager == null) return;
            gm.enemiesManager.CurrentStaffDamage = State.OhkDamage(gm.enemiesManager.CurrentStaffDamage);
        }
    }

    // DAMAGE: regular enemies subtract their private currentStaffDamage (staff, Daruma and bat hits all end up here).
    [HarmonyPatch(typeof(Enemy), "EnemyLoseHealth")]
    public static class Patch_Enemy_EnemyLoseHealth
    {
        static void Prefix(ref float ___currentStaffDamage)
        {
            ___currentStaffDamage = State.OhkDamage(___currentStaffDamage);
        }
    }

    // TRAPS (God Mode): lasers, fireballs, wall of fire, moving-platform crush -> DamagedFromHazard() starts the
    // "dead" animation + checkpoint respawn. With God Mode they are ignored completely.
    [HarmonyPatch(typeof(NewPlayer), "DamagedFromHazard")]
    public static class Patch_NewPlayer_DamagedFromHazard
    {
        static bool Prefix()
        {
            return !State.GodMode;
        }
    }

    // TRAPS (God Mode): KillZone triggers call DamagedFromKillzone() every physics tick while the player overlaps.
    // Spike zones are ignored; zones that look like bottomless pits / level boundaries keep the vanilla respawn so you are
    // never stranded. See GodTrap.IsPitLike.
    [HarmonyPatch(typeof(KillZone), "OnTriggerStay2D")]
    public static class Patch_KillZone_OnTriggerStay2D
    {
        static FieldInfo typeField = typeof(KillZone).GetField("type", BindingFlags.NonPublic | BindingFlags.Instance);
        static bool Prefix(KillZone __instance)
        {
            if (!State.GodMode) return true;
            object t = null;
            try { t = typeField == null ? null : typeField.GetValue(__instance); } catch (Exception) { }
            if (!GodTrap.IsPitLike(__instance, t)) return false;                       // spike patch
            string ts = t == null ? "" : t.ToString();
            if (State.FallIgnore && ts != "TempRespawnTrigger" && ts != "Autoscroller" && !SoftRescue.Scripted()) return false;   // pit: just keep falling
            return true;
        }
    }

    // TRAPS (God Mode): "InstantKill" damage colliders (spike balls, thorns ...) -> DamagedFromKillzone().
    [HarmonyPatch(typeof(DamagePlayerOnCollision), "PerformDamage")]
    public static class Patch_DamagePlayerOnCollision_PerformDamage
    {
        static FieldInfo caseField = typeof(DamagePlayerOnCollision).GetField("specialCase", BindingFlags.NonPublic | BindingFlags.Instance);
        static bool Prefix(DamagePlayerOnCollision __instance)
        {
            if (!State.GodMode) return true;
            try
            {
                object c = caseField == null ? null : caseField.GetValue(__instance);
                if (c != null && c.ToString() == "InstantKill") return false;
            }
            catch (Exception) { }
            return true;
        }
    }

    public static class GodTrap
    {
        public static float PitMinSize = 12f;       // KillZone colliders at least this wide/tall are treated as pits/boundaries

        // true => keep the game's own behaviour (respawn at checkpoint); false => harmless in God Mode
        public static bool IsPitLike(KillZone kz, object type)
        {
            string t = type == null ? "" : type.ToString();
            if (t == "Spikes" || t == "PuzzleSpikes") return false;
            if (t == "Autoscroller" || t == "TempRespawnTrigger") return true;   // scripted chase / puzzle respawns
            try
            {
                Collider2D c = kz == null ? null : kz.GetComponent<Collider2D>();
                if (c != null && Math.Max(c.bounds.size.x, c.bounds.size.y) < PitMinSize) return false;   // small "Standard" zone = a spike patch
            }
            catch (Exception) { }
            return true;
        }
    }

    // FALLS / KILL ZONES (God Mode): every pit, crush and kill-zone path ends in NewPlayer.DamagedFromKillzone(), which plays the
    // "dead" animation, fades out and teleports to the last checkpoint. In God Mode we instead put the player back on the last
    // solid ground he stood on (no animation, no HP loss, no fade). Scripted scenes keep the vanilla behaviour.
    [HarmonyPatch(typeof(NewPlayer), "DamagedFromKillzone")]
    public static class Patch_NewPlayer_DamagedFromKillzone
    {
        static bool Prefix(NewPlayer __instance)
        {
            if (!State.GodMode) return true;
            return !SoftRescue.TryRescue(__instance);
        }
    }

    public static class SoftRescue
    {
        struct Spot { public Vector3 Pos; public float T; }
        static readonly List<Spot> trail = new List<Spot>();
        static int playerId;
        static string sceneName = "";
        static float nextRecord;
        static float lastRescueAt = -100f;
        static int chain;
        public static int RescueCount;
        public static int TrailCount { get { return trail.Count; } }
        public static string SceneName { get { return sceneName; } }

        public static bool Scripted()
        {
            try { return ScriptedScene(GameManager.Instance); } catch (Exception) { return true; }
        }

        static bool ScriptedScene(GameManager gm)
        {
            try
            {
                SceneNameManager s = gm.sceneNameManager;
                string a = s.activeSceneName;
                return a == s.KBAscent || a == s.GashaBossFight || a == s.SBWave || a == s.IMCShogunChase || s.IsBossRushScene();
            }
            catch (Exception) { return true; }
        }

        // name of the game method that triggered the rescue (diagnostics for the log)
        static string Caller()
        {
            try
            {
                System.Diagnostics.StackFrame[] fr = new System.Diagnostics.StackTrace(2, false).GetFrames();
                if (fr == null) return "?";
                StringBuilder sb = new StringBuilder();
                int n = 0;
                foreach (System.Diagnostics.StackFrame f in fr)
                {
                    MethodBase m = f.GetMethod();
                    if (m == null || m.DeclaringType == null) continue;
                    string tn = m.DeclaringType.Name;
                    if (tn == "NewPlayer" || tn.StartsWith("Patch_") || tn == "SoftRescue" || tn.StartsWith("DMD")) continue;
                    if (n > 0) sb.Append(" < ");
                    sb.Append(tn + "." + m.Name);
                    if (++n >= 2) break;
                }
                return n == 0 ? "?" : sb.ToString();
            }
            catch (Exception) { return "?"; }
        }

        // called every frame while a player exists
        public static void Record(NewPlayer pc)
        {
            GameManager gm = GameManager.Instance;
            string sc = "";
            try { sc = gm.sceneNameManager.activeSceneName; } catch (Exception) { }
            if (pc.GetInstanceID() != playerId || sc != sceneName) { playerId = pc.GetInstanceID(); sceneName = sc; trail.Clear(); chain = 0; }
            if (Time.unscaledTime < nextRecord) return;
            nextRecord = Time.unscaledTime + 0.25f;
            if (!pc.IsGrounded() || pc.dying || pc.respawning || pc.PlayerHit || pc.PlayerHitFromKillzone || pc.cannotMove || gm.changingScene) return;
            Spot s; s.Pos = pc.transform.position; s.T = Time.unscaledTime;
            trail.Add(s);
            while (trail.Count > 48) trail.RemoveAt(0);
        }

        // true => the player was moved to safe ground and the game's own death/respawn must be skipped
        public static bool TryRescue(NewPlayer pc) { return TryRescue(pc, false); }
        public static bool TryRescue(NewPlayer pc, bool manual)
        {
            try
            {
                GameManager gm = GameManager.Instance;
                if (pc == null || gm == null || pc.dying || pc.respawning || gm.changingScene || (!manual && ScriptedScene(gm))) return false;
                if (trail.Count == 0) return false;
                float now = Time.unscaledTime;
                chain = (now - lastRescueAt < 6f) ? chain + 1 : 0;      // repeated falls from the same spot walk further back along the trail
                float age = 1.0f + 2.5f * chain;
                int idx = -1;
                for (int i = trail.Count - 1; i >= 0; i--) if (now - trail[i].T >= age) { idx = i; break; }
                if (idx < 0) idx = 0;
                Vector3 target = trail[idx].Pos;
                lastRescueAt = now;
                RescueCount++;

                Hover hv = pc.GetComponent<Hover>();
                if (hv != null && hv.hovering) hv.CancelHover();
                Rigidbody2D rb = pc.GetComponent<Rigidbody2D>();
                if (NewVCManager.Instance != null) NewVCManager.Instance.CameraWillSnapAtCheckpoint();
                pc.transform.position = target;
                if (rb != null) { rb.position = target; rb.velocity = Vector2.zero; }
                pc.ResetPhysicsObjectVelocity();
                pc.OverrideForcedVelocity();
                if (NewVCManager.Instance != null) { NewVCManager.Instance.SnapCameraAtCheckpoint(); NewVCManager.Instance.CheckpointCameraSnap = false; }
                BoTrainerPlugin.Log("God Mode: kill-zone call from " + Caller() + " -> returned to safe ground (" + target.x.ToString("0.0") + ", " + target.y.ToString("0.0") + ")");
                return true;
            }
            catch (Exception e)
            {
                BoTrainerPlugin.Log("SoftRescue failed, using the game's respawn: " + e.Message);
                return false;
            }
        }
    }

    // ---------------------------------------------------------------------------------------------------------------
    // POOLED / MULTI-STAGE BOSSES (Karasa Tengu Duo, Daitengu + lesser tengu, and their Boss Rush versions).
    // The fight is driven by ONE shared health pool inside a controller. Every staff hit calls CheckDefeatStatus():
    //   pool -= damage; then, depending on the pool level, the first / second lesser tengu is defeated (or the Daitengu);
    //   once pool <= 0 the method returns early on every later hit ("NoHealth").
    // A 9999-damage one-hit-kill therefore empties the pool in a single hit, defeats only ONE stage and every later hit is
    // ignored, so the boss can never die. While One-Hit Kill is on, clamp each hit so that it completes at most the
    // current stage; the next hit completes the next stage (Duo = 2 hits, Daitengu fight = 3 hits).
    // ---------------------------------------------------------------------------------------------------------------
    public static class PooledBoss
    {
        const float Eps = 0.01f;

        // largest damage that still leaves the pool just under `threshold` (>0) -> finishes exactly one stage
        public static float StageCap(float pool, float threshold)
        {
            return Math.Max(pool - threshold + Eps, Eps);
        }

        static object Get(object o, string field)
        {
            FieldInfo f = AccessTools.Field(o.GetType(), field);
            return f == null ? null : f.GetValue(o);
        }
        static float Pool(object ctrl)
        {
            object v = Get(ctrl, "currentHealthInPool");
            return v is float ? (float)v : float.NaN;
        }
        static float Phase(object ctrl, string prop)
        {
            object bd = Get(ctrl, "bossData");
            if (bd == null) return float.NaN;
            PropertyInfo p = bd.GetType().GetProperty(prop, BindingFlags.Public | BindingFlags.Instance);
            object v = p == null ? null : p.GetValue(bd, null);
            return v is float ? (float)v : float.NaN;
        }

        public static void Clamp(object ctrl, ref float damage, bool pairController, bool anyDefeated, bool allDefeated)
        {
            if (!State.OneHitKill || ctrl == null) return;
            try
            {
                float pool = Pool(ctrl);
                if (float.IsNaN(pool) || pool <= 0f) return;
                float threshold;
                if (pairController)                       // Duo: first tengu falls when pool <= healthUntilFirstTenguDefeated, second when pool <= 0
                {
                    if (anyDefeated) return;
                    object t = Get(ctrl, "healthUntilFirstTenguDefeated");
                    if (!(t is float)) return;
                    threshold = (float)t;
                }
                else                                      // Daitengu: lesser #1 at HealthToPhase2, lesser #2 at HealthToPhase3, Daitengu at 0
                {
                    if (allDefeated) return;
                    threshold = Phase(ctrl, anyDefeated ? "HealthToPhase3" : "HealthToPhase2");
                    if (float.IsNaN(threshold)) return;
                }
                float cap = StageCap(pool, threshold);
                if (damage > cap) damage = cap;
            }
            catch (Exception) { }
        }
    }

    [HarmonyPatch(typeof(KarasaTenguDuoController), "CheckDefeatStatus", new Type[] { typeof(KarasaTenguDuoBehavior), typeof(float) })]
    public static class Patch_KarasaDuo_CheckDefeatStatus
    {
        static void Prefix(KarasaTenguDuoController __instance, ref float damage)
        {
            PooledBoss.Clamp(__instance, ref damage, true, __instance.OneTenguDefeated(), __instance.AllTenguDefeated());
        }
    }

    [HarmonyPatch(typeof(TenguDuoControllerBR), "CheckDefeatStatus", new Type[] { typeof(TenguDuoBehaviorBR), typeof(float) })]
    public static class Patch_DuoBR_CheckDefeatStatus
    {
        static void Prefix(TenguDuoControllerBR __instance, ref float damage)
        {
            PooledBoss.Clamp(__instance, ref damage, true, __instance.OneTenguDefeated(), __instance.AllTenguDefeated());
        }
    }

    [HarmonyPatch(typeof(DaiTenguController), "CheckDefeatStatus", new Type[] { typeof(KarasaTenguDuoBehavior), typeof(float) })]
    public static class Patch_Dai_CheckDefeatStatus_Lesser
    {
        static void Prefix(DaiTenguController __instance, ref float damage)
        {
            PooledBoss.Clamp(__instance, ref damage, false, __instance.OneLesserTenguDefeated(), __instance.AllLesserTenguDefeated());
        }
    }

    [HarmonyPatch(typeof(DaiTenguController), "CheckDefeatStatus", new Type[] { typeof(float) })]
    public static class Patch_Dai_CheckDefeatStatus
    {
        static void Prefix(DaiTenguController __instance, ref float damage)
        {
            PooledBoss.Clamp(__instance, ref damage, false, __instance.OneLesserTenguDefeated(), __instance.AllLesserTenguDefeated());
        }
    }

    [HarmonyPatch(typeof(DaitenguBRController), "CheckDefeatStatus", new Type[] { typeof(TenguDuoBehaviorBR), typeof(float) })]
    public static class Patch_DaiBR_CheckDefeatStatus_Lesser
    {
        static void Prefix(DaitenguBRController __instance, ref float damage)
        {
            PooledBoss.Clamp(__instance, ref damage, false, __instance.OneLesserTenguDefeated(), __instance.AllLesserTenguDefeated());
        }
    }

    [HarmonyPatch(typeof(DaitenguBRController), "CheckDefeatStatus", new Type[] { typeof(float) })]
    public static class Patch_DaiBR_CheckDefeatStatus
    {
        static void Prefix(DaitenguBRController __instance, ref float damage)
        {
            PooledBoss.Clamp(__instance, ref damage, false, __instance.OneLesserTenguDefeated(), __instance.AllLesserTenguDefeated());
        }
    }

    // TRAPS (God Mode): white / icy crystals (IcyHazardTrigger) call DamagedFromKillzone() when the player touches them.
    // Harmless in God Mode (the IceBat branch of the same method is left alone).
    [HarmonyPatch(typeof(IcyHazardTrigger), "OnTriggerEnter2D")]
    public static class Patch_IcyHazardTrigger_OnTriggerEnter2D
    {
        static bool Prefix(Collider2D collision)
        {
            if (State.GodMode && collision != null && collision.CompareTag(BoConstants.PLAYER_TAG)) return false;
            return true;
        }
    }
}



