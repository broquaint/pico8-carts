pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

#include utils.lua
#include animation.lua

game_state_title   = 'title'
game_state_playing = 'playing'
game_state_won     = 'won'

-- Default state so title screen works
g_anims = {}
frame_count = 0
WATER_LINE = 32

WATER_GRAV  = 12 * 1/40
AIR_GRAV    = 8  * 1/30
MAX_SPEED_X = 2.5
MIN_SPEED_X = 0.25
ACCEL_X     = 0.02
DECEL_X     = 0.04

function _init()
   cam = make_obj({
         x = 0,
         y = 0,
   })

   player = make_obj({
         x = 32,
         y = WATER_LINE-7,
         sprite = 0,
         move_dir = 0,
         speed_x = MIN_SPEED_X,
         speed_y = 0,
         jumping = false,
         bounces = 0,
         points = 0,
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

   level = {}
   for i = 1,128 do
      add(level, make_obj({
                x = 16 * i,
                y = 121,
                height = i % 2 == 0 and randx(5) or 3,
                collected = false,
                flipped = rnd() < 0.51,
      }))
   end

   splashes = {}
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
   local nx2 = nx1+6
   local ny2 = net.y+7
   for sw in all(level) do
      if sw.x >= nx1 and sw.x <= nx2 then
         local swtop = 127 - (8*sw.height)
         if ny2 > swtop then
            local newh = max(0,(flr((127-ny2)/8)))
            local delta = sw.height - newh
            player.points += sw.height - delta
            sw.height = newh
            -- Slow down the player if too much seaweed is cut down
            if delta > 1 then
               player.speed_x *= (1 - (0.15 * delta))
            end
            break
         end
      end
   end
end

function _update60()
   frame_count += 1
   run_animations()

   -- player horizontal movement
   if btn(b_right) then
      local ps = player.speed_x
      player.speed_x = ps + ACCEL_X <= MAX_SPEED_X and ps + ACCEL_X or ps
   end
   if btn(b_left) then
      local ps = player.speed_x
      player.speed_x = ps - DECEL_X >= MIN_SPEED_X and ps - DECEL_X or ps
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
   rectfill(cam.x, cam.y+32, cam.x+127, cam.y+127, orange)
   line(cam.x, WATER_LINE, cam.x+127, WATER_LINE, white)

   rectfill(cam.x, cam.y, cam.x+127, cam.y+7, white)

   -- print(dumper(player.speed_x, ' @ ', player.x, ' ^ ', net.speed_y, ' y ', net.y, ' b ', player.bounces), cam.x+1, cam.y+1, slate)
   spr(16, cam.x+2, 0)
   print(dumper(player.points, ' > ', player.speed_x), cam.x+9, 1, slate)

   pal(ember, tea, 1)
   for sw in all(level) do
      for i = 1,sw.height do
         spr(21-i, sw.x, 1+127-(8*i))
      end
   end

   spr(player.sprite, player.x, player.y)
   spr(net.sprite, net.x, net.y)
   line(player.x, player.y+7, net.x+5, net.y, silver)

   for s in all(splashes) do
      if s.animating then
         spr(2, s.x, s.y)
      end
   end
end

__gfx__
00000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaa00000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aacaca0000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aacaca0005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a9aaaa0005000007000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa99aab000500007f0000f700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaabb0000500000f00f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbbbbb0000555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000000800000008000000880000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008d0000008d0000008000000880000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000000880000008d0000008d00000d800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000800000008000000d8000008800000008d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008d000000d80000000800000880000000880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d80000000880000008d00000d88000000880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
008000000008d00000d8000000088000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
008d000000080000008800000088d000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
