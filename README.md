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

## 🛠️ Project Setup for Developers

### ✅ 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
```

### ✅ 2. Install Dependencies

```bash
flutter pub get
```

### ✅ 3. Firebase Setup

Each developer must set up their own Firebase project or reuse the main one.

#### Option A: Using the Same Firebase Project

1. Ask the owner to add your email to the [Firebase Console → Project Settings → Users & Permissions](https://console.firebase.google.com/).
2. Once invited, go to Firebase Console → the project.
3. Download your own `google-services.json`:
   - Go to **Project settings > Android app**
   - Download `google-services.json`
   - Place it in:

     ```
     android/app/google-services.json
     ```

4. (✅ This file is ignored in Git with `.gitignore`)

#### Option B: Create Your Own Firebase Project

- Go to [Firebase Console](https://console.firebase.google.com/)
- Create new project
- Enable:
  - **Google Sign-in** in Firebase Auth
  - **Cloud Firestore**
- Add Android app → download and place `google-services.json` into `android/app/`

---

## 🔐 Firebase Access for Team Members

To share Firebase access:

- Go to Firebase Console → ⚙️ Project Settings → Users and permissions
- Add each team member's Google email
- Assign role: **Editor** or **Owner**

---

## 📤 Git Commands to Push & Pull Code

### ✅ Pull latest changes

```bash
git pull origin main
```

### ✅ Push your updates

```bash
git add .
git commit -m "Meaningful message"
git push origin main
```

---

## 📁 Project Structure (Lib Folder)

```
lib/
├── main.dart
├── firebase_options.dart
├── routes/
│   └── app_routes.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── pdf_service.dart
│   ├── ai_service.dart
│   └── voice_service.dart
├── utils/
│   ├── constants.dart
│   ├── validators.dart
│   └── helpers.dart
├── modules/
│   ├── auth/
│   ├── dashboard/
│   ├── resume_progress/
│   ├── voice_input/
│   ├── result/
│   ├── cv_preview/
│   ├── download_share_screen.dart
│   ├── library/
│   └── edit_cv/
└── models/
    └── cv_model.dart
```

---

## 🧭 App Flow

```
LoginScreen
   ↓
HomeScreen
 ├─ Start New CV → VoiceInputScreen → ResultScreen → PreviewScreen → Download/Share
 ├─ Resume CV → ResumePromptScreen → VoiceInputScreen ...
 └─ My CV Library → LibraryScreen → Preview → Share
```

---

## ✨ Development Tasks (Live Progress)

| Feature                   | Status        |
| ------------------------- | ------------- |
| Login w/ Google           | ✅ Complete    |
| Home Screen Navigation    | ✅ Complete    |
| Voice Input               | ⏳ Bug fixes   |
| Firestore Integration     | ⏳ Partial     |
| Preview & Edit CV         | ✅ Functional  |
| PDF Generation            | ❌ To build    |
| Share / Save to Firestore | ❌ To build    |
| AI Enhancement            | ❌ To build    |
| Library Screen            | ❌ Needs work  |
| Full Manual Edit Screen   | ❌ Future step |

---

## ⚙️ Important Notes

- ✅ `google-services.json` is **ignored** by Git (`.gitignore`)
- ✅ Always **pull before pushing** to avoid conflicts
- 🚀 Use **feature branches** for larger features
- 💬 Keep commit messages short and clear

---

## 🤝 Contributing

Feel free to fork and contribute! Discuss major feature ideas in issues or team chat before starting.

---

## 📬 Contact

**Project Lead**: [Your Name]  
📧 Email: your.email@example.com  
🔐 Firebase Access: Ask project owner to invite you via email

