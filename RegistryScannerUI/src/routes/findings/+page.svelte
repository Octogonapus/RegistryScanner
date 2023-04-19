<script lang="ts">
	import FindingsTable from "$lib/components/FindingsTable.svelte"

	export let data: any

	function reloadFindings(event: any) {
		window.location.reload()
	}
</script>

<FindingsTable findings={data.findings} on:dismiss_finding={reloadFindings} />
