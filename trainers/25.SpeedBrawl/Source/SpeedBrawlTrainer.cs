using System;
using System.Collections.Generic;
using System.Reflection;
using BepInEx;
using HarmonyLib;
using UnityEngine;
using DS.Game.Luna;
using DS.Game.Items;
using DS.Game.Util;
using DS.Tech.Networking;

namespace SpeedBrawlTrainer
{
    [BepInPlugin(PluginGuid, PluginName, PluginVersion)]
    public class SpeedBrawlTrainerPlugin : BaseUnityPlugin
    {
        public const string PluginGuid = "com.rea.speedbrawl.trainer";
        public const string PluginName = "SpeedBrawl In-Game Trainer";
        public const string PluginVersion = "1.0.0";

        internal static SpeedBrawlTrainerPlugin Instance;

        internal static bool ShowMenu = true;
        internal static bool GodMode;
        internal static bool InfiniteJumps;
        internal static bool DoubleSpeed;
        internal static bool InfiniteStamina;
        internal static bool InfiniteCoins;
        internal static bool InfiniteItems;
        internal static bool OneHitKill;
        internal static bool ShowItems;

        private static float _nextCoinTopUp;
        private static float _nextStaminaRefill;
        private static float _nextCheatSync;
        private static float _nextEspScan;
        private static string _status = "Ready.";
        private static float _statusUntil;

        private static readonly List<Transform> EspTargets = new List<Transform>();
        private static Texture2D _white;
        private static GUIStyle _labelStyle;

        private Harmony _harmony;

        private void Awake()
        {
            Instance = this;
            _white = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            _white.SetPixel(0, 0, Color.white);
            _white.Apply();
            _harmony = new Harmony(PluginGuid);
            TryPatch(typeof(Health_Server), "OnPreDamage", typeof(HealthOnPreDamagePatch), "Prefix", null, null);
            TryPatch(typeof(Health_Server), "ResolveDamage", typeof(HealthResolveDamagePatch), "Prefix", null, null);
            TryPatch(typeof(PlatformerController2D_Server), "get_AirJumps", null, null, typeof(AirJumpsPatch), "Postfix");
            TryPatch(typeof(MovementController_Server), "GetTargetRunSpeed", null, null, typeof(RunSpeedPatch), "Postfix");
            TryPatch(typeof(InventoryStacker), "SetAmountInternal", typeof(InventorySetAmountPatch), "Prefix", null, null);

            Logger.LogInfo("SpeedBrawl In-Game Trainer v" + PluginVersion + " loaded.");
            Logger.LogInfo("Press Insert to toggle the trainer menu. F1..F11 toggle features.");
        }

        private void TryPatch(Type targetType, string methodName, Type prefixType, string prefixName, Type postfixType, string postfixName)
        {
            try
            {
                MethodInfo original = AccessTools.Method(targetType, methodName);
                if (original == null)
                {
                    Logger.LogWarning("Patch target not found: " + targetType.FullName + "." + methodName);
                    return;
                }
                HarmonyMethod prefix = null;
                HarmonyMethod postfix = null;
                if (prefixType != null)
                    prefix = new HarmonyMethod(prefixType.GetMethod(prefixName, BindingFlags.Static | BindingFlags.NonPublic));
                if (postfixType != null)
                    postfix = new HarmonyMethod(postfixType.GetMethod(postfixName, BindingFlags.Static | BindingFlags.NonPublic));
                _harmony.Patch(original, prefix, postfix);
                Logger.LogInfo("Patched " + targetType.Name + "." + methodName);
            }
            catch (Exception ex)
            {
                Logger.LogError("Failed to patch " + targetType.FullName + "." + methodName + ": " + ex);
            }
        }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.Insert))
                ShowMenu = !ShowMenu;

            bool blocked = IsOnlineBlocked();
            if (blocked)
            {
                SuppressGameCheats();
                if (Time.unscaledTime > _statusUntil)
                {
                    _status = "ONLINE SESSION DETECTED - trainer features are disabled.";
                    _statusUntil = Time.unscaledTime + 5f;
                }
            }
            else
            {
                if (Input.GetKeyDown(KeyCode.F1)) SetGodMode(!GodMode);
                if (Input.GetKeyDown(KeyCode.F2)) SetInfiniteJumps(!InfiniteJumps);
                if (Input.GetKeyDown(KeyCode.F3)) SetDoubleSpeed(!DoubleSpeed);
                if (Input.GetKeyDown(KeyCode.F4)) SetInfiniteStamina(!InfiniteStamina);
                if (Input.GetKeyDown(KeyCode.F5)) SetInfiniteCoins(!InfiniteCoins);
                if (Input.GetKeyDown(KeyCode.F6)) AddCoins(100000);
                if (Input.GetKeyDown(KeyCode.F7)) SetInfiniteItems(!InfiniteItems);
                if (Input.GetKeyDown(KeyCode.F8)) UnlockAllGear();
                if (Input.GetKeyDown(KeyCode.F9)) SetShowItems(!ShowItems);
                if (Input.GetKeyDown(KeyCode.F10)) SetOneHitKill(!OneHitKill);
                if (Input.GetKeyDown(KeyCode.F11)) UnlockAllChampionships();
                if (Input.GetKeyDown(KeyCode.Home)) ForceSave();

                if (InfiniteCoins && Time.unscaledTime >= _nextCoinTopUp)
                {
                    _nextCoinTopUp = Time.unscaledTime + 0.75f;
                    TopUpCoins();
                }
                if (InfiniteStamina && Time.unscaledTime >= _nextStaminaRefill)
                {
                    _nextStaminaRefill = Time.unscaledTime + 0.5f;
                    RefillHeroEnergy();
                }
                if (Time.unscaledTime >= _nextCheatSync)
                {
                    _nextCheatSync = Time.unscaledTime + 1f;
                    SyncGameCheatBools();
                }
            }

            if (ShowItems && Time.unscaledTime >= _nextEspScan)
            {
                _nextEspScan = Time.unscaledTime + 0.5f;
                ScanEspTargets();
            }
        }

        private void OnGUI()
        {
            if (_white == null)
                return;
            if (_labelStyle == null)
            {
                _labelStyle = new GUIStyle(GUI.skin.label);
                _labelStyle.fontSize = 11;
                _labelStyle.normal.textColor = Color.white;
            }

            if (ShowItems)
                DrawEsp();

            if (!ShowMenu)
                return;

            Color old = GUI.backgroundColor;
            GUI.backgroundColor = new Color(0.04f, 0.05f, 0.08f, 0.96f);
            GUILayout.BeginArea(new Rect(20f, 20f, 650f, 500f), GUI.skin.box);
            GUI.backgroundColor = old;

            GUILayout.Label("SPEEDBRAWL IN-GAME TRAINER  v" + PluginVersion);
            GUILayout.Label("Insert: show/hide menu    Home: force save");
            GUILayout.Label(BuildStatusLine());

            GUILayout.Space(4f);
            GUILayout.BeginHorizontal();

            GUILayout.BeginVertical(GUILayout.Width(305f));
            GodMode = Toggle(GodMode, "[F1] God Mode (player heroes)");
            InfiniteJumps = Toggle(InfiniteJumps, "[F2] Unlimited Jumps");
            DoubleSpeed = Toggle(DoubleSpeed, "[F3] Character Move Speed x2");
            InfiniteStamina = Toggle(InfiniteStamina, "[F4] Infinite Stamina / Special");
            InfiniteCoins = Toggle(InfiniteCoins, "[F5] Infinite Coins");
            if (GUILayout.Button("[F6] Add 100,000 Coins")) AddCoins(100000);
            GUILayout.EndVertical();

            GUILayout.BeginVertical(GUILayout.Width(305f));
            InfiniteItems = Toggle(InfiniteItems, "[F7] Infinite Items (no item loss)");
            if (GUILayout.Button("[F8] Unlock All Gear Items")) UnlockAllGear();
            ShowItems = Toggle(ShowItems, "[F9] Show All Items (ESP)");
            OneHitKill = Toggle(OneHitKill, "[F10] One-Hit Kill (enemies)");
            if (GUILayout.Button("[F11] Unlock All Championships")) UnlockAllChampionships();
            if (GUILayout.Button("[Home] Force Save")) ForceSave();
            GUILayout.EndVertical();

            GUILayout.EndHorizontal();

            GUILayout.Space(4f);
            GUILayout.Label("Active: " + BuildActiveSummary());
            GUILayout.Label("Offline / single-player use only. Do not enable in online matches.");
            GUILayout.EndArea();
        }

        private static bool Toggle(bool value, string text)
        {
            bool next = GUILayout.Toggle(value, text);
            if (next != value)
            {
                string key = text.Substring(0, text.IndexOf(']') + 1);
                if (key == "[F1]") SetGodMode(next);
                else if (key == "[F2]") SetInfiniteJumps(next);
                else if (key == "[F3]") SetDoubleSpeed(next);
                else if (key == "[F4]") SetInfiniteStamina(next);
                else if (key == "[F5]") SetInfiniteCoins(next);
                else if (key == "[F7]") SetInfiniteItems(next);
                else if (key == "[F9]") SetShowItems(next);
                else if (key == "[F10]") SetOneHitKill(next);
            }
            return next;
        }

        private static string BuildStatusLine()
        {
            string coins = "Coins: ?";
            try
            {
                if (ItemManager.Instance != null)
                    coins = "Coins: " + ItemManager.Instance.Coins;
            }
            catch { }
            string online = IsOnlineBlocked() ? "ONLINE-LOCK" : "offline-ok";
            string heroes = "Heroes: " + CountHeroes();
            string msg = Time.unscaledTime < _statusUntil ? ("  |  " + _status) : "";
            return coins + "    " + heroes + "    " + online + msg;
        }

        private static string BuildActiveSummary()
        {
            List<string> on = new List<string>();
            if (GodMode) on.Add("GOD");
            if (InfiniteJumps) on.Add("JUMPS");
            if (DoubleSpeed) on.Add("SPEED");
            if (InfiniteStamina) on.Add("STAMINA");
            if (InfiniteCoins) on.Add("MONEY");
            if (InfiniteItems) on.Add("ITEMS");
            if (OneHitKill) on.Add("OHK");
            if (ShowItems) on.Add("ESP");
            return on.Count == 0 ? "none" : string.Join(", ", on.ToArray());
        }

        private static void SetStatus(string text)
        {
            _status = text;
            _statusUntil = Time.unscaledTime + 4f;
        }

        internal static void SetGodMode(bool on)
        {
            GodMode = on;
            try { Cheats.SetCheatBool(Cheats.CheatBool.Invincible, on); } catch { }
            SetStatus(on ? "God Mode ON" : "God Mode OFF");
        }

        internal static void SetInfiniteJumps(bool on)
        {
            InfiniteJumps = on;
            SetStatus(on ? "Unlimited jumps ON" : "Unlimited jumps OFF");
        }

        internal static void SetDoubleSpeed(bool on)
        {
            DoubleSpeed = on;
            SetStatus(on ? "Move speed x2 ON" : "Move speed x2 OFF");
        }

        internal static void SetInfiniteStamina(bool on)
        {
            InfiniteStamina = on;
            try { Cheats.SetCheatBool(Cheats.CheatBool.InfiniteEnergy, on); } catch { }
            if (on) RefillHeroEnergy();
            SetStatus(on ? "Infinite stamina ON" : "Infinite stamina OFF");
        }

        internal static void SetInfiniteCoins(bool on)
        {
            InfiniteCoins = on;
            if (on) TopUpCoins();
            SetStatus(on ? "Infinite coins ON" : "Infinite coins OFF");
        }

        internal static void SetInfiniteItems(bool on)
        {
            InfiniteItems = on;
            SetStatus(on ? "Infinite items ON" : "Infinite items OFF");
        }

        internal static void SetOneHitKill(bool on)
        {
            OneHitKill = on;
            SetStatus(on ? "One-hit kill ON" : "One-hit kill OFF");
        }

        internal static void SetShowItems(bool on)
        {
            ShowItems = on;
            if (on) ScanEspTargets();
            SetStatus(on ? "Item ESP ON" : "Item ESP OFF");
        }

        internal static void AddCoins(int amount)
        {
            if (IsOnlineBlocked()) return;
            try
            {
                if (ItemManager.Instance == null || ItemManager.Instance.TeamInventory == null || GameConfig.Instance == null)
                    return;
                int current = ItemManager.Instance.Coins;
                long target = (long)current + amount;
                if (target > 999999999L) target = 999999999L;
                ItemManager.Instance.TeamInventory.Stacker[GameConfig.Instance.CoinItemID] = (int)target;
                ForceSave();
                SetStatus("Added " + amount + " coins");
            }
            catch (Exception ex)
            {
                SetStatus("Add coins failed: " + ex.GetType().Name);
            }
        }

        internal static void TopUpCoins()
        {
            if (IsOnlineBlocked()) return;
            try
            {
                if (ItemManager.Instance == null || ItemManager.Instance.TeamInventory == null || GameConfig.Instance == null)
                    return;
                if (ItemManager.Instance.Coins < 9000000)
                {
                    ItemManager.Instance.TeamInventory.Stacker[GameConfig.Instance.CoinItemID] = 9999999;
                }
            }
            catch { }
        }

        internal static void UnlockAllGear()
        {
            if (IsOnlineBlocked()) return;
            try
            {
                ItemManager im = ItemManager.Instance;
                if (im == null || im.TeamInventory == null) return;
                List<GearItemData> gears = im.GearItemDatas;
                if (gears == null) return;
                int added = 0;
                for (int i = 0; i < gears.Count; i++)
                {
                    GearItemData g = gears[i];
                    if (g == null) continue;
                    if (!im.TeamInventory.ContainsItemID(g.ItemID))
                    {
                        if (im.TeamInventory.Add(g.ItemID)) added++;
                    }
                }
                ForceSave();
                SetStatus("Unlocked gear: " + added);
            }
            catch (Exception ex)
            {
                SetStatus("Unlock gear failed: " + ex.GetType().Name);
            }
        }

        internal static void UnlockAllChampionships()
        {
            if (IsOnlineBlocked()) return;
            try
            {
                Cheats.SetCheatBool(Cheats.CheatBool.AllChampionshipsUnlocked, true);
                SetStatus("All championships unlocked");
            }
            catch (Exception ex)
            {
                SetStatus("Unlock championships failed: " + ex.GetType().Name);
            }
        }

        internal static void ForceSave()
        {
            try
            {
                Cheats.ForceSave();
            }
            catch { }
        }

        private static void RefillHeroEnergy()
        {
            try
            {
                Hero_Server[] heroes = UnityEngine.Object.FindObjectsOfType<Hero_Server>();
                for (int i = 0; i < heroes.Length; i++)
                {
                    Hero_Server h = heroes[i];
                    if (h == null) continue;
                    if (h.Stamina != null) h.Stamina.Value = h.Stamina.Max;
                    if (h.Special != null) h.Special.Value = h.Special.Max;
                }
            }
            catch { }
        }

        private static void SyncGameCheatBools()
        {
            try
            {
                if (GodMode && !Cheats.GetCheatBool(Cheats.CheatBool.Invincible))
                    Cheats.SetCheatBool(Cheats.CheatBool.Invincible, true);
                if (InfiniteStamina && !Cheats.GetCheatBool(Cheats.CheatBool.InfiniteEnergy))
                    Cheats.SetCheatBool(Cheats.CheatBool.InfiniteEnergy, true);
            }
            catch { }
        }

        private static void SuppressGameCheats()
        {
            try
            {
                if (Cheats.GetCheatBool(Cheats.CheatBool.Invincible))
                    Cheats.SetCheatBool(Cheats.CheatBool.Invincible, false);
                if (Cheats.GetCheatBool(Cheats.CheatBool.InfiniteEnergy))
                    Cheats.SetCheatBool(Cheats.CheatBool.InfiniteEnergy, false);
            }
            catch { }
        }

        internal static int CountHeroes()
        {
            try { return UnityEngine.Object.FindObjectsOfType<Hero_Server>().Length; }
            catch { return 0; }
        }

        internal static bool IsOnlineBlocked()
        {
            try
            {
                SBNetworkManager manager = SBNetworkManager.Instance;
                if (manager == null) return false;
                INetworkPartyService connector = manager.Connector;
                if (connector == null) return false;
                return connector.IsPartyOnline;
            }
            catch { return false; }
        }

        internal static bool IsHeroObject(GameObject go)
        {
            if (go == null) return false;
            try
            {
                if (go.GetComponent<Hero_Server>() != null) return true;
                if (go.GetComponentInParent<Hero_Server>() != null) return true;
            }
            catch { }
            return false;
        }

        internal static bool IsEnemyObject(GameObject go)
        {
            if (go == null) return false;
            try
            {
                if (go.GetComponent<Enemy_Server>() != null) return true;
                if (go.GetComponentInParent<Enemy_Server>() != null) return true;
            }
            catch { }
            return false;
        }

        private static readonly Type[] EspTypes = new Type[]
        {
            typeof(DS.Game.Items.Item),
            typeof(Crate_Server),
            typeof(Barrel_Server),
            typeof(Target_Server),
            typeof(MovingProp_Server),
            typeof(StaticProp_Server),
            typeof(NetworkCrate),
            typeof(NetworkBarrel),
            typeof(NetworkTarget),
            typeof(NetworkMovingProp)
        };

        private static void ScanEspTargets()
        {
            EspTargets.Clear();
            HashSet<int> seen = new HashSet<int>();
            for (int t = 0; t < EspTypes.Length; t++)
            {
                UnityEngine.Object[] found = null;
                try { found = UnityEngine.Object.FindObjectsOfType(EspTypes[t]); }
                catch { continue; }
                if (found == null) continue;
                for (int i = 0; i < found.Length; i++)
                {
                    Component c = found[i] as Component;
                    if (c == null) continue;
                    int id = c.GetInstanceID();
                    if (seen.Contains(id)) continue;
                    seen.Add(id);
                    EspTargets.Add(c.transform);
                }
            }
        }

        private static void DrawEsp()
        {
            Camera cam = Camera.main;
            if (cam == null) return;
            Transform player = null;
            try
            {
                Hero_Server[] heroes = UnityEngine.Object.FindObjectsOfType<Hero_Server>();
                if (heroes.Length > 0) player = heroes[0].transform;
            }
            catch { }

            Vector3 playerPos = player != null ? player.position : Vector3.zero;
            for (int i = EspTargets.Count - 1; i >= 0; i--)
            {
                Transform tr = EspTargets[i];
                if (tr == null)
                {
                    EspTargets.RemoveAt(i);
                    continue;
                }
                Vector3 sp = cam.WorldToScreenPoint(tr.position);
                if (sp.z <= 0f) continue;
                if (sp.x < -40f || sp.x > Screen.width + 40f) continue;
                if (sp.y < -40f || sp.y > Screen.height + 40f) continue;
                float y = Screen.height - sp.y;
                float dist = Vector3.Distance(playerPos, tr.position);
                GUI.color = new Color(0.1f, 1f, 0.4f, 0.95f);
                GUI.DrawTexture(new Rect(sp.x - 3f, y - 3f, 6f, 6f), _white);
                GUI.color = Color.white;
                GUI.Label(new Rect(sp.x + 5f, y - 9f, 240f, 20f),
                    tr.name + "  [" + dist.ToString("0") + "m]", _labelStyle);
            }
        }
    }

    internal static class HealthOnPreDamagePatch
    {
        private static bool Prefix(Health_Server __instance, SBDamageResult __0)
        {
            if (!SpeedBrawlTrainerPlugin.GodMode || SpeedBrawlTrainerPlugin.IsOnlineBlocked())
                return true;
            if (__instance == null || __0 == null)
                return true;
            try
            {
                if (!SpeedBrawlTrainerPlugin.IsHeroObject(__instance.gameObject))
                    return true;
                SBDamageData data = __0.DamageData;
                if (data != null && data.IsHelpful)
                    return true;
                __0.Abort();
                return false;
            }
            catch
            {
                return true;
            }
        }
    }

    internal static class HealthResolveDamagePatch
    {
        private static bool Prefix(Health_Server __instance, SBDamageResult __0)
        {
            if (!SpeedBrawlTrainerPlugin.OneHitKill || SpeedBrawlTrainerPlugin.IsOnlineBlocked())
                return true;
            if (__instance == null || __0 == null)
                return true;
            try
            {
                if (!SpeedBrawlTrainerPlugin.IsEnemyObject(__instance.gameObject))
                    return true;
                SBDamageData data = __0.DamageData;
                if (data != null && data.IsHelpful)
                    return true;
                __0.Damage = 9999999f;
                return true;
            }
            catch
            {
                return true;
            }
        }
    }

    internal static class AirJumpsPatch
    {
        private static void Postfix(PlatformerController2D_Server __instance, ref int __result)
        {
            if (!SpeedBrawlTrainerPlugin.InfiniteJumps || SpeedBrawlTrainerPlugin.IsOnlineBlocked())
                return;
            if (__instance == null)
                return;
            try
            {
                if (SpeedBrawlTrainerPlugin.IsHeroObject(__instance.gameObject))
                    __result = -1;
            }
            catch { }
        }
    }

    internal static class RunSpeedPatch
    {
        private static void Postfix(MovementController_Server __instance, ref float __result)
        {
            if (!SpeedBrawlTrainerPlugin.DoubleSpeed || SpeedBrawlTrainerPlugin.IsOnlineBlocked())
                return;
            if (__instance == null)
                return;
            try
            {
                if (SpeedBrawlTrainerPlugin.IsHeroObject(__instance.gameObject))
                    __result *= 2f;
            }
            catch { }
        }
    }

    internal static class InventorySetAmountPatch
    {
        private static bool Prefix(InventoryStacker __instance, UnityGuid __0, int __1, ref bool __result)
        {
            if (!SpeedBrawlTrainerPlugin.InfiniteItems || SpeedBrawlTrainerPlugin.IsOnlineBlocked())
                return true;
            if (__instance == null)
                return true;
            try
            {
                ItemManager im = ItemManager.Instance;
                if (im == null || im.TeamInventory == null)
                    return true;
                if (!object.ReferenceEquals(im.TeamInventory.Stacker, __instance))
                    return true;
                GameConfig config = GameConfig.Instance;
                if (config != null && __0 == config.CoinItemID)
                    return true;
                int current = __instance[__0];
                if (__1 < current)
                {
                    __result = true;
                    return false;
                }
            }
            catch { }
            return true;
        }
    }
}












