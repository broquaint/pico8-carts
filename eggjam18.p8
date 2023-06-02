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
         speed_x = 0,
         speed_y = 0,
         jumping = false,
         bounces = 0,
   })
   net = make_obj({
         x = 16,
         y = WATER_LINE + 64,
         sprite = 1,
         move_dir = 0,
         speed_x = 0,
         speed_y = 0,
   })

   level = {}
   for i = 1,128 do
      add(level, make_obj({
                x = 16 * i,
                y = 121,
                height = randx(5),
                collected = false
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

function calc_player_speed()
   player.speed_x *= 0.991
   -- Because we need to calculate from the base of the sprite
   local wl = WATER_LINE-7
   if player.jumping then
      if player.y > wl then
         if player.prev_grav == air_grav then
            animate_splash()
         end
         player.speed_y -= water_grav
         player.prev_grav = water_grav
      else
         if player.prev_grav == water_grav then
            player.bounces += 3
         end
         player.speed_y += air_grav
         player.prev_grav = air_grav
      end
      if player.bounces >= 16 then
         player.jumping = false
         player.y = wl
         player.speed_y = 0
         player.bounces = 0
      end
   end
end

water_grav = 12 * 1/40
air_grav   = 8  * 1/30
function _update60()
   frame_count += 1
   run_animations()

   -- player horizontal movement
   if btn(b_right) then
      player.move_dir = 1
      local sx = player.move_dir * 0.01
      if sx < 4 then
         player.speed_x += sx
      end
   end
   if btn(b_left) then
      player.move_dir = -1
      local sx = player.move_dir * 0.01
      if sx < 4 then
         player.speed_x += sx
      end
   end

   -- jump/water physics
   if btn(b_x) and not player.jumping then
      player.speed_y = -3
      player.jumping = true
      player.bounces = 1
      player.prev_grav = air_grav
   end

   calc_player_speed()

   if btn(b_up) then
      net.move_dir = -1
      local sx = net.move_dir * 0.02
      if sx < 4 then
         net.speed_y += sx
      end
   end
   if btn(b_down) then
      net.move_dir = 1
      local sx = net.move_dir * 0.025
      if sx < 4 then
         net.speed_y += sx
      end
   end


   cam.x    += player.speed_x
   player.x += player.speed_x
   player.y += (1/player.bounces*player.speed_y)

   net.x    += player.speed_x
   local ny = net.y + net.speed_y
   if ny > (WATER_LINE+32) and (ny+8) < 127 then
      net.y    += net.speed_y
   else
      net.speed_y = 0
   end
end

function _draw()
   cls(black)

   camera(cam.x, cam.y)
   rectfill(cam.x, cam.y,  cam.x+127, cam.y+31, pink)
   rectfill(cam.x, cam.y+32, cam.x+127, cam.y+127, orange)
   line(cam.x, WATER_LINE, cam.x+127, WATER_LINE, white)

   rectfill(cam.x, cam.y, cam.x+127, cam.y+7, white)
   print(dumper(player.speed_x, ' @ ', player.x, ' ^ ', player.speed_y, ' y ', player.y, ' b ', player.bounces), cam.x+1, cam.y+1, slate)

   pal(ember, tea, 1)
   for sw in all(level) do
      for i = 1,sw.height do
         spr(16, sw.x, 127-(8*i))
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
0aa99aa0000500007f0000f700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaa000000500000f00f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
008d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
