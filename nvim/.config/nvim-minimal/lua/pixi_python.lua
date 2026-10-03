-- Resolve Python interpreters from project-local and shared Pixi environments.
local M = {}

local cad_projects = vim.fs.normalize(vim.fn.expand("~/Projects/cad"))
local cad_manifest = vim.fs.normalize(vim.fn.expand("~/.local/share/envs/cadquery/pixi.toml"))

local function within(path, root)
  path = vim.fs.normalize(path or "")
  return path == root or vim.startswith(path, root .. "/")
end

local function project_manifest(path)
  if not path or path == "" then
    return nil
  end
  local stat = vim.uv.fs_stat(path)
  local found = vim.fs.find("pixi.toml", {
    path = stat and stat.type == "directory" and path or vim.fs.dirname(path),
    upward = true,
    type = "file",
  })[1]
  if found then
    return vim.fs.normalize(found)
  end
  if within(path, cad_projects) and vim.fn.filereadable(cad_manifest) == 1 then
    return cad_manifest
  end
end

local function python_in(manifest)
  local path = vim.fs.joinpath(vim.fs.dirname(manifest), ".pixi", "envs", "default", "bin", "python")
  return vim.fn.executable(path) == 1 and path or nil
end

function M.interpreter(path)
  if not path or path == "" then
    return nil
  end
  local manifest = project_manifest(path)
  if manifest then
    return python_in(manifest)
  end
  -- `pixi shell` exposes the selected environment through CONDA_PREFIX.
  local prefix = vim.env.CONDA_PREFIX
  if prefix then
    local python = vim.fs.joinpath(prefix, "bin", "python")
    if vim.fn.executable(python) == 1 then
      return python
    end
  end
end

return M
