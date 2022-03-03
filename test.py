import cryptography
import numpy as np

# import required module
from cryptography.fernet import Fernet

# key generation
key = Fernet.generate_key()
  
# string the key in a file
with open('filekey.key', 'wb') as filekey:
   filekey.write(key)


# opening the key
with open('filekey.key', 'rb') as filekey:
    key = filekey.read()
  
# using the generated key
fernet = Fernet(key)
  
# opening the original file to encrypt
with open('global_weights.npy', 'rb') as file:
    original = file.read()
      
# encrypting the file
encrypted = fernet.encrypt(original)
  
# opening the file in write mode and 
# writing the encrypted data
with open('global_weights.npy', 'wb') as encrypted_file:
    encrypted_file.write(encrypted)

# using the key
fernet = Fernet(key)
  
# opening the encrypted file
with open('global_weights.npy', 'rb') as enc_file:
    encrypted = enc_file.read()
  
# decrypting the file
decrypted = fernet.decrypt(encrypted)
  
# opening the file in write mode and
# writing the decrypted data
with open('global_weights_dec.npy', 'wb') as dec_file:
    dec_file.write(decrypted)

b = np.load('global_weights_dec.npy', allow_pickle=True)
print(b)

