import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient('https://dummy', 'dummy');
  int a = await supabase.from('table').count(CountOption.exact).eq('id', 1);
  int b = await supabase.from('table').select('id', const FetchOptions(count: CountOption.exact)).eq('id', 1);
}
