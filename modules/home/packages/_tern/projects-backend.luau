--!strict
-- Nix builds the backend before activation; never compile in mutable plugin data.
local backend = {}

function backend.status(): string?
	return nil
end

function backend.ensure(cb: (string?, string?) -> ())
	cb("@backend@", nil)
end

return backend
