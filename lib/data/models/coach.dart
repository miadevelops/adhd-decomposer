import 'dart:math';

import 'package:flutter/material.dart';

/// AI Coach personality types for different moods/preferences
enum CoachType {
  zen,        // Calm, mindful
  cheerleader, // High energy, enthusiastic
  drill,      // No-nonsense, direct
  friend,     // Warm, casual
  default_,   // Standard balanced
}

/// Represents an AI Coach personality with unique messages and style
class Coach {
  final CoachType type;
  final String name;
  final String avatar;  // Emoji (legacy, for text display)
  final IconData icon;  // Material icon for consistent cross-platform display
  final String tagline;
  final List<String> completionMessages;
  final List<String> stuckMessages;
  final List<String> greetings;
  final String promptStyle; // For AI decomposition tone

  const Coach({
    required this.type,
    required this.name,
    required this.avatar,
    required this.icon,
    required this.tagline,
    required this.completionMessages,
    required this.stuckMessages,
    required this.greetings,
    required this.promptStyle,
  });
  
  static final Random _random = Random();

  /// Picked once per app launch so the greeting doesn't change every time
  /// the screen rebuilds.
  static final int _sessionGreetingSeed = _random.nextInt(1 << 16);

  /// Get a random completion message
  String getRandomCompletionMessage() {
    return completionMessages[_random.nextInt(completionMessages.length)];
  }
  
  /// Get a random stuck message
  String getRandomStuckMessage() {
    return stuckMessages[_random.nextInt(stuckMessages.length)];
  }
  
  /// Get this session's greeting (stable across rebuilds, varies per launch)
  String getRandomGreeting() {
    return greetings[_sessionGreetingSeed % greetings.length];
  }
}
