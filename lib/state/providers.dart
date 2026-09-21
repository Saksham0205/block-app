import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/block_rule.dart';
import '../models/installed_app.dart';
import '../services/native_bridge.dart';

const _rulesKey = 'block_rules_v1';

/// The list of block rules. Persisted locally and mirrored to the native
/// blocking service on every change.
class RulesNotifier extends AsyncNotifier<List<BlockRule>> {
  @override
  Future<List<BlockRule>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rulesKey);
    final rules = raw == null
        ? <BlockRule>[]
        : (jsonDecode(raw) as List)
            .map((e) => BlockRule.fromJson(e as Map<String, dynamic>))
            .toList();
    // Make sure the service has what we have, e.g. after an app update.
    unawaited(NativeBridge.instance.syncRules(rules));
    return rules;
  }

  Future<void> upsert(BlockRule rule) async {
    final current = [...?state.value];
    final index = current.indexWhere((r) => r.id == rule.id);
    if (index == -1) {
      current.insert(0, rule);
    } else {
      current[index] = rule;
    }
    await _save(current);
  }

  Future<void> toggle(String id, bool enabled) async {
    await _save([
      for (final r in [...?state.value])
        if (r.id == id) r.copyWith(enabled: enabled) else r,
    ]);
  }

  Future<void> remove(String id) async {
    await _save([...?state.value]..removeWhere((r) => r.id == id));
  }

  Future<void> _save(List<BlockRule> rules) async {
    state = AsyncData(rules);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _rulesKey, jsonEncode(rules.map((r) => r.toJson()).toList()));
    await NativeBridge.instance.syncRules(rules);
  }
}

final rulesProvider =
    AsyncNotifierProvider<RulesNotifier, List<BlockRule>>(RulesNotifier.new);

final installedAppsProvider = FutureProvider<List<InstalledApp>>(
  (ref) => NativeBridge.instance.getInstalledApps(),
);

/// Whether the accessibility service that does the actual blocking is on.
/// Call `ref.invalidate` when the app resumes to re-check.
final serviceEnabledProvider = FutureProvider<bool>(
  (ref) => NativeBridge.instance.isBlockingServiceEnabled(),
);
