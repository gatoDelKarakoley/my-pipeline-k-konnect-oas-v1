# Certificats mTLS pour Tests - DEV

Ce dossier contient les certificats nécessaires pour tester les routes externes avec mTLS.

## 📁 Fichiers

- **`ca-new.crt`** : Certificat de l'Autorité de Certification (CA)
- **`ca.key`** : Clé privée de la CA (⚠️ À garder secret, ne pas partager)
- **`client.crt`** : Certificat client signé par la CA (pour Postman/curl)
- **`client.key`** : Clé privée du certificat client (⚠️ À garder secret)
- **`client.csr`** : Demande de signature de certificat (peut être supprimé)

## 🔧 Utilisation avec Postman

1. **Ouvrez Postman Settings** (⚙️) → **Certificates**

2. **Ajoutez un certificat client** :
   - Cliquez sur **Add Certificate**
   - **Host**: `external.localhost:8000` (ou votre host externe)
   - **CRT file**: Sélectionnez `certs/dev/client.crt`
   - **Key file**: Sélectionnez `certs/dev/client.key`
   - **Passphrase**: (laissez vide si pas de passphrase)

3. **Pour les autres environnements**, ajoutez le même certificat pour :
   - `external.localhost:8002` (UAT)
   - `external.localhost:8004` (STAGING)
   - `external.localhost:8006` (PROD)

## 🧪 Test avec curl

```bash
# Test de la route externe avec mTLS
curl -v \
  --cert certs/dev/client.crt \
  --key certs/dev/client.key \
  --cacert certs/dev/ca-new.crt \
  -H "Authorization: Bearer YOUR_OIDC_TOKEN" \
  http://external.localhost:8000/health
```

## ⚠️ Important

- Ces certificats sont pour les **tests en développement uniquement**
- Ne partagez **jamais** les fichiers `.key` (clés privées)
- Pour la production, générez de nouveaux certificats avec une CA sécurisée
- Le certificat client expire dans 365 jours

## 🔄 Régénérer les Certificats

Si vous devez régénérer les certificats :

```bash
cd certs/dev

# 1. Générer une nouvelle clé CA (si nécessaire)
openssl genrsa -out ca.key 4096

# 2. Générer le certificat CA
openssl req -new -x509 -days 365 -key ca.key -out ca-new.crt \
  -subj "/CN=KongAir Self Signed CA"

# 3. Générer la clé privée du client
openssl genrsa -out client.key 2048

# 4. Créer la demande de signature (CSR)
openssl req -new -key client.key -out client.csr \
  -subj "/CN=postman-client"

# 5. Signer le certificat client avec la CA
openssl x509 -req -in client.csr -CA ca-new.crt -CAkey ca.key \
  -CAcreateserial -out client.crt -days 365
```

## 📝 Note sur le CN (Common Name)

Le CN du certificat client (`postman-client`) sera utilisé par Kong comme identifiant si vous utilisez le plugin `mtls-auth` avec `consumer_by` configuré. Pour l'instant, le plugin est configuré avec `anonymous: null`, donc tous les certificats signés par la CA seront acceptés.

