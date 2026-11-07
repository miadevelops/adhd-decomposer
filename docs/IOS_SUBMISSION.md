# iOS App Store Submission Guide

This document outlines the requirements and steps for submitting **Tiny Steps** to the Apple App Store.

## Prerequisites

### 1. Apple Developer Account
- **Cost:** $99/year (individual) or $299/year (organization)
- **Enrollment:** https://developer.apple.com/programs/enroll/
- **Timeline:** Individual accounts are usually approved within 48 hours
- **D-U-N-S Number:** Required for organization accounts (free, takes 1-2 weeks)

### 2. Required Information
Before starting, gather:
- [ ] App name: **Tiny Steps**
- [ ] Bundle ID: `com.tinysteps.app`
- [ ] Privacy Policy URL (hosted)
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] App description (4000 characters max)
- [ ] Keywords (100 characters max, comma-separated)
- [ ] App category: Productivity (primary), Health & Fitness (secondary)

## App Store Connect Setup

### 1. Create App Record
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - **Platforms:** iOS
   - **Name:** Tiny Steps
   - **Primary Language:** English (U.S.)
   - **Bundle ID:** com.tinysteps.app
   - **SKU:** tinysteps-ios-001

### 2. App Information
- **Category:** Productivity
- **Secondary Category:** Health & Fitness
- **Content Rights:** Does not contain third-party content
- **Age Rating:** Complete questionnaire (likely 4+)

### 3. Pricing and Availability
- **Price:** Free (with in-app purchases)
- **Availability:** All territories (or select specific)
- **Pre-Orders:** Optional

## Required Screenshots

App Store requires screenshots for each device size you support.

### iPhone Screenshots (Required)
| Device | Size (pixels) | Required |
|--------|---------------|----------|
| 6.7" (iPhone 15 Pro Max) | 1290 × 2796 | ✓ |
| 6.5" (iPhone 14 Plus) | 1284 × 2778 | ✓ |
| 5.5" (iPhone 8 Plus) | 1242 × 2208 | Optional |

### iPad Screenshots (If supporting iPad)
| Device | Size (pixels) | Required |
|--------|---------------|----------|
| 12.9" (iPad Pro 6th gen) | 2048 × 2732 | ✓ |
| 11" (iPad Pro 4th gen) | 1668 × 2388 | Optional |

### Screenshot Guidelines
- **Minimum:** 3 screenshots, **Maximum:** 10
- **Format:** PNG or JPEG (no alpha)
- **Content:** Show actual app UI
- **Text overlays:** Allowed and recommended for explaining features

### Recommended Screenshots
1. **Task Decomposition** - Show the AI breaking down a task
2. **Mini Tasks List** - Clean task list with checkmarks
3. **Progress/Rewards** - Confetti celebration or achievement
4. **Ambient Mode** - Focus timer with calming visuals
5. **Routines** - A morning or evening routine with its streak

## App Preview Videos (Optional but Recommended)
- **Duration:** 15-30 seconds
- **Resolution:** Same as screenshot sizes
- **Format:** H.264, .mov or .mp4
- **Audio:** Optional

## Required Documents

### 1. Privacy Policy
**URL Required for Submission**

Must include:
- What data you collect
- How data is used
- Third-party services (analytics, etc.)
- User data rights (GDPR, CCPA)
- Contact information

See: `docs/PRIVACY_POLICY.md` (needs to be hosted at a public URL)

### 2. Terms of Service
Recommended for apps with:
- In-app purchases
- User accounts
- User-generated content

See: `docs/TERMS_OF_SERVICE.md`

## App Review Guidelines Considerations

### 1. ADHD/Mental Health Claims
- **Do NOT** claim the app treats, diagnoses, or cures ADHD
- **DO** frame as a "productivity tool" or "task management app"
- Use phrases like:
  - "Designed with ADHD-friendly features"
  - "Helps break down overwhelming tasks"
  - "Created to reduce task paralysis"
- **Avoid:** "ADHD treatment", "therapy", "medical advice"

### 2. In-App Purchases
- Must clearly describe what user gets
- Restore purchases must work
- No "bait and switch" between free/paid features
- Subscription terms must be clear

### 3. Privacy
- Request only necessary permissions
- Explain why each permission is needed (done in Info.plist)
- No data collection without disclosure

### 4. Performance
- App must not crash
- Must work without network (offline functionality)
- Must handle edge cases gracefully

## Build & Upload Process

### 1. Configure Signing
```bash
# In Xcode, set up signing:
# Runner > Signing & Capabilities > Team: Your Apple Developer Team
# Automatically manage signing: Yes
```

### 2. Create Archive
```bash
# Build release version
flutter build ios --release

# Or use Xcode:
# Product > Archive
```

### 3. Upload to App Store Connect
**Option A: Xcode Organizer**
1. Open Xcode > Window > Organizer
2. Select archive > Distribute App
3. Choose "App Store Connect"
4. Upload

**Option B: xcrun altool (CLI)**
```bash
xcrun altool --upload-app -f "build/ios/ipa/adhd_decomposer.ipa" -u "your@email.com" -p "app-specific-password"
```

**Option C: Transporter App**
- Download from Mac App Store
- Drag and drop .ipa file

### 4. Submit for Review
1. Go to App Store Connect > Your App
2. Add build to version
3. Fill in "What's New" notes
4. Submit for Review

## TestFlight Setup

### Internal Testing
- Up to 100 testers
- No review required
- Immediate access after upload

### External Testing
- Up to 10,000 testers
- Requires Beta App Review (1-2 days)
- Public link option available

### TestFlight Process
1. Upload build to App Store Connect
2. Build processes (15-30 minutes)
3. Add testers (internal or external)
4. Testers receive invitation email
5. Install via TestFlight app

## Common Rejection Reasons

1. **Crashes/Bugs** - Test thoroughly!
2. **Incomplete metadata** - Fill everything out
3. **Placeholder content** - No "lorem ipsum" or test data
4. **Missing privacy policy** - Must be accessible
5. **Misleading description** - Match app functionality
6. **Login required without demo** - Provide test account or skip
7. **In-app purchase issues** - Test restore purchases

## Review Timeline
- **Average:** 24-48 hours
- **First submission:** May take longer (1-3 days)
- **Expedited review:** Request available for critical fixes

## Checklist Before Submission

### App Functionality
- [ ] All features work on iOS 14+
- [ ] No crashes on any screen
- [ ] Routines run and track streaks
- [ ] Notifications work
- [ ] In-app purchases work
- [ ] Restore purchases works
- [ ] Offline mode works

### App Store Assets
- [ ] App icon (1024x1024)
- [ ] Screenshots (6.7", 6.5" minimum)
- [ ] App preview video (optional)

### Metadata
- [ ] App description
- [ ] Keywords
- [ ] What's New text
- [ ] Support URL
- [ ] Privacy Policy URL

### Legal
- [ ] Privacy Policy published
- [ ] Terms of Service (if needed)
- [ ] No medical claims

### Technical
- [ ] Bundle ID matches everywhere
- [ ] Version number set
- [ ] Build number unique
- [ ] Signing configured
- [ ] Archive created successfully

## Post-Submission

### If Approved
🎉 App goes live within 24 hours (or on scheduled date)

### If Rejected
1. Read rejection reason carefully
2. Fix issues
3. Reply in Resolution Center
4. Submit new build if needed

## Useful Links

- [App Store Connect](https://appstoreconnect.apple.com)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)

## Contact

For submission help or questions, contact the development team.
