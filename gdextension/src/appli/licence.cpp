// MBLicence — voir licence.h.
#include "licence.h"

#include "monocypher/monocypher-ed25519.h"
#include "monocypher/monocypher.h"

#include <godot_cpp/core/class_db.hpp>

#include <cstring>

using namespace godot;

// Un message VIDE (le premier vecteur de la RFC 8032) : un PackedByteArray vide peut rendre un pointeur nul.
static const uint8_t *octets(const PackedByteArray &a) {
	static const uint8_t rien = 0;
	return a.size() > 0 ? a.ptr() : &rien;
}

bool MBLicence::verifier(const PackedByteArray &publique, const PackedByteArray &message,
		const PackedByteArray &signature) const {
	if (publique.size() != 32 || signature.size() != 64) {
		return false;
	}
	// `crypto_ed25519_check` rend 0 si la signature est bonne, -1 sinon (S hors de l'ordre du groupe compris).
	return crypto_ed25519_check(signature.ptr(), publique.ptr(), octets(message), size_t(message.size())) == 0;
}

PackedByteArray MBLicence::publique_de(const PackedByteArray &graine) const {
	PackedByteArray publique;
	if (graine.size() != 32) {
		return publique;
	}
	uint8_t g[32];
	uint8_t secrete[64];
	std::memcpy(g, graine.ptr(), 32);
	publique.resize(32);
	crypto_ed25519_key_pair(secrete, publique.ptrw(), g); // efface `g`
	crypto_wipe(secrete, sizeof(secrete));
	return publique;
}

PackedByteArray MBLicence::signer(const PackedByteArray &graine, const PackedByteArray &message) const {
	PackedByteArray signature;
	if (graine.size() != 32) {
		return signature;
	}
	uint8_t g[32];
	uint8_t secrete[64];
	uint8_t publique[32];
	std::memcpy(g, graine.ptr(), 32);
	crypto_ed25519_key_pair(secrete, publique, g);
	signature.resize(64);
	crypto_ed25519_sign(signature.ptrw(), secrete, octets(message), size_t(message.size()));
	crypto_wipe(secrete, sizeof(secrete));
	return signature;
}

void MBLicence::_bind_methods() {
	ClassDB::bind_method(D_METHOD("verifier", "publique", "message", "signature"), &MBLicence::verifier);
	ClassDB::bind_method(D_METHOD("publique_de", "graine"), &MBLicence::publique_de);
	ClassDB::bind_method(D_METHOD("signer", "graine", "message"), &MBLicence::signer);
}
