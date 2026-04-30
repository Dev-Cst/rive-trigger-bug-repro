// Minimal reproducer for: ViewModelInstanceTrigger.trigger() is silently
// dropped by the State Machine when invoked too soon after the first
// dataBind(). Subsequent invocations of the same trigger work correctly.
//
// How to reproduce:
//
//   1. Start the app. Nothing fires automatically — the dice sits idle.
//   2. Tap the [trigger()] FAB. Watch the console: the VM-side listener
//      fires, but no state change is logged. The dice does not animate.
//   3. Tap the FAB again (a second or two later). Same code, same Trigger
//      instance, same line of code. Now the SM responds: state changes
//      to "rise" and the spin animation plays.
//
// The VM-side listener confirms the trigger reaches the ViewModel layer
// on BOTH taps. The SM only consumes it on the second tap.

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiveNative.init();
  runApp(const MaterialApp(home: ReproScreen()));
}

class ReproScreen extends StatefulWidget {
  const ReproScreen({super.key});

  @override
  State<ReproScreen> createState() => _ReproScreenState();
}

class _ReproScreenState extends State<ReproScreen> {
  RiveWidgetController? _ctrl;
  ViewModelInstanceTrigger? _go;

  // Names below match our production `dice.riv`:
  //   Artboard:           "Dice"
  //   State Machine:      "DiceAnimator"
  //   ViewModel property: "triggerRoll"   (Trigger)
  //   Transition:         Idle → rise     condition: triggerRoll
  static const _artboardName = 'Dice';
  static const _stateMachineName = 'DiceAnimator';
  static const _triggerName = 'triggerRoll';

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final file = await File.asset('assets/repro.riv', riveFactory: Factory.rive);
    if (file == null) {
      debugPrint('Failed to load assets/repro.riv');
      return;
    }
    final ctrl = RiveWidgetController(
      file,
      artboardSelector: ArtboardSelector.byName(_artboardName),
      stateMachineSelector: StateMachineSelector.byName(_stateMachineName),
    );

    final vmi = ctrl.dataBind(DataBind.auto());
    final go = vmi.trigger(_triggerName);
    if (go == null) {
      debugPrint('Trigger "$_triggerName" not found on the ViewModel');
      return;
    }

    go.addListener((_) => debugPrint('VM listener fired'));

    // ignore: deprecated_member_use, invalid_use_of_internal_member, unused_result
    ctrl.stateMachine.onStateChanged((s) => debugPrint('state → $s'));

    setState(() {
      _ctrl = ctrl;
      _go = go;
    });
  }

  int _tapCount = 0;

  void _fire() {
    if (_go == null) return;
    _tapCount++;
    debugPrint('--- firing go.trigger() (tap #$_tapCount) ---');
    _go!.trigger();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rive Trigger Repro')),
      body: Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: _ctrl == null
              ? const CircularProgressIndicator()
              : RiveWidget(controller: _ctrl!, fit: Fit.contain),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ctrl == null ? null : _fire,
        icon: const Icon(Icons.play_arrow),
        label: const Text('trigger()'),
      ),
    );
  }
}
