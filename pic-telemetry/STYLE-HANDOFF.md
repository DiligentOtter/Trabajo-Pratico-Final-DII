# Handoff para UI Designer — PIC Telemetry Dashboard

## Tech Stack Visual

| Capa             | Tecnología                                                 |
| ---------------- | ---------------------------------------------------------- |
| Framework        | Svelte 5 + SvelteKit                                       |
| CSS              | Tailwind CSS v4 (`@import "tailwindcss"`)                  |
| Componentes base | shadcn-svelte Nova style                                   |
| Base color       | **Zinc**                                                   |
| Iconos           | Lucide (disponible pero no usado aún)                      |
| Fuente           | `font-sans` (system-ui) para UI, `font-mono` para terminal |

## Tema (variables CSS de shadcn-svelte Nova)

El tema se resuelve en build-time vía el plugin de shadcn + Tailwind v4.
Las clases que ya se usan y sus variables asociadas:

| Clase Tailwind                            | Variable CSS         | Uso                                                                            |
| ----------------------------------------- | -------------------- | ------------------------------------------------------------------------------ |
| `bg-background`                           | `--background`       | Fondo del layout principal                                                     |
| `text-foreground`                         | `--foreground`       | Texto general                                                                  |
| `text-muted-foreground`                   | `--muted-foreground` | Labels secundarios (DISTANCIA, UMBRAL), valores null, link simulación inactivo |
| `text-blue-600`                           | `--color-blue-600`   | Link simulación activo (hardcoded)                                             |
| `border-b`, `border`                      | `--border`           | Borde inferior del header, borders de componentes                              |
| `ring-destructive`                        | `--destructive`      | Ring de alerta en card Distancia cuando D <= U                                 |
| `ring-2`, `ring-1`                        | `--ring`             | Anillos en focus y alerta                                                      |
| `rounded-lg`, `rounded-xl`, `rounded-4xl` | `--radius-*`         | Bordes de componentes shadcn                                                   |

## Componentes shadcn instalados

```
alert        → Alert, AlertDescription, AlertAction, AlertTitle
badge
button
card         → Card, CardContent, CardHeader, CardTitle, CardAction, CardDescription, CardFooter
separator    → instalado pero SIN USO (se puede eliminar si no se necesita)
```

---

## Layout General

```
┌─────────────────────────────────────────────────┐
│ Header: "Telemetría PIC"       [Simular] [Conectar] │
├─────────────────────────────────────────────────┤
│        [Alert error — condicional, variant=destructive] │
├──────────────────────┬──────────────────────────┤
│                      │                          │
│   MetricsDisplay     │   ControlPanel           │
│   ┌────────┐┌──────┐│   ┌────────────────────┐  │
│   │DISTANCIA││UMBRAL││   │ [Pausar] [Reanudar]│  │
│   │  42 cm  ││ 30cm ││   └────────────────────┘  │
│   └────────┘└──────┘│                          │
│                      │   Terminal               │
│                      │   ┌────────────────────┐ │
│                      │   │ 14:32:01 › D:42... │ │
│                      │   │ 14:32:03 › D:43... │ │
│                      │   │    ...scroll...     │ │
│                      │   └────────────────────┘ │
└──────────────────────┴──────────────────────────┘
```

Grid: `grid grid-cols-1 gap-4 p-4 md:grid-cols-2 items-start`

---

## Componentes Custom — API y estructura

### ConnectionPanel

```svelte
<ConnectionPanel
  connected={boolean}
  disabled={boolean}           // opcional, true cuando Web Serial no soportado
  onConnect={() => void}
  onDisconnect={() => void}
/>
```

**Render:**

- `<Card>` contenedor
- `<Badge variant={connected ? 'default' : 'secondary'}>` con texto "Conectado" / "Desconectado"
- Botón único que alterna:
  - `!connected`: "Conectar dispositivo" (variant por defecto)
  - `connected`: "Desconectar" (`variant="destructive"`)

---

### MetricsDisplay

```svelte
<MetricsDisplay distance={number | null} threshold={number | null} />
```

**Render:**

- Contenedor `grid grid-cols-2 gap-4`
- **Card DISTANCIA**: Label "DISTANCIA" (`text-xs text-muted-foreground uppercase tracking-widest`), valor en `text-5xl font-bold font-mono-data` + `"cm"` como `<span class="text-sm font-normal">`. Si null, muestra `"--"` en `text-muted-foreground`.
- **Card UMBRAL**: misma estructura con label "UMBRAL".
- **Alerta visual**: la Card DISTANCIA recibe `ring-2 ring-destructive` cuando `distance !== null && threshold !== null && distance <= threshold`.

---

### ControlPanel

```svelte
<ControlPanel
  connected={boolean}
  onPause={() => void}
  onResume={() => void}
/>
```

**Render:**

- `<Card>` con `<CardHeader><CardTitle>Control</CardTitle></CardHeader>`
- `<CardContent class="flex gap-2">` con dos botones:
  - "Pausar" (`variant="outline"`, `disabled={!connected}`)
  - "Reanudar" (`variant="default"`, `disabled={!connected}`)

---

### Terminal

```svelte
<Terminal
  logs={string[]}           // strings con formato "HH:MM:SS › D:42cm U:30cm"
  onClear={() => void}      // opcional, resetea logs a []
/>
```

**Render:**

- `<Card>` con `<CardHeader class="flex flex-row items-center justify-between">`
  - `<CardTitle>Terminal</CardTitle>`
  - `<Button variant="ghost" size="sm" onclick={onClear}>Limpiar</Button>`
- `<CardContent>` con `<div bind:this={containerEl} class="overflow-y-auto max-h-64 font-mono text-xs">`
  - `{#each logs as log} <p>{log}</p> {/each}`
- **Auto-scroll**: `$effect` que corre `containerEl.scrollTop = containerEl.scrollHeight`

---

## Estados Visuales

| Estado                       | UI                                                                                        |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| **Sin conexión**             | Badge "Desconectado", botón "Conectar dispositivo", controles deshabilitados              |
| **Conectado**                | Badge "Conectado", botón "Desconectar" (destructive), controles habilitados               |
| **Simulación activa**        | Link "● Simulación" en `text-blue-600 underline`, deshabilitado mientras conectado        |
| **Simulación inactiva**      | Link "○ Simular" en `text-muted-foreground`, hover → `text-foreground`                    |
| **Error**                    | `<Alert variant="destructive">` arriba del grid, con botón × para cerrar (`error = null`) |
| **Web Serial no soportado**  | Alert de error + `disabled={true}` en botón de conexión                                   |
| **Alerta de proximidad**     | Card DISTANCIA con `ring-2 ring-destructive` cuando D ≤ U                                 |
| **Valores null en métricas** | Cards muestran "--" en `text-muted-foreground`                                            |
| **Logs vacío**               | Terminal sin entries, scroll vacío                                                        |

---

## Mensajes de Error (texto congelado — NO CAMBIAR)

```
- "El puerto está en uso. Cerrá cualquier otra aplicación que lo esté usando."
- "Dispositivo desconectado inesperadamente."
- "No se pudo enviar el comando. Verificá la conexión."
- "Tu navegador no soporta Web Serial API. Usá Chrome o Edge (versión 89 o superior)."
```

---

## Lo que NO debe tocarse

- `src/lib/SimulatedSerialPort.ts` — lógica de simulación serial, no tiene UI
- `src/App.svelte` líneas 1–161 (script section con estado y lógica) — solo cambiar template HTML a partir de línea 163
- Los mensajes de error (tabla arriba) son exactos y no deben modificarse
- La clase CSS `.font-mono-data` en `src/app.css` con `font-variant-numeric: tabular-nums` — necesaria para que los números no salten visualmente
