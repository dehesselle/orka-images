# Orka Images

TBD

## Build

```bash
mkdir orka-images
curl -L https://github.com/dehesselle/orka-images/archive/refs/heads/main.zip | bsdtar -C orka-images --strip-components 1 -xvf-
bash orka-images/runner/initvm.sh runner
```
