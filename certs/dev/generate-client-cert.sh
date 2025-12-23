#!/bin/bash
# Script pour générer un certificat client mTLS pour les tests

set -e

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CN="${1:-postman-client}"

echo "🔐 Génération d'un certificat client mTLS"
echo "📁 Répertoire: $CERT_DIR"
echo "👤 Common Name (CN): $CN"
echo ""

# Vérifier que la CA existe
if [ ! -f "$CERT_DIR/ca-new.crt" ] || [ ! -f "$CERT_DIR/ca.key" ]; then
    echo "❌ Erreur: La CA n'existe pas. Génération de la CA..."
    
    # Générer la clé privée de la CA
    openssl genrsa -out "$CERT_DIR/ca.key" 4096
    
    # Générer le certificat CA
    openssl req -new -x509 -days 365 -key "$CERT_DIR/ca.key" \
        -out "$CERT_DIR/ca-new.crt" \
        -subj "/CN=KongAir Self Signed CA"
    
    echo "✅ CA générée: $CERT_DIR/ca-new.crt"
fi

# Générer la clé privée du client
echo "🔑 Génération de la clé privée du client..."
openssl genrsa -out "$CERT_DIR/client.key" 2048

# Créer la demande de signature (CSR)
echo "📝 Création de la demande de signature (CSR)..."
openssl req -new -key "$CERT_DIR/client.key" \
    -out "$CERT_DIR/client.csr" \
    -subj "/CN=$CN"

# Signer le certificat client avec la CA
echo "✍️  Signature du certificat client..."
openssl x509 -req -in "$CERT_DIR/client.csr" \
    -CA "$CERT_DIR/ca-new.crt" \
    -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERT_DIR/client.crt" \
    -days 365

# Nettoyer le CSR (optionnel)
rm -f "$CERT_DIR/client.csr"

echo ""
echo "✅ Certificat client généré avec succès !"
echo ""
echo "📄 Fichiers générés:"
echo "   - client.crt : Certificat client (à utiliser dans Postman)"
echo "   - client.key : Clé privée du client (à utiliser dans Postman)"
echo "   - ca-new.crt : Certificat CA (déjà dans le template public.yaml)"
echo ""
echo "🔧 Pour utiliser dans Postman:"
echo "   1. Ouvrez Postman Settings → Certificates"
echo "   2. Ajoutez un certificat pour: external.localhost:8000"
echo "   3. CRT file: $CERT_DIR/client.crt"
echo "   4. Key file: $CERT_DIR/client.key"
echo ""
echo "🧪 Test avec curl:"
echo "   curl -v --cert $CERT_DIR/client.crt --key $CERT_DIR/client.key \\"
echo "        -H 'Authorization: Bearer YOUR_OIDC_TOKEN' \\"
echo "        http://external.localhost:8000/health"

