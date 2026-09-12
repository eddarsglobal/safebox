#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-4 — i18n Cleanup
#
# Goal:
# - one final language controller
# - language applies globally, not only Help
# - Settings titles/notes/buttons stay translated after rebuilds
# - no translation of file names, paths, codes, user metadata
# - no visual double translation
#
# Does NOT touch encryption / SBX format / receiver unlock logic / macOS icon.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint10a4-i18n-cleanup.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a4-i18n-cleanup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a4-i18n-cleanup-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-4 — final i18n cleanup controller
// Marker: sprint10a4-i18n-cleanup-v1
type SbxI18nLocale10A4 = "en" | "fr" | "de" | "hr" | "es" | "ar";

const SBX_I18N_10A4: Record<SbxI18nLocale10A4, Record<string, string>> = {
  en: {
    settings: "Settings",
    help: "Help",
    theme: "Theme",
    create: "Create",
    createSbx: "Create SBX",
    open: "Open",
    openSbx: "Open SBX",
    openExistingSbx: "Open existing SBX",
    chooseFile: "Choose file",
    chooseAFile: "Choose a file",
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
    clear: "Clear",
    delete: "Delete",
    edit: "Edit",
    setDefault: "Set default",
    default: "Default",
    general: "General",
    generalSubtitle: "Language and sender defaults.",
    accessProfiles: "Access Profiles",
    accessProfilesSubtitle: "Keep SafeBox simple: add a profile only when you need separate access.",
    security: "Security",
    securitySubtitle: "Session codes and security notes.",
    language: "Language",
    autoSystem: "Auto - System language",
    defaultSbxName: "Default SBX name",
    globalSenderLabel: "Global sender label",
    useGlobalCode: "Use global code by default",
    globalCode: "Global code",
    clearGlobalCode: "Clear global code",
    noAccessProfilesYet: "No access profiles yet.",
    addProfile: "+ Add profile",
    newAccessProfile: "New Access Profile",
    editAccessProfile: "Edit Access Profile",
    accessProfile: "Access profile",
    nameInSafeBox: "Name in SafeBox",
    shownInFileInfo: "Shown in File info",
    senderLabel: "Sender label",
    saveProfile: "Save profile",
    keptOnlySession: "kept only for this app session",
    optionalGlobalSender: "optional, uses global sender if empty",
    profileCodesSession: "Profile codes are kept only for this app session. Profile names and labels are saved.",
    globalCodeSession: "MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.",
    howToUseSafeBox: "How to Use SafeBox",
    howToSubtitle: "Create, send and unlock encrypted .sbx files safely."
  },
  fr: {
    settings: "Paramètres",
    help: "Aide",
    theme: "Thème",
    create: "Créer",
    createSbx: "Créer SBX",
    open: "Ouvrir",
    openSbx: "Ouvrir SBX",
    openExistingSbx: "Ouvrir un SBX existant",
    chooseFile: "Choisir un fichier",
    chooseAFile: "Choisir un fichier",
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
    clear: "Effacer",
    delete: "Supprimer",
    edit: "Modifier",
    setDefault: "Définir par défaut",
    default: "Par défaut",
    general: "Général",
    generalSubtitle: "Langue et valeurs expéditeur.",
    accessProfiles: "Profils d’accès",
    accessProfilesSubtitle: "Gardez SafeBox simple : ajoutez un profil seulement si vous avez besoin d’un accès séparé.",
    security: "Sécurité",
    securitySubtitle: "Codes de session et notes de sécurité.",
    language: "Langue",
    autoSystem: "Auto - langue du système",
    defaultSbxName: "Nom SBX par défaut",
    globalSenderLabel: "Label expéditeur global",
    useGlobalCode: "Utiliser le code global par défaut",
    globalCode: "Code global",
    clearGlobalCode: "Effacer le code global",
    noAccessProfilesYet: "Aucun profil d’accès pour le moment.",
    addProfile: "+ Ajouter un profil",
    newAccessProfile: "Nouveau profil d’accès",
    editAccessProfile: "Modifier le profil d’accès",
    accessProfile: "Profil d’accès",
    nameInSafeBox: "Nom dans SafeBox",
    shownInFileInfo: "Affiché dans File info",
    senderLabel: "Label expéditeur",
    saveProfile: "Enregistrer le profil",
    keptOnlySession: "gardé seulement pour cette session",
    optionalGlobalSender: "optionnel, utilise l’expéditeur global si vide",
    profileCodesSession: "Les codes de profils sont gardés seulement pour cette session. Les noms et labels sont enregistrés.",
    globalCodeSession: "MVP : le code global est gardé seulement pour cette session. Le stockage sécurisé permanent viendra plus tard avec Keychain / Credential Manager.",
    howToUseSafeBox: "Comment utiliser SafeBox",
    howToSubtitle: "Créer, envoyer et ouvrir des fichiers chiffrés .sbx."
  },
  de: {
    settings: "Einstellungen",
    help: "Hilfe",
    theme: "Design",
    create: "Erstellen",
    createSbx: "SBX erstellen",
    open: "Öffnen",
    openSbx: "SBX öffnen",
    openExistingSbx: "Bestehende SBX öffnen",
    chooseFile: "Datei wählen",
    chooseAFile: "Datei wählen",
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
    clear: "Löschen",
    delete: "Löschen",
    edit: "Bearbeiten",
    setDefault: "Als Standard setzen",
    default: "Standard",
    general: "Allgemein",
    generalSubtitle: "Sprache und Absender-Standardwerte.",
    accessProfiles: "Zugriffsprofile",
    accessProfilesSubtitle: "Halte SafeBox einfach: Füge ein Profil nur hinzu, wenn du getrennten Zugriff brauchst.",
    security: "Sicherheit",
    securitySubtitle: "Sitzungscodes und Sicherheitshinweise.",
    language: "Sprache",
    autoSystem: "Auto - Systemsprache",
    defaultSbxName: "Standard-SBX-Name",
    globalSenderLabel: "Globales Absenderlabel",
    useGlobalCode: "Globalen Code standardmässig verwenden",
    globalCode: "Globaler Code",
    clearGlobalCode: "Globalen Code löschen",
    noAccessProfilesYet: "Noch keine Zugriffsprofile.",
    addProfile: "+ Profil hinzufügen",
    newAccessProfile: "Neues Zugriffsprofil",
    editAccessProfile: "Zugriffsprofil bearbeiten",
    accessProfile: "Zugriffsprofil",
    nameInSafeBox: "Name in SafeBox",
    shownInFileInfo: "In File info angezeigt",
    senderLabel: "Absenderlabel",
    saveProfile: "Profil speichern",
    keptOnlySession: "nur für diese App-Sitzung gespeichert",
    optionalGlobalSender: "optional, nutzt globalen Absender wenn leer",
    profileCodesSession: "Profilcodes werden nur für diese App-Sitzung gespeichert. Profilnamen und Labels werden gespeichert.",
    globalCodeSession: "MVP: Der globale Code wird nur für diese App-Sitzung gespeichert. Permanenter sicherer Speicher kommt später mit Keychain / Credential Manager.",
    howToUseSafeBox: "SafeBox verwenden",
    howToSubtitle: "Verschlüsselte .sbx-Dateien erstellen, senden und öffnen."
  },
  hr: {
    settings: "Postavke",
    help: "Pomoć",
    theme: "Tema",
    create: "Kreiraj",
    createSbx: "Kreiraj SBX",
    open: "Otvori",
    openSbx: "Otvori SBX",
    openExistingSbx: "Otvori postojeći SBX",
    chooseFile: "Odaberi datoteku",
    chooseAFile: "Odaberi datoteku",
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
    clear: "Obriši",
    delete: "Obriši",
    edit: "Uredi",
    setDefault: "Postavi kao zadano",
    default: "Zadano",
    general: "Općenito",
    generalSubtitle: "Jezik i zadane vrijednosti pošiljatelja.",
    accessProfiles: "Profili pristupa",
    accessProfilesSubtitle: "Neka SafeBox ostane jednostavan: dodaj profil samo kad trebaš odvojeni pristup.",
    security: "Sigurnost",
    securitySubtitle: "Kodovi sesije i sigurnosne napomene.",
    language: "Jezik",
    autoSystem: "Auto - jezik sustava",
    defaultSbxName: "Zadani SBX naziv",
    globalSenderLabel: "Globalni label pošiljatelja",
    useGlobalCode: "Koristi globalni kod kao zadani",
    globalCode: "Globalni kod",
    clearGlobalCode: "Obriši globalni kod",
    noAccessProfilesYet: "Još nema profila pristupa.",
    addProfile: "+ Dodaj profil",
    newAccessProfile: "Novi profil pristupa",
    editAccessProfile: "Uredi profil pristupa",
    accessProfile: "Profil pristupa",
    nameInSafeBox: "Naziv u SafeBoxu",
    shownInFileInfo: "Prikazano u File info",
    senderLabel: "Label pošiljatelja",
    saveProfile: "Spremi profil",
    keptOnlySession: "čuva se samo za ovu sesiju",
    optionalGlobalSender: "opcionalno, koristi globalnog pošiljatelja ako je prazno",
    profileCodesSession: "Kodovi profila čuvaju se samo za ovu sesiju. Nazivi i labeli profila se spremaju.",
    globalCodeSession: "MVP: globalni kod čuva se samo za ovu sesiju. Trajna sigurna pohrana dolazi kasnije kroz Keychain / Credential Manager.",
    howToUseSafeBox: "Kako koristiti SafeBox",
    howToSubtitle: "Kreiranje, slanje i otvaranje šifriranih .sbx datoteka."
  },
  es: {
    settings: "Ajustes",
    help: "Ayuda",
    theme: "Tema",
    create: "Crear",
    createSbx: "Crear SBX",
    open: "Abrir",
    openSbx: "Abrir SBX",
    openExistingSbx: "Abrir SBX existente",
    chooseFile: "Elegir archivo",
    chooseAFile: "Elegir archivo",
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
    clear: "Borrar",
    delete: "Eliminar",
    edit: "Editar",
    setDefault: "Definir por defecto",
    default: "Por defecto",
    general: "General",
    generalSubtitle: "Idioma y valores del remitente.",
    accessProfiles: "Perfiles de acceso",
    accessProfilesSubtitle: "Mantén SafeBox simple: añade un perfil solo cuando necesites acceso separado.",
    security: "Seguridad",
    securitySubtitle: "Códigos de sesión y notas de seguridad.",
    language: "Idioma",
    autoSystem: "Auto - idioma del sistema",
    defaultSbxName: "Nombre SBX por defecto",
    globalSenderLabel: "Etiqueta global del remitente",
    useGlobalCode: "Usar código global por defecto",
    globalCode: "Código global",
    clearGlobalCode: "Borrar código global",
    noAccessProfilesYet: "Aún no hay perfiles de acceso.",
    addProfile: "+ Añadir perfil",
    newAccessProfile: "Nuevo perfil de acceso",
    editAccessProfile: "Editar perfil de acceso",
    accessProfile: "Perfil de acceso",
    nameInSafeBox: "Nombre en SafeBox",
    shownInFileInfo: "Mostrado en File info",
    senderLabel: "Etiqueta del remitente",
    saveProfile: "Guardar perfil",
    keptOnlySession: "guardado solo para esta sesión",
    optionalGlobalSender: "opcional, usa el remitente global si está vacío",
    profileCodesSession: "Los códigos de perfil se guardan solo para esta sesión. Los nombres y etiquetas se guardan.",
    globalCodeSession: "MVP: el código global se guarda solo para esta sesión. El almacenamiento seguro permanente llegará luego con Keychain / Credential Manager.",
    howToUseSafeBox: "Cómo usar SafeBox",
    howToSubtitle: "Crear, enviar y abrir archivos cifrados .sbx."
  },
  ar: {
    settings: "الإعدادات",
    help: "مساعدة",
    theme: "المظهر",
    create: "إنشاء",
    createSbx: "إنشاء SBX",
    open: "فتح",
    openSbx: "فتح SBX",
    openExistingSbx: "فتح SBX موجود",
    chooseFile: "اختيار ملف",
    chooseAFile: "اختيار ملف",
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
    clear: "مسح",
    delete: "حذف",
    edit: "تعديل",
    setDefault: "تعيين كافتراضي",
    default: "افتراضي",
    general: "عام",
    generalSubtitle: "اللغة وإعدادات المرسل.",
    accessProfiles: "ملفات الوصول",
    accessProfilesSubtitle: "اجعل SafeBox بسيطاً: أضف ملف وصول فقط عندما تحتاج إلى وصول منفصل.",
    security: "الأمان",
    securitySubtitle: "أكواد الجلسة وملاحظات الأمان.",
    language: "اللغة",
    autoSystem: "تلقائي - لغة النظام",
    defaultSbxName: "اسم SBX الافتراضي",
    globalSenderLabel: "تسمية المرسل العامة",
    useGlobalCode: "استخدام الكود العام افتراضياً",
    globalCode: "الكود العام",
    clearGlobalCode: "مسح الكود العام",
    noAccessProfilesYet: "لا توجد ملفات وصول بعد.",
    addProfile: "+ إضافة ملف وصول",
    newAccessProfile: "ملف وصول جديد",
    editAccessProfile: "تعديل ملف الوصول",
    accessProfile: "ملف الوصول",
    nameInSafeBox: "الاسم في SafeBox",
    shownInFileInfo: "يظهر في File info",
    senderLabel: "تسمية المرسل",
    saveProfile: "حفظ الملف",
    keptOnlySession: "محفوظ فقط خلال هذه الجلسة",
    optionalGlobalSender: "اختياري، يستخدم المرسل العام إذا كان فارغاً",
    profileCodesSession: "أكواد الملفات محفوظة فقط خلال هذه الجلسة. الأسماء والتسميات يتم حفظها.",
    globalCodeSession: "MVP: الكود العام محفوظ فقط خلال هذه الجلسة. التخزين الآمن الدائم سيأتي لاحقاً عبر Keychain / Credential Manager.",
    howToUseSafeBox: "طريقة استخدام SafeBox",
    howToSubtitle: "إنشاء وإرسال وفتح ملفات .sbx مشفرة."
  }
};

function sbxI18nLocale10A4(): SbxI18nLocale10A4 {
  let stored = "auto";

  try {
    stored = localStorage.getItem("safebox.language.v1") || "auto";
  } catch {}

  const raw = stored === "auto" ? navigator.language : stored;
  const lang = raw.toLowerCase();

  if (lang.startsWith("fr")) return "fr";
  if (lang.startsWith("de")) return "de";
  if (lang.startsWith("hr") || lang.startsWith("sr") || lang.startsWith("bs")) return "hr";
  if (lang.startsWith("es")) return "es";
  if (lang.startsWith("ar")) return "ar";

  return "en";
}

function sbxI18nT10A4(key: string) {
  const locale = sbxI18nLocale10A4();
  return SBX_I18N_10A4[locale]?.[key] || SBX_I18N_10A4.en[key] || key;
}

function sbxI18nNormalize10A4(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function sbxI18nBuildReverseMap10A4() {
  const map = new Map<string, string>();

  (Object.keys(SBX_I18N_10A4) as SbxI18nLocale10A4[]).forEach((locale) => {
    const dict = SBX_I18N_10A4[locale];

    Object.keys(dict).forEach((key) => {
      map.set(sbxI18nNormalize10A4(dict[key]).toLowerCase(), key);
    });
  });

  const extra: Record<string, string> = {
    "auto – langue du système": "autoSystem",
    "auto - langue du système": "autoSystem",
    "auto – system language": "autoSystem",
    "auto - system language": "autoSystem",
    "settings": "settings",
    "paramètres": "settings",
    "aide": "help",
    "help": "help",
    "default access profile": "accessProfile",
    "access profile": "accessProfile",
    "access profiles": "accessProfiles",
    "file info": "fileInfo",
    "global sender label": "globalSenderLabel",
    "sender label": "senderLabel",
    "global code": "globalCode",
    "clear global code": "clearGlobalCode",
    "save profile": "saveProfile",
    "create sbx": "createSbx",
    "open sbx": "openSbx"
  };

  Object.keys(extra).forEach((label) => {
    map.set(sbxI18nNormalize10A4(label).toLowerCase(), extra[label]);
  });

  return map;
}

function sbxI18nKeyForText10A4(value: string) {
  const normalized = sbxI18nNormalize10A4(value).toLowerCase();
  if (!normalized) return null;

  return sbxI18nBuildReverseMap10A4().get(normalized) || null;
}

function sbxI18nSetText10A4(selector: string, key: string) {
  const value = sbxI18nT10A4(key);

  document.querySelectorAll<HTMLElement>(selector).forEach((node) => {
    node.textContent = value;
  });
}

function sbxI18nShouldSkipNode10A4(parent: HTMLElement) {
  const tag = parent.tagName.toLowerCase();

  if (["script", "style", "code", "textarea", "input"].includes(tag)) return true;

  return !!(
    parent.closest("code") ||
    parent.closest(".result-grid") ||
    parent.closest(".receiver-file-name") ||
    parent.closest("#hardReceiverFile") ||
    parent.closest("#hardInfoName") ||
    parent.closest("#hardInfoSender") ||
    parent.closest("#hardInfoAccess") ||
    parent.closest("#hardInfoNote") ||
    parent.closest("#hardReceiverIdentity") ||
    parent.closest("#hardReceiverNote") ||
    parent.closest("[data-sbx-user-content='1']") ||
    parent.closest(".compact-profile-main") ||
    parent.closest(".profile-card-top")
  );
}

function sbxI18nTranslateTextNodes10A4(root: ParentNode) {
  const walker = document.createTreeWalker(
    root,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        const parent = node.parentElement;

        if (!parent || sbxI18nShouldSkipNode10A4(parent)) {
          return NodeFilter.FILTER_REJECT;
        }

        return sbxI18nKeyForText10A4(node.nodeValue || "")
          ? NodeFilter.FILTER_ACCEPT
          : NodeFilter.FILTER_REJECT;
      }
    }
  );

  const nodes: Text[] = [];

  while (walker.nextNode()) {
    nodes.push(walker.currentNode as Text);
  }

  nodes.forEach((node) => {
    const raw = node.nodeValue || "";
    const key = sbxI18nKeyForText10A4(raw);

    if (!key) return;

    const prefix = raw.match(/^\s*/)?.[0] || "";
    const suffix = raw.match(/\s*$/)?.[0] || "";

    node.nodeValue = `${prefix}${sbxI18nT10A4(key)}${suffix}`;
  });
}

function sbxI18nTranslatePlaceholders10A4() {
  document.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>("input[placeholder], textarea[placeholder]").forEach((input) => {
    if (
      input.closest("#hardReceiverOverlay") ||
      input.id.toLowerCase().includes("code") ||
      input.type === "password"
    ) {
      return;
    }

    const key = sbxI18nKeyForText10A4(input.placeholder);
    if (key) input.placeholder = sbxI18nT10A4(key);
  });
}

function sbxI18nApplySettings10A4() {
  const locale = sbxI18nLocale10A4();

  document.documentElement.lang = locale === "hr" ? "hr" : locale;
  document.documentElement.dir = locale === "ar" ? "rtl" : "ltr";

  sbxI18nSetText10A4("#settingsBtn", "settings");
  sbxI18nSetText10A4("#howToUseBtn", "help");
  sbxI18nSetText10A4("#helpBtn", "help");

  document.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
    if (button.dataset.tab === "general") button.textContent = sbxI18nT10A4("general");
    if (button.dataset.tab === "profiles") button.textContent = sbxI18nT10A4("accessProfiles");
    if (button.dataset.tab === "security") button.textContent = sbxI18nT10A4("security");
  });

  const generalTitle = document.querySelector<HTMLElement>("#settingsPanelGeneral .sbx-settings-panel-title-10a3c");
  if (generalTitle) {
    generalTitle.querySelector("h3")!.textContent = sbxI18nT10A4("general");
    generalTitle.querySelector("p")!.textContent = sbxI18nT10A4("generalSubtitle");
  }

  const securityTitle = document.querySelector<HTMLElement>("#settingsPanelSecurity .sbx-settings-panel-title-10a3c");
  if (securityTitle) {
    securityTitle.querySelector("h3")!.textContent = sbxI18nT10A4("security");
    securityTitle.querySelector("p")!.textContent = sbxI18nT10A4("securitySubtitle");
  }

  document.querySelectorAll<HTMLElement>(".profiles-header h3").forEach((node) => {
    node.textContent = sbxI18nT10A4("accessProfiles");
  });

  document.querySelectorAll<HTMLElement>(".profiles-header p").forEach((node) => {
    node.textContent = sbxI18nT10A4("accessProfilesSubtitle");
  });

  document.querySelectorAll<HTMLElement>(".profiles-empty-state strong, .compact-profiles-empty strong").forEach((node) => {
    node.textContent = sbxI18nT10A4("noAccessProfilesYet");
  });

  document.querySelectorAll<HTMLElement>(".profiles-empty-state p, .compact-profiles-empty p").forEach((node) => {
    node.textContent = sbxI18nT10A4("accessProfilesSubtitle");
  });

  sbxI18nSetText10A4("#addProfileBtn", "addProfile");

  document.querySelectorAll<HTMLElement>("#settingsLanguageField .settings-language-title, .settings-language-title").forEach((node) => {
    node.textContent = sbxI18nT10A4("language");
  });

  const languageSelect = document.querySelector<HTMLSelectElement>("#settingsLanguageSelect");

  if (languageSelect) {
    Array.from(languageSelect.options).forEach((option) => {
      if (option.value === "auto") option.textContent = sbxI18nT10A4("autoSystem");
      if (option.value === "en") option.textContent = "English";
      if (option.value === "fr") option.textContent = "Français";
      if (option.value === "de") option.textContent = "Deutsch";
      if (option.value === "hr") option.textContent = "Hrvatski / BCS";
      if (option.value === "ar") option.textContent = "العربية";
      if (option.value === "es") option.textContent = "Español";
    });
  }

  document.querySelectorAll<HTMLElement>("#settingsPanelSecurity .settings-note, #settingsPanelSecurity p").forEach((node) => {
    const text = (node.textContent || "").toLowerCase();

    if (
      text.includes("mvp") ||
      text.includes("global code") ||
      text.includes("code global") ||
      text.includes("keychain") ||
      text.includes("credential manager")
    ) {
      node.textContent = sbxI18nT10A4("globalCodeSession");
    }
  });

  const profileTitle = document.querySelector<HTMLElement>("#profileEditorTitle");
  if (profileTitle) {
    const raw = (profileTitle.textContent || "").toLowerCase();
    const editWords = ["edit", "modifier", "bearbeiten", "uredi", "editar", "تعديل"];
    profileTitle.textContent = editWords.some((word) => raw.includes(word))
      ? sbxI18nT10A4("editAccessProfile")
      : sbxI18nT10A4("newAccessProfile");
  }

  sbxI18nSetText10A4("#saveProfileEditorBtn", "saveProfile");
  sbxI18nSetText10A4("#cancelProfileEditorBtn", "cancel");
  sbxI18nSetText10A4("#closeHowToUseFooterBtn", "close");
  sbxI18nSetText10A4("#hardReceiverUnlock", "unlock");
  sbxI18nSetText10A4("#hardReceiverInfoBtn", "fileInfo");
}

function sbxI18nApply10A4() {
  try {
    sbxI18nApplySettings10A4();
    sbxI18nTranslateTextNodes10A4(document.body);
    sbxI18nTranslatePlaceholders10A4();

    const maybeHowTo = (window as any).initHowToUseSafeBox;
    if (typeof maybeHowTo === "function") {
      maybeHowTo();
    }
  } catch (error) {
    console.warn("SafeBox Sprint 10A-4 i18n cleanup failed", error);
  }
}

(window as any).sbxApplyI18n = sbxI18nApply10A4;

let sbxI18nRaf10A4: number | null = null;

function sbxI18nSchedule10A4() {
  if (sbxI18nRaf10A4 !== null) return;

  sbxI18nRaf10A4 = window.requestAnimationFrame(() => {
    sbxI18nRaf10A4 = null;
    sbxI18nApply10A4();
  });
}

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;

  if (target?.id === "settingsLanguageSelect") {
    const select = target as HTMLSelectElement;

    try {
      localStorage.setItem("safebox.language.v1", select.value);
    } catch {}

    setTimeout(sbxI18nApply10A4, 20);
    setTimeout(sbxI18nApply10A4, 120);
    setTimeout(sbxI18nApply10A4, 300);
  }
});

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;

    if (
      target?.closest("#settingsBtn") ||
      target?.closest("#howToUseBtn") ||
      target?.closest("#addProfileBtn") ||
      target?.closest(".settings-tab-button") ||
      target?.closest(".compact-profile-edit")
    ) {
      setTimeout(sbxI18nApply10A4, 50);
      setTimeout(sbxI18nApply10A4, 180);
      setTimeout(sbxI18nApply10A4, 420);
    }
  },
  true
);

if (!(window as any).__safeboxI18nObserver10A4) {
  const observer = new MutationObserver((mutations) => {
    const relevant = mutations.some((mutation) => {
      const target = mutation.target as HTMLElement | null;

      return !!(
        target?.closest?.("#settingsModal") ||
        target?.closest?.("#howToUseModal") ||
        target?.closest?.("#accessProfileEditorModal") ||
        target?.closest?.("#hardReceiverOverlay")
      );
    });

    if (relevant) {
      sbxI18nSchedule10A4();
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true
  });

  (window as any).__safeboxI18nObserver10A4 = observer;
}

setTimeout(sbxI18nApply10A4, 100);
setTimeout(sbxI18nApply10A4, 500);
setTimeout(sbxI18nApply10A4, 1200);

console.debug("sprint10a4-i18n-cleanup-v1");
TS
fi

if ! grep -q "sprint10a4-i18n-cleanup-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-4 — i18n Cleanup */
:root {
  --sprint10a4-i18n-cleanup-v1: 1;
}

html[dir="rtl"] body {
  direction: rtl !important;
}

html[dir="rtl"] input,
html[dir="rtl"] textarea,
html[dir="rtl"] select,
html[dir="rtl"] code,
html[dir="rtl"] .receiver-file-name,
html[dir="rtl"] #hardReceiverFile,
html[dir="rtl"] #hardInfoName,
html[dir="rtl"] #hardInfoSender,
html[dir="rtl"] #hardInfoAccess,
html[dir="rtl"] #hardInfoNote {
  direction: ltr !important;
  text-align: left !important;
}

html[dir="rtl"] .modal-head,
html[dir="rtl"] .topbar,
html[dir="rtl"] .profiles-header,
html[dir="rtl"] .compact-profile-row {
  direction: rtl !important;
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-4 marker"
grep -R -- "sprint10a4-i18n-cleanup-v1" dist || echo "ERROR: Sprint 10A-4 marker absent from dist"

echo ""
echo "Sprint 10A-4 i18n Cleanup applied."
echo "Run:"
echo "  npm run tauri dev"
