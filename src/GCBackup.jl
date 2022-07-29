module GCBackup
using TOML
export backup, printbaklist, rmbaklist, initbaklist

const SETTINGNAME = ".gcbackup.toml"

function _reg_ex(s::AbstractString)
    t = replace(s, "." => "\\.")
    t = replace(t, "*" => ".*")
    return Regex("^" * t * "\$")
end

function _regex_in(str::AbstractString, reg::Vector{<:Regex})
    return any(p -> occursin(p, str), reg)
end

function _regex_notin(str::AbstractString, reg::Vector{<:Regex})
    return !any(p -> occursin(p, str), reg)
end

function _read_setting(dir::AbstractString)
    if isfile(joinpath(dir, SETTINGNAME))
        s = TOML.parsefile(joinpath(dir, SETTINGNAME))
        d4tfile = s["default_include_file"]
        d4tdir = s["default_include_dir"]
        file_in = map(_reg_ex, s["include_file"])
        file_ex = map(_reg_ex, s["exclude_file"])
        dir_in = map(_reg_ex, s["include_dir"])
        dir_ex = map(_reg_ex, s["exclude_dir"])
    else
        d4tfile = false
        d4tdir = false
        file_in = Regex[]
        file_ex = Regex[]
        dir_in = Regex[]
        dir_ex = Regex[]
    end
    return (ff=d4tfile, fin=file_in, fex=file_ex, df=d4tdir, din=dir_in, dex=dir_ex)
end

function _read_lists(dir::AbstractString)
    setting  = _read_setting(dir)
    filelist = String[]
    dirlist  = String[]
    for f in readdir(dir)
        apath = joinpath(dir, f)
        if isdir(apath) && !islink(apath)
            if _regex_in(f, setting.din) || (setting.df && _regex_notin(f, setting.dex))
                push!(dirlist, f)
            end
        else
            if _regex_in(f, setting.fin) || (setting.ff && _regex_notin(f, setting.fex))
                push!(filelist, f)
            end
        end
    end
    return (filelist, dirlist)
end

function _collect_file(src::AbstractString, dst::AbstractString, show::Bool)
    (fl, dl) = _read_lists(src)
    if !isdir(dst)
        mkpath(dst)
    end

    for f in fl
        if !isfile(joinpath(dst, f))
            if show
                println(joinpath(src, f), " -> ", joinpath(dst, f))
            end
            cp(joinpath(src, f), joinpath(dst, f))
        end
    end
    return dl
end

function backup(src::AbstractString, dst::AbstractString; lshow::Bool=false)
    ds = _collect_file(src, dst, lshow)
    if !isempty(ds)
        for d in ds
            backup(joinpath(src, d), joinpath(dst, d))
        end
    end
    return nothing
end

function _print_list(src::AbstractString)
    (fl, dl) = _read_lists(src)
    for f in fl
        println(joinpath(src, f))
    end
    return dl
end

function printbaklist(src::AbstractString=".")
    ds = _print_list(src)
    if !isempty(ds)
        for d in ds
            printbaklist(joinpath(src, d))
        end
    end
    return nothing
end

"""
initbaklist(p="."; recursive=false, exclude=String[])
"""
function initbaklist(p::AbstractString="."; recursive::Bool=false, overwrite::Bool=false, excludefile::Vector{String}=String[],
    excludedir::Vector{String}=String[])
    setting = Dict("default_include_file" => true,
                   "default_include_dir" => true,
                   "include_file" => String[],
                   "exclude_file" => excludefile,
                   "include_dir" => String[],
                   "exclude_dir" => excludedir)
    if (!overwrite) && isfile(joinpath(p, SETTINGNAME))
        @warn "Setting file already exist in $(p)"
        return nothing
    end
    open(joinpath(p, SETTINGNAME), "w") do io
        TOML.print(io, setting; sorted=true)
    end
    if recursive
        for d in filter(v->isdir(v) && !islink(v), readdir(p; join=true))
            if _regex_notin(d, _reg_ex.(excludedir))
                initbaklist(d; recursive=true, overwrite=overwrite, excludefile=excludefile, excludedir=excludedir)
            end
        end
    end
    return nothing
end

function rmbaklist(dir::AbstractString; recursive::Bool=true)
    if recursive
        (_, dl) = _read_lists(dir)
        for d in dl
            rmbaklist(joinpath(dir, d))
        end
    end
    if isfile(joinpath(dir, SETTINGNAME))
        rm(joinpath(dir, SETTINGNAME))
    end
    return nothing
end
end
