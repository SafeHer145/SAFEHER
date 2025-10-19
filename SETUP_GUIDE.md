# SafeHer - Complete Setup Guide

## 🎯 Project Overview

SafeHer is a production-ready women's safety mobile app built with Flutter, Firebase, and modern SMS integration. The app provides emergency SOS functionality with location-based alerts, contact management, and comprehensive safety features.

## ✨ Key Features Implemented

### 🔐 Authentication System
- **Dual Authentication**: Phone OTP (Firebase Auth) + Email/Password login
- **Country Code Picker**: Default +91 for Indian users
- **6-digit OTP Verification**: Using Pinput widget with modern UI
- **Automatic User Registration**: For new phone numbers
- **Profile Management**: Edit name, email, phone with real-time updates

### 🚨 Emergency SOS System
- **Large Animated SOS Button**: 200x200px with pulsing animation
- **GPS Location Capture**: Under 5 seconds as per SRS requirements
- **SMS Emergency Alerts**: Sent to all verified contacts with Google Maps links
- **Offline SMS Delivery**: Using url_launcher for native SMS app integration
- **Alert History**: Complete log of all SOS alerts with timestamps and locations

### 👥 Contact Management
- **Emergency Contacts**: Add up to 5 contacts with verification
- **SMS Verification**: OTP-based contact verification system
- **Contact CRUD**: Add, edit, delete, and verify contacts
- **Real-time Status**: Shows verification status for each contact
- **Relationship Tracking**: Family, Friend, Colleague, Other categories

### 🎨 Modern UI/UX
- **Material 3 Design**: Custom pink theme with modern components
- **Google Fonts**: Poppins typography throughout
- **Smooth Animations**: Using animate_do package
- **Responsive Design**: Works on all screen sizes
- **Tutorial Carousel**: First-time user onboarding

### 📱 Technical Implementation
- **Firebase Integration**: Auth, Firestore, real-time data
- **Location Services**: Geolocator with permission handling
- **SMS Services**: url_launcher for reliable SMS delivery
- **Offline Support**: Works without internet for core features
- **Error Handling**: Comprehensive error management and user feedback

## 🛠️ Setup Instructions

### Prerequisites
- Flutter SDK (3.9.0+)
- Android Studio / VS Code
- Firebase Project
- Android device/emulator for testing

### 1. Clone and Setup Project
```bash
git clone <repository-url>
cd SafeHer/safeher
flutter pub 
get
```

### 2. Firebase Configuration

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project: `safeher-g546`
3. Enable Authentication and Firestore

#### Configure Authentication
1. **Enable Phone Authentication**:
   - Go to Authentication > Sign-in method
   - Enable Phone provider
   - Add test phone numbers if needed for development

2. **Enable Email/Password**:
   - Enable Email/Password provider in Firebase Console

#### Configure Firestore
1. **Create Database**:
   - Go to Firestore Database
   - Create in production mode
   - Choose appropriate region

2. **Security Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /contacts/{contactId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /alerts/{alertId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

#### Android Configuration
1. **Add SHA-1 Fingerprint**:
```bash
# Debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Add the SHA-1 to Firebase project settings
```

2. **Download google-services.json**:
   - Place in `android/app/` directory

### 3. Update Firebase Options
Replace the dummy values in `lib/firebase_options.dart` with your actual Firebase project configuration:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ANDROID_API_KEY',
  appId: 'YOUR_ANDROID_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId: 'your-project-id',
  storageBucket: 'your-project-id.appspot.com',
);
```

### 4. Android Permissions
The app requires these permissions (already configured in AndroidManifest.xml):
- `ACCESS_FINE_LOCATION` - For GPS location
- `ACCESS_COARSE_LOCATION` - For approximate location
- `SEND_SMS` - For SMS functionality
- `READ_PHONE_STATE` - For phone operations
- `VIBRATE` - For haptic feedback
- `WAKE_LOCK` - For keeping screen on during emergency

### 5. Build and Run
```bash
flutter clean
flutter pub get
flutter run
```

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── theme/
│   └── app_theme.dart                # Material 3 theme
├── screens/
│   ├── onboarding/
│   │   └── tutorial_screen.dart      # First-time tutorial
│   ├── auth/
│   │   ├── auth_wrapper.dart         # Auth state management
│   │   ├── auth_choice_page.dart     # Login method selection
│   │   ├── login_page.dart           # Email login
│   │   └── otp_login_page.dart       # Phone OTP login
│   ├── dashboard/
│   │   └── dashboard_screen.dart     # Main dashboard with SOS
│   ├── contacts/
│   │   ├── contacts_screen.dart      # Contact management
│   │   └── add_contact_screen.dart   # Add/edit contacts
│   ├── alerts/
│   │   └── alerts_history_screen.dart # SOS history viewer
│   └── profile/
│       └── profile_screen.dart       # User profile management
├── services/
│   ├── auth_service.dart             # Firebase authentication
│   ├── sms_service_simple.dart      # SMS functionality
│   └── location_service.dart         # GPS location services
└── config/
    └── (optional config files)
```

## 🔧 Key Dependencies

```yaml
dependencies:
  # Core Flutter
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  
  # Firebase
  firebase_core: ^3.15.2
  firebase_auth: ^5.7.0
  cloud_firestore: ^5.6.12
  
  # Location & Permissions
  geolocator: ^14.0.2
  permission_handler: ^11.4.0
  
  # SMS & Communication
  url_launcher: ^6.3.1
  http: ^1.1.0
  
  # Authentication & OTP
  pinput: ^5.0.0
  country_picker: ^2.0.26
  
  # UI & Animations
  google_fonts: ^6.2.1
  animate_do: ^3.3.4
  lottie: ^3.1.2
  
  # Utilities
  shared_preferences: ^2.3.2
  intl: ^0.19.0
  material_color_utilities: ^0.11.1
```

## 🚀 Usage Guide

### For Users

#### First Time Setup
1. **Tutorial**: Complete the onboarding tutorial
2. **Authentication**: Choose phone OTP or email login
3. **Add Contacts**: Add up to 5 emergency contacts
4. **Verify Contacts**: Send verification SMS to contacts

#### Emergency Usage
1. **SOS Button**: Press the large red SOS button on dashboard
2. **Location Capture**: App automatically gets your location
3. **SMS Alerts**: Emergency SMS sent to all verified contacts
4. **History**: View all alerts in Alert History screen

#### Contact Management
1. **Add Contact**: Use + button to add new emergency contact
2. **Verify Contact**: Send verification SMS with OTP
3. **Edit/Delete**: Manage existing contacts
4. **Limit**: Maximum 5 contacts allowed

### For Developers

#### Adding New Features
1. **Services**: Add new services in `lib/services/`
2. **Screens**: Add new screens in appropriate `lib/screens/` subdirectory
3. **Navigation**: Update routing in main.dart or use direct navigation
4. **Database**: Add new Firestore collections following existing patterns

#### Customization
1. **Theme**: Modify `lib/theme/app_theme.dart` for UI changes
2. **Colors**: Update primary/secondary colors in theme
3. **Fonts**: Change Google Fonts in theme configuration
4. **SMS Messages**: Customize SMS templates in SMS service

## 🔒 Security Considerations

### Firebase Security
- **Authentication Required**: All Firestore operations require authentication
- **User Isolation**: Users can only access their own data
- **API Keys**: Keep Firebase API keys secure (they're client-safe)

### SMS Security
- **Verification Required**: Only verified contacts receive emergency alerts
- **OTP Validation**: Contact verification uses OTP system
- **Rate Limiting**: Firebase provides built-in rate limiting

### Location Privacy
- **Permission Based**: Location only accessed with user permission
- **Emergency Only**: Location shared only during SOS alerts
- **No Tracking**: App doesn't continuously track location

## 🐛 Troubleshooting

### Common Issues

#### Firebase Authentication
- **Phone Auth Not Working**: Ensure SHA-1 fingerprint is added to Firebase
- **Billing Required**: Enable billing for phone authentication in production
- **Test Numbers**: Use Firebase test phone numbers for development

#### SMS Issues
- **SMS Not Sending**: Check SMS permissions and device SMS app
- **url_launcher**: Ensure device has default SMS app configured
- **Contact Verification**: Verify contacts have valid phone numbers

#### Location Issues
- **Permission Denied**: Request location permission in app settings
- **GPS Timeout**: Ensure device has GPS enabled and good signal
- **Accuracy**: Location accuracy depends on device GPS capability

#### Build Issues
- **Gradle Errors**: Run `flutter clean` and `flutter pub get`
- **Plugin Conflicts**: Check for plugin version compatibility
- **Android SDK**: Ensure Android SDK and tools are updated

### Debug Commands
```bash
# Clean build
flutter clean
flutter pub get

# Check dependencies
flutter pub deps

# Run with verbose logging
flutter run --verbose

# Check device connectivity
flutter devices

# Analyze code
flutter analyze
```

## 📊 Performance Considerations

### Optimization Tips
1. **Firestore Queries**: Use indexed queries and pagination
2. **Image Assets**: Optimize images and use appropriate formats
3. **Memory Management**: Dispose controllers and streams properly
4. **Battery Usage**: Minimize location requests and background processing

### Monitoring
1. **Firebase Analytics**: Track user engagement and app performance
2. **Crashlytics**: Monitor app crashes and errors
3. **Performance**: Use Flutter DevTools for performance analysis

## 🔄 Future Enhancements

### Planned Features
1. **Multi-language Support**: Hindi, Telugu, other regional languages
2. **Voice Commands**: Voice-activated SOS
3. **Wearable Integration**: Smartwatch SOS functionality
4. **Family Tracking**: Optional location sharing with family
5. **Emergency Services**: Direct integration with local emergency services

### Technical Improvements
1. **Offline Sync**: Better offline data synchronization
2. **Push Notifications**: Real-time alerts and notifications
3. **Biometric Auth**: Fingerprint/face unlock for quick access
4. **AI Integration**: Smart threat detection and prevention

## 📞 Support

For technical support or questions:
- **Email**: support@safeher.app
- **Documentation**: Check FIREBASE_SMS_SETUP.md for detailed Firebase setup
- **Issues**: Report bugs and feature requests via project repository

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**SafeHer - Empowering Women's Safety Through Technology** 🛡️💪
