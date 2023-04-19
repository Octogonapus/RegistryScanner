import { getPackagesByUUID } from "$lib/server/database"

export async function GET({ params }) {
	const packages = await getPackagesByUUID(params.uuid)
	return new Response(JSON.stringify(packages), {
		headers: {
			"Content-Type": "application/json",
		},
	})
}
