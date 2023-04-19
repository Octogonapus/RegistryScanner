import knex from "knex"
import { DateTime } from "luxon"
import { env } from "process"

const db = knex({
	client: "mysql2",
	connection: {
		host: env.DB_HOST ?? "127.0.0.1",
		port: parseInt(env.DB_PORT ?? "3306"),
		user: env.DB_USER ?? "root",
		password: env.DB_PASSWORD ?? "",
		database: env.DB_DATABASE ?? "main",
		typeCast: mysqlTypeCast,
		ssl: env.SSL_SCHEME,
	},
})

export async function getFindings() {
	const resp = await db.select("*").from("finding").orderBy("found", "desc")
	for (const it of resp) {
		it["found"] = (it["found"] as DateTime).setZone("local").toLocaleString(DateTime.DATETIME_SHORT)
	}
	return uniqueFindings(resp).sort((a, b) => {
		// put errors above warnings
		if (a.level == "ERROR") {
			return -1
		} else if (b.level == "ERROR") {
			return 1
		} else {
			// keep the current order. try not to unsort the already sorted list (sorted by time from the DB)
			return 0
		}
	})
}

export async function getImportErrors() {
	const resp = await db.select("*").from("import_error").orderBy("found", "desc")
	for (const it of resp) {
		it["found"] = (it["found"] as DateTime).setZone("local").toLocaleString(DateTime.DATETIME_SHORT)
	}
	return resp
}

export async function getPackagesByUUID(uuid: string) {
	return await db
		.select("*")
		.from("package")
		.leftJoin("registry", "package.registry_uuid", "registry.registry_uuid")
		.where("package_uuid", uuid)
}

interface PackageImport {
	registry_uuid: string
	package_uuid: string
	package_name: string
	package_repo: string
}
export async function forceImportPackage(pkg: PackageImport) {
	await db("package").insert(pkg).onConflict("package_uuid").merge()
}

export async function deleteImportError(id: string) {
	await db("import_error").where("id", id).delete()
}

export async function deleteFinding(id: string) {
	await db("finding").where("id", id).delete()
}

function uniqueFindings(rows: any[]) {
	function key(it: any) {
		return JSON.stringify([it["category"], it["type"], it["level"], it["body"]])
	}

	const seen = new Set()
	return rows.filter((it) => {
		const k = key(it)
		return seen.has(k) ? false : seen.add(k)
	})
}

function mysqlTypeCast(field: any, next: any) {
	if (field.type == "DATETIME" || field.type == "DATE" || field.type == "TIME") {
		const v = field.string()
		// Set the time zone to UTC because all dates/times in the DB are in UTC. If we don't set UTC here then the
		// system time zone will be used.
		return v ? DateTime.fromSQL(v, { zone: "UTC" }) : null
	}
	return next()
}
