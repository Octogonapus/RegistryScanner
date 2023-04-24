export async function dismissFinding(finding: any, dispatch: any) {
	if (finding.mergedFinding) {
		await fetch(`/finding/${finding.ids}`, { method: "DELETE" })
	} else {
		await fetch(`/finding/${finding.id}`, { method: "DELETE" })
	}
	dispatch("dismiss_finding")
}
