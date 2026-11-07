class AppStrings {
  // App
  static const String appName = 'Tiny Steps';
  static const String appTagline = 'Break it down. Get it done.';
  
  // Home
  static const String newTask = 'New Task';
  static const String yourTasks = 'Your Tasks';
  static const String noTasksYet = 'No tasks yet';
  static const String startByAdding = 'Start by adding a task to break down';
  
  // Task Input
  static const String whatNeedsToBeDone = "What needs to be done?";
  static const String taskPlaceholder = "e.g., Clean the kitchen";
  static const String breakItDown = "Break It Down";
  static const String decomposing = "Breaking it down...";
  
  // Execution
  static const String letsDoThis = "Let's do this!";
  static const String step = "Step";
  static const String of_ = "of";
  static const String done = "Done!";
  static const String skip = "Skip";
  static const String imStuck = "I'm stuck";
  static const String takeABreak = "Take a break";
  static const String startTimer = "Start Timer";
  static const String pause = "Pause";
  static const String resume = "Resume";
  
  // Celebration
  static const String amazing = "Amazing!";
  static const String youDidIt = "You did it!";
  static const String taskComplete = "Task Complete!";
  static const String backToTasks = "Back to Tasks";
  static const String allStepsSkippedTitle = "That's okay";
  static const String allStepsSkippedMessage =
      "You skipped every step this time. Some days are like that. Come back to it whenever you're ready.";
  
  // Settings
  static const String settings = "Settings";
  static const String appearance = "Appearance";
  static const String darkMode = "Dark Mode";
  static const String sounds = "Sounds";
  static const String enableSounds = "Enable Sounds";
  static const String about = "About";
  
  // Coach
  static const String aiCoach = "AI Coach";
  static const String meetYourCoaches = "Meet Your Coaches";
  static const String chooseYourCoach = "Choose Your Coach";
  static const String coachDescription = "Different coaching styles for different moods";
  
  // Errors
  static const String somethingWentWrong = "Something went wrong";
  static const String tryAgain = "Try Again";
  static const String noInternet = "No internet connection";
}

/// Default encouragement messages (used as fallback)
/// The app now primarily uses Coach-specific messages
class Encouragements {
  static const List<String> stepComplete = [
    "Nice work!",
    "You're doing great!",
    "One step closer!",
    "Look at you go!",
    "Tiny wins add up!",
    "Keep it up!",
    "Awesome!",
    "Crushing it!",
    "That wasn't so hard!",
    "Progress!",
  ];
  
  static const List<String> taskComplete = [
    "You did it! Amazing!",
    "Task crushed!",
    "Look what you accomplished!",
    "That's how it's done!",
    "You're unstoppable!",
    "Victory!",
    "Mission accomplished!",
  ];
  
  static const List<String> stuckHelp = [
    "Let's break it down even smaller.",
    "No worries, let's make it easier.",
    "Here are some smaller steps to try.",
    "Sometimes tasks need more breaking down.",
  ];
}
