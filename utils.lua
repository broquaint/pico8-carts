----------------------
-- UTILITY functions and constants --
----------------------

IS_DEV_BUILD = true

-- Default colour palette indices (names from /r/pico8)
black = 0 storm  = 1 wine   = 2  moss  = 3
tan   = 4 slate  = 5 silver = 6  white = 7
ember = 8 orange = 9 lemon  = 10 lime  = 11
sky   = 12 dusk  = 13 pink  = 14 peach = 15

-- Alternate colour palette indices (names from /r/pico8)
cocoa   = 128 midnight  = 129 port   = 130 sea   = 131
leather = 132 charcoal  = 133 olive  = 134 sand  = 135
crimson = 136 amber     = 137 tea    = 138 jade  = 139
denim   = 140 aubergine = 141 salmon = 142 coral = 143 

screen_width = 128

dir_left  = -1
dir_right = 1

b_left  = ⬅️ b_right = ➡️
b_down  = ⬇️ b_up    = ⬆️
b_x     = ❎  b_z     = 🅾️

DEBUG_GFX = IS_DEV_BUILD and false
DEBUG = IS_DEV_BUILD and true

if DEBUG then
   printh("-- Started at " .. t())
end

function make_obj(attr)
   return merge({
      x = nil, y = nil,
      from = nil, to = nil,
      frames = nil,
      animating = false,
      alive = true,
      }, attr)
end

function dumper(...)
   local res = ''
   for v in all({...}) do
      if type(v) == 'table' then
         res = res .. tbl_to_str(v)
      elseif type(v) == 'number' then
         res = res .. ( v % 1 == 0 and v or nice_pos(v) )
      else
         res = res .. tostr(v)
      end
   end
   return res
end

function debug(...)
   if(not DEBUG) return

   printh(dumper(...))
end

function dump(...)
   printh(dumper(...))
end

__d1_tbl = {}
function dump_once(...)
   local m = dumper(...)
   if __d1_tbl[m] == nil then
      printh(m)
      __d1_tbl[m] = true
   end
end

function tbl_to_str(a)
   local res = '{'
   for k, v in pairs(a) do
      -- XXX This fails when the keys _are_ numbers (not just indices)
      local lhs = type(k) != 'number' and (k .. ' = ') or ''
      -- Special case strings so the data can easily be round tripped/formatted.
      if type(v) == 'string' then
         res = res .. lhs .. '"' .. v .. '"' .. ', '
      else
         res = res .. lhs .. dumper(v) .. ', '
      end
   end
   return sub(res, 0, #res - 2) .. "}"
end

-- Create a deep copy of a given table.
function copy_table(tbl)
   local ret = {}
   for i,v in pairs(tbl) do
      if(type(v) == 'table') then
         ret[i] = copy_table(v)
      else
         ret[i] = v
      end
   end
   return ret
end

-- Like copy_table but for any value
function clone(v)
   return type(v) == 'table' and copy_table(v) or v
end

-- Take a slice of a table.
function slice(tbl, from, to)
   from = from or 1
   to = to or #tbl
   local res = {}
   for idx = from,to do
      res[idx] = clone(tbl[idx])
   end
   return res
end

-- Add one table to another in-place.
function merge(t1, t2)
   for k,v in pairs(t2) do t1[k] = v end
   return t1
end

-- Test if a value is present in a table.
function any(t, f)
   for v in all(t) do
      if f(v) then
         return true
      end
   end
   return false
end

-- Count of occurrences in a table
function count(t, f)
   local res = 0
   for v in all(t) do
      if f(v) then
         res += 1
      end
   end
   return res
end

-- Random index.
function randx(n)
   return flr(rnd(n)) + 1
end

-- Create a randomly ordered copy of a
function shuffle(a)
   local copy = copy_table(a)
   local res = {}
   for _ = 1, #copy do
      local idx = randx(#copy)
      add(res, copy_table(copy[idx]))
      deli(copy, idx)
   end
   return res
end

-- Like sprintf %2f
function nice_pos(num)
   local s   = sgn(num)
   local n   = abs(num)
   local sig = flr(n)
   local frc = flr(n * 100 % 100)
   if(frc == 0) then
      frc = '00'
   elseif(frc < 10) then
      frc = '0' .. frc
   end
   return (s == -1 and '-' or '') .. sig .. '.' .. frc
end

-- via https://www.lexaloffle.com/bbs/?pid=78451
function spr_rotate(x,y,rot,mx,my,w,flip,scale)
  scale=scale or 1
  w*=scale*4

  local cs, ss = cos(rot)*.125/scale,sin(rot)*.125/scale
  local sx, sy = mx+cs*-w, my+ss*-w
  local hx = flip and -w or w

  local halfw = -w
  for py=y-w, y+w do
    tline(x-hx, py, x+hx, py, sx-ss*halfw, sy+cs*halfw, cs, ss)
    halfw+=1
  end
end
