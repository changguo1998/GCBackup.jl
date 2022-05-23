module GCBackup
    export backup, printbaklist, rmbaklist, initbaklist

    const INCLUDEFILENAME = ".gcbakup"
    const IGNOREDIRNAME  = ".gcbaksearchignore"

    function _read_lists(dir::AbstractString)
        filelist = String[]
        if isfile(joinpath(dir, INCLUDEFILENAME))
            t = readlines(joinpath(dir, INCLUDEFILENAME))
            for i in t
                if !isempty(i)
                    if isfile(joinpath(dir, i))
                        push!(filelist, i)
                    end
                end
            end
        end
        dirlist  = String[]
        for i in readdir(dir)
            if isdir(joinpath(dir, i))
                push!(dirlist, i)
            end
        end
        ignlist = isfile(joinpath(dir, IGNOREDIRNAME)) ? readlines(joinpath(dir, IGNOREDIRNAME)) : String[]
        return (filelist, filter(x->!(x in ignlist), dirlist))
    end

    function _collect_file(src::AbstractString, dst::AbstractString)
        (fl, dl) = _read_lists(src)
        for f in fl
            if !isfile(joinpath(dst, f))
                if !isdir(dst)
                    mkdir(dst)
                end
                println(joinpath(src, f))
                cp(joinpath(src, f), joinpath(dst, f))
            end
        end
        return dl
    end

    function backup(src::AbstractString, dst::AbstractString)
        ds = _collect_file(src, dst)
        if !isempty(ds)
            for d in ds
                backup(joinpath(src, d), joinpath(dst, d))
            end
        end
        return nothing
    end

    function _print_file(src::AbstractString)
        (fl, dl) = _read_lists(src)
        for f in fl
            println(joinpath(src, f))
        end
        return dl
    end

    function printbaklist(src::AbstractString=".")
        ds = _print_file(src)
        if !isempty(ds)
            for d in ds
                printbaklist(joinpath(src, d))
            end
        end
        return nothing
    end

    function initbaklist(p::AbstractString = "."; recursive::Bool = false)
        includes = readdir(p)
        searchdir = String[]
        open(joinpath(p, INCLUDEFILENAME), "w") do io
            for s in includes
                if (s == INCLUDEFILENAME) || (s == IGNOREDIRNAME) || isempty(s)
                    continue
                end
                if isfile(joinpath(p, s))
                    println(io, s)
                end
                if recursive && isdir(joinpath(p, s))
                    push!(searchdir, s)
                end
            end
        end
        open(joinpath(p, IGNOREDIRNAME), "w") do io
            print("")
        end
        if recursive
            for d in searchdir
                initbaklist(joinpath(p, d), recursive=true)
            end
        end
        return nothing
    end

    function rmbaklist(dir::AbstractString="."; recursive::Bool = true)
        if isfile(joinpath(dir, IGNOREDIRNAME))
            println("rm ", joinpath(dir, IGNOREDIRNAME))
            rm(joinpath(dir, IGNOREDIRNAME))
        end
        if isfile(joinpath(dir, INCLUDEFILENAME))
            println("rm ", joinpath(dir, INCLUDEFILENAME))
            rm(joinpath(dir, INCLUDEFILENAME))
        end
        if recursive
            (_, ds) = _read_lists(dir)
            for d in ds
                if isdir(joinpath(dir, d))
                    rmbaklist(joinpath(dir, d); recursive=recursive)
                end
            end
        end
        return nothing
    end
end
