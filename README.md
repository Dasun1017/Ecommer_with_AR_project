# E-Commerce AR Shopping App

A modern mobile e-commerce application built with Flutter and Firebase, featuring Augmented Reality (AR) product visualization.

## Features

- 🛍️ **Browse Products**: View products by categories with advanced filtering
- 🔍 **Search**: Search products by name
- 📱 **AR View**: Visualize products in your space using AR technology
- 🛒 **Shopping Cart**: Add, remove, and manage cart items
- 💳 **Checkout**: Complete purchase with multiple payment options
- 📦 **Order Tracking**: Track your orders in real-time
- 🔔 **Notifications**: Get updates about orders and promotions
- 👤 **User Profile**: Manage account and view order history
- 🔐 **Authentication**: Secure login and signup with Firebase

## Tech Stack

- **Frontend**: Flutter/Dart
- **Backend**: Firebase
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Storage
  - Firebase Cloud Messaging
- **AR**: ARCore Flutter Plugin
- **State Management**: Provider & GetX

## Project Structure

```
lib/
├── models/           # Data models
├── screens/          # UI screens
├── services/         # Business logic and API calls
├── utils/            # Utilities and helpers
├── firebase_options.dart
└── main.dart
```

## Setup Instructions

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code
- Firebase account

### Installation

1. **Clone the repository**
   ```bash
   cd "d:\final project\Test 02\Ecommer_with_AR_project"
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Download `google-services.json` for Android and place it in `android/app/`
   - Download `GoogleService-Info.plist` for iOS and place it in `ios/Runner/`
   - Update `lib/firebase_options.dart` with your Firebase configuration

4. **Enable Firebase Services**
   - Authentication (Email/Password, Google)
   - Cloud Firestore
   - Firebase Storage
   - Cloud Messaging

5. **Run the app**
   ```bash
   flutter run
   ```

## Screens

1. **Get Started**: Onboarding screen with app introduction
2. **Login/Signup**: User authentication
3. **Home**: Featured products and categories
4. **Shop**: Browse all products with filters
5. **Products**: Category-specific product listing
6. **Product Details**: Detailed product view with AR option
7. **Cart**: Shopping cart management
8. **Checkout**: Order placement and payment
9. **Profile**: User account management
10. **Notifications**: Order updates and promotions

## Firebase Collections Structure

### users
```json
{
  "id": "string",
  "email": "string",
  "name": "string",
  "phoneNumber": "string",
  "photoUrl": "string",
  "address": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### products
```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "price": "number",
  "category": "string",
  "images": ["array"],
  "arModelUrl": "string",
  "stock": "number",
  "rating": "number",
  "reviewCount": "number",
  "colors": ["array"],
  "sizes": ["array"],
  "isFeatured": "boolean",
  "createdAt": "timestamp"
}
```

### orders
```json
{
  "id": "string",
  "userId": "string",
  "items": ["array"],
  "totalAmount": "number",
  "status": "string",
  "shippingAddress": "string",
  "paymentMethod": "string",
  "createdAt": "timestamp",
  "deliveredAt": "timestamp"
}
```

## Future Enhancements

- [ ] Wishlist functionality
- [ ] Product reviews and ratings
- [ ] Social media authentication
- [ ] Real-time order tracking
- [ ] Push notifications
- [ ] Payment gateway integration
- [ ] Multi-language support
- [ ] Dark mode

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

## Support

For support, email your-email@example.com or create an issue in the repository.