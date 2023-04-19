import { deleteImportError } from "$lib/server/database"

export async function DELETE({ params }) {
	await deleteImportError(params.id)
	return new Response(null, { status: 204 })
}
