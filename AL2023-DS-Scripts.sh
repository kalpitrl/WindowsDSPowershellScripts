#Installing NICE DCV 
sudo rpm --import https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
sudo wget https://d1uj6qtbmh3dt5.cloudfront.net/2025.0/Servers/nice-dcv-2025.0-20103-amzn2023-x86_64.tgz
sudo tar -xvzf nice-dcv-2025.0-20103-amzn2023-x86_64.tgz && cd nice-dcv-2025.0-20103-amzn2023-x86_64
sudo dnf install nice-dcv-server-2025.0.20103-1.amzn2023.x86_64.rpm -y
sudo dnf install nice-dcv-web-viewer-2025.0.20103-1.amzn2023.x86_64.rpm -y 
sudo dnf install nice-xdcv-2025.0.688-1.amzn2023.x86_64.rpm -y
sudo dnf groupinstall "Desktop" -y
sudo systemctl set-default graphical.target
sudo reboot
sudo systemctl restart dcvserver
sudo systemctl enable dcvserver
sudo systemctl start dcvserver

#Installing Google-Chrome
sudo tee /etc/yum.repos.d/google-chrome.repo <<EOF
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
sudo dnf install google-chrome-stable -y

#Installing Git, AWS CLI
sudo dnf install git -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

#NVIDIA driver
sudo dnf install cuda-toolkit -y
sudo dnf module install nvidia-driver:open-dkms -y
sudo dnf install nvidia-gds nvidia-fabric-manager -y
sudo systemctl enable nvidia-fabricmanager nvidia-persistenced
sudo reboot
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo
sudo dnf clean all
sudo dnf makecache
sudo dnf module install nvidia-driver:latest-dkms/default -y
sudo reboot
nvidia-smi #verification
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

sudo dnf install cuda-toolkit -y
nvcc --version  # Should show CUDA 13.1
sudo systemctl enable nvidia-persistenced
sudo systemctl start nvidia-persistenced
sudo systemctl status nvidia-persistenced  # Should show active

# ===== 1-4: FIX MINICONDA PYTHON (eliminates solver conflicts)
sudo /opt/miniconda3/bin/conda install python=3.10.11 -y --force-reinstall
sudo ln -sf /opt/miniconda3/bin/python /usr/bin/python3
sudo ln -sf /opt/miniconda3/bin/pip /usr/bin/pip3
source /etc/profile.d/miniconda.sh

# ===== 5-6: PYTORCH GPU (cu124 for Tesla T4 + CUDA 12.9)
pip3 install torch==2.5.0 torchvision==0.20.0 torchaudio==2.5.0 --index-url https://download.pytorch.org/whl/cu124

# ===== 7: TENSORFLOW GPU
pip3 install tensorflow[and-cuda]

# ===== 8-11: ML PACKAGES
pip3 install scikit-learn pyspark "dask[complete]" vowpalwabbit

# ===== 12: QUICK GPU TEST
python3 -c "import torch; print('✅ PyTorch GPU:', torch.cuda.is_available(), torch.cuda.get_device_name(0))"



