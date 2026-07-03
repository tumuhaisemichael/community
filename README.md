# Community App

A robust community safety and connection platform built with Flutter and Firebase. This app empowers neighbors to stay informed, report incidents, and coordinate for a safer living environment.

## 🌟 Key Features

-   **Real-time Incident Reporting:** Report safety concerns or emergencies with location data, descriptions, and photos. Options for anonymous reporting are included.
-   **Interactive Safety Map:** View a live map showing your current location and nearby reported incidents, categorized by severity and type.
-   **Panic Button (SOS):** Instantly alert nearby community members when in immediate danger with a high-priority SOS signal and your precise location.
-   **Community Bulletin:** A shared space for announcements, general updates, and non-emergency community news.
-   **Neighbor-to-Neighbor Messaging:** Secure chat functionality to communicate directly with other members of the community.
-   **Emergency Resources:**
    -   **Police Station Locator:** Find the nearest police stations based on your GPS coordinates.
    -   **Emergency Contacts:** Quick access to essential local emergency numbers.
-   **Safety Tools:**
    -   **Vacation Watch:** Notify trusted neighbors when you're away so they can keep an eye on your property.
    -   **Personal Safety Log:** Maintain a private record of safety-related observations.
    -   **Crime Statistics:** Visualize community safety trends through interactive charts and dashboards.
-   **Privacy Controls:** Manage your profile and decide how much information you share with the community.

## 🛠 Technology Stack

-   **Frontend:** [Flutter](https://flutter.dev/) (Dart)
-   **Backend:** [Firebase](https://firebase.google.com/)
    -   **Authentication:** Secure user sign-up and login.
    -   **Firestore:** Real-time NoSQL database for posts, chats, and user data.
    -   **Cloud Storage:** Hosting for images attached to incident reports.
-   **Mapping:** [flutter_map](https://pub.dev/packages/flutter_map) with [MapTiler](https://www.maptiler.com/) integration.
-   **Location Services:** [geolocator](https://pub.dev/packages/geolocator) for precise GPS positioning.
-   **Data Visualization:** [fl_chart](https://pub.dev/packages/fl_chart) for crime statistics and analytics.

## 🚀 Getting Started

### Prerequisites

-   Flutter SDK (^3.10.1)
-   Dart SDK
-   A Firebase project
-   A MapTiler API Key (for map tiles)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd community
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Setup:**
    -   Create a new project in the [Firebase Console](https://console.firebase.google.com/).
    -   Enable Authentication (Email/Password), Firestore, and Storage.
    -   Download and add the configuration files:
        -   Android: `google-services.json` to `android/app/`
        -   iOS: `GoogleService-Info.plist` to `ios/Runner/`
    -   Alternatively, use the FlutterFire CLI to configure the app.

4.  **MapTiler Setup:**
    -   Obtain an API key from [MapTiler](https://www.maptiler.com/).
    -   Run the app with the following flag to enable maps:
        ```bash
        flutter run --dart-define=MAPTILER_KEY=your_api_key_here
        ```

## 📱 Screenshots

*(Add screenshots of the Home Screen, Incident Reporting, and Statistics Dashboard here)*

## 🤝 Contributing

Contributions are welcome! If you have suggestions for new features or improvements, please feel free to:
1. Fork the repository.
2. Create a feature branch.
3. Commit your changes.
4. Push to the branch.
5. Open a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details (or specify your preferred license).
