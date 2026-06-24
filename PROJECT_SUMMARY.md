# VISAIA - Flutter Project Summary

**Last Updated:** June 20, 2026  
**Version:** 1.0.0

---

## 1. Project Purpose

### What the App Does
**VISAIA** is a comprehensive farm management and pest monitoring application designed to help farmers manage their agricultural operations through digital tools and AI-powered pest detection.

### Target Users
- **Primary:** Smallholder farmers and agricultural practitioners
- **Secondary:** Farm managers and agricultural technicians
- **Admin Users:** Government/organizational agricultural extension officers (for account verification)

### Main Business Process
The app facilitates a complete farming lifecycle:
1. **Setup Phase:** Farmers define their farm boundaries, create fields, and assign crops
2. **Cycle Management:** Create and manage crop cycles with planting/harvest dates
3. **Daily Operations:** Log routine farm activities (irrigation, fertilization, harvesting)
4. **Monitoring:** Perform field scouting and pest detection via AI image analysis
5. **Reporting:** View historical logs, income tracking, and performance analytics
6. **Planning:** Inspect traps and track pests across growing cycles

---

## 2. Technology Stack

### Flutter & Dart
- **Flutter Version:** 3.9.2+
- **Language:** Dart 3.9.2+

### State Management
- **Provider** (v6.1.5+1)
  - Used for global state: `FarmProvider` manages active farm context across all screens
  - Single `ChangeNotifier` for cross-screen state sharing

### Database & Cloud Storage
- **Firebase Cloud Firestore**
  - Primary database for all user data (real-time, NoSQL)
  - Storage bucket: `visaia.firebasestorage.app`
- **Firebase Storage**
  - Stores annotated pest images and processed photos

### Authentication
- **Firebase Authentication**
  - Email/password authentication
  - Admin-verified account system (verification status stored in Firestore)
  - Sessions managed by Firebase (automatic token refresh)

### APIs & External Services
- **Custom Backend API** (ngrok endpoint)
  - `https://automatically-unbefriended-misty.ngrok-free.dev`
  - Pest detection and AI image analysis
  - Returns bounding boxes, confidence scores, risk levels, and treatment recommendations
- **Google Geolocation Services**
  - Latitude/Longitude data for farms and fields
- **Google Fonts**
  - Custom font: `Inter` for consistent typography

### Key Third-Party Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^4.5.0 | Firebase initialization |
| `cloud_firestore` | ^6.1.3 | Cloud database |
| `firebase_auth` | ^6.2.0 | Authentication |
| `provider` | ^6.1.5+1 | State management |
| `flutter_map` | ^8.2.2 | Interactive maps with field visualization |
| `latlong2` | ^0.9.1 | Latitude/Longitude handling |
| `geolocator` | ^14.0.2 | Device GPS location access |
| `geocoding` | ^4.0.0 | Address geocoding |
| `image_picker` | ^1.2.1 | Camera/gallery image capture |
| `camera` | ^0.11.3+1 | Direct camera access |
| `image` | ^4.7.2 | Image processing |
| `flutter_image_compress` | ^2.3.0 | Image compression |
| `file_picker` | ^10.3.10 | File selection |
| `path_provider` | ^2.1.0 | File system access |
| `http` | ^1.6.0 | HTTP requests to pest detection API |
| `shared_preferences` | ^2.5.4 | Local persistent storage |
| `intl` | ^0.20.2 | Internationalization and date formatting |
| `share_plus` | ^12.0.1 | Share data to other apps |
| `google_fonts` | ^8.0.1 | Google Fonts integration |
| `flutter_markdown` | ^0.7.7+1 | Markdown rendering |
| `iconify_flutter` | ^0.0.7 | Icon library |
| `phosphor_flutter` | ^2.1.0 | Phosphor icon set |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

---

## 3. Folder Structure & Architecture

### Project Structure Overview
```
visaia/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── firebase_options.dart        # Firebase configuration
│   ├── core/
│   │   ├── models/                  # Data models
│   │   └── providers/               # State management (Provider)
│   ├── screens/                     # UI screens organized by feature
│   ├── services/                    # Business logic & API integration
│   ├── utils/                       # Utility functions
│   └── widgets/                     # Reusable components
├── android/                         # Android-specific config
├── ios/                             # iOS-specific config
├── web/                             # Web platform files
├── macos/                           # macOS platform files
├── linux/                           # Linux platform files
├── windows/                         # Windows platform files
└── assets/
    └── images/                      # PNG images (logos, backgrounds, onboarding)
```

### Architecture Pattern: **MVCS (Model-View-Controller-Service)**

- **Models** (`core/models/`): Data classes representing Firestore documents
- **Views** (`screens/`): Flutter UI widgets organized by feature
- **Controllers**: Provider-based state management
- **Services** (`services/`): Firebase and API integration logic

### Directory Details

#### `lib/core/models/`
Contains data models that mirror Firestore structure:
- `cycle_model.dart`: Crop cycle with planting/harvest dates, crop variety
- `activity_log.dart`: Farm activities (irrigation, fertilization, harvesting)
- `pest_model.dart`: Pest detection records with severity levels
- `crop_type.dart`: Crop type definitions
- `field_model.dart`: Field/plot information and boundaries

#### `lib/core/providers/`
- `farm_provider.dart`: Global provider managing active farm context across screens

#### `lib/screens/`
Organized by feature/workflow:

| Folder | Purpose |
|--------|---------|
| `auth/` | Login, registration, email verification |
| `onboarding/` | Initial setup (farm creation, field area mapping) |
| `dashboard_screens/` | Main dashboard, notifications, analysis, cycles view, income tracking |
| `logging_screens/` | Daily logs, field scouting, pest upload, trap inspection |
| `monitoring_screens/` | Weekly crop monitoring and risk assessment |
| `cycle_screens/` | Cycle creation, editing, completion, viewing history |
| `map/` | Interactive farm/field visualization with geolocation |
| `profile_screens/` | User settings, account management, support, privacy |
| `report_history/` | Historical data and generated reports |
| `root_screen.dart` | Main navigation hub (bottom tab bar) |

#### `lib/services/`
- `auth_service.dart`: Firebase Auth operations + verification logic
- `firestore_service.dart`: Firestore CRUD operations for monitoring data
- `farm_service.dart`: Farm/field creation with automatic area calculation
- `api_service.dart`: Pest detection AI API integration (HTTP requests)

#### `lib/utils/`
- `geo_utils.dart`: Geographic calculations (area in sqm/acres, boundary processing)

#### `lib/widgets/`
Reusable UI components used across screens

### Data Flow Architecture

```
UI Screen (Widget)
    ↓
Provider (State Management)
    ↓
Service Layer (FirebaseAuth, Firestore, API Service)
    ↓
Firebase SDK / External APIs
    ↓
Cloud Services (Firestore, Firebase Storage, ngrok Backend)
```

---

## 4. Screens and Features

### 4.1 Authentication Screens

#### **Get Started Screen** (`onboarding/get_started_screen.dart`)
- **Purpose:** First-time landing page
- **Navigation:** Routes to Login or Registration
- **Features:** Onboarding carousel, app introduction

#### **Login Screen** (`auth/login_screen.dart`)
- **Purpose:** User authentication
- **Main Widgets:** Form with email/password fields
- **Data Source:** Firebase Auth + Firestore (verification status check)
- **Navigation Flow:** 
  - Valid login → Dashboard
  - Unverified account → Error message
- **Features:** 
  - Email/password validation
  - Account verification check
  - Error handling with user-friendly messages

#### **Registration Screen** (`auth/registration_screen.dart`)
- **Purpose:** New user account creation
- **Main Widgets:** Registration form with email, password, confirmation
- **Data Source:** Firebase Auth + Firestore (`farmers` collection)
- **Features:** 
  - Email validation
  - Password strength validation
  - Admin verification workflow
  - Account status tracking

#### **Auth Gate** (`auth/auth_gate.dart`)
- **Purpose:** Protected route between authenticated/unauthenticated states
- **Logic:** Checks Firebase Auth state, routes accordingly

#### **Verification Form** (`auth/veri_form.dart`)
- **Purpose:** Email verification and admin approval tracking
- **Features:** Status polling, email re-send capability

---

### 4.2 Onboarding Screens

#### **Farm Area Setup** (`onboarding/farm_area_setup.dart`)
- **Purpose:** Define farm boundaries using map
- **Main Widgets:** Interactive map, polygon drawing tools
- **Data Source:** GPS/map data (LatLng coordinates)
- **Navigation Flow:** Map drawing → Field setup
- **Features:** 
  - Geofence creation with multiple points
  - Area calculation (automatic conversion to acres)
  - Save farm to Firestore

#### **Field Area Setup Screen** (`onboarding/field_area_setup_screen.dart`)
- **Purpose:** Create individual fields within farm
- **Main Widgets:** Multiple field creation form, map visualization
- **Data Source:** GPS coordinates, crop type
- **Features:** 
  - Define field boundaries
  - Assign crop types to fields
  - Automatic area calculation

#### **Field Creation** (`onboarding/field_creation.dart`)
- **Purpose:** Detailed field configuration
- **Features:** Crop selection, area input, boundary mapping

#### **Welcome Screen** (`onboarding/welcome_screen.dart`)
- **Purpose:** Post-login welcome screen
- **Features:** User onboarding flow introduction

---

### 4.3 Dashboard Screens

#### **Main Dashboard** (`dashboard_screens/dashboard.dart`)
- **Purpose:** Home screen with overview of farm status
- **Main Widgets:** 
  - Active cycle cards
  - Farm summary statistics
  - Recent activities feed
  - Quick action buttons (add log, view map)
- **Data Source:** Firestore (current cycle, recent logs, pest alerts)
- **Navigation Flow:** Links to cycles, monitoring, logging

#### **Notifications Screen** (`dashboard_screens/notifications.dart`)
- **Purpose:** Alert management (pest alerts, cycle milestones, system notifications)
- **Features:** Notification history, marking read/unread

#### **Full Analysis Screen** (`dashboard_screens/full_analysis.dart`)
- **Purpose:** Comprehensive crop/pest analysis with risk indicators
- **Data Source:** Firestore (pest records, monitoring data)
- **Features:** Risk assessment, threat visualization

#### **Cycles Screen** (`dashboard_screens/cycles_screen.dart`)
- **Purpose:** View all crop cycles (active and completed)
- **Main Widgets:** Cycle cards with status, dates, crop variety
- **Features:** Cycle listing, filtering, quick actions

#### **Threat Details Screen** (`dashboard_screens/threat_details.dart`)
- **Purpose:** Detailed pest/threat information
- **Features:** Risk level, recommendations, treatment options

#### **View Income Screen** (`dashboard_screens/view_income.dart`)
- **Purpose:** Income tracking per cycle
- **Data Source:** Firestore (income records)
- **Features:** Revenue analysis, profitability tracking

---

### 4.4 Logging Screens (Farm Activity Recording)

#### **Daily Log Screen** (`logging_screens/daily_log_screen.dart`)
- **Purpose:** Record routine farm activities
- **Main Widgets:** Form for activity details (type, description, date)
- **Data Source:** Activity types (irrigation, fertilization, pesticide, harvest, other)
- **Navigation Flow:** Activity form → Log created → Back to dashboard
- **Features:** 
  - Timestamp tracking
  - Photo attachment
  - Cycle assignment
  - Activity categorization

#### **Field Scouting Screen** (`logging_screens/field_scouting_screen.dart`)
- **Purpose:** Weekly crop inspection and health assessment
- **Main Widgets:** Scouting form with plant health, pest observations
- **Features:** 
  - Photo capture
  - Crop condition assessment
  - Pest presence tracking
  - Manual notes

#### **Upload Pest Screen** (`logging_screens/upload_pest.dart`)
- **Purpose:** AI-powered pest detection via image upload
- **Main Widgets:** Camera/gallery picker, image preview, upload button
- **Data Source:** Device camera/gallery
- **Navigation Flow:** Image selection → AI analysis → Results display
- **Features:** 
  - Image capture from camera
  - Image selection from gallery
  - Image quality optimization

#### **Analyzing Screen** (`logging_screens/analyzing.dart`)
- **Purpose:** Shows loading/progress during AI pest analysis
- **Features:** Loading animation, progress tracking

#### **Pest Verification Screen** (`logging_screens/pest_verification.dart`)
- **Purpose:** Review and confirm AI-detected pests
- **Main Widgets:** Pest data display, bounding boxes on image, confidence scores
- **Data Source:** API response with pest details
- **Features:** 
  - Accept/reject detection
  - Risk level review
  - Treatment recommendations

#### **Assign Pest Detected** (`logging_screens/assign_pest_detected.dart`)
- **Purpose:** Assign detected pest to a cycle
- **Features:** Cycle selection, pest linking

#### **AI Result** (`logging_screens/ai_result.dart`)
- **Purpose:** Display AI analysis results
- **Features:** Pest name, scientific name, confidence, bounding boxes

#### **Inspect Trap Screen** (`logging_screens/inspect_trap_screen.dart`)
- **Purpose:** Record monitoring trap inspections
- **Features:** Photo capture, trap count tracking, pest identification

#### **Harvest Recording** (`logging_screens/harvest_recording.dart`)
- **Purpose:** Log harvest events
- **Features:** Harvest date, yield quantity, quality notes

#### **Field Scouting Demo** (`logging_screens/field_scouting_demo.dart`)
- **Purpose:** Tutorial/demo for field scouting workflow

---

### 4.5 Monitoring Screens

#### **Monitoring Screen** (`monitoring_screens/monitoring.dart`)
- **Purpose:** Weekly crop monitoring and risk assessment
- **Main Widgets:** 
  - Monitoring checklist
  - Weekly task list
  - Risk threshold calculator
  - Photo documentation
- **Data Source:** Firestore (cycle weeks, daily logs, pest data)
- **Navigation Flow:** Weekly monitoring form → Save data → Next week
- **Features:** 
  - Automated week calculation from planting date
  - Risk scoring system
  - Cumulative threat tracking
  - Photo upload per week
  - Auto-save functionality

---

### 4.6 Cycle Management Screens

#### **Start Cycle Screen** (`cycle_screens/start_cycle.dart`)
- **Purpose:** Create new crop cycle
- **Main Widgets:** Form for cycle details (crop, field, planting date)
- **Features:** Cycle configuration, date selection, field assignment

#### **Cycle Details Screen** (`cycle_screens/cycle_details.dart`)
- **Purpose:** View active cycle information
- **Data Source:** Firestore (cycle document)
- **Features:** Full cycle details, management options

#### **Edit Cycle** (`cycle_screens/edit_cycle.dart`)
- **Purpose:** Modify cycle information
- **Features:** Update crop, dates, or other parameters

#### **Completed Cycle Details** (`cycle_screens/completed_cycle_details.dart`)
- **Purpose:** View historical cycle with income summary
- **Features:** Revenue, expenses, profitability metrics

#### **Record Previous Cycle** (`cycle_screens/record_previous_cycle.dart`)
- **Purpose:** Add historical cycles to system
- **Features:** Backdated cycle creation

---

### 4.7 Map Screen

#### **Map View Screen** (`map/map_screen.dart`)
- **Purpose:** Interactive visualization of farm and fields
- **Main Widgets:** 
  - Flutter Map (OpenStreetMap-based)
  - Field polygons with boundaries
  - Markers for field centers
- **Data Source:** Firestore (farm/field boundaries as LatLng coordinates)
- **Features:** 
  - Zoom and pan controls
  - Field boundary visualization
  - Risk overlay (color-coded threat levels)
  - Location-based marker display
- **Related:** `risk_map.dart` (risk level visualization overlay)

---

### 4.8 Profile & Account Screens

#### **Profile Screen** (`profile_screens/profile_screen.dart`)
- **Purpose:** User account dashboard
- **Main Widgets:** User info, account settings menu
- **Navigation:** Links to settings, help, privacy, FAQs

#### **Manage Account** (`profile_screens/manage_account.dart`)
- **Purpose:** Update user profile information
- **Features:** Edit name, email, contact info

#### **Preferences** (`profile_screens/preferences.dart`)
- **Purpose:** App settings and preferences
- **Features:** Language, notifications, data sync settings

#### **Help and Support** (`profile_screens/help_and_support.dart`)
- **Purpose:** Support and documentation
- **Features:** Help articles, contact support

#### **FAQs Screen** (`profile_screens/faqs_screen.dart`)
- **Purpose:** Frequently asked questions
- **Features:** Searchable FAQ database

#### **Privacy Data Screen** (`profile_screens/privacy_data_screen.dart`)
- **Purpose:** Privacy policy and data handling information
- **Features:** Data deletion, export options

#### **Deletion Confirmation** (`profile_screens/deletion_confirmation_screens.dart`)
- **Purpose:** Account/data deletion workflow
- **Features:** Confirmation dialogs, deletion warnings

---

### 4.9 Report History Screen

#### **Report History** (`report_history/report_history.dart`)
- **Purpose:** View historical logs and generate reports
- **Main Widgets:** Filterable activity history, export options
- **Data Source:** Firestore (all user activity logs)
- **Features:** 
  - Date filtering
  - Activity type filtering
  - Report generation
  - Data export

---

### 4.10 Root Navigation Screen

#### **Root Screen** (`root_screen.dart`)
- **Purpose:** Main app navigation hub
- **Main Widgets:** Bottom tab navigation bar
- **Navigation Items:**
  - **Reports** → Report history
  - **Home** → Main dashboard
  - **Cycle** → Cycles management
  - **Map** → Map view
  - **Profile** → User profile
- **Features:**
  - Floating action button (+ Add Log modal)
  - Bottom modal for logging options (daily log, field scouting, pest upload, trap inspection)

---

## 5. Database Structure

### Firestore Collections Hierarchy

```
users/
├── {userId}/
│   ├── Basic user data (email, name, createdAt)
│   ├── farms/
│   │   └── {farmId}/
│   │       ├── name: String
│   │       ├── acres: Double
│   │       ├── boundaries: Array<{lat, lng}>
│   │       ├── createdAt: Timestamp
│   │       └── ...
│   ├── fields/
│   │   └── {fieldId}/
│   │       ├── farmId: String (reference)
│   │       ├── name: String
│   │       ├── crop: String
│   │       ├── acres: Double
│   │       ├── boundaries: Array<{lat, lng}>
│   │       ├── createdAt: Timestamp
│   │       └── ...
│   ├── cycles/
│   │   └── {cycleId}/
│   │       ├── fieldId: String (reference)
│   │       ├── fieldName: String
│   │       ├── farmId: String (reference)
│   │       ├── cycleName: String
│   │       ├── cropVariety: String
│   │       ├── plantingDate: Timestamp
│   │       ├── harvestDate: Timestamp
│   │       ├── seedDensity: Double
│   │       ├── isCompleted: Boolean
│   │       ├── status: String (active, completed)
│   │       ├── income: Double
│   │       ├── createdAt: Timestamp
│   │       ├── weeks/
│   │       │   └── {weekId}/
│   │       │       ├── weekNumber: Integer
│   │       │       ├── startDate: Timestamp
│   │       │       ├── riskThreshold: Double
│   │       │       ├── totalThreats: Double
│   │       │       ├── photos: Array<String> (URLs)
│   │       │       └── ...
│   │       ├── dailyLogs/
│   │       │   └── {logId}/
│   │       │       ├── type: String (irrigation, fertilization, etc.)
│   │       │       ├── description: String
│   │       │       ├── timestamp: Timestamp
│   │       │       ├── photoUrl: String
│   │       │       └── ...
│   │       └── pests/
│   │           └── {pestId}/
│   │               ├── name: String
│   │               ├── severity: String (high, moderate, low, monitoring)
│   │               ├── detectedAt: Timestamp
│   │               ├── isActive: Boolean
│   │               └── ...
│   ├── activityLogs/
│   │   └── {logId}/
│   │       ├── fieldId: String
│   │       ├── fieldName: String
│   │       ├── type: String
│   │       ├── title: String
│   │       ├── description: String
│   │       ├── timestamp: Timestamp
│   │       └── ...
│   └── notifications/
│       └── {notificationId}/
│           ├── type: String
│           ├── title: String
│           ├── message: String
│           ├── read: Boolean
│           ├── createdAt: Timestamp
│           └── ...

farmers/
└── {userId}/
    ├── email: String
    ├── name: String
    ├── phone: String
    ├── status: String (unverified, verified, pending)
    ├── createdAt: Timestamp
    ├── verifiedAt: Timestamp
    └── ...
```

### Data Models & Relationships

| Model | Key Fields | Relationships | Purpose |
|-------|-----------|---------------|---------|
| **User** | email, name, uid | owns Farms, Cycles, Logs | Account holder |
| **Farm** | name, boundaries, acres | has many Fields, is parent of Cycles | Physical farm property |
| **Field** | name, crop, boundaries, acres, farmId | belongs to Farm, has many Cycles | Plot within farm |
| **Cycle** | cycleName, cropVariety, fieldId, plantingDate, harvestDate | belongs to Field/Farm, has Weeks/Logs/Pests | Crop growing period |
| **Week** | weekNumber, riskThreshold, totalThreats | belongs to Cycle, part of monitoring | Weekly monitoring unit |
| **DailyLog** | type, description, timestamp | belongs to Cycle, activity record | Farm activity record |
| **Pest** | name, severity, detectedAt, isActive | belongs to Cycle/Field, detected via AI | Pest occurrence |
| **ActivityLog** | type, title, description, timestamp | belongs to User | General activity tracking |

### Firestore Queries Used

- **Get active farm:** `users/{uid}/farms` ordered by `createdAt` DESC, limit 1
- **Get user's cycles:** `users/{uid}/cycles` where `isCompleted == false`
- **Get cycle weeks:** `users/{uid}/cycles/{cycleId}/weeks`
- **Get active pests:** `users/{uid}/cycles/{cycleId}/pests` where `isActive == true`
- **Get activity history:** `users/{uid}/activityLogs` ordered by `timestamp` DESC

---

## 6. Authentication Flow

### 6.1 Login Process

1. **User Input:** Email and password entered on login screen
2. **Firebase Auth:** 
   - Attempt email/password authentication via `FirebaseAuth.signInWithEmailAndPassword()`
   - Returns `UserCredential` with authenticated user
3. **Verification Check:**
   - Query Firestore `farmers` collection using user UID
   - Check `status` field (must be "verified")
4. **Success Path:**
   - If verified → navigate to `AuthGate`
   - `AuthGate` detects authenticated user → shows main dashboard
5. **Error Paths:**
   - Invalid credentials → show "Wrong password" or "User not found"
   - Unverified account → auto sign-out, show "Account not verified yet"

### 6.2 Registration Process

1. **User Input:** Email, password, and confirmation on registration screen
2. **Firebase Auth:**
   - Create new user via `FirebaseAuth.createUserWithEmailAndPassword()`
   - Returns new `UserCredential`
3. **Firestore Entry:**
   - Create document in `farmers` collection with user UID
   - Initialize with `status: "unverified"` and `createdAt` timestamp
4. **Verification Workflow:**
   - Admin reviews account in backend system
   - Admin sets `status: "verified"` in Firestore
   - User can now login (verification check will pass)
5. **Verification Status Screen:**
   - User can view account status via verification form
   - Polls Firestore for status updates
   - Shows "Pending verification" message while awaiting approval

### 6.3 Session Handling

- **Firebase Session Management:**
  - Firebase Auth handles token persistence automatically
  - Tokens stored securely in device storage
  - Automatic refresh before expiration
- **App-Level Session:**
  - On app restart, `Firebase.initializeApp()` in `main.dart` restores user session
  - `AuthGate` checks `FirebaseAuth.currentUser` to determine authenticated state
  - No manual session management needed (handled by Firebase SDK)
- **Session Termination:**
  - Sign out via `AuthService.signOut()` calls `FirebaseAuth.signOut()`
  - Clears cached auth tokens
  - User redirected to login screen

---

## 7. Data Flow

### 7.1 Application Data Flow Architecture

```
┌─────────────────────────────────────────────┐
│         UI Layer (Screens/Widgets)          │
└───────────────────┬─────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│   Provider (State Management - FarmProvider) │
│  - Manages active farm context              │
│  - Notifies listeners on state change       │
└───────────────────┬─────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│       Service Layer (Business Logic)        │
│  - AuthService (Firebase Auth)              │
│  - FirestoreService (Database ops)          │
│  - ApiService (Pest detection AI)           │
│  - FarmService (Farm/field creation)        │
└───────────────────┬─────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│    Firebase SDKs + External APIs            │
│  - Firebase Auth                            │
│  - Cloud Firestore                          │
│  - Firebase Storage                         │
│  - Custom ngrok-based pest detection API    │
└─────────────────────────────────────────────┘
```

### 7.2 Key Data Flows

#### **Farm Setup Flow**
```
GetStartedPage 
  → FarmAreaSetup (draw boundaries)
  → FarmService.saveFarm() 
  → Firestore: users/{uid}/farms (save polygon)
  → FieldAreaSetup (define fields)
  → FarmService.saveFields()
  → Firestore: users/{uid}/fields (save field polygons)
  → FarmProvider notified → UI updates
```

#### **Cycle Creation Flow**
```
StartCycleScreen (form input)
  → CycleModel creation
  → Firestore: users/{uid}/cycles/{cycleId}
  → FarmProvider.switchFarm() updates context
  → Dashboard displays active cycle
```

#### **Pest Detection Flow**
```
UploadPestScreen (image selection)
  → AnalyzingScreen (loading)
  → ApiService.analyzePest(imageFile)
  → HTTP POST to ngrok backend with image
  → Backend returns: pest name, confidence, bounding boxes, treatment
  → PestVerificationScreen shows results
  → User confirms/rejects
  → Firestore: users/{uid}/cycles/{cycleId}/pests/{pestId}
  → Dashboard notified via Firestore listener
```

#### **Monitoring Data Flow**
```
MonitoringScreen (weekly check-in)
  → User fills monitoring form
  → MonitoringFirestoreService.saveWeek()
  → Firestore: users/{uid}/cycles/{cycleId}/weeks/{weekId}
  → Week contains: risk threshold, threats, photos
  → Auto-save every 30 seconds (via timer)
  → Dashboard aggregates week data for overview
```

#### **Activity Logging Flow**
```
RootScreen (tap + button)
  → DailyLogFormScreen (select activity type)
  → User fills form + uploads photo
  → ActivityLogModel created
  → Firestore: users/{uid}/cycles/{cycleId}/dailyLogs/{logId}
  → ActivityLog also saved to users/{uid}/activityLogs for history
  → ReportHistoryScreen queries activity history
```

### 7.3 Provider State Management

**FarmProvider** (Single global provider):
```dart
class FarmProvider extends ChangeNotifier {
  String? _activeFarmId;      // Currently selected farm
  String? _activeFarmName;    // Farm display name
  bool _isLoading = true;     // Loading state
  
  // Getters
  String? get activeFarmId => _activeFarmId;
  String? get activeFarmName => _activeFarmName;
  bool get isLoading => _isLoading;
  
  // Initialize: Fetch user's most recent farm on app startup
  Future<void> init() { }
  
  // Switch farm when user changes active farm
  void switchFarm(String farmId, String farmName) { }
}
```

**Usage Pattern:**
```dart
// Read active farm in any screen
final farmId = context.read<FarmProvider>().activeFarmId;

// Watch for changes
Consumer<FarmProvider>(
  builder: (context, farmProvider, child) {
    return Text('Farm: ${farmProvider.activeFarmName}');
  },
)
```

---

## 8. Offline Capability Assessment

### 8.1 Currently Works Offline

✅ **Local Operations:**
- Form input and validation
- Image capture and preview
- Photo gallery browsing
- GPS coordinate collection (device always has location)
- UI navigation and page transitions
- Offline data display (cached from previous session)

✅ **Partially Cached:**
- Firestore: Enables offline persistence with `await FirebaseFirestore.instance.enableNetwork();`
- Recently fetched farm/cycle data may be available from cache
- Shared preferences for app settings

### 8.2 Requires Internet Connection

❌ **Authentication:**
- Initial login/registration (Firebase Auth needs server)
- Account verification check (Firestore query required)

❌ **Real-time Database:**
- Firestore queries (no offline caching enabled by default)
- Creating/updating cycles, fields, farms
- Saving activity logs
- Fetching farm boundaries

❌ **AI Features:**
- Pest detection API call to ngrok backend (internet required)
- Image analysis and bounding box generation

❌ **Cloud Storage:**
- Uploading photos to Firebase Storage
- Fetching previously uploaded images

### 8.3 Potential Offline-First Improvements

1. **Enable Firestore Offline Persistence**
   ```dart
   // Add to Firebase initialization
   FirebaseFirestore.instance.settings = Settings(
     persistenceEnabled: true,
   );
   ```
   - Caches writes and queries
   - Syncs when connection restored

2. **Implement Local Cache Layer**
   - SQLite (sqflite) for offline database
   - Cache farm/field/cycle data locally
   - Queue pending writes

3. **Offline Activity Queue**
   - Store daily logs, pests in local queue
   - Sync with Firestore when online
   - Show sync status to user

4. **Local Image Processing**
   - Pre-process images locally before upload
   - Could cache previous pest detection results
   - Reduce bandwidth usage

5. **Sync Service**
   ```dart
   // Implement background sync
   - Detect connectivity changes
   - Auto-sync queued data when online
   - Show sync progress to user
   - Handle conflict resolution
   ```

6. **Progressive Web Caching**
   - Implement Service Worker
   - Cache static assets (images, CSS, JS)
   - Background sync for PWA

---

## 9. Known Issues & Concerns

### 9.1 Critical Issues

🔴 **iOS Platform Not Configured**
- `firebase_options.dart` throws `UnsupportedError` for iOS
- iOS Firebase setup incomplete
- Impact: App cannot run on iOS devices

🔴 **ngrok Backend Dependency**
- Pest detection API uses temporary ngrok tunnel
- `https://automatically-unbefriended-misty.ngrok-free.dev`
- Issue: ngrok URLs are temporary and expire/change
- Impact: Pest detection will fail if URL changes

### 9.2 Performance Concerns

🟡 **No Pagination on Historical Queries**
- Report history, activity logs load all records
- Large datasets (1000+ logs) will cause UI lag
- Recommendation: Implement pagination or infinite scroll

🟡 **Unoptimized Image Handling**
- No image caching strategy
- Each upload without compression optimization in production
- Large images slow down app startup

🟡 **Real-time Firestore Listeners**
- Monitoring screen may attach many listeners
- Could drain battery on long monitoring sessions
- Recommendation: Implement listener cleanup, reduce update frequency

### 9.3 Security Concerns

🔐 **Firebase Rules Not Visible**
- No Firestore security rules file in repo
- Assuming default rules (unsafe in production)
- Recommendation: Implement proper security rules:
  ```
  // Example rules
  match /users/{uid} {
    allow read, write: if request.auth.uid == uid;
    match /farms/{farmId} {
      allow read, write: if request.auth.uid == uid;
    }
  }
  ```

🔐 **Admin Verification Process Unclear**
- No admin panel visible in Flutter code
- Backend admin system not documented
- Recommendation: Implement secure admin interface, audit logging

🔐 **API Key in google-services.json**
- Firebase API key visible in repo
- Not critical (Google API keys need IP/app signatures)
- Recommendation: Consider using Cloud Functions to proxy API calls

🔐 **GPS Coordinate Exposure**
- Farm boundaries contain exact GPS coordinates
- Not encrypted or anonymized
- Recommendation: Consider privacy implications, get user consent

### 9.4 UX/Usability Issues

🟡 **No Error Recovery**
- If Firestore save fails, no retry mechanism
- No user feedback on failed operations
- Recommendation: Implement error boundary widgets, retry logic

🟡 **Loading States**
- Some screens may appear frozen during Firestore queries
- No loading indicators on all async operations
- Recommendation: Add consistent loading spinners

🟡 **Empty State Handling**
- No empty state UI for lists (no farms, no cycles, no logs)
- Recommendation: Show helpful empty state messages

### 9.5 Data Quality Issues

🟡 **Missing Validation**
- No validation on date ranges (harvest before planting)
- No seed density bounds checking
- Recommendation: Add form validation before Firestore save

🟡 **Duplicate Data**
- Activity logs saved in both user's collection and cycles collection
- Risk of sync issues
- Recommendation: Normalize to single source of truth

---

## 10. Deployment Setup

### 10.1 Android Deployment

**Configuration Status:** ✅ Configured

**Files:**
- `android/app/build.gradle.kts`: App-level build configuration
- `android/app/google-services.json`: Firebase credentials
- `android/gradle/wrapper/gradle-wrapper.properties`: Gradle version
- `android/local.properties`: Local SDK paths (not in repo)

**Build Configuration:**
- **Min SDK:** Flutter default (usually 21)
- **Target SDK:** Flutter default (usually 33+)
- **Kotlin:** Java 11 compatibility
- **App ID:** `com.example.visaia` (development)
- **Firebase Plugin:** Google Services plugin configured

**Steps for Production Release:**
1. Update `applicationId` in `build.gradle.kts` to unique ID (e.g., `com.mycompany.visaia`)
2. Generate signing key:
   ```bash
   keytool -genkey -v -keystore ~/visaia-release-key.jks \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
3. Configure signing in `build.gradle.kts`:
   ```kotlin
   signingConfigs {
     release {
       storeFile file('/path/to/visaia-release-key.jks')
       storePassword System.getenv('KEYSTORE_PASSWORD')
       keyAlias System.getenv('KEY_ALIAS')
       keyPassword System.getenv('KEY_PASSWORD')
     }
   }
   ```
4. Build release APK:
   ```bash
   flutter build apk --release
   ```
5. Upload to Google Play Store

### 10.2 iOS Deployment

**Configuration Status:** ❌ **Not Configured**

**Issues:**
- `firebase_options.dart` has no iOS configuration
- `Runner.xcodeproj` and `Runner.xcworkspace` exist but Firebase not initialized
- No `GoogleService-Info.plist` file present

**Required Setup:**
1. Run FlutterFire CLI:
   ```bash
   flutterfire configure --platforms=ios
   ```
2. This will:
   - Add iOS Firebase configuration to `firebase_options.dart`
   - Download `GoogleService-Info.plist`
   - Update `ios/Podfile` with Firebase pods
3. Update development team ID in Xcode
4. Create App ID and provisioning profiles in Apple Developer
5. Build and test on iOS device:
   ```bash
   flutter run -d <ios-device-id>
   ```
6. Archive and upload to App Store

### 10.3 Firebase Configuration

**Project ID:** `visaia`
**Storage Bucket:** `visaia.firebasestorage.app`
**Android API Key:** `AIzaSyCmXNJZaZlceU3bjiAAZNfk_Xz-A2lJ24U`
**Web API Key:** Not configured (web platform not fully setup)

**Enabled Firebase Services:**
- ✅ Authentication (email/password)
- ✅ Cloud Firestore
- ✅ Cloud Storage
- ✅ Analytics (likely enabled by default)

**Configuration File Locations:**
- Android: `android/app/google-services.json`
- iOS: Not present (needs setup)
- Web: Not configured
- `lib/firebase_options.dart`: Platform-specific config

**Firebase Firestore Setup Checklist:**
- [ ] Enable offline persistence in settings
- [ ] Configure security rules (not visible in repo)
- [ ] Set up backup schedule
- [ ] Enable Cloud Storage security rules
- [ ] Configure Firebase Auth settings (password reset, email templates)
- [ ] Set up email verification (optional)

### 10.4 API Configuration

**Pest Detection API:**
- **Base URL:** `https://automatically-unbefriended-misty.ngrok-free.dev`
- **Endpoint:** `/analyze` (inferred from code)
- **Method:** HTTP POST (file upload)
- **Response:** JSON with `BoundingBox` array, pest details

**Production Considerations:**
1. Replace ngrok with permanent backend:
   - Deploy on AWS, Google Cloud, or Azure
   - Use stable domain (e.g., `api.visaia.io`)
   - Implement authentication (API key or OAuth)
2. Update `ApiService.baseUrl` in code
3. Add rate limiting and usage tracking
4. Monitor API health and errors

### 10.5 Platform-Specific Considerations

| Platform | Status | Notes |
|----------|--------|-------|
| **Android** | ✅ Ready | Signing key needed for production |
| **iOS** | ❌ Incomplete | Requires FlutterFire setup, provisioning profiles |
| **Web** | ❌ Not Setup | Flutter web target available but not configured |
| **macOS** | ⚠️ Partial | Folders present, Firebase not configured |
| **Linux** | ⚠️ Partial | Folders present, Firebase not configured |
| **Windows** | ⚠️ Partial | Folders present, Firebase not configured |

### 10.6 Environment-Specific Configuration

**Development:**
- Firebase project: `visaia`
- API: ngrok temporary URL
- Auth: Email verification not enforced

**Production:**
- Firebase project: `visaia` (same project)
- API: Stable backend URL
- Auth: Enforce email verification
- Crashlytics: Enable error reporting
- Performance Monitoring: Enable if needed
- App signing: Use production signing key

---

## 11. Recommendations & Next Steps

### 11.1 Critical Path Items

1. **Fix iOS Configuration**
   - Run `flutterfire configure --platforms=ios`
   - Test on iOS simulator/device

2. **Stabilize API Backend**
   - Move from ngrok to production backend
   - Document API contract
   - Implement versioning

3. **Implement Security Rules**
   - Write Firestore security rules
   - Test with Firebase Security Rules emulator
   - Audit public data exposure

### 11.2 Performance Optimizations

1. Add Firestore pagination for large datasets
2. Implement image caching strategy
3. Optimize Firestore queries (add indexes)
4. Profile app for jank/60 FPS

### 11.3 Feature Enhancements

1. Offline-first capability with local caching
2. Push notifications (Firebase Cloud Messaging)
3. Data export/reports (PDF generation)
4. Multi-language support
5. Dark mode
6. Biometric authentication

---

## Conclusion

**VISAIA** is a well-structured Flutter application for agricultural farm management and pest monitoring. The project uses modern Firebase backend services, Provider for state management, and a clean MVCS architecture. While the Android deployment is configured, iOS requires setup, and several production considerations should be addressed before launch (API stabilization, security rules, offline capability).

**Current Status:** Development-ready for Android, needs iOS configuration for full platform support.

**Estimated Effort to Production:**
- Android release: 1-2 weeks (signing, testing, Play Store submission)
- iOS release: 2-3 weeks (Firebase setup, provisioning, App Store submission)
- Backend stabilization: 2-4 weeks (API production deployment, monitoring)
