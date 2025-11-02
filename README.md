# Dhatnoon App (Flutter Internship Assessment)

This is a Flutter application built as an assessment. It's a request-driven app where a "Requester" can create a ticket for a service, and a "Sender" can accept and fulfill that request in real-time.

The app is built on a hybrid backend to maximize the use of free-tier services.

---

## Features Implemented

* **Firebase Authentication:** Secure sign-up, sign-in, and role management.
* **Role-Based Routing:** Users are designated as either a "Requester" or a "Sender" at signup and are routed to different dashboards.
* **Firestore Ticket System:** A complete, real-time ticket dashboard where Requesters can create tickets and Senders can see and accept them.
* **Firestore Security Rules:** Secure, role-based rules to protect all user and ticket data.
* **Service 1: Image Sample Upload (Working)**
    * **Backend:** Uses **Supabase Storage** (free tier, no credit card required).
    * **Flow:** A Sender can accept a ticket, open their camera, take a photo, and upload it. The Requester can then view this image in their ticket details.
* **Service 2: Live Location (Working)**
    * **Backend:** Uses **Supabase Realtime** for live coordinate streaming.
    * **Frontend:** Uses **OpenStreetMap** via the `flutter_map` package (100% free, no API key).
    * **Flow:** A Sender can start streaming their location. The Requester will see a map with the Sender's marker updating in real-time.
* **Service 3: Live Video Stream (Partial)**
    * **Signaling:** The complete WebRTC signaling logic is implemented using Firestore. The "offer" and "answer" handshake is functional.
    * **Status:** The media connection fails (black screen), which is a common network/NAT traversal issue that typically requires a paid TURN server, which was outside the scope of this assessment's free-tier-only rule.

---

## Tech Stack

* **Flutter** (Dart)
* **Firebase** (Authentication, Firestore Database, Security Rules)
* **Supabase** (Storage, Realtime Database)
* **OpenStreetMap** (`flutter_map`)
* **WebRTC** (`flutter_webrtc`)