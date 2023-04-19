import { deleteFinding } from "$lib/server/database"

export async function DELETE({ params }) {
	await deleteFinding(params.id)
	return new Response(null, { status: 204 })
}
