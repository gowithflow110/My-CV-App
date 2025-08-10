// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../../../routes/app_routes.dart';

// class CVFormScreen extends StatelessWidget {
//   const CVFormScreen({super.key});

//   Future<void> _signOut(BuildContext context) async {
//     await FirebaseAuth.instance.signOut();

//     Navigator.of(context).pushNamedAndRemoveUntil(
//       AppRoutes.login,
//       (route) => false,
//     );

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Signed out successfully')),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('CV Form'),
//         backgroundColor: Colors.blue,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () => _signOut(context),
//             tooltip: 'Sign Out',
//           ),
//         ],
//       ),
//       body: const Center(
//         child: Text('Welcome to your Dashboard!'),
//       ),
//     );
//   }
// }
