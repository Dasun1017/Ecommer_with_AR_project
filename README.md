# E-Commerce AR Shopping App 2

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
├── features/         # Feature-based modules
├── models/           # Data models
├── screens/          # UI screens
├── services/         # Business logic and API calls
├── utils/            # Utilities and helpers
├── auth_wrapper.dart # Authentication state wrapper
├── firebase_options.dart
└── main.dart
scripts/
└── populate_db.py    # Database population script
```

## Setup Instructions

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code
- Firebase account
- Python 3.x (for database population script)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Ecommer_with_AR_project_2
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - You can use the FlutterFire CLI for easy configuration:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```
   - Alternatively, download `google-services.json` for Android and place it in `android/app/`
   - Download `GoogleService-Info.plist` for iOS and place it in `ios/Runner/`

4. **Enable Firebase Services**
   - Authentication (Email/Password, Google)
   - Cloud Firestore
   - Firebase Storage

5. **Populate the Database (Optional but recommended for testing)**
   To use the provided product mock data:
   - Go to your Firebase Console -> Project Settings -> Service Accounts.
   - Click "Generate new private key" to download your service account JSON file.
   - Save the file as `serviceAccountKey.json` in the root of the project.
   - Create a virtual environment, install the required Python packages, and run the populate script:
     ```bash
     python3 -m venv venv
     source venv/bin/activate  # On Windows, use `venv\Scripts\activate`
     pip install firebase-admin
     python3 scripts/populate_db.py --service-account serviceAccountKey.json
     ```

6. **Run the app**
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