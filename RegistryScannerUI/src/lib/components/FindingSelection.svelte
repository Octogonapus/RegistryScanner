<script lang="ts">
	import MultiPackageDatabaseFinding from "./MultiPackageDatabaseFinding.svelte"
	import PRFinding from "./PRFinding.svelte"
	import SinglePackageDatabaseFinding from "./SinglePackageDatabaseFinding.svelte"

	export let finding: any

	let showMultiPackageDatabaseFinding = false
	let showSinglePackageDatabaseFinding = false
	let showPRFinding = false
	$: {
		if (finding) {
			if (finding.category == "PULL_REQUEST") {
				showMultiPackageDatabaseFinding = false
				showSinglePackageDatabaseFinding = false
				showPRFinding = true
			} else {
				if (
					finding.type == "PACKAGE_NON_UNIQUE_NAME" ||
					finding.type == "PACKAGE_NON_UNIQUE_UUID" ||
					finding.type == "SHADOWED_PACKAGE"
				) {
					showMultiPackageDatabaseFinding = true
					showSinglePackageDatabaseFinding = false
					showPRFinding = false
				} else {
					showMultiPackageDatabaseFinding = false
					showSinglePackageDatabaseFinding = true
					showPRFinding = false
				}
			}
		} else {
		}
	}
</script>

<div>
	{#if showMultiPackageDatabaseFinding}
		<MultiPackageDatabaseFinding {finding} />
	{:else if showSinglePackageDatabaseFinding}
		<SinglePackageDatabaseFinding {finding} />
	{:else if showPRFinding}
		<PRFinding {finding} on:dismiss_finding />
	{/if}
</div>
