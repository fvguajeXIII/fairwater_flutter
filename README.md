# fairwater

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

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
