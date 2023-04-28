<script lang="ts">
	import { Table } from "@skeletonlabs/skeleton"
	import type { TableSource } from "@skeletonlabs/skeleton"
	import FindingSelection from "./FindingSelection.svelte"

	export let findings: any[]

	let findingsValues = findings.map((row) => {
		if (row.category == "PULL_REQUEST") {
			return [row.found, row.body.registry_name, row.body.package_name_in_pr, row.category, row.type, row.level]
		} else {
			if (
				row.type == "PACKAGE_NON_UNIQUE_NAME" ||
				row.type == "PACKAGE_NON_UNIQUE_UUID" ||
				row.type == "SHADOWED_PACKAGE"
			) {
				return [row.found, row.body.registry_names[0], row.body.package_names[0], row.category, row.type, row.level]
			} else {
				return [row.found, row.registry_name, row.package_name, row.category, row.type, row.level]
			}
		}
	})

	const table: TableSource = {
		// A list of heading labels.
		head: ["Found", "Registry Name", "Package Name", "Category", "Type", "Level"],
		// The data visibly shown in your table body UI.
		body: findingsValues,
		// Optional: The data returned when interactive is enabled and a row is clicked.
		meta: findings,
	}

	let selectedFinding: any | undefined = null
	function tableOnSelected(it: any) {
		// Array for one row of the table with one element per column
		const row = it.detail
		selectedFinding = row
	}
</script>

<div class="m-2">
	<FindingSelection finding={selectedFinding} on:dismiss_finding />
	<h3 class="mb-1">All Findings</h3>
	<Table source={table} interactive={true} on:selected={tableOnSelected} />
</div>
