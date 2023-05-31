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
         frames = 1,
         sprite = 0,
         move_dir = 0,
         speed_x = 0,
         speed_y = 0,
         jumping = false,
         bounces = 0,
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
   player.speed_x *= 0.991

   -- jump/water physics
   if btn(b_x) and not player.jumping then
      player.speed_y = -3
      player.jumping = true
      player.bounces = 1
      player.prev_grav = air_grav
   end
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

   cam.x    += player.speed_x
   player.x += player.speed_x
   player.y += (1/player.bounces*player.speed_y)
end

function _draw()
   cls(black)

   camera(cam.x, cam.y)
   rectfill(cam.x, cam.y,  cam.x+127, cam.y+31, pink)
   rectfill(cam.x, cam.y+32, cam.x+127, cam.y+127, orange)
   line(cam.x, WATER_LINE, cam.x+127, WATER_LINE, white)
   spr(player.sprite, player.x, player.y)

   rectfill(cam.x, cam.y, cam.x+127, cam.y+7, white)
   print(dumper(player.speed_x, ' @ ', player.x, ' ^ ', player.speed_y, ' y ', player.y, ' b ', player.bounces), cam.x+1, cam.y+1, slate)

   pal(ember, tea, 1)
   for sw in all(level) do
      for i = 1,sw.height do
         spr(16, sw.x, 127-(8*i))
      end
   end

   for s in all(splashes) do
      if s.animating then
         spr(2, s.x, s.y)
      end
   end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aacaca0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aacaca0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a9aaaa0000000007000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa99aa0009009007900009700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaa00099999900090090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000996666990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
008d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
