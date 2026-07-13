import 'dart:math';

/// Tipo de callback para o sistema PubSub do jsPDF.
typedef PubSubCallback = void Function(List<dynamic> args);

/// Sistema de Publish/Subscribe interno do jsPDF.
///
/// Usado para comunicação entre o core e os plugins/módulos.
/// Portado fielmente do JavaScript original.
class PubSub {
  final Map<String, Map<String, _Subscription>> _topics = {};
  final Random _rng = Random();

  /// Subscreve a um [topic] com um [callback].
  ///
  /// Se [once] for true, o callback é removido após a primeira execução.
  /// Retorna um token que pode ser usado para [unsubscribe].
  String subscribe(String topic, PubSubCallback callback, {bool once = false}) {
    if (topic.isEmpty) {
      throw ArgumentError(
        'Invalid arguments passed to PubSub.subscribe (jsPDF-module)',
      );
    }

    _topics.putIfAbsent(topic, () => {});

    final token = _rng.nextDouble().toRadixString(35);
    _topics[topic]![token] = _Subscription(callback, once);

    return token;
  }

  /// Remove a subscrição identificada por [token].
  /// Retorna true se encontrou e removeu, false caso contrário.
  bool unsubscribe(String token) {
    for (final topic in _topics.keys.toList()) {
      if (_topics[topic]!.containsKey(token)) {
        _topics[topic]!.remove(token);
        if (_topics[topic]!.isEmpty) {
          _topics.remove(topic);
        }
        return true;
      }
    }
    return false;
  }

  /// Publica um evento no [topic] com os [args] fornecidos.
  ///
  /// Todos os callbacks subscritos ao topic são executados.
  /// Callbacks marcados como "once" são removidos após execução.
  void publish(String topic, [List<dynamic>? args]) {
    if (!_topics.containsKey(topic)) return;

    final effectiveArgs = args ?? [];
    final tokensToRemove = <String>[];

    for (final entry in _topics[topic]!.entries) {
      try {
        entry.value.callback(effectiveArgs);
      } catch (ex) {
        // Silencia erros como no original — em produção pode logar
        print('jsPDF PubSub Error: $ex');
      }
      if (entry.value.once) {
        tokensToRemove.add(entry.key);
      }
    }

    for (final token in tokensToRemove) {
      unsubscribe(token);
    }
  }

  /// Retorna os tópicos ativos (para debug).
  Map<String, Map<String, _Subscription>> get topics =>
      Map.unmodifiable(_topics);
}

class _Subscription {
  final PubSubCallback callback;
  final bool once;

  const _Subscription(this.callback, this.once);
}

/// Extensão para num para suportar toRadixString em double.
extension _RadixDouble on double {
  String toRadixString(int radix) {
    return (this * 1e15).toInt().toRadixString(radix);
  }
}
