//lib/routes/app_routes.dart

class AppRoutes {
  // ----------------- Authentication -----------------
  static const login = '/login';                 // 👤 Sign-in screen

  // ----------------- Dashboard / Home -----------------
  static const home = '/home';                    // 🏠 Main dashboard

  // ----------------- Resume Builder -----------------
  static const resumePrompt = '/resume-prompt';   // 📝 Prompt for resume input
  static const voiceInput = '/voice-input';       // 🎤 Voice-based input
  static const summary = '/summary';              // 📋 Summary view
  static const aiProcessing = '/ai-processing';   // ⚙️ AI animation
  static const preview = '/preview';              // 🖨 Final CV preview
  static const editCV = '/edit-cv';               // ✏️ Manual editing

  // ----------------- CV Library -----------------
  static const library = '/library';              // 📚 Saved CVs
}
