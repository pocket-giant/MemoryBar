# MemoryBar audit and release direction

## Findings, in priority order

1. **High — permission prompt on launch.** The previous app requested notification access before a user enabled alerts. The new build requests it only when alerts are switched on.
2. **Medium — memory result could exceed its valid range.** The previous page arithmetic could underflow or produce a percentage above 100. The sampler now bounds the result to physical RAM and handles a failed read.
3. **Medium — no glanceable detail.** The text menu exposed only one percentage. The new compact popover adds a short trend and used/available amounts without per-process polling.
4. **Medium — user-facing credit was inconsistent with the studio brand.** The interface, README and generated app metadata now say Pocket Giant. The bundle identifier stays unchanged so existing preferences and login registration continue to work.
5. **Low — theme followed only macOS.** System, Light and Dark are now persisted preferences.
6. **Low — menu controls lacked context and hierarchy.** Percentage, Status and percentage-only remain available, alongside restrained metric panels and a short explanation of the numbers.

The current icon is distinctive and consistent with the memory gauge, so it is retained. The app has no network calls or per-process scan. Its five-second sampling interval remains fixed to keep behaviour predictable and overhead small.

## Feature priorities

1. **Now:** a five-minute in-memory usage trend, basic memory amounts, saved appearance and optional alerts. These reuse the existing sampling call or inexpensive preferences.
2. **Later:** memory pressure if a supported, low-cost current-state API can be validated against Activity Monitor across macOS versions. Pressure is more actionable than raw percentage but must not be inferred from percentage alone.
3. **Later:** configurable refresh interval only if users need it. The current five-second interval is inexpensive and a setting would add complexity.
4. **Later:** swap and cached memory once the displayed definitions can be checked against macOS reporting across supported systems.
5. **Defer:** top-app rankings, persistent history and process-level notifications. They require more sampling, storage or permissions and would increase the utility's own resource use.

## Measurement and constraints

Used RAM is calculated from internal non-purgeable, wired and compressor pages. Available is physical RAM minus that measure. The percentage is therefore a physical-memory occupancy estimate, not a memory-pressure score or a prediction of when macOS will run out. The graph stores at most 60 Double values (five minutes at five-second intervals) and is discarded on quit.
