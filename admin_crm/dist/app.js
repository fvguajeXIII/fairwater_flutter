import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  addDoc,
  collection,
  doc,
  getFirestore,
  onSnapshot,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

const LOGIN_USERNAME = "FairWater";
const LOGIN_PASSWORD = "FairWater2026!";
const LOGIN_STORAGE_KEY = "fairwater-admin-auth";

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
const db = getFirestore(firebaseApp);

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

const links = Array.from(document.querySelectorAll(".nav-link"));
const panels = Array.from(document.querySelectorAll(".view"));
const titleNode = document.getElementById("view-title");
const loginShell = document.getElementById("login-shell");
const loginForm = document.getElementById("login-form");
const loginError = document.getElementById("login-error");
const logoutButton = document.getElementById("logout-button");
const dataStatus = document.getElementById("data-status");

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

function unlockAdmin() {
  if (loginShell) {
    loginShell.classList.add("is-hidden");
  }
  window.sessionStorage.setItem(LOGIN_STORAGE_KEY, "ok");
}

function lockAdmin() {
  if (loginShell) {
    loginShell.classList.remove("is-hidden");
  }
  window.sessionStorage.removeItem(LOGIN_STORAGE_KEY);
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

function renderEmptyRow(colspan, message) {
  return `<tr><td colspan="${colspan}" class="table-empty">${message}</td></tr>`;
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
    await setDoc(doc(db, "users", userId), {
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

function bindSnapshot(collectionName, stateKey, renderFn) {
  onSnapshot(
    collection(db, collectionName),
    (snapshot) => {
      state[stateKey] = snapshot.docs.map((entry) => ({
        id: entry.id,
        ...entry.data(),
      }));
      renderFn();
      setStatus("Dati sincronizzati con Firestore.", "success");
    },
    (error) => {
      setStatus(`Errore lettura ${collectionName}: ${error.message}`, "error");
    }
  );
}

if (loginForm) {
  loginForm.addEventListener("submit", (event) => {
    event.preventDefault();

    const formData = new FormData(loginForm);
    const username = String(formData.get("username") ?? "").trim();
    const password = String(formData.get("password") ?? "");

    if (username === LOGIN_USERNAME && password === LOGIN_PASSWORD) {
      if (loginError) {
        loginError.textContent = "";
      }
      unlockAdmin();
      return;
    }

    if (loginError) {
      loginError.textContent = "Credenziali non corrette.";
    }
    lockAdmin();
  });
}

if (logoutButton) {
  logoutButton.addEventListener("click", () => {
    lockAdmin();
    setStatus("Sessione CRM chiusa.");
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

if (window.sessionStorage.getItem(LOGIN_STORAGE_KEY) === "ok") {
  unlockAdmin();
} else {
  lockAdmin();
}

setView("dashboard");
bindSnapshot("users", "users", renderUsers);
bindSnapshot("bars", "bars", renderBars);
bindSnapshot("sponsors", "sponsors", renderSponsors);
