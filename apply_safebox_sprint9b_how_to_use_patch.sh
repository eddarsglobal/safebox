#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9B — How To Use SafeBox
# Adds a professional Help / How To Use modal with multilingual content.
# Does NOT touch encryption / SBX format / unlock logic.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint9b-howto.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint9b-howto.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint9b-how-to-use-safebox-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 9B — Professional How To Use modal
// Marker: sprint9b-how-to-use-safebox-v1
type SbxHowToLang = "en" | "fr" | "de" | "hr" | "es" | "ar";
type SbxHowToBlock = { title: string; items: string[] };
type SbxHowToContent = { help: string; title: string; subtitle: string; close: string; blocks: SbxHowToBlock[] };

const SBX_HOWTO: Record<SbxHowToLang, SbxHowToContent> = {
  en: { help: "Help", title: "How to Use SafeBox", subtitle: "Create, send and unlock encrypted .sbx files safely.", close: "Close", blocks: [
    { title: "What is SafeBox?", items: ["SafeBox creates an encrypted file with the .sbx extension.", "The receiver only sees the .sbx file until the correct code is entered.", "The original filename, extension and content stay hidden before unlock."] },
    { title: "Create a SafeBox file", items: ["Choose a file, enter a code, then create the SafeBox file.", "By default the visible file name is document.sbx.", "Use a strong code and send it through a different channel than the .sbx file."] },
    { title: "Send a .sbx file", items: ["Send it like any normal file: email, USB, AirDrop, cloud drive or messenger.", "The receiver does not need an online account to unlock it.", "Do not send the unlock code in the same message as the .sbx file."] },
    { title: "Unlock a received .sbx file", items: ["Open the .sbx file with SafeBox, enter the code, then press Unlock.", "After a successful unlock, the original file is restored.", "In the current MVP, the local .sbx is removed after unlock."] },
    { title: "File info", items: ["Before unlock, the receiver screen stays minimal.", "Optional public information appears only inside File info.", "File info is public metadata, not secret encrypted content."] },
    { title: "Access Profiles", items: ["Access Profiles are optional.", "Keep them empty for a simple workflow.", "Add a profile only when you need separate access for family, work, clients or private files."] },
    { title: "Security notes", items: ["SafeBox protects file content with encryption and a code.", "Security depends on the strength and secrecy of the code.", "Share the code separately and avoid obvious words, names or dates."] },
    { title: "macOS .sbx files", items: ["SafeBox registers .sbx as a macOS file type.", "Double-clicking a .sbx should open SafeBox in receiver mode.", "Finder may cache icons and file associations after updates."] },
    { title: "Current MVP limits", items: ["Global code and profile codes are kept only for the current app session.", "Permanent secure storage will come later with Keychain / Credential Manager.", "Offline burn is local-only: it removes the local .sbx after successful unlock."] }
  ]},
  fr: { help: "Aide", title: "Comment utiliser SafeBox", subtitle: "Créer, envoyer et ouvrir des fichiers chiffrés .sbx.", close: "Fermer", blocks: [
    { title: "Qu’est-ce que SafeBox ?", items: ["SafeBox crée un fichier chiffré avec l’extension .sbx.", "Le destinataire voit seulement le fichier .sbx tant que le bon code n’est pas entré.", "Le nom original, l’extension et le contenu restent cachés avant le déverrouillage."] },
    { title: "Créer un fichier SafeBox", items: ["Choisissez un fichier, entrez un code, puis créez le fichier SafeBox.", "Par défaut, le nom visible est document.sbx.", "Utilisez un code fort et envoyez-le par un autre canal que le fichier .sbx."] },
    { title: "Envoyer un fichier .sbx", items: ["Envoyez le .sbx comme un fichier normal : email, USB, AirDrop, cloud ou messagerie.", "Le destinataire n’a pas besoin d’un compte en ligne pour l’ouvrir.", "N’envoyez pas le code dans le même message que le fichier .sbx."] },
    { title: "Ouvrir un .sbx reçu", items: ["Ouvrez le .sbx avec SafeBox, entrez le code, puis cliquez sur Unlock.", "Après un déverrouillage réussi, le fichier original est restauré.", "Dans le MVP actuel, le .sbx local est supprimé après ouverture."] },
    { title: "File info", items: ["Avant le code, l’écran destinataire reste minimal.", "Les informations publiques optionnelles apparaissent seulement dans File info.", "File info est une métadonnée publique, pas un contenu secret chiffré."] },
    { title: "Access Profiles", items: ["Les Access Profiles sont optionnels.", "Laissez-les vides pour un flux simple.", "Ajoutez un profil seulement pour un accès séparé : famille, travail, clients ou fichiers privés."] },
    { title: "Notes de sécurité", items: ["SafeBox protège le contenu avec chiffrement et code.", "La sécurité dépend de la force et du secret du code.", "Envoyez le code séparément et évitez les mots, noms ou dates évidents."] },
    { title: "Fichiers .sbx sur macOS", items: ["SafeBox enregistre .sbx comme type de fichier macOS.", "Un double-clic sur un .sbx doit ouvrir SafeBox en mode destinataire.", "Finder peut garder d’anciens caches d’icône ou d’association après update."] },
    { title: "Limites MVP actuelles", items: ["Le global code et les codes de profils sont gardés seulement pour la session actuelle.", "Le stockage sécurisé permanent viendra plus tard avec Keychain / Credential Manager.", "Offline burn est local : il supprime le .sbx local après déverrouillage réussi."] }
  ]},
  de: { help: "Hilfe", title: "SafeBox verwenden", subtitle: "Verschlüsselte .sbx-Dateien erstellen, senden und öffnen.", close: "Schliessen", blocks: [
    { title: "Was ist SafeBox?", items: ["SafeBox erstellt eine verschlüsselte Datei mit der Endung .sbx.", "Der Empfänger sieht nur die .sbx-Datei bis der richtige Code eingegeben wird.", "Originalname, Endung und Inhalt bleiben vor dem Entsperren verborgen."] },
    { title: "Datei erstellen", items: ["Datei wählen, Code eingeben und SafeBox-Datei erstellen.", "Standardmässig heisst die sichtbare Datei document.sbx.", "Sende den Code getrennt von der .sbx-Datei."] },
    { title: "Senden", items: ["Sende die .sbx wie eine normale Datei: E-Mail, USB, AirDrop, Cloud oder Messenger.", "Der Empfänger braucht kein Online-Konto.", "Sende den Code nicht in derselben Nachricht."] },
    { title: "Öffnen", items: ["Öffne die .sbx mit SafeBox, gib den Code ein und klicke Unlock.", "Danach wird die Originaldatei wiederhergestellt.", "Im MVP wird die lokale .sbx danach entfernt."] },
    { title: "File info", items: ["Vor dem Code bleibt der Empfängerbildschirm minimal.", "Optionale öffentliche Infos erscheinen nur in File info.", "File info ist öffentliche Metadaten."] },
    { title: "Access Profiles", items: ["Access Profiles sind optional.", "Leer lassen für einfache Nutzung.", "Nur hinzufügen, wenn getrennte Zugänge nötig sind."] },
    { title: "Sicherheit", items: ["SafeBox schützt den Inhalt mit Verschlüsselung und Code.", "Sicherheit hängt von Stärke und Geheimhaltung des Codes ab.", "Code getrennt senden und offensichtliche Daten vermeiden."] },
    { title: "macOS .sbx", items: ["SafeBox registriert .sbx als macOS-Dateityp.", "Doppelklick soll SafeBox im Empfängermodus öffnen.", "Finder kann Icons und Zuordnungen cachen."] },
    { title: "MVP-Grenzen", items: ["Codes gelten nur für die aktuelle Sitzung.", "Keychain / Credential Manager kommt später.", "Offline burn ist lokal-only."] }
  ]},
  hr: { help: "Pomoć", title: "Kako koristiti SafeBox", subtitle: "Kreiranje, slanje i otvaranje šifriranih .sbx datoteka.", close: "Zatvori", blocks: [
    { title: "Što je SafeBox?", items: ["SafeBox stvara šifriranu datoteku s nastavkom .sbx.", "Primatelj vidi samo .sbx dok ne unese točan kod.", "Originalni naziv, ekstenzija i sadržaj ostaju skriveni prije otključavanja."] },
    { title: "Kreiranje", items: ["Odaberi datoteku, unesi kod i kreiraj SafeBox.", "Zadani vidljivi naziv je document.sbx.", "Kod pošalji drugim kanalom od .sbx datoteke."] },
    { title: "Slanje", items: ["Pošalji .sbx kao normalnu datoteku: email, USB, AirDrop, cloud ili messenger.", "Primatelju ne treba online račun.", "Nemoj slati kod u istoj poruci."] },
    { title: "Otvaranje", items: ["Otvori .sbx sa SafeBoxom, unesi kod i klikni Unlock.", "Originalna datoteka se vraća nakon uspješnog otključavanja.", "U MVP-u se lokalni .sbx nakon toga uklanja."] },
    { title: "File info", items: ["Prije koda ekran primatelja ostaje minimalan.", "Javne informacije vide se samo u File info.", "File info nije tajni šifrirani sadržaj."] },
    { title: "Access Profiles", items: ["Access Profiles su opcionalni.", "Ostavi ih prazne za jednostavan rad.", "Dodaj profil samo za odvojeni pristup."] },
    { title: "Sigurnost", items: ["SafeBox štiti sadržaj šifriranjem i kodom.", "Sigurnost ovisi o jačini i tajnosti koda.", "Kod šalji odvojeno i izbjegavaj očite riječi ili datume."] },
    { title: "macOS .sbx", items: ["SafeBox registrira .sbx kao macOS tip datoteke.", "Dvoklik na .sbx treba otvoriti receiver mode.", "Finder može zadržati cache nakon updatea."] },
    { title: "MVP ograničenja", items: ["Kodovi vrijede samo za trenutnu sesiju.", "Keychain / Credential Manager dolaze kasnije.", "Offline burn je lokalni-only."] }
  ]},
  es: { help: "Ayuda", title: "Cómo usar SafeBox", subtitle: "Crear, enviar y abrir archivos cifrados .sbx.", close: "Cerrar", blocks: [
    { title: "¿Qué es SafeBox?", items: ["SafeBox crea un archivo cifrado .sbx.", "El receptor solo ve el .sbx hasta introducir el código correcto.", "Nombre original, extensión y contenido quedan ocultos antes de abrir."] },
    { title: "Crear", items: ["Elige archivo, introduce código y crea SafeBox.", "Por defecto se ve document.sbx.", "Envía el código por otro canal."] },
    { title: "Enviar", items: ["Envía .sbx como archivo normal: email, USB, AirDrop, nube o messenger.", "El receptor no necesita cuenta online.", "No envíes el código junto al archivo."] },
    { title: "Abrir", items: ["Abre .sbx con SafeBox, introduce código y pulsa Unlock.", "Se restaura el archivo original.", "En MVP se elimina el .sbx local después."] },
    { title: "File info", items: ["La pantalla del receptor queda mínima.", "Información pública aparece solo en File info.", "No es contenido secreto cifrado."] },
    { title: "Access Profiles", items: ["Son opcionales.", "Déjalos vacíos para uso simple.", "Añade perfiles solo para accesos separados."] },
    { title: "Seguridad", items: ["SafeBox protege con cifrado y código.", "La seguridad depende del código.", "Comparte el código por separado."] },
    { title: "macOS .sbx", items: ["SafeBox registra .sbx en macOS.", "Doble clic abre receiver mode.", "Finder puede guardar caché."] },
    { title: "Límites MVP", items: ["Códigos solo por sesión.", "Keychain / Credential Manager vendrán después.", "Offline burn es local-only."] }
  ]},
  ar: { help: "مساعدة", title: "طريقة استخدام SafeBox", subtitle: "إنشاء وإرسال وفتح ملفات .sbx مشفرة.", close: "إغلاق", blocks: [
    { title: "ما هو SafeBox؟", items: ["SafeBox ينشئ ملفاً مشفراً بامتداد .sbx.", "المستلم يرى ملف .sbx فقط حتى إدخال الكود الصحيح.", "الاسم والامتداد والمحتوى الأصلي تبقى مخفية قبل الفتح."] },
    { title: "إنشاء ملف", items: ["اختر ملفاً، أدخل الكود، ثم أنشئ SafeBox.", "الاسم الافتراضي هو document.sbx.", "أرسل الكود عبر قناة مختلفة."] },
    { title: "إرسال .sbx", items: ["أرسل .sbx كأي ملف عادي: بريد، USB، AirDrop، cloud أو messenger.", "لا يحتاج المستلم إلى حساب أونلاين.", "لا ترسل الكود مع نفس الرسالة."] },
    { title: "فتح ملف", items: ["افتح .sbx مع SafeBox، أدخل الكود واضغط Unlock.", "يتم استرجاع الملف الأصلي بعد النجاح.", "في MVP يتم حذف .sbx المحلي بعد الفتح."] },
    { title: "File info", items: ["قبل الكود تبقى شاشة المستلم بسيطة.", "المعلومات العامة تظهر فقط داخل File info.", "ليست محتوى سرياً مشفراً."] },
    { title: "Access Profiles", items: ["اختياري.", "اتركه فارغاً للاستعمال البسيط.", "أضف بروفايل فقط عند الحاجة لوصول منفصل."] },
    { title: "الأمان", items: ["SafeBox يحمي المحتوى بالتشفير والكود.", "الأمان يعتمد على قوة وسرية الكود.", "أرسل الكود بشكل منفصل."] },
    { title: "macOS .sbx", items: ["SafeBox يسجل .sbx كنوع ملف macOS.", "النقر مرتين يفتح وضع المستلم.", "Finder قد يحتفظ بالكاش."] },
    { title: "حدود MVP", items: ["الأكواد محفوظة فقط خلال جلسة التطبيق.", "Keychain / Credential Manager سيأتي لاحقاً.", "Offline burn محلي فقط."] }
  ]}
};

function sbxHowToLang(): SbxHowToLang {
  const stored = localStorage.getItem("safebox.language.v1") || "auto";
  const raw = stored === "auto" ? navigator.language : stored;
  const l = raw.toLowerCase();
  if (l.startsWith("fr")) return "fr";
  if (l.startsWith("de")) return "de";
  if (l.startsWith("hr") || l.startsWith("sr") || l.startsWith("bs")) return "hr";
  if (l.startsWith("es")) return "es";
  if (l.startsWith("ar")) return "ar";
  return "en";
}

function sbxHowToEsc(v: string) {
  return v.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
}

function sbxHowToContent() {
  return SBX_HOWTO[sbxHowToLang()] || SBX_HOWTO.en;
}

function ensureHowToUseButton() {
  let b = document.querySelector<HTMLButtonElement>("#howToUseBtn");
  if (!b) {
    b = document.createElement("button");
    b.id = "howToUseBtn";
    b.className = "mini-btn how-to-use-btn";
    b.type = "button";
    const target = document.querySelector<HTMLElement>(".top-actions") || document.querySelector<HTMLElement>(".app-actions") || document.querySelector<HTMLElement>(".header-actions") || document.querySelector<HTMLElement>("header") || document.querySelector<HTMLElement>("#app") || document.body;
    target.appendChild(b);
  }
  b.textContent = sbxHowToContent().help;
  return b;
}

function ensureHowToUseModal() {
  let m = document.querySelector<HTMLElement>("#howToUseModal");
  if (!m) {
    m = document.createElement("div");
    m.id = "howToUseModal";
    m.className = "modal-backdrop hidden how-to-use-modal";
    document.body.appendChild(m);
    m.addEventListener("click", (event) => { if (event.target === m) m?.classList.add("hidden"); });
  }
  return m;
}

function renderHowToUseModal() {
  const m = ensureHowToUseModal();
  const c = sbxHowToContent();
  const rtl = sbxHowToLang() === "ar";
  m.dir = rtl ? "rtl" : "ltr";
  m.innerHTML = `
    <section class="settings-modal how-to-use-card" role="dialog" aria-modal="true" aria-labelledby="howToUseTitle">
      <div class="modal-head how-to-use-head">
        <div><h2 id="howToUseTitle">${sbxHowToEsc(c.title)}</h2><p>${sbxHowToEsc(c.subtitle)}</p></div>
        <button id="closeHowToUseBtn" class="icon-btn" type="button">×</button>
      </div>
      <div class="how-to-use-body">
        ${c.blocks.map((block, index) => `
          <article class="how-to-section">
            <div class="how-to-section-number">${String(index + 1).padStart(2, "0")}</div>
            <div><h3>${sbxHowToEsc(block.title)}</h3><ul>${block.items.map(item => `<li>${sbxHowToEsc(item)}</li>`).join("")}</ul></div>
          </article>`).join("")}
      </div>
      <div class="settings-actions how-to-use-actions"><button id="closeHowToUseFooterBtn" class="primary-btn" type="button">${sbxHowToEsc(c.close)}</button></div>
    </section>`;
  m.querySelector("#closeHowToUseBtn")?.addEventListener("click", () => m.classList.add("hidden"));
  m.querySelector("#closeHowToUseFooterBtn")?.addEventListener("click", () => m.classList.add("hidden"));
}

function openHowToUseModal() {
  renderHowToUseModal();
  ensureHowToUseModal().classList.remove("hidden");
}

function initHowToUseSafeBox() {
  const b = ensureHowToUseButton();
  if (b.dataset.sbxHowToBound !== "1") {
    b.dataset.sbxHowToBound = "1";
    b.addEventListener("click", (event) => { event.preventDefault(); event.stopPropagation(); openHowToUseModal(); });
  }
  renderHowToUseModal();
}

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") document.querySelector<HTMLElement>("#howToUseModal")?.classList.add("hidden");
});

document.addEventListener("change", (event) => {
  if ((event.target as HTMLElement | null)?.id === "settingsLanguageSelect") {
    setTimeout(initHowToUseSafeBox, 50);
    setTimeout(initHowToUseSafeBox, 250);
  }
});

document.querySelector("#settingsBtn")?.addEventListener("click", () => setTimeout(initHowToUseSafeBox, 120));
setTimeout(initHowToUseSafeBox, 100);
setTimeout(initHowToUseSafeBox, 500);
setInterval(() => {
  const b = document.querySelector<HTMLButtonElement>("#howToUseBtn");
  if (!b) initHowToUseSafeBox();
  else b.textContent = sbxHowToContent().help;
}, 1200);

console.debug("sprint9b-how-to-use-safebox-v1");
TS
fi

if ! grep -q "--sprint9b-how-to-use-safebox-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 9B — How To Use SafeBox */
:root { --sprint9b-how-to-use-safebox-v1: 1; }
.how-to-use-btn { white-space: nowrap !important; }
.how-to-use-modal { z-index: 1000002 !important; }
.how-to-use-card {
  width: min(860px, calc(100vw - 48px)) !important;
  height: min(860px, calc(100vh - 48px)) !important;
  max-height: calc(100vh - 48px) !important;
  display: flex !important;
  flex-direction: column !important;
  overflow: hidden !important;
  padding: 0 !important;
}
.how-to-use-head { flex: 0 0 auto !important; padding: 24px 28px 18px !important; }
.how-to-use-body {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow-y: auto !important;
  overflow-x: hidden !important;
  padding: 18px 28px 110px !important;
  display: grid !important;
  gap: 14px !important;
  scrollbar-gutter: stable !important;
}
.how-to-section {
  display: grid !important;
  grid-template-columns: 48px minmax(0, 1fr) !important;
  gap: 16px !important;
  padding: 18px !important;
  border: 1px solid rgba(150, 170, 195, 0.20) !important;
  border-radius: 16px !important;
  background: rgba(255,255,255,0.045) !important;
}
.how-to-section-number {
  width: 40px !important;
  height: 40px !important;
  display: grid !important;
  place-items: center !important;
  border-radius: 12px !important;
  background: rgba(93,190,255,0.10) !important;
  border: 1px solid rgba(93,190,255,0.24) !important;
  color: #8FD3FF !important;
  font-size: 12px !important;
  font-weight: 900 !important;
}
.how-to-section h3 { margin: 0 0 10px !important; font-size: 15px !important; font-weight: 900 !important; color: var(--text) !important; }
.how-to-section ul { margin: 0 !important; padding-left: 18px !important; display: grid !important; gap: 7px !important; }
.how-to-section li { color: var(--muted) !important; font-size: 13px !important; line-height: 1.55 !important; }
.how-to-use-modal[dir="rtl"] .how-to-section ul { padding-left: 0 !important; padding-right: 18px !important; }
.how-to-use-actions { flex: 0 0 auto !important; padding: 16px 28px 22px !important; border-top: 1px solid rgba(150,170,195,0.20) !important; }
.how-to-use-body::-webkit-scrollbar { width: 10px !important; }
.how-to-use-body::-webkit-scrollbar-thumb { background: rgba(150,170,195,0.40) !important; border-radius: 999px !important; }
.how-to-use-body::-webkit-scrollbar-track { background: transparent !important; }
@media (max-width: 760px) {
  .how-to-use-card { width: calc(100vw - 24px) !important; height: calc(100vh - 24px) !important; }
  .how-to-section { grid-template-columns: 1fr !important; }
  .how-to-section-number { width: 34px !important; height: 34px !important; }
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 9B marker"
grep -R "sprint9b-how-to-use-safebox-v1" dist || echo "ERROR: Sprint 9B marker absent from dist"

echo ""
echo "Sprint 9B How To Use SafeBox applied."
echo "Run: npm run tauri dev"
