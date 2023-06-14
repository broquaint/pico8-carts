pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- kelp on mars
-- by broquaint

#include utils.lua
#include animation.lua
#include eggjam18_lakebed.lua

game_state_title   = 'title'
game_state_playing = 'playing'
game_state_day_summary = 'day_summary'
game_state_run_summary = 'run_summary'
game_state_won     = 'won'

g_anims = {}
frame_count = 0

WATER_LINE  = 32
WATER_GRAV  = 12 * 1/40
AIR_GRAV    = 8  * 1/30
MAX_SPEED_X = 2.5
MIN_SPEED_X = 0.5
ACCEL_X     = 0.5

-- Default state
KELP__FRESH = 'fresh'
-- Top portion picked, ideal height, will regrow
KELP_PICKED = 'picked'
-- Too low, regrows but not pickable
KELP_PRUNED = 'pruned'
-- The root was pulled, kelp won't grow again.
KELP_ROUTED = 'routed'
-- Pruned and regrowing.
KELP_SPROUT = 'sprout'

lakebed = {}
function init_lakebed()
   function make_kelp_sprite(kelp_x,s)
      return {x=kelp_x,sprite=s}
   end
   if #lakebed > 0 then
      debug('regrowing lakebed e.g ',lakebed[1])
      for kelp in all(lakebed) do
         -- Unpicked kelp grows
         if kelp.status == KELP__FRESH then
            kelp.sprites[#kelp.sprites] = make_kelp_sprite(kelp.x, rnd({17,18,19}))
            kelp.height = min(7, kelp.height+1)
            add(kelp.sprites, make_kelp_sprite(kelp.x, 16))
            -- Add the tip back to picked kelp
         elseif kelp.status == KELP_PICKED then
            kelp.height = min(7, kelp.height+1)
            kelp.sprites[#kelp.sprites] = make_kelp_sprite(kelp.x, 16)
            kelp.status = KELP__FRESH
         -- Pruned kelp gets a new shoot
         elseif kelp.status == KELP_PRUNED then
            kelp.height+=1
            kelp.sprites[kelp.height] = make_kelp_sprite(kelp.x, 32)
            kelp.status = KELP_SPROUT
         -- Have sprout turn back into a fresh pickable kelp
         elseif kelp.status == KELP_SPROUT then
            kelp.sprites[kelp.height] = make_kelp_sprite(kelp.x, 16)
            kelp.status = KELP__FRESH
         -- Won't regrow, a terminal state (for now)
         elseif kelp.status == KELP_ROUTED then
            kelp.height = 1
            kelp.sprites[1] = make_kelp_sprite(kelp.x, 36)
            -- kelp.status = KELP_PRUNED
         end
      end
   else
      -- lakebed_kelp defined in from eggjam18_lakebed
      for i,t in pairs(lakebed_kelp) do
         local kelp_x = 48 + (16 * i)
         local sprites = {make_kelp_sprite(kelp_x, 20)}
         for i = 2,(t.height-1) do
            add(sprites, make_kelp_sprite(kelp_x, rnd({17,18,19})))
         end
         add(sprites, make_kelp_sprite(kelp_x, t.status == 'fresh' and 16 or 32))
         local kelp = make_obj({
                   x = kelp_x,
                   height = t.height,
                   status = t.status,
                   sprites = sprites,
         })
         add(lakebed, kelp)
      end
   end

   for kelp in all(lakebed) do
      if kelp.status != 'empty' then
         animate_obj(kelp, function(obj)
                        local orig_x = obj.x
                        while obj.height > 0 do
                           for i,s in pairs(obj.sprites) do
                              if s.x > (cam.x-8) and s.x < (cam.x+127) and nth_frame(i*30) and s.sprite != 20 then
                                 -- This is very boring, but it's fine.
                                 s.x = s.x != orig_x and orig_x or s.x+(i % 2 == 0 and 1 or -1)
                              end
                           end
                           yield()
                        end
            end)
         end
   end
end

function animate_fish(fish, frames, anim)
   animate_obj(fish, function(obj)
                  while game_state == game_state_playing and obj.x > (cam.x-obj.w) do
                     local from = obj.x
                     local to   = obj.x - 16
                     local astep  = frames / #anim
                     for f = 1,frames do
                        obj.x = lerp(from, to, easeinquad(f/frames))
                        if f % astep == 0 then
                           obj.sx = anim[f/astep]*8
                        end
                        yield()
                     end
                  end
   end)
end

function make_wee_fish(f_x, f_y)
   local fish = make_obj({x=f_x, y=f_y, sx=5*8, sy=16, w=8,  h=8})
   animate_fish(fish, 45, {7,9,5})
   return fish
end

function make_mid_fish(f_x, f_y)
   local fish = make_obj({x=f_x, y=f_y,  sx=5*8, sy=24, w=16, h=8})
   animate_fish(fish, 90, {7,9,5})
   return fish
end

function make_big_fish(f_x, f_y)
   local fish = make_obj({x=f_x, y=f_y, sx=5*8, sy=0,  w=16, h=16})
   animate_fish(fish, 120, {7,9,7,5})
   return fish
end

function init_day()
   game_state = 'playing'

   g_anims = {}
   frame_count = 0

   cam = make_obj({
         x = 0,
         y = 0,
   })

   player = make_obj({
         x = 32,
         y = WATER_LINE-7,
         sprite = 0,
         move_dir = 0,
         speed_x = 0.5,
         speed_y = 0,
         jumping = false,
         bounces = 0,
         tips = 0,
         trunks = 0,
         accelerating = false,
   })
   net = make_obj({
         x = 16,
         y = WATER_LINE + 48,
         sprite = 1,
         move_dir = 0,
         speed_x = 0,
         speed_y = 0,
         pos = 5,
         cooling_down = false,
   })

   ducks = {
      -- make_obj({
      --       x = 200,
      --       y = WATER_LINE-7,
      -- })
   }

   fishies = {
      make_wee_fish(256, 106),
      make_mid_fish(512, 97),
      make_wee_fish(768, 111),
      make_wee_fish(1024, 106),
      make_mid_fish(1312, 97),
   }

   local horizon = 32
   local azimuth = 8
   sun = make_obj({
         x = 0,
         y = horizon,
         minute = 0,
   })
   animate_obj(sun, function(obj)
                  while sun.minute < (60*12) do
                     if nth_frame(25) then
                        sun.minute += (60*12)/128
                        sun.x      += 1
                        if sun.x < 64 then
                           sun.y = lerp(horizon, azimuth, sun.x/64)
                        else
                           sun.y = lerp(azimuth, horizon, (sun.x-64)/64)
                        end
                     end
                     yield()
                  end
   end)

   init_lakebed()

   splashes = {}
   gather_particles = {}

   music(0)
end

function init_title()
   -- init_day()
   game_state = game_state_title
   g_anims = {}
   frame_count = 0

   cam = make_obj({
         x = 0,
         y = 0,
   })

   local horizon = 32
   local azimuth = 8
   sun = make_obj({
         x = 0,
         y = horizon,
         minute = 0,
   })

   init_lakebed()
end

function init_run()
   run = {
      tips = 0,
      trunks = 0,
      nets = 3,
   }
end

function _init()
   init_title()
end

function animate_splash()
   local s = make_obj({
         x = player.x,
         y = WATER_LINE-7,
   })
   animate_obj(s, function(obj)
                  wait(30)
   end)
   add(splashes, s)
end

function calc_player_jump()
   -- Because we need to calculate from the base of the sprite
   local wl = WATER_LINE-7
   if player.jumping then
      if player.y > wl then
         if player.prev_grav == AIR_GRAV then
            animate_splash()
         end
         player.speed_y -= WATER_GRAV
         player.prev_grav = WATER_GRAV
      else
         if player.prev_grav == WATER_GRAV then
            player.bounces += 3
         end
         player.speed_y += AIR_GRAV
         player.prev_grav = AIR_GRAV
      end
      if player.bounces >= 16 then
         player.jumping = false
         player.y = wl
         player.speed_y = 0
         player.bounces = 0
      end
   end
end

local GATHER_COLOUR = {[KELP_PICKED] = lime, [KELP_PRUNED] = moss, [KELP_ROUTED] = storm}
function animate_gathered_kelp(kelp, ny2, count)
   for i = 1,count do
      local p1 = make_obj({x=kelp.x+6,y=ny2,colour=GATHER_COLOUR[kelp.status]})
      animate_obj(p1, function(obj)
                     wait(10)
                     obj.x += rnd({1,2}) + player.speed_x
                     obj.y -= 1
                     wait(20)
                     obj.x += 2
                     obj.y -= rnd({1,2})
                     wait(20)
                     obj.x += rnd({1,2})  + player.speed_x
                     obj.y -= 1
                     wait(20)
                     obj.x += 2
                     obj.y -= rnd({1,2})  + player.speed_x
                     wait(10)
                     obj.x = -1
                     obj.y = -1
      end)
      add(gather_particles, p1)
   end
end

function gather_kelp()
   if net.cooling_down then
      return
   end

   local nx1 = net.x
   local nx2 = nx1+4
   local ny2 = net.y+7
   for kelp in all(lakebed) do
      if kelp.x >= nx1 and kelp.x <= nx2 then
         local kelp_top = 127 - (8*kelp.height)
         if ny2 > kelp_top then
            local newh  = max(0,(flr((127-ny2)/8)))
            local delta = kelp.height - newh

            kelp.height = newh
            if delta == 1 and kelp.status == KELP__FRESH then
               player.tips += 1
               kelp.status = KELP_PICKED
            elseif newh == 0 then
               kelp.status = KELP_ROUTED
            else
               player.trunks += kelp.status != KELP_SPROUT and 1 or 0
               kelp.status = KELP_PRUNED
            end

            animate_gathered_kelp(kelp, ny2, delta+1)
            break
         end
      end
   end
end


function detect_line_intersection(ox1, ox2, oy1, oy2)
   -- Make bounding box smaller than sprite
   local px1 = net.x + 1
   local px2 = net.x + 7
   local py1 = net.y + 1
   local py2 = net.y + 7

   -- bottom line intersection with top line
   if py2 >= oy1 and py2 <= oy2
      and ((px1 >= ox1 and px1 <= ox2) or (px2 >= ox1 and px2 <= ox2))
   then
      return true
      -- left line intersects with top line
   elseif px1 >= ox1 and px1 <= ox2
      and ((py1 >= oy1 and py1 <= oy2) or (py2 >= oy1 and py2 <= oy2))
   then
      return true
      -- right line intersects with top line
   elseif px2 >= ox1 and px2 <= ox2
      and ((py1 >= oy1 and py1 <= oy2) or (py2 >= oy1 and py2 <= oy2))
   then
      return true
   end
end

function detect_fishies()
   if net.cooling_down then
      return
   end
   for f in all(fishies) do
      local fx1 = f.x
      local fx2 = f.x + f.w
      local fy1 = f.y
      local fy2 = f.y + f.h
      if detect_line_intersection(fx1, fx2, fy1, fy2) then
         run.nets -= 1
         net.cooling_down = true
         animate_obj(net, function(obj)
                        obj.sprite = 2
                        wait(10)
                        obj.sprite = 1
                        wait(10)
                        obj.sprite = 2
                        wait(10)
                        obj.sprite = 1
                        wait(10)
                        obj.sprite = 2
                        wait(10)
                        obj.sprite = 1
                        obj.cooling_down = false
         end)
         return f
      end
   end
end

function harvest_kelp()
      -- player horizontal movement
   if btnp(b_right) then
      local ps = player.speed_x
      if not(ps + ACCEL_X > MAX_SPEED_X) and not player.accelerating then
         player.accelerating = true
         animate(function()
               local target = ps + ACCEL_X
               while player.speed_x < target do
                  player.speed_x += 0.03
                  yield()
               end
               player.speed_x = target
               player.accelerating = false
         end)
      end
   end
   if btnp(b_left) then
      local ps = player.speed_x
      if not(ps - ACCEL_X < MIN_SPEED_X) and not player.accelerating then
         player.accelerating = true
         animate(function()
               local target = ps - ACCEL_X
               while player.speed_x > target do
                  player.speed_x -= 0.05
                  yield()
               end
               player.speed_x = target
               player.accelerating = false
         end)
      end
   end

   -- jump/water physics
   if frame_count > 10 and btn(b_x) and not player.jumping then
      player.speed_y = -3
      player.jumping = true
      player.bounces = 1
      player.prev_grav = AIR_GRAV
   end

   calc_player_jump()

   -- net movement
   if not net.cooling_down then
      if btn(b_up) then
         if net.pos < 9 then
            net.pos += 1
            net.cooling_down = true
            delay(function() net.cooling_down = false end, 10)
            animate(function()
                  for _ = 1,8 do
                     net.y -= 1
                     yield()
                  end
            end)
         end
      elseif btn(b_down) then
         if net.pos > 0 then
            net.pos -= 1
            net.cooling_down = true
            delay(function() net.cooling_down = false end, 10)
            animate(function()
                  for _ = 1,8 do
                     net.y += 1
                     yield()
                  end
            end)
         end
      end
   end

   cam.x    += player.speed_x
   player.x += player.speed_x
   player.y += (1/player.bounces*player.speed_y)

   net.x    += player.speed_x

   gather_kelp()
   detect_fishies()
end

function _update60()
   frame_count += 1
   run_animations()

   if game_state == game_state_playing and run.nets == 0 then
      g_anims = {}
      cam.x = 0
      music(-1)
      game_state = game_state_run_summary
   elseif game_state == game_state_playing and not(sun.minute < (60*12)) then
      g_anims = {}
      cam.x = 0
      run.tips += player.tips
      run.trunks += player.trunks
      game_state = game_state_day_summary
   end

   if game_state == game_state_playing then
      harvest_kelp()
   elseif game_state == game_state_day_summary or game_state == game_state_run_summary or game_state == game_state_title then
      if btnp(b_x) then
         if game_state == game_state_run_summary or game_state == game_state_title then
            lakebed = {}
            init_run()
         end
         init_day()
      end
   end
end

function draw_kelp()
   for kelp in all(lakebed) do
      if kelp.x > (cam.x-8) and kelp.x < (cam.x+127) then
         for i = 1,kelp.height-1 do
            local s1 = kelp.sprites[i]
            local s2 = kelp.sprites[i+1]
            local y1 = 1+127-(8*i)+4
            local y2 = y1 - 8
            line(s1.x+3, y1, s2.x+3, y2, moss)
         end
      end
   end
   for kelp in all(lakebed) do
      if kelp.x > (cam.x-8) and kelp.x < (cam.x+127) then
         for i = 1,kelp.height do
            spr(kelp.sprites[i].sprite, kelp.sprites[i].x, 1+127-(8*i))
         end
      end
   end
end

function draw_sky()
   local hour = sun.minute / 60
   local sky_colour = hour < 0.5 and wine or
      hour < 0.8  and aubergine or
      hour < 1    and salmon or
      hour < 1.3  and pink or
      hour > 11.5 and wine or
      hour > 11.2 and aubergine or
      hour > 10.8 and salmon or
      hour > 10.2 and pink or
      coral

   pal(pink, sky_colour, 1)
   rectfill(cam.x, cam.y,  cam.x+127, cam.y+31, pink)
end

function draw_water()
   local hour = sun.minute / 60
   local water_colour = hour < 0.5 and port or
      hour < 0.8  and leather or
      hour < 1    and tan or
      hour < 1.3  and amber or
      hour > 11.5 and port or
      hour > 11.2 and leather or
      hour > 10.8 and tan or
      hour > 10.2 and amber or
      orange

   pal(orange, water_colour, 1)

   rectfill(cam.x, cam.y+32, cam.x+127, cam.y+127, orange)
   line(cam.x, WATER_LINE, cam.x+127, WATER_LINE, peach)

   pal(ember, olive, 0)
   line(cam.x, 127, cam.x+127, 127, ember)
end

function draw_harvesting()
   draw_sky()

   pal(ember, coral, 0)
   circfill(sun.x+cam.x, sun.y, 4, ember)
   circfill(sun.x+cam.x, sun.y, 3, white)

   draw_water()

   rectfill(cam.x, cam.y, cam.x+127, cam.y+6, slate)

   -- print(dumper(player.speed_x, ' @ ', player.x, ' ^ ', net.speed_y, ' y ', net.y, ' b ', player.bounces), cam.x+1, cam.y+1, slate)
   pal(ember, coral, 0)
   for i = 1,(player.speed_x/ACCEL_X) do
      print('>', cam.x+(i*3), 1, orange)
      print('>', cam.x+(i*3), 1, coral)
   end

   local mins = flr(sun.minute % 60)
   local hour = flr(6 + (sun.minute/60))
   local time = (hour < 10 and '0'..hour or hour)..':'..(mins < 10 and '0'..mins or mins)
   print(dumper('^', player.tips, ' L', player.trunks, ' N', run.nets, ' ⧗', time), cam.x+21, 1, white)

   pal(storm, sea, 1)

   draw_kelp()

   for p in all(gather_particles) do
      pset(p.x, p.y, p.colour)
   end

   if not player.jumping or abs(player.y -  WATER_LINE+7) < 2 then
      spr(47+(player.speed_x/ACCEL_X), player.x-4,player.y)
   end

   spr(player.sprite, player.x, player.y)
   spr(net.sprite, net.x, net.y)
   line(player.x, player.y+7, net.x+5, net.y, silver)

   for s in all(splashes) do
      if s.animating then
         spr(3, s.x, s.y)
      end
   end

   for d in all(ducks) do
      spr(4, d.x, d.y)
   end

   for f in all(fishies) do
      sspr(f.sx, f.sy, f.w, f.h, f.x, f.y)
   end
end

function draw_day_summary()
   print('end of the day!', 16 , 32, white)
   print(dumper('gathered: ^', player.tips, ' L', player.trunks), 16, 48, white)
end

function draw_run_summary()
   print('end of the run!', 16 , 32, white)
   print(dumper('gathered: ^', player.tips, ' L', player.trunks), 16, 48, white)
end

function draw_title()
   draw_sky()
   draw_water()

   sspr(0, 32, 128, 128, 0, 5)

   draw_kelp()
end

function _draw()
   cls(black)

   camera(cam.x, cam.y)

   if game_state == game_state_playing then
      draw_harvesting()
   elseif game_state == game_state_day_summary then
      draw_day_summary()
   elseif game_state == game_state_run_summary then
      draw_run_summary()
   elseif game_state == game_state_title then
      draw_title()
   end
end

__gfx__
00000000000005000000070000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaa00000050000000700000000000044909000000000006660000000000000660000000000000066000000000000006600000000000000000000000000000
0aacaca0000500000007000000000000043400000000000066600000000000006660000000000000666000000000000066600000000000000000000000000000
0aacaca0005000000070000000000000aa4400000000055555000004000005555500004000000555550004000000055555000500000000000000000000000000
0a9aaaa0005000000070000070000007004400000055555555500044005555555550004000555555555006000055555555500600000000000000000000000000
0aa99aab00050000000700007f0000f7009544400555a655555504460555a655555504400555a655555504400555a65555550440000000000000000000000000
00aaaabb000050000000700000f00f00009455540755555559555464075555555595546007555555559554600755555555955460000000000000000000000000
0bbbbbb0000555500007777000000000000addd0077e755995555646077e755599555640077e755599555640077e755599555640000000000000000000000000
000b00000003300000030000003300000011000077e755555595564677e755555595564077e755555595564077e7555555955640000000000000000000000000
000bd0000003d0000003000000330000001100005755556599555464575555659955546057555565995554605755556599555460000000000000000000000000
0000b000000330000003d0000003d00000d100000555565555550446055556555555044005555655555504400555565555550440000000000000000000000000
0000b00000003000000d3000003300000001d0000055555555500044005555555550004000555555555006000055555555500600000000000000000000000000
000bd000000d30000000300000330000000110000005555550000004000555555000004000055555500004000005555550000500000000000000000000000000
00db0000000330000003d00000d33000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bb00000003d00000d3000000033000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bb00000030000003300000033d000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000cc00000000000000cc00000000000000cc00000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000ccc0000000000000ccc0000000000000ccc000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000caddc0c000000000caddcc0000000000caddc0c000000000000000000000000000000000000000000000000
000000000000000000000000000000000000d000cddcddc000000000cdddddc000000000cddcddc0000000000000000000000000000000000000000000000000
000b000000000000000000000000000000ddd0000cddcc0c000000000cddccc0000000000cddcc0c000000000000000000000000000000000000000000000000
00db000000000000000000000000000000d1000000cc00000000000000cc00000000000000cc0000000000000000000000000000000000000000000000000000
00bb0000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bb000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000a00a000000000000a00a000000000000a00a0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000aaaaaaaa00000000aaaaaaaa00000000aaaaaaaa000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000aaaaaaaaaa00a000aaaaaaaaaa0a0000aaaaaaaaaa00a00000000000000000000000000000000000000000
00000000000000000000000000000000a0000000ffaadaaafaaaaa00ffaadaafaaaaaa00ffaadaaafaaaaa000000000000000000000000000000000000000000
0000000000000000000000007a0000007a000000ffaaaafffaaaaa00ffaaaaffaaaaaa00ffaaaaffaaaaaa000000000000000000000000000000000000000000
00000000aa000000aaa00000a7a0000007a0000000aaaaaaaaaaa0a000aaaaaaaaaaaa0000aaaaaaaaaaa0a00000000000000000000000000000000000000000
aaaa00007aaa000007aa00000a7a000007aa0000000aaaaaaaaa0000000aaaaaaaaa0000000aaaaaaaaa00000000000000000000000000000000000000000000
0777a000007aa000007aa000007aa0000a7aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000dd0000000000000000000000000000000000000000000000
0000dd00000000000000000000000000000000000000000000000000000000000000000000000000dd0000000000dd0000000000000000000000000000000000
0000dd00000000000000000000000000000000000000000000000000000000000000000000000000dd000000000ddd0000000000000000000000000000000000
0000dd0000dd0000000000000000000000000000000000000000000000000000000000000000000dddd00000000ddd0000000000000000000000000000000000
0000dd0000dd00000000000000dd000000000000000000000000000000000000000000000000000dddd0000000dddd0000000000000000000000000000000000
0000dd000ddd00000000000000dd000000000000000000000000000000000000000000000000000ddddd000000dddd0000000000000000000000000000000000
0000dd000dd000000000000000dd00000000000000000000000000000000000000000000000000ddd0dd00000ddddd0000000000000000000000000000000000
0000dd000dd000000000000000dd00000000000000000000000000000000000000000000000000ddd0ddd0000dd0ddd000000000000000000000000000000000
0000dd00ddd000000000000000dd00000000000000000000000000000000000000000000000000dd00ddd000ddd0ddd000000000000000000000000000000000
0000dd00dd0000000000000000dd00000000000000000000000000000000000000000000000000dd000dd000dd000dd000000000000000000000000000000000
0000dd0ddd0000000000000000dd00000000000000000000000000000000000000000000000000dd000dd000dd000dd000000000000000000000000000000000
0000dd0dd00000000000000000dd0000000000000000000000000000000000000000000000000ddd000dd00ddd000dd000000000000000000000000000000000
0000ddddd00000000000000000dd0000dddd0000000000000dddd000000000000000000000000dd0000dd00dd0000dd000000000000000000000000000000000
0000dddd000000000ddddd0000dd00ddddddd0000000000ddddddd00000dd00ddddd000000000dd0000dd00dd0000dd000000000000000000000000000000000
0000dddd00000000dddddd0000dd00ddddddd000000000dddd0dddd0000dddddddddd00000000dd0000dd00dd0000dd000000ddddd00dd0ddddd0000dddd0000
0000ddddd000000dddd0dd0000dd00dd000ddd0000000ddd0000dddd000dddddd0ddd00000000dd0000dd0ddd0000dd0000ddddddd00dddddddd000ddddddd00
0000ddddd00000ddd00ddd0000dd00dd0000dd0000000dd000000ddd000dddd0000dd00000000dd0000ddddd00000ddd00dddd0ddd00dddd0000000dd00ddd00
000ddd0ddd000ddddddddd0000dd00dd000ddd0000000dd000000ddd000ddd00000dd00000000dd00000dddd000000dd00ddd00ddd00ddd00000000dd000dd00
000dd00ddd000ddddddd000000dd00dd00dddd000000ddd000000ddd000dd000000dd00000000dd00000dddd000000dd0ddd000ddd00dd000000000ddd000000
000dd000ddd00dd00000000000dd00dd00ddd0000000dd0000000dd000ddd000000dd00000000dd00000ddd0000000dd0ddd00dddd00dd000000000dddd00000
000dd0000dd00dd00000000000dd00dd0ddd00000000dd0000000dd000ddd00000ddd00000000dd00000ddd0000000dd0dd000ddd00ddd0000000000dddd0000
000dd0000dd00dd0000000000ddd00ddddd000000000dd000000ddd000dd000000ddd00000000dd00000ddd0000000dd0ddd0dddd00dd000000000000ddd0000
000dd0000dd00ddd000ddd000dd000ddddd000000000ddd000ddddd000dd000000dd000000000dd000000dd0000000dd0dddddddd00dd00000000ddd00dd0000
00ddd0000ddd00dddddddd00ddd000dddd0000000000dddddddddd0000dd000000dd000000000dd000000dd0000000dd000dddddd00dd00000000ddddddd0000
00ddd00000dd00ddddddd000ddd000dd0000000000000ddddddd000000dd000000dd000000000dd000000dd0000000dd0000000dd00dd000000000dddddd0000
00dd00000000000000000000000000dd000000000000000000000000000000000000000000000000000000000000000000000000000dd0000000000ddd000000
000000000000000000000000000000dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010600001805418052180521805218050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001c0541c0521c0521c0521c050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001f0541f0521f0521f0521f050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600002105421052210522105221050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600002405424052240522405224050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0112000003744030250a7040a005137441302508744080251b7110a704037440302524615080240a7440a02508744087250a7040c0241674416025167251652527515140240c7440c025220152e015220150a525
011200000c033247151f5152271524615227151b5051b5151f5201f5201f5221f510225212252022522225150c0331b7151b5151b715246151b5151b5051b515275202752027522275151f5211f5201f5221f515
011200000c0330802508744080250872508044187151b7151b7000f0251174411025246150f0240c7440c0250c0330802508744080250872508044247152b715275020f0251174411025246150f0240c7440c025
011200002452024520245122451524615187151b7151f71527520275202751227515246151f7151b7151f715295202b5212b5122b5152461524715277152e715275002e715275022e715246152b7152771524715
011200002352023520235122351524615177151b7151f715275202752027512275152461523715277152e7152b5202c5212c5202c5202c5202c5222c5222c5222b5202b5202b5222b515225151f5151b51516515
011200000c0330802508744080250872508044177151b7151b7000f0251174411025246150f0240b7440b0250c0330802508744080250872524715277152e715080242e715080242e715246150f0240c7440c025
011600000042500415094250a4250042500415094250a42500425094253f2050a42508425094250a425074250c4250a42503425004150c4250a42503425004150c42500415186150042502425024250342504425
011600000c0330c4130f54510545186150c0330f545105450c0330f5450c41310545115450f545105450c0230c0330c4131554516545186150c03315545165450c0330c5450f4130f4130e5450e5450f54510545
__music__
00 05424344
00 05424344
00 05064344
00 05064344
01 05064344
00 05064344
00 07084344
02 090a4344
01 0b0c4344

