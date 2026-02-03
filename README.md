<p align="center">
  <img src="assets/icon/aniflux_logo.png" width="120" alt="AniFlux Logo" />
</p>

<h1 align="center">AniFlux</h1>
<p align="center">
  A Flutter based AniList API with a clean and simple UI.
</p>

<p align="center">
  🌐 <strong>Official Website:</strong> https://www.aniflux.in/
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue" />
  <img src="https://img.shields.io/badge/Firebase-Enabled-orange" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>


AniFlux is a modern **Flutter-based anime tracking application** inspired by **MyAnimeList** and **AniList**.  
It allows users to **search, browse, and track anime**, with **cloud sync using Firebase and Appwrite** and **live data from the AniList GraphQL API**.

---

<h2 align="center">⬇️ Download AniFlux</h2>

<p align="center">
  <strong>The fluid way to track anime. Available now.</strong>
</p>

<p align="center">
  <a href="https://github.com/som120/AniFlux/releases/latest">
    <img src="https://img.shields.io/badge/Download_APK-GitHub-24292e?style=for-the-badge&logo=github&logoColor=white&height=50" height="50" alt="Download from GitHub" />
  </a>
  &nbsp;&nbsp;
  <a href="#">
    <img src="https://img.shields.io/badge/Google_Play-Coming_Soon-lightgrey?style=for-the-badge&logo=googleplay&logoColor=grey&height=50" height="50" alt="Google Play Coming Soon" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/som120/AniFlux?style=flat-square&color=2979FF&label=Latest%20Version" alt="Latest Version" />
  &nbsp;
  <img src="https://img.shields.io/github/downloads/som120/AniFlux/total?style=flat-square&color=success&label=Total%20Downloads" alt="Total Downloads" />
  &nbsp;
  <img src="https://img.shields.io/badge/APK_Size-59.3_MB-orange?style=flat-square" alt="APK Size" />
</p>

---

## 📱 Screenshots

| Home Screen | Anime Details | Search | Profile |
|:---:|:---:|:---:|:---:|
| <img src="assets/Screenshorts/Home.png" width="200" alt="Home" /> | <img src="assets/Screenshorts/Detail.png" width="200" alt="Details" /> | <img src="assets/Screenshorts/Search.png" width="200" alt="Search" /> | <img src="assets/Screenshorts/Profile.png" width="200" alt="Profile" /> |

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Telegram-Animated-Emojis/main/Objects/Chart%20Increasing.webp" alt="Chart Increasing" width="25" height="25" /> Development Activity

<p align="center">
  <img
    src="https://github-readme-activity-graph.vercel.app/graph?username=som120&repo=AniFlux&theme=github-compact"
    alt="AniFlux commit activity graph"
  />
</p>



---
## 📈 Project Growth

<p align="center">
  <a href="https://star-history.com/#som120/AniFlux&Date">
    <img src="https://api.star-history.com/svg?repos=som120/AniFlux&type=Date" alt="Star History Chart" />
  </a>
</p>

---


## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Telegram-Animated-Emojis/main/Travel%20and%20Places/Rocket.webp" alt="Rocket" width="50" height="50" /> Features

### <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Telegram-Animated-Emojis/main/Objects/Magnifying%20Glass%20Tilted%20Left.webp" alt="Magnifying Glass Tilted Left" width="25" height="25" /> Anime Search
- Search anime using **AniList GraphQL API**
- Clean and modern UI
- Displays poster, rating, release year
- Fast filters:
  - Top 100
  - Calandar
  - Seasonal
  - Popular
  - Upcoming
  - Airing
  - Movies

### 🎨 Modern UI
- Custom anime cards
- Rounded corners & soft shadows
- Smooth animations
- Clean white theme
- Fully responsive for **Android & iOS**

### <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Telegram-Animated-Emojis/main/Animals%20and%20Nature/Star.webp" alt="Star" width="25" height="25" /> Anime Details
- High-quality cover image
- Description & synopsis
- Genres
- Rating & episode count
- Direct link to AniList page

### ☁️ Firebase Integration
- Firebase Core configured
- Firestore database connected
- Store user watchlist & progress
- Real-time cloud sync *(coming soon)*

### <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Telegram-Animated-Emojis/main/Animals%20and%20Nature/Dove.webp" alt="Dove" width="25" height="25" /> Seamless Updates
- Powered by **Shorebird** Code Push
- Get **instant bug fixes** and performance improvements
- No need to re-download the APK for minor updates
- OTA (Over-The-Air) patching enabled

---

## 🏗️ Tech Stack

| Technology | Icon | Purpose |
|-----------|:---:|--------|
| **Flutter 3** | <img src="https://skillicons.dev/icons?i=flutter" width="20"/> | Cross-platform UI Framework |
| **Dart** | <img src="https://skillicons.dev/icons?i=dart" width="20"/> | Programming Language |
| **Firebase** | <img src="https://skillicons.dev/icons?i=firebase" width="20"/> | Auth, Database, & Backend |
| **Appwrite** | <img src="https://skillicons.dev/icons?i=appwrite" width="20"/> | Cloud Functions |
| **GraphQL** | <img src="https://skillicons.dev/icons?i=graphql" width="20"/> | AniList Data Querying |
| **Shorebird** | <img src="https://avatars.githubusercontent.com/u/135552150?s=200&v=4" width="20"/> | OTA Code Push & Updates |

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Telegram-Animated-Emojis/main/Objects/Card%20Index%20Dividers.webp" alt="Card Index Dividers" width="25" height="25" /> Project Structure

```text
AniFlux/
├── android/
├── assets/
├── backend/
├── build/
├── functions/
├── ios/
├── lib/
│   ├── screens/
│   │   ├── anime_detail_screen.dart
│   │   ├── avatar_picker_screen.dart
│   │   ├── character_detail_screen.dart
│   │   ├── forgot_password_screen.dart
│   │   ├── home_screen.dart
│   │   ├── login_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── search_screen.dart
│   │   └── signup_screen.dart
│   │
│   ├── services/
│   │   ├── anilist_service.dart
│   │   ├── app_update_service.dart
│   │   ├── auth_service.dart
│   │   └── notification_service.dart
│   │
│   ├── theme/
│   │   └── app_theme.dart
│   │
│   ├── utils/
│   │   ├── light_skeleton.dart
│   │   └── transitions.dart
│   │
│   ├── widgets/
│   │   ├── account_settings_bottom_sheet.dart
│   │   ├── anime_entry_bottom_sheet.dart
│   │   ├── avatar_picker_bottom_sheet.dart
│   │   ├── edit_profile_bottom_sheet.dart
│   │   └── auth_wrapper.dart
│   │
│   ├── firebase_options.dart
│   └── main.dart
│
├── linux/
├── macos/
├── web/
└── pubspec.yaml
```


---

## 🔧 Setup Instructions

### 1️⃣ Clone the repository
```bash
git clone https://github.com/<your-username>/AniFlux.git
cd AniFlux
```
```bash
flutter pub get
```
```bash
flutterfire configure
```
```bash
flutter run
```
---

🌐 API Used
AniList GraphQL API

---
## 📖 Documentation:
https://anilist.gitbook.io/anilist-apiv2-docs/

🛠️ Planned Features

🔐 Google Sign-In (Firebase Auth)

⭐ User ratings

❤️ Favorites list

📌 Watchlist system (Watching / Completed / Dropped)

📊 User statistics

🌙 Dark mode

🔄 Offline support

🎴 Seasonal anime page

✨ Hero animations & advanced transitions

---
## 🤝 Contributing

Contributions are welcome!
Please open an issue first to discuss major changes.

Steps:

Fork the repository

Create a new branch

Commit your changes

Open a pull request

---
## 📜 Legal & Community

This project is licensed under the **MIT License** and follows open-source best practices.

- 📄 [MIT License](LICENSE)
- 🤝 [Contributing Guidelines](CONTRIBUTING.md)
- 🧭 [Code of Conduct](CODE_OF_CONDUCT.md)
- 🔐 [Security Policy](SECURITY.md)

Please read the respective files in the repository for more details.

---

## Disclaimer

AniFlux is a third-party client and is not affiliated with, endorsed by, or sponsored by AniList.

AniList content and trademarks belong to their respective owners.

---

<p align="center">
  Built with ❤️ using Flutter • Firebase • AppWrite • AniList API
</p>
