sudo yum install libXcomposite libXcursor libXi libXtst libXrandr alsa-lib mesa-libEGL libXdamage mesa-libGL libXScrnSaver -y 

sudo amazon-linux-extras install aws-nitro-enclaves-cli

sudo yum install aws-nitro-enclaves-cli-devel -y

sudo usermod -aG ne $USER

sudo usermod -aG docker $USER

sudo nano /etc/nitro_enclaves/allocator.yaml

Memory → 8192
CPU → 2

sudo systemctl start nitro-enclaves-allocator.service && sudo systemctl enable nitro-enclaves-allocator.service

sudo systemctl start docker && sudo systemctl enable docker

Reboot

sudo yum install git

git clone https://github.com/evandiewald/nitro-enclave-tensorflow.git

cd nitro-enclave-tensorflow

docker build -t enclave-tensorflow .

nitro-cli build-enclave --docker-uri enclave-tensorflow:latest --output-file enclave-tensorflow.eif


Open a new terminal

cd nitro-enclave-tensorflow


Install Pip

curl -O https://bootstrap.pypa.io/get-pip.py

python3 get-pip.py --user


pip3 install cryptography
pip3 install rsa
pip3 install pillow
pip3 install imutils
pip3 install scikit-learn
pip3 install opencv-python
pip3 install tensorflow-cpu

ImportError: /lib64/libm.so.6: version `GLIBC_2.27' not found
pip3 install open3d==0.9

python3 vsock-parent-global.py server 5006

python3 vsock-parent-local.py server 5006


Back in the first terminal

nitro-cli run-enclave --eif-path enclave-tensorflow.eif --memory 8192 --cpu-count 2 --enclave-cid 16 --debug-mode


Terminal 4

python3 FL-Local-org1.py

Terminal 5

python3 FL-Local-org2.py

EnclaveID=i-09a42d462278cc681-enc17f34c625440269

nitro-cli console --enclave-id $ENCLAVE_ID

In third terminal

python3 vsock-parent-global.py client 16 5005

python3 vsock-parent-local.py client 16 5005
