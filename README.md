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
They reset on abilities that reset a swing timer (Heroic Strike, Cleave, Slam, Maul, Raptor Strike, Rune Strike) and take parry haste into account.
Both frames can be moved with the usual click-and-drag.
Open the options with `/wst`, `/WeaponSwingTimer` or `/weaponswingtimer`.

### Hunter/Wand Bars
The shot bars track the player's Auto Shot and Shoot timing, and the cast time of Aimed Shot, Multi-Shot and Steady Shot.
The shot bar turns white when the projectile leaves the player.
While the bar is white, the player can move and cast freely without clipping their next Auto Shot or Shoot.
When the white bar is depleted, the player should stand still while their Auto Shot or Shoot is 'casting'.

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
