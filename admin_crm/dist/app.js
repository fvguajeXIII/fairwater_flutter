import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  GoogleAuthProvider,
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  onSnapshot,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

const firebaseConfig = {
  apiKey: "AIzaSyDUtIYqhpqrBzprag_IAIWF2QfwOwSll54",
  appId: "1:574931919668:web:5f62017a0dc5a774963b61",
  messagingSenderId: "574931919668",
  projectId: "fairwater-app",
  authDomain: "fairwater-app.firebaseapp.com",
  databaseURL:
    "https://fairwater-app-default-rtdb.europe-west1.firebasedatabase.app",
  storageBucket: "fairwater-app.firebasestorage.app",
  measurementId: "G-8PH9X510X0",
};

const firebaseApp = initializeApp(firebaseConfig);
const userAdminApp = initializeApp(firebaseConfig, "fairwater-user-admin");
const auth = getAuth(firebaseApp);
const db = getFirestore(firebaseApp);
const userAdminAuth = getAuth(userAdminApp);
const userAdminDb = getFirestore(userAdminApp);

const LOGIN_USERNAME = "FairWater";
const LOGIN_PASSWORD = "FairWater2026!";
const LOGIN_STORAGE_KEY = "fairwater-admin-auth";
const googleAdminProvider = new GoogleAuthProvider();
googleAdminProvider.setCustomParameters({ prompt: "select_account" });

const titleByView = {
  dashboard: "Dashboard",
  users: "Utenti",
  refill: "Punti refill",
  sponsors: "Sponsor",
  roles: "Ruoli e accessi",
  deploy: "Deploy",
};

const state = {
  users: [],
  bars: [],
  sponsors: [],
};

const snapshotUnsubscribers = {
  users: null,
  bars: null,
  sponsors: null,
};

const appSeedBars = [
  ["caffe-del-duomo", "Caffe del Duomo", "Piazza Municipio 18", "Terracina", 41.291636, 13.2485294, "Refill verificato", "Lun-Dom 07:00-23:30", ["Acqua fresca", "Bottle refill", "Tavoli esterni"], true],
  ["bar-grande", "Bar Grande", "Piazza Municipio 12", "Terracina", 41.2915161, 13.2490918, "Punto refill", "Lun-Sab 06:30-22:30", ["Refill rapido", "Caffetteria", "Snack"], false],
  ["ready-steady-go", "Ready Steady Go!", "Via Salita Annunziata 17", "Terracina", 41.291187, 13.2496871, "Punto refill", "Mar-Dom 08:00-00:00", ["Refill water", "Brunch", "Wi-Fi"], false],
  ["artis-cafe", "Artis Cafe", "Piazza Garibaldi 3;5", "Terracina", 41.2882868, 13.2534868, "Punto refill", "Lun-Dom 07:00-20:30", ["Acqua filtrata", "Dolci", "Posti a sedere"], false],
  ["caffetteria-bar-quadrifoglio", "Caffetteria Bar Quadrifoglio", "Viale della Vittoria 59", "Terracina", 41.2855149, 13.2480586, "Punto refill", "Mo-Su 07:30-02:00", ["Refill bottle", "Cocktail", "Dehors"], false],
  ["caffe-del-viale", "Caffe del viale", "Viale della Vittoria 17", "Terracina", 41.2882055, 13.2499981, "Punto refill", "Lun-Sab 06:30-21:30", ["Acqua fresca", "Colazioni", "Take away"], false],
  ["colorado-caffe", "Colorado Cafe", "Piazza Garibaldi 21", "Terracina", 41.2884611, 13.2524521, "Punto refill", "Lun-Dom 07:00-01:00", ["Refill", "Aperitivi", "Outdoor seating"], false],
  ["bar-roma", "Bar Roma", "Via Roma 72", "Terracina", 41.2892293, 13.2513132, "Punto refill", "Lun-Dom 05:30-23:00", ["Acqua refrigerata", "Caffetteria", "Accessibile"], false],
  ["bar-traiano", "Bar Traiano", "Terracina", "Terracina", 41.2865912, 13.2532889, "Punto refill", "Lun-Sab 07:00-22:00", ["Refill acqua", "Snack veloci", "Tavoli interni"], false],
  ["bar-milano", "Bar Milano", "Piazzale Lido 20", "Terracina", 41.2845739, 13.2469707, "Punto refill", "Mo-Su 07:30-02:00", ["Refill gratuito", "Lounge", "Vista mare"], false],
  ["caffe-del-corso-fondi", "Caffe del Corso", "Corso Appio Claudio 44", "Fondi", 41.357925, 13.425316, "Punto refill", "Lun-Dom 07:00-22:30", ["Refill acqua", "Colazioni", "Tavoli interni"], true],
  ["bar-san-pietro-fondi", "Bar San Pietro", "Via San Pietro 12", "Fondi", 41.356812, 13.427144, "Punto refill", "Lun-Sab 06:30-21:30", ["Refill rapido", "Caffetteria", "Snack"], false],
  ["bistrot-castello-fondi", "Bistrot Castello", "Piazza Unita d Italia 6", "Fondi", 41.355744, 13.428066, "Punto refill", "Mar-Dom 08:00-23:00", ["Refill bottle", "Brunch", "Wi-Fi"], false],
  ["gran-caffe-baronale-fondi", "Gran Caffe Baronale", "Via Baronale 21", "Fondi", 41.354968, 13.429552, "Punto refill", "Lun-Dom 07:00-00:00", ["Acqua fresca", "Aperitivi", "Dehors"], false],
  ["lido-urban-cafe-fondi", "Lido Urban Cafe", "Viale Vittorio Emanuele III 18", "Fondi", 41.358511, 13.431189, "Punto refill", "Lun-Sab 07:30-22:00", ["Refill gratuito", "Take away", "Posti a sedere"], false],
  ["caffetteria-porta-romana-fondi", "Caffetteria Porta Romana", "Via Roma 83", "Fondi", 41.353922, 13.432701, "Punto refill", "Lun-Dom 06:30-21:00", ["Acqua refrigerata", "Dolci", "Accessibile"], false],
  ["vittoria-lounge-fondi", "Vittoria Lounge", "Viale Regina Margherita 10", "Fondi", 41.359674, 13.423981, "Punto refill", "Lun-Dom 08:00-01:00", ["Refill water", "Cocktail", "Outdoor seating"], false],
  ["piazza-cafe-fondi", "Piazza Cafe", "Piazza Alcide De Gasperi 5", "Fondi", 41.361102, 13.427852, "Punto refill", "Lun-Sab 07:00-20:30", ["Refill acqua", "Panini", "Tavoli esterni"], false],
  ["dolce-pausa-fondi", "Dolce Pausa", "Via Arnale Rosso 14", "Fondi", 41.355286, 13.423944, "Punto refill", "Mar-Dom 07:30-22:30", ["Refill bottle", "Pasticceria", "Wi-Fi"], false],
  ["le-cinema-sant-anastasia", "Le Cinema", "Via Roma 343", "Sant Anastasia", 40.867761, 14.402595, "Punto refill", "Lun-Dom 16:30-00:30", ["Refill acqua", "Area relax", "Snack bar"], false],
].map(([id, name, address, city, latitude, longitude, refillInfo, openInfo, services, featured]) => ({
  id,
  name,
  address,
  city,
  latitude,
  longitude,
  refillInfo,
  openInfo,
  services,
  socialLinks: buildDefaultSocialLinks(id),
  galleryImages: buildGallery(id),
  featured,
}));

const appSeedSponsors = [
  {
    id: "emporio-del-corso",
    name: "Emporio del Corso",
    category: "Market di quartiere",
    address: "Corso Italia 18, Fondi",
    contribution: "Supporto logistico e materiali per gli eventi.",
    thankYouMessage: "Grazie per aver creduto nel progetto fin dal primo momento e per averci aiutato a coinvolgere il quartiere.",
    supports: ["Eventi locali", "Materiali", "Presenza sul territorio"],
    socialLinks: {
      instagram: "https://www.instagram.com/emporiodelcorso",
      facebook: "https://www.facebook.com/emporiodelcorso",
    },
    featured: true,
  },
  {
    id: "pasticceria-la-portella",
    name: "Pasticceria La Portella",
    category: "Pasticceria artigianale",
    address: "Via Roma 42, Fondi",
    contribution: "Accoglienza durante presentazioni e giornate divulgative.",
    thankYouMessage: "Il vostro contributo ha reso gli incontri con la comunita piu calorosi, accessibili e partecipati.",
    supports: ["Accoglienza", "Degustazioni", "Eventi"],
    socialLinks: {
      instagram: "https://www.instagram.com/pasticcerialaportella",
      website: "https://www.pasticcerialaportella.it",
    },
    featured: false,
  },
  {
    id: "cartolibreria-aurora",
    name: "Cartolibreria Aurora",
    category: "Cartoleria e libreria",
    address: "Viale Vittorio Emanuele III 7, Fondi",
    contribution: "Stampa di materiali informativi e supporti promozionali.",
    thankYouMessage: "Grazie per averci aiutato a raccontare il progetto con materiali chiari, curati e sempre disponibili.",
    supports: ["Volantini", "Locandine", "Comunicazione"],
    socialLinks: {
      facebook: "https://www.facebook.com/cartolibreriaaurora",
      instagram: "https://www.instagram.com/cartolibreriaaurora",
    },
    featured: false,
  },
  {
    id: "officina-verde",
    name: "Officina Verde",
    category: "Mobilita sostenibile",
    address: "Via Appia Lato Roma 95, Fondi",
    contribution: "Supporto tecnico per iniziative legate a mobilita e territorio.",
    thankYouMessage: "La vostra sensibilita verso il territorio ha dato forza concreta alla visione del progetto.",
    supports: ["Territorio", "Tecnica", "Sostenibilita"],
    socialLinks: {
      instagram: "https://www.instagram.com/officinaverdefondi",
      website: "https://www.officinaverdefondi.it",
    },
    featured: false,
  },
  {
    id: "erboristeria-san-magno",
    name: "Erboristeria San Magno",
    category: "Benessere e prodotti naturali",
    address: "Piazza Unita d Italia 11, Fondi",
    contribution: "Sostegno economico e visibilita alle attivita di lancio.",
    thankYouMessage: "Grazie per il sostegno ricevuto: il vostro aiuto ha contribuito davvero alla realizzazione del progetto.",
    supports: ["Sponsorizzazione", "Benessere", "Community"],
    socialLinks: {
      instagram: "https://www.instagram.com/erboristeriasanmagno",
      facebook: "https://www.facebook.com/erboristeriasanmagno",
    },
    featured: false,
  },
];

const links = Array.from(document.querySelectorAll(".nav-link"));
const panels = Array.from(document.querySelectorAll(".view"));
const titleNode = document.getElementById("view-title");
const loginShell = document.getElementById("login-shell");
const loginForm = document.getElementById("login-form");
const loginError = document.getElementById("login-error");
const logoutButton = document.getElementById("logout-button");
const dataStatus = document.getElementById("data-status");
const userAdminAuthForm = document.getElementById("user-admin-auth-form");
const userAdminGoogleButton = document.getElementById("user-admin-google-button");
const userAdminAuthStatus = document.getElementById("user-admin-auth-status");

const usersCount = document.getElementById("users-count");
const barsCount = document.getElementById("bars-count");
const sponsorsCount = document.getElementById("sponsors-count");

const usersTableBody = document.getElementById("users-table-body");
const refillTableBody = document.getElementById("refill-table-body");
const sponsorsTableBody = document.getElementById("sponsors-table-body");

const dashboardUserForm = document.getElementById("dashboard-user-form");
const dashboardRefillForm = document.getElementById("dashboard-refill-form");
const dashboardSponsorForm = document.getElementById("dashboard-sponsor-form");
const refillEditForm = document.getElementById("refill-edit-form");
const sponsorEditForm = document.getElementById("sponsor-edit-form");

function unlockAdmin(user) {
  if (loginShell) {
    loginShell.classList.add("is-hidden");
  }
  document.body.classList.remove("crm-login-open");
  window.sessionStorage.setItem(LOGIN_STORAGE_KEY, "ok");
  setStatus(`Accesso CRM attivo: ${user?.email ?? "FairWater"}`, "success");
}

function lockAdmin({ clearSession = true } = {}) {
  if (loginShell) {
    loginShell.classList.remove("is-hidden");
  }
  document.body.classList.add("crm-login-open");
  if (clearSession) {
    window.sessionStorage.removeItem(LOGIN_STORAGE_KEY);
  }
  stopDataSync();
  resetState();
}

function setView(viewName) {
  for (const link of links) {
    link.classList.toggle("is-active", link.dataset.view === viewName);
  }

  for (const panel of panels) {
    panel.classList.toggle("is-visible", panel.dataset.panel === viewName);
  }

  if (titleNode) {
    titleNode.textContent = titleByView[viewName] ?? "FairWater CRM";
  }
}

function setStatus(message, type = "neutral") {
  if (!dataStatus) {
    return;
  }

  dataStatus.textContent = message;
  dataStatus.classList.remove("is-success", "is-error");

  if (type === "success") {
    dataStatus.classList.add("is-success");
  }

  if (type === "error") {
    dataStatus.classList.add("is-error");
  }
}

function appendStatus(message, type = "neutral") {
  if (!dataStatus) {
    return;
  }

  setStatus(message, type);
  console.info(`[FairWater CRM] ${message}`);
}

function setUserAdminStatus(message, type = "neutral") {
  if (!userAdminAuthStatus) {
    return;
  }

  userAdminAuthStatus.textContent = message;
  userAdminAuthStatus.classList.remove("is-success", "is-error");
  if (type === "success") {
    userAdminAuthStatus.classList.add("is-success");
  }
  if (type === "error") {
    userAdminAuthStatus.classList.add("is-error");
  }
}

function firebaseAdminAuthMessage(error) {
  const code = String(error?.code ?? "");
  const message = String(error?.message ?? "");

  if (code === "auth/unauthorized-domain") {
    return "Dominio non autorizzato in Firebase Auth. Aggiungi fairwater-admin.web.app e admin.fairwater.it in Authentication > Settings > Authorized domains.";
  }

  if (code === "auth/operation-not-allowed") {
    return "Provider Google non abilitato in Firebase Auth. Abilitalo in Authentication > Sign-in method.";
  }

  if (code === "auth/popup-blocked" || code === "auth/popup-closed-by-user") {
    return "Accesso Google interrotto dal browser. Riprova dal pulsante Google Firebase.";
  }

  if (message.toLowerCase().includes("requested action is invalid")) {
    return "Azione Google/Firebase non valida per questo dominio. Verifica che fairwater-admin.web.app o admin.fairwater.it siano nei domini autorizzati di Firebase Auth.";
  }

  return message || "Errore non riconosciuto durante l'accesso Firebase.";
}

function normalizeList(value) {
  return String(value ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function buildSocialLinks({ instagram = "", website = "" }) {
  const socialLinks = {};
  if (instagram.trim()) {
    socialLinks.instagram = instagram.trim();
  }
  if (website.trim()) {
    if (website.includes("facebook.com")) {
      socialLinks.facebook = website.trim();
    } else {
      socialLinks.website = website.trim();
    }
  }
  return socialLinks;
}

function buildGallery(seed) {
  return Array.from({ length: 4 }, (_, index) => {
    return `https://picsum.photos/seed/${seed}-${index + 1}/1200/900`;
  });
}

function buildDefaultSocialLinks(seed) {
  const slug = String(seed ?? "").replace(/-/g, "");
  const socialLinks = {
    instagram: `https://instagram.com/${slug}`,
    facebook: `https://facebook.com/${slug}`,
  };

  if (seed === "le-cinema-sant-anastasia") {
    socialLinks.website = "https://lecinema.it";
  }

  return socialLinks;
}

function fullName(user) {
  const first = String(user.firstName ?? "").trim();
  const last = String(user.lastName ?? "").trim();
  const display = String(user.displayName ?? "").trim();
  return display || `${first} ${last}`.trim() || user.email || "Utente";
}

function safeText(value) {
  return String(value ?? "").trim();
}

function renderEmptyRow(colspan, message) {
  return `<tr><td colspan="${colspan}" class="table-empty">${message}</td></tr>`;
}

function resetState() {
  state.users = [];
  state.bars = [];
  state.sponsors = [];
  renderUsers();
  renderBars();
  renderSponsors();
}

function stopDataSync() {
  for (const key of Object.keys(snapshotUnsubscribers)) {
    stopSnapshot(key);
  }
}

function stopSnapshot(stateKey) {
  const unsubscribe = snapshotUnsubscribers[stateKey];
  if (typeof unsubscribe === "function") {
    unsubscribe();
  }
  snapshotUnsubscribers[stateKey] = null;
}

async function checkAdminAccess(user, database = db) {
  if (!user?.uid) {
    return false;
  }

  try {
    const snapshot = await getDoc(doc(database, "users", user.uid));
    const data = snapshot.data() ?? {};
    const roles = Array.isArray(data.roles) ? data.roles : [];
    const isAdmin = roles.includes("admin");

    if (!snapshot.exists()) {
      appendStatus(
        `Account autenticato (${user.email}), ma manca il profilo users/${user.uid}.`,
        "error"
      );
      return false;
    }

    if (!isAdmin) {
      appendStatus(
        `Account autenticato (${user.email}), ma manca il ruolo admin nel profilo users/${user.uid}.`,
        "error"
      );
      return false;
    }

    return true;
  } catch (error) {
    appendStatus(`Errore controllo ruolo admin: ${error.message}`, "error");
    return false;
  }
}

function renderUsers() {
  if (usersCount) {
    usersCount.textContent = String(state.users.length);
  }

  if (!usersTableBody) {
    return;
  }

  if (!state.users.length) {
    usersTableBody.innerHTML = renderEmptyRow(
      5,
      "Nessun profilo utente presente."
    );
    return;
  }

  const rows = [...state.users]
    .sort((a, b) => fullName(a).localeCompare(fullName(b), "it"))
    .map((user) => {
      return `
        <tr>
          <td>${fullName(user)}</td>
          <td>${safeText(user.email) || "-"}</td>
          <td>${(user.roles ?? ["user"]).join(", ")}</td>
          <td>${safeText(user.status) || "-"}</td>
          <td>${safeText(user.residence) || "-"}</td>
        </tr>
      `;
    })
    .join("");

  usersTableBody.innerHTML = rows;
}

function renderBars() {
  if (barsCount) {
    barsCount.textContent = String(state.bars.length);
  }

  if (!refillTableBody) {
    return;
  }

  if (!state.bars.length) {
    refillTableBody.innerHTML = renderEmptyRow(
      5,
      "Nessun punto refill registrato."
    );
    return;
  }

  const rows = [...state.bars]
    .sort((a, b) => safeText(a.name).localeCompare(safeText(b.name), "it"))
    .map((bar) => {
      return `
        <tr>
          <td>${safeText(bar.name)}</td>
          <td>${safeText(bar.city)}</td>
          <td>${safeText(bar.address)}</td>
          <td>${bar.featured ? "Si" : "No"}</td>
          <td>
            <button class="table-action" type="button" data-edit-bar="${bar.id}">
              Modifica
            </button>
          </td>
        </tr>
      `;
    })
    .join("");

  refillTableBody.innerHTML = rows;
}

function renderSponsors() {
  if (sponsorsCount) {
    sponsorsCount.textContent = String(state.sponsors.length);
  }

  if (!sponsorsTableBody) {
    return;
  }

  if (!state.sponsors.length) {
    sponsorsTableBody.innerHTML = renderEmptyRow(5, "Nessuno sponsor registrato.");
    return;
  }

  const rows = [...state.sponsors]
    .sort((a, b) => safeText(a.name).localeCompare(safeText(b.name), "it"))
    .map((sponsor) => {
      return `
        <tr>
          <td>${safeText(sponsor.name)}</td>
          <td>${safeText(sponsor.category)}</td>
          <td>${safeText(sponsor.address)}</td>
          <td>${sponsor.featured ? "Si" : "No"}</td>
          <td>
            <button class="table-action" type="button" data-edit-sponsor="${sponsor.id}">
              Modifica
            </button>
          </td>
        </tr>
      `;
    })
    .join("");

  sponsorsTableBody.innerHTML = rows;
}

function fillRefillEditForm(bar) {
  if (!refillEditForm || !bar) {
    return;
  }

  refillEditForm.elements.id.value = bar.id;
  refillEditForm.elements.name.value = safeText(bar.name);
  refillEditForm.elements.city.value = safeText(bar.city);
  refillEditForm.elements.address.value = safeText(bar.address);
  refillEditForm.elements.latitude.value = String(bar.latitude ?? "");
  refillEditForm.elements.longitude.value = String(bar.longitude ?? "");
  refillEditForm.elements.refillInfo.value = safeText(bar.refillInfo);
  refillEditForm.elements.openInfo.value = safeText(bar.openInfo);
  refillEditForm.elements.services.value = (bar.services ?? []).join(", ");
  refillEditForm.elements.instagram.value = safeText(
    bar.socialLinks?.instagram ?? ""
  );
  refillEditForm.elements.website.value = safeText(
    bar.socialLinks?.facebook ?? bar.socialLinks?.website ?? ""
  );
  refillEditForm.elements.featured.checked = bar.featured === true;
  setView("refill");
  refillEditForm.scrollIntoView({ behavior: "smooth", block: "start" });
}

function fillSponsorEditForm(sponsor) {
  if (!sponsorEditForm || !sponsor) {
    return;
  }

  sponsorEditForm.elements.id.value = sponsor.id;
  sponsorEditForm.elements.name.value = safeText(sponsor.name);
  sponsorEditForm.elements.category.value = safeText(sponsor.category);
  sponsorEditForm.elements.address.value = safeText(sponsor.address);
  sponsorEditForm.elements.contribution.value = safeText(sponsor.contribution);
  sponsorEditForm.elements.thankYouMessage.value = safeText(
    sponsor.thankYouMessage
  );
  sponsorEditForm.elements.supports.value = (sponsor.supports ?? []).join(", ");
  sponsorEditForm.elements.instagram.value = safeText(
    sponsor.socialLinks?.instagram ?? ""
  );
  sponsorEditForm.elements.website.value = safeText(
    sponsor.socialLinks?.website ?? sponsor.socialLinks?.facebook ?? ""
  );
  sponsorEditForm.elements.featured.checked = sponsor.featured === true;
  setView("sponsors");
  sponsorEditForm.scrollIntoView({ behavior: "smooth", block: "start" });
}

async function handleUserCreate(event) {
  event.preventDefault();

  const adminUser = userAdminAuth.currentUser;
  if (!adminUser || !(await checkAdminAccess(adminUser, userAdminDb))) {
    setStatus(
      "La creazione utenti dal CRM richiede un accesso Firebase admin dedicato.",
      "error"
    );
    return;
  }

  const form = event.currentTarget;
  const formData = new FormData(form);
  const firstName = safeText(formData.get("firstName"));
  const lastName = safeText(formData.get("lastName"));
  const email = safeText(formData.get("email")).toLowerCase();
  const role = safeText(formData.get("role")) || "user";
  const status = safeText(formData.get("status")) || "active";
  const userId =
    safeText(email).replace(/[^a-z0-9]+/gi, "-") + "-" + Date.now().toString();

  try {
    await setDoc(doc(userAdminDb, "users", userId), {
      uid: userId,
      firstName,
      lastName,
      displayName: `${firstName} ${lastName}`.trim(),
      email,
      phone: safeText(formData.get("phone")),
      residence: safeText(formData.get("residence")),
      photoUrl: "",
      photoBase64: "",
      provider: "crm",
      roles: [role],
      accountType: role === "admin" ? "admin" : "user",
      status,
      managedRefillPointIds: [],
      managedSponsorIds: [],
      refillCount: 0,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    form.reset();
    setStatus("Profilo utente salvato in Firestore.", "success");
  } catch (error) {
    setStatus(`Errore salvataggio utente: ${error.message}`, "error");
  }
}

async function handleRefillCreate(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  const name = safeText(formData.get("name"));
  const seed = name.toLowerCase().replace(/[^a-z0-9]+/gi, "-");

  try {
    await addDoc(collection(db, "bars"), {
      name,
      city: safeText(formData.get("city")),
      address: safeText(formData.get("address")),
      latitude: Number(formData.get("latitude")),
      longitude: Number(formData.get("longitude")),
      refillInfo: safeText(formData.get("refillInfo")) || "Punto refill",
      openInfo: safeText(formData.get("openInfo")) || "Orari da confermare",
      services: normalizeList(formData.get("services")),
      socialLinks: buildSocialLinks({
        instagram: safeText(formData.get("instagram")),
        website: safeText(formData.get("website")),
      }),
      galleryImages: buildGallery(seed || "bar"),
      featured: formData.get("featured") === "on",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    form.reset();
    setStatus("Punto refill salvato. Sara visibile anche nell'app.", "success");
  } catch (error) {
    setStatus(`Errore salvataggio refill: ${error.message}`, "error");
  }
}

async function handleSponsorCreate(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);

  try {
    await addDoc(collection(db, "sponsors"), {
      name: safeText(formData.get("name")),
      category: safeText(formData.get("category")),
      address: safeText(formData.get("address")),
      contribution: safeText(formData.get("contribution")),
      thankYouMessage: safeText(formData.get("thankYouMessage")),
      supports: normalizeList(formData.get("supports")),
      socialLinks: buildSocialLinks({
        instagram: safeText(formData.get("instagram")),
        website: safeText(formData.get("website")),
      }),
      featured: formData.get("featured") === "on",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    form.reset();
    setStatus("Sponsor salvato. Sara visibile anche nell'app.", "success");
  } catch (error) {
    setStatus(`Errore salvataggio sponsor: ${error.message}`, "error");
  }
}

async function handleRefillUpdate(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  const id = safeText(formData.get("id"));

  if (!id) {
    setStatus("Seleziona prima un punto refill da modificare.", "error");
    return;
  }

  try {
    await updateDoc(doc(db, "bars", id), {
      name: safeText(formData.get("name")),
      city: safeText(formData.get("city")),
      address: safeText(formData.get("address")),
      latitude: Number(formData.get("latitude")),
      longitude: Number(formData.get("longitude")),
      refillInfo: safeText(formData.get("refillInfo")),
      openInfo: safeText(formData.get("openInfo")),
      services: normalizeList(formData.get("services")),
      socialLinks: buildSocialLinks({
        instagram: safeText(formData.get("instagram")),
        website: safeText(formData.get("website")),
      }),
      featured: formData.get("featured") === "on",
      updatedAt: serverTimestamp(),
    });

    setStatus("Punto refill aggiornato correttamente.", "success");
  } catch (error) {
    setStatus(`Errore aggiornamento refill: ${error.message}`, "error");
  }
}

async function handleSponsorUpdate(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const formData = new FormData(form);
  const id = safeText(formData.get("id"));

  if (!id) {
    setStatus("Seleziona prima uno sponsor da modificare.", "error");
    return;
  }

  try {
    await updateDoc(doc(db, "sponsors", id), {
      name: safeText(formData.get("name")),
      category: safeText(formData.get("category")),
      address: safeText(formData.get("address")),
      contribution: safeText(formData.get("contribution")),
      thankYouMessage: safeText(formData.get("thankYouMessage")),
      supports: normalizeList(formData.get("supports")),
      socialLinks: buildSocialLinks({
        instagram: safeText(formData.get("instagram")),
        website: safeText(formData.get("website")),
      }),
      featured: formData.get("featured") === "on",
      updatedAt: serverTimestamp(),
    });

    setStatus("Sponsor aggiornato correttamente.", "success");
  } catch (error) {
    setStatus(`Errore aggiornamento sponsor: ${error.message}`, "error");
  }
}

async function ensureAppSeedBars() {
  const snapshot = await getDocs(collection(db, "bars"));
  const existingDocs = new Map(
    snapshot.docs.map((entry) => [entry.id, entry.data()])
  );
  const batch = writeBatch(db);
  let writes = 0;

  for (const bar of appSeedBars) {
    const barRef = doc(db, "bars", bar.id);
    const existing = existingDocs.get(bar.id);

    if (!existing) {
      batch.set(barRef, {
        ...bar,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      writes += 1;
      continue;
    }

    const patch = {};
    if (!safeText(existing.openInfo) || existing.openInfo === "OSM") {
      patch.openInfo = bar.openInfo;
    }
    if (!Array.isArray(existing.services) || existing.services.length === 0) {
      patch.services = bar.services;
    }
    if (!existing.socialLinks || !Object.keys(existing.socialLinks).length) {
      patch.socialLinks = bar.socialLinks;
    }
    if (!Array.isArray(existing.galleryImages) || existing.galleryImages.length < 4) {
      patch.galleryImages = bar.galleryImages;
    }

    if (Object.keys(patch).length) {
      batch.set(barRef, {
        ...patch,
        updatedAt: serverTimestamp(),
      }, { merge: true });
      writes += 1;
    }
  }

  if (writes > 0) {
    await batch.commit();
  }
}

async function ensureAppSeedSponsors() {
  const snapshot = await getDocs(collection(db, "sponsors"));
  const existingDocs = new Map(
    snapshot.docs.map((entry) => [entry.id, entry.data()])
  );
  const batch = writeBatch(db);
  let writes = 0;

  for (const sponsor of appSeedSponsors) {
    const sponsorRef = doc(db, "sponsors", sponsor.id);
    const existing = existingDocs.get(sponsor.id);

    if (!existing) {
      batch.set(sponsorRef, {
        ...sponsor,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      writes += 1;
      continue;
    }

    const patch = {};
    for (const key of [
      "category",
      "address",
      "contribution",
      "thankYouMessage",
    ]) {
      if (!safeText(existing[key])) {
        patch[key] = sponsor[key];
      }
    }
    if (!Array.isArray(existing.supports) || existing.supports.length === 0) {
      patch.supports = sponsor.supports;
    }
    if (!existing.socialLinks || !Object.keys(existing.socialLinks).length) {
      patch.socialLinks = sponsor.socialLinks;
    }

    if (Object.keys(patch).length) {
      batch.set(sponsorRef, {
        ...patch,
        updatedAt: serverTimestamp(),
      }, { merge: true });
      writes += 1;
    }
  }

  if (writes > 0) {
    await batch.commit();
  }
}

function bindSnapshot(collectionName, stateKey, renderFn, database = db) {
  stopSnapshot(stateKey);
  const unsubscribe = onSnapshot(
    collection(database, collectionName),
    (snapshot) => {
      state[stateKey] = snapshot.docs.map((entry) => ({
        id: entry.id,
        ...entry.data(),
      }));
      renderFn();
      appendStatus(
        `${collectionName}: ${snapshot.docs.length} documenti sincronizzati.`,
        "success"
      );
    },
    (error) => {
      appendStatus(`Errore lettura ${collectionName}: ${error.message}`, "error");
    }
  );

  snapshotUnsubscribers[stateKey] = unsubscribe;
}

async function unlockUsersWithCurrentFirebaseUser(user, database = db) {
  if (!user || user.isAnonymous) {
    stopSnapshot("users");
    usersTableBody.innerHTML = renderEmptyRow(
      5,
      "Utenti non disponibili con il login CRM base: sblocca la sezione con un account Firebase admin."
    );
    return false;
  }

  const hasAdminAccess = await checkAdminAccess(user, database);
  if (!hasAdminAccess) {
    const email = user.email ?? "email non disponibile";
    const uid = user.uid ?? "uid non disponibile";
    stopSnapshot("users");
    usersTableBody.innerHTML = renderEmptyRow(
      5,
      "Accesso utenti bloccato: l'account Firebase non ha il ruolo admin."
    );
    setUserAdminStatus(
      `Account Firebase autenticato (${email}), ma senza ruolo admin nel profilo users/${uid}.`,
      "error"
    );
    return false;
  }

  bindSnapshot("users", "users", renderUsers, database);
  setUserAdminStatus(
    `Sezione utenti sbloccata con ${user.email ?? "account admin"}.`,
    "success"
  );
  return true;
}

async function unlockUsersWithSavedFirebaseAdmin() {
  const crmSessionActive =
    window.sessionStorage.getItem(LOGIN_STORAGE_KEY) === "ok";
  const adminUser = userAdminAuth.currentUser;

  if (!crmSessionActive || !adminUser) {
    return false;
  }

  return unlockUsersWithCurrentFirebaseUser(adminUser, userAdminDb);
}

async function startDataSync(user) {
  stopDataSync();
  unlockAdmin(user);
  appendStatus("Sincronizzazione dati CRM in corso...");

  if (user?.isAnonymous) {
    appendStatus(
      "Sessione Firebase anonima attiva: refill e sponsor sono collegati all'app. Gli utenti richiedono un accesso admin dedicato."
    );
  }

  try {
    await ensureAppSeedBars();
    appendStatus("Punti refill dell'app verificati su Firestore.", "success");
  } catch (error) {
    appendStatus(`Errore sincronizzazione punti refill: ${error.message}`, "error");
  }

  try {
    await ensureAppSeedSponsors();
    appendStatus("Sponsor dell'app verificati su Firestore.", "success");
  } catch (error) {
    appendStatus(`Errore sincronizzazione sponsor: ${error.message}`, "error");
  }

  bindSnapshot("bars", "bars", renderBars);
  bindSnapshot("sponsors", "sponsors", renderSponsors);
  if (!(await unlockUsersWithSavedFirebaseAdmin())) {
    await unlockUsersWithCurrentFirebaseUser(user);
  }
}

if (loginForm) {
  loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    const formData = new FormData(loginForm);
    const username = String(formData.get("username") ?? "").trim();
    const password = String(formData.get("password") ?? "");

    if (username !== LOGIN_USERNAME || password !== LOGIN_PASSWORD) {
      if (loginError) {
        loginError.textContent = "Credenziali non corrette.";
      }
      lockAdmin();
      return;
    }

    try {
      if (loginError) {
        loginError.textContent = "";
      }
      window.sessionStorage.setItem(LOGIN_STORAGE_KEY, "ok");
      unlockAdmin({ email: "FairWater" });
      appendStatus("Accesso CRM confermato. Sincronizzazione dati in corso...");
      await startDataSync({ email: "FairWater CRM", isAnonymous: true });
    } catch (error) {
      appendStatus(`Errore avvio CRM base: ${error.message}`, "error");
    }
  });
}

if (userAdminAuthForm) {
  userAdminAuthForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    const formData = new FormData(userAdminAuthForm);
    const email = String(formData.get("adminEmail") ?? "").trim();
    const password = String(formData.get("adminPassword") ?? "");

    if (!email || !password) {
      setUserAdminStatus("Inserisci email e password Firebase admin.", "error");
      return;
    }

    try {
      setUserAdminStatus("Verifica accesso Firebase admin in corso...");
      const credential = await signInWithEmailAndPassword(
        userAdminAuth,
        email,
        password
      );
      const unlocked = await unlockUsersWithCurrentFirebaseUser(
        credential.user,
        userAdminDb
      );
      if (unlocked) {
        appendStatus("Lista utenti sbloccata con accesso Firebase admin.", "success");
      }
    } catch (error) {
      setUserAdminStatus(`Errore accesso Firebase admin: ${error.message}`, "error");
    }
  });
}

if (userAdminGoogleButton) {
  userAdminGoogleButton.addEventListener("click", async () => {
    try {
      setUserAdminStatus("Apertura accesso Google Firebase...");
      const credential = await signInWithPopup(
        userAdminAuth,
        googleAdminProvider
      );
      const unlocked = await unlockUsersWithCurrentFirebaseUser(
        credential.user,
        userAdminDb
      );
      if (unlocked) {
        setView("users");
        appendStatus("Lista utenti sbloccata con account Google admin.", "success");
      }
    } catch (error) {
      setUserAdminStatus(
        `Errore accesso Google Firebase: ${firebaseAdminAuthMessage(error)}`,
        "error"
      );
    }
  });
}

if (logoutButton) {
  logoutButton.addEventListener("click", async () => {
    window.sessionStorage.removeItem(LOGIN_STORAGE_KEY);
    await signOut(userAdminAuth).catch(() => {});
    await signOut(auth);
  });
}

for (const link of links) {
  link.addEventListener("click", () => {
    const { view } = link.dataset;
    if (view) {
      setView(view);
    }
  });
}

for (const button of document.querySelectorAll("[data-target]")) {
  button.addEventListener("click", () => {
    const targetId = button.getAttribute("data-target");
    const target = targetId ? document.getElementById(targetId) : null;
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  });
}

if (dashboardUserForm) {
  dashboardUserForm.addEventListener("submit", handleUserCreate);
}

if (dashboardRefillForm) {
  dashboardRefillForm.addEventListener("submit", handleRefillCreate);
}

if (dashboardSponsorForm) {
  dashboardSponsorForm.addEventListener("submit", handleSponsorCreate);
}

if (refillEditForm) {
  refillEditForm.addEventListener("submit", handleRefillUpdate);
}

if (sponsorEditForm) {
  sponsorEditForm.addEventListener("submit", handleSponsorUpdate);
}

document.addEventListener("click", (event) => {
  const editBarId = event.target?.getAttribute?.("data-edit-bar");
  if (editBarId) {
    const bar = state.bars.find((entry) => entry.id === editBarId);
    fillRefillEditForm(bar);
  }

  const editSponsorId = event.target?.getAttribute?.("data-edit-sponsor");
  if (editSponsorId) {
    const sponsor = state.sponsors.find((entry) => entry.id === editSponsorId);
    fillSponsorEditForm(sponsor);
  }
});

setView("dashboard");

onAuthStateChanged(auth, (user) => {
  const crmSessionActive =
    window.sessionStorage.getItem(LOGIN_STORAGE_KEY) === "ok";

  if (crmSessionActive) {
    unlockAdmin({ email: "FairWater" });
    appendStatus("Ripristino sessione CRM. Sincronizzazione dati in corso...");
    startDataSync({ email: "FairWater CRM", isAnonymous: true });
    return;
  }

  lockAdmin({ clearSession: false });
  setStatus("Sessione CRM chiusa.");
});

onAuthStateChanged(userAdminAuth, (user) => {
  if (!user) {
    return;
  }

  unlockUsersWithSavedFirebaseAdmin();
});
