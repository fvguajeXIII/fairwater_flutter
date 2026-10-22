const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

initializeApp();

const geoapifyApiKey = defineSecret("GEOAPIFY_API_KEY");
const region = "europe-west1";
const adminRoles = new Set([
  "super_admin",
  "admin",
  "refill_manager",
  "sponsor_manager",
]);

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Accesso richiesto.");
  }

  const user = await getFirestore().collection("users")
      .doc(request.auth.uid).get();
  const roles = user.exists && Array.isArray(user.data().roles) ?
    user.data().roles : [];
  if (!roles.some((role) => adminRoles.has(role))) {
    throw new HttpsError("permission-denied", "Permessi admin richiesti.");
  }
}

async function geoapifyRequest(path, parameters) {
  const url = new URL(`https://api.geoapify.com${path}`);
  for (const [key, value] of Object.entries(parameters)) {
    if (value !== undefined && value !== null && value !== "") {
      url.searchParams.set(key, String(value));
    }
  }
  url.searchParams.set("apiKey", geoapifyApiKey.value());

  const response = await fetch(url);

  if (!response.ok) {
    console.error("Geoapify error", response.status,
        await response.text());
    throw new HttpsError("internal", "Servizio indirizzi non disponibile.");
  }
  return response.json();
}

exports.autocompleteAddress = onCall(
    {region, secrets: [geoapifyApiKey]},
    async (request) => {
      await requireAdmin(request);
      const query = String(request.data?.query || "").trim();
      const sessionToken = String(request.data?.sessionToken || "").trim();
      if (query.length < 4 || sessionToken.length < 8) {
        throw new HttpsError("invalid-argument", "Ricerca non valida.");
      }

      const result = await geoapifyRequest("/v1/geocode/autocomplete", {
        text: query,
        format: "json",
        lang: "it",
        limit: 8,
        filter: "countrycode:it",
        bias: "proximity:13.35,41.30",
      });

      return {
        suggestions: (result.results || [])
            .map((place) => ({
              placeId: place.place_id,
              label: place.formatted || "",
              mainText: place.address_line1 || place.name || "",
              secondaryText: place.address_line2 || "",
            }))
            .filter((place) => place.placeId && place.label),
      };
    });

exports.getAddressDetails = onCall(
    {region, secrets: [geoapifyApiKey]},
    async (request) => {
      await requireAdmin(request);
      const placeId = String(request.data?.placeId || "").trim();
      const sessionToken = String(request.data?.sessionToken || "").trim();
      if (!placeId || sessionToken.length < 8) {
        throw new HttpsError("invalid-argument", "Luogo non valido.");
      }

      const result = await geoapifyRequest("/v2/place-details", {
        id: placeId,
        features: "details",
        lang: "it",
      });
      const feature = result.features?.[0];
      const place = feature?.properties || {};
      const coordinates = feature?.geometry?.coordinates || [];
      const latitude = place.lat ?? coordinates[1];
      const longitude = place.lon ?? coordinates[0];
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
        throw new HttpsError("not-found", "Coordinate del luogo non trovate.");
      }

      return {
        placeId: place.place_id || placeId,
        formattedAddress: place.formatted || "",
        streetNumber: place.housenumber || "",
        route: place.street || "",
        city: place.city || place.town || place.village || place.county || "",
        postalCode: place.postcode || "",
        latitude,
        longitude,
      };
    });

exports.recordCustomerRefill = onCall({region}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Accesso richiesto.");
  }

  const db = getFirestore();
  const refillerRef = db.collection("users").doc(request.auth.uid);
  const rawPayload = String(request.data?.qrPayload || "").trim();
  const match = /^fairwater:\/\/customer\/([A-Za-z0-9_-]{20,128})$/.exec(rawPayload);
  if (!match) {
    throw new HttpsError("invalid-argument", "QR Customer non valido.");
  }

  const customerUid = match[1];
  if (customerUid === request.auth.uid) {
    throw new HttpsError("failed-precondition", "Non puoi registrare un refill a te stesso.");
  }
  const customerRef = db.collection("users").doc(customerUid);
  const eventId = db.collection("_ids").doc().id;
  const customerEventRef = customerRef.collection("refill_events").doc(eventId);
  const refillerEventRef = refillerRef.collection("refill_events").doc(eventId);

  return db.runTransaction(async (transaction) => {
    const [refillerSnapshot, customerSnapshot] = await Promise.all([
      transaction.get(refillerRef),
      transaction.get(customerRef),
    ]);
    if (!refillerSnapshot.exists || !customerSnapshot.exists) {
      throw new HttpsError("not-found", "Customer non trovato.");
    }

    const refiller = refillerSnapshot.data();
    const roles = Array.isArray(refiller.roles) ? refiller.roles : [];
    if (!roles.includes("refill_manager") && refiller.accountType !== "refill_point") {
      throw new HttpsError("permission-denied", "Permessi Refiller richiesti.");
    }
    if (refiller.status !== "active") {
      throw new HttpsError("permission-denied", "Account Refiller non attivo.");
    }

    const customer = customerSnapshot.data();
    const customerRoles = Array.isArray(customer.roles) ? customer.roles : [];
    if (customer.status !== "active" ||
        (!customerRoles.includes("customer") && !customerRoles.includes("user"))) {
      throw new HttpsError("failed-precondition", "Account Customer non attivo.");
    }

    const lastRefillAt = customer.lastRefillAt?.toMillis?.() || 0;
    const lastRefillerUid = customer.lastRefillerUid || "";
    if (lastRefillerUid === request.auth.uid && Date.now() - lastRefillAt < 30000) {
      throw new HttpsError("already-exists", "Questo refill e gia stato registrato.");
    }

    const customerCount = Number(customer.refillCount || 0) + 1;
    const refillerCount = Number(refiller.refillCount || 0) + 1;
    const now = new Date();
    transaction.update(customerRef, {
      refillCount: customerCount,
      lastRefillAt: now,
      lastRefillerUid: request.auth.uid,
      updatedAt: now,
    });
    transaction.update(refillerRef, {
      refillCount: refillerCount,
      lastRefillAt: now,
      updatedAt: now,
    });
    const event = {
      customerUid,
      refillerUid: request.auth.uid,
      source: "customer-qr",
      createdAt: now,
    };
    transaction.create(customerEventRef, event);
    transaction.create(refillerEventRef, event);

    return {
      customerName: customer.displayName || customer.firstName || "Customer",
      customerRefillCount: customerCount,
      refillerRefillCount: refillerCount,
    };
  });
});

exports.createManagedUser = onCall({region}, async (request) => {
  await requireAdmin(request);
  const role = String(request.data?.role || "customer").trim();
  const allowedRoles = new Set([
    "customer", "refill_manager", "sponsor_manager", "admin", "super_admin",
  ]);
  if (!allowedRoles.has(role)) {
    throw new HttpsError("invalid-argument", "Ruolo non valido.");
  }
  if (["admin", "super_admin"].includes(role)) {
    const caller = await getFirestore().collection("users")
        .doc(request.auth.uid).get();
    const callerRoles = caller.exists && Array.isArray(caller.data().roles) ?
      caller.data().roles : [];
    if (!callerRoles.includes("super_admin")) {
      throw new HttpsError("permission-denied", "Solo i Super Admin possono assegnare ruoli admin.");
    }
  }

  const email = String(request.data?.email || "").trim().toLowerCase();
  const password = String(request.data?.password || "");
  const firstName = String(request.data?.firstName || "").trim();
  const lastName = String(request.data?.lastName || "").trim();
  if (!email || password.length < 8 || !firstName || !lastName) {
    throw new HttpsError("invalid-argument", "Nome, cognome, email e password valida sono richiesti.");
  }

  let authUser;
  try {
    authUser = await getAuth().createUser({
      email,
      password,
      displayName: `${firstName} ${lastName}`.trim(),
      disabled: request.data?.status === "suspended",
    });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Questa email e gia registrata.");
    }
    throw new HttpsError("internal", "Creazione account non riuscita.");
  }

  const accountType = role === "refill_manager" ? "refill_point" :
    role === "sponsor_manager" ? "sponsor" : "customer";
  try {
    await getFirestore().collection("users").doc(authUser.uid).set({
      uid: authUser.uid,
      firstName,
      lastName,
      displayName: `${firstName} ${lastName}`.trim(),
      email,
      phone: String(request.data?.phone || "").trim(),
      residence: String(request.data?.residence || "").trim(),
      photoUrl: "",
      photoBase64: "",
      provider: "crm",
      roles: [role],
      accountType,
      status: String(request.data?.status || "active"),
      managedRefillPointIds: [],
      managedSponsorIds: [],
      refillCount: 0,
      bottleOwnerSince: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  } catch (error) {
    await getAuth().deleteUser(authUser.uid);
    throw new HttpsError("internal", "Profilo non creato; account annullato.");
  }
  return {uid: authUser.uid, email, role, accountType};
});
