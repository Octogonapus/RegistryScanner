import { getImportErrors } from "$lib/server/database"
import type { PageServerLoad } from "./$types"

export const load = (async ({ params }) => {
	return {
		importErrors: await getImportErrors(),
	}
}) satisfies PageServerLoad
