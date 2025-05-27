# PlanIt - Event Planning Platform

<div align="center">
  <img src="assets/images/newlogo3.png" alt="PlanIt Logo" width="200"/>
</div>

## 📱 Overview
PlanIt is a modern event planning platform that seamlessly connects clients with professional event organizers. Built with Flutter, it provides a robust solution for event planning, management, and coordination.

## ✨ Features

### For Clients
- 🔍 **Smart Search**: Find the perfect organizer with advanced filtering
- 📱 **Portfolio Viewing**: Browse detailed organizer profiles and past work
- 📅 **Easy Booking**: Simple and secure event booking process
- 💳 **Secure Payments**: Integrated payment processing
- 📊 **Order Tracking**: Real-time booking status updates
- ⭐ **Review System**: Rate and review organizers
- 🌤️ **Weather Updates**: Get weather forecasts for your events
- 🔔 **Real-time Notifications**: Stay updated with instant alerts

### For Organizers
- 📝 **Portfolio Management**: Showcase your work and services
- 📅 **Booking Management**: Handle requests and manage schedule
- 💼 **Service Customization**: Set your services and pricing
- 📈 **Analytics Dashboard**: Track performance and growth
- ⭐ **Review Management**: Respond to client feedback
- 📱 **Client Communication**: Built-in messaging system
- 📊 **Business Insights**: Detailed performance metrics

## 🛠️ Technology Stack

### Frontend
- **Framework**: Flutter
- **State Management**: Provider
- **UI Components**: Material Design
- **Local Storage**: SharedPreferences

### Backend
- **Authentication**: Firebase Auth
- **Database**: Firebase Firestore
- **Storage**: Firebase Storage
- **Functions**: Firebase Cloud Functions

### APIs & Services
- **Payment**: Stripe Integration
- **Email**: Firebase Cloud Messaging
- **Weather**: OpenWeatherMap API

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (2.0.0+)
- Dart SDK (2.12.0+)
- Firebase Account
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/planit.git
```

2. **Navigate to project directory**
```bash
cd planit
```

3. **Install dependencies**
```bash
flutter pub get
```

4. **Configure Firebase**
   - Create a new Firebase project
   - Add Android/iOS apps
   - Download and add configuration files
   - Enable Authentication and Firestore

5. **Run the app**
```bash
flutter run
```

## 📁 Project Structure
planit/
├── android/                    # Android specific files
├── ios/                       # iOS specific files
├── lib/                       # Main application code
│   ├── controllers/           # Business logic controllers
│   │   ├── auth_controller.dart
│   │   ├── booking_controller.dart
│   │   ├── organizer_controller.dart
│   │   └── user_controller.dart
│   │
│   ├── models/               # Data models
│   │   ├── user_model.dart
│   │   ├── booking_model.dart
│   │   ├── organizer_model.dart
│   │   ├── portfolio_model.dart
│   │   └── review_model.dart
│   │
│   ├── views/                # UI screens
│   │   ├── auth/
│   │   │   ├── login_view.dart
│   │   │   ├── register_view.dart
│   │   │   └── forgot_password_view.dart
│   │   │
│   │   ├── client/
│   │   │   ├── client_home_view.dart
│   │   │   ├── search_view.dart
│   │   │   ├── booking_view.dart
│   │   │   └── profile_view.dart
│   │   │
│   │   ├── organizer/
│   │   │   ├── organizer_home_view.dart
│   │   │   ├── portfolio_view.dart
│   │   │   ├── booking_management_view.dart
│   │   │   └── analytics_view.dart
│   │   │
│   │   └── common/
│   │       ├── splash_screen.dart
│   │       └── error_screen.dart
│   │
│   ├── services/             # External services
│   │   ├── auth_service.dart
│   │   ├── firebase_service.dart
│   │   ├── storage_service.dart
│   │   └── api_service.dart
│   │
│   ├── providers/            # State management
│   │   ├── auth_provider.dart
│   │   ├── booking_provider.dart
│   │   └── user_provider.dart
│   │
│   ├── utils/               # Utility functions
│   │   ├── constants.dart
│   │   ├── validators.dart
│   │   ├── helpers.dart
│   │   └── theme.dart
│   │
│   ├── widgets/             # Reusable widgets
│   │   ├── common/
│   │   │   ├── custom_button.dart
│   │   │   ├── custom_text_field.dart
│   │   │   └── loading_indicator.dart
│   │   │
│   │   ├── client/
│   │   │   ├── booking_card.dart
│   │   │   └── organizer_card.dart
│   │   │
│   │   └── organizer/
│   │       ├── portfolio_item.dart
│   │       └── booking_item.dart
│   │
│   └── main.dart            # Application entry point
│
├── assets/                  # Static assets
│   ├── images/
│   │   ├── logo.png
│   │   └── icons/
│   │
│   ├── fonts/
│   │   └── custom_fonts/
│   │
│   └── translations/        # Localization files
│       ├── en.json
│       └── es.json
│
├── test/                   # Test files
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── docs/                   # Documentation
│   ├── api/
│   ├── setup/
│   └── architecture/
│
├── .gitignore             # Git ignore file
├── pubspec.yaml           # Flutter dependencies
├── README.md             # Project documentation
└── LICENSE               # License file

## ⚙️ Configuration

### Environment Setup
Create a `.env` file in the root directory with:
FIREBASE_API_KEY=your_api_key
FIREBASE_AUTH_DOMAIN=your_auth_domain
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_storage_bucket
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID=your_app_id


## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📈 Roadmap

- [ ] Multi-language support
- [ ] Advanced analytics
- [ ] Mobile app for organizers
- [ ] Calendar integration
- [ ] Automated event reminders
- [ ] Social media integration

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

- [Arsal Ajmal](https://github.com/ArsalAjmal)
- [Mahneen Kamran Mirza](https://github.com/MahamMirza8)


## 📞 Support

- **Email**: arsal.ajmal621@gmail.com

## 🙏 Acknowledgments

- Flutter Team
- Firebase Team
- All contributors

## ⭐ Show your support

Give a ⭐️ if this project helped you!

## 📝 Notes

- Make sure to update the Firebase configuration
- Keep your API keys secure
- Follow the contribution guidelines

---

Made with ❤️ by [Arsal Ajmal](https://github.com/ArsalAjmal)
