# rive_trigger_repro

Minimal reproducer for a `ViewModelInstanceTrigger.trigger()` issue we are
seeing in `rive: ^0.14.6` / `rive_native: ^0.1.6`.

## Symptom

When `trigger()` is called shortly after the first `dataBind()`, the trigger
reaches the ViewModel layer (an `addListener` callback fires) but the State
Machine **never** runs the corresponding transition. The SM stays in `Idle`.
Re-firing `trigger()` repeatedly does not unblock the SM.

After ~1–2 s of unrelated ViewModel writes (e.g. periodically setting a
Number property from Dart to keep the SM ticking), the next `trigger()`
runs the transition correctly.

A Number-property edge (`0 → 1`) on a transition condition like `n > 0`
fires the transition reliably on the **first** write — so as a workaround
we have moved off Triggers in our production code.

## `.riv` file (`assets/repro.riv`)

This reproducer is wired up against the exact `.riv` we ship in
production. The constants in `lib/main.dart` reflect those names:

| Element              | Name           | Notes                                          |
|----------------------|----------------|------------------------------------------------|
| Artboard             | `Dice`         |                                                |
| State Machine        | `DiceAnimator` | bound to the artboard                          |
| Default state        | `Idle`         |                                                |
| Outgoing transition  | —              | `Idle → rise`, condition: trigger `triggerRoll`|
| ViewModel property   | `triggerRoll`  | type **Trigger**                               |

The destination state name (`rise`) is irrelevant to the bug — what
matters is whether any state change is logged after the `trigger()` call.
Adjust the three constants at the top of `_ReproScreenState` if you want
to point this at a smaller standalone `.riv`.

## Run

```sh
flutter pub get
flutter run            # tested on iOS Simulator
```

## Test flow

1. Start the app. **Nothing** fires automatically — the dice just sits
   in its idle pose.
2. Tap the **`trigger()`** FAB at the bottom-right (tap #1).
   Watch the console: `VM listener fired` is logged, but **no** state
   change follows. The dice does not animate.
3. Wait a second or two, then tap the FAB again (tap #2).
   The exact same line of code runs, on the exact same Trigger instance.
   This time the state machine responds with `state → rise` and the spin
   animation plays.

## Expected console output (bug NOT present)

```
state → Idle
state → sparkle_idle
--- firing go.trigger() (tap #1) ---
VM listener fired
state → rise                ← currently missing
state → spin_…
…
```

## Actual console output (bug present)

```
state → Idle
state → sparkle_idle

(... user taps FAB ...)

--- firing go.trigger() (tap #1) ---
VM listener fired
[no further state change — dice stays idle]

(... user waits a second, then taps the FAB again ...)

--- firing go.trigger() (tap #2) ---
VM listener fired
state → rise                ← same Trigger, same code path, now works
state → spin_…
…
```

The crucial point: tap #1 and tap #2 go through the **exact same
`go.trigger()` line** on the **same Trigger instance**. The only
difference is **when** they fire relative to the first `dataBind()`
call.

## Code

`lib/main.dart` is ~60 lines and self-contained. Names of the artboard /
state machine / trigger property are constants at the top of the file —
adjust them if your `.riv` uses different names.
