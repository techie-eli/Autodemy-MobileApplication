import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/theme/app_theme.dart';

class OCRScannerScreen extends StatefulWidget {
  final List<String> studentNames;
  const OCRScannerScreen({super.key, required this.studentNames});

  @override
  State<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends State<OCRScannerScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  File? _image;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickAndProcessImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isProcessing = true;
      });

      try {
        final inputImage = InputImage.fromFile(_image!);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        
        String? matchedName;
        final fullText = recognizedText.text.toUpperCase();

        for (String name in widget.studentNames) {
          final upperName = name.toUpperCase();
          // Check for exact name or components of the name (e.g. Surname)
          final parts = upperName.split(',');
          bool match = false;
          if (fullText.contains(upperName)) {
            match = true;
          } else if (parts.isNotEmpty && fullText.contains(parts[0].trim())) {
             // If surname matches, it's a strong candidate
             match = true;
          }

          if (match) {
            matchedName = name;
            break;
          }
        }

        if (matchedName != null) {
          if (mounted) {
            _showMatchDialog(matchedName);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No matching student name found on the ID.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OCR Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  void _showMatchDialog(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Student ID Matched'),
        content: Text('Scanned ID belongs to:\n\n$name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('RETRY')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, name);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR ID SCANNER'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                ),
                child: _image != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.file(_image!, fit: BoxFit.cover))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('Position the ID card within frame', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
              ),
              const SizedBox(height: 40),
              if (_isProcessing)
                const CircularProgressIndicator(color: Colors.teal)
              else
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _pickAndProcessImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                    label: const Text('SCAN PHYSICAL ID', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Uses OCR technology to detect the name on the physical NU-D ID card for students without mobile access.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
