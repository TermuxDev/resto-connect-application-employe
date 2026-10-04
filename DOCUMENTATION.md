# DOCUMENTATION DE L'APPLICATION TERMINAL — RESTO-CONNECT

> Application Flutter des **terminaux de scan** (comptes « Employé »). Toutes les commandes se lancent
> **depuis le dossier `APP-EMPLOYE/`**. Le contrat de l'API est décrit dans
> [../ARCHITECTURE.md](../ARCHITECTURE.md), section 5.

---

## 1. Ce que fait l'application

1. **Connexion** avec le compte du terminal (téléphone + mot de passe) créé par le gérant.
2. **Avant le service** : « Rechercher les mises à jour » envoie les scans en attente puis charge les étudiants
   (avec leurs photos) que ce terminal contrôle : internes **ou** externes.
3. **Pendant le service** : la caméra lit les QR en continu, **sans Internet**. Chaque scan se fait en deux temps :
   - **refusé** : écran **rouge** + bip grave + icône ✕, avec le motif (déjà servi, solde épuisé, carte bloquée…).
     **Rien n'est enregistré** ;
   - **autorisé** : la photo et le nom s'affichent ; l'employé vérifie la photo puis touche **« Valider le repas »**.
     La vérification est **refaite** à cet instant (impossible de badger deux fois), le repas est enregistré :
     écran **vert** + bip aigu + icône ✓. « Annuler » n'enregistre rien.
4. **Menu** : le bouton « Menu » ramène à l'accueil **sans terminer le service** ; « Reprendre le scan » y retourne.
5. **Terminer le service** (depuis l'accueil) : le service est fermé et les repas sont envoyés dès que le réseau le permet.
6. **Envois** (icône nuage) : repas en attente d'envoi, **historique des envois** (réussis ou échoués) et
   bouton « Envoyer maintenant ».

Contrôles automatiques : écart entre l'heure du téléphone et celle du serveur, version minimale exigée
par le serveur, session expirée (les scans en attente ne sont jamais perdus).

---

## 2. Architecture

```
lib/
├── main.dart                     Démarrage : base locale, API, sons
├── app.dart                      Choix de l'écran selon la phase (connexion, accueil, service…)
├── config/
│   ├── configuration.dart        Adresse du serveur par défaut, durées d'affichage
│   └── theme.dart                Couleurs et styles (identiques au front Gérant)
├── domaine/                      Règles métier PURES (aucune dépendance) — testées
│   ├── modeles.dart              Étudiant, Terminal, Paramètres, Service, Passage (repas), Synchronisation
│   ├── verification.dart         Bip vert / bip rouge (reproduit les règles du serveur)
│   └── version.dart              Comparaison de versions
├── donnees/
│   ├── base_locale.dart          SQLite + MIGRATIONS VERSIONNÉES
│   ├── depot.dart                Lecture / écriture de la base locale
│   └── client_api.dart           Appels HTTP, jetons JWT, renouvellement automatique
├── synchronisation/
│   └── synchroniseur.dart        Push des scans PUIS pull des données, téléchargement des photos
├── etat/
│   └── etat_terminal.dart        État de l'application et actions (connexion, scan, clôture…)
└── interface/
    ├── sons.dart                 Bips préchargés + vibration
    ├── composants/               Résultat plein écran animé, photo, éléments communs
    └── ecrans/                   Connexion, Accueil, Service (scan), Mise à jour requise
test/                             Tests des règles de vérification et des versions
assets/sons/                      bip_vert.wav, bip_rouge.wav
```

**Sens des dépendances** : `interface → etat → synchronisation / donnees → domaine`.
Le dossier `domaine/` ne dépend de rien : c'est là que se trouvent les règles, testables sans téléphone.

> **Règles identiques au serveur.** `domaine/verification.dart` reproduit les règles RG03 à RG06
> (ETUDESYSTEME.md). Toute évolution d'une règle doit être faite **des deux côtés**, avec ses tests.

Icônes de l'application : générées à partir du logo par `outils/generer_icones.py`
(à relancer seulement si le logo change).

---

## 3. Commandes

```bash
# Dépendances
flutter pub get

# Lancer sur un téléphone branché ou un émulateur (serveur local vu depuis l'émulateur : 10.0.2.2)
flutter run

# Lancer en visant le serveur du PC sur le Wi-Fi (le serveur doit tourner avec runserver 0.0.0.0:8000)
flutter run --dart-define=SERVEUR=http://192.168.1.20:8000

# Qualité
flutter analyze
flutter test

# Version de production (HTTPS obligatoire)
flutter build apk --release --dart-define=SERVEUR=https://resto.exemple.ci
# → build/app/outputs/flutter-apk/app-release.apk
```

L'adresse du serveur reste modifiable sur l'écran de connexion (« Adresse du serveur »).

> La version publiée **refuse le HTTP non chiffré** : seule la version de développement l'autorise
> (`android/app/src/debug/AndroidManifest.xml`).

---

## 4. Mettre à jour l'application en production

### 4.1 Numéro de version (`pubspec.yaml`)
```yaml
version: 1.2.0+5     # MAJEURE.MINEURE.CORRECTIF + NUMÉRO_DE_BUILD
```
| Changement | Exemple |
|---|---|
| Correction sans effet sur les données | `1.2.0+5` → `1.2.1+6` |
| Nouvelle fonctionnalité compatible | `1.2.1+6` → `1.3.0+7` |
| Changement incompatible avec l'ancien serveur ou l'ancienne API | `1.3.0+7` → `2.0.0+8` |

Le **numéro de build** (après le `+`) doit **toujours augmenter** : Android refuse sinon d'installer la mise à jour.

### 4.2 Signature : la clé ne doit jamais changer
Android n'installe une mise à jour **par-dessus** l'ancienne version que si elle est signée avec **la même clé**.

Création, **une seule fois** :
```bash
keytool -genkey -v -keystore resto-terminal.jks -keyalg RSA -keysize 2048 -validity 10000 -alias resto
```
Puis créer `android/key.properties` (ignoré par Git) :
```properties
storeFile=C:/chemin/sûr/resto-terminal.jks
storePassword=…
keyAlias=resto
keyPassword=…
```
> ⚠️ Sauvegarder le fichier `.jks` et ses mots de passe **hors du projet** (coffre-fort, clé USB chiffrée).
> Clé perdue = impossible de mettre à jour les terminaux sans les désinstaller (et perdre les scans en attente).

### 4.3 Base locale : migrations versionnées
La base SQLite du téléphone contient les **scans en attente d'envoi**. Une mise à jour ne doit jamais les perdre.

- Les évolutions de la base sont des **migrations** ajoutées **à la fin** de la liste `migrations`
  dans `lib/donnees/base_locale.dart`. Au démarrage, l'application applique celles qui manquent.
- **Ne jamais modifier** une migration déjà publiée ; **ne jamais supprimer** de passages ou de services
  dont `envoye = 0`.

Exemple réel — migration n°2, ajoutée pendant la phase de test de la 1.0.0 (la n°1 n'a pas été touchée) :
```dart
// 2 — Historique des envois ; les refus ne sont plus enregistrés (1.0.0, phase de test).
[
  'CREATE TABLE synchronisations (…)',
  'DELETE FROM passages WHERE accepte = 0',   // refus : plus aucune valeur, jamais des repas
],
```
Les colonnes `accepte` et `motif_refus` de la version 1 restent dans la table `passages` : on ne retire
pas une colonne d'une base déjà en service, on cesse simplement de s'en servir.

### 4.4 Version minimale imposée par le serveur
Le serveur indique la version minimale acceptée (`VERSION_MIN_APPLICATION` dans `SERVEUR/.env`).
Une application plus ancienne affiche « Mise à jour requise » et ne scanne plus ; ses scans en attente restent conservés.
Chaque requête envoie aussi l'en-tête `X-Application-Version` pour suivre les versions en service.

**Procédure pour une mise à jour obligatoire**
1. Publier la nouvelle version de l'application (APK signé avec la même clé) et l'installer sur les terminaux.
2. Seulement ensuite, relever `VERSION_MIN_APPLICATION` sur le serveur.

### 4.5 Compatibilité avec le serveur
- Le serveur doit rester compatible avec les applications encore en service : ajouter des champs à l'API
  est sans risque, en retirer ou en renommer impose une nouvelle version majeure **et** une version minimale.
- L'application ignore les champs qu'elle ne connaît pas : un serveur plus récent ne la casse pas.

### 4.6 Liste de contrôle avant publication
- [ ] `flutter analyze` sans erreur et `flutter test` au vert.
- [ ] Numéro de version et numéro de build augmentés dans `pubspec.yaml`.
- [ ] Nouvelle migration ajoutée si la base locale change (aucune migration existante modifiée).
- [ ] Règles de vérification identiques à celles du serveur.
- [ ] APK construit en `--release`, signé avec la clé de publication, adresse HTTPS du serveur.
- [ ] Essai sur un terminal : mise à jour **par-dessus** l'ancienne version, scans en attente toujours présents.

---

## 5. Problèmes fréquents

| Problème | Solution |
|---|---|
| « Serveur injoignable » | Vérifier l'adresse du serveur et le réseau. Le terminal continue de scanner hors ligne |
| « Session expirée » | Se reconnecter : les scans en attente sont conservés et seront envoyés |
| Bandeau « heure décalée » | Régler l'heure du téléphone (automatique) : les scans sont horodatés |
| « Mise à jour requise » | Installer la version fournie par le gérant |
| Caméra noire | Autoriser la caméra dans les réglages du téléphone |
| Déconnexion impossible | Envoyer d'abord les scans en attente et clôturer le service |
