<script lang="ts">
	// The ordering of these imports is critical to your app working properly
	import "@skeletonlabs/skeleton/themes/theme-skeleton.css"
	// If you have source.organizeImports set to true in VSCode, then it will auto change this ordering
	import "@skeletonlabs/skeleton/styles/all.css"
	// Most of your app wide CSS should be put in this file
	import "../app.postcss"
	import { AppBar, AppRail, AppRailAnchor, AppShell } from "@skeletonlabs/skeleton"
	import { selectedAppRailItem } from "../stores/selectedAppRailItem"
</script>

<AppShell>
	<svelte:fragment slot="header">
		<AppBar>Registry Scanner</AppBar>
	</svelte:fragment>
	<svelte:fragment slot="sidebarLeft">
		<AppRail selected={selectedAppRailItem}>
			<AppRailAnchor label="Findings" value={0} tag="a" href="/findings">
				<span>Findings</span>
			</AppRailAnchor>
			<AppRailAnchor label="Import Errors" value={1} tag="a" href="/import_errors">
				<span>Import Errors</span>
			</AppRailAnchor>
		</AppRail>
	</svelte:fragment>
	<slot />
</AppShell>
