--[[ ------------------------------------------------------------------
  EMERGENCY STOP - Figment 2

  Run this if Cheat Engine becomes sluggish or stops responding after
  f2_resolve.lua has been executed.

  Cause: the keeper is a CE timer, and CE timers run on the MAIN thread - the
  same thread that serves the MCP bridge, the GUI, and every Lua call. If a
  tick does expensive work (a Mono heap scan takes SECONDS) and outlasts its
  interval, ticks pile up and CE is starved permanently. It looks exactly like
  the bridge has crashed.

  If CE is too unresponsive to even run this, just restart Cheat Engine -
  timers do not survive a restart, and nothing here is persistent. The game
  process is untouched.
------------------------------------------------------------------------- ]]

local stopped = 0

-- the named keeper
if F2_KEEPER ~= nil then
  pcall(function() F2_KEEPER.Enabled = false end)
  pcall(function() F2_KEEPER.destroy() end)
  F2_KEEPER = nil
  stopped = stopped + 1
end
F2_KEEPER_BUSY = false

-- unfreeze every cheat-table entry (freezes also run on the main thread)
local thawed = 0
local ok = pcall(function()
  local al = getAddressList()
  for i = 0, al.Count - 1 do
    local r = al[i]
    if r and r.Active then r.Active = false; thawed = thawed + 1 end
  end
end)

print(string.format("[F2] emergency stop: timers=%d unfrozen=%d (ok=%s)",
  stopped, thawed, tostring(ok)))
print("[F2] CE should respond normally now. Re-run f2_resolve.lua to reapply.")
