import 'package:flutter/material.dart';

class Student {
  final String? id;
  final String name;
  final int grade;
  final String strand;
  final String section;
  final String subject;
  final String time;
  final String password;
  
  // Simulation fields
  String logText;
  String status;
  Color statusColor;

  Student({
    this.id,
    required this.name,
    this.grade = 0,
    this.strand = '',
    required this.section,
    this.subject = '',
    this.time = '',
    this.password = '',
    this.logText = 'NOT LOGGED IN',
    this.status = 'PENDING',
    this.statusColor = Colors.grey,
  });

  factory Student.fromMap(Map<dynamic, dynamic> map) {
    // ── KEY NORMALIZATION ──────────────────────────────────────────────────
    // Firebase entries sometimes have keys with spaces (e.g. "grade " or
    // " section") due to manual data entry in the console. We normalize all
    // keys by trimming whitespace so lookups are reliable regardless.
    final clean = <String, dynamic>{};
    for (final entry in map.entries) {
      clean[entry.key.toString().trim()] = entry.value;
    }

    // ── grade ──────────────────────────────────────────────────────────────
    final rawGrade = clean['grade'];
    int parsedGrade = 0;
    if (rawGrade is int) {
      parsedGrade = rawGrade;
    } else if (rawGrade != null) {
      parsedGrade = int.tryParse(rawGrade.toString().trim()) ?? 0;
    }

    // ── strand ─────────────────────────────────────────────────────────────
    final rawStrand = clean['strand'];
    final parsedStrand = rawStrand != null
        ? rawStrand.toString().trim()
        : '';

    // ── section ────────────────────────────────────────────────────────────
    final rawSection = clean['section'];
    final parsedSection =
        (rawSection == null || rawSection.toString().trim().isEmpty)
            ? 'No Section'
            : rawSection.toString().trim();

    // ── subject ────────────────────────────────────────────────────────────
    final rawSubject = clean['subject'] ?? clean['assignedSubject'];
    final parsedSubject =
        rawSubject != null ? rawSubject.toString().trim() : '';

    // ── time ───────────────────────────────────────────────────────────────
    final rawTime = clean['time'] ?? clean['assignedTime'];
    final parsedTime =
        rawTime != null ? rawTime.toString().trim() : '';

    // ── name ───────────────────────────────────────────────────────────────
    final parsedName = clean['name']?.toString().trim() ?? '';

    // ── password ───────────────────────────────────────────────────────────
    final parsedPassword = clean['password']?.toString().trim() ?? '';

    return Student(
      id      : clean['_id']?.toString() ?? clean['id']?.toString(),
      name    : parsedName,
      grade   : parsedGrade,
      strand  : parsedStrand,
      section : parsedSection,
      subject : parsedSubject,
      time    : parsedTime,
      password: parsedPassword,
    );
  }
}