<h1 align="center">hosmas</h1>
<p align="center">
  One native SwiftUI app for life in a Thapar hostel: complaints, canteen food and orders, in one place.
</p>

> **Personal interoperability project.** hosmas is not affiliated with, endorsed by, or connected to FretBox or HungerBox. It talks to their services using your own account, the same way their official apps do. I built it for myself and haven't distributed it, and I'd only offer it to other students with both companies' permission.

## Why

At Thapar, hostel life runs through two apps: **FretBox** for the hostel (complaints and resident services) and **HungerBox** for the canteen. Using them every day, I kept hitting the same frustrations:

- **Nothing is cached.** Opening the app to check the mess or canteen menu meant waiting around 10 seconds while it fetched everything again.
- **The resident app is cross-platform (Flutter)**, so it never quite feels native on an iPhone.
- **Two apps, two logins, two experiences** for what is really one student's day.

So I mapped how the official apps talk to their servers and built one native client on top of the same APIs, designed around what a student actually needs.

## What it does

- **Hostel sign-in** with your FretBox account, using its OTP code and hCaptcha challenge
- **Complaints:** browse complaint categories and raise a request
- **Canteen:** sign in with your HungerBox account, browse the menu, add items, check out and pay through your UPI app
- **Orders:** see what you've ordered and the reference to quote at the counter
- **Profile:** your resident details in one place
- **Cached data:** menus and lists load instantly from disk, and only what has changed gets fetched again

## How it's built

```
hosmas (SwiftUI app)
 ├─ Features/        Login, Complaints, Food, Checkout, Orders, Profile
 ├─ Platform/        Apple-only pieces: Keychain storage, the hCaptcha web view
 └─ AppEnvironment   the one place app code meets the package
         │
         ▼
HosKhas (Swift package, pure Swift)
 ├─ ResidentService  FretBox auth + resident APIs
 ├─ CanteenService   HungerBox auth, menu, cart, orders
 └─ FileCacheStore   shared disk cache
```

- **HosKhas holds all the logic and has no Apple-UI dependencies,** so it also compiles for Android with the Swift Android SDK. Platform-specific pieces, like the hCaptcha challenge, which needs `WKWebView`, sit in the app and plug into protocols the package defines (`CaptchaTokenProvider`, a secure store).
- **Two services, kept separate.** They share one disk cache and one Keychain, but each has its own session, host and header conventions.
- **Swift Concurrency and Observation throughout.** The captcha flow suspends on a checked continuation until the web view hands back a token.
- **Credentials stay out of the source.** API config values go in a gitignored `Secrets.swift` (see `Secrets.example.swift`), and session tokens are stored in the Keychain.

## Status

This is a working personal prototype, not a public app. **HosKhas is a local package that isn't published yet**, so this repo won't build on its own. It's here so you can read the code.

## Ideas I'd like to build

- Scheduled or recurring cleaning requests, so students can pick a time slot and cleaning staff aren't stuck doing 50–60 rooms in a single day
- The mess menu as a widget

---

Built by [Aarav Gupta](https://github.com/atpugvaraa). More on why: [LinkedIn post](https://www.linkedin.com/posts/atpugvaraa_when-frustration-becomes-deafening-you-ugcPost-7497244689209769984-9w7X/).
