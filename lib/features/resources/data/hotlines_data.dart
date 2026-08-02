import 'package:flutter/material.dart';

class HotlineEntry {
  const HotlineEntry({required this.name, required this.description, required this.phone});

  final String name;
  final String description;
  final String phone;
}

class SafetyGuide {
  const SafetyGuide({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> steps;
}

// NOTE: these are placeholder/sample numbers for development only — verify
// real VAWC desk, PNP, and DSWD hotline numbers with Barangay Camino Nuevo
// before this ships to real users. A wrong number here could cost someone
// time in an actual emergency, so don't skip this before deployment.
const List<HotlineEntry> kHotlines = [
  HotlineEntry(
    name: 'VAWC Desk — Brgy. Camino Nuevo',
    description: 'Barangay Violence Against Women & Children desk',
    phone: '0917 000 0000',
  ),
  HotlineEntry(
    name: 'PNP Women & Children Protection',
    description: 'National hotline',
    phone: '(02) 8532 6690',
  ),
  HotlineEntry(
    name: 'DSWD Hotline',
    description: 'Social welfare & emergency assistance',
    phone: '8888',
  ),
];

const List<SafetyGuide> kSafetyGuides = [
  SafetyGuide(
    id: 'g1',
    icon: Icons.health_and_safety_outlined,
    title: 'After an incident: preserving evidence',
    subtitle: 'What to keep, what to photograph',
    steps: [
      'Do not wash or discard clothing involved in the incident.',
      'Photograph visible injuries in good lighting before they heal.',
      'Keep any messages, call logs, or objects related to the incident.',
      "Report as soon as it's safe to do so — details fade over time.",
    ],
  ),
  SafetyGuide(
    id: 'g2',
    icon: Icons.explore_outlined,
    title: 'If you feel unsafe right now',
    subtitle: 'Immediate steps before help arrives',
    steps: [
      'Move to a room with a lock or exit if possible.',
      'Use the SOS button — it shares your location automatically.',
      'Stay on the line if a responder calls back.',
      "If you can't speak safely, texting your Tanod contact is fine.",
    ],
  ),
];
