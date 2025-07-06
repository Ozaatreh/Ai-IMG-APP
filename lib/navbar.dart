import 'package:ai_img_generator/home_page.dart';
import 'package:ai_img_generator/img_eraser.dart';
import 'package:flutter/material.dart';
import 'package:circle_nav_bar/circle_nav_bar.dart';

class NavBarPage extends StatefulWidget {
  @override
  State<NavBarPage> createState() => _NavBarPageState();
}

class _NavBarPageState extends State<NavBarPage> {
  int currentIndex = 0;

  final List<Widget> pages = [
    Center(child: HomePage()),
    // Center(child: Text('Gallery', style: TextStyle(fontSize: 24))),
    Center(child: MagicEraserPage()),
    // Center(child: Text('Settings', style: TextStyle(fontSize: 24))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: CircleNavBar(
        activeIcons: const [
          Icon(Icons.home, color: Colors.white),
          // Icon(Icons.photo_library, color: Colors.white),
          Icon(Icons.edit, color: Colors.white),
          // Icon(Icons.settings, color: Colors.white),
        ],
        inactiveIcons: const [
          Icon(Icons.home_outlined, color: Colors.black54),
          // Icon(Icons.photo_library_outlined, color: Colors.black54),
          Icon(Icons.edit_outlined, color: Colors.black54),
          // Icon(Icons.settings_outlined, color: Colors.black54),
        ],
        color: Colors.blueGrey.shade800,
        height: 60,
        circleWidth: 60,
        activeIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        cornerRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        shadowColor: Colors.black.withOpacity(0.1),
        elevation: 8,
        circleShadowColor: Colors.black45,
        circleColor: Colors.teal.shade700,
      ),
    );
  }
}
