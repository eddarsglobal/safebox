#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9C — Full App i18n
# Language selector must change the whole SafeBox UI, not only Help.
# Does NOT touch encryption / SBX format / unlock logic.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup files"
cp src/main.ts "src/main.ts.backup-sprint9c-full-i18n.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint9c-full-i18n.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

if "sprint9c-full-app-i18n-v1" not in text:
    text += r'''

// SafeBox Sprint 9C — Full App i18n
// Marker: sprint9c-full-app-i18n-v1

type SbxFullLocale = "en" | "fr" | "de" | "hr" | "es" | "ar";

const SBX_FULL_I18N: Record<SbxFullLocale, Record<string, string>> = {
  en: {
    settings: "Settings",
    help: "Help",
    theme: "Theme",
    light: "Light",
    dark: "Dark",
    create: "Create",
    createSbx: "Create SBX",
    open: "Open",
    openSbx: "Open SBX",
    openExistingSbx: "Open existing SBX",
    chooseFile: "Choose file",
    selectFile: "Select file",
    noFileSelected: "No file selected",
    code: "Code",
    enterCode: "Enter code",
    unlock: "Unlock",
    fileInfo: "File info",
    file: "File",
    from: "From",
    access: "Access",
    note: "Note",
    save: "Save",
    cancel: "Cancel",
    close: "Close",
    show: "Show",
    hide: "Hide",
    delete: "Delete",
    edit: "Edit",
    setDefault: "Set default",
    default: "Default",
    general: "General",
    accessProfiles: "Access Profiles",
    security: "Security",
    language: "Language",
    autoSystem: "Auto - System language",
    senderDefaults: "Sender defaults",
    defaultSbxName: "Default SBX name",
    globalSenderLabel: "Global sender label",
    useGlobalCode: "Use global code by default",
    globalCode: "Global code",
    clearGlobalCode: "Clear global code",
    accessProfile: "Access profile",
    noAccessProfilesYet: "No access profiles yet.",
    keepSafeBoxSimple: "Keep SafeBox simple: add a profile only when you need separate access.",
    keepSafeBoxSimpleLong: "Keep SafeBox simple: add a profile only when you need separate access for family, work, clients or private files.",
    addProfile: "+ Add profile",
    newAccessProfile: "New Access Profile",
    editAccessProfile: "Edit Access Profile",
    nameInSafeBox: "Name in SafeBox",
    shownInFileInfo: "Shown in File info",
    senderLabel: "Sender label",
    saveProfile: "Save profile",
    profileCodesSession: "Profile codes are kept only for this app session. Profile names and labels are saved.",
    globalCodeSession: "MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.",
    keptOnlySession: "kept only for this app session",
    optionalGlobalSender: "optional, uses global sender if empty",
    howToUseSafeBox: "How to Use SafeBox",
    howToSubtitle: "Create, send and unlock encrypted .sbx files safely."
  },

  fr: {
    settings: "Paramètres",
    help: "Aide",
    theme: "Thème",
    light: "Clair",
    dark: "Sombre",
    create: "Créer",
    createSbx: "Créer SBX",
    open: "Ouvrir",
    openSbx: "Ouvrir SBX",
    openExistingSbx: "Ouvrir un SBX existant",
    chooseFile: "Choisir un fichier",
    selectFile: "Sélectionner un fichier",
    noFileSelected: "Aucun fichier sélectionné",
    code: "Code",
    enterCode: "Entrer le code",
    unlock: "Déverrouiller",
    fileInfo: "Infos fichier",
    file: "Fichier",
    from: "De",
    access: "Accès",
    note: "Note",
    save: "Enregistrer",
    cancel: "Annuler",
    close: "Fermer",
    show: "Afficher",
    hide: "Masquer",
    delete: "Supprimer",
    edit: "Modifier",
    setDefault: "Définir par défaut",
    default: "Par défaut",
    general: "Général",
    accessProfiles: "Profils d’accès",
    security: "Sécurité",
    language: "Langue",
    autoSystem: "Auto - langue du système",
    senderDefaults: "Valeurs expéditeur",
    defaultSbxName: "Nom SBX par défaut",
    globalSenderLabel: "Label expéditeur global",
    useGlobalCode: "Utiliser le code global par défaut",
    globalCode: "Code global",
    clearGlobalCode: "Effacer le code global",
    accessProfile: "Profil d’accès",
    noAccessProfilesYet: "Aucun profil d’accès pour le moment.",
    keepSafeBoxSimple: "Gardez SafeBox simple : ajoutez un profil seulement si vous avez besoin d’un accès séparé.",
    keepSafeBoxSimpleLong: "Gardez SafeBox simple : ajoutez un profil seulement si vous avez besoin d’un accès séparé pour famille, travail, clients ou fichiers privés.",
    addProfile: "+ Ajouter un profil",
    newAccessProfile: "Nouveau profil d’accès",
    editAccessProfile: "Modifier le profil d’accès",
    nameInSafeBox: "Nom dans SafeBox",
    shownInFileInfo: "Affiché dans File info",
    senderLabel: "Label expéditeur",
    saveProfile: "Enregistrer le profil",
    profileCodesSession: "Les codes de profils sont gardés seulement pour cette session. Les noms et labels sont enregistrés.",
    globalCodeSession: "MVP : le code global est gardé seulement pour cette session. Le stockage sécurisé permanent viendra plus tard avec Keychain / Credential Manager.",
    keptOnlySession: "gardé seulement pour cette session",
    optionalGlobalSender: "optionnel, utilise l’expéditeur global si vide",
    howToUseSafeBox: "Comment utiliser SafeBox",
    howToSubtitle: "Créer, envoyer et ouvrir des fichiers chiffrés .sbx."
  },

  de: {
    settings: "Einstellungen",
    help: "Hilfe",
    theme: "Design",
    light: "Hell",
    dark: "Dunkel",
    create: "Erstellen",
    createSbx: "SBX erstellen",
    open: "Öffnen",
    openSbx: "SBX öffnen",
    openExistingSbx: "Bestehende SBX öffnen",
    chooseFile: "Datei wählen",
    selectFile: "Datei auswählen",
    noFileSelected: "Keine Datei ausgewählt",
    code: "Code",
    enterCode: "Code eingeben",
    unlock: "Entsperren",
    fileInfo: "Dateiinfo",
    file: "Datei",
    from: "Von",
    access: "Zugriff",
    note: "Notiz",
    save: "Speichern",
    cancel: "Abbrechen",
    close: "Schliessen",
    show: "Anzeigen",
    hide: "Verbergen",
    delete: "Löschen",
    edit: "Bearbeiten",
    setDefault: "Als Standard setzen",
    default: "Standard",
    general: "Allgemein",
    accessProfiles: "Zugriffsprofile",
    security: "Sicherheit",
    language: "Sprache",
    autoSystem: "Auto - Systemsprache",
    senderDefaults: "Absender-Standardwerte",
    defaultSbxName: "Standard-SBX-Name",
    globalSenderLabel: "Globales Absenderlabel",
    useGlobalCode: "Globalen Code standardmässig verwenden",
    globalCode: "Globaler Code",
    clearGlobalCode: "Globalen Code löschen",
    accessProfile: "Zugriffsprofil",
    noAccessProfilesYet: "Noch keine Zugriffsprofile.",
    keepSafeBoxSimple: "Halte SafeBox einfach: Füge ein Profil nur hinzu, wenn du getrennten Zugriff brauchst.",
    keepSafeBoxSimpleLong: "Halte SafeBox einfach: Füge ein Profil nur hinzu, wenn du getrennten Zugriff für Familie, Arbeit, Kunden oder private Dateien brauchst.",
    addProfile: "+ Profil hinzufügen",
    newAccessProfile: "Neues Zugriffsprofil",
    editAccessProfile: "Zugriffsprofil bearbeiten",
    nameInSafeBox: "Name in SafeBox",
    shownInFileInfo: "In File info angezeigt",
    senderLabel: "Absenderlabel",
    saveProfile: "Profil speichern",
    profileCodesSession: "Profilcodes werden nur für diese App-Sitzung gespeichert. Profilnamen und Labels werden gespeichert.",
    globalCodeSession: "MVP: Der globale Code wird nur für diese App-Sitzung gespeichert. Permanenter sicherer Speicher kommt später mit Keychain / Credential Manager.",
    keptOnlySession: "nur für diese App-Sitzung gespeichert",
    optionalGlobalSender: "optional, nutzt globalen Absender wenn leer",
    howToUseSafeBox: "SafeBox verwenden",
    howToSubtitle: "Verschlüsselte .sbx-Dateien erstellen, senden und öffnen."
  },

  hr: {
    settings: "Postavke",
    help: "Pomoć",
    theme: "Tema",
    light: "Svijetlo",
    dark: "Tamno",
    create: "Kreiraj",
    createSbx: "Kreiraj SBX",
    open: "Otvori",
    openSbx: "Otvori SBX",
    openExistingSbx: "Otvori postojeći SBX",
    chooseFile: "Odaberi datoteku",
    selectFile: "Izaberi datoteku",
    noFileSelected: "Nijedna datoteka nije odabrana",
    code: "Kod",
    enterCode: "Unesi kod",
    unlock: "Otključaj",
    fileInfo: "Info o datoteci",
    file: "Datoteka",
    from: "Od",
    access: "Pristup",
    note: "Bilješka",
    save: "Spremi",
    cancel: "Odustani",
    close: "Zatvori",
    show: "Prikaži",
    hide: "Sakrij",
    delete: "Obriši",
    edit: "Uredi",
    setDefault: "Postavi kao zadano",
    default: "Zadano",
    general: "Općenito",
    accessProfiles: "Profili pristupa",
    security: "Sigurnost",
    language: "Jezik",
    autoSystem: "Auto - jezik sustava",
    senderDefaults: "Zadane vrijednosti pošiljatelja",
    defaultSbxName: "Zadani SBX naziv",
    globalSenderLabel: "Globalni label pošiljatelja",
    useGlobalCode: "Koristi globalni kod kao zadani",
    globalCode: "Globalni kod",
    clearGlobalCode: "Obriši globalni kod",
    accessProfile: "Profil pristupa",
    noAccessProfilesYet: "Još nema profila pristupa.",
    keepSafeBoxSimple: "Neka SafeBox ostane jednostavan: dodaj profil samo kad trebaš odvojeni pristup.",
    keepSafeBoxSimpleLong: "Neka SafeBox ostane jednostavan: dodaj profil samo kad trebaš odvojeni pristup za obitelj, posao, klijente ili privatne datoteke.",
    addProfile: "+ Dodaj profil",
    newAccessProfile: "Novi profil pristupa",
    editAccessProfile: "Uredi profil pristupa",
    nameInSafeBox: "Naziv u SafeBoxu",
    shownInFileInfo: "Prikazano u File info",
    senderLabel: "Label pošiljatelja",
    saveProfile: "Spremi profil",
    profileCodesSession: "Kodovi profila čuvaju se samo za ovu sesiju. Nazivi i labeli profila se spremaju.",
    globalCodeSession: "MVP: globalni kod čuva se samo za ovu sesiju. Trajna sigurna pohrana dolazi kasnije kroz Keychain / Credential Manager.",
    keptOnlySession: "čuva se samo za ovu sesiju",
    optionalGlobalSender: "opcionalno, koristi globalnog pošiljatelja ako je prazno",
    howToUseSafeBox: "Kako koristiti SafeBox",
    howToSubtitle: "Kreiranje, slanje i otvaranje šifriranih .sbx datoteka."
  },

  es: {
    settings: "Ajustes",
    help: "Ayuda",
    theme: "Tema",
    light: "Claro",
    dark: "Oscuro",
    create: "Crear",
    createSbx: "Crear SBX",
    open: "Abrir",
    openSbx: "Abrir SBX",
    openExistingSbx: "Abrir SBX existente",
    chooseFile: "Elegir archivo",
    selectFile: "Seleccionar archivo",
    noFileSelected: "Ningún archivo seleccionado",
    code: "Código",
    enterCode: "Introducir código",
    unlock: "Desbloquear",
    fileInfo: "Info del archivo",
    file: "Archivo",
    from: "De",
    access: "Acceso",
    note: "Nota",
    save: "Guardar",
    cancel: "Cancelar",
    close: "Cerrar",
    show: "Mostrar",
    hide: "Ocultar",
    delete: "Eliminar",
    edit: "Editar",
    setDefault: "Definir por defecto",
    default: "Por defecto",
    general: "General",
    accessProfiles: "Perfiles de acceso",
    security: "Seguridad",
    language: "Idioma",
    autoSystem: "Auto - idioma del sistema",
    senderDefaults: "Valores del remitente",
    defaultSbxName: "Nombre SBX por defecto",
    globalSenderLabel: "Etiqueta global del remitente",
    useGlobalCode: "Usar código global por defecto",
    globalCode: "Código global",
    clearGlobalCode: "Borrar código global",
    accessProfile: "Perfil de acceso",
    noAccessProfilesYet: "Aún no hay perfiles de acceso.",
    keepSafeBoxSimple: "Mantén SafeBox simple: añade un perfil solo cuando necesites acceso separado.",
    keepSafeBoxSimpleLong: "Mantén SafeBox simple: añade un perfil solo cuando necesites acceso separado para familia, trabajo, clientes o archivos privados.",
    addProfile: "+ Añadir perfil",
    newAccessProfile: "Nuevo perfil de acceso",
    editAccessProfile: "Editar perfil de acceso",
    nameInSafeBox: "Nombre en SafeBox",
    shownInFileInfo: "Mostrado en File info",
    senderLabel: "Etiqueta del remitente",
    saveProfile: "Guardar perfil",
    profileCodesSession: "Los códigos de perfil se guardan solo para esta sesión. Los nombres y etiquetas se guardan.",
    globalCodeSession: "MVP: el código global se guarda solo para esta sesión. El almacenamiento seguro permanente llegará luego con Keychain / Credential Manager.",
    keptOnlySession: "guardado solo para esta sesión",
    optionalGlobalSender: "opcional, usa el remitente global si está vacío",
    howToUseSafeBox: "Cómo usar SafeBox",
    howToSubtitle: "Crear, enviar y abrir archivos cifrados .sbx."
  },

  ar: {
    settings: "الإعدادات",
    help: "مساعدة",
    theme: "المظهر",
    light: "فاتح",
    dark: "داكن",
    create: "إنشاء",
    createSbx: "إنشاء SBX",
    open: "فتح",
    openSbx: "فتح SBX",
    openExistingSbx: "فتح SBX موجود",
    chooseFile: "اختيار ملف",
    selectFile: "تحديد ملف",
    noFileSelected: "لم يتم اختيار ملف",
    code: "الكود",
    enterCode: "أدخل الكود",
    unlock: "فتح",
    fileInfo: "معلومات الملف",
    file: "الملف",
    from: "من",
    access: "الوصول",
    note: "ملاحظة",
    save: "حفظ",
    cancel: "إلغاء",
    close: "إغلاق",
    show: "إظهار",
    hide: "إخفاء",
    delete: "حذف",
    edit: "تعديل",
    setDefault: "تعيين كافتراضي",
    default: "افتراضي",
    general: "عام",
    accessProfiles: "ملفات الوصول",
    security: "الأمان",
    language: "اللغة",
    autoSystem: "تلقائي - لغة النظام",
    senderDefaults: "إعدادات المرسل",
    defaultSbxName: "اسم SBX الافتراضي",
    globalSenderLabel: "تسمية المرسل العامة",
    useGlobalCode: "استخدام الكود العام افتراضياً",
    globalCode: "الكود العام",
    clearGlobalCode: "مسح الكود العام",
    accessProfile: "ملف الوصول",
    noAccessProfilesYet: "لا توجد ملفات وصول بعد.",
    keepSafeBoxSimple: "اجعل SafeBox بسيطاً: أضف ملف وصول فقط عندما تحتاج إلى وصول منفصل.",
    keepSafeBoxSimpleLong: "اجعل SafeBox بسيطاً: أضف ملف وصول فقط عندما تحتاج إلى وصول منفصل للعائلة أو العمل أو العملاء أو الملفات الخاصة.",
    addProfile: "+ إضافة ملف وصول",
    newAccessProfile: "ملف وصول جديد",
    editAccessProfile: "تعديل ملف الوصول",
    nameInSafeBox: "الاسم في SafeBox",
    shownInFileInfo: "يظهر في File info",
    senderLabel: "تسمية المرسل",
    saveProfile: "حفظ الملف",
    profileCodesSession: "أكواد الملفات محفوظة فقط خلال هذه الجلسة. الأسماء والتسميات يتم حفظها.",
    globalCodeSession: "MVP: الكود العام محفوظ فقط خلال هذه الجلسة. التخزين الآمن الدائم سيأتي لاحقاً عبر Keychain / Credential Manager.",
    keptOnlySession: "محفوظ فقط خلال هذه الجلسة",
    optionalGlobalSender: "اختياري، يستخدم المرسل العام إذا كان فارغاً",
    howToUseSafeBox: "طريقة استخدام SafeBox",
    howToSubtitle: "إنشاء وإرسال وفتح ملفات .sbx مشفرة."
  }
};

function sbxFullLocale(): SbxFullLocale {
  const stored = localStorage.getItem("safebox.language.v1") || "auto";
  const raw = stored === "auto" ? navigator.language : stored;
  const lang = raw.toLowerCase();

  if (lang.startsWith("fr")) return "fr";
  if (lang.startsWith("de")) return "de";
  if (lang.startsWith("hr") || lang.startsWith("sr") || lang.startsWith("bs")) return "hr";
  if (lang.startsWith("es")) return "es";
  if (lang.startsWith("ar")) return "ar";

  return "en";
}

function sbxFullDict() {
  return SBX_FULL_I18N[sbxFullLocale()] || SBX_FULL_I18N.en;
}

function sbxFullNorm(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function sbxFullVariantMap() {
  const variants = new Map<string, string>();

  (Object.keys(SBX_FULL_I18N) as SbxFullLocale[]).forEach((locale) => {
    const dict = SBX_FULL_I18N[locale];

    Object.keys(dict).forEach((key) => {
      variants.set(sbxFullNorm(dict[key]).toLowerCase(), key);
    });
  });

  const extra: Record<string, string> = {
    "auto – langue du système": "autoSystem",
    "auto - langue du système": "autoSystem",
    "auto – system language": "autoSystem",
    "auto - system language": "autoSystem",
    "default access profile": "accessProfile",
    "access profile": "accessProfile",
    "access profiles": "accessProfiles",
    "file info": "fileInfo",
    "global sender label": "globalSenderLabel",
    "sender label": "senderLabel",
    "clear global code": "clearGlobalCode",
    "save profile": "saveProfile",
    "create sbx": "createSbx",
    "open sbx": "openSbx"
  };

  Object.keys(extra).forEach((label) => {
    variants.set(sbxFullNorm(label).toLowerCase(), extra[label]);
  });

  return variants;
}

function sbxFullKeyForText(value: string) {
  const normalized = sbxFullNorm(value).toLowerCase();
  if (!normalized) return null;

  return sbxFullVariantMap().get(normalized) || null;
}

function sbxFullSetText(selector: string, key: string) {
  const value = sbxFullDict()[key];
  if (!value) return;

  document.querySelectorAll<HTMLElement>(selector).forEach((element) => {
    element.textContent = value;
  });
}

function sbxFullTranslateTextNodes(root: ParentNode) {
  const dict = sbxFullDict();

  const walker = document.createTreeWalker(
    root,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        const parent = node.parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;

        const tag = parent.tagName.toLowerCase();

        if (
          tag === "script" ||
          tag === "style" ||
          tag === "code" ||
          tag === "textarea" ||
          tag === "input" ||
          parent.closest("code") ||
          parent.closest(".result-grid") ||
          parent.closest("#hardReceiverFile") ||
          parent.closest("#hardInfoName") ||
          parent.closest("#hardInfoSender") ||
          parent.closest("#hardInfoAccess") ||
          parent.closest("#hardInfoNote")
        ) {
          return NodeFilter.FILTER_REJECT;
        }

        return sbxFullKeyForText(node.nodeValue || "") ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      }
    }
  );

  const nodes: Text[] = [];

  while (walker.nextNode()) {
    nodes.push(walker.currentNode as Text);
  }

  nodes.forEach((node) => {
    const raw = node.nodeValue || "";
    const key = sbxFullKeyForText(raw);
    if (!key || !dict[key]) return;

    const prefix = raw.match(/^\s*/)?.[0] || "";
    const suffix = raw.match(/\s*$/)?.[0] || "";
    node.nodeValue = `${prefix}${dict[key]}${suffix}`;
  });
}

function sbxFullTranslateAttributes() {
  const dict = sbxFullDict();

  document.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>("input[placeholder], textarea[placeholder]").forEach((element) => {
    const key = sbxFullKeyForText(element.placeholder);
    if (key && dict[key]) element.placeholder = dict[key];
  });

  document.querySelectorAll<HTMLElement>("[title]").forEach((element) => {
    const title = element.getAttribute("title") || "";
    const key = sbxFullKeyForText(title);
    if (key && dict[key]) element.setAttribute("title", dict[key]);
  });

  document.querySelectorAll<HTMLElement>("[aria-label]").forEach((element) => {
    const label = element.getAttribute("aria-label") || "";
    const key = sbxFullKeyForText(label);
    if (key && dict[key]) element.setAttribute("aria-label", dict[key]);
  });
}

function sbxFullTranslateKnownUi() {
  const dict = sbxFullDict();

  sbxFullSetText("#settingsBtn", "settings");
  sbxFullSetText("#helpBtn", "help");
  sbxFullSetText("#howToUseBtn", "help");

  document.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
    if (button.dataset.tab === "general") button.textContent = dict.general;
    if (button.dataset.tab === "profiles") button.textContent = dict.accessProfiles;
    if (button.dataset.tab === "security") button.textContent = dict.security;
  });

  const langTitle = document.querySelector<HTMLElement>("#settingsLanguageField .settings-language-title");
  if (langTitle) langTitle.textContent = dict.language;

  const languageSelect = document.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (languageSelect) {
    Array.from(languageSelect.options).forEach((option) => {
      if (option.value === "auto") option.textContent = dict.autoSystem;
      if (option.value === "en") option.textContent = "English";
      if (option.value === "fr") option.textContent = "Français";
      if (option.value === "de") option.textContent = "Deutsch";
      if (option.value === "hr") option.textContent = "Hrvatski / BCS";
      if (option.value === "ar") option.textContent = "العربية";
      if (option.value === "es") option.textContent = "Español";
    });
  }

  sbxFullSetText("#addProfileBtn", "addProfile");
  sbxFullSetText("#saveProfileEditorBtn", "saveProfile");
  sbxFullSetText("#cancelProfileEditorBtn", "cancel");
  sbxFullSetText("#closeHowToUseFooterBtn", "close");

  const title = document.querySelector<HTMLElement>("#profileEditorTitle");
  if (title) {
    const current = sbxFullNorm(title.textContent || "").toLowerCase();
    const editWords = ["edit", "modifier", "bearbeiten", "uredi", "editar", "تعديل"];
    title.textContent = editWords.some((word) => current.includes(word)) ? dict.editAccessProfile : dict.newAccessProfile;
  }

  document.documentElement.lang = sbxFullLocale() === "hr" ? "hr" : sbxFullLocale();
  document.documentElement.dir = sbxFullLocale() === "ar" ? "rtl" : "ltr";
}

function sbxFullApplyAppLanguage() {
  try {
    sbxFullTranslateKnownUi();
    sbxFullTranslateTextNodes(document.body);
    sbxFullTranslateAttributes();
  } catch (error) {
    console.warn("SafeBox full app i18n failed", error);
  }
}

(window as any).sbxApplyI18n = sbxFullApplyAppLanguage;

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;

  if (target?.id === "settingsLanguageSelect") {
    setTimeout(sbxFullApplyAppLanguage, 20);
    setTimeout(sbxFullApplyAppLanguage, 120);
    setTimeout(sbxFullApplyAppLanguage, 350);
  }
});

document.addEventListener(
  "click",
  () => {
    setTimeout(sbxFullApplyAppLanguage, 80);
    setTimeout(sbxFullApplyAppLanguage, 260);
  },
  true
);

setTimeout(sbxFullApplyAppLanguage, 100);
setTimeout(sbxFullApplyAppLanguage, 500);
setTimeout(sbxFullApplyAppLanguage, 1200);
setInterval(sbxFullApplyAppLanguage, 1200);

console.debug("sprint9c-full-app-i18n-v1");
'''

p.write_text(text)
print("OK: Sprint 9C full app i18n appended")
PY

cat >> src/style.css <<'CSS'

/* SafeBox Sprint 9C — Full App i18n */
:root {
  --sprint9c-full-app-i18n-v1: 1;
}

html[dir="rtl"] body {
  direction: rtl !important;
}

html[dir="rtl"] input,
html[dir="rtl"] textarea,
html[dir="rtl"] select,
html[dir="rtl"] code {
  direction: ltr !important;
  text-align: left !important;
}

html[dir="rtl"] .modal-head,
html[dir="rtl"] .topbar,
html[dir="rtl"] .profile-card-top,
html[dir="rtl"] .profiles-header,
html[dir="rtl"] .compact-profile-row {
  direction: rtl !important;
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 9C marker"
grep -R -- "sprint9c-full-app-i18n-v1" dist || echo "ERROR: Sprint 9C marker absent from dist"

echo ""
echo "Sprint 9C Full App i18n applied."
echo "Run:"
echo "  npm run tauri dev"
