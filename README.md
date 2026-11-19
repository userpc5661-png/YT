# ليل — Layl

تطبيق آيفون بأسلوب نتفليكس، واجهته عربية من اليمين إلى اليسار، ويعرض أفلامًا مفتوحة الترخيص تعمل مباشرة بلا مفاتيح API.

Layl is a native SwiftUI iOS app: a dark, Netflix-style browser for freely licensed films. The interface is Arabic and right-to-left, with an English toggle. Videos stream with AVPlayer. Profiles, My List, and playback progress stay on the device.

## بناء IPA بدون ماك، ثم تثبيته من ويندوز

لا تحتاج إلى جهاز ماك. Codemagic يبني ملفًا **غير موقَّع** على جهاز macOS سحابي، ثم توقّعه أنت على ويندوز ببرنامج Sideloadly وبحساب Apple ID مجاني. التوقيع المجاني ينتهي بعد ٧ أيام، فتعيد الخطوة نفسها كل أسبوع.

رابط استنساخ المستودع (خاص، لذلك Codemagic سيطلب بيانات الدخول):

```text
https://origin.cursor.com/git/abdullah-al-harthy/tmp-6d77c1239481e944.git
```

1. أنشئ حسابًا على [codemagic.io](https://codemagic.io).
2. من صفحة Applications اضغط **Add application**.
3. اختر **HTTPS/SSH** ثم **Next: Select repository**.
4. الصق رابط الاستنساخ أعلاه. لا تختر Public repository؛ المستودع خاص.
5. أدخل اسم مستخدم Origin ورمز الوصول (Personal Access Token) إذا طُلبت كلمة المرور. إن فضّلت SSH، ولّد زوج مفاتيح من Codemagic وأضف المفتاح العام إلى المستودع.
6. عند اختيار نوع المشروع اختر **iOS / Xcode** وأكّد أن البناء يقرأ `codemagic.yaml`. اسم سير العمل: **Layl unsigned IPA**.
7. اضغط **Start new build** واختر فرع `main` وسير العمل `ios-unsigned-ipa`.
8. بعد نجاح البناء افتح **Artifacts** ونزّل `Layl-unsigned.ipa`.
9. على ويندوز ثبّت [Sideloadly](https://sideloadly.io) ووصّل الآيفون (iOS 17 أو أحدث) ووافق على «الثقة بهذا الكمبيوتر».
10. على الآيفون فعّل وضع المطوّر: **الإعدادات ← الخصوصية والأمن ← وضع المطوّر**.
11. في Sideloadly اسحب ملف IPA، وأدخل Apple ID المجاني (مع رمز التحقق بخطوتين إن ظهر)، ثم **Start**. إذا رُفض معرّف الحزمة `com.layl.streaming` فغيّره من خيارات Sideloadly إلى اسم فريد مثل `com.yourname.layl`.
12. على الآيفون: **الإعدادات ← عام ← VPN وإدارة الجهاز** ثم ثق بشهادة حسابك.
13. كل ٧ أيام أعد الخطوتين ١١ و١٢ بنفس Apple ID. Sideloadly يوقّع التطبيق من جديد؛ لا تحتاج إلى إعادة بناء IPA ما دام الملف عندك.

إن نسخت المستودع إلى GitHub، فسير العمل `.github/workflows/ios-unsigned-ipa.yml` يبني الملف نفسه على `macos-latest`. بعد اكتمال Actions نزّل artifact باسم `Layl-unsigned-ipa`، ثم أكمل من الخطوة ٩.

## What you can do

- Choose who’s watching. Profiles are stored locally, including a kids profile that hides horror and other non-family titles.
- Browse a hero banner and horizontal rows: trending, top 10, Blender open movies, animation, family, shorts, public-domain classics, horror, comedy, science fiction, and drama.
- Open a title for the synopsis, year, maturity, score, credits, and — for series — an episode list.
- Play the real film. Progress is saved and **Continue watching** resumes it. **My List** adds and removes favorites.
- Search by title, synopsis, or credit, and filter by genre.
- Switch the whole interface between Arabic (RTL) and English (LTR).

The catalog has 26 titles: 13 Blender Foundation open movies, the three-episode series *Caminandes*, and 12 public-domain classics. Posters and backdrops are frames from those same films.

### Streaming Availability API

Layl can connect to the open [Streaming Availability API](https://github.com/movieofthenight/streaming-availability-api) (Movie of the Night). With a free key from [developers.movieofthenight.com](https://developers.movieofthenight.com/), the **Discover** tab shows Top lists for Netflix, Disney+, Apple TV, Prime, and Max in your country (default Saudi Arabia). **Search** also queries the API, and title pages show where a film streams plus deep links. In-app playback still uses the Internet Archive catalog; API titles open their streaming service unless Layl already has a matching free film.

In the app: **Settings** (gear) → paste **API key** → choose **country** and preferred **services**. Data and posters from the API are subject to [their terms](https://developers.movieofthenight.com/terms-and-conditions).

### iPhone layout

The UI scales for iPhone mini, standard, Pro, and Pro Max width buckets (including 15/16/17 families). **Settings → Screen density** switches comfortable vs compact spacing.

## Playback and rights

Films stream over HTTPS from the Internet Archive. The phone or simulator needs a network connection. Layl does not modify the picture; Creative Commons titles are attributed on the detail screen and under **Rights and sources** in the profile menu.

| Kind | Examples | License |
| --- | --- | --- |
| Blender open movies | Sintel, Big Buck Bunny, Cosmos Laundromat, Spring, Sprite Fright, Wing It! | CC BY or CC BY-ND, Blender Foundation |
| Series | Caminandes (3 episodes) | CC BY 3.0 |
| Public-domain features | Night of the Living Dead, Nosferatu, Sherlock Jr., His Girl Friday, Meet John Doe | Public domain, or the CC BY encode noted on the title |

Some archival transfers are standard definition. The detail page says so. Blender masters on [studio.blender.org](https://studio.blender.org/films/) are often sharper than the streaming copy.

## Requirements

- Mac with **Xcode 15 or newer** (Xcode 16 recommended)
- iOS **17** or newer (iPhone and iPad)
- A network connection while watching
- An Apple ID only if you install on a physical device

## Run it

1. Open `Layl.xcodeproj` in Xcode.
2. Select the **Layl** scheme.
3. Choose an iPhone or iPad simulator.
4. Press Run.

The first screen is **Who’s watching?** Pick a profile. The simulator can play videos as long as it can reach `archive.org`.

From Terminal, on a Mac:

```bash
xcodebuild -project Layl.xcodeproj -scheme Layl \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

If that simulator name is not installed, list devices with `xcrun simctl list devices available` and use one of those names.

## Unsigned IPA without a Mac

This environment cannot compile iOS apps. `codemagic.yaml` builds an **unsigned** IPA on a Codemagic `mac_mini_m2` runner with the latest Xcode (`CODE_SIGNING_ALLOWED=NO`). The artifact is `build/ipa/Layl-unsigned.ipa`. Sign it on Windows with [Sideloadly](https://sideloadly.io) and a free Apple ID; repeat every 7 days. The Arabic steps above use this clone URL:

```text
https://origin.cursor.com/git/abdullah-al-harthy/tmp-6d77c1239481e944.git
```

The repository is private, so Codemagic needs HTTPS credentials or an SSH key. A GitHub mirror can use `.github/workflows/ios-unsigned-ipa.yml` instead. A paid Apple Developer account is only required for Ad Hoc, TestFlight, or the App Store.

## Install on your iPhone from Xcode (free Apple ID)

This does not create an IPA file. Xcode installs a development build directly.

1. Connect the iPhone and trust the computer.
2. On the iPhone, turn on Developer Mode if iOS asks (`Settings → Privacy & Security → Developer Mode`).
3. In Xcode, open `Layl.xcodeproj`.
4. Select the **Layl** target → **Signing & Capabilities**.
5. Check **Automatically manage signing**.
6. Set **Team** to your Personal Team (Xcode → Settings → Accounts → your Apple ID).
7. If Xcode says the bundle id is taken, change `com.layl.streaming` to something unique, such as `com.yourname.layl`.
8. Choose your iPhone as the run destination and press Run.
9. On the phone, if iOS blocks the app: `Settings → General → VPN & Device Management`, trust your developer certificate.

The free profile expires after about 7 days. Run again from Xcode to refresh it.

## Export an IPA

You still need a Mac and Xcode. Replace `YOUR_TEAM_ID` in the plist you use with the 10-character Team ID (visible in Xcode under Signing & Capabilities, or at [developer.apple.com/account](https://developer.apple.com/account)).

### Development IPA

Installs on devices registered to your team. A free Apple ID can often export this for your own registered device. A paid account is more reliable.

```bash
# edit ios/ExportOptions-development.plist first
./scripts/export-ipa.sh ios/ExportOptions-development.plist
```

The IPA is written to `build/ipa/Layl.ipa`.

Or do it in Xcode:

1. Select **Any iOS Device (arm64)** as the destination. Do not select a simulator.
2. **Product → Archive**.
3. In the Organizer, **Distribute App → Debugging** or **Custom → Development**.
4. Automatic signing, then export.

### Ad Hoc IPA (paid Developer Program)

Registers up to 100 devices by UDID. Add each device at developer.apple.com before exporting.

```bash
# edit ios/ExportOptions-ad-hoc.plist first
./scripts/export-ipa.sh ios/ExportOptions-ad-hoc.plist
```

In Xcode: **Distribute App → Custom → Ad Hoc**.

### App Store / TestFlight (paid Developer Program)

```bash
# edit ios/ExportOptions-app-store.plist first
./scripts/export-ipa.sh ios/ExportOptions-app-store.plist
```

Then upload that IPA with the Transporter app, or in Xcode choose **Distribute App → App Store Connect**. TestFlight is the usual way to share a build before release.

## Sideload an IPA you already exported

These tools re-sign with your Apple ID. They do not remove the need for a Mac to compile the app in the first place.

- **Apple Configurator** (Mac): drag a development or Ad Hoc IPA onto a connected device that is covered by the provisioning profile.
- **Sideloadly** (Mac or Windows, after you have an IPA): open the IPA, enter the Apple ID, connect the device, and start. A free Apple ID still expires in about 7 days.
- **AltStore** or **SideStore**: install the AltServer companion on a computer, then sideload the IPA from the phone. Same 7-day limit on a free Apple ID. A paid account lasts a year.

An unsigned or “simulator” build cannot be installed on a phone. Sideloadly needs an IPA that Xcode has already archived.

## Project layout

```
Layl.xcodeproj          Xcode project and shared scheme
Layl/LaylApp.swift      App entry
Layl/Model              Catalog, profiles, progress
Layl/Views              Home, details, player, search, profiles
Layl/Assets.xcassets    App icon and film frames
ios/                    Export options for development, Ad Hoc, and App Store
scripts/export-ipa.sh   Archive + export on a Mac
```

If you add a Swift file, run `python3 scripts/generate_xcodeproj.py` or drag the file into the Layl target in Xcode.

Profiles, My List, and continue-watching positions are stored in `UserDefaults` under `layl.state.v1`. Uninstalling the app clears them.
