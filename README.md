# MicroLend — Solo Lending Management Suite

MicroLend is a local-first, offline-capable micro-lending management application for solo operators. It includes automated loan amortization scheduling, credit risk assessment, local state persistence with write queueing, dashboard portfolio analytics, and repayment tracking.

This repository contains both the **React Web Application** and the **Flutter Mobile Application** (Android & iOS).

---

## 🚀 CI / CD & Automated Builds (GitHub Actions)

On every push to `main` and pull request, GitHub Actions automatically builds, analyzes, and tests the application:

- **Android Job (`ubuntu-latest`)**: Sets up Java 17 & Flutter, runs `flutter analyze` and `flutter test`, builds release APK and AAB, and uploads artifacts:
  - `microlend-android-apk` (`app-release.apk`)
  - `microlend-android-aab` (`app-release.aab`)
- **iOS Job (`macos-latest`)**: Sets up Flutter, runs `flutter build ios --release --no-codesign`, and uploads the unsigned iOS build artifact:
  - `microlend-ios-unsigned`

To download the latest APK or build artifacts, navigate to the **Actions** tab on GitHub, click the latest workflow run, and scroll down to **Artifacts**.

### 🔑 App Licensing
Full features (unlocking the 5-borrower limit) are enabled by entering the static master unlock code in the application Settings screen.

---

## 📚 Documentation & User Guides

- **[Lender's Guide to Issuing a Loan (PDF)](docs/lending-guide.pdf)** — A plain-English walkthrough for non-technical lenders explaining interest calculation methods, upfront deductions, dynamic terms, and late penalties.

---

## 📱 Flutter Mobile Application (`flutter_app/`)

Reimplemented in Dart/Flutter with local-first on-device storage (`shared_preferences`), `fl_chart` analytics, and full feature parity with the web suite.

### Running the Mobile App
```bash
cd flutter_app
flutter pub get
flutter run
```

### Running Mobile Unit Tests
```bash
cd flutter_app
flutter test
```

### Building Release Packages
- **Android APK**: `cd flutter_app && flutter build apk --release`
- **iOS App Bundle**: `cd flutter_app && flutter build ipa --release`
- **Obfuscated Production Release (Reverse Engineering Deterrence)**:
  ```bash
  cd flutter_app
  flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
  flutter build windows --release --obfuscate --split-debug-info=build/windows/symbols
  flutter build macos --release --obfuscate --split-debug-info=build/macos/symbols
  ```

---

## 💻 Web Application (React + Vite)

Local-first React SPA using Tailwind CSS, Recharts, and `useSyncExternalStore` bound to LocalStorage.

### Running the Web App
```bash
npm install
npm run dev
```

### Running Web Unit Tests
```bash
npm test
```

---

## 📊 Core Business & Financial Logic

Both platforms share identical financial calculations and business rules:
- **Amortization Schedule (`generateSchedule`)**: Standard equal-monthly-payment calculation with month-over-month due dates and rounding drift correction on final installment.
- **Installment Status (`getScheduleWithStatus`)**: Sequential payment allocation tracking `paid`, `partial`, `overdue`, `pending`, and `cancelled` statuses.
- **Credit & Risk Assessment (`assessBorrower`)**: Derives credit score and Debt-to-Income (DTI %) from borrower income, active loan obligations, and payment history to assign `low`, `medium`, or `high` risk ratings.
- **Local-First Write Queue**: Off-grid operations are queued and drained during simulated or remote synchronization (`syncAll`).
