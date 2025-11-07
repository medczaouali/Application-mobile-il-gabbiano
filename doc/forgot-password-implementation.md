# Mot de passe oublié avec email (code + lien)

Oui, c'est possible, mais il faut un service d'authentification/serveur pour envoyer des emails et valider des codes/tokens. Avec la base locale SQLite actuelle (hors-ligne), on ne peut pas envoyer et valider des codes de manière fiable. Il faut donc ajouter un backend.

Ci-dessous, deux approches solides (recommandé: Supabase, alternative: Firebase Auth). Les deux permettent l'envoi d'un lien de réinitialisation. Supabase permet aussi un OTP (code) par email très facilement.

---

## Option A (recommandée): Supabase Auth (lien + OTP)

- Avantages
  - Envoi de lien de réinitialisation de mot de passe prêt à l'emploi.
  - OTP par email (code) possible via `auth.signInWithOtp()`/`verifyOtp()`.
  - Pas de serveur à maintenir; Postgres + Auth + Emails intégrés.

- Étapes
  1. Crée un projet sur https://supabase.com, active Email auth.
  2. Configure l'email sender (Domain + DKIM/SPF si possible, ou l'expéditeur par défaut).
  3. Dans le projet Flutter, ajoute:
     ```yaml
     dependencies:
       supabase_flutter: ^2.5.0
       uni_links: ^0.5.1
     ```
  4. Initialise Supabase au démarrage (dans `main.dart`):
     ```dart
     await Supabase.initialize(
       url: 'https://<PROJECT_REF>.supabase.co',
       anonKey: '<ANON_KEY>',
     );
     ```
  5. Lien magique (reset password):
     - Appelle `Supabase.instance.client.auth.resetPasswordForEmail(email, redirectTo: 'ilgabbiano://reset');`
     - Ajoute un schéma d'URL/deep link `ilgabbiano://reset` (Android/iOS/Web) et écoute avec `uni_links`.
     - Sur réception du lien, Supabase fournit le `access_token` temporaire; affiche un écran "Nouveau mot de passe" et appelle `auth.updateUser(UserAttributes(password: newPassword))`.

  6. Code OTP par email (alternative dans le même écran):
     - `await supabase.auth.signInWithOtp(email: email, shouldCreateUser: false);` → l’utilisateur reçoit un code (6 chiffres).
     - L’utilisateur saisit le code → `await supabase.auth.verifyOTP(email: email, token: code, type: OtpType.email);`
     - Une fois vérifié, l’utilisateur est authentifié; propose de définir un nouveau mot de passe via `auth.updateUser(...)`.

  7. Migration users:
     - Soit tu migres tes utilisateurs vers Supabase (table `auth.users` + table profil optionnelle),
     - Soit tu bascules l'inscription/connexion sur Supabase et tu n'utilises plus la table `users` locale pour l'auth (tu peux la garder pour des métadonnées non sensibles si besoin).

- UI suggérée (dans `ForgotPasswordScreen`):
  - Champ email.
  - Deux boutons: "Recevoir un lien" et "Recevoir un code".
  - Écran de saisie du code (si OTP) ou écran de nouveau mot de passe (après lien/deep link).

---

## Option B: Firebase Authentication (lien standard)

- Avantages
  - Envoi du lien de réinitialisation de mot de passe très simple (`sendPasswordResetEmail`).
  - Infra gérée par Google.
- Limites
  - Flux par code séparé moins direct (le "code" est encapsulé dans l'OOB code du lien). Tu peux techniquement le récupérer via Dynamic Links, mais l'expérience est moins naturelle qu'avec l'OTP Supabase.

- Étapes
  1. Crée un projet Firebase, ajoute l’app Flutter (Android/iOS/Web).
  2. Active Email/Password dans Authentication.
  3. Ajoute FlutterFire (`firebase_core`, `firebase_auth`, `firebase_dynamic_links` si deep link natif).
  4. Appelle `await FirebaseAuth.instance.sendPasswordResetEmail(email: ...)`.
  5. Le lien ouvre soit une page web d’hébergement Firebase, soit un Dynamic Link qui revient dans l’app; puis appelle `confirmPasswordReset(oobCode, newPassword)`.

---

## Option C: Backend personnalisé (Node/Express + Mailgun/Resend)

- Étapes (résumé)
  1. Endpoint POST `/auth/forgot` → génère `token` + `code` (6 chiffres), expiration (ex: 15 min). Stocke en base (Postgres/MySQL/SQLite serveur), rate-limit.
  2. Envoie un email via Mailgun/Resend contenant:
     - Le code à 6 chiffres.
     - Un lien: `https://votredomaine/reset?token=...`
  3. Deux flux côté client:
     - Saisie du code dans l’app → POST `/auth/verify-code` → si ok, autorise `POST /auth/reset`.
     - Clic sur le lien → page web/index, ou deep link `ilgabbiano://reset?token=...` → app → écran "Nouveau mot de passe" → POST `/auth/reset`.
  4. `POST /auth/reset` met à jour le mot de passe hashé et invalide code/token.

- À noter: ton app actuelle stocke les mots de passe dans SQLite local; il faut alors passer à une base centralisée, sinon le serveur ne peut pas mettre à jour le mot de passe du téléphone de l’utilisateur.

---

## Conseils de choix
- Tu veux à la fois lien + code sans gérer un serveur: choisis Supabase.
- Tu veux juste un lien de réinitialisation simple et fiable: Firebase Auth.
- Tu as déjà un backend et un domaine mail: fais un backend personnalisé.

---

## Sécurité et bonnes pratiques
- Toujours mettre une expiration courte (10–20 min) pour codes/tokens.
- Invalider le code/token après usage (one-time).
- Rate-limit la route `/auth/forgot` pour éviter l’abus.
- Ne loggue jamais les codes/tokens complets en clair.
- Utiliser TLS/HTTPS et des secrets stockés en sécurité.

---

## Intégration Flutter (exemple Supabase minimal)

- Envoyer lien:
```dart
await Supabase.instance.client.auth.resetPasswordForEmail(
  email,
  redirectTo: 'ilgabbiano://reset',
);
```
- Recevoir le lien (deep link) avec uni_links et mettre à jour le mot de passe:
```dart
final uri = await getInitialUri();
// si uri.scheme == 'ilgabbiano' et uri.host == 'reset'
await Supabase.instance.client.auth.updateUser(
  UserAttributes(password: newPassword),
);
```
- OTP (code par email):
```dart
await supabase.auth.signInWithOtp(email: email, shouldCreateUser: false);
// puis, après saisie du code dans l'UI, vérifier
await supabase.auth.verifyOTP(
  email: email,
  token: code,
  type: OtpType.email,
);
// utilisateur connecté → proposer de définir un nouveau mot de passe
await supabase.auth.updateUser(UserAttributes(password: newPassword));
```

---

Si tu me dis quelle option tu préfères (Supabase, Firebase, ou backend perso), je peux te brancher l’app et remplacer l’écran `ForgotPasswordScreen` actuel par le nouveau flux (lien + code) et configurer les deep links.
