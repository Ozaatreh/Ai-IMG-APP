import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'; // for consolidateHttpClientResponseBytes

class MagicEraserPage extends StatefulWidget {
  @override
  _MagicEraserPageState createState() => _MagicEraserPageState();
}

class _MagicEraserPageState extends State<MagicEraserPage> {
  Uint8List? original;
  Uint8List? erased;
  bool loading = false;
  List<Offset> selectedPoints = [];
  GlobalKey imageKey = GlobalKey();
  double brushSize = 20.0;
  bool isDrawing = false;
  Offset? currentPosition;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    final modelPath = await _downloadModelIfNeeded();
    await InpaintingService.instance.initializeOrt(modelPath);
  }

  Future<String> _downloadModelIfNeeded() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelPath = '${dir.path}/lama_fp32.onnx';
    final file = File(modelPath);

    if (await file.exists()) return modelPath;

    final url = 'https://yourdomain.com/models/lama_fp32.onnx'; // ✅ REPLACE THIS
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();
    final bytes = await consolidateHttpClientResponseBytes(response);
    await file.writeAsBytes(bytes);
    return modelPath;
  }

  Future<void> pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      original = bytes;
      erased = null;
      selectedPoints.clear();
    });
  }

  Future<void> erase() async {
    if (original == null || selectedPoints.isEmpty) return;
    setState(() => loading = true);

    try {
      final image = img.decodeImage(original!);
      if (image == null) {
        setState(() => loading = false);
        return;
      }

      final renderBox = imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        setState(() => loading = false);
        return;
      }

      final scaleX = image.width / renderBox.size.width;
      final scaleY = image.height / renderBox.size.height;
      final scaledBrushSize = brushSize * ((scaleX + scaleY) / 2);

      // Turn points into circular polygon regions
      final regions = selectedPoints.map((center) {
        final scaledCenter = Offset(center.dx * scaleX, center.dy * scaleY);
        const int steps = 12;
        final radius = scaledBrushSize / 2;

        return List.generate(steps, (i) {
          final angle = 2 * pi * i / steps;
          final dx = scaledCenter.dx + radius * cos(angle);
          final dy = scaledCenter.dy + radius * sin(angle);
          return {'x': dx, 'y': dy};
        });
      }).toList();

      final uiImage = await InpaintingService.instance.inpaint(original!, regions);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);

      setState(() {
        erased = byteData!.buffer.asUint8List();
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> saveImage() async {
    if (erased == null) return;
    final status = await Permission.storage.request();
    if (!status.isGranted) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/erased_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(erased!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image saved to $path')),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      isDrawing = true;
      selectedPoints.add(details.localPosition);
      currentPosition = details.localPosition;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!isDrawing) return;
    setState(() {
      selectedPoints.add(details.localPosition);
      currentPosition = details.localPosition;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      isDrawing = false;
      currentPosition = null;
    });
  }

  void clearSelection() {
    setState(() => selectedPoints.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Magic Eraser"),
        backgroundColor: Colors.teal[700],
        centerTitle: true,
        elevation: 1,
        actions: [
          if (selectedPoints.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: clearSelection,
              tooltip: 'Clear selection',
            ),
          IconButton(
            icon: Icon(Icons.brush),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Brush Size"),
                  content: Slider(
                    value: brushSize,
                    min: 5,
                    max: 50,
                    divisions: 9,
                    label: brushSize.round().toString(),
                    onChanged: (value) {
                      setState(() => brushSize = value);
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
            tooltip: 'Change brush size',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: original != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: GestureDetector(
                          onPanStart: _handlePanStart,
                          onPanUpdate: _handlePanUpdate,
                          onPanEnd: _handlePanEnd,
                          child: RepaintBoundary(
                            key: imageKey,
                            child: Stack(
                              children: [
                                Image.memory(erased ?? original!, fit: BoxFit.contain),
                                CustomPaint(
                                  painter: SelectionPainter(selectedPoints, brushSize, isDrawing, currentPosition),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text("Tap 'Choose' to select an image", style: TextStyle(color: Colors.grey[600])),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            if (loading)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.photo),
                      label: Text("Choose"),
                      onPressed: pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[800],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.delete_sweep),
                      label: Text("Erase"),
                      onPressed: erase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.save),
                      label: Text("Save"),
                      onPressed: saveImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}

class SelectionPainter extends CustomPainter {
  final List<Offset> points;
  final double brushSize;
  final bool isDrawing;
  final Offset? currentPosition;

  SelectionPainter(this.points, this.brushSize, this.isDrawing, this.currentPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(isDrawing ? 0.7 : 0.5)
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, brushSize / 2, paint);
    }

    if (isDrawing && currentPosition != null) {
      canvas.drawCircle(currentPosition!, brushSize / 2, paint..color = Colors.red.withOpacity(0.3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
