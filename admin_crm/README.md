# FairWater Admin CRM

Questa cartella ospita il pannello destinato a `admin.fairwater.it`.

## Obiettivo

Separare il CRM dal sito pubblico e dall'app consumer:

- `fairwater.it` resta sito pubblico
- `admin.fairwater.it` ospita il CRM
- entrambi possono convivere nello stesso progetto Firebase

## Accesso e autorizzazioni

- Il pannello usa Firebase Authentication con provider email/password e Google.
- L'utente deve esistere in Firebase Authentication e avere un documento
  `users/{uid}` in Firestore con `roles` contenente `admin` o `super_admin`.
- Abilita i provider email/password e Google in Firebase Console >
  Authentication > Sign-in method.
- Aggiungi i domini di Hosting in Authentication > Settings > Authorized
  domains.

Le password non devono essere salvate nel codice. Se credenziali precedentemente
inserite nel frontend sono state pubblicate, reimpostale in Firebase
Authentication.

## Deploy

Il frontend statico si trova in `dist/` ed è configurato sul target Firebase
Hosting `admin`.

```bash
firebase deploy --only hosting:admin
```

## Cartelle

- `dist/`: build statica pronta per Firebase Hosting

## Hosting target

Questo pannello e pensato per il target Firebase Hosting:

- `admin`

Configurazione di esempio:

- site id Firebase: `fairwater-admin`
- dominio: `admin.fairwater.it`
