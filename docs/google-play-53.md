# Google Play candidate 53

Apple remains 1.1.4 (87). Android candidate uses versionCode 53 and versionName 0.6.3.

The user screenshots refer to Android release 52 (0.6.2), not this candidate. They show:

- DEX obfuscation 1%, deadline February 2027.
- Possible edge-to-edge display issues.
- Deprecated edge-to-edge/window APIs; the screenshot does not expose their qualified names.

The isolated development-branch workflow builds a signed AAB with R8 optimization and resource shrinking enabled. Rules preserve reflectively created WorkManager workers and Room implementations to address the historical startup risk. The workflow verifies exact original launcher pixels in the optimized APK and starts that optimized release on an Android 15 emulator. Flutter analysis and all Flutter tests run before compilation.

No production track, existing main-branch release workflow, public Android release, iOS workflow or TestFlight build is changed. No automatic Play upload is configured. Play Console access was denied by the browser permission boundary; this workflow only produces a reviewable candidate.

The app has no explicit deprecated SystemChrome color/window overrides in lib/. Current Flutter defaults to edge-to-edge with the generated target SDK. The top AppBar and existing SafeArea handle insets. An upstream-library warning cannot be declared resolved until Play Console identifies its APIs and processes the candidate. No claim is made that every function has been physically tested or that Play Console has accepted this candidate.

Verification run: https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37881616661
Status: SUCCESS, including signed AAB/APK, versionCode 53, exact original APK launcher pixels, all 15 Flutter tests, and Android 15 optimized-release startup. Analysis has no errors/warnings and 25 informational lints.

Bundle R8 metadata version 9.1.31 reports disabled percentages: obfuscation 18.49%, optimization 18.88%, shrinking 18.42%. Calculated enabled scores (100 minus disabled) are 81.51%, 81.12% and 81.58%. Uncompressed DEX size is 7,306,960 bytes. These scores exceed 25%; final Play Console acceptance/warning status is unverified because Console access was denied.

Artifact: RVAZ-Google-Play-53-candidate (ID 11595016861), SHA-256 a0d60d0e6517750c210cb542bad4288b024b315b2b7e2551d711162de8be0e0d.

The inspected startup screenshot shows the rendered home page with the Android notification-permission prompt. It is startup evidence, not a complete end-to-end feature test. Evidence is recorded in verification/play53/optimization.json and verification/play53/rvaz-startup.png by report run 37882411900.
