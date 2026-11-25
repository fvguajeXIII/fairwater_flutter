// Aggiorna su Firestore i dati di Bar Rosso Blu e degli sponsor (novembre 2026).
//
// Prima esegue una prova: mostra i valori attuali e quelli nuovi senza scrivere nulla.
// Per scrivere davvero aggiungi --applica.
//
//   cd functions
//   gcloud auth application-default login      (una volta sola, con l'account admin del progetto)
//   node scripts/aggiorna-dati-novembre-2026.js
//   node scripts/aggiorna-dati-novembre-2026.js --applica
//
// I link social vengono aggiunti senza cancellare quelli già presenti.

const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp({credential: applicationDefault(), projectId: "fairwater-app"});
const db = getFirestore();
const applica = process.argv.includes("--applica");

const ORARI_ROSSO_BLU =
  "Lun e mer–sab 6:30–21:00 · mar 12:00–21:00 · dom 6:30–13:00 e 14:30–21:00";
const FACEBOOK_ROSSO_BLU = "https://www.facebook.com/p/Bar-Rosso-Blu-100063898965619/";

const modifiche = [
  {
    percorso: "bars/cgh9S1JdxRdTouc5l4cj",
    descrizione: "Bar Rosso Blu: orari, servizi, Facebook",
    dati: {
      openInfo: ORARI_ROSSO_BLU,
      services: FieldValue.arrayUnion("SuperEnalotto", "Mooney", "Amazon"),
      "socialLinks.facebook": FACEBOOK_ROSSO_BLU,
    },
  },
  {
    percorso: "sponsors/barrossoblu",
    descrizione: "Sponsor Bar Rosso Blu: Facebook",
    dati: {"socialLinks.facebook": FACEBOOK_ROSSO_BLU},
  },
  {
    percorso: "sponsors/davidemanna",
    descrizione: "Sponsor Davide Manna: nome senza Photographer, Instagram e sito",
    dati: {
      name: "Davide Manna",
      "socialLinks.instagram": "https://www.instagram.com/davidemannaph_/",
      "socialLinks.website": "https://davidemanna.myportfolio.com",
    },
  },
  {
    percorso: "sponsors/meravigliafondi",
    descrizione: "Sponsor Meraviglia Fondi: sito della sede di Fondi",
    dati: {"socialLinks.website": "https://partner.meraviglialab.com/fondi/"},
  },
  // Imperium: profilo Instagram da verificare prima di attivarlo.
  // {
  //   percorso: "sponsors/imperium",
  //   descrizione: "Sponsor Imperium: Instagram",
  //   dati: {"socialLinks.instagram": "https://www.instagram.com/imperium_produzioni/"},
  // },
];

async function main() {
  console.log(applica ? "Scrittura su Firestore\n" : "Prova: nessuna scrittura (aggiungi --applica per scrivere)\n");
  for (const {percorso, descrizione, dati} of modifiche) {
    const ref = db.doc(percorso);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`SALTATO  ${percorso}: il documento non esiste`);
      continue;
    }
    const attuale = snap.data();
    console.log(`${descrizione} (${percorso})`);
    for (const [campo, valore] of Object.entries(dati)) {
      const [radice, figlio] = campo.split(".");
      const prima = figlio ? (attuale[radice] || {})[figlio] : attuale[radice];
      const dopo = valore instanceof FieldValue ? "aggiunge SuperEnalotto, Mooney, Amazon" : valore;
      console.log(`  ${campo}: ${JSON.stringify(prima ?? null)} -> ${JSON.stringify(dopo)}`);
    }
    if (applica) {
      await ref.update({...dati, updatedAt: FieldValue.serverTimestamp()});
      console.log("  salvato");
    }
    console.log("");
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
