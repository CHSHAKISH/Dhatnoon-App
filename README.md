# Dhatnoon App (Flutter Internship Assessment)

This is a Flutter application built as an assessment. It's a request-driven "instant presence" app where a "Requester" can ping a specific "Sender" to get a live, one-way stream of their video, location, or a single image.

The app is built on a hybrid backend to maximize the use of free-tier services.

---

## Features Implemented

* **Firebase Authentication:** Secure sign-up, sign-in, and role management. A user is either a "Requester" or a "Sender."
* **Request-Driven Flow (Logic 1):** The app inverts the traditional chat flow. A Requester browses a list of available Senders and pings them directly.
* **Custom Timers (Logic 2):** Requesters can set a specific duration (H:M:S) for any live request, making the sessions "time-bound" and ephemeral.
* **Firestore Security Rules (Logic 4 & 5):**
  * Implements a secure, role-based "Privacy Audit Framework" (Logic 5).
  * Rules are auth-integrated, only allowing Senders to see requests assigned to them and Requesters to see *their* pings.
* **Consent Synchronization (Logic 8):** The `tickets` collection acts as a consent ledger, moving from `pending` to `accepted` to track the state of a request.

---

## Implemented Services

### 1. Service: Image Sample Upload (Working)
* **Backend:** Uses **Supabase Storage** (free tier).
* **Flow:** A Requester can ping a Sender for an image. The Sender accepts, opens their camera, and uploads the photo. The Requester can then view the image in their "My Pings" list.

### 2. Service: Live Location (Working & Ephemeral)
* **Backend:** Uses **Supabase Realtime** for live coordinate streaming.
* **Frontend:** Uses **OpenStreetMap** via the `flutter_map` package (100% free, no API key).
* **Flow:** A Requester pings a Sender for their location for a set duration. The Sender accepts and starts the stream. The Requester can then open the ticket and watch the Sender's marker move on a map in real-time.
* **Ephemeral (Logic 2):** As per the "burn-after-stream" requirement, when the Sender stops sharing (or the timer expires), the location data is **instantly deleted** from the Supabase table, leaving no trace.

### 3. Service: Live Video Stream (Signaling Implemented)
* **Audio & Mute:** The Sender's stream includes audio and a functional mute/unmute button.
* **Flow:** The *entire* signaling and app logic for this feature is complete.
* **Status:** The video connection results in a **black screen**. This is a known network (NAT traversal) problem.
* **Solution (Logic 6):** The feedback (Logic 6) states the app must "fall back to TURN servers." This is a paid service. As this assessment was limited to the free tier, this feature cannot be completed without upgrading to a paid plan to enable a TURN server.

---

## Tech Stack

* **Flutter** (Dart)
* **Firebase** (Authentication, Firestore Database, Security Rules)
* **Supabase** (Storage, Realtime Database)
* **OpenStreetMap** (`flutter_map`)
* **WebRTC** (`flutter_webrtc`)