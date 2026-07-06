# FairWater Admin CRM

Questa cartella ospita il pannello destinato a `admin.fairwater.it`.

## Obiettivo

Separare il CRM dal sito pubblico e dall'app consumer:

- `fairwater.it` resta sito pubblico
- `admin.fairwater.it` ospita il CRM
- entrambi possono convivere nello stesso progetto Firebase

## Stato attuale

In questa fase e presente una shell web statica deployabile su Firebase Hosting.
Serve per:

- occupare il sottodominio admin senza toccare il sito pubblico
- validare DNS, SSL e deploy
- preparare la struttura UI del CRM

## Evoluzione consigliata

Step successivo:

1. sostituire questa shell con una web app Flutter o con un frontend admin piu ricco
2. collegare Firebase Auth
3. collegare Firestore per:
   - utenti
   - refill point
   - sponsor
   - inviti
4. applicare i ruoli `admin`, `refill_manager`, `sponsor_manager`

## Cartelle

- `dist/`: build statica pronta per Firebase Hosting

## Hosting target

Questo pannello e pensato per il target Firebase Hosting:

- `admin`

Configurazione di esempio:

- site id Firebase: `fairwater-admin`
- dominio: `admin.fairwater.it`
