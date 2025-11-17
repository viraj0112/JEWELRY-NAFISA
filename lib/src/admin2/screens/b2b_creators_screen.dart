import 'package:flutter/material.dart';
import '../providers/creators_provider.dart';
import '../sections/creators_section.dart';
import 'package:provider/provider.dart';

class B2BCreatorsScreen extends StatelessWidget {
  const B2BCreatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreatorsProvider()..loadCreators(),
      child: const CreatorsSection(),
    );
  }
}
