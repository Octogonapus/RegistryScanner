using DBInterface, MySQL, Dates, TimeZones
using RegistryScanner

db = DBInterface.connect(MySQL.Connection, "127.0.0.1", "root", "secret"; db = "main", port = 33061)

import_registry(db, joinpath(homedir(), ".julia/registries/General"))
import_registry(db, joinpath(homedir(), ".julia/registries/HolyLabRegistry"))
import_registry(db, joinpath(@__DIR__, "TestRegistry1"))

scan_db(db)

df = scan_github_registry("JuliaRegistries", "General", "master", ZonedDateTime(now() - Hour(10), tz"EST"))

run_service(
    db,
    [
        GitHubRegistry("https://github.com/JuliaRegistries/General", "master"),
        GitHubRegistry("https://github.com/HolyLab/HolyLabRegistry", "master"),
    ],
)
