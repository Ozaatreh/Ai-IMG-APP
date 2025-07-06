import 'package:ai_img_generator/home_page.dart';
import 'package:ai_img_generator/navbar.dart';
import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';

void main () async {
  WidgetsFlutterBinding.ensureInitialized();
  // await InpaintingService.instance.initializeOrt('assets/lama_fp32.onnx');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Ai Img Generator",
      home: NavBarPage(),
    );
  }
}
