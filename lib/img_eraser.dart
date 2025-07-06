import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';


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
 
 void initState() async {
    super.initState();
    // await InpaintingService.instance.initializeOrt('assets/lama_fp32.onnx');
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

      // Convert points to the required format
      final polygons = selectedPoints.map((point) {
        return {
          'x': (point.dx * scaleX).toDouble(),
          'y': (point.dy * scaleY).toDouble(),
        };
      }).toList();

      // Perform inpainting with the correct parameter format
      final uiImage = await InpaintingService.instance.inpaint(
        original!,
        [polygons], // List of polygons where each polygon is a list of points
      );

      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      setState(() {
        erased = byteData!.buffer.asUint8List();
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
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
    setState(() {
      selectedPoints.clear();
    });
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
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
                                  painter: SelectionPainter(
                                    selectedPoints,
                                    brushSize,
                                    isDrawing,
                                    currentPosition,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          "Tap 'Choose' to select an image",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.delete_sweep),
                      label: Text("Erase"),
                      onPressed: erase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.save),
                      label: Text("Save"),
                      onPressed: saveImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),),
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
      ..strokeWidth = brushSize
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw the path
    if (points.length > 1) {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }

    // Draw a circle at the current position if drawing
    if (isDrawing && currentPosition != null) {
      canvas.drawCircle(
        currentPosition!,
        brushSize / 2,
        paint..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}