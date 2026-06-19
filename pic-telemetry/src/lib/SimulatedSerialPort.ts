/**
 * Puerto serie simulado para desarrollo sin hardware.
 *
 * Implementa la misma interfaz que SerialPort (open, close, readable, writable).
 * Genera tramas D:XXcm U:XXcm falsas cada ~1.5s en un ReadableStream.
 * Responde a comandos 'P' (pausa) y 'R' (reanuda) en el WritableStream.
 *
 * Uso:
 *   const port = new SimulatedSerialPort();
 *   await port.open();
 *   const reader = port.readable.getReader();
 *   const writer = port.writable.getWriter();
 *   await writer.write(new TextEncoder().encode('P')); // pausa
 */
export class SimulatedSerialPort {
	readable!: ReadableStream<Uint8Array>;
	writable!: WritableStream<Uint8Array>;

	private _controller: ReadableStreamDefaultController<Uint8Array> | null = null;
	private _timer: ReturnType<typeof setInterval> | null = null;
	private _paused = false;

	async open(): Promise<void> {
		this.readable = new ReadableStream<Uint8Array>({
			start: (controller) => {
				this._controller = controller;
				this._startEmitting();
			},
			cancel: () => {
				this._stopEmitting();
			}
		});

		this.writable = new WritableStream<Uint8Array>({
			write: async (chunk) => {
				const cmd = new TextDecoder().decode(chunk);
				if (cmd === 'P') this._paused = true;
				if (cmd === 'R') this._paused = false;
			}
		});
	}

	async close(): Promise<void> {
		this._stopEmitting();
		this._controller = null;
	}

	private _startEmitting(): void {
		const emit = () => {
			if (this._paused || !this._controller) return;

			const d = Math.floor(Math.random() * 100) + 10;
			const u = Math.floor(Math.random() * 50) + 20;
			const line = `D:${d}cm U:${u}cm\r\n`;

			try {
				this._controller.enqueue(new TextEncoder().encode(line));
			} catch {
				/* stream closed */
			}
		};

		emit();
		this._timer = setInterval(emit, 1500);
	}

	private _stopEmitting(): void {
		if (this._timer) {
			clearInterval(this._timer);
			this._timer = null;
		}
	}
}
