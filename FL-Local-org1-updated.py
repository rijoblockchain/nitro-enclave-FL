import numpy as np
import random
import cv2
import os
from struct import unpack, pack
import argparse
import socket, pickle
import sys
import time
import subprocess
import rsa as rsa_base
from crypto_utils import *
from imutils import paths
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelBinarizer
from sklearn.model_selection import train_test_split
from sklearn.utils import shuffle
from sklearn.metrics import accuracy_score
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Conv2D
from tensorflow.keras.layers import MaxPooling2D
from tensorflow.keras.layers import Activation
from tensorflow.keras.layers import Flatten
from tensorflow.keras.layers import Dense
from tensorflow.keras.optimizers import SGD
from tensorflow.keras import backend as K
import cryptography
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.backends.interfaces import RSABackend
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.fernet import Fernet
import rsa as rsa_base
from PIL import Image
import base64
import hashlib
import json
import logging
#import tflite_runtime.interpreter as tflite

class SimpleMLP:
    @staticmethod
    def build(shape, classes):
        model = Sequential()
        model.add(Dense(200, input_shape=(shape,)))
        model.add(Activation("relu"))
        model.add(Dense(200))
        model.add(Activation("relu"))
        model.add(Dense(classes))
        model.add(Activation("softmax"))
        return model

lr = 0.01 
comms_round = 10
loss='categorical_crossentropy'
metrics = ['accuracy']
optimizer = SGD(learning_rate=lr, 
                decay=lr / comms_round, 
                momentum=0.9
               ) 

#initialize global model
smlp_global = SimpleMLP()
global_model = smlp_global.build(1024, 4)

# get the global model's weights - will serve as the initial weights for all local models
global_weights = global_model.get_weights()

smlp_local1 = SimpleMLP()
local_model1 = smlp_local1.build(1024, 4)
local_model1.compile(loss=loss, 
                optimizer=optimizer, 
                metrics=metrics)

#set local model weight to the weight of the global model
local_model1.set_weights(global_weights)



global_weights_encrypted = np.load('encrypted_average_weights.npy', allow_pickle=True)

#global_weights_encrypted = list()
print(len(global_weights_encrypted))

# for x in range(len(updated_weights_encrypted)):
#     global_weights_encrypted.append(np.asarray(updated_weights_encrypted[x], dtype=np.float32))

# print(len(global_weights_encrypted))


with open('inference_key_received', 'rb') as f:
    encrypted_key = f.read()

global_weights_decrypted = list()

(parent_public_key, parent_private_key) = load_rsa_keys_parent()
for x in range(len(global_weights_encrypted)):
    decrypted_content = decrypt_local_weights(global_weights_encrypted[x], encrypted_key, parent_private_key)
    global_weights_decrypted.append(np.frombuffer(decrypted_content, dtype=np.float32))





b = list()
b.append(global_weights_decrypted[0].reshape([1024, 200]))
b.append(global_weights_decrypted[1])
b.append(global_weights_decrypted[2].reshape([200, 200]))
b.append(global_weights_decrypted[3])
b.append(global_weights_decrypted[4].reshape([200, 4]))
b.append(global_weights_decrypted[5])

for x in range(len(b)): 
    print(b[x].shape)

print(b)
# new_global_weights = list()
# for x in range(len(global_weights_decrypted)):
#     new_global_weights.append(np.asarray(global_weights_decrypted[x], dtype=np.float32))

#print(new_global_weights)
# print(len(global_weights))
# for x in range(len(new_global_weights)):
#     print(new_global_weights[x].shape)
        
#set local model weight to the weight of the global model
local_model1.set_weights(b)

print(local_model1.get_weights())