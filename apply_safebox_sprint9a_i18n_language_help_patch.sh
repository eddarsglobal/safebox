#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9A — i18n Foundation + Language Selector + Help Entry
#
# Adds:
# - Language selector in Settings -> General
# - Auto/System language detection
# - Manual language preference saved in localStorage
# - Supported locales: EN, FR, DE, HR/BCS, AR, ES
# - Help button in top actions
# - "How to Use SafeBox" modal foundation
#
# Does not change encryption / unlock / SBX format.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup frontend"
cp src/main.ts "src/main.ts.backup-sprint9a-i18n.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint9a-i18n.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

if "SAFEBOX_I18N_SPRINT9A_MARKER" not in text:
    text += r'''

type SafeBoxLocaleChoice = "auto" | "en" | "fr" | "de" | "hr" | "ar" | "es";
type SafeBoxResolvedLocale = Exclude<SafeBoxLocaleChoice, "auto">;

const SAFEBOX_LANGUAGE_KEY = "safebox.language.v1";
const SAFEBOX_SUPPORTED_LOCALES: SafeBoxLocaleChoice[] = ["auto", "en", "fr", "de", "hr", "ar", "es"];

const SAFEBOX_I18N: Record<SafeBoxResolvedLocale, Record<string, string>> = {
  en: {
    help: "Help",
    howToUse: "How to Use SafeBox",
    close: "Close",
    language: "Language",
    autoSystem: "Auto – System language",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    general: "General",
    accessProfiles: "Access Profiles",
    security: "Security",
    helpIntro: "SafeBox creates encrypted .sbx files. The receiver only needs SafeBox and the correct code.",
    helpWhatIsSbxTitle: "What is an .sbx file?",
    helpWhatIsSbxText: "An .sbx file is an encrypted SafeBox file. The original filename, extension and content stay hidden until unlock.",
    helpCodeTitle: "What is the code?",
    helpCodeText: "The code is the secret shared between sender and receiver. Without it, the .sbx file cannot be opened.",
    helpProfilesTitle: "What are Access Profiles?",
    helpProfilesText: "Access Profiles are optional. They help you use different codes and labels for family, work, clients or private files.",
    helpNameTitle: "Name in SafeBox vs Shown in File info",
    helpNameText: "Name in SafeBox is only for you. Shown in File info is what the receiver can see after clicking File info.",
    helpBurnTitle: "What happens after unlock?",
    helpBurnText: "After a correct unlock, SafeBox restores the original file and removes the local .sbx copy.",
    helpMoreLater: "More detailed help and examples will be added in the next Help sprint."
  },
  fr: {
    help: "Aide",
    howToUse: "Comment utiliser SafeBox",
    close: "Fermer",
    language: "Langue",
    autoSystem: "Auto – langue du système",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    general: "Général",
    accessProfiles: "Profils d’accès",
    security: "Sécurité",
    helpIntro: "SafeBox crée des fichiers .sbx chiffrés. Le receveur a seulement besoin de SafeBox et du bon code.",
    helpWhatIsSbxTitle: "Qu’est-ce qu’un fichier .sbx ?",
    helpWhatIsSbxText: "Un fichier .sbx est un fichier SafeBox chiffré. Le nom original, l’extension et le contenu restent cachés jusqu’au déverrouillage.",
    helpCodeTitle: "Qu’est-ce que le code ?",
    helpCodeText: "Le code est le secret partagé entre l’expéditeur et le receveur. Sans lui, le fichier .sbx ne peut pas être ouvert.",
    helpProfilesTitle: "Que sont les profils d’accès ?",
    helpProfilesText: "Les profils d’accès sont optionnels. Ils servent à utiliser différents codes et labels pour famille, travail, clients ou fichiers privés.",
    helpNameTitle: "Name in SafeBox vs Shown in File info",
    helpNameText: "Name in SafeBox est seulement pour toi. Shown in File info est ce que le receveur peut voir en cliquant sur File info.",
    helpBurnTitle: "Que se passe-t-il après le déverrouillage ?",
    helpBurnText: "Après un déverrouillage correct, SafeBox restaure le fichier original et supprime la copie locale .sbx.",
    helpMoreLater: "Une aide plus détaillée avec exemples sera ajoutée dans le prochain sprint Help."
  },
  de: {
    help: "Hilfe",
    howToUse: "SafeBox verwenden",
    close: "Schließen",
    language: "Sprache",
    autoSystem: "Auto – Systemsprache",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    general: "Allgemein",
    accessProfiles: "Zugriffsprofile",
    security: "Sicherheit",
    helpIntro: "SafeBox erstellt verschlüsselte .sbx-Dateien. Der Empfänger braucht nur SafeBox und den richtigen Code.",
    helpWhatIsSbxTitle: "Was ist eine .sbx-Datei?",
    helpWhatIsSbxText: "Eine .sbx-Datei ist eine verschlüsselte SafeBox-Datei. Originalname, Erweiterung und Inhalt bleiben bis zum Entsperren verborgen.",
    helpCodeTitle: "Was ist der Code?",
    helpCodeText: "Der Code ist das gemeinsame Geheimnis zwischen Sender und Empfänger. Ohne ihn kann die .sbx-Datei nicht geöffnet werden.",
    helpProfilesTitle: "Was sind Zugriffsprofile?",
    helpProfilesText: "Zugriffsprofile sind optional. Sie helfen, verschiedene Codes und Labels für Familie, Arbeit, Kunden oder private Dateien zu nutzen.",
    helpNameTitle: "Name in SafeBox vs Shown in File info",
    helpNameText: "Name in SafeBox ist nur für dich. Shown in File info ist das, was der Empfänger unter File info sehen kann.",
    helpBurnTitle: "Was passiert nach dem Entsperren?",
    helpBurnText: "Nach dem richtigen Entsperren stellt SafeBox die Originaldatei wieder her und entfernt die lokale .sbx-Kopie.",
    helpMoreLater: "Detailliertere Hilfe mit Beispielen kommt im nächsten Help-Sprint."
  },
  hr: {
    help: "Pomoć",
    howToUse: "Kako koristiti SafeBox",
    close: "Zatvori",
    language: "Jezik",
    autoSystem: "Auto – jezik sistema",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    general: "Opšte",
    accessProfiles: "Pristupni profili",
    security: "Sigurnost",
    helpIntro: "SafeBox stvara šifrirane .sbx fajlove. Primaocu treba samo SafeBox i tačan kod.",
    helpWhatIsSbxTitle: "Šta je .sbx fajl?",
    helpWhatIsSbxText: ".sbx je šifrirani SafeBox fajl. Originalno ime, ekstenzija i sadržaj ostaju skriveni dok se fajl ne otključa.",
    helpCodeTitle: "Šta je kod?",
    helpCodeText: "Kod je tajna koju dijele pošiljalac i primalac. Bez njega .sbx fajl ne može da se otvori.",
    helpProfilesTitle: "Šta su pristupni profili?",
    helpProfilesText: "Pristupni profili su opcionalni. Koriste se za različite kodove i labele za porodicu, posao, klijente ili privatne fajlove.",
    helpNameTitle: "Name in SafeBox vs Shown in File info",
    helpNameText: "Name in SafeBox je samo za tebe. Shown in File info je ono što primalac vidi kad klikne File info.",
    helpBurnTitle: "Šta se dešava nakon otključavanja?",
    helpBurnText: "Nakon tačnog koda SafeBox vraća originalni fajl i uklanja lokalnu .sbx kopiju.",
    helpMoreLater: "Detaljnije uputstvo i primjeri dolaze u sljedećem Help sprintu."
  },
  ar: {
    help: "مساعدة",
    howToUse: "كيفية استخدام SafeBox",
    close: "إغلاق",
    language: "اللغة",
    autoSystem: "تلقائي – لغة النظام",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    general: "عام",
    accessProfiles: "ملفات الوصول",
    security: "الأمان",
    helpIntro: "SafeBox ينشئ ملفات .sbx مشفرة. يحتاج المستقبل فقط إلى SafeBox والرمز الصحيح.",
    helpWhatIsSbxTitle: "ما هو ملف .sbx؟",
    helpWhatIsSbxText: "ملف .sbx هو ملف SafeBox مشفر. يبقى اسم الملف الأصلي والامتداد والمحتوى مخفيًا حتى فتحه.",
    helpCodeTitle: "ما هو الرمز؟",
    helpCodeText: "الرمز هو السر المشترك بين المرسل والمستقبل. بدونه لا يمكن فتح ملف .sbx.",
    helpProfilesTitle: "ما هي ملفات الوصول؟",
    helpProfilesText: "ملفات الوصول اختيارية. تساعدك على استخدام رموز وتسميات مختلفة للعائلة أو العمل أو العملاء أو الملفات الخاصة.",
    helpNameTitle: "Name in SafeBox vs Shown in File info",
    helpNameText: "Name in SafeBox يظهر لك فقط. Shown in File info هو ما يمكن للمستقبل رؤيته عند الضغط على File info.",
    helpBurnTitle: "ماذا يحدث بعد الفتح؟",
    helpBurnText: "بعد إدخال الرمز الصحيح، يسترجع SafeBox الملف الأصلي ويحذف نسخة .sbx المحلية.",
    helpMoreLater: "سيتم إضافة شرح مفصل وأمثلة في Sprint المساعدة التالي."
  },
  es: {
    help: "Ayuda",
    howToUse: "Cómo usar SafeBox",
    close: "Cerrar",
    language: "Idioma",
    autoSystem: "Auto – idioma del sistema",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    general: "General",
    accessProfiles: "Perfiles de acceso",
    security: "Seguridad",
    helpIntro: "SafeBox crea archivos .sbx cifrados. El receptor solo necesita SafeBox y el código correcto.",
    helpWhatIsSbxTitle: "¿Qué es un archivo .sbx?",
    helpWhatIsSbxText: "Un archivo .sbx es un archivo SafeBox cifrado. El nombre original, la extensión y el contenido quedan ocultos hasta desbloquearlo.",
    helpCodeTitle: "¿Qué es el código?",
    helpCodeText: "El código es el secreto compartido entre remitente y receptor. Sin él, el archivo .sbx no se puede abrir.",
    helpProfilesTitle: "¿Qué son los perfiles de acceso?",
    helpProfilesText: "Los perfiles de acceso son opcionales. Ayudan a usar diferentes códigos y etiquetas para familia, trabajo, clientes o archivos privados.",
    helpNameTitle: "Name in SafeBox vs Shown in File info",
    helpNameText: "Name in SafeBox es solo para ti. Shown in File info es lo que el receptor puede ver al hacer clic en File info.",
    helpBurnTitle: "¿Qué ocurre después de desbloquear?",
    helpBurnText: "Después de un desbloqueo correcto, SafeBox restaura el archivo original y elimina la copia local .sbx.",
    helpMoreLater: "La ayuda más detallada con ejemplos se añadirá en el próximo sprint Help."
  }
};

function sbxHtmlEscape(value: string): string {
  return value.replace(/[&<>'"]/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#039;",
    '"': "&quot;"
  }[char] ?? char));
}

function sbxStoredLanguageChoice(): SafeBoxLocaleChoice {
  const stored = localStorage.getItem(SAFEBOX_LANGUAGE_KEY) as SafeBoxLocaleChoice | null;
  return stored && SAFEBOX_SUPPORTED_LOCALES.includes(stored) ? stored : "auto";
}

function sbxDetectSystemLanguage(): SafeBoxResolvedLocale {
  const languages = navigator.languages?.length ? navigator.languages : [navigator.language || "en"];
  const first = (languages[0] || "en").toLowerCase();

  if (first.startsWith("fr")) return "fr";
  if (first.startsWith("de")) return "de";
  if (first.startsWith("hr") || first.startsWith("bs") || first.startsWith("sr") || first.startsWith("sh")) return "hr";
  if (first.startsWith("ar")) return "ar";
  if (first.startsWith("es")) return "es";

  return "en";
}

function sbxResolvedLanguage(): SafeBoxResolvedLocale {
  const choice = sbxStoredLanguageChoice();
  return choice === "auto" ? sbxDetectSystemLanguage() : choice;
}

function sbxT(key: string): string {
  const locale = sbxResolvedLanguage();
  return SAFEBOX_I18N[locale]?.[key] || SAFEBOX_I18N.en[key] || key;
}

function sbxSetText(selector: string, value: string) {
  const element = document.querySelector<HTMLElement>(selector);
  if (element) element.textContent = value;
}

function sbxEnsureHelpButton() {
  if (document.querySelector("#helpBtn")) return;

  const settingsButton = document.querySelector<HTMLElement>("#settingsBtn");
  const parent = settingsButton?.parentElement || document.querySelector<HTMLElement>(".top-actions");

  if (!parent) return;

  const helpButton = document.createElement("button");
  helpButton.id = "helpBtn";
  helpButton.className = settingsButton?.className || "ghost-btn";
  helpButton.type = "button";
  helpButton.textContent = sbxT("help");

  if (settingsButton) {
    parent.insertBefore(helpButton, settingsButton.nextSibling);
  } else {
    parent.appendChild(helpButton);
  }

  helpButton.addEventListener("click", () => {
    sbxEnsureHelpModal();
    sbxRenderHelpModal();
    document.querySelector<HTMLElement>("#howToUseModal")?.classList.remove("hidden");
  });
}

function sbxEnsureLanguageSelector() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const existing = modal.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  const generalPanel =
    modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="general"]') ||
    modal.querySelector<HTMLElement>("#settingsTabsRoot") ||
    modal.querySelector<HTMLElement>(".settings-content") ||
    modal.querySelector<HTMLElement>(".modal-content") ||
    modal;

  if (!generalPanel) return;

  if (!existing) {
    const wrapper = document.createElement("label");
    wrapper.id = "settingsLanguageField";
    wrapper.className = "settings-language-field";
    wrapper.innerHTML = `
      <span class="settings-language-title"></span>
      <select id="settingsLanguageSelect">
        <option value="auto"></option>
        <option value="en"></option>
        <option value="fr"></option>
        <option value="de"></option>
        <option value="hr"></option>
        <option value="ar"></option>
        <option value="es"></option>
      </select>
    `;

    const firstChild = generalPanel.firstElementChild;
    if (firstChild) {
      generalPanel.insertBefore(wrapper, firstChild);
    } else {
      generalPanel.appendChild(wrapper);
    }

    const select = wrapper.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
    select?.addEventListener("change", () => {
      localStorage.setItem(SAFEBOX_LANGUAGE_KEY, select.value);
      sbxApplyI18n();
    });
  }

  const select = modal.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (select) {
    select.value = sbxStoredLanguageChoice();

    const labels: Record<SafeBoxLocaleChoice, string> = {
      auto: sbxT("autoSystem"),
      en: sbxT("english"),
      fr: sbxT("french"),
      de: sbxT("german"),
      hr: sbxT("croatian"),
      ar: sbxT("arabic"),
      es: sbxT("spanish")
    };

    Array.from(select.options).forEach((option) => {
      option.textContent = labels[option.value as SafeBoxLocaleChoice] || option.value;
    });
  }

  const title = modal.querySelector<HTMLElement>(".settings-language-title");
  if (title) title.textContent = sbxT("language");
}

function sbxEnsureHelpModal() {
  if (document.querySelector("#howToUseModal")) return;

  const modal = document.createElement("div");
  modal.id = "howToUseModal";
  modal.className = "modal-backdrop hidden";
  modal.innerHTML = `
    <section class="settings-modal help-modal-card" role="dialog" aria-modal="true">
      <div class="modal-head">
        <div>
          <h2 id="howToUseTitle"></h2>
          <p id="howToUseIntro"></p>
        </div>
        <button id="closeHelpBtn" class="icon-btn" type="button">×</button>
      </div>

      <div id="howToUseContent" class="help-content"></div>

      <div class="settings-actions">
        <button id="closeHelpFooterBtn" class="primary-btn" type="button"></button>
      </div>
    </section>
  `;

  document.body.appendChild(modal);

  document.querySelector("#closeHelpBtn")?.addEventListener("click", () => {
    document.querySelector("#howToUseModal")?.classList.add("hidden");
  });

  document.querySelector("#closeHelpFooterBtn")?.addEventListener("click", () => {
    document.querySelector("#howToUseModal")?.classList.add("hidden");
  });

  modal.addEventListener("click", (event) => {
    if (event.target === modal) modal.classList.add("hidden");
  });
}

function sbxRenderHelpModal() {
  sbxEnsureHelpModal();

  sbxSetText("#howToUseTitle", sbxT("howToUse"));
  sbxSetText("#howToUseIntro", sbxT("helpIntro"));
  sbxSetText("#closeHelpFooterBtn", sbxT("close"));

  const content = document.querySelector<HTMLElement>("#howToUseContent");
  if (!content) return;

  const sections = [
    ["helpWhatIsSbxTitle", "helpWhatIsSbxText"],
    ["helpCodeTitle", "helpCodeText"],
    ["helpProfilesTitle", "helpProfilesText"],
    ["helpNameTitle", "helpNameText"],
    ["helpBurnTitle", "helpBurnText"]
  ];

  content.innerHTML = sections.map(([titleKey, textKey]) => `
    <article class="help-section">
      <h3>${sbxHtmlEscape(sbxT(titleKey))}</h3>
      <p>${sbxHtmlEscape(sbxT(textKey))}</p>
    </article>
  `).join("") + `
    <p class="settings-note">${sbxHtmlEscape(sbxT("helpMoreLater"))}</p>
  `;
}

function sbxTranslateSettingsTabs() {
  document.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
    const tab = button.dataset.tab;
    if (tab === "general") button.textContent = sbxT("general");
    if (tab === "profiles") button.textContent = sbxT("accessProfiles");
    if (tab === "security") button.textContent = sbxT("security");
  });
}

function sbxApplyI18n() {
  const locale = sbxResolvedLanguage();

  document.documentElement.lang = locale;
  document.documentElement.dir = locale === "ar" ? "rtl" : "ltr";

  sbxEnsureHelpButton();
  sbxEnsureLanguageSelector();
  sbxEnsureHelpModal();
  sbxTranslateSettingsTabs();
  sbxRenderHelpModal();

  sbxSetText("#helpBtn", sbxT("help"));
}

function SAFEBOX_I18N_SPRINT9A_MARKER() {
  return "i18n-language-selector-help-foundation";
}

console.debug(SAFEBOX_I18N_SPRINT9A_MARKER());

setTimeout(sbxApplyI18n, 0);
setTimeout(sbxApplyI18n, 250);

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxApplyI18n, 80);
  setTimeout(sbxApplyI18n, 250);
});

new MutationObserver(() => {
  if (document.querySelector("#settingsModal:not(.hidden)") || !document.querySelector("#helpBtn")) {
    sbxApplyI18n();
  }
}).observe(document.body, {
  childList: true,
  subtree: true
});
'''

p.write_text(text)
print("Sprint 9A i18n/help patched into src/main.ts")
PY

cat >> src/style.css <<'CSS'

/* Sprint 9A — i18n Language Selector + Help */
.settings-language-field {
  margin-bottom: 14px;
}

.settings-language-field select {
  width: 100%;
  border: 1px solid var(--border);
  color: var(--text);
  background: rgba(255, 255, 255, 0.08);
  border-radius: 16px;
  outline: none;
  padding: 14px 15px;
  font: inherit;
}

.settings-language-field select:focus {
  border-color: rgba(56, 189, 248, 0.70);
  box-shadow: 0 0 0 4px rgba(56, 189, 248, 0.12);
}

.settings-language-title {
  display: block;
  margin-bottom: 7px;
  font-weight: 800;
}

.help-modal-card {
  width: min(660px, 100%);
  max-height: min(86vh, 860px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.help-content {
  overflow-y: auto;
  padding-right: 8px;
  display: grid;
  gap: 12px;
  min-height: 0;
}

.help-section {
  border: 1px solid rgba(142, 167, 194, 0.20);
  border-radius: 18px;
  padding: 14px;
  background: rgba(8, 26, 49, 0.26);
}

.help-section h3 {
  margin: 0 0 6px;
  font-size: 15px;
  color: var(--text);
}

.help-section p {
  margin: 0;
  color: var(--muted);
  line-height: 1.48;
}

.help-content::-webkit-scrollbar {
  width: 9px;
}

.help-content::-webkit-scrollbar-thumb {
  background: rgba(121, 215, 255, 0.45);
  border-radius: 999px;
}

.help-content::-webkit-scrollbar-track {
  background: rgba(142, 167, 194, 0.08);
  border-radius: 999px;
}

:root[dir="rtl"] body {
  direction: rtl;
}

:root[dir="rtl"] input,
:root[dir="rtl"] textarea,
:root[dir="rtl"] select,
:root[dir="rtl"] code {
  direction: ltr;
  text-align: left;
}

:root[dir="rtl"] .modal-head,
:root[dir="rtl"] .topbar,
:root[dir="rtl"] .profile-card-top,
:root[dir="rtl"] .profiles-header {
  direction: rtl;
}

@media (max-width: 760px), (max-height: 760px) {
  .help-modal-card {
    max-height: calc(100vh - 20px);
  }
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 9A marker"
grep -R "i18n-language-selector-help-foundation" dist || echo "ERROR: Sprint 9A marker absent from dist"
grep -R "settingsLanguageSelect" dist || echo "ERROR: language selector absent from dist"
grep -R "howToUseModal" dist || echo "ERROR: help modal absent from dist"

echo ""
echo "Sprint 9A i18n Language + Help foundation patch applied."
echo "Run:"
echo "  npm run tauri dev"
