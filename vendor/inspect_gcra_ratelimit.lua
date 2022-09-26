local rate_limit_key = KEYS[1]
local burst = ARGV[1]
local rate = ARGV[2]
local period = ARGV[3]

local emission_interval = period / rate
local delay_variation_tolerance = emission_interval * (burst + 1)
local now = redis.call("TIME")

-- redis returns time as an array containing two integers: seconds of the epoch
-- time (10 digits) and microseconds (6 digits). for convenience we need to
-- convert them to a floating point number. the resulting number is 16 digits,
-- bordering on the limits of a 64-bit double-precision floating point number.
-- adjust the epoch to be relative to Jan 1, 2017 00:00:00 GMT to avoid floating
-- point problems. this approach is good until "now" is 2,483,228,799 (Wed, 09
-- Sep 2048 01:46:39 GMT), when the adjusted value is 16 digits.
local jan_1_2017 = 1483228800
now = (now[1] - jan_1_2017) + (now[2] / 1000000)

local tat = redis.call("GET", rate_limit_key)

if not tat then
  tat = now
else
  tat = tonumber(tat)
end

local allow_at = math.max(tat, now) - delay_variation_tolerance
local diff = now - allow_at

local remaining = math.floor(diff / emission_interval + 0.5) -- poor man's round

local reset_after = tat - now
if reset_after == 0 then
  reset_after = -1
end

local limited
local retry_after

if remaining < 1 then
  remaining = 0
  limited = 1
  retry_after = emission_interval - diff
else
  limited = 0
  retry_after = -1
end

return {limited, remaining, tostring(retry_after), tostring(reset_after)}
