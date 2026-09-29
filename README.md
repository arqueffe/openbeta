# Crux Climbing Gym Management System

A comprehensive climbing gym management platform featuring a Flutter mobile application and WordPress-based backend for route tracking, user interactions, and performance analytics.

## 🏗️ System Overview

- **Frontend**: Flutter mobile app with route visualization and cross-platform support
- **Backend**: WordPress plugin with REST API for gym management and user authentication
- **Architecture**: Clean Architecture with Provider pattern (Frontend) + WordPress REST API (Backend)

## ✨ Key Features

### 🧗‍♂️ Route Management
- Interactive climbing wall visualization
- Advanced filtering (grade, setter, wall section, color)
- Route interactions (likes, comments, ticks, projects)
- Grade proposals and safety warnings

### 👤 User Management
- WordPress cookie-based authentication
- Role-based access control (Admin, Route Setter, Member)
- Personal climbing statistics and progress tracking
- Multi-language support (English/French)

### 📊 Analytics & Performance
- Comprehensive climbing statistics
- Performance tracking (sends, attempts, flashes)
- Intelligent caching with offline capability
- Real-time updates and background sync

## 🚀 Quick Start

### Backend Setup (WordPress)
```bash
# Install WordPress and copy plugin
cp -r backend/wp-content/plugins/crux-climbing-gym /home/cruxclubxi/cruxclub.fr/wp-content/plugins/

# Activate plugin in WordPress admin
# Plugin automatically creates database schema and sample data
```

### Frontend Setup (Flutter)
```bash
cd frontend

# Install dependencies
flutter pub get

# Generate localization files
flutter pub run intl_utils:generate

# Build the web application for production
flutter build web --release --base-href "/climb/"

# Build the web application for staging
flutter build web --release --base-href "/climb_test/"

# Deploy build/web to the corresponding remote directory with SFTP
# Production: /home/cruxclubxi/cruxclub.fr/climb/
# Staging:    /home/cruxclubxi/cruxclub.fr/climb_test/
```

### Local Development

The repository pins the Flutter SDK with `mise`. From the repository root:

```bash
mise install
cd frontend
mise exec -- flutter pub get
mise exec -- flutter run -d chrome
```

The VS Code launch configuration includes **Flutter Web (Chrome)** and tasks for
dependency installation, analysis, tests, and web builds. The WordPress plugin
in `backend/` is loaded by a separate WordPress installation; this repository
does not include a WordPress runtime or database.

### Automated Deployment

GitHub Actions runs Flutter analysis/tests/builds and PHP syntax checks on pull
requests to `master`; pull requests never deploy. Merges to `master` deploy the
Flutter web app to `/home/cruxclubxi/cruxclub.fr/climb_test/`. There is no
WordPress staging installation, so plugin changes are checked but not
automatically deployed.

Production deployment is manual from **Actions → Production deploy**, only for
the `master` branch. Select `frontend`, `backend`, or `both`. The backend
selection uploads the WordPress plugin. Configure a
`production` GitHub Environment with required reviewers before using the
workflow; approval is required before any production upload. The production
frontend path is `/home/cruxclubxi/cruxclub.fr/climb/`, and the plugin path is
`/home/cruxclubxi/cruxclub.fr/wp-content/plugins/crux-climbing-gym/`.

The deployment workflows use SFTP on port 22 with SSH key authentication and
strict host-key checking. Configure separate `staging` and `production` GitHub
Environments and add these secrets to the matching environment:

| Environment | Secret names |
| --- | --- |
| `staging` | `STAGING_SFTP_HOST`, `STAGING_SFTP_USERNAME`, `STAGING_SFTP_PRIVATE_KEY`, `STAGING_SFTP_KNOWN_HOSTS` |
| `production` | `PROD_SFTP_HOST`, `PROD_SFTP_USERNAME`, `PROD_SFTP_PRIVATE_KEY`, `PROD_SFTP_KNOWN_HOSTS` |

Both host secrets should be `ftp.cluster027.hosting.ovh.net`. Use separate
deployment users/keys where the host permits, granting staging access only to
`climb_test` and production access only to the live frontend and plugin
directories. Do not use the FileZilla password as a workflow secret. Create a
dedicated, non-interactive SSH key for each target and authorize its public key
with the hosting provider. Verify each server host-key fingerprint against OVH
or the fingerprint confirmed by FileZilla before saving the corresponding
OpenSSH `known_hosts` entry.

Restrict both Environments to deployments from `master`. Configure the
`production` Environment with required reviewers and prevent self-review before
the first production release. Credentials are environment-scoped, so they are
unavailable to validation jobs and are not configured as repository-wide
secrets. The account must have write permission to its destination directories.
Uploads overwrite matching files but do not delete remote files. Plugin
deployment updates the live plugin directly; no WordPress restart is performed.
To roll back, revert the deployed change on `master`, then run the production
workflow again. Existing Flutter analyzer warnings and informational lints are
reported but non-fatal; analyzer errors, failing tests, failed builds, or PHP
syntax errors block deployment.

## 📁 Project Structure

```
topo_app/
├── backend/                    # WordPress backend
│   ├── wp-content/plugins/     # Main plugin directory
│   │   └── crux-climbing-gym/  # Plugin files and admin interface
│   └── requirements.txt        # Dependencies
├── frontend/                   # Flutter mobile app
│   ├── lib/                    # Application source code
│   │   ├── models/            # Data models
│   │   ├── providers/         # State management
│   │   ├── screens/           # UI screens
│   │   ├── services/          # API and data services
│   │   └── widgets/           # Reusable UI components
│   └── assets/                # Static assets and 3D models
└── README.md                  # This file
```

## 🛠️ Technology Stack

### Frontend
- **Flutter 3.0+** - Cross-platform mobile framework
- **Provider** - State management
- **HTTP** - API communication with intelligent caching

### Backend
- **WordPress 5.0+** - Content management system
- **PHP 7.4+** - Server-side logic
- **MySQL/MariaDB** - Database
- **WordPress REST API** - Backend API endpoints

## 📚 API Overview

Base URL: `/wp-json/crux/v1/`

### Core Endpoints
- `GET /routes` - Retrieve climbing routes with filtering
- `POST /routes/{id}/ticks` - Mark route completion
- `GET /user/stats` - Get user climbing statistics
- `GET /auth/me` - Current user authentication status

## 🔒 Authentication & Roles

- **Authentication**: WordPress cookie-based system
- **Admin**: Full system management access
- **Route Setter**: Route creation and editing
- **Member**: Route interaction and personal tracking

## 🌍 Internationalization

- English (primary)
- French (secondary)
- Extensible localization system

## 📱 Platform Support

- **Web**: Primary deployment target
- **Android**: Mobile app via Flutter
- **iOS**: Mobile app via Flutter (macOS required for development)

## 🔧 Development

### Prerequisites
- Flutter SDK ≥3.0.0
- WordPress 5.0+
- PHP 7.4+ with MySQL/MariaDB

### Documentation
- [Frontend Documentation](frontend/README.md) - Detailed Flutter app architecture
- [Backend Documentation](backend/README.md) - WordPress plugin implementation

## 📄 License

See [LICENSE](LICENSE) file for details.

---

**Version**: 0.11.2
**Architecture**: Flutter + WordPress  
**Platform**: Cross-platform mobile with web backend
