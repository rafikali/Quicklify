import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/premium_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/plan.dart';
import '../plans_provider.dart';
import '../premium_provider.dart';

// WhatsApp contact for manual premium upgrades.
// Number is in international format without "+" (wa.me requirement).
const String _whatsappNumber = '9779867086525';
const String _whatsappDisplay = '+977 986-708-6525';
const Color _waGreen = Color(0xFF25D366);

// Luxury gold palette — reserved for the premium emblem + wordmark only.
// Anchored to D2AF26 with a tight shaded gradient for depth.
const Color _goldLight = Color(0xFFE5C24A);
const Color _gold = Color(0xFFD2AF26);
const Color _goldDeep = Color(0xFFA8881A);
const LinearGradient _goldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_goldLight, _gold, _goldDeep],
  stops: [0.0, 0.55, 1.0],
);

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Consumer<PremiumProvider>(
        builder: (context, premium, _) {
          return _PremiumContent(premium: premium);
        },
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Main scrollable content. Adapts CTA section based on auth + premium state.

class _PremiumContent extends StatefulWidget {
  final PremiumProvider premium;
  const _PremiumContent({required this.premium});

  @override
  State<_PremiumContent> createState() => _PremiumContentState();
}

class _PremiumContentState extends State<_PremiumContent>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtl;
  late final AnimationController _heroGlowCtl;
  bool _busy = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _entranceCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _heroGlowCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entranceCtl.dispose();
    _heroGlowCtl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final user = await widget.premium.signIn();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?',
            style: TextStyle(color: AppColors.textPrimary)),
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
            child:
                const Text('Sign out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.premium.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final premium = widget.premium;
    final isSignedIn = premium.isSignedIn;
    final isPremium = premium.isPremium;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _HeroSection(
              glow: _heroGlowCtl,
              entrance: _entranceCtl,
              isPremium: isPremium,
            ),
          ),
          SliverToBoxAdapter(
            child: _fadeSlideIn(
              child: const _BenefitsGrid(),
              start: 0.08,
            ),
          ),
          if (!isPremium)
            SliverToBoxAdapter(
              child: _fadeSlideIn(
                child: const _PlansSection(),
                start: 0.12,
              ),
            ),
          SliverToBoxAdapter(
            child: _fadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildCta(isSignedIn, isPremium),
              ),
              start: 0.16,
            ),
          ),
          if (isSignedIn) ...[
            SliverToBoxAdapter(
              child: _fadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _AccountCard(
                    user: premium.user!,
                    isPremium: isPremium,
                    onSignOut: _signOut,
                    onRefresh: _refresh,
                    refreshing: _refreshing,
                  ),
                ),
                start: 0.24,
              ),
            ),
            SliverToBoxAdapter(
              child: _fadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _DeviceList(uid: premium.user!.uid),
                ),
                start: 0.30,
              ),
            ),
          ],
          if (!isPremium)
            SliverToBoxAdapter(
              child: _fadeSlideIn(
                child: const _FaqSection(),
                start: 0.36,
              ),
            ),
          SliverToBoxAdapter(
            child: _fadeSlideIn(
              child: const _TrustFooter(),
              start: 0.42,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Widget _fadeSlideIn({required Widget child, required double start}) {
    return AnimatedBuilder(
      animation: _entranceCtl,
      builder: (context, _) {
        final t =
            Curves.easeOutCubic.transform(((_entranceCtl.value - start) / (1 - start)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildCta(bool isSignedIn, bool isPremium) {
    if (isPremium) return const _PremiumActiveCard();
    if (!isSignedIn) {
      return _SignInCta(busy: _busy, onPressed: _signIn);
    }
    return _WhatsAppUpgradeCard(email: widget.premium.user?.email ?? '');
  }
}

// --------------------------------------------------------------------------
// Hero — large premium emblem with glow + animated gradient backdrop.

class _HeroSection extends StatelessWidget {
  final Animation<double> glow;
  final Animation<double> entrance;
  final bool isPremium;
  const _HeroSection({
    required this.glow,
    required this.entrance,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          // Subtle animated gradient backdrop (cyan/purple — keeps depth).
          Positioned.fill(
            child: AnimatedBuilder(
              animation: glow,
              builder: (context, _) {
                return CustomPaint(
                  painter: _HeroGradientPainter(progress: glow.value),
                );
              },
            ),
          ),
          // Soft fade to background at the bottom.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.55),
                    AppColors.background,
                  ],
                  stops: const [0.55, 0.9, 1.0],
                ),
              ),
            ),
          ),
          // Centered emblem + wordmark.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: glow,
                    builder: (context, _) {
                      final pulse = 0.65 + glow.value * 0.35;
                      return Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _gold.withValues(alpha: 0.40 * pulse),
                              _goldDeep.withValues(alpha: 0.18 * pulse),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.35 * pulse),
                              blurRadius: 36 + glow.value * 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: ShaderMask(
                            shaderCallback: (rect) =>
                                _goldGradient.createShader(rect),
                            child: Icon(
                              isPremium
                                  ? Icons.verified_rounded
                                  : Icons.workspace_premium_rounded,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (rect) => _goldGradient.createShader(rect),
                    child: const Text(
                      'QUICKLIFY  PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.5,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Hairline divider in gold — luxury cue.
                  Container(
                    width: 56,
                    height: 1.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _gold.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPremium
                        ? 'Unlocked. Enjoy the full experience.'
                        : 'The complete Quicklify experience',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGradientPainter extends CustomPainter {
  final double progress;
  _HeroGradientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Two large soft radial blobs that drift with progress.
    final cx1 = size.width * (0.25 + 0.12 * math.sin(progress * math.pi));
    final cy1 = size.height * (0.35 + 0.05 * math.cos(progress * math.pi));
    final cx2 = size.width * (0.78 - 0.10 * math.sin(progress * math.pi));
    final cy2 = size.height * (0.55 + 0.08 * math.cos(progress * math.pi));

    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(cx1, cy1), radius: size.width * 0.55),
      );
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accent.withValues(alpha: 0.30),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(cx2, cy2), radius: size.width * 0.55),
      );

    // Base
    canvas.drawRect(rect, Paint()..color = AppColors.background);
    canvas.drawRect(rect, p1);
    canvas.drawRect(rect, p2);
  }

  @override
  bool shouldRepaint(covariant _HeroGradientPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --------------------------------------------------------------------------
// Benefits — 2x2 grid of premium perks.

class _BenefitsGrid extends StatelessWidget {
  const _BenefitsGrid();

  @override
  Widget build(BuildContext context) {
    final items = const [
      _Benefit(
        icon: Icons.block_rounded,
        title: 'Zero Ads',
        sub: 'No banners. No interstitials. Just downloads.',
        tint: AppColors.primary,
      ),
      _Benefit(
        icon: Icons.bolt_rounded,
        title: 'Priority Speed',
        sub: 'Faster routing to extraction servers.',
        tint: Color(0xFFFFB300),
      ),
      _Benefit(
        icon: Icons.devices_rounded,
        title: '3 Devices',
        sub: 'Sign in on phone, tablet & spare.',
        tint: AppColors.accent,
      ),
      _Benefit(
        icon: Icons.support_agent_rounded,
        title: 'Direct Support',
        sub: 'Talk to the developer on WhatsApp.',
        tint: _waGreen,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'WHAT YOU GET', icon: Icons.star_rounded),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: items.map((b) => _BenefitCard(benefit: b)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Benefit {
  final IconData icon;
  final String title;
  final String sub;
  final Color tint;
  const _Benefit({
    required this.icon,
    required this.title,
    required this.sub,
    required this.tint,
  });
}

class _BenefitCard extends StatelessWidget {
  final _Benefit benefit;
  const _BenefitCard({required this.benefit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            benefit.tint.withValues(alpha: 0.07),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: benefit.tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: benefit.tint.withValues(alpha: 0.32),
              ),
            ),
            child: Icon(benefit.icon, color: benefit.tint, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                benefit.sub,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Section header pill.

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 13),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.glassBorder,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// CTA: Sign-in card (anonymous).

class _SignInCta extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _SignInCta({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.accent.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Start with Google',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Step 1 of 2 — this links premium to your account so it survives reinstalls and works on up to 3 devices.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: busy ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Image.network(
                    'https://developers.google.com/identity/images/g-logo.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.login, size: 18, color: Colors.black87),
                  ),
            label: Text(
              busy ? 'Signing in…' : 'Continue with Google',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// CTA: Premium-active celebration card.

class _PremiumActiveCard extends StatelessWidget {
  const _PremiumActiveCard();

  @override
  Widget build(BuildContext context) {
    final expiresAt = PremiumService.instance.expiresAt;
    final subline = _buildSubline(expiresAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2418),
            Color(0xFF1F1A12),
          ],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.20),
            blurRadius: 26,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _goldGradient,
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium active',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subline,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildSubline(DateTime? expiresAt) {
    if (expiresAt == null) {
      return 'Lifetime access. Thanks for supporting Quicklify.';
    }
    // Server-anchored "now" — defeats device clock manipulation.
    final now = PremiumService.instance.serverNow();
    final daysLeft = expiresAt.difference(now).inDays;
    final dateStr =
        '${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}';
    if (daysLeft <= 0) {
      return 'Expires today ($dateStr). Renew soon to stay premium.';
    }
    if (daysLeft <= 7) {
      return 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'} ($dateStr). Renew soon to stay premium.';
    }
    return 'Active until $dateStr · $daysLeft days left.';
  }
}

// --------------------------------------------------------------------------
// Account card (signed-in).

class _AccountCard extends StatelessWidget {
  final User user;
  final bool isPremium;
  final VoidCallback onSignOut;
  final VoidCallback onRefresh;
  final bool refreshing;

  const _AccountCard({
    required this.user,
    required this.isPremium,
    required this.onSignOut,
    required this.onRefresh,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surface,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? const Icon(Icons.person_rounded,
                          color: AppColors.textSecondary)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName ?? user.email ?? 'User',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    color: Colors.white, size: 11),
                                SizedBox(width: 3),
                                Text('PRO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (user.email != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          user.email!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: refreshing ? null : onRefresh,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: refreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Sign out',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// WhatsApp upgrade card — shown to signed-in non-premium users.

class _WhatsAppUpgradeCard extends StatelessWidget {
  final String email;
  const _WhatsAppUpgradeCard({required this.email});

  Future<void> _openWhatsApp(BuildContext context, Plan? plan) async {
    final planLine = plan == null
        ? ''
        : 'Plan: ${plan.name} (${plan.priceLabel} for ${plan.durationLabel})\n';
    final body = 'Hi! I want to upgrade to Quicklify Premium.\n'
        '${planLine}My account email: $email\n'
        'Please activate premium for this email. Thanks!';
    final encoded = Uri.encodeComponent(body);

    // Try WhatsApp's native scheme first — opens the app directly with no
    // browser hop / disambiguation dialog. Falls back to wa.me if not installed.
    final nativeUri =
        Uri.parse('whatsapp://send?phone=$_whatsappNumber&text=$encoded');
    final webUri =
        Uri.parse('https://wa.me/$_whatsappNumber?text=$encoded');

    bool opened = false;
    try {
      opened = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      try {
        opened = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: _whatsappDisplay));
      Fluttertoast.showToast(
        msg: 'Could not open WhatsApp. Number copied: $_whatsappDisplay',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<PlansProvider>().selected;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _waGreen.withValues(alpha: 0.45)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _waGreen.withValues(alpha: 0.20),
            _waGreen.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _waGreen.withValues(alpha: 0.18),
            blurRadius: 28,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _waGreen.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _waGreen.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.chat_rounded,
                    color: _waGreen, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activate Premium',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Step 2 of 2',
                      style: TextStyle(
                        color: _waGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            selected == null
                ? 'Send us your account email on WhatsApp — we\'ll flip your switch within minutes.'
                : 'You\'re sending the ${selected.name} plan (${selected.priceLabel}) for the email below. We\'ll activate within minutes.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.alternate_email_rounded,
                    color: _waGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email.isEmpty ? '(no email on account)' : email,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: email.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: email));
                          Fluttertoast.showToast(msg: 'Email copied');
                        },
                  icon: const Icon(Icons.copy_rounded,
                      color: AppColors.textSecondary, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openWhatsApp(context, selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: _waGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: Text(
                selected == null
                    ? 'Chat on WhatsApp'
                    : 'Chat on WhatsApp · ${selected.priceLabel}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _whatsappDisplay,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Plans section — 3 selectable plan cards sourced from PlansProvider.

class _PlansSection extends StatelessWidget {
  const _PlansSection();

  @override
  Widget build(BuildContext context) {
    final plansProvider = context.watch<PlansProvider>();
    final plans = plansProvider.plans;
    final selectedId = plansProvider.selected?.id;

    if (plans.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              label: 'CHOOSE YOUR PLAN', icon: Icons.local_offer_rounded),
          const SizedBox(height: 10),
          // IntrinsicHeight gives the row a bounded height (= tallest child)
          // so CrossAxisAlignment.stretch can equalize the card heights.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < plans.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _PlanCard(
                      plan: plans[i],
                      selected: plans[i].id == selectedId,
                      onTap: () => plansProvider.select(plans[i].id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        selected ? _gold : AppColors.glassBorder;
    final List<BoxShadow> shadow = selected
        ? [
            BoxShadow(
              color: _gold.withValues(alpha: 0.32),
              blurRadius: 18,
              spreadRadius: -3,
            ),
          ]
        : const [];
    final perMonth = plan.perMonthInr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [
                      _gold.withValues(alpha: 0.18),
                      _gold.withValues(alpha: 0.04),
                    ]
                  : [
                      AppColors.card,
                      AppColors.card,
                    ],
            ),
            boxShadow: shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (plan.popular)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: _goldGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
              const SizedBox(height: 8),
              Text(
                plan.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    plan.currency,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${plan.priceInr}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                perMonth != null && plan.durationDays > 30
                    ? '≈ ${plan.currency} ${perMonth.toStringAsFixed(0)}/mo'
                    : 'per ${plan.durationLabel}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
              if (plan.tagline != null) ...[
                const SizedBox(height: 6),
                Text(
                  plan.tagline!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? _gold
                        : AppColors.textSecondary.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// FAQ — collapsible Q&A.

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  @override
  Widget build(BuildContext context) {
    final faqs = const [
      _Faq(
        q: 'Why WhatsApp instead of in-app payment?',
        a: 'We accept sideloaded distribution and manual activation keeps things simple. No store fees, no card details, no friction.',
      ),
      _Faq(
        q: 'How long does activation take?',
        a: 'Usually within minutes during waking hours. We\'ll reply on WhatsApp once it\'s done.',
      ),
      _Faq(
        q: 'Will my premium survive a reinstall?',
        a: 'Yes. Premium is tied to your Google account, not the install. Sign back in and you\'re premium again.',
      ),
      _Faq(
        q: 'Can I move it to another phone?',
        a: 'Yes — sign in on the new device. You can be active on up to 3 devices simultaneously; manage them on this screen.',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'COMMON QUESTIONS', icon: Icons.help_rounded),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.glassBorder),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: AppColors.glassBorder,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < faqs.length; i++) ...[
                      if (i > 0)
                        Container(
                            height: 1, color: AppColors.glassBorder),
                      _FaqTile(faq: faqs[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
}

class _FaqTile extends StatelessWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      iconColor: AppColors.primary,
      collapsedIconColor: AppColors.textSecondary,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        faq.q,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            faq.a,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Trust footer — small reassurance row.

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
          color: AppColors.card.withValues(alpha: 0.4),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded,
                color: AppColors.textSecondary, size: 13),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Secured by Google Sign-In. We never see your password.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            Icon(Icons.verified_user_rounded,
                color: _gold.withValues(alpha: 0.85), size: 13),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Device list — streams profiles/{uid}/devices.

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
          return const SizedBox.shrink();
        }
        if (snap.hasError) {
          return Text('Could not load devices: ${snap.error}',
              style: const TextStyle(color: AppColors.error, fontSize: 12));
        }
        final docs = snap.data?.docs ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
                label: 'YOUR DEVICES (${docs.length}/3)',
                icon: Icons.devices_rounded),
            const SizedBox(height: 12),
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

  Widget _deviceTile(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> d) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_android_rounded,
                color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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

  Future<void> _confirmRevoke(
      BuildContext context, String deviceId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
