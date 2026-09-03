# 🤝 Team Collaboration & Workflow Guide

Welcome! Since we are working on the **PalengkeGoAPP** together, this document outlines the essential rules for sharing code and managing our backend connections. Reading and following this will prevent merge conflicts, lost work, and broken database connections.

---

## 🛠️ 1. Safe Git Pulling (Avoiding "Buggy" Code Overwrites)

**The Golden Rule:** *Never pull code from GitHub if you have uncommitted changes in your local workspace.* 

If you pull while having uncommitted changes, Git might forcefully merge things in a way that breaks your local copy, leading to a mess of bugs.

### How to safely pull new code:
Before you run `git pull`, check your status:
```bash
git status
```
If you have modified files (shown in red or green), you have two safe options:

**Option A: Commit your changes first (Recommended)**
Save your work as a commit before bringing in your teammate's code.
```bash
git add .
git commit -m "WIP: Working on feature X"
git pull origin main
```
*(If there is a conflict, Git will now safely ask you to resolve it without losing your work).*

**Option B: Stash your changes**
If you aren't ready to commit but want to see their new code:
```bash
git stash          # Hides your changes safely
git pull origin main # Pulls the new code cleanly
git stash pop      # Brings your hidden changes back on top of the new code
```

---

## 🧬 2. Clone, Never Download-and-Re-upload (Why Our Histories Must Stay Connected)

**The team repository (`PalengkeGo/PalengkeGoApp`) is the single source of truth.** Everyone works from a *clone* of it — never from a ZIP download re-uploaded as a new repo.

### What went wrong once (learn from it)
A teammate once downloaded the project as a ZIP and pushed the files into a fresh GitHub repo. Git treated that copy as a brand-new project with **zero shared history**, so when the two lines were merged:
- every file had to be resolved from scratch (no common ancestor to diff against),
- `pubspec.lock` got committed **with merge-conflict markers inside it**, and
- `flutter pub get` failed for anyone cloning the repo until the lock file was regenerated.

A disconnected history turns every sync into this. A shared history makes conflicts rare, small, and resolvable.

### The only three commands a beginner needs
```bash
git clone https://github.com/PalengkeGo/PalengkeGoApp.git
git checkout -b my-feature          # your own branch, safe to experiment
git push origin my-feature          # then open a Pull Request on GitHub
```
You cannot break `main` from a branch. If you're unsure, commit often and ask before merging.

### House rules
1. **No direct pushes to `main`** — always a branch + Pull Request (PR). The CI workflow (`Analyze, Test, Coverage`) runs on every PR and catches broken code *before* it lands; a direct push skips that safety net.
2. **Never hand-edit `pubspec.lock` to resolve a conflict.** Take either side, then regenerate and commit:
   ```bash
   git checkout --theirs pubspec.lock   # or --ours — either is fine
   flutter pub get                      # this writes the correct lock file
   git add pubspec.lock
   ```
3. **If Git ever shows `<<<<<<<` in a file, stop and resolve it** — search the repo before pushing: `grep -rn "<<<<<<<" --include="*" .` (excluding `node_modules`, `build`). Conflict markers must never be committed.
4. **Adding a teammate?** They clone the team repo. Backups/forks of the team repo only *pull* from it — work never flows back in via re-uploads.

---

## 🗄️ 3. Enterprise Secrets Management & Configuration

We use a "Hybrid" backend: **Firebase** for core app architecture and **Supabase** for the recipe database. We also integrate **PayMongo** for payments. Security is paramount, and we strictly enforce the separation of client-side publishable keys and backend-only secret keys.

### 🛡️ Core Security Rule
**NEVER commit any `.env` files or hardcode API keys in the source code.** 
- Client apps (like our Flutter app) must **only** ever contain **Public/Publishable Keys**.
- **Secret Keys** must ONLY exist within secure backend vaults (e.g., Google Secret Manager, AWS Secrets Manager, or Supabase Vault).

### 📱 Frontend Security (The Flutter App)
The Flutter application uses a `.env` file purely for local development of public configurations.
- **What goes in here:** `SUPABASE_URL`, `SUPABASE_ANON_KEY` (publicly safe role-based key), and `PAYMONGO_PUBLIC_KEY`.
- **How to share:** Since `.env` is ignored by Git, you must Direct Message (DM) these public/anon keys via Discord/Slack.
- **Production:** In production CI/CD, these variables will be injected during the build process, not bundled as a raw file.

### 🔐 Backend Security (Firebase / Supabase Functions)
This is where the real security happens. For sensitive operations like creating PayMongo Payment Links or processing transactions, your backend code must securely retrieve the `PAYMONGO_SECRET_KEY`. Do not use `.env` files for production backend environments.

#### Using Firebase Cloud Functions (Google Secret Manager)
If you are deploying Firebase Functions to handle PayMongo:
1. Store the secret securely using the Firebase CLI:
   ```bash
   firebase functions:secrets:set PAYMONGO_SECRET_KEY
   ```
2. Access it securely in your backend function (it automatically pulls from Google Secret Manager):
   ```typescript
   import { defineSecret } from "firebase-functions/params";
   const paymongoSecret = defineSecret("PAYMONGO_SECRET_KEY");
   
   export const createPayment = onCall({ secrets: [paymongoSecret] }, (request) => {
     const secretKey = paymongoSecret.value();
     // Use secretKey to securely call PayMongo API
   });
   ```

#### Using Supabase Edge Functions (Supabase Vault)
If you are using Supabase Edge Functions instead:
1. Store the secret in the Supabase Dashboard (Settings -> Edge Functions -> Secrets) or via CLI:
   ```bash
   supabase secrets set PAYMONGO_SECRET_KEY=your_secret_key_here
   ```
2. Access it securely in your Deno backend:
   ```typescript
   const secretKey = Deno.env.get('PAYMONGO_SECRET_KEY');
   ```

### 🚫 Logging and Anti-Leak Policies
- **No `print()` or `console.log()` for secrets:** Never log API requests, responses, or configurations containing keys.
- **Sanitize Errors:** If a backend request fails, return a generic error to the frontend (e.g., "Payment failed to process"). Do not leak the backend stack trace or raw PayMongo API response to the Flutter app.

### 🔴 Firebase (Your Job — Git Sharing)

The app is already fully wired for Firebase. All the repositories and providers are ready. You just need to connect a real Firebase project.

#### Your step-by-step checklist:

**Step 1 — Create the Firebase project**
- Go to [console.firebase.google.com](https://console.firebase.google.com) and create a new project named `PalengkeGo`.
- Enable **Email/Password** authentication: Authentication → Sign-in method → Email/Password → Enable.
- Create a **Firestore Database**: Firestore Database → Create database → Start in test mode.

**Step 2 — Generate the config file**

In the project root terminal, run:
```bash
flutterfire configure
```
This generates `lib/firebase_options.dart` automatically. This file is safe to commit.

**Step 3 — Uncomment two lines in `firebase_service.dart`**

Open `lib/core/infrastructure/firebase_service.dart` and make these two changes:

```dart
// UNCOMMENT this import at the top:
import 'package:palengkego/firebase_options.dart';

// INSIDE FirebaseService.initialize(), REPLACE:
await Firebase.initializeApp();

// WITH:
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

**Step 4 — Push to GitHub**
```bash
git add lib/firebase_options.dart lib/core/infrastructure/firebase_service.dart
git commit -m "feat: connect Firebase project"
git push origin main
```

**Step 5 — Run the app in Firebase mode**
```bash
flutter run --dart-define=FIREBASE_ENABLED=true
```

That's it. The app will now use real Firebase Auth and Firestore instead of mock data.

> **Note:** Running `flutter run` without the flag still uses mock data — nothing breaks.

---

## 🚨 Summary Checklist Before Coding

1. Did I pull the latest changes safely?
2. Does my `.env` file exist and have the Supabase keys? *(for recipe features)*
3. Is `firebase_options.dart` generated? *(for Firebase auth features)*
4. Am I running with `--dart-define=FIREBASE_ENABLED=true` when testing Firebase?
