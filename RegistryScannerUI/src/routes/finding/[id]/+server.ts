import { deleteFinding } from "$lib/server/database"

export async function DELETE({ params }) {
	const ids = params.id.split(",") // id can be single- or multi-valued
	for (const id of ids) {
		await deleteFinding(id)
	}
	return new Response(null, { status: 204 })
}
