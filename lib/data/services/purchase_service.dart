import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Error types for purchase operations
enum PurchaseErrorType {
  networkError,
  userCancelled,
  paymentDeclined,
  purchaseUnavailable,
  productNotFound,
  alreadyPurchased,
  unknown,
}

/// Exception for purchase errors
class PurchaseException implements Exception {
  final PurchaseErrorType type;
  final String message;
  
  PurchaseException(this.type, this.message);
  
  @override
  String toString() => message;
  
  /// Human-readable error message for UI
  String get userMessage {
    switch (type) {
      case PurchaseErrorType.networkError:
        return 'Unable to connect. Please check your internet connection and try again.';
      case PurchaseErrorType.userCancelled:
        return 'Purchase cancelled.';
      case PurchaseErrorType.paymentDeclined:
        return 'Payment was declined. Please check your payment method and try again.';
      case PurchaseErrorType.purchaseUnavailable:
        return 'Purchases are unavailable on this device or account.';
      case PurchaseErrorType.productNotFound:
        return 'Product not available. Please try again later.';
      case PurchaseErrorType.alreadyPurchased:
        return 'You already have an active subscription!';
      case PurchaseErrorType.unknown:
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Service for managing in-app purchases via RevenueCat
class PurchaseService extends ChangeNotifier {
  // RevenueCat API keys
  // Public RevenueCat SDK keys; override per build with
  // --dart-define=REVENUECAT_ANDROID_KEY=... / REVENUECAT_IOS_KEY=...
  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: 'goog_AlilYWerPjIQtwOfMamxRVObQmx',
  );
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: 'appl_VVZzBmKhtHZJuvUwfgXgNAIqsgE',
  );
  
  // Entitlement ID configured in RevenueCat
  static const String _entitlementId = 'entl2de33d59e5';
  
  // Product identifiers (must match RevenueCat/Play Store)
  static const String productIdMonthly = 'tinysteps_pro_monthly';
  static const String productIdYearly = 'tinysteps_pro_yearly';
  static const String productIdLifetime = 'tinysteps_pro_lifetime';
  
  bool _isInitialized = false;
  bool _isConfigured = false;
  bool _isPremium = false;
  bool? _debugPremiumOverride;
  CustomerInfo? _customerInfo;
  List<Package> _availablePackages = [];
  
  bool get isInitialized => _isInitialized;
  bool get isConfigured => _isConfigured;
  bool get isPremium => _debugPremiumOverride ?? _isPremium;
  CustomerInfo? get customerInfo => _customerInfo;
  List<Package> get availablePackages => _availablePackages;

  /// Override entitlement state for the current debug session.
  void setDebugPremiumOverride(bool? value) {
    if (!kDebugMode) return;
    final wasPremium = isPremium;
    _debugPremiumOverride = value;
    if (wasPremium != isPremium) {
      notifyListeners();
    }
  }
  
  /// Initialize RevenueCat SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Determine platform and use appropriate API key
      final String apiKey;
      if (defaultTargetPlatform == TargetPlatform.iOS || 
          defaultTargetPlatform == TargetPlatform.macOS) {
        apiKey = _iosApiKey;
      } else {
        apiKey = _androidApiKey;
      }
      
      // Skip initialization if using placeholder key (for development)
      if (apiKey.startsWith('YOUR_')) {
        debugPrint('PurchaseService: Using placeholder API key, skipping SDK configuration');
        _isConfigured = false;
        _isInitialized = true;
        return;
      }
      
      // Configure RevenueCat
      await Purchases.configure(PurchasesConfiguration(apiKey));
      
      // Enable debug logs in debug mode
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      
      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      
      _isConfigured = true;
      
      // Get initial customer info, but don't hold app launch on a slow
      // network; the check keeps running and notifies listeners when done.
      await checkPremiumStatus()
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      
      _isInitialized = true;
      debugPrint('PurchaseService: Initialized successfully');
    } catch (e) {
      debugPrint('PurchaseService: Failed to initialize: $e');
      // Don't throw - allow app to function without purchases
      _isInitialized = true;
    }
  }
  
  /// Callback for customer info updates
  void _onCustomerInfoUpdated(CustomerInfo info) {
    _customerInfo = info;
    _updatePremiumStatus(info);
  }
  
  /// Update premium status based on customer info
  void _updatePremiumStatus(CustomerInfo info) {
    final entitlement = info.entitlements.active[_entitlementId];
    final wasPremium = isPremium;
    _isPremium = entitlement != null;
    
    if (wasPremium != isPremium) {
      debugPrint('PurchaseService: Premium status changed to $isPremium');
      notifyListeners();
    }
  }
  
  /// Check current premium status from RevenueCat
  Future<void> checkPremiumStatus() async {
    if (!_isConfigured) {
      debugPrint('PurchaseService: SDK not configured, skipping premium check');
      return;
    }
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(_customerInfo!);
    } catch (e) {
      debugPrint('PurchaseService: Error checking premium status: $e');
    }
  }
  
  /// Get available subscription packages from RevenueCat
  Future<List<Package>> getOfferings() async {
    if (!_isConfigured) {
      debugPrint('PurchaseService: SDK not configured, no offerings available');
      return [];
    }
    try {
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current == null) {
        debugPrint('PurchaseService: No current offering available');
        return [];
      }
      
      _availablePackages = offerings.current!.availablePackages;
      notifyListeners();
      
      return _availablePackages;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    } catch (e) {
      debugPrint('PurchaseService: Error getting offerings: $e');
      throw PurchaseException(
        PurchaseErrorType.unknown,
        'Failed to load subscription options',
      );
    }
  }
  
  /// Purchase a subscription package
  Future<bool> purchasePackage(Package package) async {
    if (!_isConfigured) {
      throw PurchaseException(
        PurchaseErrorType.unknown,
        'Purchases not configured',
      );
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _customerInfo = result.customerInfo;
      _updatePremiumStatus(result.customerInfo);
      
      return _isPremium;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    } catch (e) {
      debugPrint('PurchaseService: Error purchasing package: $e');
      throw PurchaseException(
        PurchaseErrorType.unknown,
        'Purchase failed: ${e.toString()}',
      );
    }
  }
  
  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    if (!_isConfigured) {
      throw PurchaseException(
        PurchaseErrorType.unknown,
        'Purchases not configured',
      );
    }
    try {
      final result = await Purchases.restorePurchases();
      _customerInfo = result;
      _updatePremiumStatus(result);
      
      return _isPremium;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    } catch (e) {
      debugPrint('PurchaseService: Error restoring purchases: $e');
      throw PurchaseException(
        PurchaseErrorType.unknown,
        'Restore failed: ${e.toString()}',
      );
    }
  }
  
  /// Handle RevenueCat platform exceptions
  PurchaseException _handlePlatformException(PlatformException e) {
    final errorCode = PurchasesErrorHelper.getErrorCode(e);
    
    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        return PurchaseException(
          PurchaseErrorType.userCancelled,
          'Purchase was cancelled',
        );
        
      case PurchasesErrorCode.networkError:
        return PurchaseException(
          PurchaseErrorType.networkError,
          'Network error occurred',
        );
        
      case PurchasesErrorCode.productAlreadyPurchasedError:
        // Not actually an error - user already has premium
        _isPremium = true;
        notifyListeners();
        return PurchaseException(
          PurchaseErrorType.alreadyPurchased,
          'You already have an active subscription',
        );
        
      case PurchasesErrorCode.paymentPendingError:
        return PurchaseException(
          PurchaseErrorType.paymentDeclined,
          'Payment is pending approval',
        );
        
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return PurchaseException(
          PurchaseErrorType.productNotFound,
          'Product not available',
        );
        
      case PurchasesErrorCode.purchaseNotAllowedError:
        return PurchaseException(
          PurchaseErrorType.purchaseUnavailable,
          'Purchases not allowed on this device',
        );
        
      default:
        debugPrint('PurchaseService: Unhandled error code: $errorCode');
        return PurchaseException(
          PurchaseErrorType.unknown,
          e.message ?? 'An error occurred',
        );
    }
  }
  
  /// Get the monthly package from available offerings
  Package? get monthlyPackage {
    try {
      return _availablePackages.firstWhere(
        (p) => p.packageType == PackageType.monthly,
      );
    } catch (_) {
      return null;
    }
  }
  
  /// Get the yearly package from available offerings
  Package? get yearlyPackage {
    try {
      return _availablePackages.firstWhere(
        (p) => p.packageType == PackageType.annual,
      );
    } catch (_) {
      return null;
    }
  }
  
  /// Get the lifetime package from available offerings
  Package? get lifetimePackage {
    try {
      return _availablePackages.firstWhere(
        (p) => p.packageType == PackageType.lifetime,
      );
    } catch (_) {
      return null;
    }
  }
  
  /// Get formatted price string for a package
  String getFormattedPrice(Package package) {
    return package.storeProduct.priceString;
  }
  
  /// Get price value for a package
  double getPrice(Package package) {
    return package.storeProduct.price;
  }
  
  /// Calculate yearly savings compared to monthly
  double? getYearlySavings() {
    final monthly = monthlyPackage;
    final yearly = yearlyPackage;
    
    if (monthly == null || yearly == null) return null;
    
    final yearlyMonthlyPrice = getPrice(monthly) * 12;
    final yearlyPrice = getPrice(yearly);
    
    return yearlyMonthlyPrice - yearlyPrice;
  }
  
  /// Get monthly equivalent price for yearly subscription
  double? getYearlyMonthlyEquivalent() {
    final yearly = yearlyPackage;
    if (yearly == null) return null;
    
    return getPrice(yearly) / 12;
  }
  
  /// Yearly plan price per month, formatted in the store's currency.
  String? getYearlyMonthlyEquivalentFormatted() {
    final yearly = yearlyPackage;
    if (yearly == null) return null;
    
    final product = yearly.storeProduct;
    final storeString = product.pricePerMonthString;
    if (storeString != null && storeString.isNotEmpty) return storeString;
    
    try {
      return NumberFormat.simpleCurrency(name: product.currencyCode)
          .format(product.price / 12);
    } catch (_) {
      return null;
    }
  }
  
  /// RevenueCat app user ID for this install, used to link the device to the
  /// backend so it can verify premium status server-side.
  Future<String?> getAppUserId() async {
    if (!_isConfigured) return null;
    try {
      return await Purchases.appUserID;
    } catch (e) {
      debugPrint('PurchaseService: Error getting app user ID: $e');
      return null;
    }
  }

  /// Set user ID for attribution (optional)
  Future<void> setUserId(String userId) async {
    if (!_isConfigured) return;
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      debugPrint('PurchaseService: Error setting user ID: $e');
    }
  }
  
  @override
  void dispose() {
    if (_isConfigured) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    super.dispose();
  }
}
