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
   local at_y = flr(p.y)
   if not snow_fall[at_y] then
      snow_fall[at_y] = {}
   end
   local at_x = flr(p.x)
   snow_fall[at_y][at_x] = {at_x,at_y}
end

function has_fallen(p)
   local at_x, at_y = flr(p.x), flr(p.y)
   if snow_fall[at_y] and snow_fall[at_y][at_x] then
      return true
   end
   return false
end

wobble = {-1,0,1}
function animate_snowflake(p)
   while p.y < 126 do
      if p.y % 20.0 == 0.0 and randx(3) == 1 then
            p.dir = wobble[randx(3)]
            p.flipping = 40
      end
      local next_x, next_y = p.x+(p.dir*0.1), p.y + 0.25
      if has_fallen({x=next_x, y=next_y}) then
         break
      end
      if p.flipping and p.dir != 0 then
         if nth_frame(10, p.flipping) then
            p.sprite = (p.sprite + p.dir) % 4
         end
         p.flipping -= 1
         if(p.flipping == 0) p.flipping = false
      end
      p.y = next_y
      p.x = next_x
      yield()
   end
   add_snow_fall(p)
end

function make_snowflake()
   local p = make_obj({x = randx(127), y = -randx(32), dir = 1, sprite = 0, flipping=false})
   add(snow_particles, p)
   animate_obj(p, animate_snowflake)
end

function _update60()
   run_animations()

   if nth_frame(90) then
      for i = 1,10 do
         add(snow_particles, make_snowflake())
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
      spr(p.sprite, p.x, p.y)
   end
end

__gfx__
70700000700000000700000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000070000000700000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70700000700000000700000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
