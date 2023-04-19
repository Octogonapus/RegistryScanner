<script lang="ts">
	import ImportErrorsTable from "$lib/components/ImportErrorsTable.svelte"

	export let data: any

	function reloadImportErrors(event: any) {
		window.location.reload()
	}
</script>

<ImportErrorsTable importErrors={data.importErrors} on:reload_import_errors={reloadImportErrors} />
