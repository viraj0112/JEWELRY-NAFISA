import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient('https://dummy', 'dummy');
  int a = await supabase.from('table').count(CountOption.exact).eq('id', 1);
  // The old FetchOptions API was removed in supabase_flutter v2; the
  // supported form is the .count() call above.
}
