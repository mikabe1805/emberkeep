/// The small, per-save memory surface for the optional Steward encounter.
///
/// Story content owns validation of node and choice identifiers. This model
/// deliberately keeps unfamiliar string identifiers from newer story builds so
/// an older client does not erase a person's choices on its next save.
class StewardMemory {
  StewardMemory({
    this.discovered = false,
    this.completed = false,
    String? nodeId,
    Map<String, String>? choices,
  }) : nodeId = _boundedString(nodeId, maxLength: _maxNodeIdLength),
       choices = _boundedChoices(choices);

  static const _maxChoices = 64;
  static const _maxChoiceIdLength = 128;
  static const _maxChoiceValueLength = 512;
  static const _maxNodeIdLength = 256;

  bool discovered;
  bool completed;
  String? nodeId;
  final Map<String, String> choices;

  /// Clears only transient replay progress. Discovery and completion remain
  /// durable so replaying cannot revoke the encounter's one-time history.
  void resetReplay() {
    nodeId = null;
    choices.clear();
  }

  Map<String, dynamic> toJson() {
    final safeNodeId = _boundedString(nodeId, maxLength: _maxNodeIdLength);
    return {
      'discovered': discovered,
      'completed': completed,
      'nodeId': ?safeNodeId,
      'choices': _boundedChoices(choices),
    };
  }

  static StewardMemory fromJson(Object? raw) {
    if (raw is! Map) return StewardMemory();

    final choices = <String, String>{};
    final rawChoices = raw['choices'];
    if (rawChoices is Map) {
      for (final entry in rawChoices.entries.take(_maxChoices)) {
        final key = _boundedString(entry.key, maxLength: _maxChoiceIdLength);
        final value = _boundedString(
          entry.value,
          maxLength: _maxChoiceValueLength,
        );
        if (key != null && value != null) choices[key] = value;
      }
    }

    return StewardMemory(
      discovered: raw['discovered'] == true,
      completed: raw['completed'] == true,
      nodeId: _boundedString(raw['nodeId'], maxLength: _maxNodeIdLength),
      choices: choices,
    );
  }

  static String? _boundedString(Object? value, {required int maxLength}) {
    if (value is! String || value.isEmpty || value.length > maxLength) {
      return null;
    }
    return value;
  }

  static Map<String, String> _boundedChoices(Map<String, String>? source) {
    if (source == null) return <String, String>{};
    final choices = <String, String>{};
    for (final entry in source.entries.take(_maxChoices)) {
      final key = _boundedString(entry.key, maxLength: _maxChoiceIdLength);
      final value = _boundedString(
        entry.value,
        maxLength: _maxChoiceValueLength,
      );
      if (key != null && value != null) choices[key] = value;
    }
    return choices;
  }
}
