pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

#include utils.lua
#include animation.lua
#include eggjam18_lakebed.lua

game_state_title   = 'title'
game_state_playing = 'playing'
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
SEAWEED__FRESH = 'fresh'
-- Top portion picked, ideal height, will regrow
SEAWEED_PICKED = 'picked'
-- Too low, regrows but not pickable
SEAWEED_PRUNED = 'pruned'
-- The root was pulled, seaweed won't grow again.
SEAWEED_ROUTED = 'routed'
-- Pruned and regrowing.
SEAWEED_SPROUT = 'sprout'

lakebed = {}
function init_day()
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
         points = 0,
         accelerating = false,
   })
   net = make_obj({
         x = 16,
         y = WATER_LINE + 64,
         sprite = 1,
         move_dir = 0,
         speed_x = 0,
         speed_y = 0,
         pos = 5,
         cooling_down = false,
   })

   ducks = {
      make_obj({
            x = 200,
            y = WATER_LINE-7,
      })
   }

   fishies = {
      make_obj({x=192, y=64, sprite=5})
   }

   animate_obj(fishies[1], function(obj)
                  while obj.x > 0 do
                     local from = obj.x
                     local to   = obj.x - 16
                     local anim = {7,9,7,5}
                     for f = 1,60 do
                        obj.x = lerp(from, to, easeinquad(f/60))
                        if f % 15 == 0 then
                           obj.sprite = anim[f/15]
                        end
                        yield()
                     end
                  end
   end)

   local horizon = 32
   local azimuth = 8
   sun = make_obj({
         x = 0,
         y = horizon,
         minute = 0,
   })
   animate_obj(sun, function(obj)
                  while sun.minute < (60*12) do
                     if nth_frame(30) then
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

   function make_sw_sprite(sw_x,s)
      return {x=sw_x,sprite=s}
   end
   if #lakebed > 0 then
      debug('regrowing lakebed e.g ',lakebed[1])
      for sw in all(lakebed) do
         -- Unpicked seaweed grows
         if sw.status == SEAWEED__FRESH then
            sw.sprites[#sw.sprites] = make_sw_sprite(sw.x, rnd({17,18,19}))
            sw.height = min(7, sw.height+1)
            add(sw.sprites, make_sw_sprite(sw.x, 16))
            -- Add the tip back to picked seaweed
         elseif sw.status == SEAWEED_PICKED then
            sw.height = min(7, sw.height+1)
            sw.sprites[#sw.sprites] = make_sw_sprite(sw.x, 16)
            sw.status = SEAWEED__FRESH
         -- Pruned seaweed gets a new shoot
         elseif sw.status == SEAWEED_PRUNED then
            sw.height+=1
            sw.sprites[sw.height] = make_sw_sprite(sw.x, 32)
            sw.status = SEAWEED_SPROUT
         -- Have sprout turn back into a fresh pickable seaweed
         elseif sw.status == SEAWEED_SPROUT then
            sw.sprites[sw.height] = make_sw_sprite(sw.x, 16)
            sw.status = SEAWEED__FRESH
         -- Won't regrow, a terminal state (for now)
         elseif sw.status == SEAWEED_ROUTED then
            sw.height = 1
            sw.sprites[1] = make_sw_sprite(sw.x, 36)
            -- sw.status = SEAWEED_PRUNED
         end
      end
   else
      -- lakebed_seaweed defined in from eggjam18_lakebed
      for i,h in pairs(lakebed_seaweed) do
         local sw_x = 32 + (16 * i)
         local sprites = {make_sw_sprite(sw_x, 20)}
         for i = 2,(h-1) do
            add(sprites, make_sw_sprite(sw_x, rnd({17,18,19})))
         end
         add(sprites, make_sw_sprite(sw_x, 16))
         local sw = make_obj({
                   x = sw_x,
                   height = h,
                   sprites = sprites,
                   status = h == 0 and 'empty' or SEAWEED__FRESH,
         })
         add(lakebed, sw)
      end
   end

   for sw in all(lakebed) do
      if sw.status != 'empty' then
         animate_obj(sw, function(obj)
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

   splashes = {}
   gather_particles = {}
end

function _init()
   init_day()
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

function gather_seaweed()
   local nx1 = net.x
   local nx2 = nx1+4
   local ny2 = net.y+7
   for sw in all(lakebed) do
      if sw.x >= nx1 and sw.x <= nx2 then
         local swtop = 127 - (8*sw.height)
         if ny2 > swtop then
            local newh = max(0,(flr((127-ny2)/8)))
            local delta = sw.height - newh
            --sfx(sw.height-1)
            player.points += sw.height - delta
            sw.height = newh
            if delta == 1 then
               sw.status = SEAWEED_PICKED
            elseif newh == 0 then
               sw.status = SEAWEED_ROUTED
            else
               sw.status = SEAWEED_PRUNED
            end
            local cm = {[SEAWEED_PICKED] = lime, [SEAWEED_PRUNED] = moss, [SEAWEED_ROUTED] = storm}
            for i = 1,delta do
               local p1 = make_obj({x=sw.x+6,y=ny2,colour=cm[sw.status]})
               animate_obj(p1, function(obj)
                              wait(10)
                              obj.x += rnd({1,2})
                              obj.y -= 1
                              wait(20)
                              obj.x += 2
                              obj.y -= rnd({1,2})
                              wait(20)
                              obj.x += rnd({1,2})
                              obj.y -= 1
                              wait(20)
                              obj.x += 2
                              obj.y -= rnd({1,2})
                              wait(10)
                              obj.x = -1
                              obj.y = -1
               end)
               add(gather_particles, p1)
            end
            break
         end
      end
   end
end

function _update60()
   frame_count += 1
   run_animations()

   if not(sun.minute < (60*4)) then
      init_day()
   end

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
   if btn(b_x) and not player.jumping then
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
         if net.pos > 2 then
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

   gather_seaweed()
end

function _draw()
   cls(black)

   camera(cam.x, cam.y)

   rectfill(cam.x, cam.y,  cam.x+127, cam.y+31, pink)
   pal(ember, coral, 0)
   circfill(sun.x+cam.x, sun.y, 4, ember)
   circfill(sun.x+cam.x, sun.y, 3, white)
   rectfill(cam.x, cam.y+32, cam.x+127, cam.y+127, orange)
   line(cam.x, WATER_LINE, cam.x+127, WATER_LINE, peach)

   pal(ember, olive, 0)
   line(cam.x, 127, cam.x+127, 127, ember)

   rectfill(cam.x, cam.y, cam.x+127, cam.y+6, white)

   -- print(dumper(player.speed_x, ' @ ', player.x, ' ^ ', net.speed_y, ' y ', net.y, ' b ', player.bounces), cam.x+1, cam.y+1, slate)
   pal(ember, coral, 0)
   for i = 1,(player.speed_x/ACCEL_X) do
      print('>', cam.x+24+(i*3), 1, orange)
      print('>', cam.x+25+(i*3), 1, coral)
   end

   local mins = flr(sun.minute % 60)
   local hour = flr(6 + (sun.minute/60))
   local time = (hour < 10 and '0'..hour or hour)..':'..(mins < 10 and '0'..mins or mins)
   print(dumper('★ ', player.points, '      ⧗', time), cam.x+1, 1, slate)

   pal(storm, sea, 1)

   for sw in all(lakebed) do
      if sw.x > (cam.x-8) and sw.x < (cam.x+127) then
         for i = 1,sw.height-1 do
            local s1 = sw.sprites[i]
            local s2 = sw.sprites[i+1]
            local y1 = 1+127-(8*i)+4
            local y2 = y1 - 8
            line(s1.x+3, y1, s2.x+3, y2, moss)
         end
      end
   end
   for sw in all(lakebed) do
      if sw.x > (cam.x-8) and sw.x < (cam.x+127) then
         for i = 1,sw.height do
            spr(sw.sprites[i].sprite, sw.sprites[i].x, 1+127-(8*i))
         end
      end
   end

   for p in all(gather_particles) do
      pset(p.x, p.y, p.colour)
   end

   spr(47+(player.speed_x/ACCEL_X), player.x-4,player.y)
   spr(player.sprite, player.x, player.y)
   spr(net.sprite, net.x, net.y)
   line(player.x, player.y+7, net.x+5, net.y, silver)

   for s in all(splashes) do
      if s.animating then
         spr(2, s.x, s.y)
      end
   end

   for d in all(ducks) do
      spr(4, d.x, d.y)
   end

   for f in all(fishies) do
      sspr(f.sprite*8,0,16,16,f.x,f.y)
   end
end

__gfx__
00000000000005000000000000090000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaa00000050000000000000909440044909000000000006660000000000000660000000000000066000000000000000000000000000000000000000000000
0aacaca0000500000000000000004340043400000000000066600000000000006660000000000000666000000000000000000000000000000000000000000000
0aacaca00050000000000000000044aaaa4400000000055555000004000005555500004000000555550004000000000000000000000000000000000000000000
0a9aaaa0005000007000000700004400004400000055555555500044005555555550004000555555555006000000000000000000000000000000000000000000
0aa99aab000500007f0000f704445900009544400555a655955504460555a655955504400555a655955504400000000000000000000000000000000000000000
00aaaabb0000500000f00f0045554900009455540755555595555464075555559555546007555555955554600000000000000000000000000000000000000000
0bbbbbb0000555500000000004449000000addd0077e755595555646077e755595555640077e7555955556400000000000000000000000000000000000000000
000b00000003300000030000003300000011000077e755559555564677e755559555564077e75555955556400000000000000000000000000000000000000000
000bd0000003d0000003000000330000001100005755556595555464575555659555546057555565955554600000000000000000000000000000000000000000
0000b000000330000003d0000003d00000d100000555565595550446055556559555044005555655955504400000000000000000000000000000000000000000
0000b00000003000000d3000003300000001d0000055555555500044005555555550004000555555555006000000000000000000000000000000000000000000
000bd000000d30000000300000330000000110000005555550000004000555555000004000055555500004000000000000000000000000000000000000000000
00db0000000330000003d00000d33000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bb00000003d00000d3000000033000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bb00000030000003300000033d000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b000000000000000000000000000000ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00db000000000000000000000000000000d100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bb0000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bb000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000007a0000007a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aa000000aaa00000a7a0000007a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaaa00007aaa000007aa00000a7a000007aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777a000007aa000007aa000007aa0000a7aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010600001805418052180521805218050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001c0541c0521c0521c0521c050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001f0541f0521f0521f0521f050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600002105421052210522105221050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600002405424052240522405224050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
