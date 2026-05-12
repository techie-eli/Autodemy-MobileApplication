# User Flow Diagram

Below is the user-flow (presentation → services → backend) for the current AUTODEMY project.

```mermaid
flowchart LR
  subgraph Presentation[Presentation / UI]
    Splash["Splash"]
    Onboard["Onboarding"]
    Login["Login"]
    Home["App Home (role-based)"]
    Admin["Admin Home"]
    Teacher["Teacher Home"]
    Student["Student Home"]
    Live["Live Attendance"]
    Reports["Reports"]
    Calendar["Calendar"]
    Support["Support Request"]
  end

  subgraph ClientServices[Client Data Services]
    ApiService["ApiService"]
    AttendanceService["AttendanceService"]
    AppData["AppData (runtime state)"]
  end

  subgraph Backend[Backend / Server]
    ServerJS["server.js"]
    AuthAPI["/auth/*"]
    AttendanceAPI["/attendance/*"]
    ReportsAPI["/reports/*"]
    UserModel[("User model")]
    AttendanceModel[("Attendance model")]
    SeedScript["seed.js"]
  end

  DB[("Database")]
  Theme["app_theme + custom_widgets"]

  %% Presentation flow
  Splash --> Onboard --> Login --> Home
  Home --> Admin
  Home --> Teacher
  Home --> Student
  Admin --> Reports
  Teacher --> Live
  Student --> Live
  Home --> Calendar
  Home --> Support

  %% Client-service interactions
  Home -->|calls| ApiService
  Live -->|calls| AttendanceService
  ApiService -->|HTTP| AuthAPI
  ApiService -->|HTTP| ReportsAPI
  AttendanceService -->|HTTP| AttendanceAPI
  AppData -->|holds state for| Home

  %% Backend internals
  AuthAPI --> ServerJS
  AttendanceAPI --> ServerJS
  ReportsAPI --> ServerJS
  ServerJS --> UserModel
  ServerJS --> AttendanceModel
  UserModel --> DB
  AttendanceModel --> DB
  SeedScript --> UserModel
  SeedScript --> AttendanceModel

  %% UI helpers
  Home -. uses .-> Theme
  Splash -. uses .-> Theme
  Live -. uses .-> Theme

  %% Summary edges
  AttendanceService ---|sync/submit| AttendanceModel
  ApiService ---|queries| UserModel
```

Notes
- UI screens in `lib/presentation/screens/*` drive user actions (auth, dashboard, live attendance, reports, calendar, support).
- `lib/data/services/*` (ApiService, AttendanceService) encapsulate HTTP calls to `backend/server.js` endpoints.
- Backend handlers use `backend/models/User.js` and `backend/models/Attendance.js` to persist to the DB; `seed.js` seeds initial data.
- `lib/data/app_data.dart` keeps runtime app state; `lib/core/theme/app_theme.dart` and `lib/presentation/widgets/custom_widgets.dart` provide styling/components.

File: [docs/user_flow.md](docs/user_flow.md)
