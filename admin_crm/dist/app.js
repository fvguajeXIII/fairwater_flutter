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
  getFirestore,
  onSnapshot,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";
import {
  getFunctions,
  httpsCallable,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-functions.js";

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
const userAdminFunctions = getFunctions(userAdminApp, "europe-west1");

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

function fullName(user) {
  const first = String(user.firstName ?? "").trim();
  const last = String(user.lastName ?? "").trim();
  const display = String(user.displayName ?? "").trim();
  return display || `${first} ${last}`.trim() || user.email || "Utente";
}

function safeText(value) {
  return String(value ?? "").trim();
}

function setAddressResults(container, content) {
  if (!container) {
    return;
  }

  container.replaceChildren(...content);
  container.classList.toggle("is-visible", content.length > 0);
}

function addressMessage(message) {
  const node = document.createElement("div");
  node.className = "address-result-message";
  node.textContent = message;
  return node;
}

function firstAddressValue(source, keys) {
  for (const key of keys) {
    const value = safeText(source?.[key]);
    if (value) {
      return value;
    }
  }
  return "";
}

function buildPhotonLabel(properties, city) {
  const name = safeText(properties.name);
  const street = safeText(properties.street);
  const houseNumber = safeText(properties.housenumber);
  const postcode = safeText(properties.postcode);
  const country = safeText(properties.country);
  const streetLine = [street, houseNumber].filter(Boolean).join(" ");
  return [
    streetLine || name,
    postcode,
    city,
    country,
  ].filter(Boolean).join(", ");
}

function parseNominatimAddress(item) {
  const latitude = Number(item.lat);
  const longitude = Number(item.lon);
  const address = item.address ?? {};
  const label = safeText(item.display_name);
  const city = firstAddressValue(address, [
    "city",
    "town",
    "village",
    "municipality",
    "county",
  ]);

  if (!label || Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return null;
  }

  return { label, city, latitude, longitude };
}

function parsePhotonAddress(feature) {
  const properties = feature.properties ?? {};
  const coordinates = feature.geometry?.coordinates ?? [];
  const longitude = Number(coordinates[0]);
  const latitude = Number(coordinates[1]);
  const city = firstAddressValue(properties, [
    "city",
    "town",
    "village",
    "municipality",
    "county",
    "state",
  ]);
  const label = buildPhotonLabel(properties, city);

  if (!label || Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return null;
  }

  return { label, city, latitude, longitude };
}

async function searchAddressWithNominatim(query) {
  const params = new URLSearchParams({
    q: query,
    format: "jsonv2",
    addressdetails: "1",
    limit: "5",
    countrycodes: "it",
    "accept-language": "it",
  });
  const response = await fetch(
    `https://nominatim.openstreetmap.org/search?${params.toString()}`,
    {
      headers: {
        Accept: "application/json",
        "Accept-Language": "it",
      },
    }
  );

  if (!response.ok) {
    throw new Error("Nominatim non disponibile");
  }

  const data = await response.json();
  return data.map(parseNominatimAddress).filter(Boolean);
}

async function searchAddressWithPhoton(query) {
  const params = new URLSearchParams({
    q: query,
    limit: "5",
    lang: "it",
  });
  const response = await fetch(
    `https://photon.komoot.io/api/?${params.toString()}`,
    {
      headers: {
        Accept: "application/json",
        "Accept-Language": "it",
      },
    }
  );

  if (!response.ok) {
    throw new Error("Photon non disponibile");
  }

  const data = await response.json();
  return (data.features ?? []).map(parsePhotonAddress).filter(Boolean);
}

async function searchAddress(query) {
  let results = [];

  try {
    results = await searchAddressWithNominatim(query);
  } catch (error) {
    console.info("[FairWater CRM] Nominatim non disponibile, provo Photon.");
  }

  if (results.length === 0) {
    results = await searchAddressWithPhoton(query);
  }

  return results;
}

function applyAddressResult(form, result) {
  form.elements.address.value = result.label;
  form.elements.city.value = result.city;
  form.elements.latitude.value = result.latitude.toFixed(7);
  form.elements.longitude.value = result.longitude.toFixed(7);
  form.dataset.selectedAddress = result.label;
}

function setupAddressLookup(form) {
  if (!form?.elements.address) {
    return;
  }

  const addressInput = form.elements.address;
  const searchButton = form.querySelector(".address-search-button");
  const resultsContainer = form.querySelector("[data-address-results]");
  let debounce = null;
  let lastQuery = "";

  const clearCoordinates = () => {
    if (form.dataset.selectedAddress !== addressInput.value.trim()) {
      delete form.dataset.selectedAddress;
      form.elements.latitude.value = "";
      form.elements.longitude.value = "";
    }
  };

  const runSearch = async () => {
    const query = addressInput.value.trim();
    window.clearTimeout(debounce);

    if (query.length < 4) {
      setAddressResults(resultsContainer, [
        addressMessage("Inserisci almeno 4 caratteri."),
      ]);
      return;
    }

    lastQuery = query;
    searchButton.disabled = true;
    setAddressResults(resultsContainer, [addressMessage("Ricerca in corso...")]);

    try {
      const results = await searchAddress(query);
      if (lastQuery !== query) {
        return;
      }

      if (results.length === 0) {
        setAddressResults(resultsContainer, [
          addressMessage("Nessun indirizzo trovato."),
        ]);
        return;
      }

      const buttons = results.map((result) => {
        const button = document.createElement("button");
        const title = document.createElement("span");
        const meta = document.createElement("span");

        button.type = "button";
        button.className = "address-result-button";
        title.className = "address-result-title";
        meta.className = "address-result-meta";
        title.textContent = result.label;
        meta.textContent = `${result.latitude.toFixed(6)}, ${result.longitude.toFixed(6)}`;
        button.append(title, meta);
        button.addEventListener("click", () => {
          applyAddressResult(form, result);
          setAddressResults(resultsContainer, []);
        });
        return button;
      });

      setAddressResults(resultsContainer, buttons);
    } catch (error) {
      setAddressResults(resultsContainer, [
        addressMessage("Impossibile cercare l'indirizzo ora."),
      ]);
    } finally {
      searchButton.disabled = false;
    }
  };

  addressInput.addEventListener("input", () => {
    clearCoordinates();
    window.clearTimeout(debounce);
    debounce = window.setTimeout(runSearch, 450);
  });
  addressInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      runSearch();
    }
  });
  searchButton?.addEventListener("click", runSearch);
  form.addEventListener("reset", () => {
    window.setTimeout(() => {
      delete form.dataset.selectedAddress;
      setAddressResults(resultsContainer, []);
    });
  });
}

function assertAddressSelected(form) {
  const address = safeText(form.elements.address.value);
  const latitude = Number(form.elements.latitude.value);
  const longitude = Number(form.elements.longitude.value);

  if (
    !address ||
    form.dataset.selectedAddress !== address ||
    Number.isNaN(latitude) ||
    Number.isNaN(longitude)
  ) {
    throw new Error("Seleziona un indirizzo dalla lista dei risultati.");
  }
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
  refillEditForm.dataset.selectedAddress = safeText(bar.address);
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
  const role = safeText(formData.get("role")) || "customer";
  const status = safeText(formData.get("status")) || "active";

  try {
    const createManagedUser = httpsCallable(
      userAdminFunctions,
      "createManagedUser"
    );
    await createManagedUser({
      firstName,
      lastName,
      email,
      password: String(formData.get("password") || ""),
      phone: safeText(formData.get("phone")),
      residence: safeText(formData.get("residence")),
      role,
      status,
    });

    form.reset();
    setStatus("Account creato in Firebase Auth e profilo salvato.", "success");
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
    assertAddressSelected(form);

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
    assertAddressSelected(form);

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

  // Firestore is the only source of truth. Loading the CRM must never recreate
  // deleted demo records; the live listeners below mirror every CRUD change.
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
  setupAddressLookup(dashboardRefillForm);
  dashboardRefillForm.addEventListener("submit", handleRefillCreate);
}

if (dashboardSponsorForm) {
  dashboardSponsorForm.addEventListener("submit", handleSponsorCreate);
}

if (refillEditForm) {
  setupAddressLookup(refillEditForm);
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
