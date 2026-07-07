# Sincronizzazione Real-Time Admin Panel - FairWater

## Come Funziona la Sincronizzazione

Il sistema utilizza **Cloud Firestore Streams** per una sincronizzazione istantanea tra il CRM e l'app consumer.

### Flusso dei Dati

```
Admin Panel (web)
    ↓
[Modifica/Salva Bar]
    ↓
Cloud Firestore (database centrale)
    ↓ (Stream listener)
   / \
  /   \
App Consumer    Home Page
(mobile)        (web)
(aggiornamento  (aggiornamento
automatico)     automatico)
```

## Implementazione Tecnica

### 1. BarService (lib/services/bar_service.dart)

```dart
Stream<List<BarSpot>> watchBars() {
  return _collection.snapshots().map(
    (snapshot) => snapshot.docs.map(BarSpot.fromDoc).toList(),
  );
}
```

- Crea uno Stream real-time da Firestore
- Ascolta tutti i cambiamenti alla collection 'bars'
- Ritorna i dati aggiornati non appena Firestore riceve cambiamenti

### 2. Home Page (lib/screens/home_page.dart)

```dart
StreamBuilder<List<BarSpot>>(
  stream: _barService.watchBars(),
  builder: (context, snapshot) {
    // Rebuild automatico quando i dati cambiano
  },
)
```

- `StreamBuilder` rinasconde il widget quando arrivano nuovi dati
- Nessun polling, nessun refresh manuale necessario

### 3. Admin Dashboard (lib/screens/admin_dashboard_page.dart)

```dart
// Salvataggio nel CRM
await FirebaseFirestore.instance
    .collection('bars')
    .doc(bar.id)
    .update(bar.toMap());
```

- Scrive nel Firestore gli aggiornamenti
- Firestore notifica automaticamente tutti i listener
- L'app consumer riceve l'aggiornamento istantaneamente

## Testing della Sincronizzazione

### Scenario 1: Aggiungi un Nuovo Bar

1. Apri il panel admin: `https://admin.fairwater.it/admin-login`
2. Login con credenziali admin
3. Clicca il pulsante "+" per aggiungere un locale
4. Compila il form e salva
5. **Risultato**: Il bar appare istantaneamente nella mappa app consumer

### Scenario 2: Modifica un Bar Esistente

1. Nel panel admin, clicca "Modifica" su un bar
2. Cambia un dettaglio (es. nome, orari)
3. Salva le modifiche
4. **Risultato**: La modifica è visibile istantaneamente nell'app

### Scenario 3: Elimina un Bar

1. Nel panel admin, clicca "Elimina" su un bar
2. Conferma l'eliminazione
3. **Risultato**: Il bar scompare istantaneamente dalla mappa

## Vantaggi della Sincronizzazione Real-Time

✅ **Istantanea**: Nessun ritardo tra salvataggio e visualizzazione  
✅ **Automatica**: L'app si aggiorna senza azioni manuali  
✅ **Bidirezionale**: Funziona tra admin panel e app consumer  
✅ **Efficiente**: Solo i delta cambiano, non tutto il dataset  
✅ **Offline-aware**: Firestore queue le operazioni offline  

## Architettura Firestore

### Collection: bars

```json
{
  "id": "caffe-del-duomo",
  "name": "Caffè del Duomo",
  "address": "Piazza Municipio 18",
  "city": "Terracina",
  "latitude": 41.2916360,
  "longitude": 13.2485294,
  "refillInfo": "Refill verificato",
  "openInfo": "Lun-Dom 07:00-23:30",
  "services": ["Acqua fresca", "Bottle refill"],
  "socialLinks": {
    "instagram": "https://...",
    "facebook": "https://..."
  },
  "galleryImages": ["url1", "url2", ...],
  "featured": true,
  "updatedAt": "2026-07-07T12:00:00Z"
}
```

## Firestore Security Rules

Per garantire che solo gli admin possano modificare i bar, le security rules devono essere configurate:

```
match /bars/{document=**} {
  allow read: if request.auth != null;
  allow create, update, delete: if 
    request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['admin', 'refill_manager']);
}
```

## Troubleshooting

### I dati non si aggiornano
- Verificare la connessione internet
- Controllare le Firestore security rules
- Verificare che l'utente abbia i ruoli admin in Firestore

### Il login admin non funziona
- Assicurarsi che l'utente ha il ruolo 'admin' o 'super_admin' in Firestore
- Verificare l'email e password in Firebase Auth

### La app non carica i bar
- Verificare che la collection 'bars' esiste in Firestore
- Controllare le security rules permettono il read
- Verificare il link a Firestore in firebase_options.dart

## Prossimi Passi

1. ✅ Sincronizzazione real-time (COMPLETATA)
2. ⬜ Aggiungere più campi editabili nel form admin
3. ⬜ Bulk upload bar da CSV
4. ⬜ Gestione immagini galleriaS (upload da admin)
5. ⬜ Dashboard analytics (bar più visitati, ecc.)
