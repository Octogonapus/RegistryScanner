<script lang="ts">
	import { dismissFinding } from "$lib/util"
	import { Table } from "@skeletonlabs/skeleton"
	import type { TableSource } from "@skeletonlabs/skeleton"
	import { createEventDispatcher } from "svelte"

	export let finding: any

	const dispatch = createEventDispatcher()

	let title = ""
	$: {
		if (finding.type == "PREEXISTING_UUID") {
			title = "Found Package with a Pre-Existing UUID"
		} else if (finding.type == "PREEXISTING_NAME") {
			title = "Found Package with a Pre-Existing Name"
		} else if (finding.type == "PACKAGE_USES_HTTP") {
			title = "Found Package Using HTTP"
		} else {
			title = ""
		}
	}

	let table: TableSource = {
		// A list of heading labels.
		head: ["Registry UUID", "Registry Name", "Registry Repo", "Package UUID", "Package Name", "Package Repo"],
		// The data visibly shown in your table body UI.
		body: [
			[
				finding.registry_uuid,
				finding.registry_name,
				`<a href=${finding.registry_repo}>${finding.registry_repo}</a>`,
				finding.package_uuid,
				finding.package_name,
				`<a href=${finding.package_repo}>${finding.package_repo}</a>`,
			],
		],
	}

	async function onDismissFinding() {
		dismissFinding(finding, dispatch)
	}
</script>

<h3 class="mb-1">{title}</h3>
<Table source={table} />
<button type="button" class="btn variant-filled-error" on:click={onDismissFinding}>Dismiss Finding</button>
