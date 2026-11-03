// 9 Years of Shadows - Vietnamese language pack (BepInEx 5 + Harmony plugin).
//
// What it does (all at runtime, no game file is modified):
//   1. The game stores every UI text in a ScriptableObject (LocalizedStringLibrary: tag -> one text per Language enum value) and every
//      spoken line in per-language Yarn programs (DialogueFileLibrary). Language values 1..8 are English..Dutch(German).
//      This plugin adds language value 9 = Vietnamese:
//        * LocalizedStringLibrary.GetLocalizedStringFromTag(tag, 9) -> embedded ui.tsv (tag -> Vietnamese)
//        * DialogueFileLibrary.GetLocalizedDialogueFileFromTag(tag, 9) -> English YarnProgram cloned with a Vietnamese string table
//          (embedded dlg.tsv, keyed by a hash of the English "Speaker:Text" line)
//   2. Adds "Tiếng Việt" to the language selector (Options > Game > Language) by appending a SpinnerRecord(9) to the spinner.
//   3. The game's TextMeshPro fonts (Jost) are dynamic and already contain the Vietnamese letters; the one static font asset
//      (Jost-SemiBold SDF No Outline) gets a dynamic fallback built from the same Jost font so Vietnamese letters render in the same style.
//   4. Optional self test (TRAINER_SELFTEST=1 or nys_vi_selftest.flag in the game folder) -> nys_vi_selftest_report.json.
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using BepInEx;
using HarmonyLib;
using TMPro;
using UnityEngine;
using UnityEngine.TextCore;
using _9YoS.Scripts.Dialogue;
using _9YoS.Scripts.Managers;
using _9YoS.Scripts.UI.Selections;

namespace NysVietnamese
{
    [BepInPlugin(PluginGuid, "9 Years of Shadows Vietnamese Language Pack", "1.0.0")]
    public class VietnamesePlugin : BaseUnityPlugin
    {
        public const string PluginGuid = "com.research.nysvietnamese";
        internal const int ViLang = 9;                         // value of the new entry in ConstantsManager.Localization.Language
        internal const string LangTag = "Settings_Vietnamese_Tag";
        internal const string NativeName = "Tiếng Việt";

        internal static VietnamesePlugin Instance;
        internal static Harmony Harm;
        internal static string PluginDir;
        internal static readonly Dictionary<string, string> Ui = new Dictionary<string, string>();
        internal static readonly Dictionary<ulong, string> Dlg = new Dictionary<ulong, string>();
        internal static readonly Dictionary<string, string> PatchStatus = new Dictionary<string, string>();
        internal static int DialogueMissing;
        internal static int DialogueTranslated;
        bool selfTest, selfTestRan, forced, dlgDone;
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
            selfTest = Environment.GetEnvironmentVariable("TRAINER_SELFTEST") == "1"
                || File.Exists(Path.Combine(Paths.GameRootPath, "nys_vi_selftest.flag"));
            Logger.LogInfo("Vietnamese pack loaded: " + Ui.Count + " UI texts, " + Dlg.Count + " dialogue lines");
        }

        float nextFonts, nextAdvance;
        void Update()
        {
            if (Time.realtimeSinceStartup > nextFonts) { nextFonts = Time.realtimeSinceStartup + 1f; ViFonts.Tick(); }
            string force = Environment.GetEnvironmentVariable("NYS_VI_FORCE");
            if (!forced && (force == "1" || force == "vi" || force == "en") && Time.realtimeSinceStartup - startedAt > 12f)
            {
                // test aid only: select Vietnamese without the menu
                try
                {
                    var mm = MainManager.Instance;
                    if (mm != null && mm.SettingsManager != null && mm.SettingsManager.SettingsObject != null)
                    {
                        forced = true;
                        mm.SettingsManager.SettingsObject.CurrentLanguage = force == "en" ? 1 : ViLang;
                        Log("NYS_VI_FORCE: language set to " + (force == "en" ? "English" : "Vietnamese"));
                    }
                }
                catch (Exception e) { Warn("force: " + e.Message); }
            }
            string dlg = Environment.GetEnvironmentVariable("NYS_VI_DIALOG");   // test aid: "SceneTag|Node" starts that conversation once gameplay is loaded
            if (!string.IsNullOrEmpty(dlg) && !dlgDone && Time.realtimeSinceStartup - startedAt > 30f)
            {
                try
                {
                    if (GameplayManager.Instance != null && GameplayManager.Instance.UI != null && GameplayManager.Instance.UI.DialogueRunner != null)
                    {
                        dlgDone = true;
                        string[] parts = dlg.Split('|');
                        var runner = GameplayManager.Instance.UI.DialogueRunner;
                        _9YoS.Scripts.Europa.Neutral.Central.PlayerController.Instance.EnablePlayerInput(false);
                        runner.Clear();
                        runner.Add(MainManager.Instance.LocalizationManager.GetLocalizedDialogueFile(parts[0]));
                        runner.StartDialogue(parts[1]);
                        Log("NYS_VI_DIALOG started " + dlg);
                    }
                }
                catch (Exception e) { dlgDone = true; Warn("dialog test: " + e); }
            }
            if (dlgDone && !string.IsNullOrEmpty(dlg) && Time.realtimeSinceStartup > nextAdvance)   // test aid: advance a line every 6 s
            {
                nextAdvance = Time.realtimeSinceStartup + 6f;
                try { GameplayManager.Instance.UI.Dialogue.MarkLineComplete(); } catch (Exception) { }
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
            foreach (var n in asm.GetManifestResourceNames())
            {
                bool isUi = n.EndsWith("ui.tsv");
                bool isDlg = n.EndsWith("dlg.tsv");
                if (!isUi && !isDlg) continue;
                using (var rd = new StreamReader(asm.GetManifestResourceStream(n), new UTF8Encoding(false)))
                {
                    string line;
                    while ((line = rd.ReadLine()) != null)
                    {
                        int tab = line.IndexOf('\t');
                        if (tab <= 0) continue;
                        string val = Unescape(line.Substring(tab + 1));
                        if (isUi) Ui[line.Substring(0, tab)] = val;
                        else if (tab == 16) Dlg[Convert.ToUInt64(line.Substring(0, 16), 16)] = val;
                    }
                }
            }
            if (Ui.Count == 0 || Dlg.Count == 0) throw new FileNotFoundException("embedded ui.tsv / dlg.tsv not found");
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
    }

    // ------------------------------------------------------------------ dialogue (Yarn) support
    static class Dialogues
    {
        static readonly Dictionary<string, YarnProgram> cache = new Dictionary<string, YarnProgram>();

        internal static YarnProgram Get(DialogueFileLibrary lib, string tag)
        {
            if (string.IsNullOrEmpty(tag)) return null;
            YarnProgram p;
            if (cache.TryGetValue(tag, out p) && p != null) return p;
            YarnProgram en = lib.GetLocalizedDialogueFileFromTag(tag, ConstantsManager.Localization.Language.English);
            if (en == null || en.baseLocalisationStringTable == null) return null;
            p = Build(en);
            cache[tag] = p;
            return p;
        }

        internal static YarnProgram Build(YarnProgram en)
        {
            string csv = Translate(en.baseLocalisationStringTable.text);
            YarnProgram vi = UnityEngine.Object.Instantiate(en);
            vi.name = en.name + "-vi";
            var ta = new TextAsset(csv);
            ta.name = en.name + "-vi";
            ta.hideFlags = HideFlags.HideAndDontSave;
            vi.baseLocalisationStringTable = ta;
            vi.localizations = new YarnTranslation[0];
            vi.hideFlags = HideFlags.HideAndDontSave;
            return vi;
        }

        /// <summary>Replaces the "text" column of a Yarn string table (id,text,file,node,lineNumber) with the Vietnamese lines.</summary>
        internal static string Translate(string csv)
        {
            List<List<string>> rows = ParseCsv(csv);
            int textCol = 1;
            if (rows.Count > 0) { int i = rows[0].IndexOf("text"); if (i >= 0) textCol = i; }
            for (int r = 1; r < rows.Count; r++)
            {
                List<string> row = rows[r];
                if (row.Count <= textCol) continue;
                string en = row[textCol];
                string vi;
                if (VietnamesePlugin.Dlg.TryGetValue(VietnamesePlugin.Fnv(en), out vi)) { row[textCol] = vi; VietnamesePlugin.DialogueTranslated++; }
                else if (!string.IsNullOrEmpty(en)) VietnamesePlugin.DialogueMissing++;
            }
            return WriteCsv(rows);
        }

        internal static List<List<string>> ParseCsv(string s)
        {
            var rows = new List<List<string>>();
            var row = new List<string>();
            var f = new StringBuilder();
            bool q = false;
            int i = 0;
            while (i < s.Length)
            {
                char c = s[i];
                if (q)
                {
                    if (c == '"')
                    {
                        if (i + 1 < s.Length && s[i + 1] == '"') { f.Append('"'); i += 2; continue; }
                        q = false; i++; continue;
                    }
                    f.Append(c); i++; continue;
                }
                if (c == '"') { q = true; i++; }
                else if (c == ',') { row.Add(f.ToString()); f.Length = 0; i++; }
                else if (c == '\r' || c == '\n')
                {
                    if (c == '\r' && i + 1 < s.Length && s[i + 1] == '\n') i++;
                    i++;
                    row.Add(f.ToString()); f.Length = 0;
                    rows.Add(row); row = new List<string>();
                }
                else { f.Append(c); i++; }
            }
            if (f.Length > 0 || row.Count > 0) { row.Add(f.ToString()); rows.Add(row); }
            return rows;
        }

        internal static string WriteCsv(List<List<string>> rows)
        {
            var sb = new StringBuilder();
            foreach (var row in rows)
            {
                for (int i = 0; i < row.Count; i++)
                {
                    if (i > 0) sb.Append(',');
                    sb.Append('"').Append(row[i].Replace("\"", "\"\"")).Append('"');
                }
                sb.Append('\n');
            }
            return sb.ToString();
        }
    }

    // ------------------------------------------------------------------ fonts
    // The game draws its text with the TextMeshPro font family "Jost" (dynamic atlases, source = Jost *.ttf). Jost has no Vietnamese
    // letters (ơ ư and U+1EA0..U+1EF9 are missing), the game's fallbacks (Noto Sans SC/JP *Black*) would make them look wrong.
    // While Vietnamese is the selected language every Jost font asset is switched to Noto Sans (same size, same material = same outline
    // and colours) and switched back when another language is chosen. Reversible, nothing is written to the game's files.
    static class ViFonts
    {
        internal sealed class Original
        {
            internal Font Source;                       // dynamic assets
            internal List<Glyph> Glyphs;                // static assets
            internal List<TMP_Character> Chars;
            internal TMP_FontAsset Fallback;
        }

        internal static readonly Dictionary<TMP_FontAsset, Original> Swapped = new Dictionary<TMP_FontAsset, Original>();
        internal static readonly List<TMP_FontAsset> Created = new List<TMP_FontAsset>();
        internal static bool VietMode;
        internal static string LastError = "";
        internal const string Sample = "ăâđêôơưĂÂĐÊÔƠƯàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵÀÁẢÃẠẰẮẲẴẶẦẤẨẪẬÈÉẺẼẸỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌỒỐỔỖỘỜỚỞỠỢÙÚỦŨỤỪỨỬỮỰỲÝỶỸỴ";
        static readonly FieldInfo SourceField = AccessTools.Field(typeof(TMP_FontAsset), "m_SourceFontFile");
        static readonly FieldInfo MissingField = AccessTools.Field(typeof(TMP_FontAsset), "m_MissingUnicodesFromFontFile");
        static Font regular, bold;

        static Font Load(bool wantBold)
        {
            if (wantBold ? bold != null : regular != null) return wantBold ? bold : regular;
            string file = Path.Combine(VietnamesePlugin.PluginDir, wantBold ? "NotoSans-Bold.ttf" : "NotoSans-Regular.ttf");
            if (!File.Exists(file)) throw new FileNotFoundException(file);
            Font f = new Font(file);
            f.hideFlags = HideFlags.HideAndDontSave;
            if (wantBold) bold = f; else regular = f;
            return f;
        }

        static bool IsBold(string fontName)
        {
            return fontName.Contains("Bold") || fontName.Contains("Black") || fontName.Contains("SemiBold");
        }

        internal static void SetMode(bool viet)
        {
            if (VietMode == viet) return;
            VietMode = viet;
            VietnamesePlugin.Log("fonts: " + (viet ? "Vietnamese mode (Noto Sans)" : "original mode (Jost)"));
            Tick();
        }

        /// <summary>Applies the current mode to every loaded Jost font asset (new assets that were loaded later are picked up by the timer).</summary>
        internal static void Tick()
        {
            try
            {
                TMP_FontAsset[] all = Resources.FindObjectsOfTypeAll<TMP_FontAsset>();
                foreach (TMP_FontAsset fa in all)
                {
                    if (fa == null || !fa.name.StartsWith("Jost") || fa.name.EndsWith(" ViFallback")) continue;
                    bool done = Swapped.ContainsKey(fa);
                    if (VietMode && !done) ToVietnamese(fa);
                    else if (!VietMode && done) ToOriginal(fa);
                }
                foreach (var f in Created) Protect(f);
            }
            catch (Exception e) { LastError = e.ToString(); VietnamesePlugin.Warn("fonts: " + e); }
        }

        static void Notify(TMP_FontAsset fa)
        {
            try { TMPro_EventManager.ON_FONT_PROPERTY_CHANGED(true, fa); } catch (Exception e) { VietnamesePlugin.Warn("font notify: " + e.Message); }
        }

        static void ForgetMissing(TMP_FontAsset fa)
        {
            var set = MissingField != null ? MissingField.GetValue(fa) as HashSet<uint> : null;
            if (set != null) set.Clear();
        }

        static void ToVietnamese(TMP_FontAsset fa)
        {
            var o = new Original();
            if (fa.atlasPopulationMode == AtlasPopulationMode.Dynamic)
            {
                o.Source = fa.sourceFontFile;
                SourceField.SetValue(fa, Load(IsBold(fa.name)));
                ForgetMissing(fa);
                fa.isMultiAtlasTexturesEnabled = true;   // 134 extra letters may not fit one atlas page
                fa.ClearFontAssetData(false);
                string missing; fa.TryAddCharacters(Sample, out missing);
                if (!string.IsNullOrEmpty(missing)) VietnamesePlugin.Warn(fa.name + ": glyphs missing: " + missing);
            }
            else
            {
                // static atlas: hide the baked glyphs and let a Noto fallback with the same material draw everything
                o.Glyphs = new List<Glyph>(fa.glyphTable);
                o.Chars = new List<TMP_Character>(fa.characterTable);
                o.Fallback = MakeFallback(Load(IsBold(fa.name)), fa);
                if (fa.fallbackFontAssetTable == null) fa.fallbackFontAssetTable = new List<TMP_FontAsset>();
                if (o.Fallback != null) fa.fallbackFontAssetTable.Insert(0, o.Fallback);
                fa.characterTable.Clear();
                fa.glyphTable.Clear();
                fa.ReadFontAssetDefinition();
            }
            Swapped[fa] = o;
            Notify(fa);
            VietnamesePlugin.Log("font '" + fa.name + "' -> Noto Sans");
        }

        static void ToOriginal(TMP_FontAsset fa)
        {
            Original o = Swapped[fa];
            if (fa.atlasPopulationMode == AtlasPopulationMode.Dynamic)
            {
                SourceField.SetValue(fa, o.Source);
                ForgetMissing(fa);
                fa.ClearFontAssetData(false);
            }
            else
            {
                if (o.Fallback != null && fa.fallbackFontAssetTable != null) fa.fallbackFontAssetTable.Remove(o.Fallback);
                fa.glyphTable.Clear(); fa.characterTable.Clear();
                fa.glyphTable.AddRange(o.Glyphs);
                fa.characterTable.AddRange(o.Chars);
                fa.ReadFontAssetDefinition();
            }
            Swapped.Remove(fa);
            Notify(fa);
            VietnamesePlugin.Log("font '" + fa.name + "' restored");
        }

        static TMP_FontAsset MakeFallback(Font src, TMP_FontAsset baseFa)
        {
            int pt = Mathf.Max(24, baseFa.faceInfo.pointSize);
            int pad = Mathf.Max(4, baseFa.atlasPadding);
            int aw = Mathf.Max(512, baseFa.atlasWidth);
            int ah = Mathf.Max(512, baseFa.atlasHeight);
            TMP_FontAsset fa = TMP_FontAsset.CreateFontAsset(src, pt, pad, UnityEngine.TextCore.LowLevel.GlyphRenderMode.SDFAA, aw, ah, AtlasPopulationMode.Dynamic, true);
            if (fa == null) { VietnamesePlugin.Warn("CreateFontAsset returned null"); return null; }
            fa.name = baseFa.name + " ViFallback";
            if (baseFa.material != null)
            {
                Material m = new Material(baseFa.material);
                m.name = fa.name + " Material";
                Texture atlas = fa.atlasTexture;
                m.SetTexture(ShaderUtilities.ID_MainTex, atlas);
                m.SetFloat(ShaderUtilities.ID_TextureWidth, atlas.width);
                m.SetFloat(ShaderUtilities.ID_TextureHeight, atlas.height);
                m.SetFloat(ShaderUtilities.ID_GradientScale, pad + 1);
                fa.material = m;
            }
            // ASCII too: the static font's own glyphs are hidden while Vietnamese is active
            var sb = new StringBuilder(Sample);
            for (char c = ' '; c <= '~'; c++) sb.Append(c);
            sb.Append("…’‘“”–—·•«»°©®™€");
            string missing;
            fa.TryAddCharacters(sb.ToString(), out missing);
            if (!string.IsNullOrEmpty(missing)) VietnamesePlugin.Warn(fa.name + ": glyphs missing: " + missing);
            if (fa.material != null && fa.atlasTexture != null)
            {
                Texture atlas2 = fa.atlasTexture;   // the atlas page is only sized by the first TryAddCharacters call
                fa.material.SetTexture(ShaderUtilities.ID_MainTex, atlas2);
                fa.material.SetFloat(ShaderUtilities.ID_TextureWidth, atlas2.width);
                fa.material.SetFloat(ShaderUtilities.ID_TextureHeight, atlas2.height);
            }
            Protect(fa);
            Created.Add(fa);
            return fa;
        }

        static void Protect(TMP_FontAsset fa)
        {
            if (fa == null) return;
            fa.hideFlags = HideFlags.HideAndDontSave;
            if (fa.material != null) fa.material.hideFlags = HideFlags.HideAndDontSave;
            Texture2D[] tex = fa.atlasTextures;
            if (tex != null) foreach (var t in tex) if (t != null) t.hideFlags = HideFlags.HideAndDontSave;
        }
    }

    // ------------------------------------------------------------------ Harmony patches
    static class Patches
    {
        static readonly FieldInfo RecordsField = AccessTools.Field(typeof(SpinnerBase), "mySpinnerRecords");
        static readonly FieldInfo SettingField = AccessTools.Field(typeof(SpinnerBase), "mySetting");

        static void Try(string id, Func<bool> f)
        {
            try { bool ok = f(); VietnamesePlugin.PatchStatus[id] = ok ? "ok" : "target not found"; }
            catch (Exception e) { VietnamesePlugin.PatchStatus[id] = "error: " + e.Message; VietnamesePlugin.Warn("patch " + id + ": " + e); }
        }

        static MethodInfo Own(string name) { return typeof(Patches).GetMethod(name, BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public); }

        internal static void Apply(Harmony h)
        {
            Try("Strings.GetLocalizedStringFromTag", delegate
            {
                var m = AccessTools.Method(typeof(LocalizedStringLibrary), "GetLocalizedStringFromTag", new[] { typeof(string), typeof(ConstantsManager.Localization.Language) });
                if (m == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("Lib_Post"))); return true;
            });
            Try("Dialogue.GetLocalizedDialogueFileFromTag", delegate
            {
                var m = AccessTools.Method(typeof(DialogueFileLibrary), "GetLocalizedDialogueFileFromTag", new[] { typeof(string), typeof(ConstantsManager.Localization.Language) });
                if (m == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("Dlg_Post"))); return true;
            });
            Try("Settings.CurrentLanguage", delegate
            {
                var m = AccessTools.PropertySetter(typeof(SettingsObject), "CurrentLanguage");
                if (m == null) return false;
                h.Patch(m, prefix: new HarmonyMethod(Own("Language_Pre"))); return true;
            });
            Try("Spinner.Awake", delegate
            {
                var m = AccessTools.Method(typeof(SpinnerBase), "Awake");
                if (m == null || RecordsField == null || SettingField == null) return false;
                h.Patch(m, postfix: new HarmonyMethod(Own("Spinner_Post"))); return true;
            });
            Try("Spinner.UpdateSetting", delegate
            {
                var m = AccessTools.Method(typeof(SpinnerBase), "UpdateSetting");
                if (m == null) return false;
                h.Patch(m, prefix: new HarmonyMethod(Own("Spinner_Pre"))); return true;
            });
            Try("Spinner.Move", delegate
            {
                var m = AccessTools.Method(typeof(SpinnerBase), "Move");
                if (m == null) return false;
                h.Patch(m, prefix: new HarmonyMethod(Own("Spinner_Pre"))); return true;
            });
            foreach (var kv in VietnamesePlugin.PatchStatus) VietnamesePlugin.Log("patch " + kv.Key + ": " + kv.Value);
        }

        // --- UI strings -----------------------------------------------------------------------
        static void Lib_Post(string tag, ConstantsManager.Localization.Language language, ref string __result)
        {
            if (string.IsNullOrEmpty(tag)) return;
            if (tag == VietnamesePlugin.LangTag) { __result = VietnamesePlugin.NativeName; return; }
            if ((int)language != VietnamesePlugin.ViLang) return;
            string v;
            if (VietnamesePlugin.Ui.TryGetValue(tag, out v)) __result = v;
        }

        // --- language switch (runs before the game refreshes its texts) ------------------------
        static void Language_Pre(int value)
        {
            try { ViFonts.SetMode(value == VietnamesePlugin.ViLang); }
            catch (Exception e) { VietnamesePlugin.Warn("language switch: " + e.Message); }
        }

        // --- dialogue -------------------------------------------------------------------------
        static void Dlg_Post(DialogueFileLibrary __instance, string tag, ConstantsManager.Localization.Language language, ref YarnProgram __result)
        {
            if ((int)language != VietnamesePlugin.ViLang) return;
            try
            {
                YarnProgram p = Dialogues.Get(__instance, tag);
                if (p != null) __result = p;
            }
            catch (Exception e) { VietnamesePlugin.Warn("dialogue " + tag + ": " + e); }
        }

        // --- language selector ----------------------------------------------------------------
        static void Spinner_Post(SpinnerBase __instance) { EnsureLanguageRecord(__instance); }
        static void Spinner_Pre(SpinnerBase __instance) { EnsureLanguageRecord(__instance); }

        internal static bool EnsureLanguageRecord(SpinnerBase sb)
        {
            try
            {
                if (sb == null) return false;
                if ((ConstantsManager.Settings.GameSettings.Setting)SettingField.GetValue(sb) != ConstantsManager.Settings.GameSettings.Setting.Language) return false;
                var recs = (SpinnerRecord[])RecordsField.GetValue(sb);
                if (recs == null) return false;
                foreach (var r in recs) if (r.mySavingValue == VietnamesePlugin.ViLang) return true;
                var n = new SpinnerRecord[recs.Length + 1];
                Array.Copy(recs, n, recs.Length);
                n[recs.Length] = new SpinnerRecord { mySavingValue = VietnamesePlugin.ViLang, localizedStringTag = VietnamesePlugin.LangTag };
                RecordsField.SetValue(sb, n);
                VietnamesePlugin.Log("language selector: added 'Tiếng Việt' (" + n.Length + " entries)");
                return true;
            }
            catch (Exception e) { VietnamesePlugin.Warn("spinner: " + e.Message); return false; }
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
            foreach (var kv in VietnamesePlugin.PatchStatus) Feature("patch:" + kv.Key, kv.Value == "ok", kv.Value);
            var vi = (ConstantsManager.Localization.Language)VietnamesePlugin.ViLang;

            // ---- UI strings: every English tag of the library must be served in Vietnamese
            var libs = Resources.FindObjectsOfTypeAll<LocalizedStringLibrary>();
            Feature("string_library_found", libs.Length > 0, libs.Length + " library object(s)");
            if (libs.Length > 0)
            {
                int total = 0, ok = 0, same = 0; string firstBad = "";
                foreach (var g in libs[0].LocalizedStringGroups)
                    foreach (var r in g.LocalizedStrings)
                    {
                        string tag = r.StringTag;
                        if (string.IsNullOrEmpty(tag)) continue;
                        string en = r.GetLocalizedString(ConstantsManager.Localization.Language.English);
                        if (string.IsNullOrEmpty(en)) continue;
                        total++;
                        string v = libs[0].GetLocalizedStringFromTag(tag, vi);
                        string expect;
                        if (VietnamesePlugin.Ui.TryGetValue(tag, out expect) && v == expect) { ok++; if (v == en) same++; }
                        else if (firstBad == "") firstBad = tag;
                    }
                Feature("ui_strings_vietnamese", total > 700 && ok == total, ok + "/" + total + " tags served in Vietnamese (" + same + " identical to English, e.g. numbers/names); first bad: " + firstBad);
                string lang = libs[0].GetLocalizedStringFromTag(VietnamesePlugin.LangTag, ConstantsManager.Localization.Language.English);
                Feature("language_name_tag", lang == VietnamesePlugin.NativeName, lang);
                string play = libs[0].GetLocalizedStringFromTag("MenuMain_START", vi);
                Feature("sample_translation", play == "BẮT ĐẦU", "MenuMain_START=" + play);
                string args = "";
                try
                {
                    string t = libs[0].GetLocalizedStringFromTag("BuyScreen_Message", vi);
                    args = t;
                    Feature("placeholder_preserved", t.Contains("{{0}}"), t);
                }
                catch (Exception e) { Feature("placeholder_preserved", false, e.Message); }
            }

            // ---- Dialogue: every Yarn program of the library available in Vietnamese
            var dlibs = Resources.FindObjectsOfTypeAll<DialogueFileLibrary>();
            Feature("dialogue_library_found", dlibs.Length > 0, dlibs.Length + " library object(s)");
            if (dlibs.Length > 0)
            {
                var field = AccessTools.Field(typeof(DialogueFileLibrary), "localizedDialogueFiles");
                var arr = (IEnumerable)field.GetValue(dlibs[0]);
                int progs = 0, progsOk = 0, lines = 0, same = 0, colonBad = 0; string firstBad = "", sample = "";
                VietnamesePlugin.DialogueMissing = 0;
                foreach (object f in arr)
                {
                    string tag = (string)AccessTools.Field(f.GetType(), "dialogueSceneTag").GetValue(f);
                    YarnProgram en = dlibs[0].GetLocalizedDialogueFileFromTag(tag, ConstantsManager.Localization.Language.English);
                    YarnProgram v = dlibs[0].GetLocalizedDialogueFileFromTag(tag, vi);
                    progs++;
                    if (en == null || v == null || v == en || v.baseLocalisationStringTable == null) { if (firstBad == "") firstBad = tag; continue; }
                    var enRows = Dialogues.ParseCsv(en.baseLocalisationStringTable.text);
                    var viRows = Dialogues.ParseCsv(v.baseLocalisationStringTable.text);
                    bool good = enRows.Count == viRows.Count && enRows.Count > 1;
                    for (int r = 1; good && r < enRows.Count; r++)
                    {
                        lines++;
                        string a = enRows[r][1], b = viRows[r][1];
                        if (enRows[r][0] != viRows[r][0]) good = false;
                        if (a == b && a.Length > 3 && a.IndexOf('?') != 0) same++;
                        int c = b.IndexOf(':');
                        if (c > 0 && b.IndexOf(':', c + 1) >= 0) colonBad++;
                        if (sample == "" && b != a) sample = b;
                    }
                    if (good) progsOk++; else if (firstBad == "") firstBad = tag;
                }
                Feature("dialogue_programs", progs > 20 && progsOk == progs, progsOk + "/" + progs + " programs, " + lines + " lines; first bad: " + firstBad);
                Feature("dialogue_all_lines_translated", VietnamesePlugin.DialogueMissing == 0 && lines > 1000, "untranslated lines: " + VietnamesePlugin.DialogueMissing + ", identical-to-English: " + same + ", e.g. " + sample);
                Feature("dialogue_no_extra_colon", colonBad == 0, "lines with a second ':' (the game would cut them): " + colonBad);
            }

            // ---- Fonts: in Vietnamese mode every Jost font asset must be able to draw every Vietnamese letter; switching back must restore Jost
            bool startMode = ViFonts.VietMode;
            ViFonts.SetMode(true);
            int fOk = 0, fTotal = 0; var miss = new StringBuilder();
            foreach (TMP_FontAsset fa in Resources.FindObjectsOfTypeAll<TMP_FontAsset>())
            {
                if (fa == null || !fa.name.StartsWith("Jost") || fa.name.EndsWith(" ViFallback")) continue;
                fTotal++;
                bool ok = ViFonts.Swapped.ContainsKey(fa);
                if (ok)
                {
                    TMP_FontAsset drawer = fa;
                    if (fa.atlasPopulationMode == AtlasPopulationMode.Static) drawer = ViFonts.Swapped[fa].Fallback;
                    string m = "";
                    if (drawer == null) m = "no drawer";
                    else foreach (char ch in ViFonts.Sample) if (!drawer.HasCharacter(ch, false, false)) m += ch;
                    ok = string.IsNullOrEmpty(m);
                    if (!ok) miss.Append(drawer != null ? drawer.name : fa.name).Append(':').Append(m).Append(' ');
                    if (ok && drawer.sourceFontFile != null && !drawer.sourceFontFile.name.Contains("NotoSans")) { ok = false; miss.Append(fa.name + ": source=" + drawer.sourceFontFile.name + " "); }
                }
                else miss.Append(fa.name + ":not switched ");
                if (ok) fOk++;
            }
            Feature("fonts_vietnamese_glyphs", fTotal > 0 && fOk == fTotal, fOk + "/" + fTotal + " Jost font assets draw all Vietnamese letters with Noto Sans " + miss);
            ViFonts.SetMode(false);
            int restored = 0, rTotal = 0;
            foreach (TMP_FontAsset fa in Resources.FindObjectsOfTypeAll<TMP_FontAsset>())
            {
                if (fa == null || !fa.name.StartsWith("Jost") || fa.name.EndsWith(" ViFallback")) continue;
                rTotal++;
                bool back = !ViFonts.Swapped.ContainsKey(fa);
                if (back && fa.atlasPopulationMode == AtlasPopulationMode.Dynamic) back = fa.sourceFontFile != null && fa.sourceFontFile.name.Contains("Jost");
                if (back && fa.atlasPopulationMode == AtlasPopulationMode.Static) back = fa.characterTable.Count > 50;
                if (back) restored++;
            }
            Feature("fonts_restored_for_other_languages", rTotal > 0 && restored == rTotal, restored + "/" + rTotal + " Jost font assets back to the original typeface");
            ViFonts.SetMode(startMode);

            string path = Path.Combine(Paths.GameRootPath, "nys_vi_selftest_report.json");
            File.WriteAllText(path, "{\"overall_status\":" + J(allOk ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL") + ",\"feature_results\":[\n" + string.Join(",\n", Results.ToArray()) + "\n]}", new UTF8Encoding(false));
            VietnamesePlugin.Log("selftest report written: " + path);
        }
    }
}
