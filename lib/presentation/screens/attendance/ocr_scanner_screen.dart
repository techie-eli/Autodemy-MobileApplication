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
  String _debugText = ''; // shows what OCR actually read

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // FIX 1: Strip numbers, single letters (initials like "B."),
  // short noise words, and ID numbers before matching.
  // ─────────────────────────────────────────────────────────────
String normalizeName(String name) {
  final parts = name
      .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1)
      .toList();
  parts.sort();
  return parts.join(' ');
}

  String normalizeNameStr(String name) {
    final parts = name
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
    parts.sort();
    return parts.join(' ');
  }

  // Jaccard similarity on word sets
  double similarityScore(String a, String b) {
    final setA = a.split(' ').where((w) => w.isNotEmpty).toSet();
    final setB = b.split(' ').where((w) => w.isNotEmpty).toSet();
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  // ─────────────────────────────────────────────────────────────
  // FIX 2: Extract only the likely name lines from OCR output.
  // ID cards have numbers, school names, labels — filter those out.
  // A "name line" has 2+ words that are all alphabetic.
  // ─────────────────────────────────────────────────────────────
  String extractNameLines(String rawText) {
    final lines = rawText.split('\n');
    final nameLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip lines that are mostly numbers (ID numbers, years)
      if (RegExp(r'^\d').hasMatch(trimmed)) continue;

      // Skip lines with common non-name keywords
      final lower = trimmed.toLowerCase();
      if (lower.contains('school') ||
          lower.contains('university') ||
          lower.contains('college') ||
          lower.contains('student') ||
          lower.contains('senior') ||
          lower.contains('high') ||
          lower.contains('id') ||
          lower.contains('valid')) continue;

      // Keep lines that have at least one word with 2+ letters
      final words = trimmed.split(RegExp(r'\s+'));
      final nameWords = words.where((w) => RegExp(r'^[a-zA-Z]{2,}').hasMatch(w));
      if (nameWords.isNotEmpty) {
        nameLines.add(trimmed);
      }
    }

    return nameLines.join(' ');
  }

  Future<void> _pickAndProcessImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90, // FIX 3: higher quality = better OCR
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isProcessing = true;
        _debugText = '';
      });

      try {
        final inputImage = InputImage.fromFile(_image!);
        final recognizedText = await _textRecognizer.processImage(inputImage);

        // FIX 2: extract only name-like lines before matching
        final cleanedText = extractNameLines(recognizedText.text);
        final normalizedScan = normalizeNameStr(cleanedText);

        setState(() {
          // Show debug info so you can see what OCR read
          _debugText = 'OCR read: "${recognizedText.text.trim()}"\nCleaned: "$cleanedText"';
        });

        String? matchedName;
        double bestScore = 0.0;
        // FIX 4: lower threshold to 0.3 since initials are stripped
        const double threshold = 0.3;

        for (String name in widget.studentNames) {
          final normalizedName = normalizeNameStr(name);
          final score = similarityScore(normalizedScan, normalizedName);

          if (score > bestScore && score >= threshold) {
            bestScore = score;
            matchedName = name;
          }
        }

        if (matchedName != null) {
          if (mounted) {
            _showMatchDialog(matchedName, bestScore);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No match found. OCR saw: "$cleanedText"\n'
                  'Check if name spelling matches the roster.',
                ),
                duration: const Duration(seconds: 5),
              ),
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

  void _showMatchDialog(String name, double score) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Student ID Matched'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scanned ID belongs to:\n\n$name'),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(score * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: score >= 0.6 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Position the ID card within frame',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),

              // Debug panel — shows what OCR actually read
              if (_debugText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _debugText,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                    label: const Text(
                      'SCAN PHYSICAL ID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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