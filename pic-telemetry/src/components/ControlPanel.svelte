<script lang="ts">
	let {
		connected = false,
		onPause = () => {},
		onResume = () => {}
	}: {
		connected: boolean;
		onPause: () => void;
		onResume: () => void;
	} = $props();

	let lastCmd: { type: 'pause' | 'resume'; ts: string } | null = $state(null);
	let toastVisible: 'pause' | 'resume' | null = $state(null);
	let toastTimer: ReturnType<typeof setTimeout>;

	function handleCmd(type: 'pause' | 'resume') {
		type === 'pause' ? onPause() : onResume();
		lastCmd = { type, ts: new Date().toLocaleTimeString('es-AR', { hour12: false }) };
		clearTimeout(toastTimer);
		toastVisible = type;
		toastTimer = setTimeout(() => (toastVisible = null), 2200);
	}
</script>

<div class="depth-card p-4 pt-0">
	<div class="pt-4">
		<p class="section-label mb-3">Control</p>
		<div class="flex gap-2">
			<button
				onclick={() => handleCmd('pause')}
				disabled={!connected}
				class="push-btn flex-1 flex items-center justify-center gap-1.5 rounded-[8px] py-2 text-[13px] font-medium transition-all"
				style="background:#FAFAF9; border: 0.5px solid rgba(0,0,0,0.14); color:#18181B;"
				class:opacity-40={!connected}
				onmouseenter={(e) => {
					if (!connected) return;
					e.currentTarget.style.background = '#F0EFEA';
				}}
				onmouseleave={(e) => {
					e.currentTarget.style.background = '#FAFAF9';
				}}
			>
				Pausar
			</button>

			<button
				onclick={() => handleCmd('resume')}
				disabled={!connected}
				class="push-btn flex-1 flex items-center justify-center gap-1.5 rounded-[8px] py-2 text-[13px] font-medium transition-all"
				style="background:#18181B; color:#FFFFFF; border:none; box-shadow: 0 1px 3px rgba(0,0,0,0.18);"
				class:opacity-40={!connected}
				onmouseenter={(e) => {
					if (!connected) return;
					e.currentTarget.style.background = '#27272A';
				}}
				onmouseleave={(e) => {
					e.currentTarget.style.background = '#18181B';
				}}
			>
				Reanudar
			</button>
		</div>

		<!-- Chip de último comando -->
		<div
			style="display:flex; align-items:center; gap:7px; padding:6px 10px; border-radius:7px; margin-top:10px; background:#F4F4F5; border:0.5px solid rgba(0,0,0,0.07);"
			class:opacity-50={!lastCmd}
		>
			<span
				style="width:6px; height:6px; border-radius:50%; flex-shrink:0; background:{!lastCmd
					? '#D4D4D8'
					: lastCmd.type === 'pause'
						? '#F59E0B'
						: '#22C55E'};"
			>
			</span>

			<span style="font-size:11px; font-weight:500; color:#52525B; flex:1;">
				{#if !lastCmd}Sin comandos enviados
				{:else if lastCmd.type === 'pause'}Pausa (P · 0x50)
				{:else}Reanudación (R · 0x52)
				{/if}
			</span>

			{#if lastCmd}
				<span style="font-size:10px; color:#A1A1AA; font-variant-numeric:tabular-nums;">
					{lastCmd.ts}
				</span>
			{/if}
		</div>
	</div>
</div>

<!-- Toast flotante -->
{#if toastVisible}
	<div
		style="position:fixed; top:16px; right:16px; z-index:50; background:#18181B; color:#FFFFFF; font-size:12px; font-weight:500; padding:8px 12px; border-radius:9px; box-shadow:0 4px 16px rgba(0,0,0,0.18); display:flex; align-items:center; gap:8px; animation:fadeSlideIn 0.18s ease;"
	>
		{#if toastVisible === 'pause'}
			<span style="opacity:0.6; font-size:10px;">⏸</span> Pausa enviada · byte 0x50
		{:else}
			<span style="opacity:0.6; font-size:10px;">▶</span> Reanudación enviada · byte 0x52
		{/if}
	</div>
{/if}

<style>
	.push-btn:active {
		transform: scale(0.96);
	}

	.push-btn:disabled:active {
		transform: none;
	}

	@keyframes fadeSlideIn {
		from {
			opacity: 0;
			transform: translateY(-6px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}
</style>
