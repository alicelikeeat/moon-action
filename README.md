# Moon Action 🌙

An **original** real-time, card-based 3v3 arena fighter for iOS, built with SpriteKit.
It belongs to the anime card-fighter genre, but every character, name, move, piece of art and sound effect is original.

## Native Liquid Glass UI

All menus and the battle HUD use native UIKit controls in the iOS 26 **Liquid Glass** design language:

- `UIGlassEffect` panels.
- `UIButton.Configuration.glass()` and `.prominentGlass()` buttons.
- SF Symbols and SF Rounded type.

SpriteKit renders only the arena and characters underneath.
On iOS 15–18 the same controls fall back to native blur materials.
The Liquid Glass code is compiled when building with the iOS 26 SDK (Xcode 26), which CI selects automatically.

## Gameplay

- **3 vs 3 team battles**: knock out the whole enemy team before the 150-second timer runs out.
- **Card combat**: you hold 4 cards. **STRIKE** (red) dashes in for a melee combo. **BLAST** (blue) fires projectiles.
- **Energy**: cards cost energy. It regenerates over time, and holding **CHARGE** refills it faster.
- **Rock-paper-scissors**: a blast interrupts a strike that is dashing in, and up close a strike beats a blast. Opposing projectiles cancel each other out.
- **Evade**: swipe the arena or tap EVADE for a brief invincible dodge. It uses 1 of 4 regenerating pips and also breaks you out of enemy combos.
- **Special**: each fighter has a signature move (beam, rush or volley) with a cooldown.
- **Ultimate Art**: landing and taking hits fills the gauge. At 100% a full-screen cut-in triggers a devastating attack.
- **Tag swap**: tap a teammate's portrait to switch them in.
- **Progression**: a stage ladder with rising AI difficulty, plus coins and XP, levels, and a coin-based **Summon** that unlocks new fighters.

### Original roster

| Fighter | Title | Special | Ultimate |
|---|---|---|---|
| Kai Solaris | Dawn Brawler | Daybreak Cannon (beam) | Zenith Sunburst |
| Luna Vey | Moonblade Dancer | Eclipse Waltz (rush) | Silver Tide |
| Rook Thunderhart | Storm Knuckle | Thunderclap Rush (rush) | Skybreaker Bolt |
| Ivy Thorne | Verdant Warden | Thorn Storm (volley) | World Root Bloom |
| Nyx Obsidian ★3 | Void Walker | Abyss Lance (beam) | Event Horizon |
| Blaze Ardent ★3 | Ember Fist | Inferno Combo (rush) | Phoenix Meteor |

## Copyright / IP notice

- No third-party characters, names, logos, art, music, sound or other assets are used.
- All characters are drawn at runtime from vector shapes (`FighterNode.swift`).
- All sound effects are synthesized at launch (`Sound.swift`).
- The app icon was generated for this project.
- Game mechanics such as card-based attacks, dodging and team swapping are general genre conventions. This project does not copy any specific game's content, characters, presentation or branding.

## Building

The project is described by `project.yml` ([XcodeGen](https://github.com/yonaskolb/XcodeGen)).

```bash
brew install xcodegen
xcodegen generate
open MoonAction.xcodeproj
```

### Unsigned IPA (CI)

`.github/workflows/build-ipa.yml` builds on a GitHub macOS runner with code signing disabled and packages `Payload/MoonAction.app` into `MoonAction-unsigned.ipa`.
It uploads the IPA as a workflow artifact and attaches it to a GitHub Release.

To install it, re-sign the IPA with a sideloading tool such as AltStore or Sideloadly, or use TrollStore on supported devices.

Requirements: iOS 15+ on iPhone or iPad, landscape only.
