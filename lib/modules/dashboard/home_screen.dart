import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('Welcome Back!'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ Profile Icon with Popup Menu (More Professional)
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, color: Colors.white),
            ),
            onSelected: (value) {
              if (value == "logout") {
                _logout(context);
              } else if (value == "settings") {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Settings Coming Soon")),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "settings",
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18),
                    SizedBox(width: 8),
                    Text("Settings"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: "logout",
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Logout"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Welcome Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Let's Build Your Professional CV",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Create, edit and manage your resumes with ease.",
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ✅ Tappable Cards
            _buildActionCard(
              context,
              icon: Icons.create_new_folder,
              title: "Start a New CV",
              description: "Build a fresh CV step by step using voice or text.",
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.voiceInput,
                  arguments: {'forceNew': true},
                );
              },
            ),
            const SizedBox(height: 16),

            _buildActionCard(
              context,
              icon: Icons.play_circle_fill,
              title: "Resume Previous CV",
              description: "Continue where you left off and complete your CV.",
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.resumePrompt);
              },
            ),
            const SizedBox(height: 16),

            _buildActionCard(
              context,
              icon: Icons.library_books,
              title: "My CV Library",
              description:
              "View, edit or download all your previously created CVs.",
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.library);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Now the whole card is clickable
  Widget _buildActionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String description,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style:
                      const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    try {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logout failed")),
      );
    }
  }
}
