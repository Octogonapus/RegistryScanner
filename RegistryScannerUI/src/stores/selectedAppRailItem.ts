import { browser } from "$app/environment"
import { writable } from "svelte/store"

export const selectedAppRailItem = writable(JSON.parse((browser && localStorage.selectedAppRailItem) ?? "0"))
selectedAppRailItem.subscribe((it) => {
	if (browser) {
		localStorage.selectedAppRailItem = JSON.stringify(it)
	}
})
