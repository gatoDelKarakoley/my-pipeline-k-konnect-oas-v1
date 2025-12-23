# Guide de Gestion des Certificats mTLS

Ce document explique comment gérer l'autorité de certification (CA) et émettre des certificats clients pour l'authentification mTLS dans Kong.

## 1. Générer une Autorité de Certification (CA)

Si vous devez remplacer la CA par défaut ou en créer une nouvelle pour votre environnement :

```bash
# 1. Générer la clé privée de la CA
openssl genrsa -out ca.key 4096

# 2. Générer le certificat de la CA (Valable 1 an)
# Modifiez le "/CN" pour identifier votre organisation
openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/CN=KongAir Custom CA"
```

### Intégration dans le Template
Copiez le contenu complet de `ca.crt` (y compris les lignes `BEGIN` et `END`) dans le fichier `config/templates/public.yaml` :
- Section: `ca_certificates` -> `cert`

## 2. Émettre un Certificat Client

Pour qu'une application (consommateur) puisse appeler votre API protégée, elle doit présenter un certificat signé par cette CA.

```bash
# 1. Générer la clé privée du client
openssl genrsa -out client.key 2048

# 2. Créer une Demande de Signature de Certificat (CSR)
# IMPORTANT : Le "CN" (Common Name) sera utilisé par Kong comme identifiant (username)
openssl req -new -key client.key -out client.csr -subj "/CN=client-app-1"

# 3. Signer le certificat client avec votre CA
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365
```

## 3. Valider et Tester

### Vérifier le certificat généré
```bash
openssl x509 -in client.crt -text -noout
```

### Tester l'appel API (Exemple)
```bash
# Remplacez l'URL par votre point d'entrée Kong
curl -v --cert client.crt --key client.key https://votre-api.kongair.com/routes
```
