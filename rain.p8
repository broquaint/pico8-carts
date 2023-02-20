pico-8 cartridge // http://www.pico-8.com
version 39
__lua__

#include utils.lua
#include animation.lua

function _init()
   g_anims = {}
   frame_count = 1
   rain_particles = {}
   title_colour = title_fade[1]
   wind = 0
   wind_force = 1
   music(0,10000)
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

title_fade = {
   dusk,
   denim,
   storm,
   midnight
}

function _update60()
   run_animations()

   if frame_count % 120 == 0 then
      if #title_fade > 0 then
         title_colour = deli(title_fade, 1)
      end
   end

   if frame_count % 20 == 0 then
      local rain_amount = min(40, frame_count / 40)
      rain_amount = rain_amount == 40 and rain_amount * (0.5 + rnd()*0.5) or rain_amount
      for i = 1,rain_amount do
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

   if frame_count % 90 == 0 then
      local n = rnd()
      local new_force = n > 0.5 and n or 1+n
      animate(function()
            for i = 1,30 do
               wind_force = (i/30)*new_force
               yield()
            end
      end)
   end

   if frame_count % 300 == 0 and randx(4) == 1 then
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
   -- Protect against integer overflow.
   if frame_count < 0 then
      -- Reset to a point after the "build up" has passed.
      frame_count = 1600
   end
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

   if #title_fade > 0 then
      pal(moss, title_colour, 1)
      sspr(0, 32, 127, 32, 6, 32)
   end

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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000333330000000000000000000000000000000000000000000000000000
00000000000333333330000000000000000000000000000000000000000000000003333333333300000000000000000000000000000000000000000000000000
00000000333333333333333300000000000000000000000000000000000000000003333300333300000000000000000000000000000000000000000000000000
00000033333333300003333330000000000000000000000000330000000000000003330000003330000000000000000000000000000000000000000000000000
00003333330033300000003333000000000000000000000000333000000000000003300000003333000000000000000000000000000000000000000000000000
00033330000033300000000333300000000000000000000000333000000000000003300000000333000000000000000000000000000000000000000000000000
00033300000033300000000003300000000000000000000000033000000000000003300000000033000000000000000000000000000000000000000000000000
00033000000033300000000000000000000000000000000000033000000000000033300000000033000000000000000000000000000000000000000000000000
00000000000003300000000000000000000000000000000000033000000000000033000000000333000000000000000000000000000000000000000000000000
00000000000003300000000000000000000000000000000000033333330000000033000000033330000000000000000000000000000000000000000000000000
00000000000003300000000000000000000000000000000003333333330000000033000000333300000000000000000000330000000000000000000000000000
00000000000003300000000000000000000000000000000033333000000000000333033333333000000000000000000000330000000000000000000000000000
00000000000003300000000000000000000000000000000333333000000000000333333333300000000000000000000000000000000000000000000000000000
00000000000003300000000000000000000000000000000330033000000000000333333333000000000333333000000000000000000000000000000000000000
00000000000003300000000000000000000033333330000000033000000000000330003333300000003333333333000000330000033000000000000000000000
00000000000003300000000000000000000033333333000000033000000000003330000033330000033330003333000000330000033000333330000000000000
00000000000003300000333000000330000333000333000000333000000000003330000003333000333000000333000000330000033033333333000000000000
00000000000003300000333000003330000333000033000000330000000000003300000000333000333000003330000000330000033333330033000000000000
00000000000033300003330000003300000033330000000003330000000000003300000000033300330000003330000000330000033330000033000000000000
00000000000033000003330000003300000033333300000003330000000000003300000000033300330000003330000000330000333300000033000000000000
00000000000333000003300000033300000000333300000003300000000000033300000000003300330000333300000000330000333000000033000000000000
33300000000333000003300000033000003300003330000033300000000000033000000000003300333003333300000000330000330000000333000000000000
33330000003330000003300000333000003330003330000033000000000000033000000000003300333333333300000003330003330000003333000000000000
03333333333300000003333003330000003330000330000333000000000000033000000000003300033333303300000003330003330000003330000000000000
03333333330000000000333333330000000333333330000330000000000000033000000000003300000000003333000003300033300000003300000000000000
00000000000000000000033333000000000033333300000330000000000000000000000000000000000000003333000033300033300000003300000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033000033000000003300000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000
000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000
000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000
__sfx__
90150000006100261102611026110c6110c6110c6110c6110c6110c6110c6110761107611076110761107611076110661102611026110261102611026110261102611056110c6110061100611006110061100611
49140000006100261105611086110a6110c6110d6110d611096110761105611046110461105611096110b6110e6110e6110e6110f6110f6110d611096110a6110c6110d6110a6110561103611026110061100611
0114000000610026110261102611036110361103611036110361104611076110b6110d6110d6110d6110c61108611056110561106611096110b6110b611086110561104611046110561108611096110961109611
0110000009610056110461104611046110561107611066110361104611066110761104611066110a6110f6111061110611106110f6110f6110f6110f6110f6110f6110f6110f6110f6110f611096110661100611
490f0000006100261102611026110c6110c6110c6110c6110c6110c6110c6110261102611026110261102611026110261102611026110261102611026110261102611026110c6110061100611006110061100611
__music__
00 01424344
00 01424344
00 02424344
00 03424344
02 04424344

