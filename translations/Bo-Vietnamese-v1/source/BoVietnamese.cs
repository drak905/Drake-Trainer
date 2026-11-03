// Bo: Path of the Teal Lotus - Vietnamese language pack (BepInEx 5 + Harmony plugin).
//
// What it does (all at runtime, no game file is modified):
//   1. Adds a new language "Vietnamese" (code "vi") to the game's I2 Localization source and fills every text term with the
//      Vietnamese translation (translation table is embedded in this DLL as vi.tsv, keyed by a hash of the English text).
//   2. Adds the same translation to the Dialogue System (2,484 dialogue entries) through a "vi" field on each entry
//      and localises actor display names.
//   3. Creates TextMeshPro SDF font assets from Noto Sans (ships next to the DLL) because the game's own fonts have no
//      Vietnamese glyphs, clones the game's font materials (outline / colour look) and maps the game's font terms to them.
//   4. Adds "Tiếng Việt" to the in-game language dropdown (Options > Language).
//   5. Optional self test (TRAINER_SELFTEST=1 or vi_selftest.flag in the game folder) -> vi_selftest_report.json.
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using BepInEx;
using BepInEx.Configuration;
using HarmonyLib;
using I2.Loc;
using PixelCrushers.DialogueSystem;
using TMPro;
using UnityEngine;
using UnityEngine.TextCore.LowLevel;
using UnityEngine.UI;

namespace BoVietnamese
{
    [BepInPlugin(PluginGuid, "Bo Vietnamese Language Pack", "1.0.0")]
    public class VietnamesePlugin : BaseUnityPlugin
    {
        public const string PluginGuid = "com.research.bovietnamese";
        internal const string LangName = "Vietnamese";
        internal const string LangCode = "vi";
        internal const string NativeName = "Tiếng Việt";

        internal static VietnamesePlugin Instance;
        internal static Harmony Harm;
        internal static string PluginDir;
        internal static readonly Dictionary<ulong, string> Map = new Dictionary<ulong, string>();
        internal static readonly Dictionary<string, string> PatchStatus = new Dictionary<string, string>();
        internal static ConfigEntry<bool> CfgSmallerText;
        internal static ConfigEntry<bool> CfgSelectOnFirstRun;
        internal static int InjectedSources;
        internal static int TermsTranslated;
        internal static int TermsMissing;
        bool selfTest, selfTestRan;
        float startedAt;

        internal static void Log(string s) { if (Instance != null) Instance.Logger.LogInfo(s); }
        internal static void Warn(string s) { if (Instance != null) Instance.Logger.LogWarning(s); }

        void Awake()
        {
            Instance = this;
            startedAt = Time.realtimeSinceStartup;
            PluginDir = Path.GetDirectoryName(Info.Location);
            CfgSmallerText = Config.Bind("General", "SmallerTextLikeOtherEuropeanLanguages", true,
                "Apply the game's 'smaller font' rules (used for Spanish/French/German/...) to Vietnamese because it is longer than English.");
            CfgSelectOnFirstRun = Config.Bind("General", "SelectVietnameseWhenSystemIsVietnamese", true,
                "Handled by the game's own device-language detection (nothing to do here); kept for documentation.");
            try { LoadTranslations(); }
            catch (Exception e) { Logger.LogError("Cannot load translations: " + e); return; }
            Harm = new Harmony(PluginGuid);
            Patches.Apply(Harm);
            // Sources that were registered before this plugin ran
            try { foreach (var s in new List<LanguageSourceData>(LocalizationManager.Sources)) Injector.Inject(s); }
            catch (Exception e) { Logger.LogWarning("early inject: " + e.Message); }
            selfTest = Environment.GetEnvironmentVariable("TRAINER_SELFTEST") == "1"
                || File.Exists(Path.Combine(Paths.GameRootPath, "vi_selftest.flag"));
            Logger.LogInfo("Vietnamese pack loaded: " + Map.Count + " translations, plugin dir " + PluginDir);
        }

        float nextProtect;
        bool forced;
        void Update()
        {
            if (Time.realtimeSinceStartup > nextProtect) { nextProtect = Time.realtimeSinceStartup + 2f; ViFonts.ProtectAll(); }
            if (!forced && Environment.GetEnvironmentVariable("BO_VI_FORCE") == "1" && Time.realtimeSinceStartup - startedAt > 6f && LocalizationManager.Sources.Count > 0)
            {
                forced = true;   // test aid only: select Vietnamese without saving it to the player's settings
                LocalizationManager.SetLanguageAndCode(LangName, LangCode, false, true);
                var d = UnityEngine.Object.FindObjectOfType<PixelCrushers.DialogueSystem.I2Support.DialogueSystemUseI2Language>();
                if (d != null) d.UseCurrentI2Language();
                Localization.language = LangCode;
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
        internal static int ViIndex(LanguageSourceData src)
        {
            return src.GetLanguageIndex(VietnamesePlugin.LangName, false, false);
        }

        internal static void Inject(LanguageSourceData src)
        {
            if (src == null || src.mLanguages.Count == 0 || src.mTerms.Count == 0) return;
            if (ViIndex(src) >= 0) return;
            int en = src.GetLanguageIndexFromCode("en-US", true, false);
            if (en < 0) en = 0;
            src.AddLanguage(VietnamesePlugin.LangName, VietnamesePlugin.LangCode);
            int vi = ViIndex(src);
            if (vi < 0) { VietnamesePlugin.Warn("AddLanguage failed"); return; }
            int ukr = src.GetLanguageIndex("Ukrainian", false, false);
            int translated = 0, missing = 0;
            for (int i = 0; i < src.mTerms.Count; i++)
            {
                TermData t = src.mTerms[i];
                if (t.Languages.Length <= vi) continue;
                string e = t.Languages[en];
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
                else if (t.TermType == eTermType.TextMeshPFont && ukr >= 0)
                {
                    t.Languages[vi] = t.Languages[ukr];    // default: Ukrainian (Noto Sans) fonts; replaced below
                }
                else
                {
                    t.Languages[vi] = e;
                }
            }
            VietnamesePlugin.InjectedSources++;
            VietnamesePlugin.TermsTranslated += translated;
            VietnamesePlugin.TermsMissing += missing;
            VietnamesePlugin.Log("Injected '" + VietnamesePlugin.LangName + "' into source (index " + vi + "): " + translated + " terms translated, " + missing + " kept in English");
            try { ViFonts.Install(src, vi, ukr); }
            catch (Exception ex) { VietnamesePlugin.Warn("Font setup failed, using game fonts: " + ex); }
        }
    }

    // ------------------------------------------------------------------ fonts
    static class ViFonts
    {
        internal static readonly Dictionary<string, TMP_FontAsset> ByTerm = new Dictionary<string, TMP_FontAsset>();
        internal static readonly List<TMP_FontAsset> All = new List<TMP_FontAsset>();
        internal static TMP_FontAsset DropdownFont;
        internal static string LastError = "";
        const string Sample = "ăâđêôơưĂÂĐÊÔƠƯàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ";

        static readonly string[][] Plan = new string[][]
        {
            // term name, ttf file, asset name, game font whose material (outline/colour look) is cloned
            new[] { "Assets/FontNoOutlineAnyColor",            "NotoSans-Regular.ttf", "BoVi_Body_NoOutline", "Fonts/European Fonts/Ukrainian/Ukrainian_NotoSans_NoOutline" },
            new[] { "Assets/FontBlackOutlineWhiteTextColor",   "NotoSans-Regular.ttf", "BoVi_Body_BlackOutline", "Fonts/European Fonts/Ukrainian/UkrainianNotoSans_BlackOutline_WhiteTextColor" },
            new[] { "Assets/TitleNoOutlineAnyColor",           "NotoSans-Bold.ttf",    "BoVi_Title_NoOutline", "Fonts/European Fonts/Ukrainian/Ukrainian_NotoSans_NoOutline" },
            new[] { "Assets/TitleBlackOutlineWhiteTextColor",  "NotoSans-Bold.ttf",    "BoVi_Title_BlackOutline", "Fonts/European Fonts/Ukrainian/UkrainianNotoSans_BlackOutline_WhiteTextColor" },
            new[] { "Assets/TitleBlackTextWhiteOutline",       "NotoSans-Bold.ttf",    "BoVi_Title_WhiteOutline", "Fonts/European Fonts/Ukrainian/UkrainianNotoSans_WhiteOutline" },
            new[] { "Assets/DyslexicFontNoOutlineAnyColor",    "NotoSans-Regular.ttf", "BoVi_Dys_NoOutline", "Fonts/European Fonts/Ukrainian/Ukrainian_NotoSans_NoOutline" },
            new[] { "Assets/DyslexicFontBlackOutlineWhiteTextColor", "NotoSans-Regular.ttf", "BoVi_Dys_BlackOutline", "Fonts/European Fonts/Ukrainian/UkrainianNotoSans_BlackOutline_WhiteTextColor" },
        };

        internal static void Install(LanguageSourceData src, int vi, int ukr)
        {
            foreach (var row in Plan)
            {
                TermData td = src.GetTermData(row[0]);
                if (td == null || td.Languages.Length <= vi) continue;
                string basePath = row[3];
                TMP_FontAsset baseFa = string.IsNullOrEmpty(basePath) ? null : Resources.Load<TMP_FontAsset>(basePath);
                TMP_FontAsset fa = null;
                try { fa = Make(Path.Combine(VietnamesePlugin.PluginDir, row[1]), row[2], baseFa); }
                catch (Exception e) { LastError = e.ToString(); VietnamesePlugin.Warn("font " + row[2] + ": " + e.Message); }
                if (fa == null) continue;
                src.AddAsset(fa);
                td.Languages[vi] = fa.name;
                ByTerm[row[0]] = fa;
                All.Add(fa);
                if (row[0] == "Assets/FontNoOutlineAnyColor") DropdownFont = fa;
            }
            VietnamesePlugin.Log("Vietnamese fonts ready: " + All.Count);
        }


        /// <summary>Keep our runtime-created objects alive across scene loads (Resources.UnloadUnusedAssets).</summary>
        internal static void Protect(TMP_FontAsset fa)
        {
            if (fa == null) return;
            fa.hideFlags = HideFlags.HideAndDontSave;
            if (fa.material != null) fa.material.hideFlags = HideFlags.HideAndDontSave;
            if (fa.sourceFontFile != null) fa.sourceFontFile.hideFlags = HideFlags.HideAndDontSave;
            Texture2D[] tex = fa.atlasTextures;
            if (tex != null) foreach (var t in tex) if (t != null) t.hideFlags = HideFlags.HideAndDontSave;
        }

        internal static void ProtectAll() { foreach (var f in All) Protect(f); }
        static TMP_FontAsset Make(string ttf, string name, TMP_FontAsset baseFa)
        {
            if (!File.Exists(ttf)) throw new FileNotFoundException(ttf);
            int pt = 90, pad = 9, aw = 1024, ah = 1024;
            if (baseFa != null)
            {
                pt = Mathf.Max(24, baseFa.faceInfo.pointSize);
                pad = Mathf.Max(4, baseFa.atlasPadding);
                aw = Mathf.Max(512, baseFa.atlasWidth);
                ah = Mathf.Max(512, baseFa.atlasHeight);
            }
            Font font = new Font(ttf);
            if (font == null) throw new Exception("Font load failed " + ttf);
            font.hideFlags = HideFlags.HideAndDontSave;
            TMP_FontAsset fa = TMP_FontAsset.CreateFontAsset(font, pt, pad, GlyphRenderMode.SDFAA, aw, ah, AtlasPopulationMode.Dynamic, true);
            if (fa == null) throw new Exception("CreateFontAsset returned null for " + ttf);
            fa.name = name;
            fa.hideFlags = HideFlags.HideAndDontSave;
            if (baseFa != null && baseFa.material != null)
            {
                // keep the game's look (outline width/colour, softness, shader) - only swap the atlas
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
            // make sure every Vietnamese letter is rasterised up-front so first use never stutters
            string missing;
            fa.TryAddCharacters(Sample + "ĂÂĐÊÔƠƯÀÁẢÃẠẰẮẲẴẶẦẤẨẪẬÈÉẺẼẸỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌỒỐỔỖỘỜỚỞỠỢÙÚỦŨỤỪỨỬỮỰỲÝỶỸỴ", out missing);
            if (!string.IsNullOrEmpty(missing)) VietnamesePlugin.Warn(name + ": glyphs missing: " + missing);
            Protect(fa);
            VietnamesePlugin.Log("font " + name + " pt=" + pt + " pad=" + pad + " atlas=" + aw + "x" + ah + " base=" + (baseFa != null ? baseFa.name : "-") + " glyphs=" + fa.characterTable.Count);
            return fa;
        }
    }

    // ------------------------------------------------------------------ Harmony patches
    static class Patches
    {
        static readonly Dictionary<int, bool> seenEntries = new Dictionary<int, bool>();

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
            Try(h, "Dropdown.OnEnable", delegate
            {
                var m = AccessTools.Method(typeof(SetLanguageDropdown), "OnEnable");
                if (m == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("DropdownEnable_Post"))); return true;
            });
            Try(h, "Dropdown.LanguageFont", delegate
            {
                var m = AccessTools.Method(typeof(SetLanguageDropdown), "LanguageFont");
                if (m == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("LanguageFont_Post"))); return true;
            });
            Try(h, "Dialogue.DialogueText", delegate
            {
                var m = AccessTools.Method(typeof(DialogueEntry), "GetCurrentDialogueTextField");
                if (m == null) return false;
                h.Patch(m, prefix: new HarmonyMethod(Own("EntryField_Pre"))); return true;
            });
            Try(h, "Dialogue.MenuText", delegate
            {
                var m = AccessTools.Method(typeof(DialogueEntry), "GetCurrentMenuTextField");
                if (m == null) return false;
                h.Patch(m, prefix: new HarmonyMethod(Own("EntryField_Pre"))); return true;
            });
            Try(h, "Dialogue.ActorName", delegate
            {
                var m = AccessTools.Method(typeof(PixelCrushers.DialogueSystem.CharacterInfo), "GetLocalizedDisplayNameInDatabase");
                if (m == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("ActorName_Post"))); return true;
            });
            Try(h, "Size.CustomFontSizePerLanguage", delegate
            {
                var m = AccessTools.Method(typeof(CustomFontSizePerLanguage), "InitializeHashSet");
                if (m == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("SizeSet_Post"))); return true;
            });
            Try(h, "Size.ComboUIPopup", delegate
            {
                var m = AccessTools.Method(typeof(ComboUIPopup), "InitializeHashSet");
                if (m == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("SizeSet_Post"))); return true;
            });
            foreach (var kv in VietnamesePlugin.PatchStatus) VietnamesePlugin.Log("patch " + kv.Key + ": " + kv.Value);
        }

        // --- I2 -------------------------------------------------------------------------------
        static void AddSource_Post(LanguageSourceData Source)
        {
            try { Injector.Inject(Source); } catch (Exception e) { VietnamesePlugin.Warn("inject: " + e); }
        }

        // --- language dropdown ----------------------------------------------------------------
        static readonly FieldInfo DropdownField = AccessTools.Field(typeof(SetLanguageDropdown), "dropdown");

        static void DropdownEnable_Post(SetLanguageDropdown __instance)
        {
            try
            {
                var dd = DropdownField.GetValue(__instance) as TMP_Dropdown;
                if (dd == null) return;
                List<string> langs = LocalizationManager.GetAllLanguages();
                int vi = langs.IndexOf(VietnamesePlugin.LangName);
                if (vi < 0) return;
                bool has = false;
                foreach (var o in dd.options) if (o.text == VietnamesePlugin.NativeName) has = true;
                if (!has)
                {
                    while (dd.options.Count < vi) dd.options.Add(new TMP_Dropdown.OptionData(langs[dd.options.Count]));
                    dd.options.Add(new TMP_Dropdown.OptionData(VietnamesePlugin.NativeName));
                }
                int cur = langs.IndexOf(LocalizationManager.CurrentLanguage);
                if (cur >= 0) dd.SetValueWithoutNotify(cur);
                dd.RefreshShownValue();
                if (cur == vi && ViFonts.DropdownFont != null && dd.captionText != null) dd.captionText.font = ViFonts.DropdownFont;
            }
            catch (Exception e) { VietnamesePlugin.Warn("dropdown: " + e.Message); }
        }

        static void LanguageFont_Post(int index, ref TMP_FontAsset __result)
        {
            if (index >= 10 && ViFonts.DropdownFont != null) __result = ViFonts.DropdownFont;
        }

        // --- Dialogue System ------------------------------------------------------------------
        static void EntryField_Pre(DialogueEntry __instance)
        {
            if (Localization.language != VietnamesePlugin.LangCode) return;
            try
            {
                List<Field> fields = __instance.fields;
                if (fields == null || Field.Lookup(fields, VietnamesePlugin.LangCode) != null) return;
                string en = Field.LookupValue(fields, "Dialogue Text");
                string vi = VietnamesePlugin.Tr(en);
                if (vi != null) fields.Add(new Field(VietnamesePlugin.LangCode, vi, FieldType.Localization));
            }
            catch (Exception e) { VietnamesePlugin.Warn("entry: " + e.Message); }
        }

        static void ActorName_Post(ref string __result)
        {
            if (Localization.language != VietnamesePlugin.LangCode) return;
            string vi = VietnamesePlugin.Tr(__result);
            if (vi != null) __result = vi;
        }

        // --- sizes ----------------------------------------------------------------------------
        static void SizeSet_Post(object __instance)
        {
            if (!VietnamesePlugin.CfgSmallerText.Value) return;
            try
            {
                var f = AccessTools.Field(__instance.GetType(), "languagesForSmallerFontSize");
                var set = f.GetValue(__instance) as HashSet<string>;
                if (set != null && set.Count > 0) set.Add(VietnamesePlugin.LangName);
            }
            catch (Exception e) { VietnamesePlugin.Warn("size: " + e.Message); }
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

        internal static void Run()
        {
            string original = LocalizationManager.CurrentLanguage;
            // 1 language registered
            var langs = LocalizationManager.GetAllLanguages();
            Feature("language_registered", langs.Contains(VietnamesePlugin.LangName), string.Join(",", langs.ToArray()));
            // 2 patches
            foreach (var kv in VietnamesePlugin.PatchStatus) Feature("patch:" + kv.Key, kv.Value == "ok", kv.Value);
            // 3 term translation
            string expectPlay = VietnamesePlugin.Tr("Play");
            LocalizationManager.CurrentLanguage = VietnamesePlugin.LangName;
            string play = LocalizationManager.GetTranslation("UI/PlayButton");
            Feature("switch_language", LocalizationManager.CurrentLanguage == VietnamesePlugin.LangName && LocalizationManager.CurrentLanguageCode == "vi", LocalizationManager.CurrentLanguage + "/" + LocalizationManager.CurrentLanguageCode);
            Feature("ui_term_translated", play == expectPlay && !string.IsNullOrEmpty(play) && play != "Play", "UI/PlayButton=" + play);
            Feature("terms_coverage", VietnamesePlugin.TermsTranslated > 2000 && VietnamesePlugin.TermsMissing < 40, "translated=" + VietnamesePlugin.TermsTranslated + " english_fallback=" + VietnamesePlugin.TermsMissing);
            string tip = LocalizationManager.GetTranslation("UI/LoadingTip5");
            Feature("markup_preserved", tip.Contains("<style=Player/DarumaAction>") && tip.Contains("<color=#63faff>"), tip);
            // 4 fonts
            int okFonts = 0; var fd = new StringBuilder();
            foreach (var kv in ViFonts.ByTerm)
            {
                var mb = new StringBuilder(); foreach (char ch in "ăâđêôơưếềểễệồốổỗộờớởỡợừứửữựỳýỷỹỵĂÂĐÊÔƠƯẾỀỂỄỆ") if (!kv.Value.HasCharacter(ch, false)) mb.Append(ch); string miss = mb.ToString();
                bool ok = string.IsNullOrEmpty(miss) && kv.Value.material != null && kv.Value.material.shader != null;
                if (ok) okFonts++;
                fd.Append(kv.Key).Append('=').Append(ok ? "ok" : "missing[" + miss + "]").Append(' ');
            }
            Feature("fonts_vietnamese_glyphs", okFonts == ViFonts.ByTerm.Count && okFonts >= 5, fd.ToString());
            string fontTerm = LocalizationManager.GetTranslation("Assets/FontNoOutlineAnyColor", false);
            Feature("font_term_mapped", fontTerm == "BoVi_Body_NoOutline" && LocalizationManager.GetTranslatedObject<TMP_FontAsset>(fontTerm) != null, fontTerm);
            // 5 dialogue
            var db = DialogueManager.MasterDatabase;
            if (db != null)
            {
                Localization.language = "vi";
                int total = 0, tr = 0, noMap = 0; string sample = "";
                foreach (var c in db.conversations)
                    foreach (var e in c.dialogueEntries)
                    {
                        string en = Field.LookupValue(e.fields, "Dialogue Text");
                        if (string.IsNullOrEmpty(en)) continue;
                        total++;
                        string expect = VietnamesePlugin.Tr(en);
                        if (expect == null) { noMap++; continue; }
                        if (e.currentDialogueText == expect) { tr++; if (sample == "") sample = expect; }
                    }
                Feature("dialogue_entries", noMap == 0 && tr == total, tr + "/" + total + " served in Vietnamese, unmapped=" + noMap + " e.g. " + sample);
                Localization.language = original == VietnamesePlugin.LangName ? "vi" : LocalizationManager.GetLanguageCode(original);
            }
            else Feature("dialogue_entries", false, "no master database");
            // restore language
            LocalizationManager.CurrentLanguage = original;
            Feature("language_restored", LocalizationManager.CurrentLanguage == original, original);
            string path = Path.Combine(Paths.GameRootPath, "vi_selftest_report.json");
            File.WriteAllText(path, "{\"overall_status\":" + J(allOk ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL") + ",\"feature_results\":[\n" + string.Join(",\n", Results.ToArray()) + "\n]}", new UTF8Encoding(false));
            VietnamesePlugin.Log("selftest report written: " + path);
        }
    }
}
