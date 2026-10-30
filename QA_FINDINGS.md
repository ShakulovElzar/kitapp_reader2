# QA findings and decisions — 2026-10-30

Branch: `codex/full-app-reader-fixes`. Tested: server/admin builds, `flutter analyze`, admin API QA suite, API probes, and manual testing of the web app and admin in a browser.

## Decided fixes

### Security
- [x] **Book files:** stop serving `/files/books/**` publicly. Issue short-lived HMAC-signed URLs (~1h), checked by a guarded files route that also checks access (purchase / active rental / free).
- [x] **OTP:** max 5 attempts per code, rate limit per IP and per phone, use `crypto.randomInt`, add an SMS provider interface plus a Kyrgyz SMS gateway (*provider still to be chosen; `SMS_PROVIDER=log` works locally, and anything else refuses to send*). Show the "111111" hint only when the server returns `developmentCode`.
- [x] **Blocking:** `ReaderGuard` checks `isBlocked` / `deletedAt` in the DB on every request.
- [ ] **Payments:** keep instant fake purchases for the MVP demo (decided). Before any real launch, put them behind a `PAYMENT_MODE=local` switch.

### App-breaking
- [x] Restore `web/readiumReader.js` (it was deleted by accident, so the reader showed a black screen). Move test fixtures (`test.epub`, cover PNG) into `tool/fixtures/`, and update pubspec and the QA scripts.
- [x] Expired or invalid token leaves a blank screen forever: catch errors in `AppStateController.load()`, and on a 401 log out and go to the login screen.
- [x] Reader: force paginated mode at all widths so one tap or swipe moves one page (right now it jumps a whole chapter on phone widths).
- [x] Native iOS/Android: web-only for the MVP. Replace the hardcoded `assets/books/test.epub` with a clear "not supported" message.

### Product rules
- [x] Archived or deleted books stay readable for buyers and active renters (also update the QA test that asserts the opposite).
- [x] Library shows only books the user added or opened (new `LibraryEntry` table), not every free book.
- [x] Detail page uses real data: language from the EPUB, age from `isAdult`, dates from `publishedAt` / `updatedAt`, "Most read" from real `ReadingProgress` counts. Remove the fake view count.
- [x] Strict access per type: FREE = read; PURCHASE = buy (plus rent if `rentalPrice` is set); RENTAL = rent only; renters can upgrade to buy. Price 0 only for FREE.

### Admin and data
- [x] Enforce roles: EDITOR works on content only. SUPERADMIN only: revenue, readers, blocking, audit log.
- [x] Reports: revenue = purchases + rentals (shown separately); count only rentals that are still active; periods in Asia/Bishkek time.
- [x] Resume reading from the server-saved locator; key local progress, bookmarks and settings by user ID; clear them on logout.
- [x] Remove the unused MinIO/S3 config. Run the QA scripts against a separate `kitapp_test` DB. Test books ("adilet", "Probe PURCHASE/RENTAL") archived; the 93 test reader accounts are left in place (deleting them can't be undone). QA now runs with `npm run qa:api`.

- [x] Reader redesign to match the reference screenshots: dark panel with Contents / Settings / Search tabs, round back and bookmark buttons, chapter list with page numbers, theme swatches, font picker, vertical sliders.

## Fixes that need no decision
- [x] Duplicate author name, category, or slug, and blocking a reader who doesn't exist, return 500 errors. Map Prisma P2002 → 409 and P2025 → 404.
- [x] Remove the prefilled admin email/password (admin login) and phone `0555123456` (app login).
- [x] The DTO rejects formatted phones like `+996 (700) 12-34-56` even though `normalizePhone` would handle them.
- [ ] The share button copies `/books/<slug>`, which no route handles. Add the route or remove the button.
- [ ] Admin pages use `.then()` without a `catch` (dashboard, orders), and the block toggle has no error handling or confirmation.
- [x] Re-buying after a refund would hit the unique `reference` and return a 500.
- [x] JWT secret falls back to `'local-kitapp-secret'`. Fail on startup if `JWT_SECRET` is missing outside dev.
- [ ] `ReadingProgress` sync caps at 300 s per request, so seconds above that are lost after failed syncs.
- [x] Profile "Purchases: N books" counts every free book.
- [x] `web/index.html`: page title and description are still "kitapp_reader2" / "A new Flutter project."

## Environment notes (not app bugs)
- The root `node_modules` was corrupted (`commander` was missing files). Fixed with `npm ci`.
- The Flutter SDK cache was damaged (MaterialIcons font was missing). Fixed with `flutter precache --universal --web --force`. `flutter test` still crashes inside the Dart compiler. Probably needs `flutter doctor` / a full SDK cache reset.
- Port 3000 is taken by another local project (Remotion), so testing used API port 3100.
