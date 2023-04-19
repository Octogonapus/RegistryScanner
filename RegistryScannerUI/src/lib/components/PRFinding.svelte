<script lang="ts">
	import { Table } from "@skeletonlabs/skeleton"
	import type { TableSource } from "@skeletonlabs/skeleton"
	import { createEventDispatcher } from "svelte"

	export let finding: any

	const dispatch = createEventDispatcher()

	let title = ""
	$: {
		if (finding.type == "PREEXISTING_UUID") {
			title = "Found Pull Request Introducing Package with a Pre-Existing UUID"
		} else if (finding.type == "PREEXISTING_NAME") {
			title = "Found Pull Request Introducing Package with a Pre-Existing Name"
		} else {
			title = ""
		}
	}

	$: packageInPRTable = {
		head: [
			"Pull Request",
			"Registry UUID",
			"Registry Name",
			"Registry Repo",
			"Package UUID",
			"Package Name",
			"Package Repo",
		],
		body: [
			[
				`<a href=${finding.body.pr_url}>${finding.body.pr_url}</a>`,
				finding.body.registry_uuid,
				finding.body.registry_name,
				`<a href=${finding.body.registry_repo}>${finding.body.registry_repo}</a>`,
				finding.body.package_uuid_in_pr,
				finding.body.package_name_in_pr,
				`<a href=${finding.body.package_repo_in_pr}>${finding.body.package_repo_in_pr}</a>`,
			],
		],
	}

	async function getPackagesInDBTable() {
		let resp = await fetch(`/packages_by_uuid/${finding.body.package_uuid_in_db}`, { method: "GET" })
		let conflictingPackages: any[] = await resp.json()
		return {
			head: ["Registry UUID", "Registry Name", "Registry Repo", "Package UUID", "Package Name", "Package Repo"],
			body: conflictingPackages.map((it) => {
				return [
					it.registry_uuid,
					it.registry_name,
					`<a href=${it.registry_repo}>${it.registry_repo}</a>`,
					it.package_uuid,
					it.package_name,
					`<a href=${it.package_repo}>${it.package_repo}</a>`,
				]
			}),
		} as TableSource
	}

	async function dismissFinding() {
		await fetch(`/finding/${finding.id}`, { method: "DELETE" })
		dispatch("dismiss_finding")
	}

	let packagesInDBTable = getPackagesInDBTable()
</script>

<div class="m-2">
	<h3 class="mb-2">{title}</h3>
	<h4 class="mb-2">Package in Pull Request</h4>
	<Table source={packageInPRTable} />
	<h4 class="mb-2">Package in Database</h4>
	{#await packagesInDBTable then table}
		<Table source={table} class="pb-2" />
	{/await}
	<button type="button" class="btn variant-filled-error" on:click={dismissFinding}>Dismiss Finding</button>
</div>
