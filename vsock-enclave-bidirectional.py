# vsock-enclave-bidirectional.py
# see Dockerfile for usage

import argparse
import socket, pickle
from struct import unpack, pack
import sys
from crypto_utils import *
from predict_tflite import classify_image_in_memory
import time
import random
import subprocess
import rsa as rsa_base
import numpy as np

random.seed()

print('Hello from within the enclave!')



class VsockStream:
    """Client"""
    def __init__(self, conn_tmo=60, conn_backlog=128):
        self.conn_tmo = conn_tmo
        self.conn_backlog = conn_backlog
        self.encrypted_weights_org1 = list()
        self.encrypted_weights_org2 = list()
        self.parent_public_key = None
        self.encrypted_weights_received_org1 = None
        self.encrypted_weights_received_org2 = None
        self.encrypted_key_received_org1 = None
        self.encrypted_key_received_org2 = None
        self.decrypted_weights_org1 = list()
        self.decrypted_weights_org2 = list()
        self.scaled_local_weight_list = list()
        self.new_weights = list()
        self.new_global_weights = list()
        self.encrypted_key = None
        self.encrypted_average_weights = list()

        self.files_received = [0, 0, 0] # --> [weights, sym key, pub key]
        self.all_files_received = False

        print('Loading enclave private/public keypair...')
        (self.enclave_public_key, self.enclave_private_key) = load_rsa_keys()
        print('done.')

    def bind(self, port):
        """Bind and listen for connections on the specified port"""
        self.sock = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
        self.sock.bind((socket.VMADDR_CID_ANY, port))
        self.sock.listen(self.conn_backlog)

    def connect(self, endpoint):
        """Connect to the remote endpoint"""
        self.sock = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
        self.sock.settimeout(self.conn_tmo)
        self.sock.connect(endpoint)

    def send_keys_enclave(self):
        length = pack('>Q', len(self.enclave_public_key._save_pkcs1_pem()))
        self.sock.sendall(length)
        print('Sending public key of length: ', str(len(self.enclave_public_key._save_pkcs1_pem())))
        self.sock.sendall(self.enclave_public_key._save_pkcs1_pem())
        print('Keys sent from enclave')
    
    def sum_scaled_weights(self, scaled_weight_list):
        '''Return the sum of the listed scaled weights. The is equivalent to scaled avg of the weights'''

        for weights_list_tuple in zip(*scaled_weight_list):
            self.new_weights.append(
                [np.array(weights_).mean(axis=0)\
                    for weights_ in zip(*weights_list_tuple)])
    
        return self.new_weights

    def average_weights_and_encryption(self, endpoint):
        if self.decrypted_weights_org1:
            print('Calculating the average of weights from org1, org2 and org3')
            self.scaled_local_weight_list.append(self.decrypted_weights_org1)
            self.scaled_local_weight_list.append(self.decrypted_weights_org2)
             #to get the average over all the local model, we simply take the sum of the scaled weights
            average_weights = self.sum_scaled_weights(self.scaled_local_weight_list)
            for x in range(len(average_weights)):
                self.new_global_weights.append(np.asarray(average_weights[x], dtype=np.float32))
        
            symmetric_key = Fernet.generate_key()
            self.encrypted_key = rsa_base.encrypt(symmetric_key, self.parent_public_key)
            for x in range(len(self.new_global_weights)):
                encrypted_content = encrypt_local_weights(self.new_global_weights[x].tobytes(), symmetric_key)
                self.encrypted_average_weights.append(encrypted_content)

            data_string = pickle.dumps(self.encrypted_average_weights)
            length = pack('>Q', len(data_string))
            print(f'Sending encrypted avergae weights of length {str(len(data_string))}')
            while True:
                try:
                    self.sock.sendall(length)
                    print('Length message sent')
                    self.sock.sendall(data_string)
                    break
                except socket.timeout:
                    time.sleep(2)
        
            length = pack('>Q', len(self.encrypted_key))
            print('Sending symmetric key of length: ', str(len(self.encrypted_key)))
            self.connect(endpoint)
            self.sock.sendall(length)
            self.sock.sendall(self.encrypted_key)
            self.sock.shutdown(socket.SHUT_RDWR)
            self.sock.close()
        else:
            print('Global gradient update failed')



    def classify_and_send_inference(self, endpoint):
        if self.image_received:
            print('Classifying image...')
            output = classify_image_in_memory(self.image_received)
            print('Generating some entropy...')
            subprocess.run('rngd -r /dev/urandom -o /dev/random', shell=True)
            print('Encrypting inference...')
            encrypted_key, encrypted_contents = encrypt_in_memory(output, self.parent_public_key)
            length = pack('>Q', len(encrypted_contents))
            print('Sending encrypted inference, length: ', str(len(encrypted_contents)))
            self.sock.sendall(length)
            self.sock.sendall(encrypted_contents)

            time.sleep(2)
            print('Sending encryption key...')
            length = pack('>Q', len(encrypted_key))
            self.connect(endpoint)
            self.sock.sendall(length)
            self.sock.sendall(encrypted_key)
            print('Length of encryption key: ', str(len(encrypted_key)))

            time.sleep(2)
            self.sock.shutdown(socket.SHUT_RDWR)
            self.sock.close()
        else:
            print('Classification unsuccessful: image not received yet.')

    def recv_data_enclave_org1(self):
        full_msg = ''
        
        (from_client, (remote_cid, remote_port)) = self.sock.accept()
        msg = from_client.recv(8)
        if len(msg) == 8:
            (length,) = unpack('>Q', msg)
            print(f'Message of length {str(length)} incoming.')
            data = b''
            while len(data) < length:
                to_read = length - len(data)
                data += from_client.recv(4096 if to_read > 4096 else to_read)
            if length > 500: # assume anything larger is our (encrypted) weights
                self.encrypted_weights_received_org1 = data
                self.encrypted_weights_org1 = pickle.loads(self.encrypted_weights_received_org1)
                print('Encrypted weights received.')
                #print(self.encrypted_weights_received)
                self.files_received[0] = 1
                if self.encrypted_key_received_org1 is not None and len(self.decrypted_weights_org1)==0:
                    # print('Generating some entropy...')
                    # subprocess.run('rngd -r /dev/urandom -o /dev/random', shell=True)
                    # time.sleep(10)
                    
                    for x in range(len(self.encrypted_weights_org1)):
                        self.decrypted_content = decrypt_local_weights(self.encrypted_weights_org1[x], self.encrypted_key_received_org1, self.enclave_private_key)
                        self.decrypted_weights_org1.append(np.frombuffer(self.decrypted_content, dtype=np.float32))
                    print('Weights decrypted')
                else:
                    print('Still waiting for key to decrypt weights for org1...')
            elif length > 200 and length < 275: # this must be our encrypted symmetric key
                self.encrypted_key_received_org1 = data
                print('Encryption key received.')
                self.files_received[1] = 1
                if self.encrypted_weights_received_org1 is not None and len(self.decrypted_weights_org1)==0:
                    # print('Generating some entropy...')
                    # subprocess.run('rngd -r /dev/urandom -o /dev/random', shell=True)
                    # time.sleep(10)
                    for x in range(len(self.encrypted_weights_org1)):
                        self.decrypted_content = decrypt_local_weights(self.encrypted_weights_org1[x], self.encrypted_key_received_org1, self.enclave_private_key)
                        self.decrypted_weights_org1.append(np.frombuffer(self.decrypted_content, dtype=np.float32))
                    print('Weights decrypted')
                else:
                    print('Have the key but still waiting for org1 weights to decrypt')
            else: # parent's public key
                self.parent_public_key = rsa_base.PublicKey.load_pkcs1(data)
                print('Parent\'s public key received.')
                self.files_received[2] = 1
        if sum(self.files_received) == 3:
            self.files_received = [0, 0]
            self.all_files_received = True
            print('All files received!')

    
    def recv_data_enclave_org2(self):
        full_msg = ''
        
        (from_client, (remote_cid, remote_port)) = self.sock.accept()
        msg = from_client.recv(8)
        if len(msg) == 8:
            (length,) = unpack('>Q', msg)
            print(f'Message of length {str(length)} incoming.')
            data = b''
            while len(data) < length:
                to_read = length - len(data)
                data += from_client.recv(4096 if to_read > 4096 else to_read)
            if length > 500: # assume anything larger is our (encrypted) weights
                self.encrypted_weights_received_org2 = data
                self.encrypted_weights_org2 = pickle.loads(self.encrypted_weights_received_org2)
                print('Encrypted weights received.')
                #print(self.encrypted_weights_received)
                self.files_received[0] = 1
                if self.encrypted_key_received_org2 is not None and len(self.decrypted_weights_org2)==0:
                    # print('Generating some entropy...')
                    # subprocess.run('rngd -r /dev/urandom -o /dev/random', shell=True)
                    # time.sleep(10)
                    
                    for x in range(len(self.encrypted_weights_org2)):
                        self.decrypted_content = decrypt_local_weights(self.encrypted_weights_org2[x], self.encrypted_key_received_org2, self.enclave_private_key)
                        self.decrypted_weights_org2.append(np.frombuffer(self.decrypted_content, dtype=np.float32))
                    print('Weights decrypted')
                else:
                    print('Still waiting for key to decrypt weights for org2...')
            else: # this must be our encrypted symmetric key
                self.encrypted_key_received_org2 = data
                print('Encryption key received.')
                self.files_received[1] = 1
                if self.encrypted_weights_received_org2 is not None and len(self.decrypted_weights_org2)==0:
                    # print('Generating some entropy...')
                    # subprocess.run('rngd -r /dev/urandom -o /dev/random', shell=True)
                    # time.sleep(10)
                    for x in range(len(self.encrypted_weights_org2)):
                        self.decrypted_content = decrypt_local_weights(self.encrypted_weights_org2[x], self.encrypted_key_received_org2, self.enclave_private_key)
                        self.decrypted_weights_org2.append(np.frombuffer(self.decrypted_content, dtype=np.float32))
                    print('Weights decrypted')
                else:
                    print('Have the key but still waiting for org2 weights to decrypt')
            # else: # parent's public key
            #     self.parent_public_key = rsa_base.PublicKey.load_pkcs1(data)
            #     print('Parent\'s public key received.')
            #     self.files_received[2] = 1
        if sum(self.files_received) == 2:
            self.all_files_received = False
            print('All files received!')


def stream_handler(args):
    print('Enclave Client starting.')
    client = VsockStream()
    endpoint = (args.cid, args.port_out)
    client.connect(endpoint)

    # send public key to parent
    print('Enclave sending keys...')
    client.send_keys_enclave()

    time.sleep(2)

    # receive encrypted weights, symmetric key, and public key
    client.bind(args.port_in)
    print('Ready to receive keys and files for org1')
    while client.all_files_received == False:
        client.recv_data_enclave_org1()
        time.sleep(2)
    
    # files_received = [0, 0, 0] # --> [weights, sym key, pub key]
    # all_files_received = False

    print('Ready to receive keys and files for org2')
    while client.all_files_received == True:
        client.recv_data_enclave_org2()
        time.sleep(2)

    # Take the average of weights and send the result back
    print('Enclave calculating the average of weights...')
    client.connect(endpoint)
    client.average_weights_and_encryption(endpoint)
    print('Average is calculated')
    # client.classify_and_send_inference(endpoint)


def main():
    parser = argparse.ArgumentParser(prog='vsock-enclave-bidirectional')
    parser.add_argument("--version", action="version",
                        help="Prints version information.",
                        version='%(prog)s 0.1.0')

    parser.add_argument("cid", type=int, help="The parent instance CID (should be 3).")
    parser.add_argument("port_in", type=int, help="The port for traffic INTO enclave.")
    parser.add_argument("port_out", type=int, help="The port for traffic OUT OF enclave.")
    parser.set_defaults(func=stream_handler)


    if len(sys.argv) < 2:
        parser.print_usage()
        sys.exit(1)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()