// MAP TRACKER - shows where every Kodama and (with a hotkey) every other collectible is, and which ones are already taken.
//
// Evidence (decompiled Assembly-CSharp.dll + runtime dump of the map and a scan of all 105 scenes, see artifacts/bo_kodama/):
//   * The map is rendered by MapInstanceCache's MapCamera; every pickup has a pre-placed HandleMapIcon (UI Image) under
//     MAP SYSTEM/MapHolderCanvas/Icons/<area>/<scene>/ whose world position equals the pickup (+5 y). 34 icons are named "...Kodama...";
//     the scene scan found exactly 34 Kodamas with a LinkedMapIcon (plus 12 unlabelled Kodama Mimics = enemies) and the positions match.
//   * Secret icons (Action = EnableWithIntuitionOmamori) are only visible with the Intuition omamori. Picking an item calls
//     LinkedMapIcon.DisableLinkedIcon -> MapIconsManager.ClearedIcon(name): the name goes into GameManager.MapClearedconsDictionary
//     (saved in the save file) and the icon GameObject is deactivated.  => "taken" == MapClearedconsDictionary.ContainsKey(icon.name).
//   * Kodama total 34 == InventoryContainer.Kodamas when all are taken; 25 cleared icons == Kodamas counter in the test save.
// What this class does every frame (LateUpdate, after the game's own map code): keeps wanted icons active + enabled, tinted per
// category when still to collect, grey / transparent / smaller when taken. Switching a category off restores the game's own state.
using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;
using UnityEngine;
using UnityEngine.UI;

namespace BoTrainer
{
    public static class MapTracker
    {
        public enum Cat { Kodama, Chest, Omamori, Bamboo, Ore, Silk, Root, Petal, Vermillion, Seed, Blossom, Other }

        sealed class Entry
        {
            public HandleMapIcon H;
            public Image Img;
            public Cat C;
            public string Name;
            public Vector3 Scale;
            public Color Col;
            public bool WasActive;
            public bool Forced;
        }

        public static bool KodamaOn = true;       // always show every Kodama (default on)
        public static bool AllOn;                 // hotkey: also show every other collectible / quest item
        public static float TakenAlpha = 0.30f;

        static readonly List<Entry> list = new List<Entry>();
        static MapIconsManager mgr;
        static float nextScan;

        public static int KodamaTotal, KodamaTaken, OtherTotal, OtherTaken;
        public static string LastError = "";

        // ---- appearance -------------------------------------------------------------------------------------------------
        static Color TintOf(Cat c)
        {
            switch (c)
            {
                case Cat.Kodama: return new Color(0.35f, 1.00f, 0.35f, 1f);
                case Cat.Chest: return new Color(1.00f, 0.82f, 0.20f, 1f);
                case Cat.Omamori: return new Color(1.00f, 0.45f, 0.85f, 1f);
                case Cat.Bamboo: return new Color(0.75f, 1.00f, 0.20f, 1f);
                case Cat.Ore: return new Color(0.45f, 0.65f, 1.00f, 1f);
                case Cat.Silk: return new Color(1.00f, 1.00f, 1.00f, 1f);
                case Cat.Root: return new Color(1.00f, 0.60f, 0.20f, 1f);
                case Cat.Petal: return new Color(1.00f, 0.72f, 0.80f, 1f);
                case Cat.Vermillion: return new Color(1.00f, 0.25f, 0.25f, 1f);
                case Cat.Seed: return new Color(0.40f, 1.00f, 1.00f, 1f);
                default: return Color.white;
            }
        }

        static float ScaleOf(Cat c) { return c == Cat.Kodama ? 1.35f : 1.0f; }

        public static string Legend
        {
            get { return "Map: green=Kodama gold=chest pink=omamori lime=bamboo blue=ore white=silk orange=root rose=petal red=crystal cyan=seed; grey/faint = already taken"; }
        }

        // ---- classification ---------------------------------------------------------------------------------------------
        static bool Has(string lower, string word) { return lower.IndexOf(word, StringComparison.Ordinal) >= 0; }

        static Cat Classify(HandleMapIcon h, Image img, out bool tracked)
        {
            string n = h.name.ToLowerInvariant();
            tracked = true;
            if (Has(n, "kodama")) return Cat.Kodama;
            if (h.Action == HandleMapIcon.ActionType.EnableWithIntuitionOmamori)
            {
                if (Has(n, "chest")) return Cat.Chest;
                if (Has(n, "omamori") || Has(n, "confidence")) return Cat.Omamori;
                if (Has(n, "bamboo")) return Cat.Bamboo;
                if (Has(n, "_ore") || Has(n, "tealore")) return Cat.Ore;
                if (Has(n, "silk")) return Cat.Silk;
                if (Has(n, "root")) return Cat.Root;
                if (Has(n, "petal")) return Cat.Petal;
                if (Has(n, "vermillion")) return Cat.Vermillion;
                if (Has(n, "lotusseed")) return Cat.Seed;
                return Cat.Other;
            }
            if (img != null && img.sprite != null && img.sprite.name == "BunnyBlossomMapIcon") return Cat.Blossom;
            tracked = false;
            return Cat.Other;
        }

        // ---- scanning ---------------------------------------------------------------------------------------------------
        static MapIconsManager CurrentManager()
        {
            MapInstanceCache mic = MapInstanceCache.Instance;
            return mic == null ? null : mic.MapIconsManager;
        }

        public static void Rescan()
        {
            list.Clear();
            mgr = CurrentManager();
            if (mgr == null) return;
            HandleMapIcon[] all = mgr.GetComponentsInChildren<HandleMapIcon>(true);
            foreach (HandleMapIcon h in all)
            {
                Image img = h.IconImage != null ? h.IconImage : h.GetComponentInChildren<Image>(true);
                if (img == null) continue;
                bool tracked;
                Cat c = Classify(h, img, out tracked);
                if (!tracked) continue;
                Entry e = new Entry();
                e.H = h; e.Img = img; e.C = c; e.Name = h.name;
                e.Scale = h.transform.localScale; e.Col = img.color; e.WasActive = h.gameObject.activeSelf;
                list.Add(e);
            }
        }

        static bool NeedRescan()
        {
            if (CurrentManager() != mgr) return true;
            if (list.Count == 0) return true;
            return list[0].H == null || list[list.Count - 1].H == null;
        }

        static bool IsTaken(GameManager gm, Entry e)
        {
            return gm.MapClearedconsDictionary.ContainsKey(e.Name);
        }

        static bool OmamoriOn()
        {
            try { MapInstanceCache m = MapInstanceCache.Instance; return m != null && m.IntuitionOmamori != null && m.IntuitionOmamori.CanUseOmamori(); }
            catch (Exception) { return false; }
        }

        // ---- per-frame update ---------------------------------------------------------------------------------------------
        public static void Tick()
        {
            GameManager gm = GameManager.Instance;
            if (gm == null || gm.MapClearedconsDictionary == null) return;
            if (NeedRescan())
            {
                if (Time.unscaledTime < nextScan) return;
                nextScan = Time.unscaledTime + 1f;
                Rescan();
                if (list.Count == 0) return;
            }
            int kt = 0, kk = 0, ot = 0, ok = 0;
            bool omamori = false, omamoriKnown = false;
            for (int i = 0; i < list.Count; i++)
            {
                Entry e = list[i];
                if (e.H == null || e.Img == null) continue;
                bool taken = IsTaken(gm, e);
                if (e.C == Cat.Kodama) { kt++; if (taken) kk++; } else { ot++; if (taken) ok++; }
                bool want = e.C == Cat.Kodama ? KodamaOn : AllOn;
                if (want) Force(e, taken);
                else if (e.Forced)
                {
                    if (!omamoriKnown) { omamori = OmamoriOn(); omamoriKnown = true; }
                    Restore(e, taken, omamori);
                }
            }
            KodamaTotal = kt; KodamaTaken = kk; OtherTotal = ot; OtherTaken = ok;
        }

        static void Force(Entry e, bool taken)
        {
            GameObject go = e.H.gameObject;
            if (!e.Forced) { e.Scale = e.H.transform.localScale; e.Col = e.Img.color; e.WasActive = go.activeSelf; e.Forced = true; }
            if (!go.activeSelf) go.SetActive(true);                  // (Awake of a never-activated icon disables its image - enable after)
            if (!e.Img.enabled) e.Img.enabled = true;
            Color c; float s;
            if (taken)
            {
                c = new Color(0.62f, 0.62f, 0.62f, TakenAlpha);
                s = 0.8f;
            }
            else
            {
                c = TintOf(e.C);
                s = ScaleOf(e.C);
            }
            if (e.Img.color != c) e.Img.color = c;
            Vector3 ns = e.Scale * s;
            if (e.H.transform.localScale != ns) e.H.transform.localScale = ns;
        }

        static void Restore(Entry e, bool taken, bool omamori)
        {
            e.Forced = false;
            e.Img.color = e.Col;
            e.H.transform.localScale = e.Scale;
            if (taken)
            {
                if (!e.WasActive) e.H.gameObject.SetActive(false);
            }
            else if (e.C != Cat.Blossom)
            {
                e.Img.enabled = omamori;                              // what MapIconsManager.SetMapSecretIcons would do
            }
        }

        public static void Toggle() { AllOn = !AllOn; }

        // ---- self test --------------------------------------------------------------------------------------------------
        static string Esc(string s) { return s; }

        public static bool SelfTest(out string detail)
        {
            StringBuilder d = new StringBuilder();
            bool ok = true;
            bool kOn = KodamaOn, aOn = AllOn;
            try
            {
                GameManager gm = GameManager.Instance;
                InventoryContainer inv = gm.inventoryContainer;
                MapIconsManager m = CurrentManager();
                if (m == null) { detail = "no MapIconsManager"; return false; }
                Rescan();
                KodamaOn = true; AllOn = false;
                Tick();
                d.Append("kodama_icons=" + KodamaTotal + " taken=" + KodamaTaken + " game_counter=" + inv.Kodamas + "; ");
                bool total34 = KodamaTotal == 34;
                bool counterMatches = KodamaTaken == inv.Kodamas;
                if (!total34 || !counterMatches) ok = false;
                // visual state
                int shownOk = 0, fadedOk = 0, brightOk = 0, nTaken = 0, nLeft = 0;
                foreach (Entry e in list)
                {
                    if (e.C != Cat.Kodama) continue;
                    bool taken = IsTaken(gm, e);
                    bool visible = e.H.gameObject.activeInHierarchy && e.Img.enabled;
                    if (visible) shownOk++;
                    if (taken) { nTaken++; if (e.Img.color.a < 0.5f) fadedOk++; }
                    else { nLeft++; if (e.Img.color.a > 0.99f) brightOk++; }
                }
                d.Append("visible=" + shownOk + "/" + KodamaTotal + " faded_taken=" + fadedOk + "/" + nTaken + " bright_left=" + brightOk + "/" + nLeft + "; ");
                if (shownOk != KodamaTotal || fadedOk != nTaken || brightOk != nLeft) ok = false;

                // delta test: take one still-waiting Kodama exactly like the game does (MapIconsManager.ClearedIcon) and expect the tracker to fade it
                Entry pick = null;
                foreach (Entry e in list) if (e.C == Cat.Kodama && !IsTaken(gm, e)) { pick = e; break; }
                if (pick != null)
                {
                    bool inAll = m.AllMapIconsList.Contains(pick.H), inSecret = m.AllSecretIconsList.Contains(pick.H);
                    bool hadActive = gm.MapActiveIconsDictionary.ContainsKey(pick.Name);
                    bool hadSecret = gm.MapSecretIconsDictionary.ContainsKey(pick.Name);
                    int takenBefore = KodamaTaken;
                    m.ClearedIcon(pick.Name);
                    Tick();
                    bool nowTaken = IsTaken(gm, pick) && KodamaTaken == takenBefore + 1;
                    bool faded = pick.H.gameObject.activeInHierarchy && pick.Img.enabled && pick.Img.color.a < 0.5f;
                    // undo the simulated pick
                    gm.MapClearedconsDictionary.Remove(pick.Name);
                    if (!hadSecret) gm.MapSecretIconsDictionary.Remove(pick.Name);
                    if (hadActive && !gm.MapActiveIconsDictionary.ContainsKey(pick.Name)) gm.MapActiveIconsDictionary.Add(pick.Name, true);
                    if (inAll && !m.AllMapIconsList.Contains(pick.H)) m.AllMapIconsList.Add(pick.H);
                    if (inSecret && !m.AllSecretIconsList.Contains(pick.H)) m.AllSecretIconsList.Add(pick.H);
                    Tick();
                    bool back = !IsTaken(gm, pick) && pick.Img.color.a > 0.99f && KodamaTaken == takenBefore;
                    d.Append("pick_delta: taken+1=" + nowTaken + " faded=" + faded + " undo_ok=" + back + " (" + pick.Name + "); ");
                    if (!nowTaken || !faded || !back) ok = false;
                }
                else d.Append("pick_delta: skipped (all Kodamas already taken); ");

                // category toggle
                AllOn = true; Tick();
                int others = 0, othersShown = 0;
                foreach (Entry e in list)
                    if (e.C != Cat.Kodama) { others++; if (e.H.gameObject.activeInHierarchy && e.Img.enabled) othersShown++; }
                d.Append("collectibles_on: shown=" + othersShown + "/" + others + "; ");
                if (others < 70 || othersShown != others) ok = false;
                AllOn = false; Tick();
                int stillForced = 0;
                foreach (Entry e in list) if (e.C != Cat.Kodama && e.Forced) stillForced++;
                bool omamori = OmamoriOn();
                int wrongOff = 0;
                foreach (Entry e in list)
                {
                    if (e.C == Cat.Kodama || e.C == Cat.Blossom) continue;
                    bool taken = IsTaken(gm, e);
                    bool wantEnabled = !taken && omamori;
                    if (!taken && e.Img.enabled != wantEnabled) wrongOff++;
                    if (taken && e.H.gameObject.activeSelf && !e.WasActive) wrongOff++;
                }
                d.Append("collectibles_off: forced_left=" + stillForced + " restored_wrong=" + wrongOff + " intuition_omamori=" + omamori + "; ");
                if (stillForced != 0 || wrongOff != 0) ok = false;
            }
            catch (Exception ex) { d.Append("EXCEPTION " + ex.Message); ok = false; }
            KodamaOn = kOn; AllOn = aOn;
            detail = d.ToString();
            return ok;
        }
    }
}
