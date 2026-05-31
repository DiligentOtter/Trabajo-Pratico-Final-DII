# Git workflow — simple

## Branches

```
main
  └── dev     ← todos trabajan acá
```

Una sola rama `dev`. Cada uno commit ea sus cambios. Vos mergeás a `main` cuando algo está listo.

## Cómo arrancar

```bash
git checkout -b dev
git push origin dev
```

## Por persona

```bash
# Siempre sobre dev
git checkout dev
git pull

# Trabajar (commits frecuentes, chicos)
git add HU03-ADC-DISPLAY.asm
git commit -m "HU-03: ADC + display multiplexado funcional"

# Subir
git push origin dev
```

## Vos (merge a main)

```bash
git checkout main
git pull
git merge dev
git push origin main
```

## Reglas

- Todo el mundo commit ea a `dev`
- Commits chicos y con mensaje claro
- No commitear archivos que no son tuyos
- No hacer `git push --force` nunca
- Avisar antes de mergear `dev → main`
