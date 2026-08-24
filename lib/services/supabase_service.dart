import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://qosltemjcyyxnginkgui.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_yx9pQdqFmqYUR7MvbalFQw_4d-VNYuO';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
    );
  }

  static SupabaseClient get client {
    return Supabase.instance.client;
  }
}
