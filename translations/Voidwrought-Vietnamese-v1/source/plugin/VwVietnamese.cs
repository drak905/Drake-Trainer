// Voidwrought - Vietnamese language pack (BepInEx 5 + Harmony plugin).
//
// What it does (all at runtime, no game file is modified):
//   1. Adds a new language "Vietnamese" (code "vi") to the game's I2 Localization source (every UI / dialogue / lore /
//      compendium / achievement / tutorial / credits term). The translation table is embedded in this DLL as vi.tsv,
//      keyed by an FNV-1a hash of the English text, so it keeps working when the game's term keys change.
//   2. The game's own NotoSans TMP fonts have no glyphs for the stacked Vietnamese vowels (ả ạ ằ ắ ... ỹ ỵ), so the plugin
//      builds four dynamic TextMeshPro fallback fonts (Regular / Bold / Italic / BoldItalic, Noto Sans TTFs shipped
//      next to the DLL), clones the game's font materials and attaches them as the first fallback of the game's
//      NotoSans fonts while Vietnamese is the current language.
//   3. The language selector (Options > Language) is built from the I2 language list, so "Tiếng Việt" appears there
//      automatically (term app_language).
//   4. Optional self test (TRAINER_SELFTEST=1 or vi_selftest.flag in the game folder) -> vi_selftest_report.json.
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using BepInEx;
using HarmonyLib;
using I2.Loc;
using TMPro;
using UnityEngine;
using UnityEngine.TextCore.LowLevel;

namespace VwVietnamese
{
    [BepInPlugin(PluginGuid, "Voidwrought Vietnamese Language Pack", "1.0.0")]
    public class VietnamesePlugin : BaseUnityPlugin
    {
        public const string PluginGuid = "com.research.vwvietnamese";
        internal const string LangName = "Vietnamese";
        internal const string LangCode = "vi";
        internal const string NativeName = "Tiếng Việt";

        internal static VietnamesePlugin Instance;
        internal static Harmony Harm;
        internal static string PluginDir;
        internal static readonly Dictionary<ulong, string> Map = new Dictionary<ulong, string>();
        internal static readonly Dictionary<string, string> PatchStatus = new Dictionary<string, string>();
        internal static int InjectedSources;
        internal static int TermsTranslated;
        internal static int TermsMissing;
        bool selfTest, selfTestRan, forced;
        float startedAt;

        internal static void Log(string s) { if (Instance != null) Instance.Logger.LogInfo(s); }
        internal static void Warn(string s) { if (Instance != null) Instance.Logger.LogWarning(s); }

        void Awake()
        {
            Instance = this;
            startedAt = Time.realtimeSinceStartup;
            PluginDir = Path.GetDirectoryName(Info.Location);
            try { LoadTranslations(); }
            catch (Exception e) { Logger.LogError("Cannot load translations: " + e); return; }
            Harm = new Harmony(PluginGuid);
            Patches.Apply(Harm);
            try { foreach (var s in new List<LanguageSourceData>(LocalizationManager.Sources)) Injector.Inject(s); }
            catch (Exception e) { Logger.LogWarning("early inject: " + e.Message); }
            selfTest = Environment.GetEnvironmentVariable("TRAINER_SELFTEST") == "1"
                || File.Exists(Path.Combine(Paths.GameRootPath, "vi_selftest.flag"));
            Logger.LogInfo("Vietnamese pack loaded: " + Map.Count + " translations, plugin dir " + PluginDir);
        }

        float nextProtect;
        void Update()
        {
            if (Time.realtimeSinceStartup > nextProtect) { nextProtect = Time.realtimeSinceStartup + 2f; ViFonts.ProtectAll(); }
            if (!forced && (Environment.GetEnvironmentVariable("VW_VI_FORCE") == "1" || File.Exists(Path.Combine(Paths.GameRootPath, "vi_force.flag"))) && Time.realtimeSinceStartup - startedAt > 6f
                && LocalizationManager.Sources.Count > 0 && Injector.Injected)
            {
                forced = true;   // test aid only: select Vietnamese without saving it to the player's settings
                LocalizationManager.CurrentLanguage = LangName;
            }
            if (selfTest && !selfTestRan && Time.realtimeSinceStartup - startedAt > 25f)
            {
                selfTestRan = true;
                try { SelfTest.Run(); } catch (Exception e) { Logger.LogError("selftest: " + e); }
            }
        }

        // ---------------------------------------------------------------- translations
        static void LoadTranslations()
        {
            var asm = typeof(VietnamesePlugin).Assembly;
            string res = null;
            foreach (var n in asm.GetManifestResourceNames()) if (n.EndsWith("vi.tsv")) res = n;
            if (res == null) throw new FileNotFoundException("embedded vi.tsv not found");
            using (var rd = new StreamReader(asm.GetManifestResourceStream(res), new UTF8Encoding(false)))
            {
                string line;
                while ((line = rd.ReadLine()) != null)
                {
                    int tab = line.IndexOf('\t');
                    if (tab != 16) continue;
                    ulong h = Convert.ToUInt64(line.Substring(0, 16), 16);
                    Map[h] = Unescape(line.Substring(17));
                }
            }
        }

        static string Unescape(string s)
        {
            if (s.IndexOf('\\') < 0) return s;
            var sb = new StringBuilder(s.Length);
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (c == '\\' && i + 1 < s.Length)
                {
                    char n = s[++i];
                    sb.Append(n == 'n' ? '\n' : n == 'r' ? '\r' : n == 't' ? '\t' : n);
                }
                else sb.Append(c);
            }
            return sb.ToString();
        }

        internal static ulong Fnv(string s)
        {
            ulong h = 0xcbf29ce484222325UL;
            for (int i = 0; i < s.Length; i++) { h ^= (ulong)s[i]; h *= 0x100000001b3UL; }
            return h;
        }

        /// <summary>Vietnamese for an English game string, or null when there is no translation.</summary>
        internal static string Tr(string en)
        {
            if (string.IsNullOrEmpty(en)) return null;
            string v;
            return Map.TryGetValue(Fnv(en), out v) ? v : null;
        }
    }

    // ------------------------------------------------------------------ I2 injection
    static class Injector
    {
        internal static bool Injected;

        internal static int ViIndex(LanguageSourceData src)
        {
            return src.GetLanguageIndex(VietnamesePlugin.LangName, false, false);
        }

        internal static void Inject(LanguageSourceData src)
        {
            if (src == null || src.mLanguages.Count == 0 || src.mTerms.Count == 0) return;
            if (ViIndex(src) >= 0) return;
            int en = src.GetLanguageIndexFromCode("en", true, false);
            if (en < 0) en = 0;
            src.AddLanguage(VietnamesePlugin.LangName, VietnamesePlugin.LangCode);
            int vi = ViIndex(src);
            if (vi < 0) { VietnamesePlugin.Warn("AddLanguage failed"); return; }
            int translated = 0, missing = 0;
            for (int i = 0; i < src.mTerms.Count; i++)
            {
                TermData t = src.mTerms[i];
                if (t.Languages.Length <= vi) continue;
                string e = t.Languages[en];
                if (t.Term == "app_language") { t.Languages[vi] = VietnamesePlugin.NativeName; continue; }
                if (t.TermType == eTermType.Text)
                {
                    string v = VietnamesePlugin.Tr(e);
                    if (v != null) { t.Languages[vi] = v; translated++; }
                    else
                    {
                        t.Languages[vi] = e;               // fall back to English (never empty)
                        if (!string.IsNullOrEmpty(e)) missing++;
                    }
                }
                else t.Languages[vi] = e;
            }
            Injected = true;
            VietnamesePlugin.InjectedSources++;
            VietnamesePlugin.TermsTranslated += translated;
            VietnamesePlugin.TermsMissing += missing;
            VietnamesePlugin.Log("Injected '" + VietnamesePlugin.LangName + "' into source (index " + vi + "): " + translated + " terms translated, " + missing + " kept in English");
        }
    }

    // ------------------------------------------------------------------ fonts
    static class ViFonts
    {
        internal sealed class Style
        {
            public string Key, Ttf, AssetName;
            public TMP_FontAsset Fallback;
        }

        // style key = suffix of the game's "NotoSans-<style> SDF" font asset
        internal static readonly Style[] Styles = new Style[]
        {
            new Style { Key = "Regular",    Ttf = "NotoSans-Regular.ttf",    AssetName = "VwVi_Regular" },
            new Style { Key = "Bold",       Ttf = "NotoSans-Bold.ttf",       AssetName = "VwVi_Bold" },
            new Style { Key = "Italic",     Ttf = "NotoSans-Italic.ttf",     AssetName = "VwVi_Italic" },
            new Style { Key = "BoldItalic", Ttf = "NotoSans-BoldItalic.ttf", AssetName = "VwVi_BoldItalic" },
        };

        internal static string LastError = "";
        const string Letters = "ăâđêôơưĂÂĐÊÔƠƯàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵÀÁẢÃẠẰẮẲẴẶẦẤẨẪẬÈÉẺẼẸỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌỒỐỔỖỘỜỚỞỠỢÙÚỦŨỤỪỨỬỮỰỲÝỶỸỴ";
        internal static string AllLetters { get { return Letters; } }

        /// <summary>The game's roman fonts: every NotoSans-{Regular|Bold|Italic|BoldItalic} SDF asset in memory.</summary>
        internal static List<KeyValuePair<Style, TMP_FontAsset>> GameFonts()
        {
            var res = new List<KeyValuePair<Style, TMP_FontAsset>>();
            foreach (var f in Resources.FindObjectsOfTypeAll<TMP_FontAsset>())
            {
                if (f == null || f.name == null) continue;
                foreach (var st in Styles)
                    if (f.name == "NotoSans-" + st.Key + " SDF") { res.Add(new KeyValuePair<Style, TMP_FontAsset>(st, f)); break; }
            }
            return res;
        }

        internal static bool Ensure()
        {
            bool all = true;
            var game = GameFonts();
            foreach (var st in Styles)
            {
                if (st.Fallback != null) continue;
                TMP_FontAsset baseFa = null;
                foreach (var kv in game) if (kv.Key == st) { baseFa = kv.Value; break; }
                try { st.Fallback = Make(Path.Combine(VietnamesePlugin.PluginDir, st.Ttf), st.AssetName, baseFa); }
                catch (Exception e) { LastError = e.ToString(); VietnamesePlugin.Warn("font " + st.AssetName + ": " + e.Message); }
                if (st.Fallback == null) all = false;
            }
            return all;
        }

        internal static void Protect(TMP_FontAsset fa)
        {
            if (fa == null) return;
            fa.hideFlags = HideFlags.HideAndDontSave;
            if (fa.material != null) fa.material.hideFlags = HideFlags.HideAndDontSave;
            if (fa.sourceFontFile != null) fa.sourceFontFile.hideFlags = HideFlags.HideAndDontSave;
            Texture2D[] tex = fa.atlasTextures;
            if (tex != null) foreach (var t in tex) if (t != null) t.hideFlags = HideFlags.HideAndDontSave;
        }

        internal static void ProtectAll() { foreach (var st in Styles) Protect(st.Fallback); }

        static TMP_FontAsset Make(string ttf, string name, TMP_FontAsset baseFa)
        {
            if (!File.Exists(ttf)) throw new FileNotFoundException(ttf);
            const int pt = 100, pad = 11, aw = 2048, ah = 2048;
            Font font = new Font(ttf);
            if (font == null) throw new Exception("Font load failed " + ttf);
            font.hideFlags = HideFlags.HideAndDontSave;
            TMP_FontAsset fa = TMP_FontAsset.CreateFontAsset(font, pt, pad, GlyphRenderMode.SDFAA, aw, ah, AtlasPopulationMode.Dynamic, true);
            if (fa == null) throw new Exception("CreateFontAsset returned null for " + ttf);
            fa.name = name;
            fa.hideFlags = HideFlags.HideAndDontSave;
            if (baseFa != null && baseFa.material != null)
            {
                // keep the game's look (shader, face/outline settings) - only swap the atlas
                Material m = new Material(baseFa.material);
                m.name = name + " Material";
                m.hideFlags = HideFlags.HideAndDontSave;
                Texture atlas = fa.atlasTexture;
                m.SetTexture(ShaderUtilities.ID_MainTex, atlas);
                m.SetFloat(ShaderUtilities.ID_TextureWidth, atlas.width);
                m.SetFloat(ShaderUtilities.ID_TextureHeight, atlas.height);
                m.SetFloat(ShaderUtilities.ID_GradientScale, pad + 1);
                fa.material = m;
            }
            string missing;
            fa.TryAddCharacters(Letters, out missing);   // rasterise every Vietnamese letter up-front: no hitch on first use
            if (!string.IsNullOrEmpty(missing)) VietnamesePlugin.Warn(name + ": glyphs missing: " + missing);
            Protect(fa);
            VietnamesePlugin.Log("font " + name + " pt=" + pt + " pad=" + pad + " atlas=" + aw + "x" + ah + " base=" + (baseFa != null ? baseFa.name : "-") + " glyphs=" + fa.characterTable.Count);
            return fa;
        }

        /// <summary>Attach (vietnamese=true) or detach our fallbacks to/from the game's roman fonts and the TMP global list.</summary>
        internal static int Apply(bool vietnamese)
        {
            int changed = 0;
            if (vietnamese && !Ensure()) VietnamesePlugin.Warn("Vietnamese fonts incomplete: " + LastError);
            var game = GameFonts();
            foreach (var kv in game)
            {
                var table = kv.Value.fallbackFontAssetTable;
                if (table == null) continue;
                TMP_FontAsset ours = kv.Key.Fallback;
                // remove any of our fonts first (also from the other styles)
                foreach (var st in Styles) if (st.Fallback != null && table.Remove(st.Fallback)) changed++;
                if (vietnamese && ours != null) { table.Insert(0, ours); changed++; }
            }
            // global TMP fallback list: catches TMP texts that use some other font asset
            try
            {
                var inst = TMP_Settings.instance;
                var fld = typeof(TMP_Settings).GetField("m_fallbackFontAssets", BindingFlags.Instance | BindingFlags.NonPublic);
                if (inst != null && fld != null)
                {
                    var list = fld.GetValue(inst) as List<TMP_FontAsset>;
                    if (list == null) { list = new List<TMP_FontAsset>(); fld.SetValue(inst, list); }
                    foreach (var st in Styles) if (st.Fallback != null) list.Remove(st.Fallback);
                    if (vietnamese && Styles[0].Fallback != null) list.Add(Styles[0].Fallback);
                }
            }
            catch (Exception e) { VietnamesePlugin.Warn("global fallback: " + e.Message); }
            return changed;
        }
    }

    // ------------------------------------------------------------------ Harmony patches
    static class Patches
    {
        static void Try(Harmony h, string id, Func<bool> f)
        {
            try { bool ok = f(); VietnamesePlugin.PatchStatus[id] = ok ? "ok" : "target not found"; }
            catch (Exception e) { VietnamesePlugin.PatchStatus[id] = "error: " + e.Message; VietnamesePlugin.Warn("patch " + id + ": " + e); }
        }

        static MethodInfo Own(string name) { return typeof(Patches).GetMethod(name, BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public); }

        internal static void Apply(Harmony h)
        {
            Try(h, "I2.AddSource", delegate
            {
                var m = AccessTools.Method(typeof(LocalizationManager), "AddSource", new[] { typeof(LanguageSourceData) });
                if (m == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("AddSource_Post"))); return true;
            });
            // The game clears + refills the fallback tables of its roman fonts and THEN assigns CurrentLanguage
            // (Initializer.SetLanguage / SettingsMenu.SetLanguage); this prefix runs after the clear and before the texts re-localise.
            Try(h, "I2.CurrentLanguage", delegate
            {
                var m = AccessTools.PropertySetter(typeof(LocalizationManager), "CurrentLanguage");
                if (m == null) return false;
                h.Patch(m, prefix: new HarmonyMethod(Own("CurrentLanguage_Pre"))); return true;
            });
            foreach (var kv in VietnamesePlugin.PatchStatus) VietnamesePlugin.Log("patch " + kv.Key + ": " + kv.Value);
        }

        static void AddSource_Post(LanguageSourceData Source)
        {
            try { Injector.Inject(Source); } catch (Exception e) { VietnamesePlugin.Warn("inject: " + e); }
        }

        static void CurrentLanguage_Pre(string value)
        {
            try
            {
                bool vi = value == VietnamesePlugin.LangName;
                int n = ViFonts.Apply(vi);
                if (vi) VietnamesePlugin.Log("Vietnamese selected: fallback fonts attached to " + n + " font tables");
            }
            catch (Exception e) { VietnamesePlugin.Warn("language switch: " + e); }
        }
    }

    // ------------------------------------------------------------------ self test
    static class SelfTest
    {
        static string J(string s)
        {
            if (s == null) return "null";
            var sb = new StringBuilder("\"");
            foreach (char c in s)
            {
                if (c == '"') sb.Append("\\\""); else if (c == '\\') sb.Append("\\\\"); else if (c == '\n') sb.Append("\\n");
                else if (c == '\r') sb.Append("\\r"); else if (c == '\t') sb.Append("\\t"); else if (c < 32) sb.AppendFormat("\\u{0:x4}", (int)c); else sb.Append(c);
            }
            return sb.Append('"').ToString();
        }

        static readonly List<string> Results = new List<string>();
        static bool allOk = true;

        static void Feature(string id, bool ok, string detail)
        {
            if (!ok) allOk = false;
            Results.Add("{\"feature\":" + J(id) + ",\"status\":" + J(ok ? "PASS" : "FAIL") + ",\"detail\":" + J(detail) + "}");
            VietnamesePlugin.Log("selftest " + id + ": " + (ok ? "PASS" : "FAIL") + " " + detail);
        }

        static string Short(string s) { return s != null && s.Length > 90 ? s.Substring(0, 90) + "..." : s; }

        internal static void Run()
        {
            string original = LocalizationManager.CurrentLanguage;
            var langs = LocalizationManager.GetAllLanguages(true);
            Feature("language_registered", langs.Contains(VietnamesePlugin.LangName), string.Join(",", langs.ToArray()));
            Feature("language_is_last", langs.IndexOf(VietnamesePlugin.LangName) == langs.Count - 1, "index " + langs.IndexOf(VietnamesePlugin.LangName) + " of " + langs.Count);
            foreach (var kv in VietnamesePlugin.PatchStatus) Feature("patch:" + kv.Key, kv.Value == "ok", kv.Value);

            LocalizationManager.CurrentLanguage = VietnamesePlugin.LangName;
            Feature("switch_language", LocalizationManager.CurrentLanguage == VietnamesePlugin.LangName && LocalizationManager.CurrentLanguageCode == "vi",
                LocalizationManager.CurrentLanguage + "/" + LocalizationManager.CurrentLanguageCode);

            string lang = LocalizationManager.GetTranslation("app_language");
            Feature("language_native_name", lang == VietnamesePlugin.NativeName, lang);
            string back = LocalizationManager.GetTranslation("UI/generic_back");
            Feature("ui_term_translated", !string.IsNullOrEmpty(back) && back != "Back" && back == VietnamesePlugin.Tr("Back"), "UI/generic_back=" + back);

            // every text term: translated, markup preserved
            int total = 0, tr = 0, markupBad = 0, nlBad = 0; string firstBad = "";
            var source = LocalizationManager.Sources.Count > 0 ? LocalizationManager.Sources[0] : null;
            var chars = new HashSet<char>();
            if (source != null)
            {
                int en = source.GetLanguageIndexFromCode("en", true, false); if (en < 0) en = 0;
                int vi = Injector.ViIndex(source);
                foreach (var t in source.mTerms)
                {
                    string e = t.Languages[en];
                    if (string.IsNullOrEmpty(e) || t.TermType != eTermType.Text) continue;
                    string v = t.Languages[vi];
                    string expect = VietnamesePlugin.Tr(e);
                    total++;
                    if (expect != null && v == expect) tr++;
                    if (expect != null)
                    {
                        if (Count(e, "<i>") != Count(v, "<i>") || Count(e, "</i>") != Count(v, "</i>") || Count(e, "<b>") != Count(v, "<b>") || Count(e, "</b>") != Count(v, "</b>")) { markupBad++; if (firstBad == "") firstBad = t.Term; }
                        if (Count(e, "\n") != Count(v, "\n")) { nlBad++; if (firstBad == "") firstBad = t.Term; }
                        foreach (char c in v) chars.Add(c);
                    }
                }
            }
            Feature("terms_coverage", total > 1900 && tr >= total - 25, "translated " + tr + "/" + total + " english_fallback=" + VietnamesePlugin.TermsMissing);
            Feature("markup_and_newlines_preserved", markupBad == 0 && nlBad == 0, "markupBad=" + markupBad + " newlineBad=" + nlBad + " " + firstBad);

            // fonts: every character used by the Vietnamese text must resolve through base font + fallbacks
            var game = ViFonts.GameFonts();
            Feature("game_fonts_found", game.Count >= 4, game.Count + " NotoSans fonts in memory");
            int okFonts = 0; var fd = new StringBuilder();
            foreach (var kv in game)
            {
                var miss = new StringBuilder();
                foreach (char c in chars)
                {
                    if (c < ' ' || c == '\u00a0') continue;
                    if (!kv.Value.HasCharacter(c, true)) miss.Append(c);
                }
                bool attached = kv.Value.fallbackFontAssetTable.Count > 0 && kv.Value.fallbackFontAssetTable[0] == kv.Key.Fallback;
                bool ok = miss.Length == 0 && attached;
                if (ok) okFonts++;
                fd.Append(kv.Value.name).Append(ok ? "=ok " : "=missing[" + miss + "]attached=" + attached + " ");
            }
            Feature("fonts_vietnamese_glyphs", game.Count > 0 && okFonts == game.Count, fd.ToString());
            int dyn = 0; foreach (var st in ViFonts.Styles) if (st.Fallback != null && st.Fallback.atlasPopulationMode == AtlasPopulationMode.Dynamic && st.Fallback.material != null) dyn++;
            Feature("fallback_fonts_built", dyn == 4, dyn + "/4 dynamic fallback fonts with material");

            // switching away must detach everything again
            string other = langs.Contains("English") ? "English" : langs[0];
            LocalizationManager.CurrentLanguage = other;
            int leftover = 0;
            foreach (var kv in ViFonts.GameFonts()) foreach (var st in ViFonts.Styles) if (st.Fallback != null && kv.Value.fallbackFontAssetTable.Contains(st.Fallback)) leftover++;
            Feature("fonts_detached_for_other_language", leftover == 0 && LocalizationManager.GetTranslation("UI/generic_back") == "Back", "leftover=" + leftover + " back=" + LocalizationManager.GetTranslation("UI/generic_back"));

            LocalizationManager.CurrentLanguage = original;
            Feature("language_restored", LocalizationManager.CurrentLanguage == original, original);

            string path = Path.Combine(Paths.GameRootPath, "vi_selftest_report.json");
            File.WriteAllText(path, "{\"overall_status\":" + J(allOk ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL") + ",\"feature_results\":[\n" + string.Join(",\n", Results.ToArray()) + "\n]}", new UTF8Encoding(false));
            VietnamesePlugin.Log("selftest report written: " + path);
        }

        static int Count(string s, string sub)
        {
            int n = 0, i = 0;
            while ((i = s.IndexOf(sub, i, StringComparison.Ordinal)) >= 0) { n++; i += sub.Length; }
            return n;
        }
    }
}
