import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  Uint8List? _generatedImage;
  bool _isloading = false;
  String _errorMessage = '';
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  static const String _baseUrl = 'https://image.pollinations.ai/prompt/';

  void initState() {
    super.initState();
    _requestPermission();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    ); // AnimationController

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    ); // AnimationController

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

 Future<void> _requestPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.photos.request(); // for Android 13+
    if (!status.isGranted) {
      await Permission.storage.request(); // for Android 12 and lower
    }
  }
}


  Future<void> _generateImage() async {
    if (_promptController.text.trim().isEmpty) {
      _showSnackBar('Please enter a prompt', isError: true);
      return;
    }

    setState(() {
      _isloading = true;
      _errorMessage = '';
      _generatedImage = null;
    });

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final encodedPrompt = Uri.encodeComponent(
          _promptController.text.trim(),
        );
        final imageUrl =
            '$_baseUrl$encodedPrompt?width=1024&height=1024&seed=${Random().nextInt(10000000)}';
        print("Requesting: $imageUrl"); // Debug URL

        final response = await http.get(Uri.parse(imageUrl));

        if (response.statusCode == 200) {
          setState(() {
            _generatedImage = response.bodyBytes;
            _isloading = false;
          });
          _fadeController.forward();
          _scaleController.forward();
          _showSnackBar('Image Generated Successfully', isError: false);
          return; // Exit on success
        } else {
          print("Failed with status: ${response.statusCode}"); // Debug
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: 2)); // Wait before retrying
          }
        }
      } catch (e) {
        retryCount++;
        print("Error: $e"); // Debug
        if (retryCount >= maxRetries) {
          setState(() {
            _isloading = false;
            _errorMessage =
                'Failed after $maxRetries attempts. Try again later.';
          });
          _showSnackBar(_errorMessage, isError: true);
        }
      }
    }
  }

  Future<void> _saveImage() async {
    if (_generatedImage == null) return;
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        // Use Downloads folder
        directory = Directory('/storage/emulated/0/Download');

        // Fallback if it doesn't exist
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        // iOS or other platforms
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'ai_generated_$timestamp.png';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(_generatedImage!);

        _showSnackBar(
          'Image saved to ${directory.path}/$fileName',
          isError: false,
        );
      } else {
        _showSnackBar('Unable to access storage directory.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to save image: $e', isError: true);
    }
  }

  Future<void> _shareImage() async {
    if (_generatedImage == null) return;
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ai_generated_$timestamp.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(_generatedImage! as List<int>);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Check out this AI-generated image!');
      _showSnackBar('Image shared successfully!', isError: false);
    } catch (e) {
      _showSnackBar('Failed to share image: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ), // SnackBar
    );
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.image_outlined, color: Colors.deepPurple, size: 28),
          SizedBox(width: 12),
          Text(
            'AI Image Generator',
            style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Describe what you need",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    hintText: "e.g. A futuristic city on Mars at sunset",
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                  ),
                  maxLines: 3,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isloading ? null : _generateImage,
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: _isloading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Generate Image',
                            style: TextStyle(fontSize: 16),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Generated Image Section
          if (_generatedImage != null)
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_generatedImage!),
                      ),
                      const SizedBox(height: 20),
                      
                      // Regenerate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generateImage,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text(
                            "Regenerate",
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Save & Share Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveImage,
                              icon: const Icon(Icons.save_alt, size: 20),
                              label: const Text(
                                "Save",
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _shareImage,
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text(
                                "Share",
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
}
