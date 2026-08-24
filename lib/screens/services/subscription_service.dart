import 'package:flutter/foundation.dart';

import '../../services/supabase_service.dart';

class SubscriptionService {
  static final _client = SupabaseService.client;

  static Future<Map<String, dynamic>?> getSubscription() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final data = await _client
          .from('subscriptions')
          .select('''
            id,
            user_id,
            plan,
            status,
            provider,
            current_period_start,
            current_period_end
          ''')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return Map<String, dynamic>.from(data);
    } catch (error) {
      debugPrint('Erro ao carregar assinatura: $error');

      return null;
    }
  }

  static Future<bool> hasPaidPlan() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return false;
    }

    try {
      final result = await _client.rpc(
        'has_active_paid_plan',
        params: {'target_user_id': user.id},
      );

      return result == true;
    } catch (error) {
      debugPrint('Erro ao verificar plano pago: $error');

      return false;
    }
  }

  static Future<bool> isFreePlan() async {
    final subscription = await getSubscription();

    if (subscription == null) {
      return true;
    }

    return subscription['plan'] != 'paid';
  }

  static Future<String> getPlan() async {
    final subscription = await getSubscription();

    if (subscription == null) {
      return 'free';
    }

    return subscription['plan']?.toString() ?? 'free';
  }
}
