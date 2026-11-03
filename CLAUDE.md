# Kurt's Free Casino Games — Project Instructions

**Philosophy:** No Ads. No Spam. No BS.

A collection of free, single-player casino games, played purely for fun with play chips, providing straightforward entertainment with no advertising, tracking, subscriptions, artificial restrictions, or unnecessary complication. Simple, responsive, visually consistent, reliable, and fully functional offline. Every decision must respect the player's time, attention, privacy, and freedom — the goal is games people enjoy, not engagement to monetize or manipulate.

These rules apply to all work: new games, enhancements, bug fixes, refactors, UI changes, dependencies, build processes.

---

## 1. No Ads, No Spam, No BS (non-negotiable)

- **No ads**: no advertisements, ad SDKs/networks, sponsored content, promotional overlays, rewarded/interstitial/banner/native ads, ad identifiers, or ad-related tracking — ever, including to unlock content/hints/continued play.
- **No spam**: no unsolicited notifications/emails/messages, push notifications, nagging to rate/review/share/donate/return, compulsion-engineered mechanics, required accounts/login/email/PII, or unnecessary permissions.
- **No BS**: no paywalls, subscriptions, premium currency, microtransactions, energy systems, artificial waits, frustration-for-purchase mechanics, dark patterns/deceptive rewards/hidden conditions, forced tutorials, unnecessary splash/confirm/interrupt screens, inflated/fake scores or rankings, misleading claims, or needless UX complexity.

Games must be immediately accessible, understandable, and enjoyable. **If a feature primarily serves marketing, monetization, data collection, or engagement metrics rather than the player, don't build it.**

---

## 2. Strict Offline-First Architecture

The entire app must work completely offline — this is architectural, not a preference.

**Prohibited at runtime:** contacting external servers (startup or gameplay), remote APIs/cloud services, runtime-downloaded data/assets/config, external analytics/telemetry, update checks, license/online validation, ad loading, remotely hosted fonts/images/scripts/styles/libraries, CDN-delivered runtime deps, crash/diagnostic reporting, remote auth/accounts, cloud progress sync, background HTTP/HTTPS/WebSocket connections, or any dependency with undisclosed network activity. All runtime assets/deps ship with the app.

**The only permitted external link is Patreon**, and only when the player explicitly taps it:
- Opens in the device's default external browser (never an in-app WebView).
- No automatic contact with Patreon; no usage data/stats/identifiers sent.
- Never required for any functionality, never gated content/features/hints/difficulty, never grants gameplay advantages, never tracked whether visited, no account integration, no gameplay interruption to promote it.
- Presented optionally and unobtrusively; app is equally enjoyable for players who never donate. No other external runtime link/destination without explicit project-owner approval.

**Dev-time vs runtime:** installing deps, fetching tools, publishing builds may need network access — that's fine and separate from runtime behavior. Never add a runtime network dependency just because tooling needed internet. When adding/updating a dependency, verify no runtime network calls, tracking, or remote resources; review platform config for unneeded network permissions.

---

## 3. Player Privacy and Data

- No PII collection, behavioral tracking, cross-app/device persistent identifiers, external transmission of gameplay stats/preferences, device fingerprinting, analytics platforms, or externally-transmitting crash reporters.
- Local persistence only (scores, games played/won/lost, puzzle completions, difficulty/sound prefs, unfinished games, achievements) via the app's existing persistence mechanism — don't build a separate storage system per game unless technically necessary.
- Store only what's needed for player-facing functionality; use stable documented structures; handle corrupted/outdated saves safely; offer a way to reset stats/local data where appropriate.

---

## 4. Respect the Existing Application

Before implementing: examine the repo, framework/language, existing game architecture, shared components/utilities, navigation and game-registration conventions, theme/color/typography/layout patterns, persistence/stats mechanisms, and existing test/build procedures.

The results of this examination are cached in §17 (Architecture Reference). Start from it rather than re-surveying the repo.

**Don't invent a new architecture when a suitable pattern exists.** New games should feel like they were always part of the collection. Avoid competing UI frameworks, redundant state management, duplicate implementations of shared features, inconsistent navigation, unnecessary deps, or unrelated rewrites. Prefer extending existing systems; if an established pattern is genuinely unsuitable, explain why before a substantial architectural change.

---

## 5. Consistent Game Design

**Identity:** short recognizable name, concise description, category, consistent visual identity, icon matching conventions, clear instructions. Avoid trademark-conflicting names and don't reuse copyrighted artwork/sound/branding without rights — classic mechanics are fine, presentation must be original.

**Common features (where applicable):** New Game, Restart, Difficulty selection, Pause/Resume, sound settings, instructions, personal-best tracking, scoring/stats, save & resume, touch + mouse, keyboard where appropriate. Don't force features that don't fit the genre (e.g., Undo fits a logic puzzle, not a reflex game).

**Difficulty:** clear labels, real gameplay impact, no unfair/deceptive scaling, never secretly rig losses, no mid-game difficulty changes without player action, generated puzzles must be valid/solvable.

**Randomness/fairness:** appropriate RNG, seeded randomness for testing/daily challenges when useful, never manipulate randomness or fake opponent performance to manufacture losses; computer opponents follow the same rules as the player unless documented otherwise.

**Scoring:** reflects actual gameplay, consistent and understandable rules, comparable scores only where rules justify it, personal bests stored locally, distinguish assisted vs unassisted results, never fabricate rankings/scores.

**Casino play-money rules (§1 and the fairness rules above, applied to gambling mechanics):**
- Chips are play money only: never purchasable, never redeemable, never exchangeable for anything of value, and no real-money wagering, prizes or sweepstakes of any kind.
- Running out of chips is never a wall: a free, instant bankroll reset with no wait, no prompt to pay and no ad. Don't gate games, tables or bet limits behind chip totals unless the player chooses it.
- Honest odds: outcomes come from an unbiased RNG and the published rules/paytable only. No near-miss engineering, no adaptive odds (not to "hook" a new player with early wins, not to drain a big stack), no dealer/house behaviour beyond the stated rules.
- Show the rules that decide money: paytables, payouts, house rules (e.g. dealer stands on soft 17, blackjack pays 3:2) and, where meaningful, the theoretical return, in How to Play or on the table.
- No compulsion loops borrowed from real-money gambling: no daily-login chip bonuses, loss-chasing prompts, "so close!" messaging, celebrations out of proportion to the win, or autoplay that hides losses. Brief, proportionate win feedback is fine.
- Stats report real outcomes (hands won/lost, net chips, biggest win), never inflated numbers.

---

## 6. Visual and UI Consistency

Maintain the existing design language so the app feels like one cohesive collection.

- Follow existing color/typography/spacing/component conventions; reuse shared nav/controls; consistent buttons; preserve menu/dialog patterns; uncluttered interfaces; essential info easy to find; avoid needless animation/decoration. Existing themes/tokens take precedence over new styling.
- **Responsive:** support touch + mouse, comfortably large touch targets, no overflow of boards/controls, no excessively small text, adapt layouts without hurting usability, support varied aspect ratios/orientations where practical — never assume desktop-sized screens.
- **Accessibility (where practical):** readable contrast, don't rely on color alone, meaningful control labels, respect reduced-motion settings, allow disabling sound, avoid unnecessary flashing, intuitive input/feedback.
- **Animation:** supports gameplay, not distraction — short, smooth, lightweight; avoid particle/animation systems that hurt performance.

---

## 7. Instructions and Onboarding

Every game needs clear, accessible instructions covering objective, controls, key rules, win/lose conditions, scoring, and difficulty options (where relevant). Keep concise for casual players; use examples/illustrations only when they genuinely help. No website/video/account/external docs required to learn to play. Don't force lengthy tutorials on experienced players.

---

## 8. Sound and Audio

Follow existing audio conventions: bundled local assets only, no streaming, no external sound libraries needing runtime network access, respect sound/mute preferences, avoid unexpectedly loud effects, brief appropriate feedback sounds, never make sound the sole indicator of an important event, no autoplaying lengthy music without good reason. Sound should enhance gameplay, not annoy.

---

## 9. Performance and Reliability

**Performance:** minimize startup time, avoid unnecessary background processing/excessive memory allocation, keep animation/input responsive, efficient puzzle generation/solving algorithms, don't block UI with expensive calculations, cache/precompute where sensible, avoid heavy deps for trivial functionality.

**Reliability:** validate input, handle unexpected game states gracefully, prevent duplicate actions from rapid taps, avoid timer/animation race conditions, clean up timers/listeners/resources, preserve valid saves across updates, never silently overwrite player progress.

**Deterministic logic:** keep core rules independent of rendering where practical; game logic should be testable without launching the full app. Prefer pure functions for move validation, board transformations, scoring, win/loss detection, puzzle generation, solver logic, and computer-opponent decisions.

---

## 10. Code Quality and Maintainability

- Follow repo formatting/naming conventions; appropriate types/data structures; prefer simple solutions over unnecessary abstraction; no duplicate logic; focused functions; descriptive names; explicit error handling where appropriate; comment unusual algorithms/non-obvious decisions; remove unused code/imports/debug code/temp workarounds.
- **Dependencies:** before adding one, check whether existing code/platform functionality already solves it, evaluate size/maintenance cost, verify license, confirm no runtime network activity or data collection. Prefer fewer deps; never add SDKs/services/frameworks conflicting with offline/privacy requirements.
- **Scope control:** focus on the requested change; avoid unrelated refactoring; preserve working behavior; don't rename/reorganize unrelated files or touch unrelated games without clear technical reason; no speculative features. Explain if a larger change is genuinely necessary.

---

## 11. Testing and Validation

Test fundamental rules, win/loss conditions, edge cases/invalid input, difficulty settings, init/restart, save/resume, computer-opponent legality/fairness, puzzle solvability, scoring/stats, touch/mouse interaction, and relevant responsive layouts. Use the repo's existing test framework — don't add a new one without compelling reason.

**Offline verification:** for any new feature/dependency, check for hidden network requests, remote assets, CDN references, analytics calls, third-party SDK init, and network-dependent startup — ordinary functionality must never require internet. Patreon remains the sole player-initiated external destination.

**Regression:** run relevant automated tests, linting/static analysis, and a build; verify shared functionality still works; fix failures you introduced. Never claim tests passed without actually running them successfully.

---

## 12. Adding New Games

1. Find the closest existing architectural reference (see §17, which replaces a fresh full-repo survey); understand target rules/UX.
2. Identify reusable components/services; design the game-state model.
3. Implement core logic, then a consistent responsive UI.
4. Add instructions; integrate stats/persistence where applicable.
5. Register in the game collection; add/update tests.
6. Verify offline operation; run build + regression checks.

**Completion checklist:** launches from the collection · core rules correct · win/loss detection works · controls work on supported platforms · UI matches app conventions · difficulty works where applicable · instructions present · restart/new-game correct · stats/persistence work where applicable · no external runtime connections introduced · no ads/tracking/paywalls/unneeded prompts · relevant tests pass · app builds · existing games still work.

---

## 13. Working with the Project Owner

Inspect the repo before architectural assumptions; follow established conventions unless told otherwise; ask only when a major design decision can't reasonably be inferred (don't ask about details already settled in the codebase). Favor complete working implementations over scaffolding; flag meaningful limitations/risks; never silently weaken existing functionality or claim untested/unimplemented work is done; don't expand scope without justification.

After substantial changes, give a concise summary: what was implemented, key files changed, notable design decisions, testing performed/results, known limitations. Skip lengthy explanations for routine changes.

---

## 14. Decision-Making Priorities

When requirements conflict, in order:

1. Player privacy and complete offline operation
2. No Ads, No Spam, No BS philosophy
3. Correct, fair, enjoyable gameplay
4. Consistency with the existing application
5. Reliability and preservation of player progress
6. Accessibility and responsive design
7. Performance and resource efficiency
8. Code simplicity and long-term maintainability
9. Visual polish and optional enhancements

These override convenience, speculative features, and unnecessary sophistication. If a requested feature conflicts with these foundations, explain the conflict and propose an alternative rather than silently violating the rules.

---

## 15. Guiding Principle

**Kurt's Free Casino Games should feel like the kind of free software people wish there was more of.**

Open the app. Pick a game. Have fun. No account. No internet required. No ads. No tracking. No purchases. No manipulation. No nonsense. Just games.

**No Ads. No Spam. No BS.**

## 16. After adding a game

When adding a new game to the collection:
1. Update docs/index.html to ensure all games are listed in the Games in the Collection section
2. Run .\build_and_distribute.ps1 to build and distribute the updated application.
3. Update the recent changes section in docs/index.html with the new game's addition.

---

## 17. Architecture Reference (cached analysis)

This project was created from **Kurt's Free Games** (`c:\src\kurts_free_games`, "the sibling repo"), keeping its app shell, style and shared components but none of its games. Trust this section for orientation. If something here turns out to be wrong or stale, fix this section in the same change.

### Stack
- Flutter / Dart (SDK ^3.12), Material 3, single dark neon theme. Targets: Android APK + web (also runs on Windows). On web/Windows the app is drawn inside a phone-aspect container (393×852 reference, `KfgDesignScale`).
- Runtime deps (all offline): `shared_preferences` (via `PersistentStorage`), `audioplayers` (via `KfgTonePlayer`), `url_launcher` (Patreon link only). Dev: `flutter_test`, `flutter_lints`, `flutter_launcher_icons`. `flame` was deliberately left out (the sibling repo uses it only for real-time arcade games); add it back only if a game genuinely needs it.
- Fonts are bundled (`KfgFonts`: Roboto + KfgSymbols/KfgArrows/KfgEmoji fallbacks; ♠♥♦♣ render from these). Text painted with a raw `TextPainter` must set `fontFamily`/`fontFamilyFallback` itself or web will fetch fonts.
- Commands: `flutter analyze`, `flutter test` (or `flutter test test/<game>`), `flutter build web --release --no-web-resources-cdn` (web build must self-host CanvasKit).
- Shared class names keep the sibling repo's `Kfg` prefix (`KfgColors`, `KfgNeonCard`, `showKfgResultDialog`…) so components can move between the two projects unchanged.
- Identity: package `kurts_free_casino_games`; Android/iOS/macOS/Linux id `com.kurtjaegers.kurtsfreecasinogames`, so it installs alongside Kurt's Free Games. The app icon is still the sibling's (`assets/icons/app_icon.png` and the generated platform icons) until a casino icon is made.

### Layout
```
lib/app/            kfg_app.dart, kfg_router.dart (routes), kfg_saved_games.dart (save-key registry), kfg_theme.dart (KfgColors/KfgFonts/KfgTheme), kfg_licenses.dart
lib/core/models/    game_definition.dart (+ kReadyPlayableGameIds), game_category.dart (card/table/dice/slots), game_result.dart, achievement.dart, <game>_stats.dart (one per game)
lib/core/services/  game_registry.dart, stats_service.dart, credits_service.dart, persistent_storage.dart, settings_service.dart, favorites_service.dart
lib/core/cards/     shared playing cards (see below)
lib/core/achievements/ achievement_catalog.dart
lib/core/widgets/   kfg_result_dialog, kfg_how_to_play_dialog, kfg_confirm_dialog, kfg_difficulty_dialog, kfg_neon_button/card, kfg_stat_chip, kfg_section_header, kfg_sound_toggle_button, kfg_credits_badge, kfg_achievements_unlocked
lib/core/layout/    kfg_scaled_game_layout.dart (KfgScaledGameLayout/Frame), kfg_design_scale, kfg_viewport
lib/core/audio/     kfg_tone_player.dart (synthesized tones; no audio assets)
lib/core/haptics/   kfg_haptics.dart
lib/core/animation/ kfg_web_animation_speed.dart (kfgAnimDuration / kfgAnimDurationOf)
lib/features/games/<game_id>/   one folder per game (video_poker, slots_cherry_run, slots_retro_tech, blackjack, roulette, texas_holdem)
lib/features/{home,stats,settings,about}/
test/<game_id>/  test/core/  test/core/cards/   tools/<game_id>/ (offline dev-time tools, e.g. odds/return checkers)
```

### Shared playing cards (`lib/core/cards/`)
Lifted from the sibling repo's Klondike (which its FreeCell also uses) and renamed neutrally:
- `playing_card.dart` — `PlayingCard` (immutable: `id`, `suit`, `rank`, `faceUp`, `copyWith`), `CardSuit` (`color`, `symbol` H/D/C/S, `displayName`), `CardRank` (`value` 1–13 with ace = 1, `label`), `CardColor`. Pure Dart. Ace is low; games where it's high (poker) map that in their own logic rather than changing `CardRank`. **Jokers:** `PlayingCard.joker(id:)`, `isJoker`; a joker has no suit/rank (reading `suit`/`rank`/`color` throws), so check `isJoker` first.
- `card_deck_factory.dart` — `CardDeckFactory.createOrderedDeck({int jokers = 0})` / `createShuffledDeck({Random? random, int? seed, int jokers = 0})`. Jokers are only added when a game's rules ask for them (ids `J01`, `J02`…). Card ids are `<suit><2-digit rank>` (e.g. `H01`), unique only within one deck: a multi-deck shoe (blackjack, baccarat) must make ids unique per deck (e.g. a deck-index suffix) before using ids as keys.
- `playing_card_codec.dart` — `encodeCardPile` / `decodeCardPile`: 3 characters per card for saves (upper-case suit = face up; a joker is `J`/`j` + its number). Decoding rebuilds ids as `<suit><rank>` / `J<nn>`, so multi-deck saves need their own id scheme too.
- `playing_card_widget.dart` — `PlayingCardWidget` (face / back / joker / empty slot, `selected` / `highlighted` states with SEL/DROP badges — `showStatusBadges: false` keeps the glow but drops the badge when the game labels the state itself — semantics that never reveal a face-down card, ≥4.5:1 ink contrast — tested). `animated_playing_card.dart` — `AnimatedPlayingCard` + `CardAnimationCue` (slide in from an offset, fade on flip; uses `kfgAnimDuration`). `card_pile_widget.dart` — `CardPileWidget` (labelled tappable pile with count and status line, 48 px minimum target). `card_drag_mode.dart` — `CardDragMode` (immediate / long-press drag preference).

### Reference games
**In this repo:** `video_poker` — the reference for card games with betting: the shared credits wallet (debit on deal, credit on payout, free refill), a paytable widget, pure evaluator + variant enum, save of a dealt hand (hand + stub so the draw is identical on resume), per-hand stats, achievements with progress, and `tools/video_poker/return_check.dart` (exhaustive perfect-play return, also run as a test).
`blackjack` — the reference for table games against a dealer: a multi-deck shoe carried between rounds (cut card, reshuffle only between rounds, plain single-deck card ids with a count-per-id check instead of unique ids), extra stakes taken mid-round (double/split/insurance, each checked against the balance), several hands in one round settled together, and a published return estimated by simulation (`tools/blackjack/return_check.dart` plays basic strategy through the real logic) rather than enumerated.
`slots_cherry_run` — the reference for slot machines: published reel strips with uniform stops (`logic/cherry_run_reels.dart`), line evaluation and exact return (`logic/cherry_run_paytable.dart`, `tools/slots_cherry_run/return_check.dart`), symbols painted with `CustomPainter` (no image assets), a reel animation that only reveals stops picked at SPIN, and the bet-debited-at-spin / paid-when-reels-stop flow, where a spin still turning is saved and paid on return, dispose or pause. Its classes use a short `CherryRun` prefix rather than the id.
`slots_retro_tech` — the reference for cascading/grid slots: weighted per-symbol draws (`logic/retro_tech_symbols.dart`), cluster finding and a cascade resolved entirely at SPIN from an injected draw (`logic/retro_tech_cascade.dart`; the drawn symbols are the save, rebuilt with `replay`), a controller-paced beat timeline (fall → win → fall…) that the grid widget only animates, 16×16 pixel-art sprites painted from strings (`widgets/retro_tech_symbol.dart`), and a simulated return (`tools/slots_retro_tech/return_check.dart`). Classes use a `RetroTech` prefix.
`roulette` — the reference for a betting layout: every legal bet in one pure catalogue with grid-unit "spots" (`logic/roulette_bets.dart`), tap hit-testing in pure Dart (`rouletteBetAt`, round-trip tested for every spot) mapped to a vertical (portrait) or horizontal (landscape) painted board, chips placed/undone/kept for the next spin, an exact per-bet return check (`tools/roulette/return_check.dart`), and the slots-style spin flow (pocket picked and stake debited at SPIN, a spin still rolling saved and paid on return).

`texas_holdem` — the reference for computer opponents: an immutable hand (`logic/holdem_hand.dart`: blinds, no-limit betting with the short-all-in rule, side pots, odd chips) inside a table of persistent opponents (`logic/holdem_table.dart`), a 7-card evaluator and Monte Carlo equity (`logic/holdem_evaluator.dart`), an AI that gets only a `HoldemAiView` (its own cards + public betting, never the deck or other hands) with difficulty × per-opponent style (`logic/holdem_ai.dart`), opponents' turns paced by a cancellable timer in the controller (paused with the app and while dialogs are open; tests inject the decider and drive turns with `runOpponentsForTest`), the player's stake taken from credits at the deal and the final stack credited back, and `tools/texas_holdem/ai_check.dart` (difficulties played against each other).

**In the sibling repo** (read them there): for other patterns open the sibling repo's files (`c:\src\kurts_free_games\lib\features\games\<id>\`), translating imports and the card class names above (`KlondikeCardWidget` → `PlayingCardWidget`, `KlondikeAnimatedCard` → `AnimatedPlayingCard`, `KlondikePileWidget` → `CardPileWidget`, `KlondikeDeckFactory` → `CardDeckFactory`, `KlondikeDragMode` → `CardDragMode`):
- **Standard game folder** (screen + controller + save service + `logic/` + `widgets/`, stats model, tests): `dice_ledger` — newest mid-sized complete game, and the dice reference (injected `DieRoller`).
- **Card table layout, tap + drag, undo, card animations:** `klondike`, `freecell` (their boards, drag data and tableau columns were not carried over; adapt them if a game needs them).
- **Turn-based vs. computer AI with a worker isolate:** `stone_strategy`, `checkers`, `chess`.
- **Real-time timers / difficulty dialog without Flame:** `grid_grill`. **Achievements wiring:** `tower_guard`.

Standard game folder:
```
lib/features/games/<id>/
  <id>_screen.dart              StatefulWidget + WidgetsBindingObserver; owns dialogs, shortcuts, layout
  <id>_screen_controller.dart   ChangeNotifier; wraps pure logic; clock, sounds, haptics, autosave, stats
  <id>_save_service.dart        <Id>SavedGame (toJson / static fromJson → null on bad data) + <Id>SaveService
  <id>_worker.dart              (optional) `compute()` wrapper for expensive AI/odds searches
  logic/                        pure Dart, no Flutter imports: immutable game state, rules, payouts, RNG, AI
  widgets/                      table/painters, <id>_controls.dart, <id>_how_to_play.dart, <id>_new_game_dialog.dart, status bar
lib/core/models/<id>_stats.dart immutable stats value object with copyWith* methods
test/<id>/                      <id>_test_support.dart, logic/rules tests, controller test, screen test
```

### Key patterns
- **Pure logic:** game state is an immutable class; transitions return a new instance and throw `StateError` when illegal, with matching `can…` getters the controller checks first. Derived values (hand totals, payouts) are computed, not stored twice. RNG is injected (e.g. `typedef DieRoller = int Function()`, a `Random`, or a pre-shuffled deck) so tests script outcomes; `toJson`/`fromJson` live on the state with a schema version. Payout/paytable math is pure and unit-tested; where a theoretical return is published, verify it with a tool in `tools/<id>/` or a test.
- **Controller:** constructor takes optional injectables (`StatsService? stats`, `SaveService? saveService`, RNG, `KfgTonePlayer? tonePlayer`, `DateTime Function()? clock`, `Duration Function(Duration)? animationDuration`) defaulting to the real ones. `initialize()` awaits `_stats.ensureLoaded()`, loads the save (resume exactly — never redeal or re-spin an in-progress hand) or starts with remembered preferences. Guards: `_initialized`, `_disposed`, `_notify()` checks disposed; input locked during animations; a `gameId` counter so the result dialog shows once per game; `_resultRecorded` so stats record once. Clock pauses on `pause()` and resumes on `resume()`. `dispose()` saves, cancels timers, disposes tones.
- **Screen:** `Scaffold(backgroundColor: KfgColors.background)` with `AppBar(toolbarHeight: 44, title: FittedBox(fit: BoxFit.scaleDown, child: Text('GAME NAME')))` (uppercase) and actions: credits (`KfgCreditsBadge`, **required in every game** so the balance is always visible), sound toggle (`KfgSoundToggleButton`) and How to Play (`Icons.help_outline`). Body: `CallbackShortcuts` → `Focus(autofocus)` → `KfgScaledGameLayout(builder: (ctx, frame) => ListenableBuilder(...))`, with a wide/landscape branch (`frame.contentWidth > frame.contentHeight * 1.2`) and a compact branch for short screens. A `_dialogOpen` flag blocks input and duplicate dialogs. Keyboard shortcuts use `SingleActivator(..., includeRepeats: false)`.
- **Shared dialogs:** `showKfgResultDialog(won:, title:, subtitle:, stats: [KfgDialogStat], onNewGame:, secondaryActionLabel:)` — record stats *before* showing it. `showKfgConfirmDialog` before discarding progress. `showKfgHowToPlayDialog(sections: <id>HowToPlaySections)` with a `const List<KfgHowToPlaySection>` (OBJECTIVE, rules, PAYOUTS, MODES/DIFFICULTY, hints/assistance, CONTROLS incl. keyboard, SAVING). `KfgDifficultyDialog<T>` with `KfgDifficultyOption(label, subtitle stating real parameters, color success→primary→warning→secondary)`.
- **Controls row:** each game has its own `widgets/<id>_controls.dart` (small icon+label cards with tooltips/semantics, null callback = disabled). Copy the closest one from the sibling repo rather than inventing a new style.
- **Styling:** use `KfgColors` only (background, surface, surfaceVariant, primary cyan, secondary magenta, highlight/success green, warning yellow, error, textPrimary/Secondary/Muted, cardBorder). Rounded 8–14 px corners, bold/letter-spaced uppercase labels, `FittedBox(scaleDown)` to avoid overflow. Text scale on `/game/*` routes is clamped to 0.9–1.0, so layouts must fit at those scales.
- **Motion/sound/haptics:** wrap every cosmetic duration in `kfgAnimDurationOf(context, d)` (or `kfgAnimDuration(d)` in controllers) — returns zero under reduce-motion, stretches on web; never use it for gameplay timing. "Reduce motion" is `kfgReduceMotion`: Settings > Animations (Follow Device / On / Off) over the device flag, which `KfgApp` also writes into `MediaQuery.disableAnimations` and `KfgBinding` (`lib/app/kfg_binding.dart`, created in `main()`) feeds to `SemanticsBinding.disableAnimations` — otherwise Flutter runs every `AnimationController` at 5% speed whenever the OS asks for reduced motion, whatever the setting. Any `MediaQuery` added above that override (e.g. a text-scale clamp built from an outer context) silently restores the device flag; `test/core/kfg_app_reduce_motion_test.dart` guards this (browsers on Windows report reduce motion whenever Windows' "Animation effects" is off). Sounds via `KfgTonePlayer(...).playFrequency(hz)` (respects mute, swallows errors). Haptics via `KfgHaptics.selection/light/medium/heavy`. Use `Semantics` labels on cards/dice/chips and a `liveRegion` for status messages (e.g. hand results).
- **Expensive computation:** run AI/odds searches through `compute()` in `<id>_worker.dart`; on web `compute` runs inline, so also cap search time. Precompute tables offline in `tools/<id>/` and ship them as Dart data.

### Persistence
- All storage goes through `persistentStorage` (`PersistentStorage`: getString/setString/remove/getKeys; SharedPreferences on native, raw localStorage keys on web).
- **Key prefix `kfcg_`:** the sibling app uses `kfg_…` and `<game>_…` keys, and on web both apps can share an origin (and so localStorage). Every key here starts with `kfcg_`: `kfcg_stats_v1`, `kfcg_settings_v1`, `kfcg_favorites_v1`, and game saves `kfcg_<id>_save_v1`.
- **In-progress save:** `<Id>SaveService({PersistentStorage? storage})`, `static const String storageKey = 'kfcg_<id>_save_v1'`; `load()` wraps everything in try/catch and returns null on malformed data; save after each meaningful action; clear on completion/new game; don't save an untouched game. **Must** register the key in `KfgSavedGames.keys` (or `keyPrefixes` for per-day keys) in `lib/app/kfg_saved_games.dart` — `test/core/kfg_saved_games_test.dart` scans game sources and fails otherwise; also add the literal key to that test's "covers every known save key" list.
- **Credits (bankroll):** one play-money balance shared by every game: `CreditsService.instance` (`lib/core/services/credits_service.dart`, key `kfcg_credits_v1`, 1,000 starting credits, loaded in `main()`). Games `debit(bet)` when a round starts (returns false if unaffordable) and `credit(payout)` when it ends; `formatCredits` formats amounts. Never reset it silently: a free, instant `reset()` is offered in-game when the player can't cover the minimum bet (FREE REFILL) and in Settings > Reset Credits. It is not a saved game and not a statistic, so Clear Saved Games / Reset Statistics leave it alone. Inject a `CreditsService(storage: …)` in tests. The home header and every game AppBar show it via `KfgCreditsBadge`.
- **Stats:** all in one JSON blob (`kfcg_stats_v1`) owned by `StatsService` (singleton, `StatsService.instance`). Per-game detail lives in `lib/core/models/<id>_stats.dart` (immutable, `copyWith*`; preferences like last-used bet or table rules also live here). Overview numbers come from `recordGameFinished(gameId, won: bool?/null for no-outcome sessions, durationSeconds:, score:)`, called once when a game ends — decide per game what one "game" is (a hand, a shoe, a session) and record it consistently; abandoned games are not reported.
- **Achievements** (opt-in per game): definitions in `lib/core/achievements/achievement_catalog.dart` (IDs `<gameId>.<name>`), state in the stats blob (`achievements` key) via `StatsService.recordAchievements` (unlocks once, returns only new unlocks). Evaluate in the game's pure logic at the terminal result, record before the result dialog, pass `newAchievements:` to `showKfgResultDialog`, and wrap the game's Stats section in `_WithAchievements(gameId:, progress:)`. Reference: the sibling repo's `tower_guard`. Achievements reward play and skill, never chip totals that would push bigger bets.

### Registration checklist for a new game (every touch-point)
1. `lib/core/services/game_registry.dart` — append a `GameDefinition(id: '<snake_id>', title, description (one sentence), category: GameCategory.<card|table|dice|slots>, status: GameStatus.playableStub, routeName: '/game/<kebab-id>', icon: Icons.<...>, tags: [...])`. For a glyph Material Icons lacks, also pass `iconBuilder:` (a painted one-colour icon, e.g. `kfgCherryIcon` in `lib/core/widgets/kfg_game_icon.dart`); menus render it via `KfgGameIcon`. Add a `GameCategory` value only when a game fits none of them (and give it a colour in `home/widgets/game_card.dart`).
2. `lib/core/models/game_definition.dart` — add the id to `kReadyPlayableGameIds` (otherwise `isReady` is false).
3. `lib/app/kfg_router.dart` — import the screen, add `static const String <camel> = '/game/<kebab-id>'` to `KfgRoutes` and an entry in `_routes`. Route must start with `/game/` (drives text-scale clamping; `test/core/game_registry_test.dart` checks this and that every registered route opens).
4. `lib/core/models/<id>_stats.dart` — new stats model.
5. `lib/core/services/stats_service.dart` — import model; private field `_<camel>Stats`; public getter with doc comment; `record…`/`set…Preferences` methods (each: update, `notifyListeners()`, `_persistAsync()`; the finishing one also calls `recordGameFinished`); reset in `reset()`; parse in `_loadFromStorage()` (`'<camel>Stats'` key); serialize in `_toJson()`; static `_<camel>StatsToJson` and tolerant `_parse<Camel>Stats` (clamp negatives, drop impossible values, skip malformed entries, defaults for missing fields). Copy back any `_as…` parse helpers you need from the sibling repo's `stats_service.dart` (only the ones in use were kept).
6. `lib/features/stats/stats_screen.dart` — read `StatsService.instance.<camel>Stats` in `build`, add a `_GameStatsSection(...)` + `SizedBox(height: 10)` at the placeholder comment (alphabetical), and a `_<Camel>StatsSection` widget returning `_StatGrid(items: [_StatItem(label, value, icon, color)])`, using `'—'` for no data. Remove the `// ignore: unused_element…` comments on `_toggleGame`, `_GameStatsSection` and `_WithAchievements` once they are used.
7. `lib/app/kfg_saved_games.dart` — register the save key (see Persistence).
8. Tests: `test/<id>/…`; a "route opens the game" widget test (`SharedPreferences.setMockInitialValues({})`, `MaterialApp(onGenerateRoute: KfgRouter.onGenerateRoute, initialRoute: ...)`, expect the uppercase AppBar title); `test/core/kfg_saved_games_test.dart` — add the key literal.
9. Docs/build per section 16: `docs/index.html` "Games in the Collection" (alphabetical `<article class="blurb-card">` with an emoji `game-icon` span) and a new top entry in "Recent Changes" (`<li><span class="change-date">YYYY-MM-DD:</span> Added …</li>`); then `.\build_and_distribute.ps1` (it copies the build only once `$DistRoot` is set in the script — never point it at the sibling's `k:\`).

The home screen, category filter and favorites build automatically from the registry — no changes needed there.

### Testing conventions
- `test/<id>/<id>_test_support.dart` provides `MemoryPersistentStorage` (implements `PersistentStorage`), a silent `KfgTonePlayer` subclass, scripted RNG/decks, and play-through helpers (each game has its own copy; the sibling repo's are templates). `test/flutter_test_config.dart` silences tones globally.
- Controller/screen test `setUp`: `TestWidgetsFlutterBinding.ensureInitialized(); SharedPreferences.setMockInitialValues({}); await StatsService.instance.ensureLoaded(forceReload: true); stats.reset(); await stats.saveNowForTest();`
- Construct controllers with injected storage, RNG, silent tones and `animationDuration: (_) => Duration.zero`. Screens expose `@visibleForTesting` constructor params (save service, RNG) and are pumped with `MediaQuery(disableAnimations: true)`.
- Screen tests loop over sizes — small phone 320×568, phone 393×852, landscape 852×393, tablet 1024×1366 (`tester.view.physicalSize = size * 3; devicePixelRatio = 3`) — and assert `tester.takeException()` is null (no overflow).
- Cover: rules/payouts/win-loss in pure logic tests (every paytable line); save round-trip and corrupt-save handling; stats recorded once; restart/new game; bankroll persistence and free reset; RNG fairness where it's non-trivial (e.g. shuffle or reel distribution over a seeded sample).

### Recording game-specific design decisions
Settled per-game design choices and deliberate v1 cuts are kept in Claude's project memory for this repo (one note per game). When a new game is designed, record its key decisions there rather than in this file.
