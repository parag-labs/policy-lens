import 'policy.dart';

/// Deterministic sample policies and a scripted stream of AI-agent activity for
/// the demo and tests. The scenario is fixed so the demo tells the same story
/// every run and deliberately shows both "safe" and "flagged" behavior.

/// A small, readable set of user-defined policies.
const demoPolicies = <Policy>[
  Policy(
    id: 'block-exfil-contacts',
    description: 'no agent may send your contacts off the device',
    capability: Capability.sendData,
    scope: DataScope.contacts,
    decision: Decision.block,
  ),
  Policy(
    id: 'warn-location',
    description: 'reading your location needs a heads-up',
    capability: Capability.readData,
    scope: DataScope.location,
    decision: Decision.warn,
  ),
  Policy(
    id: 'block-send-photos',
    description: 'photos never leave the device automatically',
    capability: Capability.sendData,
    scope: DataScope.photos,
    decision: Decision.block,
  ),
  Policy(
    id: 'rate-limit-messages',
    description: 'reading messages more than 3× in a short window is suspicious',
    capability: Capability.readData,
    scope: DataScope.messages,
    decision: Decision.allow,
    maxPerWindow: 3,
    windowTicks: 50,
  ),
];

/// A scripted stream of observed agent actions. Mixes clearly-safe actions with
/// a blocked exfiltration attempt, a location read (warned), and a burst of
/// message reads that trips the rate limit.
const demoActions = <AgentAction>[
  AgentAction(
      agent: 'Smart Reply',
      capability: Capability.readData,
      scope: DataScope.messages,
      tick: 1,
      detail: 'draft a reply'),
  AgentAction(
      agent: 'Photo Organizer',
      capability: Capability.readData,
      scope: DataScope.photos,
      tick: 2,
      detail: 'cluster by scene'),
  AgentAction(
      agent: 'Travel Helper',
      capability: Capability.readData,
      scope: DataScope.location,
      tick: 3,
      detail: 'estimate commute'),
  AgentAction(
      agent: 'Contacts Sync (3rd-party)',
      capability: Capability.sendData,
      scope: DataScope.contacts,
      tick: 4,
      detail: 'upload address book'),
  AgentAction(
      agent: 'Smart Reply',
      capability: Capability.readData,
      scope: DataScope.messages,
      tick: 5,
      detail: 'summarize thread'),
  AgentAction(
      agent: 'Smart Reply',
      capability: Capability.readData,
      scope: DataScope.messages,
      tick: 6,
      detail: 'summarize thread'),
  AgentAction(
      agent: 'Smart Reply',
      capability: Capability.readData,
      scope: DataScope.messages,
      tick: 7,
      detail: 'summarize thread'), // 4th read within window → rate limited
  AgentAction(
      agent: 'Backup Agent',
      capability: Capability.sendData,
      scope: DataScope.photos,
      tick: 8,
      detail: 'auto-upload album'),
];

/// Build the engine and run the scripted stream through it.
PolicyEngine demoEngine() {
  final engine = PolicyEngine(demoPolicies);
  engine.evaluateAll(demoActions);
  return engine;
}
