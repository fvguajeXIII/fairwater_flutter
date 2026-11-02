# Deployment Admin Panel su Firebase Hosting

## Configurazione

Il pannello admin è una web app statica deployata su `admin.fairwater.it` tramite Firebase Hosting.

## Struttura

- **App principale**: `fairwater.it` (public target)
  - Build: `build/web`
  - Contiene la home, login consumer, profilo, mappa bar

- **Pannello Admin**: `admin.fairwater.it` (admin target)
  - File: `admin_crm/dist`
  - Contiene login CRM e dashboard per utenti, punti refill e sponsor
  - Autenticazione via Firebase Authentication e ruoli in Firestore

## Accesso al Pannello Admin

1. Navigare a `https://admin.fairwater.it`
2. Accedere con email e password oppure con Google
3. Il documento `users/{uid}` deve contenere `admin` o `super_admin` nell'array `roles`

In Firebase Console, abilita i provider **Email/Password** e **Google** in
Authentication > Sign-in method e autorizza il dominio del pannello in
Authentication > Settings > Authorized domains. Le password non vanno inserite
nel codice o nel repository.

## Deploy su Firebase Hosting

### Deploy solo sito pubblico
```bash
firebase deploy --only hosting:public
```

### Deploy solo pannello admin
```bash
firebase deploy --only hosting:admin
```

### Deploy completo (entrambi)
```bash
firebase deploy --only hosting
```

## Struttura Firestore per Admin

Gli utenti admin devono avere in Firestore (collection: users):

```json
{
  "uid": "user-id",
  "email": "admin@fairwater.it",
  "roles": ["admin", "refill_manager"],
  "displayName": "Admin Name",
  "accountType": "admin"
}
```

## Ruoli Disponibili

- `super_admin`: Accesso completo, gestione ruoli altri admin
- `admin`: Gestione bar, sponsor, refill points
- `refill_manager`: Gestione punti refill
- `sponsor_manager`: Gestione sponsor

## File Coinvolti

- `admin_crm/dist/index.html` - Interfaccia del pannello e login
- `admin_crm/dist/app.js` - Firebase Authentication e integrazione Firestore
- `firebase.json` - Configurazione Firebase Hosting

## Note Importanti

- Firestore Security Rules devono consentire le operazioni assegnate al ruolo (vedi `firestore.rules`).
- Se credenziali precedentemente inserite nel frontend sono state pubblicate, reimpostale in Firebase Authentication.
