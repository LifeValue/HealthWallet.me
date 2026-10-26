/// How the on-device model is constrained when it writes its JSON output.
///
/// Read from the `aiOutputMode` pref (`SharedPrefsConstants.aiOutputMode`)
/// and passed to every extraction step like the other AI tuning prefs.
enum ExtractionOutputMode {
  /// A generic "JSON array of objects" GBNF grammar (`GbnfGrammars.jsonArray`).
  grammar,

  /// A flat per-phase JSON schema passed as llamadart `responseFormat`; the
  /// object output is mapped back to the `resourceType`-tagged maps.
  schema,

  /// [schema], preceded by an unconstrained draft call whose notes go into
  /// the constrained call's prompt.
  schemaDraft;

  /// Used when the pref is unset or holds an unknown value. `schema` by the
  /// rule set before measuring (spec-on-device-schema-structured-output):
  /// on the 24-document iOS-simulator text run, mean ΔF1(schema − grammar)
  /// was +0.038 [0.006, 0.072] and strict JSON 100% vs 95.8%; schemaDraft
  /// added +0.004 [−0.012, 0.020] over schema, so it is not the default.
  static const defaultMode = ExtractionOutputMode.schema;

  static ExtractionOutputMode fromPref(String? value) {
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return defaultMode;
  }

  /// Whether generations use a JSON schema instead of the legacy grammar.
  bool get usesSchema => this != grammar;
}
