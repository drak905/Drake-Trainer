# River City Girls — plug-and-play Cheat Engine trainer

This table is for the 64-bit Unity/Mono build of `RiverCityGirls.exe`. It
resolves managed classes, singleton roots, and compiled methods each time it is
activated, so it does not retain heap or JIT addresses from an earlier process.

## Quick start

1. Start **River City Girls** and enter the game world.
2. Open Cheat Engine and attach it to `RiverCityGirls.exe`.
3. Load `RiverCityGirls.CT`.
4. Check **River City Girls Trainer - Activate**.

No MCP bridge or AI connection is required after the table has been created.

## Editable controls

Activating the main record creates these child entries:

| Entry | Default | Notes |
|---|---:|---|
| No Damage | Enabled | Uses both the global debug-invincibility field and each active player's `Invincible` field. |
| One-Hit Kill | Enabled | Raises player and player-owned weapon damage multipliers only. |
| Attack Damage Multiplier | 100000 | Editable value used by One-Hit Kill. |
| Money + XP Gain Multiplier | 10 | Multiplies positive money receipts and XP additions. Spending is unchanged. |
| Character Speed Multiplier | 2.0 | Multiplies normal walk/run speed after the game's own agility modifier. |
| Max All Character Stats | Enabled | Raises Stamina, Special, Agility, Weapons, Attack, and Luck for all four character profiles to the game's own reported caps. |

Ordinary inventory objects are deliberately not duplicated. River City Girls
stores useable items in a small slot list (two slots at the beginning), rather
than as stack quantities; inserting ten copies would fill or overflow that
inventory and could prevent later pickups.

## Scene transitions and cleanup

The table follows these persistent Mono roots:

```text
PlayerManager.s_instance -> m_players[]
PlayerAttributes.Instance -> Players[]
PlayerGlobalInventory._instance -> PlayerInventories[]
```

A lightweight keeper reapplies per-player fields every **3000 ms**. It only
follows the singleton pointers and never performs a Mono heap scan on its timer.
Money and XP use method-local hooks that remain valid through scene changes.

Unchecking the main activation record stops the timer, restores the original
method bytes, resets the active-player runtime modifiers, and restores the
pre-activation character-stat bonuses captured by profile index.

## Restart behavior

Each new process has different managed-object and JIT addresses. Activation
therefore launches the Mono collector if needed, resolves every class and
method again, validates both method prologues, and only then installs the hooks.
The same `.CT` can be reused after restarting the game and Cheat Engine.
