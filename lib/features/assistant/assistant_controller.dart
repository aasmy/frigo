import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/entitlement_repository.dart';
import '../../core/providers/service_providers.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../core/repositories/recipe_repository.dart';
import '../../core/repositories/shopping_repository.dart';
import '../../core/services/ai/ai_health.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.pending = false,
    this.failed = false,
    this.quotaBlocked = false,
  });

  final bool fromUser;
  final String text;
  final bool pending;
  final bool failed;

  /// Rendered with an upgrade affordance rather than as a failure.
  final bool quotaBlocked;
}

/// The kitchen chat assistant. Builds a fresh context string from the current
/// inventory + preferences on every turn so answers reflect reality.
class AssistantController extends Notifier<List<ChatMessage>> {
  static const _greeting = ChatMessage(
    fromUser: false,
    text: "Hi — I'm Frigo. Ask me what to cook, what's expiring, what to buy, "
        "or anything about the food in your kitchen.",
  );

  static const suggestedPrompts = [
    'What can I cook tonight?',
    "What's expiring soon?",
    'What should I buy?',
    'Give me a 3-day dinner plan',
  ];

  @override
  List<ChatMessage> build() => const [_greeting];

  void reset() => state = const [_greeting];

  Future<void> send(String raw) async {
    final question = raw.trim();
    if (question.isEmpty) return;

    // The daily allowance is checked before the question is echoed, so a
    // blocked message does not leave a dangling turn in the transcript.
    if (!ref.read(entitlementProvider.notifier).consumeAssistantReply()) {
      state = [
        ...state,
        ChatMessage(fromUser: true, text: question),
        const ChatMessage(
          fromUser: false,
          quotaBlocked: true,
          text: "That's today's free replies. They reset tomorrow, or Frigo "
              'Pro makes them unlimited.',
        ),
      ];
      return;
    }

    state = [
      ...state,
      ChatMessage(fromUser: true, text: question),
      const ChatMessage(fromUser: false, text: '', pending: true),
    ];

    final client = ref.read(llmClientProvider);
    if (client == null) {
      _replaceLast(const ChatMessage(
        fromUser: false,
        failed: true,
        text: 'The AI assistant needs an AI provider. Pick one in Profile -> '
            'AI assistant to start chatting.',
      ));
      return;
    }

    try {
      // Everything between the greeting and the just-added question + pending.
      final prior = state.sublist(1, state.length - 2);
      final history = <Map<String, String>>[
        for (final m in prior.where((m) => !m.pending && !m.failed))
          {'role': m.fromUser ? 'user' : 'model', 'text': m.text},
      ];

      final reply = await client.generateText(
        prompt: question,
        systemInstruction: _system(_kitchenContext()),
        history: history,
        timeout: const Duration(seconds: 40),
      );
      AiHealth.instance.recordSuccess(AiTask.assistant);
      _replaceLast(ChatMessage(fromUser: false, text: reply));
    } catch (e) {
      AiHealth.instance.recordFailure(AiTask.assistant, e);
      _replaceLast(const ChatMessage(
        fromUser: false,
        failed: true,
        text: "I couldn't reach the assistant just now. Try again in a moment.",
      ));
    }
  }

  void _replaceLast(ChatMessage m) {
    if (state.isEmpty) return;
    state = [...state.sublist(0, state.length - 1), m];
  }

  String _system(String context) => '''
You are Frigo, a warm, practical kitchen assistant living inside a food-inventory
app. Keep answers short and useful (a few sentences or a tight list). When asked
what to cook, give 1–3 concrete ideas that mostly use what the user already has,
and say which key items are missing. Respect the user's diet and allergies.
Never invent inventory the user doesn't have. If the user has almost nothing,
say so and suggest what to buy.

CURRENT KITCHEN
$context''';

  String _kitchenContext() {
    final inv = ref.read(inventoryProvider);
    final prefs = ref.read(preferencesProvider);
    final shopping = ref.read(shoppingListProvider);
    final history = ref.read(recipeHistoryProvider);

    final b = StringBuffer();
    b.writeln('Diet: ${prefs.diet.label}. '
        'Avoids: ${prefs.excludedIngredients.isEmpty ? 'nothing' : prefs.excludedIngredients.join(', ')}. '
        'Max cooking time: ${prefs.maxCookingTime.label}.');
    if (inv.isEmpty) {
      b.writeln('Inventory: empty.');
    } else {
      b.writeln('Inventory (item — qty — freshness):');
      for (final i in inv.take(40)) {
        final days = i.daysUntilExpiration;
        final fresh = i.storageLocation.name == 'freezer'
            ? 'frozen'
            : days == null
                ? 'no date'
                : days < 0
                    ? 'past its best'
                    : days == 0
                        ? 'use today'
                        : '$days days left';
        b.writeln('- ${i.displayName} — ${i.quantityLabel} — $fresh');
      }
    }
    final need = shopping
        .where((e) => !e.completed)
        .map((e) => e.name)
        .toList();
    if (need.isNotEmpty) b.writeln('Shopping list: ${need.join(', ')}.');
    final cooked = history.take(5).map((e) => e.recipeName).toList();
    if (cooked.isNotEmpty) b.writeln('Recently cooked: ${cooked.join(', ')}.');
    return b.toString().trim();
  }
}

final assistantProvider =
    NotifierProvider<AssistantController, List<ChatMessage>>(
        AssistantController.new);
