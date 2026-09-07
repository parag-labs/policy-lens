/// PolicyLens — a personal, on-device AI governance layer.
///
/// This file is the deterministic core: a small policy engine that observes
/// what AI agents on the device try to do, evaluates each action against
/// user-defined policies, and returns an **allow / warn / block** decision with
/// a plain-language explanation. It has **no Flutter dependency**, so every rule
/// is unit-tested and reproducible; the UI only renders what the engine decides.
///
/// The observed "agents" here are simulated, but the shapes and the evaluation
/// order match what a real on-device hook layer would feed in.
library;

/// What an agent is trying to do.
enum Capability { readData, sendData, takeAction, accessSensor }

/// The kind of data or resource involved. [none] means the action touches no
/// sensitive scope (e.g. a purely local computation).
enum DataScope { contacts, location, photos, health, messages, none }

/// The outcome of evaluating an action. Ordered by severity:
/// [allow] < [warn] < [block].
enum Decision { allow, warn, block }

/// An observed attempt by an on-device AI agent to do something.
class AgentAction {
  final String agent;
  final Capability capability;
  final DataScope scope;
  final int tick; // logical time, used for rate-limit windows
  final String detail;

  const AgentAction({
    required this.agent,
    required this.capability,
    required this.scope,
    required this.tick,
    this.detail = '',
  });
}

/// A user-defined governance rule.
///
/// A policy *matches* an action when its (optional) [capability] and [scope]
/// filters both match — a null filter means "any". A matching policy yields its
/// [decision]. If [maxPerWindow] is set, the policy also escalates to its
/// decision once an agent exceeds that many matching actions within
/// [windowTicks] — a rate limit for otherwise-allowed behavior.
class Policy {
  final String id;
  final String description;
  final Capability? capability;
  final DataScope? scope;
  final Decision decision;
  final int? maxPerWindow;
  final int windowTicks;

  const Policy({
    required this.id,
    required this.description,
    this.capability,
    this.scope,
    required this.decision,
    this.maxPerWindow,
    this.windowTicks = 100,
  });

  bool matches(AgentAction a) {
    if (capability != null && capability != a.capability) return false;
    if (scope != null && scope != a.scope) return false;
    return true;
  }

  bool get isRateLimit => maxPerWindow != null;
}

/// The result of evaluating one action.
class Verdict {
  final AgentAction action;
  final Decision decision;
  final String explanation;
  final String? policyId;

  /// True when this verdict is a rate-limit escalation rather than the policy's
  /// base decision.
  final bool rateLimited;

  const Verdict({
    required this.action,
    required this.decision,
    required this.explanation,
    this.policyId,
    this.rateLimited = false,
  });

  bool get flagged => decision != Decision.allow;
}

/// The governance engine. Holds the active policy set and an append-only audit
/// trail, and evaluates each observed [AgentAction] deterministically.
///
/// Evaluation is **strictest-wins**: every matching policy is considered and the
/// most severe decision is chosen. With no matching policy the action is
/// allowed with a clear "no policy applies" explanation (this layer observes and
/// governs; it does not deny by default).
class PolicyEngine {
  final List<Policy> policies;
  final List<Verdict> _audit = [];

  PolicyEngine(this.policies);

  List<Verdict> get audit => List.unmodifiable(_audit);

  int get flaggedCount => _audit.where((v) => v.flagged).length;

  /// Evaluate [action], record the verdict in the audit trail, and return it.
  Verdict evaluate(AgentAction action) {
    Policy? winning;
    var best = Decision.allow;
    var rateLimited = false;

    for (final p in policies) {
      if (!p.matches(action)) continue;

      // Base decision from the policy.
      if (_moreSevere(p.decision, best)) {
        best = p.decision;
        winning = p;
        rateLimited = false;
      }

      // Rate-limit escalation: does this action push the agent over the cap?
      if (p.isRateLimit) {
        final priorInWindow = _audit.where((v) =>
            v.action.agent == action.agent &&
            p.matches(v.action) &&
            action.tick - v.action.tick < p.windowTicks).length;
        if (priorInWindow + 1 > p.maxPerWindow!) {
          final escalated =
              p.decision == Decision.allow ? Decision.warn : p.decision;
          if (_moreSevere(escalated, best)) {
            best = escalated;
            winning = p;
            rateLimited = true;
          }
        }
      }
    }

    final verdict = Verdict(
      action: action,
      decision: best,
      explanation: _explain(action, winning, best, rateLimited),
      policyId: winning?.id,
      rateLimited: rateLimited,
    );
    _audit.add(verdict);
    return verdict;
  }

  /// Evaluate a whole stream in order (each shares the same audit history).
  List<Verdict> evaluateAll(Iterable<AgentAction> actions) =>
      actions.map(evaluate).toList();

  static bool _moreSevere(Decision a, Decision b) => a.index > b.index;

  String _explain(
      AgentAction a, Policy? p, Decision d, bool rateLimited) {
    final who = a.agent;
    final what = _describeAction(a);
    if (p == null || d == Decision.allow) {
      return '$who $what — allowed; no policy restricts this.';
    }
    final verb = switch (d) {
      Decision.block => 'blocked',
      Decision.warn => 'flagged',
      Decision.allow => 'allowed',
    };
    if (rateLimited) {
      return '$who $what — $verb: exceeded ${p.maxPerWindow} allowed within the '
          'window (${p.description}).';
    }
    return '$who $what — $verb by policy: ${p.description}.';
  }

  String _describeAction(AgentAction a) {
    final verb = switch (a.capability) {
      Capability.readData => 'tried to read',
      Capability.sendData => 'tried to send',
      Capability.takeAction => 'tried to act on',
      Capability.accessSensor => 'tried to access',
    };
    final scope = switch (a.scope) {
      DataScope.contacts => 'your contacts',
      DataScope.location => 'your location',
      DataScope.photos => 'your photos',
      DataScope.health => 'your health data',
      DataScope.messages => 'your messages',
      DataScope.none => 'a local resource',
    };
    return '$verb $scope';
  }
}
