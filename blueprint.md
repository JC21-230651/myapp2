
# Calendar & Health App Blueprint

## Overview

This application is a comprehensive calendar and health management tool designed to help users organize their schedules, track their health, and manage their tasks efficiently. It integrates with native calendar and health functionalities, and provides a seamless user experience with a modern and intuitive interface.

## Architecture

*   **State Management:** Provider with ChangeNotifier for managing app-wide state. This includes:
    *   `CalendarState`: Manages calendar events, selections, and device calendar interactions.
    *   `ThemeProvider`: Manages the application's light and dark themes.
    *   `HealthState`: Manages health data, including steps, sleep, goals, and weekly reports.
*   **Routing:** go_router for declarative routing, enabling a more organized and web-friendly navigation structure.
*   **Theming:** Centralized theme management with support for both light and dark modes, using google_fonts for improved typography.
*   **Error Handling:** Utilizes `dart:developer` for structured logging of errors, particularly in asynchronous operations and permission handling.

## Features

### 1. Calendar

*   **Monthly Calendar View:** A clear and easy-to-navigate monthly calendar.
*   **Event Integration:** Fetches and displays events from the user's native device calendar.
*   **Date Selection:** Users can select a date to view events.

### 2. Reminders & Tasks

*   **Task List:** A dedicated screen to manage tasks and reminders.

### 3. Health Tracking

*   **Pedometer:** Tracks the user's steps in real-time and displays the daily count.
*   **Sleep Tracking:** Fetches and displays sleep data from the native health API.
*   **Goal Setting:** Users can set a daily step goal.
*   **Weekly Reports:** Visualizes weekly step and sleep data in bar charts.

### 4. User Authentication

*   **Member Registration:** Users can create an account using their email and password.
*   **Firebase Integration:** Utilizes Firebase Authentication for secure user management.

### 5. Memo

*   **Daily Memos:** Users can add and save memos for any selected date on the calendar.

## Style and Design

*   **Modern UI:** A clean and modern user interface with a simple and intuitive layout.
*   **Bottom Navigation:** Easy access to all main features through a bottom navigation bar.
*   **Visual Feedback:** Clear visual cues for selected dates, events, and progress tracking.
*   **Typography:** Enhanced readability and a modern feel with the google_fonts package.

## Current Implementation Plan

*   **Refactoring:**
    *   **Health State:** Created a new `HealthState` provider to manage all health-related data and logic, including steps, sleep, goals, and weekly reports. This separates concerns from the UI.
    *   **Safe Permission Handling:** Implemented a dedicated `_requestCalendarPermissions` helper to handle calendar permissions in a null-safe manner, preventing crashes and centralizing logic.
    *   **Error Logging:** Added `dart:developer` logging to all `catch` blocks to ensure that errors are properly recorded and can be debugged.
    *   **UI Simplification:** Refactored `HealthScreen` and `WeeklyReportScreen` into `StatelessWidgets` that consume data from the `HealthState` provider, making the UI layer cleaner and more reactive.
    *   **Null-Safety:** Corrected the `A nullable expression can't be used as a condition` error by explicitly checking for `true` when evaluating permission results.
*   **Finalization:**
    *   Update `blueprint.md` to reflect the new architecture, including the `HealthState` provider and the improved error handling and permission logic.
