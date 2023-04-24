<script lang="ts">
	import { dismissFinding } from "$lib/util"
	import { Table } from "@skeletonlabs/skeleton"
	import type { TableSource } from "@skeletonlabs/skeleton"
	import { createEventDispatcher } from "svelte"

	export let finding: any

	const dispatch = createEventDispatcher()

	let title = ""
	$: {
		if (finding.type == "PACKAGE_NON_UNIQUE_NAME") {
			title = "Found Multiple Packages with the Same Name"
		} else if (finding.type == "PACKAGE_NON_UNIQUE_UUID") {
			title = "Found Multiple Packages with the Same UUID"
		} else if (finding.type == "SHADOWED_PACKAGE") {
			title = "Found Shadowed Packages"
		} else {
			title = ""
		}
	}

	let table: TableSource
	$: {
		let values: any[] = []
		for (let i = 0; i < finding.body.package_names.length; i++) {
			const row = [
				finding.body.registry_uuids[i],
				finding.body.registry_names[i],
				`<a href=${finding.body.registry_repos[i]}>${finding.body.registry_repos[i]}</a>`,
				finding.body.package_uuids[i],
				finding.body.package_names[i],
				`<a href=${finding.body.package_repos[i]}>${finding.body.package_repos[i]}</a>`,
			]
			values.push(row)
		}

		table = {
			// A list of heading labels.
			head: ["Registry UUID", "Registry Name", "Registry Repo", "Package UUID", "Package Name", "Package Repo"],
			// The data visibly shown in your table body UI.
			body: values,
		}
	}

	async function onDismissFinding() {
		dismissFinding(finding, dispatch)
	}
</script>

<h3 class="mb-2">{title}</h3>
<Table source={table} class="pb-2" />
<button type="button" class="btn variant-filled-error" on:click={onDismissFinding}>Dismiss Finding</button>
