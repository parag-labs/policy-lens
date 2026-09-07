import 'package:flutter_test/flutter_test.dart';
import 'package:policy_lens/core/policy.dart';
import 'package:policy_lens/core/samples.dart';

void main() {
  group('policy matching', () {
    test('null filters mean "any"', () {
      const p = Policy(
          id: 'p', description: 'any', decision: Decision.warn);
      const a = AgentAction(
          agent: 'x',
          capability: Capability.readData,
          scope: DataScope.photos,
          tick: 1);
      expect(p.matches(a), isTrue);
    });

    test('capability and scope both must match', () {
      const p = Policy(
          id: 'p',
          description: 'send contacts',
          capability: Capability.sendData,
          scope: DataScope.contacts,
          decision: Decision.block);
      const send = AgentAction(
          agent: 'x',
          capability: Capability.sendData,
          scope: DataScope.contacts,
          tick: 1);
      const read = AgentAction(
          agent: 'x',
          capability: Capability.readData,
          scope: DataScope.contacts,
          tick: 1);
      expect(p.matches(send), isTrue);
      expect(p.matches(read), isFalse);
    });
  });

  group('evaluation', () {
    test('no matching policy → allowed with clear explanation', () {
      final e = PolicyEngine(const []);
      final v = e.evaluate(const AgentAction(
          agent: 'Local Calc',
          capability: Capability.takeAction,
          scope: DataScope.none,
          tick: 1));
      expect(v.decision, Decision.allow);
      expect(v.flagged, isFalse);
      expect(v.policyId, isNull);
      expect(v.explanation.contains('no policy'), isTrue);
    });

    test('block policy blocks and cites the rule', () {
      final e = PolicyEngine(demoPolicies);
      final v = e.evaluate(const AgentAction(
          agent: 'Sync',
          capability: Capability.sendData,
          scope: DataScope.contacts,
          tick: 1));
      expect(v.decision, Decision.block);
      expect(v.policyId, 'block-exfil-contacts');
      expect(v.explanation.contains('contacts'), isTrue);
    });

    test('warn policy warns', () {
      final e = PolicyEngine(demoPolicies);
      final v = e.evaluate(const AgentAction(
          agent: 'Travel',
          capability: Capability.readData,
          scope: DataScope.location,
          tick: 1));
      expect(v.decision, Decision.warn);
      expect(v.flagged, isTrue);
    });

    test('strictest policy wins when several match', () {
      final e = PolicyEngine(const [
        Policy(id: 'a', description: 'warn all reads',
            capability: Capability.readData, decision: Decision.warn),
        Policy(id: 'b', description: 'block reading health',
            capability: Capability.readData, scope: DataScope.health,
            decision: Decision.block),
      ]);
      final v = e.evaluate(const AgentAction(
          agent: 'x',
          capability: Capability.readData,
          scope: DataScope.health,
          tick: 1));
      expect(v.decision, Decision.block);
      expect(v.policyId, 'b');
    });
  });

  group('rate limiting', () {
    test('escalates only after the cap is exceeded within the window', () {
      final e = PolicyEngine(const [
        Policy(
            id: 'rl',
            description: 'max 3 message reads',
            capability: Capability.readData,
            scope: DataScope.messages,
            decision: Decision.allow,
            maxPerWindow: 3,
            windowTicks: 50),
      ]);
      Verdict read(int tick) => e.evaluate(AgentAction(
          agent: 'A',
          capability: Capability.readData,
          scope: DataScope.messages,
          tick: tick));
      expect(read(1).decision, Decision.allow);
      expect(read(2).decision, Decision.allow);
      expect(read(3).decision, Decision.allow);
      final fourth = read(4);
      expect(fourth.decision, Decision.warn);
      expect(fourth.rateLimited, isTrue);
    });

    test('window is per-agent and time-bounded', () {
      final e = PolicyEngine(const [
        Policy(
            id: 'rl',
            description: 'max 2',
            capability: Capability.readData,
            scope: DataScope.messages,
            decision: Decision.allow,
            maxPerWindow: 2,
            windowTicks: 10),
      ]);
      Verdict read(String agent, int tick) => e.evaluate(AgentAction(
          agent: agent,
          capability: Capability.readData,
          scope: DataScope.messages,
          tick: tick));
      read('A', 1);
      read('A', 2);
      expect(read('A', 3).rateLimited, isTrue);
      // a different agent is unaffected
      expect(read('B', 3).rateLimited, isFalse);
      // outside the window, the count resets
      expect(read('A', 100).rateLimited, isFalse);
    });
  });

  group('audit trail', () {
    test('every evaluation is recorded in order', () {
      final e = PolicyEngine(demoPolicies);
      e.evaluateAll(demoActions);
      expect(e.audit.length, demoActions.length);
      for (var i = 0; i < demoActions.length; i++) {
        expect(e.audit[i].action.tick, demoActions[i].tick);
      }
    });
  });

  group('demo scenario', () {
    test('demoEngine is deterministic and shows safe + flagged behavior', () {
      final a = demoEngine();
      final b = demoEngine();
      expect(a.audit.length, b.audit.length);
      expect(a.flaggedCount, b.flaggedCount);

      // contacts upload blocked
      final contacts = a.audit.firstWhere(
          (v) => v.action.scope == DataScope.contacts);
      expect(contacts.decision, Decision.block);

      // photo auto-upload blocked
      final photoSend = a.audit.firstWhere((v) =>
          v.action.scope == DataScope.photos &&
          v.action.capability == Capability.sendData);
      expect(photoSend.decision, Decision.block);

      // location read warned
      final loc =
          a.audit.firstWhere((v) => v.action.scope == DataScope.location);
      expect(loc.decision, Decision.warn);

      // 4th message read within window is rate-limited
      final rl = a.audit.where((v) => v.rateLimited).toList();
      expect(rl.length, 1);
      expect(rl.first.action.tick, 7);

      // at least one plainly-allowed action (the first message read)
      expect(a.audit.any((v) => v.decision == Decision.allow), isTrue);
      expect(a.flaggedCount, 4); // 2 block + 1 warn + 1 rate-limit warn
    });
  });
}
