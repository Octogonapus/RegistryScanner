import { forceImportPackage } from "$lib/server/database.js"

export async function POST({ request }) {
	const body = await request.json()
	await forceImportPackage({
		registry_uuid: body.registry_uuid,
		package_uuid: body.package_uuid,
		package_name: body.package_name,
		package_repo: body.package_repo,
	})
	return new Response(null, { status: 204 })
}
