# Deployment Admin Panel su Firebase Hosting

## Configurazione

Il pannello admin è stato configurato come app Flutter Web e sarà deployato su `admin.fairwater.it` tramite Firebase Hosting.

## Struttura

- **App principale**: `fairwater.it` (public target)
  - Build: `build/web`
  - Contiene la home, login consumer, profilo, mappa bar

- **Pannello Admin**: `admin.fairwater.it` (admin target)
  - Build: `build/web` (stessa build, gestione rotte da Flutter)
  - Contiene login admin, dashboard gestione bar
  - Autenticazione via Firebase Auth con ruoli admin

## Accesso al Pannello Admin

1. Navigare a `https://admin.fairwater.it/admin-login`
2. Effettuare login con credenziali admin
3. Verifica dei ruoli admin in Firestore
4. Accesso alla dashboard gestione bar se autorizzato

## Build Web

```bash
flutter build web --release
```

Output: `build/web/`

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

## Sincronizzazione Real-Time

La dashboard admin utilizza Cloud Firestore Streams per la sincronizzazione real-time:

1. Modifiche nel CRM → salvate in Firestore
2. Firestore notifica i listener (dashboard e app consumer)
3. UI aggiornate automaticamente in tempo reale

Non è necessario fare nulla: le modifiche sono sincronizzate istantaneamente.

## File Coinvolti

- `lib/services/admin_service.dart` - Gestione ruoli e permessi admin
- `lib/screens/admin_login_page.dart` - Login page per admin
- `lib/screens/admin_dashboard_page.dart` - Dashboard gestione bar (CRUD)
- `lib/main.dart` - Routes per admin
- `firebase.json` - Configurazione Firebase Hosting

## Testing Locale

```bash
# Build web in debug
flutter build web

# Servire localmente
cd build/web
python -m http.server 8000

# Accedere a http://localhost:8000/admin-login
```

## Note Importanti

- ✅ Sincronizzazione real-time già implementata via `BarService.watchBars()`
- ✅ Autenticazione Firebase integrata
- ✅ CRUD bar completamente funzionale
- ⚠️ Firestore security rules devono consentire operazioni admin (vedi firestore.rules)
- ⚠️ Assicurarsi che gli utenti admin abbiano i ruoli corretti in Firestore
