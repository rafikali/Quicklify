import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../../core/services/premium_service.dart';
import '../../../core/theme/app_colors.dart';
import '../premium_provider.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Premium', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Consumer<PremiumProvider>(
        builder: (context, premium, _) {
          if (!premium.isSignedIn) {
            return const _SignInPitch();
          }
          return _SignedInView(premium: premium);
        },
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Sign-in pitch (anonymous user)

class _SignInPitch extends StatefulWidget {
  const _SignInPitch();
  @override
  State<_SignInPitch> createState() => _SignInPitchState();
}

class _SignInPitchState extends State<_SignInPitch> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final premium = context.read<PremiumProvider>();
      final user = await premium.signIn();
      if (!mounted) return;
      if (user == null) {
        Fluttertoast.showToast(msg: 'Sign-in cancelled');
      } else {
        Fluttertoast.showToast(msg: 'Signed in as ${user.email}');
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.accent.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quicklify Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Remove all ads. Faster downloads. Support development.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            _benefit(Icons.block_rounded, 'No banner or interstitial ads'),
            const SizedBox(height: 8),
            _benefit(Icons.shield_rounded, 'Account secured by Google Sign-In'),
            const SizedBox(height: 8),
            _benefit(Icons.devices_rounded, 'Use on up to 3 devices'),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _busy ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Image.network(
                      'https://developers.google.com/identity/images/g-logo.png',
                      width: 18, height: 18,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.login, size: 18, color: Colors.black87),
                    ),
              label: Text(_busy ? 'Signing in…' : 'Continue with Google'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign-in is required to associate premium with your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Signed-in view (status + device list + sign out)

class _SignedInView extends StatefulWidget {
  final PremiumProvider premium;
  const _SignedInView({required this.premium});

  @override
  State<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends State<_SignedInView> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await widget.premium.refresh();
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Status refreshed');
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Refresh failed: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Premium will revert to free on this device until you sign back in.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.premium.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.premium.user!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _accountCard(user),
          const SizedBox(height: 20),
          _statusCard(widget.premium.isPremium),
          const SizedBox(height: 20),
          _DeviceList(uid: user.uid),
          const SizedBox(height: 28),
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text('Sign out',
                style: TextStyle(color: AppColors.error)),
          ),
          if (_refreshing) const SizedBox(height: 16),
          if (_refreshing) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _accountCard(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surface,
            backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null
                ? const Icon(Icons.person_rounded, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName ?? user.email ?? 'User',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    )),
                if (user.email != null)
                  Text(user.email!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isPremium
            ? LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.22),
                AppColors.accent.withValues(alpha: 0.12),
              ])
            : null,
        color: isPremium ? null : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPremium
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.star_rounded : Icons.lock_outline_rounded,
            color: isPremium ? AppColors.primary : AppColors.textSecondary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'Premium active' : 'Free tier',
                  style: TextStyle(
                    color: isPremium ? AppColors.primary : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? 'No ads. Pull down to refresh.'
                      : 'Ads enabled. Contact support to upgrade.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh status',
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Device list — streams the profiles/{uid}/devices subcollection.

class _DeviceList extends StatelessWidget {
  final String uid;
  const _DeviceList({required this.uid});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('profiles')
        .doc(uid)
        .collection('devices')
        .where('revokedAt', isNull: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('Could not load devices: ${snap.error}',
              style: const TextStyle(color: AppColors.error, fontSize: 12));
        }
        final docs = snap.data?.docs ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'DEVICES (${docs.length}/3)',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Text('No active devices',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ...docs.map((d) => _deviceTile(context, d)),
          ],
        );
      },
    );
  }

  Widget _deviceTile(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final name = (data['deviceName'] as String?) ?? 'Unknown device';
    final last = (data['lastSeenAt'] as Timestamp?)?.toDate();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
                if (last != null)
                  Text('Last active: ${_relative(last)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: () => _confirmRevoke(context, d.id, name),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRevoke(BuildContext context, String deviceId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove $name?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'That device will be signed out on its next refresh. You can sign in again from any device.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PremiumService.instance.revokeOwnDevice(deviceId);
      Fluttertoast.showToast(msg: 'Device removed');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Remove failed: $e');
    }
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
