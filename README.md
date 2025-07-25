# 🧠 Voice-Based CV Generator (Flutter + Firebase)

A smart voice-controlled app to help users create, preview, and share professional CVs using speech input — enhanced by AI and saved securely via Firebase.

---

## 🚀 Project Overview

This app allows users to **generate professional CVs using voice input**. With AI assistance and minimal typing, users speak short phrases which are polished into formal CV content. Key features:

- 🎤 Voice input for CV sections (skills, education, etc.)
- 🤖 AI enhancement of raw input into professional language
- 🧾 Preview, edit, and generate a clean PDF
- ☁ Save and manage CVs in the cloud (Firestore)
- 🔐 Google sign-in authentication

---

## 🛠️ Full Setup Guide (For Developers)

Follow these steps carefully to get the app running locally:

---

### ✅ 1. Prerequisites

Make sure you have:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and added to your path
- [Android Studio](https://developer.android.com/studio) (with Flutter/Dart plugins)
- A device/emulator to test the app
- Access to the Firebase project (provided by project lead)

---

### ✅ 2. Clone the Repository

```bash
git clone https://github.com/DanialShah11/cvapp.git
cd cvapp
```

---

### ✅ 3. Install Dependencies

```bash
flutter pub get
```

---

### ✅ 4. Firebase Configuration

> ⚠️ Use Option A below unless you're explicitly setting up your own Firebase instance.

#### 🔹 Option A: Use Shared Firebase Project (Recommended)

1. Ask the project lead to **add your email** to Firebase console:
2. After invitation, log in at [console.firebase.google.com](https://console.firebase.google.com) and go to the shared project.
3. Go to:
   - Project Settings → Android App → Download `google-services.json`
4. Copy the file to the following path:

   ```
   android/app/google-services.json
   ```

5. That's it! You're now connected to the shared Firebase backend.

> ✅ This file is ignored by Git and won't be pushed (already listed in `.gitignore`)

---

#### 🔹 Option B: Use Your Own Firebase Project

Only if you're building/testing independently:

- Create a new Firebase project
- Add an Android app in Firebase
- Enable:
  - Firebase Authentication (Google Sign-In)
  - Firestore Database
- Download `google-services.json` and place it in `android/app/`
- You must also run:

```bash
flutterfire configure
```

This generates `lib/firebase_options.dart` — make sure it's created before running the app.

---

### ✅ 5. Run the App

For Android:

```bash
flutter run
```

If you face errors related to Firebase config, double-check your `google-services.json` and `firebase_options.dart`.

---

## 📤 Git Workflow (Push & Pull Code)

### 🔄 Pull Latest Changes ( download code to local PC)
> Make sure you always pull code before you start working to avoid conflict

```bash
git pull origin main
```

### 💾 Push Your Updates ( upload code to github)
> Make sure you double check errors and test output before push 

```bash
git add .
git commit -m "Descriptive message"
git push origin main
```

> 📌 Always pull before pushing to avoid conflicts.

---

## 📁 Project Structure (Lib Folder)

```
lib/
├── main.dart
├── firebase_options.dart
├── routes/
│   └── app_routes.dart
├── services/
│   ├── firestore_service.dart
│   ├── pdf_service.dart
│   ├── ai_service.dart
│   └── template_service.dart
├── utils/
│   ├── constants.dart
│   ├── validators.dart
│   └── helpers.dart
├── modules/
│   ├── auth/
│   ├── cv_preview/
│   ├── dashboard/
│   ├── edit_cv/
│   ├── library/
│   ├── result/
│   ├── resume_progress/
│   └── voice_input/
└── models/
    └── cv_model.dart
```

---

## ⚠️ Common Issues

- `google-services.json` missing:
  - Make sure it's in `android/app/`
- `firebase_options.dart` missing:
  - Run: `flutterfire configure` or ask team lead for the file
- iOS issues?
  - This project currently supports **Android only**

---

## ⚙️ Developer Notes

- 🔐 Sensitive config (like API keys or Firebase files) are **not stored in Git**
- 🔄 Sync with team before making major changes
- 🧪 Test your flow before pushing to main branch

---

## 🤝 Contributing

- Open issues for bugs or feature ideas
- Create branches for features/fixes
- Use clear commit messages (`feat:`, `fix:`, etc.)
- Pull Requests are welcome!

---

## 📬 Contact

**Project Lead**: [Danial Shah]  
📧 Email: `projectcvapp622@gmail.com`  
💬 Firebase Access: Ask lead to invite your Google email

