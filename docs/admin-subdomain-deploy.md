# Deploy di `admin.fairwater.it`

## Strategia scelta

Separare il CRM dal sito pubblico.

- `fairwater.it`: sito pubblico
- `admin.fairwater.it`: CRM admin
- stesso progetto Firebase: `fairwater-app`

## Perche cosi

- non interrompiamo il sito pubblico
- deploy indipendenti tra app pubblica e CRM
- backend unico per auth, ruoli e dati
- SSL e CDN gestiti da Firebase Hosting

## Configurazione repo

Nel repository ora sono presenti:

- [firebase.json](/C:/Users/fvell/Documents/FairWaterFlutter/fairwater/firebase.json)
- [.firebaserc.example](/C:/Users/fvell/Documents/FairWaterFlutter/fairwater/.firebaserc.example)
- [admin_crm/dist/index.html](/C:/Users/fvell/Documents/FairWaterFlutter/fairwater/admin_crm/dist/index.html)
- [admin_crm/dist/styles.css](/C:/Users/fvell/Documents/FairWaterFlutter/fairwater/admin_crm/dist/styles.css)
- [admin_crm/dist/app.js](/C:/Users/fvell/Documents/FairWaterFlutter/fairwater/admin_crm/dist/app.js)

## Struttura Hosting prevista

Target Hosting:

- `public` -> `build/web`
- `admin` -> `admin_crm/dist`

Site ID consigliati:

- `fairwater-app` per il sito principale
- `fairwater-admin` per il CRM

## Passi in Firebase Console o CLI

### 1. Creare il sito Hosting secondario

Da CLI:

```bash
firebase hosting:sites:create fairwater-admin
```

Oppure da Firebase Console:

- apri Hosting
- aggiungi un nuovo site
- usa come site id `fairwater-admin`

### 2. Creare `.firebaserc`

Prendi [.firebaserc.example](/C:/Users/fvell/Documents/FairWaterFlutter/fairwater/.firebaserc.example) come base e salvalo come `.firebaserc`.

### 3. Associare il target locale al sito admin

```bash
firebase target:apply hosting admin fairwater-admin
firebase target:apply hosting public fairwater-app
```

## Collegamento dominio

Nel pannello Firebase Hosting:

1. apri il sito `fairwater-admin`
2. scegli `Add custom domain`
3. inserisci `admin.fairwater.it`
4. segui il wizard DNS

Firebase richiedera record DNS per verifica proprieta e puntamento del sottodominio. Il wizard ti fornira i valori esatti da copiare nel provider DNS del dominio.

## DNS

Il dominio principale `fairwater.it` puo restare dov'e.

Dovrai aggiungere solo il sottodominio:

- `admin.fairwater.it`

Non conviene spostare subito il sito pubblico se oggi e gia online altrove.

## Primo deploy del CRM

```bash
firebase deploy --only hosting:admin
```

## Deploy del sito pubblico

Quando la build Flutter pubblica sara pronta:

```bash
firebase deploy --only hosting:public
```

## Nota importante

La shell presente oggi in `admin_crm/dist` e una base statica pronta per:

- validare il sottodominio
- validare hosting e SSL
- iniziare il CRM senza toccare il sito pubblico

Nel prossimo step conviene collegare questa UI a:

- Firebase Auth
- Firestore `users`
- Firestore `refill_points`
- Firestore `sponsors`

## Step successivo consigliato

Implementare il primo modulo reale del CRM:

1. login admin
2. lettura collezione `users`
3. lista utenti
4. modifica `roles`, `accountType`, `status`
