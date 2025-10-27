# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ZEET Rider App** - A Flutter mobile application for delivery riders (livreurs) of the ZEET food delivery platform. The app is written primarily in French and supports both iOS and Android platforms.

## Essential Commands

### Development
- `flutter run` - Run the app in development mode
- `flutter run -d ios` - Run on iOS simulator
- `flutter run -d android` - Run on Android emulator
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Upgrade dependencies

### Testing & Quality
- `flutter test` - Run all tests
- `flutter analyze` - Run static analysis (uses flutter_lints)
- `flutter clean` - Clean build artifacts

### Build
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app (requires Xcode)

## Architecture

### State Management

The app uses **Riverpod** for state management:
- All providers are in `lib/providers/`
- Key providers:
  - `themeModeProvider` - Manages light/dark/system theme mode with SharedPreferences persistence

### Navigation System

Custom navigation service (`lib/services/navigation_service.dart`) with:
- Global navigator key for navigation from anywhere
- Named routes defined in `Routes` class with route map
- Custom slide transitions (300ms easeInOut)
- Key navigation methods:
  - `Routes.navigateTo(routeName)` - Standard named route navigation
  - `Routes.push(widget)` - Custom page with animation
  - `Routes.pushReplacement(widget)` - Replace current screen with animation
  - `Routes.navigateAndReplace(routeName)` - Replace with named route
  - `Routes.pushAndRemoveAll(widget)` - Clear stack with animation
  - `Routes.navigateAndRemoveAll(routeName)` - Clear stack with named route
  - `Routes.goBack([result])` - Pop with optional result

Named routes available: `home`

### Project Structure

- **`lib/core/`** - Core utilities and shared components
  - `constants/` - App-wide constants (colors, sizes, themes, icons, assets, API, texts)
  - `widgets/` - Reusable widgets (popups, toasts)

- **`lib/models/`** - Data models
  - Models for rider-specific entities (deliveries, orders, locations, etc.)
  - Each model should have a `copyWith()` method for immutability
  - Use JSON serialization for API communication

- **`lib/screens/`** - Feature screens
  - Each screen is typically an `index.dart` file
  - May include separate `controllers.dart` for business logic
  - May include a `widgets/` subfolder for screen-specific widgets
  - Examples: delivery list, active delivery, navigation, history, profile, settings

- **`lib/providers/`** - Riverpod state notifiers and providers
  - Each provider file defines StateNotifierProvider and related computed providers
  - Examples: delivery provider, location provider, rider profile provider

- **`lib/services/`** - Application services
  - `navigation_service.dart` - Centralized navigation
  - Future services: API service, location service, notification service

- **`lib/data/`** - Data layer (optional)
  - Repository pattern for data access
  - API clients and data sources

### Theming

Material 3 theme system with:
- Light and dark themes defined in `lib/core/constants/themes.dart`
- Google Fonts: Poppins for headings, Inter for body text
- Theme follows system preference by default (persisted via SharedPreferences)
- Custom color scheme in `lib/core/constants/colors.dart`
- To check dark mode: `Theme.of(context).brightness == Brightness.dark`

### Responsive Sizing

`AppSizes()` singleton provides responsive dimensions:
- Must call `AppSizes().initialize(context)` before use (done in theme initialization)
- Methods:
  - `percentWidth(percent)` / `percentHeight(percent)` - Safe area percentages
  - `fullPercentWidth(percent)` / `fullPercentHeight(percent)` - Full screen percentages
  - `scaledFontSize(size)` - Font size scaled to screen width (375px baseline)
- Predefined sizes:
  - Font sizes: `h1`, `h2`, `h3`, `bodyLarge`, `bodyMedium`, `bodySmall`
  - Paddings: `paddingSmall`, `paddingMedium`, `paddingLarge`, `paddingXLarge`
  - Radii: `radiusSmall`, `radiusMedium`

### Screen Structure Pattern

Screens follow consistent patterns:
1. Consumer widgets (StatefulWidget/StatelessWidget) using `ConsumerState` or `ConsumerWidget`
2. Use `ref.watch()` to listen to providers, `ref.read()` for one-time reads
3. Initialize responsive layout via `AppSizes().initialize(context)` (if not using theme)
4. Dark mode support via `Theme.of(context).brightness`

## Key Configurations

### App Initialization
- Portrait orientation only (enforced in `main.dart`)
- Wrapped in `ProviderScope` for Riverpod
- Initial route: configurable via `MyApp(initialRoute:)` parameter
- Material 3 enabled

### Dependencies
- `flutter_riverpod` - State management
- `google_fonts` - Typography
- `shared_preferences` - Local storage for theme and settings
- `battery_plus` - Battery status
- `intl` - Internationalization and formatting
- `toastification` - Toast notifications (replaces SnackBars)
- SDK: Dart ^3.7.0

### Assets
Configured in `pubspec.yaml`:
- `assets/images/onboarding/`
- `assets/images/category/`
- `assets/images/wallet/`
- `assets/images/resto/`

## Development Notes

- The app is primarily in French (comments, UI text, route names)
- Custom icon system via `IconManager` in `lib/core/constants/icons.dart`
- Debug logging uses emoji prefixes (e.g., 🏍️ for rider, 📦 for delivery operations)
- All navigation should go through `Routes` service, not direct `Navigator` calls

### Icon Management - IMPORTANT

**CRITICAL:** Always verify that icons exist in `IconManager` before using them in any screen.

The app uses a custom icon system (`lib/core/constants/icons.dart`) that provides cross-platform icons for both Material (Android) and Cupertino (iOS).

#### Before Using Icons:

1. **Always check `lib/core/constants/icons.dart` first** to see if the icon you need exists in both `_materialIcons` and `_cupertinoIcons` maps
2. **If the icon doesn't exist:**
   - Add it to BOTH the Material icons map (`_materialIcons`) and Cupertino icons map (`_cupertinoIcons`)
   - Use appropriate Material icon from `Icons.*` class
   - Use appropriate Cupertino icon from `CupertinoIcons.*` class
   - Ensure both icons represent the same concept visually

3. **Usage in code:**
   ```dart
   // For Icon widget
   IconManager.getIcon('icon_name', color: Colors.red, size: 24)

   // For IconData (e.g., in BottomNavigationBarItem)
   IconManager.getIconData('icon_name')
   ```

#### Example: Adding a New Icon

```dart
// In _materialIcons map:
'send': Icons.send,

// In _cupertinoIcons map:
'send': CupertinoIcons.paperplane,
```

**Never use icons that don't exist in IconManager** - this will cause null pointer exceptions and app crashes.

### Toast Notifications

The app uses `toastification` package for displaying notifications (toasts) instead of traditional SnackBars.

**Location:** `lib/core/widgets/toastification.dart`

**Usage:**
```dart
// Import
import 'package:rider/core/widgets/toastification.dart';

// Show info toast (blue)
AppToast.showInfo(
  context: context,
  message: "Information message",
);

// Show success toast (green)
AppToast.showSuccess(
  context: context,
  message: "Success message",
);

// Show warning toast (orange)
AppToast.showWarning(
  context: context,
  message: "Warning message",
);

// Show error toast (red)
AppToast.showError(
  context: context,
  message: "Error message",
);
```

**Features:**
- Toasts appear at the **top center** of the screen
- Automatic dismissal after 4 seconds (configurable)
- Slide down animation with fade effect
- Support for dark/light themes
- Dismissible by dragging
- Optional callbacks on close

**Note:** The app is wrapped with `ToastificationWrapper` in `main.dart` to enable toast functionality.

## Development Workflow

### Creating a New Screen

1. Create a new folder in `lib/screens/` with the screen name
2. Add an `index.dart` file for the main screen widget
3. Optionally add `controllers.dart` for business logic
4. Optionally add a `widgets/` subfolder for screen-specific widgets
5. Add the route to `lib/services/navigation_service.dart`

Example:
```dart
// lib/screens/delivery_list/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeliveryListScreen extends ConsumerWidget {
  const DeliveryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Livraisons')),
      body: const Center(child: Text('Liste des livraisons')),
    );
  }
}

// Add to navigation_service.dart:
static const String deliveryList = '/delivery-list';
routes[deliveryList] = (context) => const DeliveryListScreen();
```

### Creating a New Model

1. Create a new file in `lib/models/` with the model name
2. Define the class with all properties
3. Add a `copyWith()` method for immutability
4. Add JSON serialization methods if needed

Example:
```dart
// lib/models/delivery_model.dart
class Delivery {
  final String id;
  final String customerName;
  final String address;
  final DeliveryStatus status;

  const Delivery({
    required this.id,
    required this.customerName,
    required this.address,
    required this.status,
  });

  Delivery copyWith({
    String? id,
    String? customerName,
    String? address,
    DeliveryStatus? status,
  }) {
    return Delivery(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      status: status ?? this.status,
    );
  }
}
```

### Creating a New Provider

1. Create a new file in `lib/providers/` with the provider name
2. Define the state notifier class
3. Export the provider

Example:
```dart
// lib/providers/delivery_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/delivery_model.dart';

final deliveryProvider = StateNotifierProvider<DeliveryNotifier, List<Delivery>>((ref) {
  return DeliveryNotifier();
});

class DeliveryNotifier extends StateNotifier<List<Delivery>> {
  DeliveryNotifier() : super([]);

  void addDelivery(Delivery delivery) {
    state = [...state, delivery];
  }

  void removeDelivery(String id) {
    state = state.where((d) => d.id != id).toList();
  }
}
```

## Next Steps

This is a base setup for the Rider app. The following needs to be implemented:

### Core Features
- **Authentication screens** (login, register, OTP verification)
- **Delivery management** (active delivery, delivery list, delivery details)
- **Navigation** (map integration, route guidance)
- **Profile & Settings** (rider profile, preferences, account settings)
- **Earnings** (earnings tracker, payment history)

### Models to Create
- `Delivery` - Delivery information
- `Order` - Order details
- `Location` - GPS coordinates and address
- `RiderProfile` - Rider information
- `Earnings` - Payment and earnings data

### Providers to Create
- `deliveryProvider` - Manage active and past deliveries
- `locationProvider` - Track rider location
- `riderProfileProvider` - Manage rider profile data
- `earningsProvider` - Track earnings and payments

### Services to Implement
- `api_service.dart` - HTTP client for API calls
- `location_service.dart` - GPS and location tracking
- `notification_service.dart` - Push notifications
