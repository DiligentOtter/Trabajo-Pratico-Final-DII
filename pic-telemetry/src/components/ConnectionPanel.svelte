<script lang="ts">
	import { Badge } from '$lib/components/ui/badge';
	import { Button } from '$lib/components/ui/button';
	import { Card, CardContent } from '$lib/components/ui/card';

	let {
		connected = false,
		disabled = false,
		onConnect = () => {},
		onDisconnect = () => {}
	}: {
		connected: boolean;
		disabled?: boolean;
		onConnect: () => void;
		onDisconnect: () => void;
	} = $props();
</script>

<Card>
	<CardContent class="flex items-center gap-4">
		<Badge variant={connected ? 'default' : 'secondary'}>
			{connected ? 'Conectado' : 'Desconectado'}
		</Badge>
		{#if connected}
			<Button variant="destructive" onclick={onDisconnect}>
				Desconectar
			</Button>
		{:else}
			<Button onclick={onConnect} {disabled}>
				Conectar dispositivo
			</Button>
		{/if}
	</CardContent>
</Card>
