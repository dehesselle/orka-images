# Orka Images

This repository contains the build scripts that I use to create images for the Orka clusters that I manage. You can get a high-level view of what an image contains by looking at the main section of the respective `initvm.sh` scripts.

## Usage

There is no automation here to build the images. The intended use is that you spin up a VM yourself, ssh into that VM and then run the `initvm.sh` script as seen below. (You actually have to run that twice as there is a reboot to apply OS updates in between.)

Afterwards, you push the image to an OCI compatible registry and destroy the VM.

### Sonoma runner

Spin up a VM based on [`ghcr.io/macstadium/orka-images/sonoma:latest`](https://github.com/macstadium/orka-images/pkgs/container/orka-images%2Fsonoma/543062841?tag=latest). Run the following command inside that VM:

```bash
curl -L https://raw.githubusercontent.com/dehesselle/orka-images/refs/heads/main/runner-sonoma/initvm.sh | bash
```

After the initial updates, the VM will reboot. Login again and run the following command:

```bash
bash orka-images/runner-sonoma/initvm.sh
```

### Sequoia runner

Spin up a VM based on [`ghcr.io/macstadium/orka-images/sequoia:latest`](https://github.com/macstadium/orka-images/pkgs/container/orka-images%2Fsequoia/543001984?tag=latest). Run the following command inside that VM:


```bash
curl -L https://raw.githubusercontent.com/dehesselle/orka-images/refs/heads/main/runner-sequoia/initvm.sh | bash
```

After the initial updates, the VM will reboot. Login again and run the following command:

```bash
bash orka-images/runner-sequoia/initvm.sh
```

## License

This work is licensed under [GPL-2.0-or-later](LICENSE).
