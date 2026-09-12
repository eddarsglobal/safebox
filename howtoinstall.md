# SafeBox — HOW TO INSTALL / RUN

**Baseline : v0.2.2d Android R28**  
Ce fichier regroupe les commandes Terminal utiles pour installer, verifier, lancer et tester SafeBox sur le Mac de developpement et sur l'emulateur Android.

> Important : cette baseline utilise le CLI Tauri local verrouille dans `node_modules/.bin/tauri`. Ne pas remplacer les commandes par `npx tauri ...`.

---

## 1. Decompresser SafeBox proprement

Depuis le dossier `Downloads` :

```bash
cd ~/Downloads
rm -rf safebox_sbx_mvp
unzip -o safebox_v0.2.2d_android_e2e_hardening_r28.zip
cd safebox_sbx_mvp
```

Si le ZIP porte un autre nom, remplace uniquement le nom du fichier dans la commande `unzip`.

---

## 2. Verifier les outils disponibles sur le Mac

```bash
node --version
npm --version
rustc --version
cargo --version
java -version
```

Verifier Android SDK / ADB :

```bash
~/Library/Android/sdk/platform-tools/adb version
~/Library/Android/sdk/emulator/emulator -list-avds
```

SafeBox attend Android Studio / Android SDK deja installes et au moins un AVD disponible. La baseline prefere automatiquement :

```text
Pixel_9_Pro_XL_API_35
```

s'il existe.

### Si Node.js n'est pas installe

Avec Homebrew :

```bash
brew install node
```

### Si Rust n'est pas installe

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
rustc --version
cargo --version
```

---

## 3. Verification complete de la baseline R28

Depuis la racine du projet :

```bash
cd ~/Downloads/safebox_sbx_mvp
bash verification/verify_v022d_android_e2e_hardening_r28.sh
```

Marker final attendu :

```text
SAFEBOX_V022D_ANDROID_E2E_HARDENING_R28_VERIFY_PASS
```

La verification couvre notamment :

- format Rust ;
- tests crypto / securite ;
- frontend TypeScript/Vite ;
- Android document I/O ;
- ANR hardening ;
- icone officielle ;
- Share / Open-With ;
- supply-chain npm ;
- politique sans `npx tauri` sur le runtime Android.

---

## 4. Lancer SafeBox sur l'emulateur Android

Commande principale :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run android:cold-dev
```

Cette commande s'occupe automatiquement de :

- restaurer les dependances npm verrouillees si necessaire ;
- generer le projet Android Tauri s'il manque ;
- installer les icones officielles ;
- detecter/reutiliser ou demarrer l'AVD ;
- attendre le boot Android ;
- compiler SafeBox ;
- installer l'APK ;
- demarrer `com.safebox.desktop/.MainActivity`.

Markers utiles possibles :

```text
SAFEBOX_FRONTEND_TOOLCHAIN_READY
SAFEBOX_ANDROID_PROJECT_READY
SAFEBOX_ANDROID_ICON_READY
SAFEBOX_ANDROID_REUSED_READY
SAFEBOX_ANDROID_COLD_BOOT_READY
```

A la fin du build Android, on doit voir :

```text
Performing Streamed Install
Success
Starting: Intent { cmp=com.safebox.desktop/.MainActivity }
```

Laisser ce Terminal ouvert pendant le test de l'application.

---

## 5. Verifier que l'emulateur Android est connecte

Dans un second Terminal :

```bash
~/Library/Android/sdk/platform-tools/adb devices
```

Exemple attendu :

```text
List of devices attached
emulator-5554    device
```

Le numero peut changer (`emulator-5556`, etc.). Utiliser le numero affiche par `adb devices` dans les commandes suivantes.

---

## 6. Envoyer un fichier du Mac vers le simulateur Android

Le simulateur Android ne peut pas parcourir directement le Bureau du Mac depuis le picker Android. Pour envoyer un fichier dans `Downloads` du Pixel :

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 push "/CHEMIN/DU/FICHIER/test.png" /sdcard/Download/
```

Exemple reel :

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 push "/Users/noury/Desktop/Capture d’écran 2026-08-28 à 18.15.45.png" /sdcard/Download/
```

Resultat attendu :

```text
1 file pushed
```

Ensuite dans SafeBox :

```text
Choose -> Downloads -> selectionner le fichier
```

### Astuce pour un chemin complique

Commencer par taper :

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 push 
```

Puis glisser le fichier depuis Finder dans la fenetre Terminal. macOS inserera son chemin. Ajouter ensuite :

```text
 /sdcard/Download/
```

### Verifier les fichiers presents dans Downloads Android

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 shell ls -lah /sdcard/Download/
```

---

## 7. Test Android E2E SafeBox

Une fois l'application lancee :

```text
1. Laisser SafeBox ouverte 60 secondes -> aucun ANR.
2. Choose -> Downloads -> choisir un PNG/PDF.
3. Verifier le vrai nom dans Original file.
4. Verifier Visible SBX name.
5. Entrer un code de test.
6. Create SBX.
7. Save le .sbx dans Downloads.
8. Ouvrir le .sbx depuis Android Files avec SafeBox.
9. Tester volontairement un mauvais code -> refus sans fichier restaure.
10. Entrer le bon code -> Unlock.
11. Save original.
12. Ouvrir et comparer le fichier restaure.
13. Verifier que le .sbx existe toujours si Keep SBX after unlock = ON.
```

Code de test temporaire utilise pendant le developpement :

```text
R28-test-1234
```

Ne pas utiliser ce code comme secret reel.

---

## 8. Arreter SafeBox Android

Dans le Terminal ou `npm run android:cold-dev` tourne :

```text
Ctrl + C
```

Pour arreter explicitement l'emulateur :

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 emu kill
```

---

## 9. Redemarrer SafeBox Android

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run android:cold-dev
```

Le script detecte automatiquement un emulateur sain deja ouvert ou effectue un cold boot si necessaire.

---

## 10. Redemarrer ADB si Android n'est plus detecte

```bash
~/Library/Android/sdk/platform-tools/adb kill-server
~/Library/Android/sdk/platform-tools/adb start-server
~/Library/Android/sdk/platform-tools/adb devices
```

Puis relancer :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run android:cold-dev
```

---

## 11. Lancer SafeBox en application macOS Desktop

Depuis le projet :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run tauri dev
```

Le wrapper SafeBox restaure automatiquement le frontend verrouille si necessaire avant le lancement.

Pour uniquement reconstruire le frontend :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run build
```

---

## 12. Restaurer explicitement le toolchain frontend

Normalement ce n'est pas necessaire car les scripts SafeBox le font automatiquement. En cas de diagnostic :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
bash scripts/ensure_frontend_toolchain.sh
```

Marker attendu :

```text
SAFEBOX_FRONTEND_TOOLCHAIN_READY
```

Puis :

```bash
npm run android:cold-dev
```

---

## 13. Verifier les vulnerabilites npm

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm audit
```

Baseline R28 attendue :

```text
found 0 vulnerabilities
```

Ne pas lancer aveuglement :

```text
npm audit fix
```

Une mise a jour de dependances doit etre analysee et reverifiee avant integration.

---

## 14. Commandes courtes a retenir

### Verifier toute la baseline

```bash
cd ~/Downloads/safebox_sbx_mvp
bash verification/verify_v022d_android_e2e_hardening_r28.sh
```

### Lancer Android

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run android:cold-dev
```

### Voir le simulateur

```bash
~/Library/Android/sdk/platform-tools/adb devices
```

### Envoyer un fichier Mac vers Android Downloads

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run android:import -- "/chemin/vers/fichier"
```

### Lancer macOS Desktop

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run tauri dev
```

### Arreter l'emulateur

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 emu kill
```

---

## 15. Regle de baseline

Pour cette version :

- utiliser les scripts inclus dans le projet ;
- conserver les versions npm verrouillees ;
- ne pas remplacer les appels Tauri locaux par `npx tauri` ;
- ne pas modifier le projet Android genere `src-tauri/gen/android` comme source canonique : il est regenerable ;
- toujours relancer le verifier R28 apres une modification du code ou du toolchain.


---

## 16. R28 — commandes E2E Android simplifiees

A partir de R28, ne tape plus les longues commandes `adb push` manuellement.

### Importer n'importe quel fichier Mac dans le simulateur

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run android:import -- "/Users/noury/Desktop/mon-fichier.png"
```

SafeBox place le fichier dans :

```text
/sdcard/Download/SafeBox-E2E/
```

et compare automatiquement le SHA-256 Mac/Android.

### Preparer toute la suite de fichiers E2E

Dans un deuxieme Terminal pendant que `npm run android:cold-dev` tourne :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run android:e2e-prepare
```

La commande cree et importe automatiquement :

- petit fichier texte ;
- nom de fichier Unicode ;
- PDF ;
- PNG SafeBox ;
- fichier binaire deterministe de 64 MiB ;
- manifeste SHA-256.

Pour tester une autre taille, par exemple 128 MiB :

```bash
SAFEBOX_E2E_LARGE_MIB=128 npm run android:e2e-prepare
```

### Gate automatique 60 secondes sans ANR

```bash
npm run android:e2e-idle
```

Marker attendu :

```text
SAFEBOX_ANDROID_E2E_IDLE_PASS
```

### Apres le parcours manuel Create -> Save -> Open -> Unlock

Verifier qu'aucun ANR/crash n'est present :

```bash
npm run android:e2e-log
```

Marker attendu :

```text
SAFEBOX_ANDROID_E2E_LOG_PASS
```

### Comparer le fichier restaure avec l'original Mac

Exemple :

```bash
npm run android:compare -- \
  "/Users/noury/Desktop/mon-fichier.png" \
  "/sdcard/Download/mon-fichier.png"
```

Marker attendu :

```text
SAFEBOX_ANDROID_COMPARE_PASS
```

### Si plusieurs appareils Android sont branches

Choisir explicitement le serial :

```bash
SAFEBOX_ANDROID_SERIAL=emulator-5554 npm run android:e2e-prepare
```

---

## 10. Android v0.2.4 — baseline finale R29

La baseline Android core est validee apres le test E2E R28.

Verification rapide de la fermeture Android (aucun rebuild Android requis) :

```bash
cd ~/Downloads/safebox_sbx_mvp
bash verification/verify_v024_android_final_r29.sh
```

Resultat attendu :

```text
ANDROID_V024_STATUS: DONE
SAFEBOX_V024_ANDROID_FINAL_R29_VERIFY_PASS
```

### Nom en doublon dans Android Files

Si Android Files enregistre un second fichier avec un nom comme :

```text
safebox-e2e-image.png (1)
```

ce suffixe est choisi par le fournisseur de documents Android lorsque le nom demande existe deja. SafeBox conserve le nom original comme suggestion et ecrit dans la destination choisie par Android. Le contenu exporte reste verifie byte-for-byte avant d'annoncer le succes.

Pour retrouver rapidement les fichiers E2E :

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 shell 'find /sdcard/Download -type f | grep "safebox-e2e"'
```

## Android emulator: insufficient storage

If Android reports `INSTALL_FAILED_INSUFFICIENT_STORAGE`, SafeBox now checks emulator storage automatically before installation.

Manual safe recovery (emulator only):

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run android:storage-recover
npm run android:cold-dev
```

The recovery command refuses physical Android devices. On the emulator it removes only the SafeBox development app, `/sdcard/Download/SafeBox-E2E`, and asks Android to trim caches. It does not delete unrelated Downloads files.

If the dedicated emulator is still full, use Android Studio > Device Manager > the SafeBox test AVD > **Wipe Data**, then run `npm run android:cold-dev` again.

---

## iOS — R31 Files Foundation

Prérequis une fois :

```bash
xcodebuild -version
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
brew install cocoapods
```

Vérifier iOS :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run ios:doctor
```

Vérifier R31 :

```bash
cd ~/Downloads/safebox_sbx_mvp
bash verification/verify_v026_ios_files_foundation_r31.sh
```

Lancer SafeBox sur iPhone Simulator :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run ios:cold-dev
```

Forcer un modèle :

```bash
SAFEBOX_IOS_DEVICE="iPhone 16 Pro" npm run ios:cold-dev
```

Si `ios:doctor` dit qu'aucun simulateur n'est disponible : Xcode → Settings → Platforms → installer un runtime iOS Simulator.

---

## iOS R32 — lancement non interactif

R32 force le CLI Tauri en mode CI uniquement pendant `ios:cold-dev`. Cela évite les questions du type « Would you like these outdated dependencies to be updated? » et n'effectue aucune mise à jour Homebrew automatiquement.

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run ios:doctor
npm run ios:cold-dev
```

Dans un second Terminal, quand le simulateur et SafeBox sont ouverts :

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run ios:runtime-status
```

Résultat attendu :

```text
SAFEBOX_IOS_SIMULATOR_BOOTED
SAFEBOX_IOS_APP_INSTALLED: ...
SAFEBOX_IOS_RUNTIME_STATUS_PASS
```

## iOS R33 — Simulator runtime without Apple Development Team

R33 avoids the Tauri `ios dev` archive step for simulator validation. It detects the Mac's native CPU even under Rosetta, builds the correct simulator architecture without distribution signing, installs the `.app` with `simctl`, then launches SafeBox.

```bash
cd ~/Downloads/safebox_sbx_mvp
bash verification/verify_v026_ios_simulator_runtime_r33.sh

cd safebox-desktop
npm run ios:cold-dev
```

You can force a specific available simulator by name:

```bash
SAFEBOX_IOS_DEVICE="iPhone 16 Pro" npm run ios:cold-dev
```

Expected runtime markers:

```text
SAFEBOX_IOS_NATIVE_SIM_TARGET: aarch64-sim (aarch64-apple-ios-sim)
SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: com.safebox.desktop
SAFEBOX_IOS_RUNTIME_BOOT_PASS
```

Then verify installation from another Terminal:

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run ios:runtime-status
```

A real iPhone / App Store build is intentionally separate and still requires proper Apple signing credentials; R33 does not bypass physical-device signing.

## iOS R34 — direct Simulator build (no archive)

R34 replaces the R33 `tauri ios build` runtime path. The Apple project is still generated by Tauri, but the runtime gate uses Xcode's simulator **build** action directly. It never enters `iphoneos` archive/export and therefore does not require a Development Team for the Simulator.

```bash
cd ~/Downloads/safebox_sbx_mvp
bash verification/verify_v026_ios_direct_simulator_r34.sh

cd safebox-desktop
npm run ios:cold-dev
```

Expected markers before SafeBox opens:

```text
SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_BEGIN
SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS
SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: com.safebox.desktop
SAFEBOX_IOS_RUNTIME_BOOT_PASS
```

If `ios:cold-dev` started Vite itself, keep that Terminal open. In a second Terminal:

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run ios:runtime-status
```

Expected:

```text
SAFEBOX_IOS_SIMULATOR_BOOTED
SAFEBOX_IOS_APP_INSTALLED: ...
SAFEBOX_IOS_RUNTIME_STATUS_PASS
```

R34 is simulator-only. Real iPhone/App Store signing remains unchanged and requires proper Apple signing credentials.

## iOS R35 — standalone Rust bridge for direct Simulator xcodebuild

R35 fixes the remaining R34 runtime failure where Tauri's generated `Build Rust Code` phase tried to contact a parent `TAURI_CLI_PORT` WebSocket server that does not exist during SafeBox's direct `xcodebuild` Simulator gate.

Verify the checkpoint:

```bash
cd ~/Downloads/safebox_sbx_mvp
bash verification/verify_v026_ios_standalone_rust_bridge_r35.sh
```

Expected:

```text
IOS_V026_STATUS: STANDALONE_RUST_BRIDGE_READY
SAFEBOX_V026_IOS_STANDALONE_RUST_BRIDGE_R35_VERIFY_PASS
```

Launch SafeBox:

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run ios:cold-dev
```

Expected runtime sequence on the Intel reference Mac:

```text
SAFEBOX_IOS_RUST_BRIDGE_BEGIN: x86_64-apple-ios debug
SAFEBOX_IOS_RUST_BRIDGE_SHA256: ...
SAFEBOX_IOS_RUST_BRIDGE_PASS
SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS
SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: com.safebox.desktop
SAFEBOX_IOS_RUNTIME_BOOT_PASS
```

Then, from a second Terminal while SafeBox/Vite stays running:

```bash
cd ~/Downloads/safebox_sbx_mvp/safebox-desktop
npm run ios:runtime-status
```

Expected:

```text
SAFEBOX_IOS_SIMULATOR_BOOTED
SAFEBOX_IOS_APP_INSTALLED: ...
SAFEBOX_IOS_RUNTIME_STATUS_PASS
```

R35 remains Simulator-only. The bridge explicitly refuses any non-Simulator platform; real iPhone and App Store builds continue through Tauri/Apple signing.

## iOS R36 — bridge argv hardening

Verify the current iOS checkpoint:

```bash
bash verification/verify_v026_ios_bridge_argv_hardening_r36.sh
```

Expected:

```text
SAFEBOX_V026_IOS_BRIDGE_ARGV_HARDENING_R36_VERIFY_PASS
```

Then launch the iPhone Simulator runtime:

```bash
cd safebox-desktop
npm run ios:cold-dev
```

Expected runtime markers include `SAFEBOX_IOS_RUST_BRIDGE_PASS`, `SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS`, `SAFEBOX_IOS_SIMULATOR_INSTALL_PASS`, and `SAFEBOX_IOS_RUNTIME_BOOT_PASS`.

## iOS final icon/runtime check

The iOS simulator launcher now injects the official SafeBox AppIcon set automatically after `tauri ios init`.

```bash
cd safebox-desktop
npm run ios:cold-dev
```

Expected icon marker before Xcode build:

```text
SAFEBOX_IOS_APPICON_INSTALL_PASS
```

Then expect the existing runtime markers:

```text
SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS
SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: com.safebox.desktop
SAFEBOX_IOS_RUNTIME_BOOT_PASS
```
