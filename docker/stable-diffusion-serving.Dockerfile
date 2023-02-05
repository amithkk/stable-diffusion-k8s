# syntax=docker/dockerfile:1
FROM nvidia/cuda:12.0.1-runtime-ubuntu22.04

ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"
RUN 

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update && \
    apt-get install -y wget fonts-dejavu-core rsync git libglib2.0-0 && \
    apt-get clean

RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir /root/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh

RUN conda install python=3.8.5 && conda clean -a -y
RUN conda install pytorch==1.11.0 torchvision==0.12.0 cudatoolkit=11.3 -c pytorch && conda clean -a -y
RUN git clone https://github.com/hlky/stable-diffusion.git && cd stable-diffusion && git reset --hard ff8c2d0b709f1e4180fb19fa5c27ec28c414cedd
RUN conda env update --file stable-diffusion/environment.yaml --name base && conda clean -a -y
RUN cd stable-diffusion && git pull && git reset --hard c5b2c86f1479dec75b0e92dd37f9357a68594bda && \
  conda env update --file environment.yaml --name base && conda clean -a -y

# Textual-inversion:
RUN <<EOF
git clone https://github.com/hlky/sd-enable-textual-inversion.git &&
cd /sd-enable-textual-inversion && git reset --hard 08f9b5046552d17cf7327b30a98410222741b070 &&
rsync -a /sd-enable-textual-inversion/ /stable-diffusion/
EOF

WORKDIR /stable-diffusion
ENV TRANSFORMERS_CACHE=/cache/transformers TORCH_HOME=/cache/torch CLI_ARGS="" \
  GFPGAN_PATH=/stable-diffusion/src/gfpgan/experiments/pretrained_models/GFPGANv1.3.pth \
  RealESRGAN_PATH=/stable-diffusion/src/realesrgan/experiments/pretrained_models/RealESRGAN_x4plus.pth \
  RealESRGAN_ANIME_PATH=/stable-diffusion/src/realesrgan/experiments/pretrained_models/RealESRGAN_x4plus_anime_6B.pth
EXPOSE 7860
CMD \
  for path in "${GFPGAN_PATH}" "${RealESRGAN_PATH}" "${RealESRGAN_ANIME_PATH}"; do \
  name=$(basename "${path}"); \
  base=$(dirname "${path}"); \
  test -f "/models/${name}" && mkdir -p "${base}" && ln -sf "/models/${name}" "${path}" && echo "Mounted ${name}";\
  done;\
  # force facexlib cache
  mkdir -p /cache/weights/ && rm -rf /stable-diffusion/src/facexlib/facexlib/weights && \
  ln -sf  /cache/weights/ /stable-diffusion/src/facexlib/facexlib/ && \
  # run, -u to not buffer stdout / stderr
  python3 -u scripts/webui.py --outdir /output --ckpt /models/model.ckpt --save-metadata ${CLI_ARGS}
