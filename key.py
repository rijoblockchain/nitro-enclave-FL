
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.backends.interfaces import RSABackend
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.fernet import Fernet
import rsa as rsa_base
from PIL import Image

def generate_keys_rsa_base(save=False):
    (pubkey, privkey) = rsa_base.newkeys(512)
    if save:
        with open('parent_public_key.pem', 'wb') as f:
            f.write(pubkey._save_pkcs1_pem())
        with open('parent_private_key.pem', 'wb') as f:
            f.write(privkey._save_pkcs1_pem())
    return (pubkey, privkey)

(pubkey, privkey) = generate_keys_rsa_base(True)