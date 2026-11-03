# Ghost Song — English → Vietnamese translation guide

Game: **Ghost Song** (Old Moon). A dark, melancholic sci-fi Metroidvania on the dying moon **Lorian**. You play the **Deadsuit**,
a robotic exosuit that wakes up in the ruins of the moon, meets survivors (hunters, scientists, androids, devils/monsters) and
gradually learns what happened. Tone: lonely, wry, sometimes darkly funny; characters talk like real people (short, casual lines);
bosses are theatrical; the UI is terse and technical.

## Input / output format (STRICT)

Each input line (`*.src.tsv`) is TAB separated:

* dialogue chunk (`dlg_NN.src.tsv`):  `id <TAB> code <TAB> speaker <TAB> english`
* UI chunk (`ui_NN.src.tsv`):         `id <TAB> field <TAB> english`

Your output file (`*.vi.tsv`) has **exactly one line per input line, same order**, format:

```
id <TAB> vietnamese
```

Rules for the text column:

1. UTF-8, **one line per record**. Never put a real TAB or real line break in the text. The text uses escape sequences:
   `\n` = line break, `\t` = tab, `\\` = backslash. **Copy every `\n`, `\t`, `\\` exactly as in the English.**
2. Keep placeholders and markup **byte-for-byte**: `{0}`, `{1}`, `<i>...</i>`, `<b>`, `<color=#61AFF0>`, `</color>`, `%s`, `%d`, `[ ]` button names,
   URLs, e-mail addresses. Do not translate or reorder tags; translate only the words between them.
3. Keep leading/trailing spaces exactly like the English (some lines end with a space on purpose).
4. Do **not** use the character `:` as a new speaker separator, do not add quotation marks that the English does not have, do not add notes.
5. `...` / `…` / `?!` / `-` style lines (pure punctuation, onomatopoeia like `Hrrngh!`, `Ahh!`) stay as is or get a natural Vietnamese equivalent.
6. Empty English → empty Vietnamese (but still output the id and a TAB).
7. Every record must be translated into **natural Vietnamese with full diacritics** (Unicode precomposed NFC: `ế ợ ữ đ ă â ê ô ơ ư`). No English left over except
   proper names / glossary terms marked "keep".
8. Length: Vietnamese is naturally ~15-25 % longer than English, but text boxes are small. Be concise: prefer short natural phrasing; for **UI labels**
   (menus, buttons, stat names, settings) keep them **no longer than ~130 % of the English** (use abbreviations/short words if needed).

## Voice & pronouns (keep consistent across all chunks!)

* Default: first person **tôi**, second person **bạn** (also for the player/Deadsuit when system text or tutorials talk to the player).
* Peers/friends in casual talk may use **mình – cậu** (young/friendly characters such as PASHA, MOLLY, DOLLY, LEAF, GILI). Older, gruff or senior characters
  (ROPER, SAYMUND, PAUL, MATILDA) may use **tôi – cậu/cô/anh/chị** but stay natural and non-regional (neutral/Northern standard Vietnamese).
* Arrogant / ancient / boss / supernatural speakers (LORD PENNICK, RELIC, DEVIL-WINK, SLOVENMUCK, OUTLIER, bosses, the "Devil" monsters, voices) may use **ta – ngươi**
  (or **ta – ngài** for the respectful).  Hostile thugs may use **tao – mày** sparingly, only if clearly insulting.
* DEADSUIT speaks politely and tersely: **tôi**; calls others by name, otherwise **bạn/anh/cô** by apparent gender (a "WOMAN" → cô/chị, a "MAN" → anh/ông).
* Do not over-use "à/ạ/nhé/nhỉ"; keep the dry tone. Swearing: mild.
* Computers / the Deadsuit's system messages: neutral, imperative, technical ("Nhấn ... để ...").

## Glossary (use these renderings consistently)

Keep in English (proper names): Deadsuit (also "The Deadsuit"), Ghost Song, Old Moon, Lorian, Pasha, Roper, Saymund, Raven, Gili, Molly, Matilda, Mutt, Lua, Paul,
Dolly, Mabec, Bill, Hector, Rime, Leaf, Adam, Steven, Filimonov, Henriette Scuttle, Lord Pennick, Slovenmuck, Devil-Wink, Nanogel, Nanites, Crashsite (as "Crashsite"),
boss/area/item proper names that are invented words. When a proper name has a meaningful descriptive title (e.g. "The Lost Soldier", "The Excommunicated",
"The Devil Stalker") translate the title and keep the name: "Filimonov, Người Lính Lạc Lối".

| English | Vietnamese |
|---|---|
| Spirit (currency/stat) | Linh khí |
| Nanogel | Nanogel |
| Bugblood | Máu Bọ |
| Health / HP | Máu / HP |
| Stamina | Thể lực |
| Gun Power / GunPower | Hỏa lực |
| Vigor | Sinh lực |
| Resolve | Ý chí |
| Volatility | Độ bất ổn |
| Luck | May mắn |
| Heat / Overheat | Nhiệt / Quá nhiệt |
| Blaster | Blaster |
| Module(s) | Mô-đun |
| Socket(s) | Khe cắm |
| Suit | Bộ giáp (the Deadsuit's body) |
| Hunter(s) | Thợ Săn |
| Devil(s) | Quỷ |
| Map / Inventory / Status | Bản đồ / Kho đồ / Trạng thái |
| Save / Load | Lưu / Tải |
| Shut down | Tắt máy |
| Fast travel | Dịch chuyển nhanh |
| Dash / Sprint / Melee / Jump | Lướt / Chạy nước rút / Cận chiến / Nhảy |
| Difficulty: Easy / Normal / Hard | Dễ / Thường / Khó |
| New Game+ | New Game+ (keep) |
| Boss | Trùm |
| Bestiary / Records | Sổ Quái Vật / Hồ sơ |
| Yes / No / Back / Quit / Resume / Settings | Có / Không / Quay lại / Thoát / Tiếp tục / Cài đặt |
| Items (equipment/relic) | Vật phẩm |
| Language | Ngôn ngữ |

If the English contains a term that is clearly a *coined fantasy/sci-fi word*, keep it (optionally add a short Vietnamese descriptor only if needed for clarity).

## Quality bar

* Translate meaning and **attitude**, not word-for-word. Jokes → equivalent Vietnamese humor when possible.
* Keep each line's *length class*: a one-word shout stays one or two words.
* No machine-style stiffness ("Bạn đã nhận được cái..."): prefer "Nhận được ...".
* Spelling: modern standard Vietnamese, correct tone-mark placement (hoà/hòa — use the common "hòa", "thuỷ" → "thủy"), correct "d / gi / r", "s / x", "ch / tr".
