import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _gameId = '800366810';
  static const _placementId = 'Rewarded_Android';

  bool _isReady = false;
  bool _isInitialized = false;
  bool _isLoading = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await UnityAds.init(
      gameId: _gameId,
      testMode: false,
      onComplete: () {
        _isInitialized = true;
        _loadAd();
      },
      onFailed: (error, message) {
        debugPrint('Unity Ads initialization failed: $error, $message');
      },
    );
  }

  void _loadAd() {
    if (_isLoading || !_isInitialized) return;
    _isLoading = true;
    UnityAds.load(
      placementId: _placementId,
      onComplete: (_) {
        _isReady = true;
        _isLoading = false;
      },
      onFailed: (_, error, message) {
        _isReady = false;
        _isLoading = false;
        debugPrint('Unity Ads load failed: $error, $message');
      },
    );
  }

  bool get isReady => _isReady;

  Future<void> showAd({
    required VoidCallback onReward,
    VoidCallback? onFailure,
  }) async {
    if (!_isReady) {
      debugPrint('Unity Ads rewarded placement is not ready');
      onFailure?.call();
      return;
    }

    _isReady = false;
    await UnityAds.showVideoAd(
      placementId: _placementId,
      onComplete: (_) {
        onReward();
        _loadAd();
      },
      onSkipped: (_) {
        onFailure?.call();
        _loadAd();
      },
      onFailed: (_, error, message) {
        debugPrint('Unity Ads show failed: $error, $message');
        onFailure?.call();
        _loadAd();
      },
    );
  }
}
