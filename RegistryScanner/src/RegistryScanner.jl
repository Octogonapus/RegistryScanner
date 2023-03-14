module RegistryScanner

using DBInterface, TOML, DataFrames, PrettyTables, MySQL, Diana, Dates, JSON, TimeZones, HTTP
using LoggingFormats, LoggingExtras
using DBInterface: execute, prepare
import Base.floor

export import_registry,
    scan_db, scan_new_package, scan_registry, scan_diff, run_service, AbstractRegistry, GitHubRegistry

const MYSQL_DATEFORMAT = DateFormat("yyyy-mm-dd HH:MM:SS")
mysql_datetime(x) = Dates.format(x, MYSQL_DATEFORMAT)

abstract type AbstractRegistry end

# TODO: make these members into traits
struct GitHubRegistry <: AbstractRegistry
    owner::AbstractString
    name::AbstractString
    base_ref_name::AbstractString
    pat_path::AbstractString
end

GitHubRegistry(owner, name, base_ref_name, pat_path) = GitHubRegistry(owner, name, base_ref_name, pat_path)

get_secret(registry::GitHubRegistry) = strip(read("/run/secrets/$(registry.pat_path)", String))

"""
    import_registry(db, registry_dir; force_update_pkgs = [])

Imports all packages from the registry into the DB.

- `force_update_pkgs`: A list of registry UUID, package UUID tuples. Any packages in this list will have their DB row updated regardless of conflicts.
"""
function import_registry(db, registry_dir; force_update_pkgs = [])
    @info "Importing registry."

    # Get all the packages using only the Package.toml files
    package_files = []
    for (root, dirs, files) in walkdir(registry_dir)
        for file in files
            if file == "Package.toml"
                push!(package_files, joinpath(root, file))
            end
        end
    end
    packages_from_registry_scan = []
    for file in package_files
        d = TOML.parsefile(file)
        push!(packages_from_registry_scan, Dict(:name => d["name"], :uuid => d["uuid"], :repo => d["repo"]))
    end
    @info "Found $(length(packages_from_registry_scan)) packages."

    # Get all the packages using only the Registry.toml file
    packages_from_registry_file = []
    registryfile = TOML.parsefile(joinpath(registry_dir, "Registry.toml"))
    for (uuid, d) in collect(registryfile["packages"])
        push!(packages_from_registry_file, Dict(:name => d["name"], :uuid => uuid))
    end
    @info "Found $(length(packages_from_registry_file)) packages in the Registry.toml file."

    @info "Validating registry consistency..."
    # Compare the two lists of packages to make sure they are the same.
    # If they are not the same, something is wrong with the registry.
    registry_is_consistent = are_package_lists_equal(packages_from_registry_file, packages_from_registry_scan)
    if !isnothing(registry_is_consistent)
        @warn "The registry has inconsistent package definitions. Package mismatches: $registry_is_consistent"
    end

    if !are_packages_unique(packages_from_registry_scan)
        @warn "The registry contains duplicate package definitions."
    end

    # Import the packages_from_registry_scan into the DB.
    # Use this over the packages_from_registry_file because it has more information.
    @info "Importing $(length(packages_from_registry_scan)) packages into the DB."

    # Import the registry first.
    idempotent_import_registry_or_fail(db, registryfile["uuid"], registryfile["name"], registryfile["repo"])

    package_import_results = DataFrame(:package => [], :successful_import => [], :exception => [])
    for package in packages_from_registry_scan
        try
            idempotent_import_package_or_fail(
                db,
                registryfile["uuid"],
                package[:uuid],
                package[:name],
                package[:repo];
                force_update_pkgs,
            )
            push!(package_import_results, Dict(:package => package, :successful_import => true, :exception => nothing))
        catch ex
            push!(package_import_results, Dict(:package => package, :successful_import => false, :exception => ex))
        end
    end
    nsuccess = nrow(filter(row -> row.successful_import, package_import_results))
    failed_packages = filter(row -> !row.successful_import, package_import_results)
    nfail = nrow(failed_packages)
    @info "Finished importing packages. Successfully imported $nsuccess. Failed to import $nfail."
    for row in eachrow(failed_packages)
        @error "Failed to import package uuid=$(row[:package][:uuid]) name=$(row[:package][:name]) repo=$(row[:package][:repo])" exception =
            row[:exception]
    end

    @info "Finished!"

    return nothing
end

"""
    idempotent_import_registry_or_fail(db, uuid, name, repo)

Imports the registry if it does not already exist or throws an error if it exists but is different.
"""
function idempotent_import_registry_or_fail(db, uuid, name, repo)
    try
        execute(prepare(db, "INSERT INTO registry VALUES (?,?,?);"), [uuid, name, repo])
        @debug "Imported registry" uuid name repo
    catch ex
        if ex isa MySQL.API.StmtError && ex.errno == 1062 # duplicate entry for primary key
            df = DataFrame(execute(prepare(db, "SELECT * FROM registry WHERE registry_uuid = ?;"), [uuid]))
            uuid_db = df[!, :registry_uuid][begin]
            name_db = df[!, :registry_name][begin]
            repo_db = df[!, :registry_repo][begin]
            if uuid_db != uuid || name_db != name || repo_db != repo
                error("Registry to import is different than existing registry in the DB. \
                To import: uuid=$uuid, name=$name, repo=$repo. \
                In DB: uuid=$uuid_db, name=$name_db, repo=$repo_db.")
            end
        else
            rethrow()
        end
    end
end

"""
    idempotent_import_package_or_fail(db, registry_uuid, package_uuid, name, repo; force_update_pkgs)

Imports the package if it does not already exist or throws an error if it exists but is different.

- `force_update_pkgs`: A list of registry UUID, package UUID tuples. Any packages in this list will have their DB row updated regardless of conflicts.
"""
function idempotent_import_package_or_fail(db, registry_uuid, package_uuid, name, repo; force_update_pkgs)
    try
        if (registry_uuid, package_uuid) ∈ force_update_pkgs
            execute(
                prepare(
                    db,
                    "INSERT INTO package VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE package_name=?, package_repo=?;",
                ),
                [package_uuid, registry_uuid, name, repo, name, repo],
            )
        else
            execute(prepare(db, "INSERT INTO package VALUES (?,?,?,?);"), [package_uuid, registry_uuid, name, repo])
        end
        @debug "Imported package" registry_uuid package_uuid name repo
    catch ex
        if ex isa MySQL.API.StmtError && ex.errno == 1062 # duplicate entry for primary key
            df = DataFrame(
                execute(
                    prepare(db, "SELECT * FROM package WHERE package_uuid = ? AND registry_uuid = ?;"),
                    [package_uuid, registry_uuid],
                ),
            )
            registry_uuid_db = df[!, :registry_uuid][begin]
            package_uuid_db = df[!, :package_uuid][begin]
            name_db = df[!, :package_name][begin]
            repo_db = df[!, :package_repo][begin]
            if registry_uuid_db != registry_uuid ||
               package_uuid_db != package_uuid ||
               name_db != name ||
               repo_db != repo
                error(
                    "Package to import is different than existing package in the DB. \
                    To import: registry_uuid=$registry_uuid, package_uuid=$package_uuid, name=$name, repo=$repo. \
                    In DB: registry_uuid_db=$registry_uuid_db, package_uuid_db=$package_uuid_db, name=$name_db, repo=$repo_db.",
                )
            end
        else
            rethrow()
        end
    end
end

function are_package_lists_equal(a, b)
    l_eq_r(l, r) = begin
        for pl in l
            idx = findfirst(it -> it[:name] == pl[:name], r)
            if isnothing(idx)
                return pl
            end
            pr = r[idx]
            if pr[:uuid] != pl[:uuid]
                return pl
            end
        end
        return nothing
    end

    a_eq_b = l_eq_r(a, b)
    b_eq_a = l_eq_r(b, a)

    return if isnothing(a_eq_b) && isnothing(b_eq_a)
        nothing
    else
        a_eq_b, b_eq_a
    end
end

function are_packages_unique(packages)
    names = map(it -> it[:name], packages)
    uuids = map(it -> it[:uuid], packages)
    return allunique(names) && allunique(uuids)
end

"""
    scan_new_package(db, package_uuid, package_name)

Scans the package against the DB for anything that is potentially malicious or otherwise bad practice:
- (error) Packages that have the same UUID.
- (warn) Packages that have the same name.

The package being scanned should not be in the DB.
This is for evaluating whether a package could be added to the registry.
"""
function scan_new_package(db, package_uuid, package_name)
    packages_with_the_same_uuid =
        DataFrame(execute(prepare(db, "SELECT * FROM package WHERE package_uuid = ?;"), [package_uuid]))
    packages_with_the_same_name =
        DataFrame(execute(prepare(db, "SELECT * FROM package WHERE package_name = ?;"), [package_name]))

    if !isempty(packages_with_the_same_uuid)
        for row in eachrow(packages_with_the_same_uuid)
            @error "PR introduces a new package with a preexisting UUID" type = "finding" scan_type = "PR" package_name =
                row[:package_name] package_uuid = row[:package_uuid]
        end
    end

    if !isempty(packages_with_the_same_name)
        for row in eachrow(packages_with_the_same_name)
            @warn "PR introduces a new package with a preexisting name" type = "finding" scan_type = "PR" package_name =
                row[:package_name] package_uuid = row[:package_uuid]
        end
    end

    return Dict(
        :packages_with_the_same_uuid => packages_with_the_same_uuid,
        :packages_with_the_same_name => packages_with_the_same_name,
    )
end

"""
    scan_db(db)

Scans the DB for anything that is potentially malicious or otherwise bad practice:
    - (error) Packages that have the same name and UUID (and are in different registries).
    - (error) Packages that use HTTP transport.
    - (error) Packages that have the same UUID.
    - (warn) Packages that have the same name.
"""
function scan_db(db)
    select_packages_by_uuid_sql = prepare(db, "SELECT * FROM package WHERE package_uuid = ?;")
    select_packages_by_name_sql = prepare(db, "SELECT * FROM package WHERE package_name = ?;")

    select_packages_by_uuid(src_packages) = begin
        packages = DataFrame()
        for row in eachrow(src_packages)
            package = DataFrame(execute(select_packages_by_uuid_sql, [row[:package_uuid]]))
            append!(packages, package)
        end
        return packages
    end

    select_packages_by_name(src_packages) = begin
        packages = DataFrame()
        for row in eachrow(src_packages)
            package = DataFrame(execute(select_packages_by_name_sql, [row[:package_name]]))
            append!(packages, package)
        end
        return packages
    end

    packages_using_http = DataFrame(execute(db, "SELECT * FROM package WHERE package_repo LIKE 'http://%';"))

    packages_with_non_unique_names = DataFrame(execute(
        db,
        "SELECT package_name, package_uuid, COUNT(package_name) FROM package
        GROUP BY package_name, package_uuid HAVING COUNT(package_name) > 1;",
    ))
    packages_with_non_unique_names = select_packages_by_name(packages_with_non_unique_names)

    packages_with_non_unique_uuids = DataFrame(execute(
        db,
        "SELECT package_name, package_uuid, COUNT(package_uuid) FROM package
        GROUP BY package_name, package_uuid HAVING COUNT(package_uuid) > 1;",
    ))
    packages_with_non_unique_uuids = select_packages_by_uuid(packages_with_non_unique_uuids)

    shadowed_packages = DataFrame(execute(
        db,
        "SELECT package_name, package_uuid, COUNT(package_name), COUNT(package_uuid)
        FROM package
        GROUP BY package_name, package_uuid
        HAVING COUNT(package_name) > 1 AND COUNT(package_uuid) > 1;",
    ))
    shadowed_packages = select_packages_by_uuid(shadowed_packages)

    if !isempty(shadowed_packages)
        for row in eachrow(shadowed_packages)
            @error "Found shadowed package" type = "finding" scan_type = "full" package_name = row[:package_name] package_uuid =
                row[:package_uuid]
        end
    end

    if !isempty(packages_using_http)
        for row in eachrow(packages_using_http)
            @error "Found packages using HTTP" type = "finding" scan_type = "full" package_name = row[:package_name] package_uuid =
                [:package_uuid]
        end
    end

    if !isempty(packages_with_non_unique_uuids)
        for row in eachrow(packages_with_non_unique_uuids)
            @error "Found packages with non-unique UUIDs" type = "finding" scan_type = "full" package_name =
                row[:package_name] package_uuid = [:package_uuid]
        end
    end

    if !isempty(packages_with_non_unique_names)
        for row in eachrow(packages_with_non_unique_names)
            @warn "Found package with non-unique name" type = "finding" scan_type = "full" package_name =
                row[:package_name] package_uuid = [:package_uuid]
        end
    end

    return Dict(
        :packages_using_http => packages_using_http,
        :packages_with_non_unique_names => packages_with_non_unique_names,
        :packages_with_non_unique_uuids => packages_with_non_unique_uuids,
        :shadowed_packages => shadowed_packages,
    )
end

"""
    scan_registry(registry::GitHubRegistry, since_time::ZonedDateTime)

Scans the GitHub repository for pull requests that introduce a new package.
"""
function scan_registry(registry::GitHubRegistry, since_time::ZonedDateTime)
    query = """
      query {
          repository(owner: "$(registry.owner)", name: "$(registry.name)") {
              pullRequests(
                  first: 100
                  orderBy: {field: UPDATED_AT, direction: DESC}
                  baseRefName: "$(registry.base_ref_name)"
                  states: [OPEN]
              ) {
                  edges {
                      node {
                          updatedAt
                          url
                          headRef {
                            name
                          }
                          files(first: 100) {
                            edges {
                              node {
                                path
                              }
                            }
                          }
                      }
                  }
              }
          }
      }
      """
    client = GraphQLClient("https://api.github.com/graphql", auth = "bearer $(get_secret(registry))")
    r = try
        client.Query(query)
    catch ex
        @error "Failed to scan registry" exception = (ex, catch_backtrace())

        # Check if we're getting rate limited
        resp = HTTP.request(
            "GET",
            "https://api.github.com/rate_limit",
            [
                "Accept" => "application/vnd.github+json",
                "Authorization" => "Bearer $(get_secret(registry))",
                "X-GitHub-Api-Version" => "2022-11-28",
            ],
        )
        @debug "rate limit check reponse" resp
        remaining = resp["resources"]["graphql"]["remaining"]
        reset = resp["resources"]["graphql"]["reset"]
        resetTime = Dates.now() - Dates.unix2datetime(reset)
        @info "GraphQL rate limit for registry $(registry.owner)/$(registry.name) has $remaining remaining and resets in $(nicetime(resetTime))"
    end
    @debug "query response" r
    d = JSON.parse(r.Data)

    pull_requests = map(it -> it["node"], d["data"]["repository"]["pullRequests"]["edges"])
    for pr in pull_requests
        @debug url = pr["url"] updatedAt = pr["updatedAt"] since_time
    end
    filter!(it -> ZonedDateTime(it["updatedAt"], dateformat"yyyy-mm-ddTHH:MM:SSz") > since_time, pull_requests)
    @debug "pull_requests after date filtering" pull_requests

    df = DataFrame(:url => [], :head_ref_name => [], :files => [])
    for pr in pull_requests
        d = Dict(
            :url => pr["url"],
            :head_ref_name => pr["headRef"]["name"],
            :files => map(it -> it["node"]["path"], pr["files"]["edges"]),
        )

        # select only new package PRs, which modify the main registry file
        if "Registry.toml" ∈ d[:files]
            push!(df, d)
        else
            @debug "Discarding PR $(d[:url]) because it does not introduce a new package"
        end
    end

    return df
end

function get_cache_dir(registry::GitHubRegistry)
    return mkpath(joinpath(ENV["CACHE_DIR"], registry.owner, registry.name))
end

function update_cache(registry::GitHubRegistry, dir = get_cache_dir(registry))
    cd(dir) do
        is_cached = ".git" ∈ readdir(dir)
        if is_cached
            @debug "Updating cache" registry dir
            run(`git checkout $(registry.base_ref_name) --`)
            run(`git pull`)
        else
            @debug "Creating new cache" registry dir
            remote = "https://$(get_secret(registry))@github.com/$(registry.owner)/$(registry.name).git"
            run(`git clone $remote .`)
        end
    end
end

"""
    scan_diff(registry::GitHubRegistry, head_ref_name)

Extracts the new package's UUID and name from a git diff.
Limitation: the diff must introduce exactly one new package and do nothing else.
"""
function scan_diff(registry::GitHubRegistry, head_ref_name)
    dir = get_cache_dir(registry)
    @debug dir
    cd(dir) do
        update_cache(registry, dir)
        run(`git checkout $head_ref_name --`)
        sout_io = IOBuffer()
        serr_io = IOBuffer()
        run(
            pipeline(
                `git diff --unified=0 $(registry.base_ref_name)...HEAD Registry.toml`,
                stdout = sout_io,
                stderr = serr_io,
            ),
        )
        resp_out = String(take!(sout_io))
        resp_err = String(take!(serr_io))
        resp = isempty(resp_out) ? resp_err : resp_out
        resp = String(strip(replace(resp, "\e[2K" => "")))
        resp = split(resp, "\n")[end]
        pkg_diff_regex = r"^\+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\s*=\s*{.*}$"
        pkg_uuid = match(pkg_diff_regex, resp).captures[begin]
        registryfile = TOML.parsefile("Registry.toml")
        pkg_name = registryfile["packages"][pkg_uuid]["name"]
        return pkg_uuid, pkg_name
    end
end

function do_registry_scans(db, registries, last_scan_time)
    for registry in registries
        @info "Updating registry $(registry.owner)/$(registry.name)"
        dir = get_cache_dir(registry)
        update_cache(registry, dir)
        import_registry(db, dir)

        @info "Scanning registry $(registry.owner)/$(registry.name)"
        pull_requests = scan_registry(registry, last_scan_time)
        @info "Found $(nrow(pull_requests)) PRs to scan"

        for pr in eachrow(pull_requests)
            @info "Scanning PR $(pr[:url])"
            pkg_uuid, pkg_name = scan_diff(registry, pr[:head_ref_name])
            @debug registry pr[:head_ref_name] pkg_uuid pkg_name
            scan_new_package(db, pkg_uuid, pkg_name)
            @info "Scan done"
        end
    end

    return nothing
end

last_scan_time_path() = joinpath(ENV["CACHE_DIR"], "last_scan_time.txt")

function load_last_scan_time()
    if !isfile(last_scan_time_path())
        time = ZonedDateTime(Dates.now(), tz"EST")
        save_last_scan_time(time)
        return time
    end

    try
        time_on_disk = strip(read(last_scan_time_path(), String))
        return ZonedDateTime(DateTime(time_on_disk), tz"EST")
    catch ex
        @error "Failed to load last scan time. Resetting it." ex = (ex, catch_backtrace())
        time = ZonedDateTime(Dates.now(), tz"EST")
        save_last_scan_time(time)
        return time
    end
end

function save_last_scan_time(time::ZonedDateTime)
    open(last_scan_time_path(), "w+") do f
        write(f, string(time.utc_datetime))
    end
    return nothing
end

function run_service()
    with_logger(FormatLogger(LoggingFormats.JSON(recursive = true), stderr)) do
        scan_interval_minutes = parse(Int, ENV["SCAN_INTERVAL_MINUTES"])

        registries = map(collect(TOML.parse(ENV["REGISTRIES_TO_SCAN"])["registries"])) do (name, properties)
            # TODO include a type property in the TOML to support more than just GitHub
            GitHubRegistry(properties["owner"], properties["name"], properties["base_ref_name"], properties["secret"])
        end

        db = retry(DBInterface.connect, delays = ExponentialBackOff(n = 3))(
            MySQL.Connection,
            ENV["DB_HOST"],
            ENV["DB_USER"],
            ENV["DB_PASS"];
            db = ENV["DB_DATABASE"],
            port = parse(Int, ENV["DB_PORT"]),
        )

        last_scan_time = load_last_scan_time()

        while true
            @info "Running registry scans"
            try
                do_registry_scans(db, registries, last_scan_time)
            catch ex
                @error "Registry scans failed" exception = (ex, catch_backtrace())
            end
            last_scan_time = ZonedDateTime(now(), tz"EST")
            save_last_scan_time(last_scan_time)

            @info "Running DB scan"
            scan_db(db)
            @info "DB scan finished"

            try
                sleep(scan_interval_minutes * 60)
            catch ex
                if ex isa InterruptException
                    break
                else
                    rethrow()
                end
            end
        end
    end
end

function repo_url_from_pr_url(pr_url)
    rx = r"^(.*)\/pull\/.*$"
    return match(rx, pr_url).captures[begin]
end

# Workaround for missing functionality comparing compound periods to periods. We don't care about losing a nanosecond
# here or there. Along the lines of https://github.com/JuliaLang/julia/issues/32389.
floor(p::Dates.CompoundPeriod, rounding_mode) = floor(Dates.Nanosecond(Dates.tons(p)), rounding_mode)

function nicetime(period::Dates.Period)
    days = floor(period, Dates.Day)
    hours = floor(period - Dates.Millisecond(days), Dates.Hour)
    minutes = floor(period - Dates.Millisecond(days) - Dates.Millisecond(hours), Dates.Minute)
    seconds =
        floor(period - Dates.Millisecond(days) - Dates.Millisecond(hours) - Dates.Millisecond(minutes), Dates.Second)
    if days > Dates.Day(0)
        return "$(Dates.value(days))d$(lpad(Dates.value(hours), 2, "0"))h$(lpad(Dates.value(minutes), 2, "0"))m$(lpad(Dates.value(seconds), 2, "0"))s"
    elseif hours > Dates.Hour(0)
        return "$(Dates.value(hours))h$(lpad(Dates.value(minutes), 2, "0"))m$(lpad(Dates.value(seconds), 2, "0"))s"
    elseif minutes > Dates.Minute(0)
        return "$(Dates.value(minutes))m$(lpad(Dates.value(seconds), 2, "0"))s"
    else
        return "$(Dates.value(seconds))s"
    end
end

function nicetime(period::Dates.CompoundPeriod)
    try
        return nicetime(convert(Dates.Second, period))
    catch ex
        @warn "Failed to convert compound period" exception = (ex, catch_backtrace())
        return "error"
    end
end

end
