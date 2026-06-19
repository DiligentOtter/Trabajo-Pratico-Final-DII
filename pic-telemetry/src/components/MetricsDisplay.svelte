<script lang="ts">
	let {
		distance = null,
		threshold = null
	}: {
		distance: number | null;
		threshold: number | null;
	} = $props();
</script>

<div class="grid grid-cols-2 gap-3">
	<!-- Card DISTANCIA -->
	<div
		class="depth-card p-4 pt-0"
		class:depth-card--alert={distance !== null && threshold !== null && distance <= threshold}
	>
		<div class="pt-4">
			<p class="section-label mb-2">Distancia</p>
			{#if distance !== null}
				<p class="metric-number font-mono-data">
					{distance}<span class="text-sm font-normal text-[#9B9A96] ml-1">cm</span>
				</p>
				<p
					class="text-[11px] mt-1.5"
					style="color: {distance !== null && threshold !== null && distance <= threshold
						? '#FCA5A5'
						: '#C0BEB8'}"
				>
					{distance !== null && threshold !== null && distance <= threshold
						? '⚠ Por debajo del umbral'
						: 'Sensor activo'}
				</p>
			{:else}
				<p class="metric-number font-mono-data text-[#C0BEB8]">--</p>
				<p class="text-[11px] mt-1.5" style="color:#C0BEB8">Sin señal</p>
			{/if}
		</div>
	</div>

	<!-- Card UMBRAL -->
	<div class="depth-card p-4 pt-0">
		<div class="pt-4">
			<p class="section-label mb-2">Umbral</p>
			{#if threshold !== null}
				<p class="metric-number font-mono-data">
					{threshold}<span class="text-sm font-normal text-[#9B9A96] ml-1">cm</span>
				</p>
				<p class="text-[11px] mt-1.5" style="color:#C0BEB8">Valor de referencia</p>
			{:else}
				<p class="metric-number font-mono-data text-[#C0BEB8]">--</p>
				<p class="text-[11px] mt-1.5" style="color:#C0BEB8">Sin señal</p>
			{/if}
		</div>
	</div>
</div>
