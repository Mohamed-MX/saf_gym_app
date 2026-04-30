# SAF Gym App 🏋️‍♂️

SAF is a premium, feature-rich gym companion application built with Flutter, designed to help users track their strength training progress with precision and intelligence.

## 🚀 Key Features

- **📊 Advanced Performance Dashboard**
  - Interactive **Weight Progression Graphs** showing max weight lifted per session.
  - Sticky summary stats (Reps, Workouts, Exercises, Time Spent) for quick reference.
  - Filterable progress views (Daily, Weekly, Monthly, Yearly).
  - **PDF Export**: Generate professional performance reports to share or keep for your records.

- **🤖 AI-Powered Workout Planning**
  - Generate customized workout plans using advanced AI logic.
  - Tailor routines based on your fitness goals and available equipment.

- **📈 Precision Tracking**
  - Detailed workout sessions with **per-set weight tracking**.
  - Intelligent rep counting via **BLE Wearable Sensor** integration.
  - Interactive muscle selection map using high-fidelity human body SVGs.

- **🛠 Plan Editor**
  - Create and customize your own workout routines.
  - Reorder exercises with intuitive drag-and-drop functionality.
  - Manage sets, reps, and target muscle groups with ease.

- **💎 Premium UI/UX**
  - Modern design aesthetic using the **Outfit** font family.
  - Clean, intuitive navigation with a dedicated Performance Dashboard tab.
  - Responsive layouts optimized for a seamless mobile experience.

## 📱 Screenshots

*(Add screenshots here)*

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Database**: [Sqflite](https://pub.dev/packages/sqflite)
- **Connectivity**: [Flutter Blue Plus](https://pub.dev/packages/flutter_blue_plus) (for BLE sensor)
- **PDF Generation**: [pdf](https://pub.dev/packages/pdf) & [path_provider](https://pub.dev/packages/path_provider)

## 🏁 Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/Mohamed-MX/saf_gym_app.git
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up environment**
   - Create a `.env` file in the root directory.
   - Add your necessary API keys (e.g., for AI features).

4. **Run the app**
   ```bash
   flutter run
   ```

---

*Developed as a graduation project by [Mohamed-MX](https://github.com/Mohamed-MX).*
