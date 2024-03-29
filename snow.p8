pico-8 cartridge // http://www.pico-8.com
version 39
__lua__

#include utils.lua
#include animation.lua

function _init()
   g_anims = {}
   frame_count = 0

   snow_particles = {}
   snow_fall = {}
end

function add_snow_fall(p)
   local at_y = tostr(flr(p.y))
   if not snow_fall[at_y] then
      snow_fall[at_y] = {}
   end
   local at_x = tostr(flr(p.x))
   snow_fall[at_y][at_x] = {at_x, at_y, rnd({1,2,2,3,3,3}), 1}
end

function has_fallen(p)
   local at_x, at_y = tostr(flr(p.x)), tostr(flr(p.y))
   if snow_fall[at_y] and snow_fall[at_y][at_x] then
      return true
   end
   return false
end

function count_snow_fall()
   local c = 0
   for i, row in pairs(snow_fall) do
      for j, col in pairs(row) do
         c += 1
      end
   end
   return c
end

wobble = {-1,0,0,1}
function animate_snowflake(p)
   while p.y < 126 do
      if not p.flipping and not p.fluttering and flr(p.y) % 20 == 0 and randx(3) == 1 then
         p.dir   = wobble[randx(4)]
         p.frame = p.dir > 0 and p.frame or #p.flake
         if p.dir != 0 then
            p.flipping = 100+({20,40,60,80})[randx(4)]
            p.flipped  = 1
            p.from     = p.x
            p.to       = p.x + (p.dir*8)
         elseif not p.fluttering and p.y > 8 then
            p.fluttering = 100+({20,40,60,80})[randx(4)]
            p.flutter    = 1
            p.from       = p.y
            p.to         = p.y + 12
         end
      end

      local next_x = p.dir != 0 and lerp(p.from, p.to, easeoutquad(p.flipped/p.flipping)) or p.x
      local next_y = p.fluttering and lerp(p.from, p.to, easeoutinquad(p.flutter/p.fluttering)) or p.y + p.speed

      if has_fallen({x=next_x, y=next_y}) then
         break
      end

      if not p.is_slow and p.flipping then
         if nth_frame(p.flipping/#p.flake, p.flipped) then
            p.frame  += p.dir
            p.sprite = p.flake[p.frame]
         end
         p.flipped += 1
         if p.flipped == p.flipping then
            p.frame = 1
            p.flipping = false
            p.dir = 0
         end
      end
      if p.fluttering then
         p.flutter += 1
         if p.flutter == p.fluttering then
            p.fluttering = false
         end
      end

      p.y = next_y
      p.x = next_x
      yield()
   end
   if not p.is_slow then
      add_snow_fall(p)
   end
end

snow_speeds = {
   0.27, 0.26, 0.25, 0.24, 0.23, 0.22, 0.21, 0.2,
   0.15, 0.14, 0.13, 0.12, 0.11
}

flake_anims = {
   {0, 1, 2, 3, 4},
   {16, 17, 18, 19, 20},
}

function make_snowflake()
   local p = make_obj({
         x = -32 + randx(200),
         y = -randx(32),
         speed = snow_speeds[randx(#snow_speeds)],
         dir = 0,
         flake = rnd(flake_anims),
         frame = 1,
         flipping = false,
         fluttering = false,
   })
   p.sprite = p.flake[1]
   p.is_slow = p.speed <= 0.15
   add(snow_particles, p)
   animate_obj(p, animate_snowflake)
end

snow_decay = {white,white,silver,silver,silver,dusk}

function compact_snow()
   -- Only check twice a frame.
   if not nth_frame(30) then
      return
   end

   -- Only compact snow if there's a certain amount.
   if count_snow_fall() < 1024 then
      return
   end

   local new_fall = {}

   for y, row in pairs(snow_fall) do
      -- Not 127 because the "stops" at 126
      if y != '126' then
         local next_row = tostr(y+1)
         if nth_frame(60) then
            for idx,p in pairs(row) do
               if p[4] > 1 or (not snow_fall[tostr(y-1)] or not snow_fall[tostr(y-1)][idx]) then
                  p[4] = (p[4] < #snow_decay) and p[4]+1 or #snow_decay
               end
            end
         end
         new_fall[next_row] = row
      end
   end
   snow_fall = new_fall
end

function _update60()
   run_animations()

   if nth_frame(60) then
      for i = 1,10 do
         add(snow_particles, make_snowflake())
      end
   end

   compact_snow()

   for idx, p in pairs(snow_particles) do
      if not p.animating then
         deli(snow_particles, idx)
      end
   end

   frame_count += 1
   -- Protect against integer overflow.
   if frame_count < 0 then
      -- Reset to a point after the "build up" has passed.
      frame_count = 1600
   end
end

function _draw()
   pal(black,midnight,1)

   cls(black)

   line(0, 127, 127, 127, moss)
   for p in all(snow_particles) do
      if p.is_slow then
         pset(p.x, p.y, silver)
      else
         spr(p.sprite, p.x, p.y)
      end
   end

   for i, col in pairs(snow_fall) do
      for j, row in pairs(col) do
         local x, y, len = row[1], i+1, row[3]
         local x0 = x - (len > 1 and (len > 2 and 1 or (y % 2)) or 0)
         line(x0, y, x0+len, y, snow_decay[row[4]])
      end
   end
   end
end

__gfx__
70700000601000000700000010700000707000007070000000000000505000007070000000000000000000000000000000000000000000000000000000000000
06000000060000000600000006000000060000000700000077700000070000000700000000000000000000000000000000000000000000000000000000000000
70700000601000000700000010700000707000005050000000000000707000007070000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000d0d0000000d00000d0000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76700000060000000600000006000000767000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000d0d00000d000000000d00000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
