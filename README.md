# WeaponSwingTimer-335-ac

> **This is a backport.** It brings **[WeaponSwingTimer-SixxFix](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix)** by WatchYourSixx (TBC Classic) to the unmodded **Wrath of the Lich King 3.3.5a (build 12340)** client.
>
> All credit for the addon, its design and its artwork goes to the original authors:
> - **WatchYourSixx** – [WeaponSwingTimer-SixxFix](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix) (the version this backport is based on, 6.7.4)
> - **LeftHandedGlove** – [WeaponSwingTimerAddon](https://github.com/LeftHandedGlove/WeaponSwingTimerAddon), who started the project
>
> Please report problems with this backport here, not to the original authors.

<p align="center">
<img src="https://github.com/LeftHandedGlove/WeaponSwingTimerAddon/blob/master/Images/wst_logo_shadow.png?raw=true" width="50%" height="50%" title="WST_Logo" class="center">
</p>

## What it does
WeaponSwingTimer tracks your own and your target's swing timers.

If you're a hunter, it also tracks Auto Shot timing and the cast time of castable shots.

If you use a wand, it also tracks when your shot will go off.

### Melee Bars
The melee bars track the player's and target's main-hand and off-hand swings.
They reset on abilities that reset a swing timer (Heroic Strike, Cleave, Maul, Raptor Strike, Rune Strike) and take parry haste into account.
Both frames can be moved with the usual click-and-drag.
Open the options with `/wst`, `/WeaponSwingTimer` or `/weaponswingtimer`.

### Hunter/Wand Bars
The shot bars track the player's Auto Shot and Shoot timing, and the cast time of Multi-Shot and Steady Shot.
The white shot bar shows the time until your next Auto Shot or Shoot; it turns gold during the global cooldown of Steady Shot or Multi-Shot.
In WotLK Auto Shot has no cast time, so there is no red 'casting' section to stand still for.

## Installation
1. Copy the `WeaponSwingTimer-335-ac` folder into `World of Warcraft\Interface\AddOns\`.
2. It should look like `Interface\AddOns\WeaponSwingTimer-335-ac\WeaponSwingTimer-335-ac.toc`.
3. Fully restart the game (a `/reload` does not pick up new image files).
4. Type `/wst` in game to open the options.

## Differences from the original

### Features added in this backport
- **Default profile**: every character uses the shared "Default" profile and your changes are saved to it. Other profiles can still be created, copied and selected under *Profiles*.
- **Show on classes**: on the main options page, choose which classes the bars appear on (all ticked by default).
- **Ranged bars only when useful**: the shot bar shows for Hunters, and for Mages, Priests and Warlocks with a wand; the spell cast bar shows for Hunters. Both are hidden when no ranged weapon is equipped.
- **No fade animation**: the spell cast bar shows its result briefly, then hides in one step.
- **Border on by default**, matching the original addon's screenshots.
- **Options that don't apply to WotLK are removed or greyed out**: the Paladin seal-twist markers (seal twisting no longer exists), the TBC "Bar Explanation" picture (it described the Auto Shot cast), and cast-bar options for shots that are instant on your client (e.g. Aimed Shot).
- **"Spell Bar Unlocked" only appears while the options window is open**, so the spell cast bar can be positioned without it showing all the time.

### Extras page (optional, everything off by default)
Interface Options → AddOns → WeaponSwingTimer (3.3.5a) → **Extras**. These answer open requests on the original issue trackers:
- **Font, bar texture and border** choice for all bars ([SixxFix #14](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix/issues/14), [#5](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix/issues/5)). Built-in game media; LibSharedMedia media also appears if another addon provides it.
- **Vertical bars** for the player and target bars ([SixxFix #18](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix/issues/18)).
- **Colour while a next-swing ability is queued**: Heroic Strike, Cleave, Maul, Raptor Strike, Rune Strike ([SixxFix #11](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix/issues/11)).
- **Colour when attack speed changes mid-swing**, e.g. Flurry ([LeftHandedGlove #18](https://github.com/LeftHandedGlove/WeaponSwingTimerAddon/issues/18)).
- **Slam marker** for Warriors: casting Slam after it delays your next swing ([SixxFix #12](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix/issues/12)).
- **Flash when a swing lands** ([SixxFix #19](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix/issues/19)).
- **Dead-zone colouring** with leading/trailing seconds ([SixxFix #21](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix/issues/21)) – logic by maldon, [LeftHandedGlove PR #22](https://github.com/LeftHandedGlove/WeaponSwingTimerAddon/pull/22).
- **Reset swing after a spell cast** – experimental, check it matches your server ([LeftHandedGlove #19](https://github.com/LeftHandedGlove/WeaponSwingTimerAddon/issues/19)).

For macros and other addons ([LeftHandedGlove #13](https://github.com/LeftHandedGlove/WeaponSwingTimerAddon/issues/13)):
```
/run print(WeaponSwingTimer_GetSwing("player"))          -- seconds left, weapon speed (main hand)
/run print(WeaponSwingTimer_GetSwing("player", "off"))   -- off hand
/run print(WeaponSwingTimer_GetSwing("target"))          -- your target
```

### WotLK mechanics and community fixes
Taken from the original author's own WotLK work and from open pull requests on the original repositories:
- **Slam no longer resets the swing timer** (as in WotLK) – from watchyoursixx's `wotlk-master` branch.
- **Auto Shot has no cast time** (as in WotLK): the red "cast" section, the Multi-Shot clip marker and their colour options are gone – from watchyoursixx's `wotlk-master` branch.
- **Aimed Shot is instant** and no longer resets the Auto Shot timer – from watchyoursixx's `wotlk-master` branch.
- **Off-hand starts half a swing late** when auto-attack begins – by Treeston, [LeftHandedGlove PR #27](https://github.com/LeftHandedGlove/WeaponSwingTimerAddon/pull/27).
- **Haste changes only rescale a running swing** – by Treeston, [LeftHandedGlove PR #26](https://github.com/LeftHandedGlove/WeaponSwingTimerAddon/pull/26).
- **No divide-by-zero on a zero ranged base speed** – by Matthew Carlis, [SixxFix PR #48](https://github.com/watchyoursixx/WeaponSwingTimer-SixxFix/pull/48).

### Changes needed for 3.3.5a
Most of these live in `WeaponSwingTimer_Compat.lua`, so the rest of the code stays close to the original.
- The combat log is rebuilt from 3.3.5 event arguments (there is no `CombatLogGetCurrentEventInfo`).
- 3.3.5 swings carry no off-hand flag, so the hand that swung is inferred from which timer is ready. This can very occasionally guess wrong when both hands are ready at the same moment.
- Swing resets and hunter shots are matched by spell name, so every rank works, including the WotLK ranks; Death Knight Rune Strike is added.
- The hunter cast bar reads the real cast time from `UnitCastingInfo`, so haste and pushback are exact.
- The bar backplane is a plain colour fill; the original white background texture rendered untinted on 3.3.5.
- Options use the 3.3.5 Interface Options window and color picker instead of the retail Settings API; `BackdropTemplate` and `SetColorTexture` are not used.
- Ace3 CallbackHandler and AceDB are patched for the missing `securecallfunction` and `GetCurrentRegion`.
- The TBC-era per-character settings migration is removed; any character it had moved to a "Name - Realm" profile is moved back to Default.
