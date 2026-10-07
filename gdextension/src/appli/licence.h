// MBLicence — la signature des clés de licence (Ed25519), pour l'appli SEULEMENT.
//
// La charte (§0, « la vente ») : une clé au nom de l'acheteur, SIGNÉE par SpannerGames, vérifiée HORS LIGNE par la
// clé publique que porte l'exe. Godot n'a pas Ed25519 (son `Crypto` ne fait que RSA et ECDSA par mbedTLS) : on prend
// Monocypher 4.0.2 (`monocypher/`, BSD-2 ou CC0 au choix, audité par Cure53 en 2020), son module optionnel
// `monocypher-ed25519` — l'Ed25519 de la RFC 8032 (SHA-512), celui de Python `cryptography`, de PyNaCl, de libsodium
// et de la Web Crypto des fonctions du site : une clé signée par n'importe lequel se vérifie ici.
//
// ⚠ ELLE NE DÉCIDE RIEN : elle dit si une signature est bonne. Ce qu'est une clé (son format, le produit, les clés
// révoquées) est écrit UNE fois, dans `app/licence.gd`.
// ⚠ PARTIE PRIVÉE (`src/appli/`) : rien de ceci ne part dans les greffons.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

namespace godot {

class MBLicence : public RefCounted {
	GDCLASS(MBLicence, RefCounted)

public:
	// Vrai si `signature` (64 octets) est la signature Ed25519 de `message` par la clé publique `publique` (32 octets).
	// Toute taille fausse rend faux.
	bool verifier(const PackedByteArray &publique, const PackedByteArray &message, const PackedByteArray &signature) const;
	// La clé publique (32 octets) d'une graine privée (32 octets) ; vide si la graine n'a pas 32 octets.
	PackedByteArray publique_de(const PackedByteArray &graine) const;
	// La signature (64 octets) de `message` par la graine privée ; vide si la graine n'a pas 32 octets.
	// Sert aux tests (et à un outil, un jour) : sans la graine de SpannerGames, elle ne signe rien qui vaille.
	PackedByteArray signer(const PackedByteArray &graine, const PackedByteArray &message) const;

protected:
	static void _bind_methods();
};

} // namespace godot
