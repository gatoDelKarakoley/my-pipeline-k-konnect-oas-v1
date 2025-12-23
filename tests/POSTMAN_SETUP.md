# Guide de Configuration Postman pour KongAir API

Ce guide explique comment configurer Postman pour tester les routes externes (mTLS + OIDC) et internes (Key Auth) de l'API KongAir.

## 📦 Import de la Collection

1. Ouvrez Postman
2. Cliquez sur **Import**
3. Sélectionnez le fichier `KongAir-API-Tests.postman_collection.json`
4. La collection apparaîtra dans votre workspace

## 🔧 Configuration des Variables d'Environnement

### Créer un Environnement Postman

1. Cliquez sur **Environments** dans la barre latérale
2. Cliquez sur **+** pour créer un nouvel environnement
3. Nommez-le "KongAir - Dev" (ou votre environnement)
4. Ajoutez les variables suivantes :

| Variable | Valeur | Description |
|----------|--------|-------------|
| `external_host` | `external.localhost:8000` | Host pour les routes externes |
| `internal_host` | `internal.localhost:8000` | Host pour les routes internes |
| `internal_api_key` | `VOTRE_CLE_API` | API Key pour les routes internes |
| `oidc_token` | `VOTRE_TOKEN_OIDC` | Token OIDC pour les routes externes |

### Valeurs par Environnement

#### DEV
```
external_host: external.localhost:8000
internal_host: internal.localhost:8000
```

#### UAT
```
external_host: external.localhost:8002
internal_host: internal.localhost:8003
```

#### STAGING
```
external_host: external.localhost:8004
internal_host: internal.localhost:8005
```

#### PROD
```
external_host: external.localhost:8006
internal_host: internal.localhost:8007
```

## 🔐 Configuration pour les Routes Internes (Key Auth)

### Obtenir une API Key

1. **Via Kong Admin API** (si vous avez accès) :
```bash
# Créer un Consumer
curl -X POST http://localhost:8001/consumers \
  --data "username=test-consumer"

# Créer une API Key
curl -X POST http://localhost:8001/consumers/test-consumer/key-auth \
  --data "key=your-secret-api-key"
```

2. **Via Kong Konnect** :
   - Allez dans votre Control Plane
   - Créez un Consumer
   - Générez une API Key pour ce Consumer

3. **Mettez à jour la variable** `internal_api_key` dans Postman avec votre clé

### Tester les Routes Internes

Les routes internes utilisent l'en-tête `apikey` :
- L'en-tête est déjà configuré dans la collection
- Assurez-vous que `internal_api_key` est défini dans votre environnement

## 🔒 Configuration pour les Routes Externes (mTLS + OIDC)

### Configuration mTLS dans Postman

1. **Ouvrez les paramètres de Postman** :
   - Cliquez sur l'icône ⚙️ (Settings)
   - Allez dans l'onglet **Certificates**

2. **Ajoutez un certificat client** :
   - Cliquez sur **Add Certificate**
   - **Host**: `external.localhost:8000` (ou votre host externe)
   - **CRT file**: Sélectionnez `certs/dev/client.crt` (déjà généré pour vous)
   - **Key file**: Sélectionnez `certs/dev/client.key` (déjà généré pour vous)
   - **Passphrase**: (laissez vide, pas de passphrase)

3. **Pour les autres environnements**, ajoutez des certificats pour :
   - `external.localhost:8002` (UAT)
   - `external.localhost:8004` (STAGING)
   - `external.localhost:8006` (PROD)

### Obtenir un Token OIDC

1. **Via Okta** (selon votre configuration) :
   - Connectez-vous à votre tenant Okta
   - Obtenez un token via le flow OAuth2/OIDC
   - Utilisez ce token dans la variable `oidc_token`

2. **Ajouter le token dans les requêtes** :
   - Les routes externes nécessitent un token OIDC
   - Ajoutez l'en-tête : `Authorization: Bearer {{oidc_token}}`
   - **Note**: Actuellement, la collection n'inclut pas automatiquement ce header. Vous pouvez l'ajouter manuellement ou modifier la collection.

### Modification de la Collection pour OIDC

Pour ajouter automatiquement le token OIDC aux routes externes :

1. Ouvrez chaque requête dans "External Routes"
2. Allez dans l'onglet **Headers**
3. Ajoutez :
   - **Key**: `Authorization`
   - **Value**: `Bearer {{oidc_token}}`

Ou modifiez la collection JSON pour l'ajouter automatiquement.

## 🧪 Exécution des Tests

### Tester une Route Individuelle

1. Sélectionnez l'environnement "KongAir - Dev"
2. Ouvrez la collection
3. Choisissez une requête (ex: "Health Check - Internal")
4. Cliquez sur **Send**

### Exécuter Tous les Tests

1. Cliquez sur la collection
2. Cliquez sur **Run**
3. Sélectionnez les requêtes à tester
4. Cliquez sur **Run KongAir API - Split Horizon Tests**

### Résultats Attendus

#### Routes Internes
- ✅ **200 OK** avec API Key valide
- ❌ **401 Unauthorized** sans API Key ou avec API Key invalide

#### Routes Externes
- ✅ **200 OK** avec certificat mTLS valide + token OIDC valide
- ❌ **401 Unauthorized** sans certificat ou token invalide
- ❌ **403 Forbidden** avec certificat invalide

## 🔍 Dépannage

### Erreur "SSL certificate problem"
- Vérifiez que le certificat client est correctement configuré dans Postman
- Assurez-vous que le certificat est signé par la CA configurée dans Kong

### Erreur "401 Unauthorized" sur routes internes
- Vérifiez que `internal_api_key` est défini dans l'environnement
- Vérifiez que l'en-tête `apikey` est présent (déjà configuré dans la collection)

### Erreur "401 Unauthorized" sur routes externes
- Vérifiez que le certificat client est configuré pour le bon host
- Vérifiez que le token OIDC est valide et non expiré
- Vérifiez que l'en-tête `Authorization` est présent avec le token

### Les hosts ne résolvent pas
- Vérifiez que vos Data Planes Docker sont en cours d'exécution
- Vérifiez que les ports sont corrects dans les variables d'environnement
- Pour `localhost`, assurez-vous que Postman peut accéder à localhost

## 📝 Notes

- Les routes externes nécessitent **à la fois** mTLS ET OIDC
- Les routes internes nécessitent uniquement l'API Key
- Le rate limiting est configuré à 100 req/min pour les routes internes
- Les certificats mTLS doivent être signés par la CA configurée dans `public.yaml`

