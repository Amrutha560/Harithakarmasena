import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('About Us', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.eco_rounded, size: 80, color: Color(0xFF2E7D32)),
            const SizedBox(height: 24),
            const Text('Harithakarma Sena', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Version 2.1.0', style: TextStyle(color: Colors.black38)),
            const SizedBox(height: 40),
            const Text(
              'Harithakarma Sena is a waste management initiative aimed at creating a clean and sustainable future. Our app streamlines the collection process, providing residents with real-time updates and an easy way to manage their waste collection services.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.privacy_tip_outlined),
              title: Text('Privacy Policy'),
            ),
            const ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('Terms of Service'),
            ),
          ],
        ),
      ),
    );
  }
}
