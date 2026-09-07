import 'package:flutter/material.dart';
import 'core/policy.dart';
import 'core/samples.dart';

void main() => runApp(const PolicyLensApp());

const _bg = Color(0xFF0C0F1A);
const _panel = Color(0xFF151A2B);
const _panel2 = Color(0xFF1C2440);
const _accent = Color(0xFF7C8CF8);
const _accentSoft = Color(0xFF2C315C);
const _allow = Color(0xFF3ECF8E);
const _warn = Color(0xFFF2B84B);
const _block = Color(0xFFE06C75);
const _muted = Color(0xFF8A93B0);
const _text = Color(0xFFEDF0FA);

class PolicyLensApp extends StatelessWidget {
  const PolicyLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PolicyLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(primary: _accent, surface: _panel),
      ),
      home: const GovernanceHome(),
    );
  }
}

class GovernanceHome extends StatefulWidget {
  const GovernanceHome({super.key});
  @override
  State<GovernanceHome> createState() => _GovernanceHomeState();
}

class _GovernanceHomeState extends State<GovernanceHome> {
  late PolicyEngine engine;
  int _revealed = 0; // how many actions are "observed" so far

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  void _rebuild() {
    engine = PolicyEngine(demoPolicies);
    engine.evaluateAll(demoActions.take(_revealed));
  }

  void _observeNext() {
    setState(() {
      if (_revealed < demoActions.length) _revealed++;
      _rebuild();
    });
  }

  void _reset() => setState(() {
        _revealed = 0;
        _rebuild();
      });

  void _observeAll() => setState(() {
        _revealed = demoActions.length;
        _rebuild();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryRow(),
                      const SizedBox(height: 16),
                      _controls(),
                      const SizedBox(height: 20),
                      _sectionLabel('Active policies'),
                      const SizedBox(height: 10),
                      ...demoPolicies.map(_policyChip),
                      const SizedBox(height: 20),
                      _sectionLabel('Audit trail'),
                      const SizedBox(height: 10),
                      _auditTrail(),
                      const SizedBox(height: 18),
                      _privacyNote(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_panel2, _bg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.policy_rounded,
                    color: _accent, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('PolicyLens',
                  style: TextStyle(
                      color: _text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded, color: _muted),
                tooltip: 'Reset',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Watch what your AI agents do — and govern it, on-device.',
            style: TextStyle(color: _muted, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow() {
    final observed = engine.audit.length;
    final flagged = engine.flaggedCount;
    return Row(
      children: [
        _stat('$observed', 'observed', _accent),
        const SizedBox(width: 10),
        _stat('${observed - flagged}', 'allowed', _allow),
        const SizedBox(width: 10),
        _stat('$flagged', 'flagged', _warn),
      ],
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final done = _revealed >= demoActions.length;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: done ? null : _observeNext,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _accentSoft,
              disabledForegroundColor: _muted,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(done ? 'All observed' : 'Observe next action'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: done ? null : _observeAll,
          style: OutlinedButton.styleFrom(
            foregroundColor: _text,
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          ),
          child: const Text('Run all'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String t) => Text(
        t.toUpperCase(),
        style: const TextStyle(
            color: _muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1),
      );

  Widget _policyChip(Policy p) {
    final color = _decisionColor(p.decision);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(_decisionLabel(p.decision),
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.isRateLimit
                  ? '${p.description} (limit ${p.maxPerWindow})'
                  : p.description,
              style: const TextStyle(color: _text, fontSize: 12.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditTrail() {
    final entries = engine.audit.reversed.toList();
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Text(
          'No agent activity observed yet. Tap “Observe next action” to watch '
          'PolicyLens evaluate each one.',
          style: TextStyle(color: _muted.withOpacity(0.9), fontSize: 12.8),
        ),
      );
    }
    return Column(children: entries.map(_auditCard).toList());
  }

  Widget _auditCard(Verdict v) {
    final color = _decisionColor(v.decision);
    final icon = switch (v.decision) {
      Decision.allow => Icons.check_circle_rounded,
      Decision.warn => Icons.warning_amber_rounded,
      Decision.block => Icons.block_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(v.action.agent,
                          style: const TextStyle(
                              color: _text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (v.rateLimited)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _warn.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('RATE LIMIT',
                            style: TextStyle(
                                color: _warn,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(v.explanation,
                    style: TextStyle(
                        color: _text.withOpacity(0.82),
                        fontSize: 12.3,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _decisionColor(Decision d) => switch (d) {
        Decision.allow => _allow,
        Decision.warn => _warn,
        Decision.block => _block,
      };

  String _decisionLabel(Decision d) => switch (d) {
        Decision.allow => 'ALLOW',
        Decision.warn => 'WARN',
        Decision.block => 'BLOCK',
      };

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _allow.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _allow.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, color: _allow, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Evaluation runs entirely on-device against policies you control. '
              'PolicyLens observes and explains — it never sends your activity '
              'anywhere.',
              style: TextStyle(
                  color: _text.withOpacity(0.85),
                  fontSize: 12,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
