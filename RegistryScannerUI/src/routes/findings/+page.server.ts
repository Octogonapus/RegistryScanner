import { getFindings } from "$lib/server/database"
import type { PageServerLoad } from "./$types"

export const load = (async ({ params }) => {
	return {
		findings: await getFindings(),
	}
}) satisfies PageServerLoad
