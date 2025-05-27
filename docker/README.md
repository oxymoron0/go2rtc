## Versions

- `alexxit/go2rtc:latest` - latest release based on `alpine` (`amd64`, `386`, `arm/v6`, `arm/v7`, `arm64`) with support hardware transcoding for Intel iGPU and Raspberry
- `alexxit/go2rtc:latest-hardware` - latest release based on `debian 13` (`amd64`) with support hardware transcoding for Intel iGPU, AMD GPU and NVidia GPU
- `alexxit/go2rtc:latest-rockchip` - latest release based on `debian 12` (`arm64`) with support hardware transcoding for Rockchip RK35xx
- `alexxit/go2rtc:master` - latest unstable version based on `alpine`
- `alexxit/go2rtc:master-hardware` - latest unstable version based on `debian 13` (`amd64`)
- `alexxit/go2rtc:master-rockchip` - latest unstable version based on `debian 12` (`arm64`)


## Build docker image
```bash
cd ~/go2rtc
docker build --no-cache -t alexxit/go2rtc -f ./docker/Dockerfile .
```


## Build docker nvidia-ffmpeg image
> The host system must have an NVIDIA driver version 570.0 or newer installed.<br>This version is the minimum required to support NVENC API version 13.0, which was used during the FFmpeg build.<br>Use the nvidia-smi command to check the driver version."
```bash
cd ~/go2rtc
docker build --no-cache -t alexxit/go2rtc:nvidia-ffmpeg -f ./docker/hardware.nvidia.Dockerfile .
```

## Docker compose

```yaml
services:
  go2rtc:
    image: alexxit/go2rtc
    network_mode: host       # important for WebRTC, HomeKit, UDP cameras
    privileged: true         # only for FFmpeg hardware transcoding
    restart: unless-stopped  # autorestart on fail or config change from WebUI
    environment:
      - TZ=Atlantic/Bermuda  # timezone in logs
    volumes:
      - "~/go2rtc:/config"   # folder for go2rtc.yaml file (edit from WebUI)
```

## Basic Deployment

```bash
docker run -d \
  --name go2rtc \
  --network host \
  --privileged \
  --restart unless-stopped \
  -e TZ=Atlantic/Bermuda \
  -v ~/go2rtc:/config \
  alexxit/go2rtc
```

## Deployment with GPU Acceleration

```bash
docker run -d \
  --name go2rtc \
  --network host \
  --privileged \
  --restart unless-stopped \
  -e TZ=Atlantic/Bermuda \
  --gpus all \
  -v ~/go2rtc:/config \
  alexxit/go2rtc:latest-hardware
```
