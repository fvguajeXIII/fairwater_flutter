# FairWater CRM Structure

## Obiettivo

Il CRM web sara il centro di gestione di:

- utenti registrati
- punti refill
- sponsor
- amministratori
- visibilita e stato dei contenuti mostrati nell'app

L'app mobile e web pubblica dovranno limitarsi a leggere i dati pubblicati e a mostrare viste diverse in base al ruolo dell'utente autenticato.

## Principi guida

- Un solo backend condiviso: `Firebase Auth` + `Cloud Firestore`
- Il CRM gestisce ruoli, anagrafiche, relazioni e pubblicazione
- L'app mostra solo cio che e attivo e pubblicato
- I permessi forti stanno nelle `Firestore Rules`, non solo nella UI
- I ruoli sono cumulabili: un utente puo essere `user` e anche `sponsor_manager` oppure `refill_manager`

## Collezioni consigliate

### `users/{uid}`

Documento profilo e controllo accessi.

Campi consigliati:

```json
{
  "uid": "auth uid",
  "email": "user@example.com",
  "firstName": "Mario",
  "lastName": "Rossi",
  "displayName": "Mario Rossi",
  "phone": "+39...",
  "residence": "Fondi",
  "photoUrl": "",
  "photoBase64": "",
  "provider": "password",
  "roles": ["user"],
  "accountType": "user",
  "status": "active",
  "managedRefillPointIds": [],
  "managedSponsorIds": [],
  "lastLoginAt": null,
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}
```

Note:

- `roles` supporta permessi cumulativi
- `accountType` serve per decidere la vista primaria dell'app
- `status` consigliati: `pending`, `active`, `suspended`, `archived`

### `refill_points/{refillPointId}`

Gestione dei locali o punti refill.

Campi consigliati:

```json
{
  "name": "Caffe del Duomo",
  "slug": "caffe-del-duomo",
  "status": "published",
  "visibility": "public",
  "address": "Piazza Municipio 18",
  "city": "Terracina",
  "latitude": 41.291636,
  "longitude": 13.2485294,
  "refillInfo": "Refill verificato",
  "openInfo": "Lun-Dom 07:00-23:30",
  "services": ["Acqua fresca", "Bottle refill"],
  "socialLinks": {
    "instagram": "https://instagram.com/...",
    "website": "https://..."
  },
  "galleryImages": [],
  "featured": true,
  "managerUserIds": ["uid-1"],
  "sponsorIds": ["sponsor-1"],
  "createdBy": "admin uid",
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp",
  "publishedAt": "server timestamp"
}
```

Status consigliati:

- `draft`
- `review`
- `published`
- `archived`

### `sponsors/{sponsorId}`

Gestione sponsor e soggetti commerciali.

Campi consigliati:

```json
{
  "name": "Emporio del Corso",
  "slug": "emporio-del-corso",
  "status": "published",
  "visibility": "public",
  "category": "Market di quartiere",
  "address": "Corso Italia 18, Fondi",
  "description": "Sponsor territoriale",
  "contribution": "Supporto logistico e materiali",
  "thankYouMessage": "Grazie per il sostegno",
  "supports": ["Eventi", "Materiali"],
  "socialLinks": {
    "instagram": "https://instagram.com/...",
    "website": "https://..."
  },
  "logoUrl": "",
  "galleryImages": [],
  "featured": true,
  "managerUserIds": ["uid-2"],
  "linkedRefillPointIds": ["refill-1"],
  "revenueEuro": 0,
  "createdBy": "admin uid",
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp",
  "publishedAt": "server timestamp"
}
```

### `user_invites/{inviteId}`

Consigliata per onboarding controllato dal CRM.

Campi consigliati:

```json
{
  "email": "new.user@example.com",
  "firstName": "Luca",
  "lastName": "Bianchi",
  "roles": ["user"],
  "accountType": "user",
  "status": "sent",
  "managedRefillPointIds": [],
  "managedSponsorIds": [],
  "invitedBy": "admin uid",
  "acceptedByUid": "",
  "expiresAt": "timestamp",
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}
```

Status consigliati:

- `draft`
- `sent`
- `accepted`
- `expired`
- `revoked`

### `audit_logs/{logId}`

Per tracciare modifiche sensibili del CRM.

Campi consigliati:

```json
{
  "actorUid": "admin uid",
  "action": "user.role.updated",
  "entityType": "user",
  "entityId": "uid",
  "before": {},
  "after": {},
  "createdAt": "server timestamp"
}
```

### Collezioni gia presenti

- `community/impact`
- `users/{uid}/refill_events/{eventId}`

Queste restano valide e vanno integrate nel CRM come dati consultabili.

## Ruoli consigliati

Ruoli cumulabili nel campo `roles`:

- `user`: utente standard dell'app
- `refill_manager`: gestisce uno o piu punti refill
- `sponsor_manager`: gestisce uno o piu sponsor
- `admin`: accesso completo al CRM

Valori consigliati per `accountType`:

- `user`
- `refill_point`
- `sponsor`
- `admin`

Regola pratica:

- `roles` governa i permessi
- `accountType` governa la vista principale mostrata in app dopo il login

## Moduli CRM MVP

### 1. Dashboard

- contatore utenti attivi
- contatore refill point pubblicati
- contatore sponsor pubblicati
- ultimi utenti registrati
- elementi in stato `draft` o `review`

### 2. Utenti

- lista utenti con ricerca
- filtro per ruolo
- filtro per stato
- scheda utente
- modifica ruoli
- modifica `accountType`
- sospensione o riattivazione

### 3. Refill Point

- lista punti refill
- creazione nuovo punto
- modifica dati anagrafici e geolocalizzazione
- assegnazione manager
- pubblicazione o archiviazione

### 4. Sponsor

- lista sponsor
- creazione sponsor
- modifica contenuti visibili in app
- assegnazione manager
- collegamento sponsor a uno o piu refill point

### 5. Inviti

- crea invito utente
- assegna ruoli iniziali
- stato invito
- scadenza invito

### 6. Audit

- storico operazioni amministrative

## Comportamento dell'app per ruolo

### `user`

- home standard
- lista refill point pubblicati
- sponsor pubblicati
- profilo personale

### `refill_manager`

- vista standard utente
- area gestione del proprio punto refill
- lettura dei dati associati al locale

### `sponsor_manager`

- vista standard utente
- area sponsor dedicata
- lettura dei propri dati sponsor e impatto

### `admin`

- accesso CRM web
- nell'app pubblica non e necessario esporre strumenti amministrativi completi

## Flussi consigliati

### Registrazione utente standard

1. L'utente crea account da app
2. Si genera `users/{uid}` con `roles: ["user"]`
3. `accountType` = `user`
4. `status` = `active`

### Creazione utente da CRM

1. L'admin crea un invito in `user_invites`
2. L'utente completa onboarding
3. Viene creato o aggiornato `users/{uid}`
4. L'admin puo assegnare ruoli come `refill_manager` o `sponsor_manager`

### Assegnazione punto refill

1. L'admin crea `refill_points/{id}`
2. Assegna `managerUserIds`
3. Aggiorna il profilo utente con `managedRefillPointIds`
4. Pubblica il punto refill

### Assegnazione sponsor

1. L'admin crea `sponsors/{id}`
2. Assegna `managerUserIds`
3. Aggiorna il profilo utente con `managedSponsorIds`
4. Pubblica lo sponsor

## Convenzioni utili

- usare `snake_case` per i nomi collezione: `refill_points`, `user_invites`, `audit_logs`
- usare `camelCase` nei campi documento
- usare `slug` per URL e identificativi leggibili
- usare `serverTimestamp` per tutti i campi data server-driven
- non salvare logiche di permesso solo lato client

## Roadmap consigliata

### Fase 1

- definizione modello dati
- Firestore Rules
- schermata login admin
- lista utenti
- modifica ruolo e stato utente

### Fase 2

- CRUD refill point
- CRUD sponsor
- associazione manager
- dashboard KPI

### Fase 3

- inviti utente
- audit log
- viste app differenziate per ruolo

## Decisione architetturale

Per FairWater conviene:

- CRM web nello stesso ecosistema Flutter/Firebase
- backend condiviso con l'app
- ruoli e permessi centralizzati in Firestore
- app pubblica focalizzata sull'esperienza, non sulla gestione amministrativa
