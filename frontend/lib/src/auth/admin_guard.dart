import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';

/// Gates a route behind [UserRole.admin].
///
/// `/admin` used to render the console for any signed-in user: the router's
/// redirect only checked that a session existed, and nothing under `admin2/`
/// re-checked the role. This wraps the route so the console never paints for a
/// non-admin.
///
/// Deep-linking to `/admin` on web is a cold page load, so the profile may not
/// be in memory yet. We load it before deciding, and treat every non-admin
/// outcome the same way — including "the load failed, so we still don't know"
/// — because failing closed is the whole point of a guard.
class AdminGuard extends StatefulWidget {
  const AdminGuard({super.key, required this.child});

  final Widget child;

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  /// Whether a profile load has finished (successfully or not) since this
  /// guard mounted. Until it has, we show a spinner rather than a verdict:
  /// `userProfile == null` on its own can't distinguish "not loaded yet" from
  /// "loaded and denied".
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final provider = context.read<UserProfileProvider>();
    // main() only kicks off loadUserProfile() when a session already exists at
    // boot, so on a deep link the profile can legitimately still be null.
    if (provider.userProfile == null && !provider.isLoading) {
      await provider.loadUserProfile();
    }
    if (mounted) setState(() => _resolved = true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProfileProvider>();

    if (!_resolved || provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // loadUserProfile() nulls the profile on failure, and userRoleFromString()
    // maps anything unrecognised to `member`, so both error paths land here.
    if (provider.userProfile?.role != UserRole.admin) {
      return const _NotAuthorised();
    }

    return widget.child;
  }
}

class _NotAuthorised extends StatelessWidget {
  const _NotAuthorised();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                'Admin access required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                "You don't have permission to view this page.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => GoRouter.of(context).go('/home'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
