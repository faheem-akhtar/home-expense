# Home Expenses (Dual Expense Tracker)

Flutter app for two people to track shared monthly spending against category budgets, synced in real time through Firebase. Requirements are in [prd.md](prd.md).

## Features

- **Buckets**: create, edit, reorder and delete categories, each with an emoji and a monthly cap.
- **Monthly reset**: when the app opens in a new month (or at local midnight on the 1st if it's running), the previous month is closed. Its spent and unspent amounts per bucket are saved in a `summary`, and a new month opens from the bucket templates. Unspent balances carry over if **Settings → Carry over** is on.
- **Quick add**: tap "+" (or tap a bucket card to preselect it), enter the amount, pick a bucket and save. You can also set the payment method, add notes or a merchant, and attach a receipt from the camera or gallery. Who added the expense and when are recorded automatically.
- **Dashboard**: shows total budget, spent and left with a colour-coded bar (green below 75%, yellow 75–90%, red above 90%), plus a card for each bucket.
- **History**: newest entries first, browsable by month, with lines like "Faheem added AED 120 (Playtomic)". Entries can be edited or deleted, and balances adjust automatically.
- **Reports**: the monthly view shows each category against its budget and compares spending per partner. The yearly view has a 12-month chart and exports to CSV or PDF through the share sheet (email, WhatsApp and so on).
- **Low-balance alert**: an in-app warning appears when a bucket drops below 10% remaining.

## Setup

Prerequisites: the Flutter SDK (3.22 or newer), Xcode and/or Android Studio, and a Firebase project.

```bash
# 1. Generate the iOS/Android platform folders (existing files in lib/ are kept)
flutter create . --platforms=ios,android --org com.faheem
flutter pub get

# 2. Connect Firebase (this overwrites lib/firebase_options.dart)
dart pub global activate flutterfire_cli
flutterfire configure

# 3. Deploy the security rules
npm i -g firebase-tools && firebase login
firebase deploy --only firestore:rules   # add ,storage once Storage is enabled
```

In the Firebase console:

1. Enable **Authentication → Email/Password**, then create the two accounts (or use "Create an account" in the app).
2. Create a **Firestore** database.
3. Optional: enable **Storage** for receipt images. This requires the Blaze plan. Then set `receiptsEnabled = true` in [lib/config.dart](lib/config.dart) and deploy `storage.rules`.

Platform settings needed after `flutter create`:

- **iOS** (`ios/Runner/Info.plist`): add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`. Set `platform :ios, '13.0'` or higher in `ios/Podfile`.
- **Android** (`android/app/build.gradle`): set `minSdk 23` or higher.

## First run

1. Partner A signs in, enters their name and picks **New household**. Five starter buckets are created.
2. Partner A copies the **household code** from Settings and sends it to Partner B.
3. Partner B signs in, picks **Join partner** and pastes the code. A household can have at most two members.

## Installing on phones (no app stores)

### Android: Firebase App Distribution

Every push to `main` runs the workflow in [.github/workflows/build.yml](.github/workflows/build.yml). It builds a signed APK and uploads it to Firebase App Distribution. Testers in the `family` group get an email for the first build and a notification in the **Firebase App Tester** app for each update after that.

One-time setup:

1. **Signing key:** run `scripts/setup-android-signing.sh`. It creates the keystore in `~/.config/home-expense/` and saves it to GitHub Secrets. Back that folder up.
2. **CI credentials:** in Google Cloud Console → IAM & Admin → Service Accounts (project `my-home-expense`), create a service account with the role **Firebase App Distribution Admin**. Create a JSON key for it, then run:
   `gh secret set FIREBASE_SERVICE_ACCOUNT < path/to/key.json`. Delete the JSON file afterwards.
3. **Testers:** in Firebase Console → App Distribution, click **Get started** if you see it, then run:
   ```bash
   firebase appdistribution:group:create "Family" family --project my-home-expense
   firebase appdistribution:testers:add --group-alias family wife@example.com --project my-home-expense
   ```
4. **On the Android phone:** open the invite email, accept it, install the App Tester app, and allow installs from unknown sources when the phone asks.

### iPhone: free Apple ID, installed from this Mac

Apple doesn't let CI install apps signed with a free account, so CI only checks that the iOS build compiles. Install from the Mac:

1. Open `ios/Runner.xcworkspace` in Xcode. Under **Runner → Signing & Capabilities**, set **Team** to your Personal Team (Xcode → Settings → Accounts → add your Apple ID).
2. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode** and restart. Connect the iPhone by cable and tap **Trust**.
3. Run `flutter run --release` and pick the iPhone. After the first install, open **Settings → General → VPN & Device Management** and trust your developer certificate.
4. **The app stops opening after 7 days.** Run step 3 again to renew it. Your data is safe because it lives in Firestore. After the first cable install you can enable **Connect via network** in Xcode → Window → Devices and Simulators, so later installs work over Wi-Fi.

## Data model (Firestore)

```
users/{uid}                          displayName, householdId, email
households/{hid}                     name, members[], carryOver
households/{hid}/buckets/{id}        name, icon, budget, order, archived
households/{hid}/months/{yyyy-MM}    allocations{bucketId: {name, icon, budget, carryIn, order}},
                                     closed, summary{bucketId: {budget, spent, unspent}}
households/{hid}/expenses/{id}       amount, bucketId, bucketName, paymentMethod, note,
                                     receiptUrl, userId, userName, createdAt, monthKey
```

How the data fits together:

- Spent amounts are always calculated from the expenses, so editing or deleting an expense updates balances immediately.
- Each month document freezes that month's budgets, so changing a bucket later doesn't rewrite history.

## Not included yet

- **Push notifications (FCM)**: the low-balance alert is in-app only. To alert both phones, add a Cloud Function that runs on `expenses` writes and sends through FCM.
- **Server-side reset**: the monthly rollover runs on the device. Neither phone has to be open at 00:00, because the first device to open in the new month performs the rollover inside a transaction. If you want the rollover to happen exactly at midnight, add a scheduled Cloud Function.
