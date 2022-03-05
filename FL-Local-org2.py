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

#declear path to your mnist data folder
img_path = '/home/ec2-user/nitro-enclave-FL/org2/covid_data/'

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

smlp_local2 = SimpleMLP()
local_model2 = smlp_local2.build(1024, 4)
local_model2.compile(loss=loss, 
                optimizer=optimizer, 
                metrics=metrics)
        
#set local model weight to the weight of the global model
local_model2.set_weights(global_weights)

#fit local model with client's data
local_model2.fit(client_batched, epochs=1, verbose=0)



def weight_scalling_factor(client_trn_data):
    #get the bs
    bs = list(client_trn_data)[0][0].shape[0]
    #first calculate the total training data points across clinets
    global_count = (6368+6368)*32      #sum([tf.data.experimental.cardinality(clients_trn_data[org2]+clients_trn_data[org2]).numpy() for client_name in client_names])*bs
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
scaled_weights = scale_model_weights(local_model2.get_weights(), scaling_factor)
# print(scaled_weights)
# scaled_local_weight_list.append(scaled_weights)


data = b''
parent_public_key = load_keys()
data += parent_public_key._save_pkcs1_pem()
parent_public_key = rsa_base.PublicKey.load_pkcs1(data)
symmetric_key = Fernet.generate_key()
encrypted_key = rsa_base.encrypt(symmetric_key, parent_public_key)
encrypted_weights = list()
for x in range(len(scaled_weights)):
    encrypted_content = encrypt_local_weights(scaled_weights[x].tobytes(), symmetric_key)
    encrypted_weights.append(encrypted_content)

# Save the encrypted local_weights to a file
np.save('org2_local_weights.npy', encrypted_weights, allow_pickle=True)
# b = np.load('org2_local_weights.npy', allow_pickle=True)

# Save the encrypted_key to a file
f = open("org2_encrypted_key.txt", "wb")
f.write(encrypted_key)
f.close()

# org2_local_weights_encrypted = np.load('org2_local_weights.npy', allow_pickle=True)
# data_string = pickle.dumps(org2_local_weights_encrypted)
# data_arr = pickle.loads(data_string)
# print(len(org2_local_weights_encrypted))
# print(len(data_arr))
# length = pack('>Q', len(data_string))
# print(length)
# (msg,) = unpack('>Q', length)
# print(msg)






# arr = np.array(scaled_local_weight_list)

# temp = []
# for x in scaled_local_weight_list:
#     for y in x:
#         temp.append(y.tobytes())


# print(type(temp))
# print(type(temp[0]))

# temp1 =[]  
# for i in temp:
#     temp1.append(np.frombuffer(i, dtype=np.float32))
        
    

# print(scaled_local_weight_list)
# print(type(scaled_local_weight_list))
# print(len(scaled_local_weight_list))

# arr1 = arr.tobytes()
# arr2 = np.array(arr1, dtype=np.float32)
# print(arr2)


# arr = list()
# for x in range(len(global_weights)):
#     arr.append(global_weights[x].tobytes())

# arr1 = list()
# for x in range(len(arr)):
#     arr1.append(np.frombuffer(arr[x], dtype=np.float32))


