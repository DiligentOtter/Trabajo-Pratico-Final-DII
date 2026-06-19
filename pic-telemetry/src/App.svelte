<script lang="ts">
	import { onMount } from 'svelte';
	import { Alert, AlertDescription, AlertAction } from '$lib/components/ui/alert';
	import MetricsDisplay from './components/MetricsDisplay.svelte';
	import ControlPanel from './components/ControlPanel.svelte';
	import Terminal from './components/Terminal.svelte';
	import { SimulatedSerialPort } from '$lib/SimulatedSerialPort';

	// ── Estado global ──────────────────────────────────────────
	let port: SerialPort | null = $state(null);
	let connected: boolean = $state(false);
	let reader: ReadableStreamDefaultReader<Uint8Array> | null = $state(null);
	let writer: WritableStreamDefaultWriter<Uint8Array> | null = $state(null);
	let distance: number | null = $state(null);
	let threshold: number | null = $state(null);
	let logs: string[] = $state([]);
	let error: string | null = $state(null);
	let isSerialUnsupported: boolean = $state(false);
	let simulate: boolean = $state(false);

	// ── Constantes serial ──────────────────────────────────────
	const SERIAL_OPTIONS: SerialOptions = {
		baudRate: 9600,
		dataBits: 8,
		stopBits: 1,
		parity: 'none',
		flowControl: 'none'
	};

	// ── Compatibilidad ─────────────────────────────────────────
	onMount(() => {
		if (!('serial' in navigator)) {
			error = 'Tu navegador no soporta Web Serial API. Usá Chrome o Edge (versión 89 o superior).';
			isSerialUnsupported = true;
		}
	});

	function toggleSimulate() {
		simulate = !simulate;
	}

	// ── Conexión ───────────────────────────────────────────────
	async function connect() {
		if (simulate) {
			const sim = new SimulatedSerialPort();
			await sim.open();
			port = sim as unknown as SerialPort;
			connected = true;
			reader = port.readable!.getReader();
			writer = port.writable!.getWriter();
			readLoop();
			return;
		}

		if (!('serial' in navigator)) return;

		try {
			port = await navigator.serial.requestPort();
			await port.open(SERIAL_OPTIONS);
			connected = true;

			if (!port.readable || !port.writable) {
				error = 'El puerto no tiene flujos de lectura/escritura disponibles.';
				await port.close();
				connected = false;
				port = null;
				return;
			}

			reader = port.readable.getReader();
			writer = port.writable.getWriter();
			readLoop();
		} catch (e: unknown) {
			if (e instanceof Error) {
				if (e.name === 'InUseError') {
					error = 'El puerto está en uso. Cerrá cualquier otra aplicación que lo esté usando.';
				} else if (e.name !== 'NotFoundError') {
					error = e.message;
				}
			}
		}
	}

	// ── Bucle de lectura ───────────────────────────────────────
	async function readLoop() {
		let buffer = '';

		try {
			while (connected && reader) {
				const { value, done } = await reader.read();
				if (done) break;

				buffer += new TextDecoder().decode(value);

				let idx: number;
				while ((idx = buffer.indexOf('\r\n')) !== -1) {
					const line = buffer.slice(0, idx);
					buffer = buffer.slice(idx + 2);

					parseLine(line);

					const ts = new Date().toLocaleTimeString('es-AR', { hour12: false });
					logs = [...logs.slice(-199), `${ts} › ${line}`];
				}
			}
		} catch {
			error = 'Dispositivo desconectado inesperadamente.';
			disconnect();
		}
	}

	// ── Parseo de trama ────────────────────────────────────────
	function parseLine(line: string) {
		const match = line.match(/D:(\d+)cm\s+U:(\d+)cm/);
		if (match) {
			distance = parseInt(match[1]);
			threshold = parseInt(match[2]);
		}
	}

	// ── Desconexión ────────────────────────────────────────────
	async function disconnect() {
		connected = false;

		try {
			await reader?.cancel();
		} catch {
			/* ignore */
		}
		try {
			await writer?.close();
		} catch {
			/* ignore */
		}
		try {
			await port?.close();
		} catch {
			/* ignore */
		}

		reader = null;
		writer = null;
		port = null;
		distance = null;
		threshold = null;
	}

	// ── Envío de comandos ──────────────────────────────────────
	async function sendCommand(cmd: 'P' | 'R') {
		try {
			const encoded = new TextEncoder().encode(cmd);
			await writer?.write(encoded);
		} catch {
			error = 'No se pudo enviar el comando. Verificá la conexión.';
		}
	}
</script>

<div class="min-h-screen" style="background-color: var(--page-bg);">
	<!-- Header glassmorphism -->
	<header
		class="sticky top-0 z-10 flex items-center justify-between px-5 h-[52px]"
		style="background: rgba(255,255,255,0.82); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); border-bottom: 0.5px solid rgba(0,0,0,0.10);"
	>
		<span class="text-[15px] font-medium tracking-tight" style="color:#18181B;">Telemetría PIC</span
		>

		<div class="flex items-center gap-3">
			<!-- Link de simulación -->
			<button
				class="text-[11px] font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-40"
				style="background:none; border:none; cursor:pointer; color: {simulate
					? '#2563EB'
					: '#9B9A96'};"
				disabled={connected}
				onclick={toggleSimulate}
				onmouseenter={(e) => {
					if (connected) return;
					e.currentTarget.style.color = '#18181B';
				}}
				onmouseleave={(e) => {
					e.currentTarget.style.color = simulate ? '#2563EB' : '#9B9A96';
				}}
			>
				{simulate ? '● Simulación' : '○ Simular'}
			</button>

			<!-- Badge de estado -->
			{#if connected}
				<span
					class="flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[12px] font-medium"
					style="background:#F0FDF4; border: 0.5px solid #BBF7D0; color:#15803D;"
				>
					<span
						class="block w-1.5 h-1.5 rounded-full bg-green-500"
						style="box-shadow: 0 0 0 2px rgba(34,197,94,0.22);"
					></span>
					Conectado
				</span>
			{:else}
				<span
					class="rounded-full px-2.5 py-1 text-[12px] font-medium"
					style="background:#F4F4F5; border: 0.5px solid #E4E4E7; color:#71717A;"
				>
					Desconectado
				</span>
			{/if}

			<!-- Botón conectar/desconectar -->
			{#if connected}
				<button
					onclick={disconnect}
					class="rounded-[7px] px-3 py-1.5 text-[12px] font-medium transition-all"
					style="background:#FEF2F2; border: 0.5px solid #FECACA; color:#DC2626;"
					onmouseenter={(e) => {
						e.currentTarget.style.background = '#FEE2E2';
					}}
					onmouseleave={(e) => {
						e.currentTarget.style.background = '#FEF2F2';
					}}
				>
					Desconectar
				</button>
			{:else}
				<button
					onclick={connect}
					disabled={isSerialUnsupported}
					class="rounded-[7px] px-3 py-1.5 text-[12px] font-medium transition-all"
					style="background:#18181B; color:#FFFFFF; border:none; box-shadow: 0 1px 3px rgba(0,0,0,0.18);"
					class:opacity-40={isSerialUnsupported}
					onmouseenter={(e) => {
						if (isSerialUnsupported) return;
						e.currentTarget.style.background = '#27272A';
					}}
					onmouseleave={(e) => {
						e.currentTarget.style.background = '#18181B';
					}}
				>
					Conectar dispositivo
				</button>
			{/if}
		</div>
	</header>

	<!-- Alerta de error -->
	{#if error}
		<div class="mx-3.5 mt-3.5">
			<Alert variant="destructive">
				<AlertDescription class="flex items-center justify-between">
					{error}
					<button
						onclick={() => (error = null)}
						class="ml-4 text-[13px] opacity-60 hover:opacity-100 transition-opacity"
						style="background:none; border:none; cursor:pointer;"
					>
						×
					</button>
				</AlertDescription>
			</Alert>
		</div>
	{/if}

	<!-- Grid principal -->
	<main class="grid grid-cols-1 gap-3 p-3.5 md:grid-cols-2 items-start">
		<MetricsDisplay {distance} {threshold} />

		<div class="flex flex-col gap-3">
			<ControlPanel
				{connected}
				onPause={() => sendCommand('P')}
				onResume={() => sendCommand('R')}
			/>
			<Terminal {logs} onClear={() => (logs = [])} />
		</div>
	</main>
</div>
