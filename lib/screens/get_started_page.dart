import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// Mark onboarding as completed and navigate to home page
  Future<void> _completeOnboarding() async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('✅ GetStartedPage: Completing onboarding');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    
    // Verify it was saved
    final saved = prefs.getBool('hasSeenOnboarding') ?? false;
    debugPrint('   Flag saved successfully: $saved');
    debugPrint('═══════════════════════════════════════');
    
    if (mounted) {
      // Navigate to home page by removing all previous routes
      // This ensures a clean navigation state
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    }
  }

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Choose Products',
      description: 'This is the initial stage where a customer selects items from an online catalog or store',
      image: 'assets/images/onboarding1.png',
    ),
    OnboardingItem(
      title: 'Make Payment',
      description: 'After selection, the customer proceeds to the checkout and completes the payment for the chosen products.',
      image: 'assets/images/onboarding2.png',
    ),
    OnboardingItem(
      title: 'Get Your Order',
      description: 'Once payment is confirmed, the order is processed, shipped, and delivered to the customer, completing the transaction.',
      image: 'assets/images/onboarding3.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with page count and skip button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentPage + 1}/${_items.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_currentPage < _items.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(_items[index]);
                },
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenH = constraints.maxHeight;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustration — scales to 35% of available height
              SizedBox(
                height: (screenH * 0.35).clamp(160.0, 340.0),
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    item.image,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 100,
                            color: Colors.grey[400],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Spacer — 4% of screen height keeps proportion on all screens
              SizedBox(height: (screenH * 0.04).clamp(16.0, 56.0)),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Prev button (only show after first page)
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Text(
                'Prev',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            )
          else
            const SizedBox(width: 60), // Placeholder for alignment
          
          // Page indicators (centered)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _items.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 32 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index ? Colors.black : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          
          // Next/Get Started button
          TextButton(
            onPressed: () {
              if (_currentPage < _items.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                _completeOnboarding();
              }
            },
            child: Text(
              _currentPage < _items.length - 1 ? 'Next' : 'Get Started',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _currentPage == _items.length - 1 
                    ? Colors.pink.shade400 
                    : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String image;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.image,
  });
}
