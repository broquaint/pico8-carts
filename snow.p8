pico-8 cartridge // http://www.pico-8.com
version 39
__lua__

#include utils.lua
#include animation.lua

function _init()
   g_anims = {}
   frame_count = 0

   snow_particles = {}
end

wobble = {-1,0,1}
function animate_snowflake(p)
   while p.y < 126 do
      if(p.y % 16.0 == 0.0) p.dir = wobble[randx(3)]
      p.y += 0.25
      p.x += p.dir * 0.1
      yield()
   end
end

function make_snowflake()
   local p = make_obj({x = randx(127), y = -randx(32), dir = 1})
   add(snow_particles, p)
   animate_obj(p, animate_snowflake)
end

function _update60()
   run_animations()

   if nth_frame(60) then
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
      spr(0, p.x, p.y)
   end
end

__gfx__
70700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
