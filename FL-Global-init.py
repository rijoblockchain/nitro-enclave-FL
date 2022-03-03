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

#declear path to your mnist data folder
img_path = '/home/ec2-user/nitro-enclave-tensorflow/org1/covid_data/'

#get the path list using the path object
image_paths = list(paths.list_images(img_path))

def load(paths, verbose=-1):
    '''expects images for each class in seperate dir, 
    e.g all digits in 0 class in the directory named 0 '''
    data = list()
    labels = list()
    # loop over the input images
    for (i, imgpath) in enumerate(paths):
        # load the image and extract the class labels
        im_gray = cv2.imread(imgpath, cv2.IMREAD_GRAYSCALE)
        resize = cv2.resize(im_gray,(32,32))
        image = np.array(resize).flatten()
        label = imgpath.split(os.path.sep)[-2]
        # scale the image to [0, 1] and add to list
        data.append(image/255)
        labels.append(label)
        # show an update every `verbose` images
        if verbose > 0 and i > 0 and (i + 1) % verbose == 0:
            print("[INFO] processed {}/{}".format(i + 1, len(paths)))
    # return a tuple of the data and labels
    return data, labels

#apply our function
image_list, label_list = load(image_paths, verbose=10000)

#binarize the labels
lb = LabelBinarizer()
label_list = lb.fit_transform(label_list)

#split data into training and test set
X_train, X_test, y_train, y_test = train_test_split(image_list, 
                                                    label_list, 
                                                    test_size=0.1, 
                                                    random_state=42)

data = list(zip(X_train, y_train))

def batch_data(data_shard, bs=32):
    '''Takes in a clients data shard and create a tfds object off it
    args:
        shard: a data, label constituting a client's data shard
        bs:batch size 
    return:
        tfds object'''
    #seperate shard into data and labels lists
    data, label = zip(*data_shard)
    dataset = tf.data.Dataset.from_tensor_slices((list(data), list(label)))
    return dataset.shuffle(len(label)).batch(bs)

#process and batch the training data for each client
client_batched = batch_data(data)
    
#process and batch the test set  
test_batched = tf.data.Dataset.from_tensor_slices((X_test, y_test)).batch(len(y_test))

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


#initial list to collect local model weights after scalling
scaled_local_weight_list = list()

smlp_local1 = SimpleMLP()
local_model1 = smlp_local1.build(1024, 4)
local_model1.compile(loss=loss, 
                optimizer=optimizer, 
                metrics=metrics)
        
#set local model weight to the weight of the global model
local_model1.set_weights(global_weights)

#fit local model with client's data
local_model1.fit(client_batched, epochs=1, verbose=0)



def weight_scalling_factor(client_trn_data):
    #get the bs
    bs = list(client_trn_data)[0][0].shape[0]
    #first calculate the total training data points across clinets
    global_count = (6368+6368)*32#sum([tf.data.experimental.cardinality(clients_trn_data[client_name]).numpy() for client_name in client_names])*bs
    # get the total number of data points held by a client
    local_count = tf.data.experimental.cardinality(client_trn_data).numpy()*bs
    #print(local_count) #6368
    return local_count/global_count

def scale_model_weights(weight, scalar):
    '''function for scaling a models weights'''
    weight_final = []
    steps = len(weight)
    for i in range(steps):
        weight_final.append(scalar * weight[i])
    return weight_final

def sum_scaled_weights(scaled_weight_list):
    '''Return the sum of the listed scaled weights. The is equivalent to scaled avg of the weights'''
    new_weights = list()

    for weights_list_tuple in zip(*scaled_weight_list):
        new_weights.append(
            [np.array(weights_).mean(axis=0)\
                for weights_ in zip(*weights_list_tuple)])
    
    return new_weights

#scale the model weights and add to list
scaling_factor = weight_scalling_factor(client_batched)
scaled_weights = scale_model_weights(local_model1.get_weights(), scaling_factor)
scaled_local_weight_list.append(scaled_weights)


#########################################

#declear path to your mnist data folder
img_path = '/home/ec2-user/nitro-enclave-tensorflow/org2/covid_data/'

#get the path list using the path object
image_paths = list(paths.list_images(img_path))

#apply our function
image_list, label_list = load(image_paths, verbose=10000)

#binarize the labels
lb = LabelBinarizer()
label_list = lb.fit_transform(label_list)

#split data into training and test set
X_train, X_test, y_train, y_test = train_test_split(image_list, 
                                                    label_list, 
                                                    test_size=0.1, 
                                                    random_state=42)

data = list(zip(X_train, y_train))

#process and batch the training data for each client
client_batched = batch_data(data)
    
#process and batch the test set  
test_batched = tf.data.Dataset.from_tensor_slices((X_test, y_test)).batch(len(y_test))

smlp_local2 = SimpleMLP()
local_model2 = smlp_local2.build(1024, 4)
local_model2.compile(loss=loss, 
                optimizer=optimizer, 
                metrics=metrics)
        
#set local model weight to the weight of the global model
local_model2.set_weights(global_weights)

#fit local model with client's data
local_model2.fit(client_batched, epochs=1, verbose=0)

bs = list(client_batched)[0][0].shape[0]
local_count2 = tf.data.experimental.cardinality(client_batched).numpy()*bs
print(local_count2) #6368

#scale the model weights and add to list
scaling_factor = weight_scalling_factor(client_batched)
scaled_weights = scale_model_weights(local_model2.get_weights(), scaling_factor)
scaled_local_weight_list.append(scaled_weights)

 #to get the average over all the local model, we simply take the sum of the scaled weights
average_weights = sum_scaled_weights(scaled_local_weight_list)

npa = list()
for x in range(len(average_weights)):
    npa.append(np.asarray(average_weights[x], dtype=np.float32))

global_model.set_weights(npa)

# print(global_model.get_weights())
# print('done')



def encrypt_in_memory(incoming_bytes: bytes, public_key):
    symmetric_key = Fernet.generate_key()
    encrypted_key = rsa_base.encrypt(symmetric_key, public_key)
    encrypted_contents = Fernet(symmetric_key).encrypt(incoming_bytes)
    return encrypted_key, encrypted_contents

def load_rsa_keys():
    with open('parent_public_key.pem', 'rb') as f:
        pubkey = rsa_base.PublicKey.load_pkcs1(f.read())
    with open('parent_private_key.pem', 'rb') as f:
        privkey = rsa_base.PrivateKey.load_pkcs1(f.read())
    return (pubkey, privkey)

data = b''
(parent_public_key, parent_private_key) = load_rsa_keys()
data += parent_public_key._save_pkcs1_pem()
parent_public_key = rsa_base.PublicKey.load_pkcs1(data)
encrypted_key, encrypted_contents = encrypt_in_memory(bytes(np.array(global_model.get_weights())), parent_public_key)
print(encrypted_contents)

def decrypt_in_memory(encrypted_contents: bytes, encrypted_key: bytes, private_key):
    print('Decrypting symmetric key')
    decrypted_key = rsa_base.decrypt(encrypted_key, private_key)
    print('Decrypting contents with symmetric key')
    decrypted_contents = Fernet(decrypted_key).decrypt(encrypted_contents)
    return decrypted_contents

data = b''
(parent_public_key, parent_private_key) = load_rsa_keys()
decrypted_contents = decrypt_in_memory(encrypted_contents, encrypted_key, parent_private_key)

#print(np.array(decrypted_contents))
np.save('global_weights.npy', global_model.get_weights(), allow_pickle=True)
# b = np.load('a.npy', allow_pickle=True)


def get_public_key(public_key_path: str, get_bytes=True):
    with open(public_key_path, 'rb') as key_file:
        public_key = serialization.load_pem_public_key(
            key_file.read(),
            backend=default_backend()
        )
    public_key_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    if get_bytes:
        return public_key_bytes
    else:
        return public_key

def encrypt(file_path, public_key_path):
    public_key = get_public_key(public_key_path, get_bytes=False)
    symmetric_key = Fernet.generate_key()
    encrypted_key = public_key.encrypt(
        symmetric_key,
        padding=padding.OAEP(
            mgf=padding.MGF1(algorithm=hashes.SHA256()),
            algorithm=hashes.SHA256(),
            label=None
        )
    )
    with open(file_path, 'rb') as file_in:
        encrypted_contents = Fernet(symmetric_key).encrypt(file_in.read())
    with open(file_path+'.encrypted', 'wb') as file_out:
        file_out.write(encrypted_contents)
    return encrypted_key

#encrypted_key = encrypt('global_weights.npy', 'parent_public_key.pem')
from io import BytesIO
np_bytes = BytesIO()
np.save(np_bytes, global_model.get_weights(), allow_pickle=True)
np_bytes = np_bytes.getvalue()


load_bytes = BytesIO(np_bytes)
loaded_np = np.load(load_bytes, allow_pickle=True)




# print(b)
# print(global_model.get_weights())

#print(local_model2.get_weights())

# weights = list()
# weights.append(global_weights)
# weights.append(local_weights)

# new_weights = list()

# for weights_list_tuple in zip(*weights):
#     new_weights.append(
#         [np.array(weights_).mean(axis=0)\
#             for weights_ in zip(*weights_list_tuple)])
# print(global_weights)
# global_model.set_weights(new_weights)

# global_weights = global_model.get_weights()
# print(global_weights)


# data_string = pickle.dumps(global_weights)
# data_arr = pickle.loads(data_string)

# global_model.save('saved_model/global_model')

# new_model = tf.keras.models.load_model('saved_model/global_model')

# # Convert the model
# converter = tf.lite.TFLiteConverter.from_saved_model('saved_model/global_model') # path to the SavedModel directory
# tflite_model = converter.convert()

# # Save the model.
# with open('model.tflite', 'wb') as f:
#   f.write(tflite_model)

# # Load TFLite model and allocate tensors.
# print('loading .tflite model...')
# # TFLITE model was converted from the full h5 model stored here: https://github.com/uyxela/Skin-Lesion-Classifier/
# interpreter = tflite.Interpreter(model_path="model.tflite")
# print('done.')
# interpreter.allocate_tensors()

# # Get input and output tensors.
# input_details = interpreter.get_input_details()
# output_details = interpreter.get_output_details()

# all_layers_details = interpreter.get_tensor_details() 


# # printing the list using loop

# print(global_weights)
# print('###########################################################')
# print(npa)

arr = list()
for x in range(len(global_weights)):
    arr.append(bytes(global_weights[x]))

arr1 = list()
for x in range(len(global_weights)):
    arr1.append(np.array(global_weights[x]))

print(arr1)
    




