# Moon Action 🌙

An **original** portrait 3D card-battle game for iOS.
It plays like the anime card-fighter genre: you play cards to fight, the camera sits over your fighter's shoulder, and the battles are flashy 3v3 team fights.
Every character, name, move, model, image and sound is original and generated in code.

## What it plays like

- **Portrait, one-handed.** An over-the-shoulder 3D camera sits behind your fighter. Specials, Ultimates and K.O.s get cinematic camera cuts, slow-mo, hit-stop and screen shake.
- **Card battle.** You hold a fanned hand of 4 cards drawn from your fighter's deck. A **NEXT** preview shows the upcoming card, and played cards are replaced from the deck.
  - 🔴 **Strike**: dash in for a melee combo of jabs, crosses, kicks and uppercuts.
  - 🟡 **Blast**: energy projectiles. A blast stops a striker who is dashing in, and opposing shots clash and cancel each other out.
  - 🔵 **Special Art**: each fighter's signature move (beam, rush or volley), with a camera cut.
  - 🟣 **Ultimate Art**: appears once the gold gauge is full. It opens with a full-screen cut-in, then fires a giant beam or a meteor.
  - 🟢 **Effect cards**: heal, barrier, power-up, energy surge, or a curse that lowers enemy defense.
  - 🌑 **Eclipse Rush**: a team finisher unlocked by collecting 7 moon shards, which you earn by landing cards and card chains.
- **Card chains.** Playing a card right after the previous one lands cancels its recovery and stacks a damage bonus.
- **Gestures.**
  - Tap the arena: basic attack.
  - Swipe left or right: evade (a sidestep with brief invincibility that also breaks enemy combos).
  - Swipe up: dash in. Swipe down: step back.
  - Hold: charge energy.
- **Team play.** Tap a bench portrait to tag in a teammate. **AUTO** mode lets the AI play your cards.
- **Progression.** A stage ladder with rising AI difficulty, coins and XP, levels, and a coin-based Summon.

## 3D characters (procedural)

`Render/FighterModel.swift` builds every fighter at runtime from SceneKit primitives:
- **Skeleton:** a joint hierarchy (spine, head, shoulders, elbows, hips, knees) posed by keyframes. It covers stance, jabs, kicks, uppercut, finisher, dash, blast, beam charge and fire, charge, hurt, KO and victory.
- **Toon look:** cel shading through a lighting-model shader modifier, a rim light, and inverted-hull outlines.
- **Anime heads:** sclera, iris and highlight eyes, angled brows, and six hairstyles built from cones (spiky, long, flat-top, ponytail, swept blades, flame).
- **Outfit variants:** coat tails, scarf and shoulder pads. Each fighter also has its own build (height and bulk) and an aura particle system.

## Native Liquid Glass UI

All UI uses native UIKit controls in the iOS 26 Liquid Glass style:
- `UIGlassEffect` panels;
- `.glass()` and `.prominentGlass()` buttons;
- SF Symbols and the SF Rounded font.

On iOS 15–18 the same controls fall back to blur materials.

## Copyright / IP

- No third-party characters, names, logos, models, art, music or sound are used.
- Characters, card art, arenas and sound effects are all generated in code.
- Genre mechanics such as cards, evading, team tag and gauges are general conventions. This project copies no specific game's content, characters, presentation or branding.

## Building

```bash
brew install xcodegen
xcodegen generate
open MoonAction.xcodeproj
```

CI (`.github/workflows/build-ipa.yml`) builds an unsigned IPA on a macOS runner with Xcode 26.
It also runs the app in the iOS Simulator in demo modes (`-demo home|team|summon|battle|special|ultimate|result`) to capture screenshots, then publishes everything as a GitHub Release.

Requirements: iOS 15+, portrait.
