import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/ad_provider.dart';
import '../services/ad_service.dart';

class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (_isDisposed) return;
    if (!AdService.isInitialized) {
      // Retry after a delay if SDK not ready yet
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isDisposed && mounted) _loadAd();
      });
      return;
    }

    _bannerAd = AdService.createBannerAd(
      onLoaded: () {
        if (mounted && !_isDisposed) {
          setState(() => _isLoaded = true);
        }
      },
      onFailed: () {
        if (mounted && !_isDisposed) {
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
          // Retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted && !_isDisposed) _loadAd();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adState = ref.watch(adProvider);

    // Don't show ads if user is ad-free
    if (adState.isAdFree) {
      return const SizedBox.shrink();
    }

    // Only show when fully loaded
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}