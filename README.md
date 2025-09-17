# SafeHer - Women Security SMS Service Mobile App

SafeHer is a comprehensive women's safety mobile application built with Flutter that enables users to quickly send emergency alerts with real-time GPS location to pre-registered emergency contacts via SMS, even when internet access is unavailable.

## 🚨 Key Features

### Core Safety Features
- **Emergency SOS Button**: Large, prominent red button for instant emergency alerts
- **GPS Location Tracking**: Captures location within 5 seconds (as per SRS requirements)
- **SMS Alert System**: Sends emergency messages with Google Maps links offline
- **Emergency Contact Management**: Add, verify, and manage up to 5 emergency contacts
- **Contact Verification**: Automatic SMS verification for added contacts

### Technical Features
- **Firebase Authentication**: Secure user registration and login
- **Offline Functionality**: Works without internet connection using GPS + SMS
- **Real-time Database**: Firestore integration for contact and alert management
- **Haptic Feedback**: Physical feedback when SOS button is pressed
- **Modern UI**: Intuitive pink-themed interface designed for emergency situations

## 📱 How It Works

1. **User Registration**: Create account with Firebase Authentication
2. **Add Emergency Contacts**: Add up to 5 contacts with SMS verification
3. **Emergency Alert**: Press large SOS button to trigger emergency sequence
4. **Location Capture**: GPS location captured within 5 seconds
5. **SMS Broadcast**: Emergency message sent to all verified contacts with Google Maps link

### Emergency Message Format
```
🚨 EMERGENCY ALERT - SafeHer 🚨

I need help! This is an automated emergency message.

My current location:
https://www.google.com/maps?q=[latitude],[longitude]

Coordinates: [latitude], [longitude]

Please contact me immediately or call emergency services if needed.

- Sent via SafeHer App
```

## 🛠️ Technical Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Authentication)
- **Location Services**: Geolocator package
- **SMS Services**: Telephony package
- **Permissions**: Permission Handler
- **Platform**: Android (iOS support can be added)

## 📋 SRS Requirements Compliance

✅ **REQ-1**: GPS capture under 5 seconds  
✅ **REQ-2**: SMS with Google Maps link  
✅ **REQ-3**: Send to all verified contacts  
✅ **REQ-4**: SOS trigger button  
✅ **REQ-5**: Add/edit/delete up to 5 contacts  
✅ **REQ-6**: SMS verification  
✅ **REQ-7**: Local storage  

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Android Studio / VS Code
- Firebase project setup
- Android device/emulator for testing

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd safeher
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Download `google-services.json` and place in `android/app/`

4. **Run the app**
   ```bash
   flutter run
   ```

### Required Permissions
The app requires the following Android permissions:
- `ACCESS_FINE_LOCATION` - GPS location access
- `ACCESS_COARSE_LOCATION` - Network-based location
- `SEND_SMS` - Send emergency SMS messages
- `READ_SMS` - Read SMS for verification
- `RECEIVE_SMS` - Receive SMS responses
- `READ_PHONE_STATE` - Phone state access
- `VIBRATE` - Haptic feedback
- `WAKE_LOCK` - Keep device awake during emergency

## 📁 Project Structure

```
lib/
├── auth/
│   ├── login_page.dart          # User login interface
│   └── register_page.dart       # User registration interface
├── dashboard/
│   └── dashboard_page.dart      # Main dashboard with SOS button
├── services/
│   ├── location_service.dart    # GPS location handling
│   └── sms_service.dart         # SMS functionality
├── add_contact_page.dart        # Emergency contact management
└── main.dart                    # App entry point
```

## 🔧 Configuration

### Firebase Configuration
1. Create Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication with Email/Password provider
3. Create Firestore database with the following structure:

```
users/
  {userId}/
    - name: string
    - email: string  
    - phone: string
    - createdAt: timestamp
    
    contacts/
      {contactId}/
        - name: string
        - phone: string
        - verified: boolean
        - addedAt: timestamp
    
    alerts/
      {alertId}/
        - timestamp: timestamp
        - location: {latitude: number, longitude: number}
        - sentTo: string
        - status: string
```

### Android Configuration
Ensure all required permissions are added in `android/app/src/main/AndroidManifest.xml`

## 🧪 Testing

### Manual Testing Checklist
- [ ] User registration and login
- [ ] Add emergency contacts (max 5)
- [ ] SMS verification for contacts
- [ ] SOS button functionality
- [ ] GPS location capture
- [ ] SMS alert sending
- [ ] Contact management (edit/delete)
- [ ] App permissions handling

### Test Emergency Flow
1. Register/login to app
2. Add at least one emergency contact
3. Verify contact receives verification SMS
4. Press SOS button
5. Verify emergency SMS is sent with location link
6. Check Firestore for alert logging

## 🔒 Security Features

- **Firebase Authentication**: Secure user management
- **Local Data Encryption**: Sensitive data stored securely
- **Permission Validation**: Runtime permission requests
- **Contact Verification**: SMS-based contact verification
- **Device Lock Respect**: App respects device security settings

## 📊 Performance Requirements

- **SMS Alert Speed**: < 5 seconds from SOS button press
- **Battery Optimization**: Minimal background resource usage
- **Offline Capability**: Core features work without internet
- **Memory Efficiency**: Optimized for low-end Android devices

## 🚀 Deployment

### Building for Release
```bash
flutter build apk --release
```

### Google Play Store Requirements
- Target SDK version 33+
- All required permissions documented
- Privacy policy for location and SMS data
- App signing with upload key

## 👥 Contributors

- **Sampangi Vaishnavi** (24BD5A6612)
- **Garige Yasha Sree** (23BD1A664P)
- **Pulluri Abhishek** (24BD5A6607)
- **Nakkeerthi Sandhya** (24BD5A6611)

**Institution**: Keshav Memorial Institute of Technology

## 📄 License

This project is developed as part of academic coursework. All rights reserved.

## 📞 Support

For technical support or questions:
- Create an issue in the repository
- Contact the development team
- Refer to the SRS documentation

## 🔮 Future Enhancements

- **Multilingual Support**: Hindi, Telugu language options
- **iOS Support**: Extend to iOS platform
- **Voice Commands**: Voice-activated emergency alerts
- **Geofencing**: Location-based automatic alerts
- **Emergency Services Integration**: Direct connection to local authorities
- **Family Dashboard**: Real-time tracking for family members

---

**⚠️ Important**: This app is designed for emergency situations. Always contact local emergency services (911, 100, etc.) for immediate life-threatening emergencies.
