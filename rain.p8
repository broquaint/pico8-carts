pico-8 cartridge // http://www.pico-8.com
version 39
__lua__

#include utils.lua
#include animation.lua

function _init()
   g_anims = {}
   frame_count = 1
   rain_particles = {}
   wind = 0
   wind_force = 1
end

splash_map = {
   black, black, storm, slate, dusk, storm, black
}
function animate_rain(obj)
   while obj.y < 125 do
      local wind_speed = is_slow(obj) and wind_force*0.5 or wind_force
      obj.x += wind > 0 and wind*wind_speed or 0
      -- 0.8 is a lazy hack to slow all rain down.
      obj.y += 0.8*obj.speed
      yield()
   end

   obj.splashing = true
   local do_splash = randx(3) == 1
   for i = 1,7 do
      obj.sprite = i
      obj.splash = do_splash and splash_map[i] or -1
      wait(2+randx(2))
   end
   wait(1)
end

function is_slow(p)
   return p.speed < 1.25
end

function rand_tile_x()
   local x = -128+randx(256)
   x = x - (x % 3)
   function occupies_tile(p)
      return p.y < 1 and p.x == x
   end
   while any(rain_particles, occupies_tile) do
      x = -128+randx(256)
      x = x - (x % 3)
   end
   return x
end

function _update60()
   run_animations()

   if frame_count % 20 == 0 then
      for i = 1,40 do
         local rp = make_obj({
               x = rand_tile_x(),
               y = -randx(20),
               speed = min(2, 0.75+rnd()+(1.2/i)),
               splashing = false,
               splash = -1,
               sprite = 1
         })
         rp.wind_speed = is_slow(rp) and rnd()*0.5 or rnd()
         add(rain_particles, rp)
         animate_obj(rp, animate_rain)
      end
   end

   if frame_count % 30 == 0 then
      wind_force = -1+randx(2) + rnd()
   end

   if frame_count % 300 == 0 then
      local dir = wind == 0 and 1 or 0
      animate(function()
            local frames = 100
            for i = 1,frames do
               wind = dir > 0 and (i/frames) or 1-(i/frames)
               yield()
            end
      end)
   end

   for idx, p in pairs(rain_particles) do
      if not p.animating then
         deli(rain_particles, idx)
      end
   end

   frame_count += 1
end

function draw_rain(p)
   if p.splashing then
      local s = is_slow(p) and p.sprite or p.sprite+16
      spr(s, p.x, 120)
      if p.splash > 0 then
         if p.x % 2 == 0 then
            pset(p.x+2, p.y - 1, p.splash)
            pset(p.x+4, p.y - 1, p.splash)
         else
            pset(p.x+3, p.y - 1, p.splash)
         end
      end
   else
      local c = is_slow(p) and slate or dusk
      local l = wind > 0.2 and 4 or 3
      local x2 = wind > 0.2 and p.x-wind_force or p.x
      line(p.x, p.y, x2, p.y-l, c)
      if not is_slow(p) then
         pset(p.x, p.y, dusk)
      end
   end
end

function _draw()
   pal(black,midnight,1)

   cls(black)
   line(1, 127, 127, 127, storm)
   for p in all(rain_particles) do
      if is_slow(p) then
         draw_rain(p)
      end
   end
   for p in all(rain_particles) do
      if not is_slow(p) then
         draw_rain(p)
      end
   end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000010000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000100010006000600010001000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000010100000d0d00000d0d00010d0d0100010100000000000
000000000001000000011000001d10000016100000d7d00000161000001110000000000000010000000100000006000000060000000600000106010000161000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000010000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100010001000100010001000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000001010000010100000101000101010100010100000000000
00000000000100000001100000151000001d1000001d100000151000001110000000000000010000000100000001000000010000000100000101010000111000
