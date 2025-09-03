import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Document Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _imageFile;
  String _extractedText = '';
  bool _isScanning = false;

  Future<void> _pickImageFromGallery() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      try {
        final pickedFile =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          setState(() {
            _imageFile = File(pickedFile.path);
            _extractedText = ''; // Clear previous OCR results
          });
        }
      } catch (e) {
        _showSnackBar('Failed to pick image: $e');
      }
    } else {
      _showSnackBar('Gallery permission is required to select images.');
    }
  }

  Future<void> _scanDocument() async {
    var cameraStatus = await Permission.camera.request();
    if (cameraStatus.isGranted) {
      try {
        List<String> imagePaths =
            await CunningDocumentScanner.getPictures() ?? [];
        if (imagePaths.isNotEmpty) {
          setState(() {
            _imageFile = File(imagePaths.first);
            _extractedText = ''; // Clear previous OCR results
          });
        }
      } catch (e) {
        _showSnackBar('Failed to scan document: $e');
      }
    } else {
      _showSnackBar('Camera permission is required to scan documents.');
    }
  }

  Future<void> _performOcr() async {
    if (_imageFile == null) {
      _showSnackBar('No image selected!');
      return;
    }

    setState(() {
      _isScanning = true;
      _extractedText = '';
    });

    try {
      final inputImage = InputImage.fromFilePath(_imageFile!.path);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      setState(() {
        _extractedText = recognizedText.text;
      });
      textRecognizer.close();
    } catch (e) {
      _showSnackBar('Error during text recognition: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _shareImage() {
    if (_imageFile != null) {
      Share.shareXFiles([XFile(_imageFile!.path)], text: 'Scanned Document');
    } else {
      _showSnackBar('Scan an image first to share it.');
    }
  }

  void _shareText() {
    if (_extractedText.isNotEmpty) {
      Share.share(_extractedText, subject: 'Extracted Text');
    } else {
      _showSnackBar('Extract text first to share it.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Document Scanner'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Image Display Area ---
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        'Scan a document to get started',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            
            // --- Primary Action Buttons: Scan & Gallery ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _scanDocument,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // --- Conditional Action Buttons: OCR & Share Image ---
            if (_imageFile != null) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   // OCR Button
                  FilledButton.icon(
                    onPressed: _performOcr,
                    icon: const Icon(Icons.text_fields_rounded),
                    label: const Text('Extract Text'),
                     style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                  ),
                  // Share Image Button
                  OutlinedButton.icon(
                    onPressed: _shareImage,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share Image'),
                     style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                  )
                ],
              ),
              const SizedBox(height: 20),
            ],

            // --- OCR Result Area ---
            if (_isScanning)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Extracting Text...'),
                  ],
                ),
              ),
            if (_extractedText.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Extracted Text:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: _shareText,
                            tooltip: 'Share Extracted Text',
                          ),
                        ],
                      ),
                      const Divider(height: 10),
                      SelectableText(_extractedText),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

