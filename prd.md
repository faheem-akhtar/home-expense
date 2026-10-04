# Product Requirement Document (PRD): Dual Expense Tracker

## 1. Executive Summary

A private, cross-platform mobile app (iOS & Android) designed for a couple to track shared monthly spending against pre-allocated category budgets in real time.

---

## 2. Core Features & Requirements

### 2.1 Setup & Budget Allocation (1st of Every Month)

- **Custom Buckets:** Ability to create, edit, and delete categories (e.g., Groceries, Sports & Padel, Dining, Retail, Fuel).
- **Monthly Cap Assignment:** Assign a fixed numerical budget to each bucket.
- **Auto-Reset Engine:** On the 1st of every month at 00:00 local time:
  - Budget allocations automatically reset for the new month.
  - Unspent balances are logged into history (with an option to carry over or start fresh).

### 2.2 Quick Expense Entry

- **Real-time Deduction:** Entering an expense instantly subtracts the amount from the designated bucket.
- **Input Fields:**
  - **Amount** (AED) — Mandatory.
  - **Category / Bucket** — Mandatory (Dropdown / Quick-select tiles).
  - **Payment Method** — Cash, Primary Card, Dedicated Prepaid Card.
  - **Notes / Merchant** — Optional (e.g., "Playtomic", "Nesto").
  - **Receipt Image** — Optional (camera capture or gallery pick).
- **Automated Metadata:** The system automatically logs the **User ID** (Husband or Wife) and the **Timestamp**.

### 2.3 Main Dashboard ("At a Glance")

- **Overall Summary Card:**
  - Total Monthly Budget vs. Total Spent vs. Total Remaining.
  - Visual progress bar (Green: <75%, Yellow: 75–90%, Red: >90%).
- **Bucket List View:**
  - Clean card interface for each category showing:
    - Category Name & Icon.
    - Assigned Budget.
    - Spent Amount.
    - **Remaining Balance** (bold and color-coded).
- **Quick Add Button:** Prominent floating "+" button on the main screen for 2-tap entry.

### 2.4 History & Audit Log

- **Chronological Feed:** Scrollable list of all logged transactions sorted by newest first.
- **Audit Metadata:** Clear indicator showing _who_ added the entry (e.g., "Faheem added AED 120 (Playtomic)" vs. "Wife added AED 350 (Nesto)").
- **Edit / Delete:** Ability to edit or delete entries in case of typing errors, with automatic balance adjustments.

### 2.5 Analytics & Reports

- **Monthly Report:**
  - Breakdown of spending per category vs. target budget.
  - User comparison chart (Husband spending vs. Wife spending per category).
- **Yearly Overview:**
  - Month-by-month spending trends over 12 months.
  - Export capability (Export report as CSV or PDF via email/WhatsApp).

---

## 3. Technical & System Architecture

```
[ iOS App (Husband) ]     <---> [ Firebase Firestore ] <---> [ Android App (Wife) ]
(Real-Time Database)
```

| Component              | Recommended Tech Stack         | Reason                                                                            |
| :--------------------- | :----------------------------- | :-------------------------------------------------------------------------------- |
| **Frontend**           | Flutter                        | Single codebase builds native iOS and Android apps simultaneously.                |
| **Backend / DB**       | Firebase Firestore             | Free tier covers 2 users easily; provides instant real-time sync across devices.  |
| **Authentication**     | Firebase Auth (Email/Password) | Simple login for 2 pre-configured accounts.                                       |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | Optional: Triggers alert to both devices when a bucket drops below 10% remaining. |

---

## 4. UI / UX Design Blueprint

```
+-----------------------------------+
|          OCTOBER 2026             |
| Total Left: AED 3,250 / 6,350     |
| [==================.......] 48%   |
+-----------------------------------+
| BUCKETS                           |
|                                   |
| [🛒] Groceries                    |
| Left: AED 1,200 | Spent: 1,300    |
|                                   |
| [🎾] Sports & Padel              |
| Left: AED 150   | Spent: 650      |
|                                   |
| [🛍️] Retail & Shopping           |
| Left: AED 400   | Spent: 600      |
+-----------------------------------+
|               [ + ]               |  <-- Floating Quick Add
+-----------------------------------+
```

---
