# fairwater

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Web app

L'app Flutter supporta browser desktop e mobile. Per avviarla localmente in
Chrome:

```powershell
flutter run -d chrome
```

Per creare la versione pronta alla pubblicazione su Firebase Hosting:

```powershell
flutter build web --release --base-href=/webapp/
firebase deploy --only hosting:public
```

La build viene generata in `build/web`; il target `public` pubblica l'app
FairWater e non il pannello admin. Per pubblicarla nel percorso del sito
`https://www.fairwater.it/webapp`, usa `flutter build web --release
--base-href=/webapp/`; il sito Vercel inoltra quella route al target Firebase.
Per il login Google, aggiungi il dominio web a quelli autorizzati in Firebase
Authentication. Il browser richiede il permesso di posizione; la scansione QR
usa il codice stampato invece della fotocamera. Biometria e notifiche push
mobile non sono disponibili sul web.

## Firebase login

L'app usa ora Firebase Authentication per login/registrazione e Cloud Firestore
per salvare il profilo utente.

Prima di avviare il progetto devi ancora collegare il tuo progetto Firebase:

1. Crea o seleziona un progetto in Firebase Console.
2. Abilita `Authentication` -> `Sign-in method` -> `Email/Password`.
3. Registra le app Android e iOS/Web del progetto.
4. Aggiungi i file di configurazione Firebase al progetto Flutter oppure
   esegui `flutterfire configure`.
5. Assicurati che Firestore sia attivo se vuoi salvare i dati del profilo.

Le credenziali non vengono salvate localmente: Firebase conserva la sessione
dell'utente e permette l'accesso anche da remoto.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
