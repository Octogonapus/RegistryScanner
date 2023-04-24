<script lang="ts">
	import { Table } from "@skeletonlabs/skeleton"
	import type { TableSource } from "@skeletonlabs/skeleton"
	import { createEventDispatcher } from "svelte"

	export let importErrors: any[]

	const dispatch = createEventDispatcher()

	let table: TableSource = {
		head: ["Found", "Registry UUID", "Registry Name", "Registry Repo", "Package UUID", "Package Name", "Package Repo"],
		body: importErrors.map((it) => {
			return [
				it.found,
				it.registry_uuid,
				it.registry_name,
				`<a href=${it.registry_repo}>${it.registry_repo}</a>`,
				it.package_uuid,
				it.package_name,
				`<a href=${it.package_repo}>${it.package_repo}</a>`,
			]
		}),
		meta: importErrors,
	}

	let selectedImportError: any

	let selectedPackageTable: TableSource = {
		head: ["Registry UUID", "Registry Name", "Registry Repo", "Package UUID", "Package Name", "Package Repo"],
		body: [],
	}

	let packagesInDBTable: TableSource = {
		head: ["Registry UUID", "Registry Name", "Registry Repo", "Package UUID", "Package Name", "Package Repo"],
		body: [],
	}

	async function tableOnSelected(it: any) {
		// Array for one row of the table with one element per column
		selectedImportError = it.detail
		const uuid = selectedImportError.package_uuid
		const resp = await fetch(`/packages_by_uuid/${uuid}`, { method: "GET" })
		const conflictingPackages: any[] = await resp.json()

		selectedPackageTable = {
			head: ["Registry UUID", "Registry Name", "Registry Repo", "Package UUID", "Package Name", "Package Repo"],
			body: [
				[
					selectedImportError.registry_uuid,
					selectedImportError.registry_name,
					`<a href=${selectedImportError.registry_repo}>${selectedImportError.registry_repo}</a>`,
					selectedImportError.package_uuid,
					selectedImportError.package_name,
					`<a href=${selectedImportError.package_repo}>${selectedImportError.package_repo}</a>`,
				],
			],
		}

		packagesInDBTable = {
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
		}
	}

	async function forceImportPackage() {
		await fetch("/force_import_package", {
			method: "POST",
			body: JSON.stringify(selectedImportError),
		})
		await fetch(`/import_error/${selectedImportError.id}`, { method: "DELETE" })
		dispatch("reload_import_errors")
	}
</script>

<div class="m-2">
	{#if importErrors.length == 0}
		<h3>No Import Errors</h3>
	{:else}
		{#if selectedImportError}
			<div class="m-2">
				<h3 class="mb-2">Selected Package</h3>
				<Table source={selectedPackageTable} />
				<h3 class="mb-2">Similar Packages in the Database</h3>
				<Table source={packagesInDBTable} class="pb-2" />
				<button type="button" class="btn variant-filled-warning" on:click={forceImportPackage}
					>Import Package Anyway</button
				>
			</div>
		{/if}
		<h2 class="mb-2">Package Import Errors</h2>
		<Table source={table} interactive={true} on:selected={tableOnSelected} />
	{/if}
</div>
