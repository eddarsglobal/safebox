import "./landing.css";

type Lang = "en"|"fr"|"it"|"pt"|"ar"|"de"|"es"|"hr";
type LangChoice = "auto" | Lang;
type Copy = { tagline:string; sub:string; create:string; open:string; story:string; scope:string; local:string; localText:string; everywhere:string; android:string; ios:string; iosHint:string; ad:string; legal:string; privacy:string; terms:string; cookies:string; licenses:string; install:string; github:string; theme:string; language:string; creator:string; heroEyebrow:string; heroLocal:string; heroContainer:string; stageAny:string; stageCrypto:string; stageSbx:string; resultLocal:string; resultEncrypted:string; resultPortable:string; outcomeAny:string; outcomeOne:string; outcomeNote:string; promiseEyebrow:string; pulseLocal:string; pulseNoCloud:string; pulsePrivate:string; deviceLabel:string; localBoundary:string; cloudLabel:string; downloadsEyebrow:string; webOpen:string; adReady:string; system:string; light:string; dark:string; auto:string };

const copies: Record<Lang, Copy> = {
  en:{tagline:"Any file. One secure SBX.",sub:"SafeBox encrypts any file locally — documents, media, apps, archives, code, data and more — and produces one portable .sbx file.",create:"Create a SafeBox",open:"Open a SafeBox",story:"Watch any file become SBX",scope:"ANY EXTENSION · ANY SIZE",local:"Local by design",localText:"Your file, password and plaintext stay inside the SafeBox crypto app. No cloud upload is required.",everywhere:"SafeBox everywhere",android:"Download Android APK",ios:"Install on iPhone / iPad",iosHint:"Use the Web App and Add to Home Screen — no App Store required.",ad:"Advertisement",legal:"Legal notice",privacy:"Privacy",terms:"Terms",cookies:"Cookies & Ads",licenses:"Licences",install:"Install SafeBox",github:"GitHub releases",theme:"Appearance",language:"Language",creator:"Free to use · Created by Mr Eddars Noureddine · Zurich, Switzerland",heroEyebrow:"SAFEBOX · LOCAL FILE ENCRYPTION",heroLocal:"LOCAL",heroContainer:"ONE SECURE CONTAINER",stageAny:"ANY FILE",stageCrypto:"LOCAL CRYPTO",stageSbx:".SBX",resultLocal:"LOCAL",resultEncrypted:"ENCRYPTED",resultPortable:"PORTABLE",outcomeAny:"ANY FILE",outcomeOne:"ONE .SBX",outcomeNote:"File contents never need to leave the device.",promiseEyebrow:"ZERO-UPLOAD CRYPTO FLOW",pulseLocal:"LOCAL",pulseNoCloud:"NO CLOUD",pulsePrivate:"PRIVATE",deviceLabel:"YOUR DEVICE",localBoundary:"LOCAL BOUNDARY",cloudLabel:"CLOUD",downloadsEyebrow:"WEB · ANDROID · iPHONE/iPAD",webOpen:"Open instantly",adReady:"AdSense ready · disabled by default",system:"System",light:"Light",dark:"Dark",auto:"Auto"},
  fr:{tagline:"N’importe quel fichier. Un SBX sécurisé.",sub:"SafeBox chiffre localement n’importe quel fichier — documents, médias, applications, archives, code, données et plus — puis produit un fichier portable .sbx.",create:"Créer un SafeBox",open:"Ouvrir un SafeBox",story:"Regardez n’importe quel fichier devenir SBX",scope:"TOUTE EXTENSION · TOUTE TAILLE",local:"Local par conception",localText:"Votre fichier, mot de passe et contenu en clair restent dans l’application crypto SafeBox. Aucun cloud n’est requis.",everywhere:"SafeBox partout",android:"Télécharger l’APK Android",ios:"Installer sur iPhone / iPad",iosHint:"Utilisez l’app Web puis Ajouter à l’écran d’accueil — sans App Store.",ad:"Publicité",legal:"Mentions légales",privacy:"Confidentialité",terms:"Conditions",cookies:"Cookies & Publicité",licenses:"Licences",install:"Installer SafeBox",github:"Versions GitHub",theme:"Apparence",language:"Langue",creator:"Libre d’utilisation · Créé par Mr Eddars Noureddine · Zurich, Switzerland",heroEyebrow:"SAFEBOX · CHIFFREMENT LOCAL DES FICHIERS",heroLocal:"LOCAL",heroContainer:"UN CONTENEUR SÉCURISÉ",stageAny:"TOUT FICHIER",stageCrypto:"CRYPTO LOCALE",stageSbx:".SBX",resultLocal:"LOCAL",resultEncrypted:"CHIFFRÉ",resultPortable:"PORTABLE",outcomeAny:"TOUT FICHIER",outcomeOne:"UN .SBX",outcomeNote:"Le contenu du fichier n’a jamais besoin de quitter l’appareil.",promiseEyebrow:"FLUX CRYPTO SANS ENVOI CLOUD",pulseLocal:"LOCAL",pulseNoCloud:"SANS CLOUD",pulsePrivate:"PRIVÉ",deviceLabel:"VOTRE APPAREIL",localBoundary:"PÉRIMÈTRE LOCAL",cloudLabel:"CLOUD",downloadsEyebrow:"WEB · ANDROID · iPHONE/iPAD",webOpen:"Ouvrir immédiatement",adReady:"AdSense prêt · désactivé par défaut",system:"Système",light:"Clair",dark:"Sombre",auto:"Auto"},
  it:{tagline:"Qualsiasi file. Un SBX sicuro.",sub:"SafeBox cifra localmente qualsiasi file — documenti, media, app, archivi, codice, dati e altro — e crea un file portatile .sbx.",create:"Crea SafeBox",open:"Apri SafeBox",story:"Guarda qualsiasi file diventare SBX",scope:"OGNI ESTENSIONE · OGNI DIMENSIONE",local:"Locale per design",localText:"File, password e contenuto in chiaro restano nell’app crittografica SafeBox. Nessun upload cloud richiesto.",everywhere:"SafeBox ovunque",android:"Scarica APK Android",ios:"Installa su iPhone / iPad",iosHint:"Usa la Web App e Aggiungi alla schermata Home — senza App Store.",ad:"Pubblicità",legal:"Note legali",privacy:"Privacy",terms:"Condizioni",cookies:"Cookie e pubblicità",licenses:"Licenze",install:"Installa SafeBox",github:"Release GitHub",theme:"Aspetto",language:"Lingua",creator:"Libero da usare · Creato da Mr Eddars Noureddine · Zurich, Switzerland",heroEyebrow:"SAFEBOX · CIFRATURA LOCALE DEI FILE",heroLocal:"LOCALE",heroContainer:"UN CONTENITORE SICURO",stageAny:"QUALSIASI FILE",stageCrypto:"CRITTOGRAFIA LOCALE",stageSbx:".SBX",resultLocal:"LOCALE",resultEncrypted:"CIFRATO",resultPortable:"PORTATILE",outcomeAny:"QUALSIASI FILE",outcomeOne:"UN .SBX",outcomeNote:"Il contenuto del file non deve mai lasciare il dispositivo.",promiseEyebrow:"FLUSSO CRITTOGRAFICO SENZA UPLOAD",pulseLocal:"LOCALE",pulseNoCloud:"NO CLOUD",pulsePrivate:"PRIVATO",deviceLabel:"IL TUO DISPOSITIVO",localBoundary:"CONFINE LOCALE",cloudLabel:"CLOUD",downloadsEyebrow:"WEB · ANDROID · iPHONE/iPAD",webOpen:"Apri subito",adReady:"AdSense pronto · disattivato per impostazione predefinita",system:"Sistema",light:"Chiaro",dark:"Scuro",auto:"Auto"},
  pt:{tagline:"Qualquer ficheiro. Um SBX seguro.",sub:"SafeBox cifra localmente qualquer ficheiro — documentos, média, apps, arquivos, código, dados e mais — e cria um ficheiro portátil .sbx.",create:"Criar SafeBox",open:"Abrir SafeBox",story:"Veja qualquer ficheiro tornar-se SBX",scope:"QUALQUER EXTENSÃO · QUALQUER TAMANHO",local:"Local por design",localText:"O ficheiro, palavra-passe e conteúdo aberto ficam na app criptográfica SafeBox. Sem upload cloud.",everywhere:"SafeBox em todo o lado",android:"Baixar APK Android",ios:"Instalar no iPhone / iPad",iosHint:"Use a Web App e Adicionar ao ecrã inicial — sem App Store.",ad:"Publicidade",legal:"Aviso legal",privacy:"Privacidade",terms:"Termos",cookies:"Cookies e anúncios",licenses:"Licenças",install:"Instalar SafeBox",github:"Versões GitHub",theme:"Aparência",language:"Idioma",creator:"Livre para usar · Criado por Mr Eddars Noureddine · Zurich, Switzerland",heroEyebrow:"SAFEBOX · CIFRAGEM LOCAL DE FICHEIROS",heroLocal:"LOCAL",heroContainer:"UM CONTENTOR SEGURO",stageAny:"QUALQUER FICHEIRO",stageCrypto:"CRIPTO LOCAL",stageSbx:".SBX",resultLocal:"LOCAL",resultEncrypted:"CIFRADO",resultPortable:"PORTÁTIL",outcomeAny:"QUALQUER FICHEIRO",outcomeOne:"UM .SBX",outcomeNote:"O conteúdo do ficheiro nunca precisa de sair do dispositivo.",promiseEyebrow:"FLUXO CRIPTO SEM UPLOAD",pulseLocal:"LOCAL",pulseNoCloud:"SEM CLOUD",pulsePrivate:"PRIVADO",deviceLabel:"O SEU DISPOSITIVO",localBoundary:"LIMITE LOCAL",cloudLabel:"CLOUD",downloadsEyebrow:"WEB · ANDROID · iPHONE/iPAD",webOpen:"Abrir imediatamente",adReady:"AdSense pronto · desativado por padrão",system:"Sistema",light:"Claro",dark:"Escuro",auto:"Auto"},
  ar:{tagline:"أي ملف. ملف SBX واحد وآمن.",sub:"يقوم SafeBox بتشفير أي ملف محليًا — مستندات ووسائط وتطبيقات وأرشيفات وكود وبيانات وغير ذلك — وينتج ملف .sbx محمولاً.",create:"إنشاء SafeBox",open:"فتح SafeBox",story:"شاهد أي ملف يتحول إلى SBX",scope:"أي امتداد · أي حجم",local:"محلي منذ التصميم",localText:"يبقى ملفك وكلمة المرور والمحتوى الواضح داخل تطبيق التشفير SafeBox. لا حاجة لرفع سحابي.",everywhere:"SafeBox في كل مكان",android:"تنزيل APK لأندرويد",ios:"التثبيت على iPhone / iPad",iosHint:"استخدم تطبيق الويب ثم أضفه إلى الشاشة الرئيسية — بدون App Store.",ad:"إعلان",legal:"إشعار قانوني",privacy:"الخصوصية",terms:"الشروط",cookies:"ملفات تعريف الارتباط والإعلانات",licenses:"التراخيص",install:"تثبيت SafeBox",github:"إصدارات GitHub",theme:"المظهر",language:"اللغة",creator:"مجاني الاستخدام · أنشأه Mr Eddars Noureddine · Zurich, Switzerland",heroEyebrow:"SAFEBOX · تشفير الملفات محليًا",heroLocal:"محلي",heroContainer:"حاوية آمنة واحدة",stageAny:"أي ملف",stageCrypto:"تشفير محلي",stageSbx:".SBX",resultLocal:"محلي",resultEncrypted:"مشفّر",resultPortable:"محمول",outcomeAny:"أي ملف",outcomeOne:"ملف .SBX واحد",outcomeNote:"لا يحتاج محتوى الملف إلى مغادرة الجهاز.",promiseEyebrow:"تشفير بلا رفع سحابي",pulseLocal:"محلي",pulseNoCloud:"بدون سحابة",pulsePrivate:"خاص",deviceLabel:"جهازك",localBoundary:"النطاق المحلي",cloudLabel:"السحابة",downloadsEyebrow:"ويب · أندرويد · iPHONE/iPAD",webOpen:"فتح فورًا",adReady:"AdSense جاهز · معطل افتراضيًا",system:"النظام",light:"فاتح",dark:"داكن",auto:"تلقائي"},
  de:{tagline:"Jede Datei. Ein sicheres SBX.",sub:"SafeBox verschlüsselt jede Datei lokal — Dokumente, Medien, Apps, Archive, Code, Daten und mehr — und erzeugt eine portable .sbx-Datei.",create:"SafeBox erstellen",open:"SafeBox öffnen",story:"Sieh zu, wie jede Datei zu SBX wird",scope:"JEDE ENDUNG · JEDE GRÖSSE",local:"Lokal by Design",localText:"Datei, Passwort und Klartext bleiben in der SafeBox-Krypto-App. Kein Cloud-Upload erforderlich.",everywhere:"SafeBox überall",android:"Android APK herunterladen",ios:"Auf iPhone / iPad installieren",iosHint:"Web-App verwenden und Zum Home-Bildschirm hinzufügen — ohne App Store.",ad:"Werbung",legal:"Impressum",privacy:"Datenschutz",terms:"Bedingungen",cookies:"Cookies & Werbung",licenses:"Lizenzen",install:"SafeBox installieren",github:"GitHub-Releases",theme:"Darstellung",language:"Sprache",creator:"Frei nutzbar · Erstellt von Mr Eddars Noureddine · Zurich, Switzerland",heroEyebrow:"SAFEBOX · LOKALE DATEIVERSCHLÜSSELUNG",heroLocal:"LOKAL",heroContainer:"EIN SICHERER CONTAINER",stageAny:"JEDE DATEI",stageCrypto:"LOKALE KRYPTO",stageSbx:".SBX",resultLocal:"LOKAL",resultEncrypted:"VERSCHLÜSSELT",resultPortable:"PORTABEL",outcomeAny:"JEDE DATEI",outcomeOne:"EINE .SBX",outcomeNote:"Dateiinhalte müssen das Gerät niemals verlassen.",promiseEyebrow:"KRYPTO-FLUSS OHNE CLOUD-UPLOAD",pulseLocal:"LOKAL",pulseNoCloud:"KEINE CLOUD",pulsePrivate:"PRIVAT",deviceLabel:"DEIN GERÄT",localBoundary:"LOKALE GRENZE",cloudLabel:"CLOUD",downloadsEyebrow:"WEB · ANDROID · iPHONE/iPAD",webOpen:"Sofort öffnen",adReady:"AdSense bereit · standardmäßig deaktiviert",system:"System",light:"Hell",dark:"Dunkel",auto:"Auto"},
  es:{tagline:"Cualquier archivo. Un SBX seguro.",sub:"SafeBox cifra localmente cualquier archivo — documentos, medios, apps, archivos comprimidos, código, datos y más — y crea un archivo .sbx portátil.",create:"Crear SafeBox",open:"Abrir SafeBox",story:"Mira cómo cualquier archivo se convierte en SBX",scope:"CUALQUIER EXTENSIÓN · CUALQUIER TAMAÑO",local:"Local por diseño",localText:"Tu archivo, contraseña y contenido en claro permanecen dentro de la app criptográfica SafeBox. Sin subida a la nube.",everywhere:"SafeBox en todas partes",android:"Descargar APK Android",ios:"Instalar en iPhone / iPad",iosHint:"Usa la Web App y Añadir a pantalla de inicio — sin App Store.",ad:"Publicidad",legal:"Aviso legal",privacy:"Privacidad",terms:"Condiciones",cookies:"Cookies y publicidad",licenses:"Licencias",install:"Instalar SafeBox",github:"Versiones GitHub",theme:"Apariencia",language:"Idioma",creator:"De uso libre · Creado por Mr Eddars Noureddine · Zurich, Switzerland",heroEyebrow:"SAFEBOX · CIFRADO LOCAL DE ARCHIVOS",heroLocal:"LOCAL",heroContainer:"UN CONTENEDOR SEGURO",stageAny:"CUALQUIER ARCHIVO",stageCrypto:"CRIPTO LOCAL",stageSbx:".SBX",resultLocal:"LOCAL",resultEncrypted:"CIFRADO",resultPortable:"PORTÁTIL",outcomeAny:"CUALQUIER ARCHIVO",outcomeOne:"UN .SBX",outcomeNote:"El contenido del archivo nunca necesita salir del dispositivo.",promiseEyebrow:"FLUJO CRIPTO SIN SUBIDA A LA NUBE",pulseLocal:"LOCAL",pulseNoCloud:"SIN NUBE",pulsePrivate:"PRIVADO",deviceLabel:"TU DISPOSITIVO",localBoundary:"LÍMITE LOCAL",cloudLabel:"NUBE",downloadsEyebrow:"WEB · ANDROID · iPHONE/iPAD",webOpen:"Abrir al instante",adReady:"AdSense listo · desactivado por defecto",system:"Sistema",light:"Claro",dark:"Oscuro",auto:"Auto"},
  hr:{tagline:"Bilo koja datoteka. Jedan sigurni SBX.",sub:"SafeBox lokalno šifrira bilo koju datoteku — dokumente, medije, aplikacije, arhive, kod, podatke i više — te stvara prenosivu .sbx datoteku.",create:"Kreiraj SafeBox",open:"Otvori SafeBox",story:"Pogledaj kako bilo koja datoteka postaje SBX",scope:"BILO KOJA EKSTENZIJA · BILO KOJA VELIČINA",local:"Lokalno po dizajnu",localText:"Datoteka, lozinka i čisti sadržaj ostaju unutar SafeBox kripto aplikacije. Cloud prijenos nije potreban.",everywhere:"SafeBox svugdje",android:"Preuzmi Android APK",ios:"Instaliraj na iPhone / iPad",iosHint:"Koristi Web App i Dodaj na početni zaslon — bez App Storea.",ad:"Oglas",legal:"Pravne informacije",privacy:"Privatnost",terms:"Uvjeti",cookies:"Kolačići i oglasi",licenses:"Licence",install:"Instaliraj SafeBox",github:"GitHub izdanja",theme:"Izgled",language:"Jezik",creator:"Slobodan za korištenje · Izradio Mr Eddars Noureddine · Zurich, Switzerland",heroEyebrow:"SAFEBOX · LOKALNO ŠIFRIRANJE DATOTEKA",heroLocal:"LOKALNO",heroContainer:"JEDAN SIGURAN SPREMNIK",stageAny:"BILO KOJA DATOTEKA",stageCrypto:"LOKALNA KRIPTOGRAFIJA",stageSbx:".SBX",resultLocal:"LOKALNO",resultEncrypted:"ŠIFRIRANO",resultPortable:"PRENOSIVO",outcomeAny:"BILO KOJA DATOTEKA",outcomeOne:"JEDAN .SBX",outcomeNote:"Sadržaj datoteke nikada ne mora napustiti uređaj.",promiseEyebrow:"KRIPTO TOK BEZ CLOUD PRIJENOSA",pulseLocal:"LOKALNO",pulseNoCloud:"BEZ CLOUDA",pulsePrivate:"PRIVATNO",deviceLabel:"TVOJ UREĐAJ",localBoundary:"LOKALNA GRANICA",cloudLabel:"CLOUD",downloadsEyebrow:"WEB · ANDROID · iPHONE/iPAD",webOpen:"Otvori odmah",adReady:"AdSense spreman · zadano isključen",system:"Sustav",light:"Svijetlo",dark:"Tamno",auto:"Auto"}
};

const supported = Object.keys(copies) as Lang[];
const SAFEBOX_SHARED_LANGUAGE_KEY = "safebox.language.v1";
const SAFEBOX_LEGACY_LANGUAGE_KEY = "safebox.lang";
const SAFEBOX_SHARED_THEME_KEY = "safebox-theme-mode.v1";
const SAFEBOX_LANDING_THEME_KEY = "safebox.theme";
const SAFEBOX_APP_LEGACY_THEME_KEY = "safebox-theme";

function detectLang(): Lang {
  for (const raw of navigator.languages || [navigator.language]) {
    const l = raw.toLowerCase().split("-")[0] as Lang;
    if (supported.includes(l)) return l;
  }
  return "en";
}
function readLanguageChoice(): LangChoice {
  const canonical = localStorage.getItem(SAFEBOX_SHARED_LANGUAGE_KEY) as LangChoice | null;
  if (canonical === "auto" || (canonical && supported.includes(canonical as Lang))) return canonical;
  const legacy = localStorage.getItem(SAFEBOX_LEGACY_LANGUAGE_KEY) as Lang | null;
  if (legacy && supported.includes(legacy)) {
    localStorage.setItem(SAFEBOX_SHARED_LANGUAGE_KEY, legacy);
    return legacy;
  }
  return "auto";
}
function persistLanguageChoice(choice: LangChoice) {
  localStorage.setItem(SAFEBOX_SHARED_LANGUAGE_KEY, choice);
  if (choice === "auto") localStorage.removeItem(SAFEBOX_LEGACY_LANGUAGE_KEY);
  else localStorage.setItem(SAFEBOX_LEGACY_LANGUAGE_KEY, choice);
}
let langChoice: LangChoice = readLanguageChoice();
let lang: Lang = langChoice === "auto" ? detectLang() : langChoice;
let theme = localStorage.getItem(SAFEBOX_SHARED_THEME_KEY) || localStorage.getItem(SAFEBOX_LANDING_THEME_KEY) || localStorage.getItem(SAFEBOX_APP_LEGACY_THEME_KEY) || "system";
if (!["system","light","dark"].includes(theme)) theme = "system";
const root = document.querySelector<HTMLDivElement>("#landing")!;

root.innerHTML = `
<header class="sbx-nav">
  <a class="brand" href="./"><img src="${import.meta.env.BASE_URL}safebox-logo.png" alt=""/><b>SafeBox</b></a>
  <nav><label><span data-i="language"></span><select id="langSel"><option value="auto"></option>${supported.map(l=>`<option value="${l}">${l.toUpperCase()}</option>`).join("")}</select></label><label><span data-i="theme"></span><select id="themeSel"><option value="system"></option><option value="dark"></option><option value="light"></option></select></label></nav>
</header>
<main>
<section class="hero motion-scope" id="heroSection">
  <div class="hero-ambient" aria-hidden="true"><span></span><span></span><span></span></div>
  <div class="hero-copy" data-motion="hero-copy"><p class="eyebrow" data-i="heroEyebrow"></p><h1 data-i="tagline"></h1><p data-i="sub"></p><div class="actions"><a class="primary" href="./app.html?mode=create" data-i="create"></a><a class="ghost" href="./app.html?mode=open" data-i="open"></a></div></div>
  <div class="hero-vault" data-motion="hero-vault" aria-hidden="true">
    <div class="vault-halo"></div><div class="vault-ring vr1"></div><div class="vault-ring vr2"></div><div class="vault-ring vr3"></div>
    <div class="vault-core"><span data-i="heroLocal"></span><strong>.SBX</strong><small data-i="heroContainer"></small></div>
    <i class="hero-chip hc1">PDF</i><i class="hero-chip hc2">MP4</i><i class="hero-chip hc3">ZIP</i><i class="hero-chip hc4">RAW</i><i class="hero-chip hc5">APP</i><i class="hero-chip hc6">DB</i>
  </div>
</section>

<section class="crypto-story" id="cryptoStory" aria-label="SafeBox encryption visualization">
  <div class="story-sticky">
    <div class="story-head"><div><span data-i="story"></span><strong data-i="scope"></strong></div><small id="storyPct">0%</small></div>
    <div class="stage-rail" aria-hidden="true"><span data-stage="input"><b>01</b> <i data-i="stageAny"></i></span><span data-stage="encrypt"><b>02</b> <i data-i="stageCrypto"></i></span><span data-stage="output"><b>03</b> <i data-i="stageSbx"></i></span></div>
    <div class="scene" id="scene">
      <div class="source-files" id="sourceFiles">
        <div class="file f1"><b>PDF</b><small>820 KB</small></div><div class="file f2"><b>MP4</b><small>1.8 GB</small></div><div class="file f3"><b>EXE</b><small>86 MB</small></div><div class="file f4"><b>ZIP</b><small>740 MB</small></div><div class="file f5"><b>JPG</b><small>6.2 MB</small></div><div class="file f6"><b>DOCX</b><small>48 KB</small></div><div class="file f7"><b>APK</b><small>132 MB</small></div><div class="file f8"><b>SQL</b><small>4.7 GB</small></div>
      </div>
      <div class="extension-cloud" id="extensionCloud" aria-hidden="true"></div>
      <div class="crypto-field" aria-hidden="true"><div class="field-line fl1"></div><div class="field-line fl2"></div><div class="field-line fl3"></div></div>
      <div class="reactor" id="reactor"><div class="ring r1"></div><div class="ring r2"></div><div class="ring r3"></div><div class="matrix" id="matrix"></div><div class="core"><span>AEAD</span><strong>XCHACHA20</strong><small>ARGON2 · LOCAL</small></div></div>
      <div class="sbx-result" id="sbxResult"><div class="sbx-glow"></div><div class="sbx-face"><span>SAFEBOX</span><strong>.SBX</strong><small><em data-i="resultLocal"></em> · <em data-i="resultEncrypted"></em> · <em data-i="resultPortable"></em></small></div></div>
      <div class="story-outcome" id="storyOutcome"><span data-i="outcomeAny"></span><i>→</i><strong data-i="outcomeOne"></strong><small data-i="outcomeNote"></small></div>
    </div>
  </div>
</section>

<section class="promise motion-scope" id="promiseSection">
  <div class="promise-copy" data-motion="promise-copy"><p class="eyebrow" data-i="promiseEyebrow"></p><h2 data-i="local"></h2><p data-i="localText"></p><div class="promise-pulses" aria-hidden="true"><span data-i="pulseLocal"></span><span data-i="pulseNoCloud"></span><span data-i="pulsePrivate"></span></div></div>
  <div class="privacy-diagram" data-motion="privacy-diagram" aria-hidden="true"><div class="device"><span data-i="deviceLabel"></span><strong>01</strong></div><div class="local-boundary"><b data-i="localBoundary"></b><i></i><i></i><i></i></div><div class="cloud-off"><span data-i="cloudLabel"></span><strong>×</strong></div></div>
</section>

<section class="ad-shell" id="adShell" aria-label="Advertisement" hidden><span data-i="ad"></span><div class="ad-slot" id="landing-ad" data-ad-state="disabled" data-i="adReady"></div></section>

<section class="downloads motion-scope" id="downloadsSection">
  <div class="downloads-head" data-motion="downloads-head"><p class="eyebrow" data-i="downloadsEyebrow"></p><h2 data-i="everywhere"></h2></div>
  <div class="download-grid">
    <a class="download-card android" id="androidDownload" href="#" aria-disabled="true" rel="noopener" data-motion="download-android"><div class="device-art android-art"><span></span></div><div class="download-copy"><strong>Android</strong><span data-i="android"></span><small data-i="github"></small></div><i aria-hidden="true">APK</i></a>
    <a class="download-card ios" href="./app.html" data-motion="download-ios"><div class="device-art phone-art"><span></span></div><div class="download-copy"><strong>iPhone / iPad</strong><span data-i="ios"></span><small data-i="iosHint"></small></div><i aria-hidden="true">PWA</i></a>
    <a class="download-card web" href="./app.html" data-motion="download-web"><div class="device-art browser-art"><span></span></div><div class="download-copy"><strong>Web</strong><span data-i="install"></span><small data-i="webOpen"></small></div><i aria-hidden="true">WEB</i></a>
  </div>
</section>
</main>
<footer><div><b>SafeBox</b><span data-i="creator"></span><a class="creator-x" href="https://x.com/EddarsStudio" target="_blank" rel="noopener noreferrer" aria-label="EDDARS Studio on X">X · @EddarsStudio</a></div><nav><a href="./legal/legal.html" data-i="legal"></a><a href="./legal/privacy.html" data-i="privacy"></a><a href="./legal/terms.html" data-i="terms"></a><a href="./legal/cookies.html" data-i="cookies"></a><a href="./legal/licenses.html" data-i="licenses"></a></nav></footer>`;

function applyTheme(){
  document.documentElement.dataset.theme=theme;
  document.documentElement.dataset.themeMode=theme;
  (root.querySelector("#themeSel") as HTMLSelectElement).value=theme;
}
function applyLang(){
  lang = langChoice === "auto" ? detectLang() : langChoice;
  const c=copies[lang];
  document.documentElement.lang=lang;
  document.documentElement.dir=lang==="ar"?"rtl":"ltr";
  root.querySelectorAll<HTMLElement>("[data-i]").forEach(el=>{ const k=el.dataset.i as keyof Copy; el.textContent=c[k]||""; });
  const langSel=root.querySelector("#langSel") as HTMLSelectElement;
  langSel.value=langChoice;
  const autoOption=langSel.querySelector<HTMLOptionElement>('option[value="auto"]'); if(autoOption) autoOption.textContent=c.auto;
  const themeSel=root.querySelector("#themeSel") as HTMLSelectElement;
  const systemOption=themeSel.querySelector<HTMLOptionElement>('option[value="system"]'); if(systemOption) systemOption.textContent=c.system;
  const lightOption=themeSel.querySelector<HTMLOptionElement>('option[value="light"]'); if(lightOption) lightOption.textContent=c.light;
  const darkOption=themeSel.querySelector<HTMLOptionElement>('option[value="dark"]'); if(darkOption) darkOption.textContent=c.dark;
}
(root.querySelector("#langSel") as HTMLSelectElement).addEventListener("change",e=>{
  langChoice=(e.target as HTMLSelectElement).value as LangChoice;
  persistLanguageChoice(langChoice);
  applyLang();
});
(root.querySelector("#themeSel") as HTMLSelectElement).addEventListener("change",e=>{
  theme=(e.target as HTMLSelectElement).value;
  localStorage.setItem(SAFEBOX_SHARED_THEME_KEY,theme);
  localStorage.setItem(SAFEBOX_LANDING_THEME_KEY,theme);
  applyTheme();
});
window.addEventListener("storage", event=>{
  if(event.key===SAFEBOX_SHARED_LANGUAGE_KEY){ langChoice=readLanguageChoice(); applyLang(); }
  if(event.key===SAFEBOX_SHARED_THEME_KEY){ theme=localStorage.getItem(SAFEBOX_SHARED_THEME_KEY)||"system"; applyTheme(); }
});
applyTheme(); applyLang();

const matrix = root.querySelector("#matrix")!;
const glyphs = "01A9F7C2E4B6D8X3K5M8Q";
for (let col=0; col<34; col++) {
  const d=document.createElement("div"); d.className="matrix-col"; d.style.setProperty("--col",String(col));
  d.textContent=Array.from({length:52},(_,i)=>glyphs[(i*7+col*5)%glyphs.length]).join("\n"); matrix.appendChild(d);
}

const extensionNames = [
  "DOCX","XLSX","PPTX","TXT","RTF","ODT","CSV","JSON","XML","YAML","SQL","DB","MDB","PDF","EPUB","MOBI",
  "JPG","PNG","GIF","WEBP","SVG","HEIC","RAW","PSD","AI","TIFF","BMP","MP4","MOV","MKV","AVI","WEBM","MP3","WAV","FLAC","AAC","OGG",
  "ZIP","RAR","7Z","TAR","GZ","ISO","DMG","EXE","MSI","APK","IPA","APP","HTML","CSS","JS","TS","PY","RS","JAVA","CPP","GO","PHP",
  "STL","OBJ","FBX","BLEND","DWG","DXF","CAD","LOG","BIN","DAT","CFG","INI","TORRENT","SRT","VTT","PARQUET","AVIF","DNG","CR3","NEF","WASM","PKG"
];
const extensionSizes = [52,46,40,36,32,28,24,21,18,16,14,12,10,9,8,7,6,5,4,3,2,1];
const extensionCloud = root.querySelector<HTMLElement>("#extensionCloud")!;
const extensionNodes: HTMLElement[] = [];
extensionNames.forEach((name,i)=>{
  const el=document.createElement("span"); el.textContent=name; el.className="extension-token";
  const px=extensionSizes[(i*7)%extensionSizes.length]; el.style.setProperty("--token-size",`${px}px`); el.style.fontSize=`${px}px`;
  el.dataset.seed=String(i); extensionCloud.appendChild(el); extensionNodes.push(el);
});

const story=root.querySelector<HTMLElement>("#cryptoStory")!;
const scene=root.querySelector<HTMLElement>("#scene")!;
const pct=root.querySelector<HTMLElement>("#storyPct")!;
const stages=Array.from(root.querySelectorAll<HTMLElement>("[data-stage]"));
const motionScopes = Array.from(root.querySelectorAll<HTMLElement>(".motion-scope"));
const reduce=matchMedia("(prefers-reduced-motion: reduce)");
if(reduce.matches) root.classList.add("reduce-motion");

function clamp01(v:number){ return Math.min(1,Math.max(0,v)); }
function smoothstep(a:number,b:number,v:number){ const t=clamp01((v-a)/(b-a)); return t*t*(3-2*t); }
function sectionProgress(el:HTMLElement){ const r=el.getBoundingClientRect(); return clamp01((window.innerHeight-r.top)/(window.innerHeight+r.height)); }

function applyScopeMotion(scope:HTMLElement, scopeIndex:number){
  const p=sectionProgress(scope); const centered=(p-.5)*2;
  const nodes=[scope,...Array.from(scope.querySelectorAll<HTMLElement>("*"))];
  nodes.forEach((el,i)=>{
    const tag=el.tagName;
    const textLike=/^(A|BUTTON|H1|H2|H3|P|SPAN|SMALL|STRONG|B|I|LABEL|SELECT)$/.test(tag);
    const amp=textLike ? 1.6 : 7.5;
    const phase=(i+1)*(1.19+scopeIndex*.23);
    const x=Math.sin(centered*Math.PI+phase)*amp;
    const y=Math.cos(centered*Math.PI*.76+phase)*amp*.62;
    const rot=Math.sin(centered*Math.PI+phase*.52)*(textLike?.12:.65);
    const scale=1+Math.sin(centered*Math.PI+phase)*(textLike?.0015:.0055);
    el.style.setProperty("--motion-x",`${x.toFixed(2)}px`);
    el.style.setProperty("--motion-y",`${y.toFixed(2)}px`);
    el.style.setProperty("--motion-r",`${rot.toFixed(3)}deg`);
    el.style.setProperty("--motion-s",scale.toFixed(4));
    el.style.setProperty("--motion-p",p.toFixed(4));
  });
}

let raf=0;
function renderScroll(){
  raf=0;
  document.documentElement.style.setProperty("--scroll-y", String(window.scrollY));
  motionScopes.forEach(applyScopeMotion);
  const r=story.getBoundingClientRect();
  const span=Math.max(1,story.offsetHeight-window.innerHeight);
  const p=clamp01(-r.top/span);
  const converge=smoothstep(.12,.58,p);
  const encrypt=smoothstep(.28,.67,p);
  const output=smoothstep(.55,.76,p);
  scene.style.setProperty("--p",p.toFixed(4));
  scene.style.setProperty("--converge",converge.toFixed(4));
  scene.style.setProperty("--encrypt",encrypt.toFixed(4));
  scene.style.setProperty("--output",output.toFixed(4));
  pct.textContent=`${Math.round(p*100)}%`;

  stages.forEach((el,i)=>{ const active=(p < .34 ? i===0 : p < .67 ? i===1 : i===2); el.classList.toggle("active",active); });

  root.querySelectorAll<HTMLElement>(".matrix-col").forEach((el,i)=>{
    const speed=.62+(i%7)*.095;
    const y=(1-encrypt)*420 - encrypt*670*speed - (i%4)*28;
    const z=Math.sin(p*Math.PI*2+i*.73)*72;
    const twist=Math.sin(p*Math.PI+i*.31)*2.6;
    el.style.transform=`translate3d(0,${y.toFixed(1)}px,${z.toFixed(1)}px) rotateZ(${twist.toFixed(2)}deg)`;
  });

  const w=window.innerWidth, h=window.innerHeight;
  extensionNodes.forEach((el,i)=>{
    const seed=i+1;
    const sx=(-.47+((seed*37)%94)/100)*w;
    const sy=(-.38+((seed*53)%79)/100)*h;
    const sz=-620+((seed*71)%960);
    const orbit=(1-converge);
    const x=sx*orbit+Math.sin(seed*1.93+p*7)*28*orbit;
    const y=sy*orbit+Math.cos(seed*1.37+p*6)*20*orbit;
    const z=sz*orbit-converge*120;
    const rot=(seed%2?1:-1)*orbit*((seed*17)%48);
    const opacity=clamp01((1-output*1.25)*(0.32+Math.min(1,parseFloat(getComputedStyle(el).fontSize)/18)));
    el.style.transform=`translate3d(${x.toFixed(1)}px,${y.toFixed(1)}px,${z.toFixed(1)}px) rotateZ(${rot.toFixed(1)}deg)`;
    el.style.opacity=opacity.toFixed(3);
  });
}
function onScroll(){if(!raf)raf=requestAnimationFrame(renderScroll)}
window.addEventListener("scroll",onScroll,{passive:true});
window.addEventListener("resize",onScroll,{passive:true});
renderScroll();

const androidUrl = (import.meta.env.VITE_SAFEBOX_ANDROID_RELEASE_URL || "").trim();
const androidLink = root.querySelector<HTMLAnchorElement>("#androidDownload");
if (androidLink) {
  if (androidUrl) { androidLink.href = androidUrl; androidLink.removeAttribute("aria-disabled"); }
  else androidLink.addEventListener("click", e => e.preventDefault());
}
