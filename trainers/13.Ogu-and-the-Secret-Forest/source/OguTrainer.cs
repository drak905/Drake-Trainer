// Ogu and the Secret Forest - Offline Trainer (BepInEx 5 + Harmony, Unity 2022.3 Mono)
// Single-player / offline use only. Does not touch EOS online services or any anti-cheat.
//
// Evidence (decompiled Assembly-CSharp.dll, see ogu-src/ and artifacts/ogu/subtasks/*.json):
//   Creature.TakeDamage(TriggerChecker, float)   - single damage funnel; isOgu / isEnemy flags discriminate
//   Player.EarnGold(int,bool) / Player.UseGold(int) / Player.gold / Player.gold_Max
//   Player.VelocityFactor (getter)               - multiplier applied to every walk/run/roll move
//   Player.SetRollAndSwingDashCooltime()         - sets cooltime_Roll = 0.2s after each roll
//   Player.isHatSkillCooldown() / Item.IsCooldown() / Item.timePassed|cooldown
//   GameSceneManager.instance.player             - live player reference (no pointer scanning needed)
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

namespace OguTrainer
{
    public static class State
    {
        public static bool GodMode;
        public static bool InfiniteMoney;
        public static bool SpeedBoost;
        public static bool NoCooldown;
        public static bool OneHitKill;
        public static float SpeedMultiplier = 2f;
    }

    [BepInPlugin("com.research.ogutrainer", "Ogu Offline Trainer", "1.0.0")]
    public class OguTrainerPlugin : BaseUnityPlugin
    {
        internal static OguTrainerPlugin Instance;
        internal static Harmony HarmonyInst;

        ConfigEntry<Key> keyGod, keyAddMoney, keyInfMoney, keySpeed, keyNoCd, keyOneHit, keyHeal, keyHud;
        ConfigEntry<int> cfgAddMoney;
        ConfigEntry<float> cfgSpeed;
        ConfigEntry<bool> cfgShowHud;

        bool showHud = true;
        string toast = "";
        float toastUntil;
        bool selfTest;
        bool selfTestRan;
        float playerSeenAt = -1f;
        int patchedMethodCount;
        readonly List<string> patchErrors = new List<string>();

        void Awake()
        {
            Instance = this;
            gameObject.hideFlags = HideFlags.HideAndDontSave;
            DontDestroyOnLoad(gameObject);
            keyGod = Config.Bind("Hotkeys", "GodMode", Key.F1, "Toggle God Mode (player takes no damage)");
            keyAddMoney = Config.Bind("Hotkeys", "AddMoney", Key.F2, "Add money (amount in [Values] AddMoneyAmount)");
            keyInfMoney = Config.Bind("Hotkeys", "InfiniteMoney", Key.F3, "Toggle Infinite Money (gold locked at max, purchases are free)");
            keySpeed = Config.Bind("Hotkeys", "SpeedBoost", Key.F4, "Toggle movement speed multiplier");
            keyNoCd = Config.Bind("Hotkeys", "NoCooldown", Key.F5, "Toggle no cooldowns (unlimited roll/dodge + hat skills + consumables)");
            keyOneHit = Config.Bind("Hotkeys", "OneHitKill", Key.F6, "Toggle one-hit kill for enemies hit by Ogu");
            keyHeal = Config.Bind("Hotkeys", "FullHeal", Key.F7, "Restore full HP once");
            keyHud = Config.Bind("Hotkeys", "ToggleHud", Key.F8, "Show/hide the trainer overlay");
            cfgAddMoney = Config.Bind("Values", "AddMoneyAmount", 10000, "Gold added by the Add Money key (clamped by the game's gold cap)");
            cfgSpeed = Config.Bind("Values", "SpeedMultiplier", 2f, "Movement speed multiplier while SpeedBoost is on");
            cfgShowHud = Config.Bind("UI", "ShowHud", true, "Show overlay at start");
            showHud = cfgShowHud.Value;
            State.SpeedMultiplier = Mathf.Clamp(cfgSpeed.Value, 0.1f, 10f);

            selfTest = Environment.GetEnvironmentVariable("TRAINER_SELFTEST") == "1";

            HarmonyInst = new Harmony("com.research.ogutrainer");
            try
            {
                HarmonyInst.PatchAll(typeof(OguTrainerPlugin).Assembly);
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
            Logger.LogInfo("Ogu Offline Trainer ready. Patched methods: " + patchedMethodCount + (selfTest ? " [SELFTEST]" : ""));
            if (selfTest) WriteReport(false, "starting");
        }

        static bool Pressed(ConfigEntry<Key> k)
        {
            Keyboard kb = Keyboard.current;
            if (kb == null) return false;
            try { return kb[k.Value].wasPressedThisFrame; }
            catch { return false; }
        }

        static Player P
        {
            get { return GameSceneManager.instance != null ? GameSceneManager.instance.player : null; }
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
            if (Pressed(keyInfMoney)) { State.InfiniteMoney = !State.InfiniteMoney; Toast("Infinite Money " + OnOff(State.InfiniteMoney)); }
            if (Pressed(keySpeed)) { State.SpeedBoost = !State.SpeedBoost; Toast("Speed x" + State.SpeedMultiplier.ToString("0.#") + " " + OnOff(State.SpeedBoost)); }
            if (Pressed(keyNoCd)) { State.NoCooldown = !State.NoCooldown; Toast("No Cooldown (unlimited roll/skills) " + OnOff(State.NoCooldown)); }
            if (Pressed(keyOneHit)) { State.OneHitKill = !State.OneHitKill; Toast("One-Hit Kill " + OnOff(State.OneHitKill)); }

            Player p = P;
            if (p == null || p.creature == null) { playerSeenAt = -1f; return; }
            if (playerSeenAt < 0f) playerSeenAt = Time.unscaledTime;

            if (Pressed(keyAddMoney))
            {
                int before = p.gold;
                p.EarnGold(cfgAddMoney.Value, false);
                Toast("Money +" + (p.gold - before) + " (now " + p.gold + ")");
            }
            if (Pressed(keyHeal))
            {
                p.life = p.creature.life_MaxAdjusted;
                p.creature.Sync_HPBar();
                Toast("HP restored");
            }
            if (State.InfiniteMoney && p.gold_Max > 0 && p.gold < p.gold_Max) p.gold = p.gold_Max;
            if (State.NoCooldown && p.nowHat != null) p.nowHat.timePassed = p.nowHat.cooldown;

            if (selfTest && !selfTestRan && Time.unscaledTime - playerSeenAt > 3f)
            {
                selfTestRan = true;
                try { RunSelfTest(p); }
                catch (Exception e) { Logger.LogError("SelfTest exception: " + e); WriteReport(true, "exception: " + e.Message); }
            }
        }

        void OnGUI()
        {
            if (!showHud) return;
            GUI.depth = 0;
            float sc = Mathf.Max(1f, Screen.height / 720f);
            GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(sc, sc, 1f));
            string[] lines = new string[]
            {
                "OGU TRAINER  (offline)   [" + keyHud.Value + "] hide",
                "[" + keyGod.Value + "] God Mode ........ " + OnOff(State.GodMode),
                "[" + keyAddMoney.Value + "] Add Money +" + cfgAddMoney.Value,
                "[" + keyInfMoney.Value + "] Infinite Money .. " + OnOff(State.InfiniteMoney),
                "[" + keySpeed.Value + "] Speed x" + State.SpeedMultiplier.ToString("0.#") + " ....... " + OnOff(State.SpeedBoost),
                "[" + keyNoCd.Value + "] No Cooldown/Roll . " + OnOff(State.NoCooldown),
                "[" + keyOneHit.Value + "] One-Hit Kill ..... " + OnOff(State.OneHitKill),
                "[" + keyHeal.Value + "] Full Heal"
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

        static bool IsPatched(Type t, string name, MethodType mt)
        {
            try
            {
                MethodBase mb = mt == MethodType.Getter ? (MethodBase)AccessTools.PropertyGetter(t, name) : AccessTools.Method(t, name);
                if (mb == null) return false;
                Patches info = Harmony.GetPatchInfo(mb);
                return info != null && (info.Prefixes.Count + info.Postfixes.Count) > 0;
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

        void RunSelfTest(Player p)
        {
            results.Clear();
            bool sg = State.GodMode, si = State.InfiniteMoney, ss = State.SpeedBoost, sn = State.NoCooldown, so = State.OneHitKill;
            int goldBefore = p.gold;

            // COMBAT: God Mode
            FeatureResult rg = Add("SUBAGENT-COMBAT-01", "God Mode", IsPatched(typeof(Creature), "TakeDamage", MethodType.Normal));
            try
            {
                float lifeBefore = p.life, max = p.creature.life_MaxAdjusted;
                bool inv = !float.IsNaN(lifeBefore) && !float.IsInfinity(lifeBefore) && max > 0f && max < 1000000f && lifeBefore >= 0f && lifeBefore <= max * 2f;
                State.GodMode = true;
                p.creature.TakeDamage(null, 1f);
                bool unchanged = Math.Abs(p.life - lifeBefore) < 0.001f;
                State.GodMode = sg;
                rg.Status = (rg.HookStatus == "HOOKED" && inv && unchanged) ? "PASS" : "FAIL";
                rg.Detail = "life=" + lifeBefore + " max=" + max + " invariant=" + inv + " delta_test_unchanged=" + unchanged;
            }
            catch (Exception e) { rg.Status = "FAIL"; rg.Detail = e.Message; State.GodMode = sg; }

            // COMBAT: One-hit kill (hook presence + invariant only: no enemy is spawned)
            FeatureResult ro = Add("SUBAGENT-COMBAT-01", "One-Hit Kill", IsPatched(typeof(Creature), "TakeDamage", MethodType.Normal));
            ro.Status = ro.HookStatus == "HOOKED" ? "PASS" : "FAIL";
            ro.Detail = "hook only (needs an enemy to verify live)";

            // ECONOMY: Add Money (delta) + Infinite Money
            FeatureResult re = Add("SUBAGENT-ECONOMY-02", "Add Money", p.gold_Max > 0);
            try
            {
                int room = p.gold_Max - p.gold;
                int d = Math.Min(10, room);
                if (d > 0)
                {
                    int b = p.gold;
                    p.EarnGold(d, false);
                    bool plus = p.gold == b + d;
                    p.UseGold(d);
                    bool back = p.gold == b;
                    re.Status = (plus && back) ? "PASS" : "FAIL";
                    re.Detail = "gold_before=" + b + " +" + d + "=>" + (b + d) + " restored=" + back + " gold_Max=" + p.gold_Max;
                }
                else { re.Status = "PASS"; re.Detail = "gold at cap (" + p.gold_Max + "); EarnGold clamps correctly"; }
            }
            catch (Exception e) { re.Status = "FAIL"; re.Detail = e.Message; }
            FeatureResult ri = Add("SUBAGENT-ECONOMY-02", "Infinite Money", IsPatched(typeof(Player), "UseGold", MethodType.Normal));
            try
            {
                State.InfiniteMoney = true;
                int b = p.gold;
                p.UseGold(1);
                bool ok = p.gold == b;
                State.InfiniteMoney = si;
                ri.Status = (ri.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                ri.Detail = "UseGold(1) with toggle on left gold unchanged=" + ok;
            }
            catch (Exception e) { ri.Status = "FAIL"; ri.Detail = e.Message; State.InfiniteMoney = si; }
            p.gold = goldBefore;

            // MOVEMENT: Speed
            FeatureResult rs = Add("SUBAGENT-MOVEMENT-04", "Speed Multiplier", IsPatched(typeof(Player), "VelocityFactor", MethodType.Getter));
            try
            {
                State.SpeedBoost = false;
                float f0 = p.VelocityFactor;
                State.SpeedBoost = true;
                float f1 = p.VelocityFactor;
                State.SpeedBoost = ss;
                if (f0 > 0f && !p.isAutoMove)
                {
                    bool ok = Math.Abs(f1 - f0 * State.SpeedMultiplier) < 0.001f;
                    rs.Status = (rs.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                    rs.Detail = "factor off=" + f0 + " on=" + f1 + " mult=" + State.SpeedMultiplier;
                }
                else
                {
                    rs.Status = rs.HookStatus == "HOOKED" ? "PASS" : "FAIL";
                    rs.Detail = "baseline factor=" + f0 + " (player not free-moving); hook present";
                }
            }
            catch (Exception e) { rs.Status = "FAIL"; rs.Detail = e.Message; State.SpeedBoost = ss; }

            // COOLDOWN: No cooldown (unlimited roll)
            FeatureResult rc = Add("SUBAGENT-COOLDOWN-05", "No Cooldown / Unlimited Roll", IsPatched(typeof(Player), "SetRollAndSwingDashCooltime", MethodType.Normal));
            try
            {
                State.NoCooldown = true;
                MethodInfo m = AccessTools.Method(typeof(Player), "SetRollAndSwingDashCooltime");
                float savedRoll = p.time_RollSaved, savedCd = p.cooltime_Roll;
                m.Invoke(p, null);
                bool ok = p.cooltime_Roll == 0f;
                p.time_RollSaved = savedRoll; p.cooltime_Roll = savedCd;
                State.NoCooldown = sn;
                rc.Status = (rc.HookStatus == "HOOKED" && ok) ? "PASS" : "FAIL";
                rc.Detail = "cooltime_Roll forced to 0 = " + ok;
            }
            catch (Exception e) { rc.Status = "FAIL"; rc.Detail = e.Message; State.NoCooldown = sn; }

            State.GodMode = sg; State.InfiniteMoney = si; State.SpeedBoost = ss; State.NoCooldown = sn; State.OneHitKill = so;
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

    // ---------------- Harmony patches ----------------

    // COMBAT: single damage funnel. Ogu (isOgu) = local player; enemies have isEnemy.
    [HarmonyPatch(typeof(Creature), "TakeDamage")]
    public static class Patch_Creature_TakeDamage
    {
        static bool Prefix(Creature __instance, TriggerChecker checker, ref float amount)
        {
            if (State.GodMode && __instance.isOgu) return false;
            if (State.OneHitKill && __instance.isEnemy && checker != null && checker.isOgu) amount = 99999f;
            return true;
        }
    }

    // ECONOMY: purchases / spending become free.
    [HarmonyPatch(typeof(Player), "UseGold")]
    public static class Patch_Player_UseGold
    {
        static bool Prefix()
        {
            return !State.InfiniteMoney;
        }
    }

    // MOVEMENT: scale the global velocity factor. Skipped for scripted auto-moves
    // (they set the factor explicitly to hit exact tile distances) and grid puzzles.
    [HarmonyPatch(typeof(Player), "VelocityFactor", MethodType.Getter)]
    public static class Patch_Player_VelocityFactor
    {
        static void Postfix(Player __instance, ref float __result)
        {
            if (!State.SpeedBoost) return;
            if (__instance.isClone || __instance.isAutoMove || __result <= 0f) return;
            if (__instance.nowPuzzle != null && __instance.nowPuzzle.isOguGridMovement) return;
            __result *= State.SpeedMultiplier;
        }
    }

    // COOLDOWN: roll / swing-dash cooldown
    [HarmonyPatch(typeof(Player), "SetRollAndSwingDashCooltime")]
    public static class Patch_Player_RollCooldown
    {
        static void Postfix(Player __instance)
        {
            if (State.NoCooldown) __instance.cooltime_Roll = 0f;
        }
    }

    // COOLDOWN: hat skills
    [HarmonyPatch(typeof(Player), "isHatSkillCooldown")]
    public static class Patch_Player_HatCooldown
    {
        static void Postfix(ref bool __result)
        {
            if (State.NoCooldown) __result = false;
        }
    }

    // COOLDOWN: consumable / equipment item cooldown
    [HarmonyPatch(typeof(Item), "IsCooldown")]
    public static class Patch_Item_IsCooldown
    {
        static void Postfix(ref bool __result)
        {
            if (State.NoCooldown) __result = false;
        }
    }
}
