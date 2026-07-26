import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/purchase_service.dart';

enum PricingOption { monthly, yearly, lifetime }

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onPurchaseComplete;
  final VoidCallback? onSkip;
  final bool showSkip;
  
  const PaywallScreen({
    super.key,
    this.onPurchaseComplete,
    this.onSkip,
    this.showSkip = true,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PricingOption _selectedOption = PricingOption.lifetime;
  bool _isLoading = false;
  bool _isLoadingPackages = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadPackages();
  }
  
  Future<void> _loadPackages() async {
    setState(() {
      _isLoadingPackages = true;
      _errorMessage = null;
    });
    try {
      final purchaseService = Provider.of<PurchaseService>(context, listen: false);
      final packages = await purchaseService.getOfferings();
      if (packages.isEmpty && mounted) {
        setState(() {
          _errorMessage = 'Purchases are unavailable right now. Please try again later.';
        });
      }
    } on PurchaseException catch (e) {
      if (mounted) setState(() => _errorMessage = e.userMessage);
    } catch (e) {
      debugPrint('Error loading packages: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load prices. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingPackages = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseService>(
      builder: (context, purchaseService, _) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  // Skip button - compact
                  if (widget.showSkip)
                    Align(
                      alignment: Alignment.topRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : (widget.onSkip ?? () => Navigator.of(context).pop()),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Maybe later'),
                      ),
                    ),
                  
                  // Compact header
                  _buildCompactHeader(context),
                  
                  const SizedBox(height: 12),
                  
                  // Features - centered in available space
                  Expanded(
                    child: Center(
                      child: _buildFeatures(context),
                    ),
                  ),
                  
                  // Error message
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(context),
                    const SizedBox(height: 8),
                  ],
                  
                  // Pricing cards - always visible
                  _buildPricingCards(context, purchaseService),
                  
                  const SizedBox(height: 12),
                  
                  // Purchase button - always visible
                  _buildPurchaseButton(context, purchaseService),
                  
                  const SizedBox(height: 8),
                  
                  // Footer row
                  _buildFooter(context, purchaseService),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildCompactHeader(BuildContext context) {
    return Column(
      children: [
        // Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.tertiary,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.workspace_premium, size: 32, color: Colors.white),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        
        const SizedBox(height: 16),
        
        // Text - centered
        Text(
          'Unlock Tiny Steps Pro',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Unlimited breakdowns & focus tools',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }
  
  Widget _buildFeatures(BuildContext context) {
    final features = [
      (icon: Icons.all_inclusive, text: 'Unlimited task & step breakdowns'),
      (icon: Icons.psychology, text: 'All 5 AI coaching styles'),
      (icon: Icons.music_note, text: 'All ambient sounds'),
    ];
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(feature.icon, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Text(feature.text, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 100 + index * 50)).slideY(begin: 0.1, end: 0);
      }).toList(),
    );
  }
  
  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPricingCards(BuildContext context, PurchaseService purchaseService) {
    final monthlyPrice = purchaseService.monthlyPackage != null
        ? purchaseService.getFormattedPrice(purchaseService.monthlyPackage!)
        : '—';
    
    final yearlyPrice = purchaseService.yearlyPackage != null
        ? purchaseService.getFormattedPrice(purchaseService.yearlyPackage!)
        : '—';
    
    final lifetimePrice = purchaseService.lifetimePackage != null
        ? purchaseService.getFormattedPrice(purchaseService.lifetimePackage!)
        : '—';
    
    final monthlyEquiv = purchaseService.getYearlyMonthlyEquivalent();
    
    return Column(
      children: [
        // Monthly & Yearly row
        IntrinsicHeight(
          child: Row(
          children: [
            Expanded(
              child: _CompactPricingCard(
                title: 'Monthly',
                price: monthlyPrice,
                period: '/mo',
                isSelected: _selectedOption == PricingOption.monthly,
                onTap: () => setState(() => _selectedOption = PricingOption.monthly),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactPricingCard(
                title: 'Yearly',
                price: yearlyPrice,
                period: '/yr',
                subtitle: monthlyEquiv != null ? '\$${monthlyEquiv.toStringAsFixed(2)}/mo' : null,
                isSelected: _selectedOption == PricingOption.yearly,
                onTap: () => setState(() => _selectedOption = PricingOption.yearly),
              ),
            ),
          ],
        ),
        ).animate().fadeIn(delay: 300.ms),
        
        const SizedBox(height: 8),
        
        // Lifetime - full width
        _CompactPricingCard(
          title: 'Lifetime',
          price: lifetimePrice,
          period: ' once',
          badge: '⭐ BEST VALUE',
          subtitle: 'Pay once, yours forever',
          isSelected: _selectedOption == PricingOption.lifetime,
          isHighlighted: true,
          onTap: () => setState(() => _selectedOption = PricingOption.lifetime),
        ).animate().fadeIn(delay: 350.ms),
      ],
    );
  }
  
  Widget _buildPurchaseButton(BuildContext context, PurchaseService purchaseService) {
    String buttonText;
    final hasSelectedPackage = switch (_selectedOption) {
      PricingOption.monthly => purchaseService.monthlyPackage != null,
      PricingOption.yearly => purchaseService.yearlyPackage != null,
      PricingOption.lifetime => purchaseService.lifetimePackage != null,
    };
    
    if (_isLoading) {
      buttonText = 'Processing...';
    } else if (_isLoadingPackages) {
      buttonText = 'Loading prices...';
    } else if (!hasSelectedPackage) {
      buttonText = 'Retry loading prices';
    } else {
      final price = switch (_selectedOption) {
        PricingOption.monthly => purchaseService.monthlyPackage != null
            ? purchaseService.getFormattedPrice(purchaseService.monthlyPackage!)
            : null,
        PricingOption.yearly => purchaseService.yearlyPackage != null
            ? purchaseService.getFormattedPrice(purchaseService.yearlyPackage!)
            : null,
        PricingOption.lifetime => purchaseService.lifetimePackage != null
            ? purchaseService.getFormattedPrice(purchaseService.lifetimePackage!)
            : null,
      };
      
      if (price == null) {
        buttonText = 'Loading prices...';
      } else {
        buttonText = switch (_selectedOption) {
          PricingOption.monthly => 'Subscribe Monthly — $price',
          PricingOption.yearly => 'Subscribe Yearly — $price',
          PricingOption.lifetime => 'Get Lifetime Access — $price',
        };
      }
    }
    
    // Billing info text
    final billingInfo = switch (_selectedOption) {
      PricingOption.monthly => 'Billed monthly. Cancel anytime.',
      PricingOption.yearly => 'Billed yearly. Cancel anytime.',
      PricingOption.lifetime => 'One-time purchase. Yours forever.',
    };
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading || _isLoadingPackages
                ? null
                : hasSelectedPackage
                    ? () => _purchase(purchaseService)
                    : _loadPackages,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(buttonText),
          ),
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 8),
        Text(
          billingInfo,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildFooter(BuildContext context, PurchaseService purchaseService) {
    return Column(
      children: [
        // Restore + privacy + terms row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _isLoading ? null : () => _restorePurchases(purchaseService),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Restore', style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(' • ', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: () => _openUrl('https://www.freeprivacypolicy.com/live/bece15e9-ea42-4925-a22b-9d0bae1bbfe3'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Privacy', style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(' • ', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: () => _openUrl('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Terms', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        Text(
          _selectedOption == PricingOption.lifetime
              ? 'One-time purchase. Yours forever.'
              : 'Cancel anytime. Auto-renews.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  Future<void> _purchase(PurchaseService purchaseService) async {
    final package = switch (_selectedOption) {
      PricingOption.monthly => purchaseService.monthlyPackage,
      PricingOption.yearly => purchaseService.yearlyPackage,
      PricingOption.lifetime => purchaseService.lifetimePackage,
    };
    
    if (package == null) {
      setState(() => _errorMessage = 'Not available. Try again later.');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final success = await purchaseService.purchasePackage(package);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedOption == PricingOption.lifetime
                ? 'Welcome to Pro — forever! 🎉'
                : 'Welcome to Pro! 🎉'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        widget.onPurchaseComplete?.call();
      }
    } on PurchaseException catch (e) {
      if (mounted) {
        if (e.type == PurchaseErrorType.userCancelled) {
          // Ignore
        } else if (e.type == PurchaseErrorType.alreadyPurchased) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already have Pro! 🎉'), backgroundColor: Colors.green),
          );
          widget.onPurchaseComplete?.call();
        } else {
          setState(() => _errorMessage = e.userMessage);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _restorePurchases(PurchaseService purchaseService) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final success = await purchaseService.restorePurchases();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restored! 🎉'), backgroundColor: Colors.green),
          );
          widget.onPurchaseComplete?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No purchases found')),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Restore failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _CompactPricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? subtitle;
  final String? badge;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;
  
  const _CompactPricingCard({
    required this.title,
    required this.price,
    required this.period,
    this.subtitle,
    this.badge,
    required this.isSelected,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            children: [
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
              
              const SizedBox(height: 2),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(period, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
              
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
