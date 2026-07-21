const {initializeApp} = require("firebase-admin/app");
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
