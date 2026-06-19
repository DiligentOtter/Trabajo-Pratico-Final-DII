<script lang="ts">
	// Terminal component — all markup is native HTML, no UI library imports needed

	let {
		logs = [],
		onClear = () => {}
	}: {
		logs: string[];
		onClear?: () => void;
	} = $props();

	let containerEl: HTMLDivElement | undefined = $state();

	$effect(() => {
		if (containerEl) {
			containerEl.scrollTop = containerEl.scrollHeight;
		}
	});
</script>

<div class="depth-card overflow-hidden" style="padding:0;">
	<!-- Header de la terminal -->
	<div
		class="flex items-center justify-between px-3.5 py-2.5"
		style="background:#FAFAF9; border-bottom: 0.5px solid rgba(0,0,0,0.06);"
	>
		<span class="section-label">Terminal</span>
		<button
			onclick={onClear}
			class="text-[11px] font-medium transition-colors"
			style="background:none; border:none; color:#C0BEB8; cursor:pointer;"
			onmouseenter={((e) => {
				e.target.style.color = '#6B6A66';
			}) as any}
			onmouseleave={((e) => {
				e.target.style.color = '#C0BEB8';
			}) as any}
		>
			Limpiar
		</button>
	</div>

	<!-- Body scrollable -->
	<div
		bind:this={containerEl}
		class="overflow-y-auto"
		style="height: 220px; background:#FAFAF9; padding: 10px 14px;"
	>
		{#if logs.length === 0}
			<p class="text-[11px]" style="color:#C0BEB8; font-family: monospace;">
				Sin datos. Conectá el dispositivo para ver la telemetría.
			</p>
		{:else}
			{#each logs as log, i}
				{@const parts = log.split(' › ')}
				<p
					class="font-mono text-[11px] leading-[1.75]"
					style="color: {i === logs.length - 1 ? '#18181B' : '#6B6A66'};"
				>
					<span style="color:#C0BEB8;">{parts[0]}</span>
					<span style="color:#D8D6CE;"> › </span>
					<span style="font-weight: {i === logs.length - 1 ? '500' : '400'};">{parts[1] ?? ''}</span
					>
				</p>
			{/each}
		{/if}
	</div>
</div>
