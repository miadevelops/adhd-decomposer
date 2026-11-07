# ADHD Task Decomposer - Product Requirements Document

**Version:** 1.0  
**Date:** February 6, 2026  
**Status:** MVP Development

---

## Overview

An ADHD-friendly mobile app that uses AI to break down overwhelming tasks into small, actionable steps and guides users through execution one step at a time with dopamine-friendly feedback.

### Problem Statement

People with ADHD struggle with:
- **Task overwhelm**: Big tasks feel impossible, causing paralysis
- **Time blindness**: Can't estimate task duration, lose track of time
- **Executive dysfunction**: Knowing what to do ≠ being able to start
- **Notification fatigue**: Traditional reminders get ignored

Existing solutions either stop at task breakdown (Goblin Tools) or are too complex/gamified (Habitica).

### Solution

A simple, calming app that:
1. Takes a task and AI-decomposes it into tiny actionable steps
2. Shows ONE step at a time (no overwhelming lists)
3. Provides timers and gentle guidance
4. Celebrates every small win with dopamine hits (confetti, sounds, encouragement)
5. Never guilts the user for skipping or taking breaks

---

## Target Audience

**Primary:** Adults (18-45) with ADHD or ADHD-like executive function challenges
**Secondary:** Anyone who struggles with task overwhelm and procrastination

**User Persona:** 
- Has tried multiple to-do apps that didn't stick
- Feels overwhelmed by big tasks
- Responds well to visual progress and celebration
- Prefers simple tools over feature-rich complexity

---

## MVP Features (v1.0)

### 1. Task Input & AI Decomposition
- Single text input for task ("Clean the kitchen")
- AI generates 5-12 actionable steps with time estimates
- Each step is ONE physical action (verb-first)
- Total estimated time displayed
- "I'm stuck" option breaks step down further

**API:** OpenAI GPT-4o-mini for cost efficiency

### 2. Execution Mode (Focus View)
- Full-screen single step display
- Large, satisfying "Done" button
- Optional countdown timer (5/10/15/25 min presets)
- Progress indicator (step 3 of 8)
- "Skip" and "I'm stuck" buttons (no judgment)

### 3. Celebration System
- Confetti animation on step completion
- Sound effects (toggleable)
- Encouraging messages (rotating pool)
- Haptic feedback
- Task completion celebration (bigger confetti burst)

### 4. Task List View
- See all tasks and their steps
- Edit/reorder steps manually
- Delete tasks
- Quick-add new task

### 5. Settings
- Dark/Light mode
- Sound effects toggle
- Notification preferences
- API key input (for unlimited use)

---

## Technical Architecture

### Stack
- **Framework:** Flutter 3.24+
- **State Management:** Provider/Riverpod
- **Local Storage:** Hive (tasks, settings)
- **AI:** OpenAI API (GPT-4o-mini)
- **Animations:** Confetti package + Lottie

### Project Structure
```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   └── utils/
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
├── presentation/
│   ├── screens/
│   ├── widgets/
│   └── providers/
```

### Key Dependencies
- provider / riverpod
- http
- hive / hive_flutter
- confetti
- audioplayers
- google_fonts

---

## User Flows

### Flow 1: Decompose a Task
1. Open app → Home screen
2. Tap "New Task" → Enter task description
3. Tap "Break it down" → Loading animation
4. AI returns steps → Review screen
5. Tap "Start" → Enter Execution Mode

### Flow 2: Execute Steps
1. See single step + timer option
2. Complete step → Tap "Done"
3. Celebration → Next step appears
4. Repeat until all steps done
5. Final celebration → Return to home

### Flow 3: Handle Being Stuck
1. On any step → Tap "I'm stuck"
2. AI suggests 2-3 smaller steps
3. User picks one → Continues

---

## Design Principles

1. **Calm, not clinical**: Warm colors, friendly language
2. **One thing at a time**: Never show overwhelming lists in focus mode
3. **Celebrate everything**: Every small win gets recognized
4. **No guilt**: Skip button always available, no penalties
5. **Accessible**: Large touch targets, good contrast, dyslexia-friendly fonts

### Color Palette
- Primary: Soft teal (#4ECDC4)
- Secondary: Warm coral (#FF6B6B)
- Background: Off-white (#FAFAFA) / Dark: #1A1A2E
- Success: Soft green (#7BC47F)
- Text: Charcoal (#2D3436) / Dark: #F5F5F5

### Typography
- Headings: Nunito (rounded, friendly)
- Body: Inter (clean, readable)

---

## MVP Milestones

### Phase 1: Foundation (Day 1-2)
- [ ] Project setup (Flutter, dependencies)
- [ ] Data models (Task, Step)
- [ ] Basic navigation structure
- [ ] Theme setup (light/dark)

### Phase 2: Core Features (Day 3-5)
- [ ] AI service integration
- [ ] Task input screen
- [ ] Decomposition result screen
- [ ] Local storage (Hive)

### Phase 3: Execution Mode (Day 6-8)
- [ ] Focus view with single step
- [ ] Timer functionality
- [ ] "I'm stuck" feature
- [ ] Step navigation

### Phase 4: Celebrations (Day 9-10)
- [ ] Confetti animations
- [ ] Sound effects
- [ ] Encouraging messages
- [ ] Haptic feedback

### Phase 5: Polish (Day 11-14)
- [ ] Settings screen
- [ ] Task list management
- [ ] Edge cases and error handling
- [ ] Testing on devices
- [ ] App icons and splash screen

---

## Success Metrics (Post-Launch)

- **Engagement:** DAU/MAU ratio > 30%
- **Retention:** 7-day retention > 40%
- **Completion:** Task completion rate > 60%
- **Satisfaction:** App Store rating > 4.5

---

## Monetization (Post-MVP)

**Freemium Model:**
- Free: 5 AI breakdowns total (including "I'm stuck" breakdowns), basic celebrations
- Premium ($4.99/mo): Unlimited, all sounds/themes, no ads, stats

**Alternative:** One-time purchase $9.99 (ADHD users prefer no subscriptions)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| AI costs at scale | Cache common tasks, rate limit, use GPT-4o-mini |
| Bad AI outputs | Feedback button, prompt refinement |
| Low retention | Focus on celebration/dopamine mechanics |
| Competition | Move fast, nail UX |

---

## Open Questions

1. App name? Options: TaskFlow, Chunk It, Tiny Steps, Decompose, FlowState
2. Mascot/character? Could add personality but also complexity
3. Onboarding flow length?

---

## Next Steps

1. Create Flutter project
2. Implement data models
3. Build AI service
4. Create basic UI screens
5. Iterate rapidly

---

*Document maintained by Mia. Last updated: Feb 6, 2026*
