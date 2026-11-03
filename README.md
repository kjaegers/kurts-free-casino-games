# Kurt's Free Casino Games

**No Ads. No Spam. No BS.**

A free, offline collection of single-player casino games played purely for fun. Chips are play money: they are never sold, never cashed out and worth nothing. There are no ads, accounts, tracking, purchases or network calls. The odds are honest, and running out of chips never stops you playing.

This is the sibling project of [Kurt's Free Games](../kurts_free_games). It shares that app's shell (home menu, favorites, stats, settings, about), its neon theme and shared widgets, and its playing-card components. It ships none of its games.

## Status

The app shell is in place and no games have been added yet. See `CLAUDE.md` for the project rules and the architecture reference, including the checklist for adding a game.

## Building

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn   # self-hosts CanvasKit so the web build works offline
flutter build apk --release
```

`build_and_distribute.ps1` bumps the build number, builds the APK and web app, and copies them to `$DistRoot`. Set `$DistRoot` at the top of the script before the first release. Never point it at the Kurt's Free Games folder, or the copy will overwrite that site. `build-forplaystore.ps1` builds a signed App Bundle and expects `android/key.properties` (not included).

## Layout

- `lib/app/`: app root, router, theme, saved-game registry, bundled licenses
- `lib/core/`: shared services (stats, settings, favorites, storage), widgets, layout, audio, haptics, animation, achievements
- `lib/core/cards/`: shared playing cards: model, deck factory, save codec, card/pile widgets
- `lib/features/`: home, stats, settings and about screens, plus one folder per game under `games/`
- `test/core/`: tests for the shared code

## AI Assistance Disclaimer

Much of this app was built with help from AI coding tools, chiefly [Claude](https://claude.ai) by Anthropic. The project owner directs, reviews and tests all the work, but some code, tests and documentation were written or drafted by AI.

## License

Copyright (C) 2026 Kurt Jaegers.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [LICENSE](LICENSE) for the full text.

Bundled fonts keep their own licenses (Roboto: Apache-2.0; Noto: SIL Open Font License 1.1), in `assets/fonts/`.

## Privacy

Everything is stored on the device. The only external link is the optional Patreon link on the About screen, which opens in the external browser when tapped. See `privacy_policy.html`.
