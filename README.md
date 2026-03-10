# Beaver Planner

An iOS task management app with an AI chat assistant. Built with SwiftUI and backed by a Kimi/Moonshot LLM, the app lets users manage scheduled events and unscheduled todos, receive smart time recommendations, and interact with an AI that can create, update, and complete tasks on their behalf.

## Features

- Today view with a daily schedule and todo checklist
- Monthly calendar with per-day detail
- AI chat with streaming responses and task action support (create, update, delete, complete)
- User profile with achievement tracking, productivity insights, and energy curve visualization
- Preference system populated from onboarding, manual settings, and chat history
- AWS Cognito authentication (sign up, sign in, email verification)
- iOS Calendar sync via EventKit
- Local push notifications

## Requirements

- Xcode 15 or later
- iOS 17 or later
- A Moonshot (Kimi) API key and/or an OpenAI API key

## Setup

1. Clone the repository.

2. Copy the example secrets file and fill in your API keys:

   ```
   cp Secrets.example.xcconfig Secrets.xcconfig
   ```

   Open `Secrets.xcconfig` and replace the placeholder values with your actual keys:

   ```
   MOONSHOT_API_KEY = your_moonshot_key_here
   OPENAI_API_KEY   = your_openai_key_here
   ```

   `Secrets.xcconfig` is listed in `.gitignore` and must never be committed.

3. If you are using AWS Amplify, place your configuration files at the following paths (both are gitignored):

   ```
   AmplifyConfig/amplifyconfiguration.json
   AmplifyConfig/awsconfiguration.json
   ```

4. Open `AI_planner.xcodeproj` in Xcode, select a simulator or device running iOS 17+, and build.

## Project Structure

```
AI_planner/
  AI_plannerApp.swift        App entry point and auth routing
  ContentView.swift          Four-tab container view
  Views/                     Screen-level views
  ViewModels/                Observable view models
  Models/                    Data models (TodoTask, UserProfile)
  Services/                  Business logic and external integrations
  Components/                Reusable UI components
  Theme/                     Design tokens (AppTheme.swift)
  Utils/                     Helpers (CalendarHelper)
```

## Tech Stack

- Swift / SwiftUI (iOS 17+)
- AWS Amplify (Cognito authentication)
- Kimi/Moonshot LLM API with SSE streaming
- EventKit for calendar sync
- UserDefaults for local persistence