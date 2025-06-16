# Mojo

Mojo is a habit tracking and personal development app built in **SwiftUI** for iOS. It helps users get their mojo back by tracking daily habits, tasks, emotional check-ins, and character growth — all backed by a Supabase-powered backend.

---

## 🚀 Features

- 🔐 **Authentication**
  - Supabase-based login/logout system
  - Secure session management
- ✅ **Habits**
  - Create, update, archive daily or weekly habits
  - Log completions and gain XP
- 📋 **Tasks**
  - Add and complete tasks with optional deadlines and tags
  - Filter by status
- 📈 **Check-Ins**
  - Daily Likert-scale ratings across life categories
  - Optional journal entries for highs and lows
  - View mood trends over time
- 🌱 **Character Growth**
  - Your progress powers a visual character that grows and evolves as you complete goals

---

## 🧱 Tech Stack

- `SwiftUI` – Modern UI framework for iOS
- `Supabase` – Backend-as-a-Service for auth, database, and real-time
- `Combine` & `@ObservableObject` – Reactive data handling
- `Three.js` (web version) – Used for 3D character animation (iOS version TBD)

---

## 🛠️ Setup

### 1. Clone the Repo
```bash
git clone https://github.com/yourusername/mojo-ios.git
cd mojo-ios

### 2. Configure Supabase
Create `Mojo/Supabase.swift` with your project URL and anon key as shown in the source.

### 3. Fetch Packages
Open `Mojo.xcodeproj` in Xcode and resolve Swift Package dependencies to download the `supabase-swift` package.


### 4. Run the App
Open the project in Xcode, build and run. Sign in with your Supabase credentials on the login screen. Use the Sign Out button in the Todos list to end your session.
