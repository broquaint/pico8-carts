pico-8 cartridge // http://www.pico-8.com
version 39
__lua__
-- eggjam16
-- by broquaint

#include utils.lua
#include animation.lua

g_anims = {}

acceleration = 0.7
friction = 0.8
max_speed = 4

game_state_playing = 'playing'
game_state_crashed = 'crashed'
   
function _init()
   camera()

   g_anims = {}

   obstacles = {}
   heat_particles = {}
   rock_particles = {}

   frame_count = 0
   depth_count = 0

   player = make_obj({
      x = 32,
      y = 12,
      sprite = 1,
      speed_x = 0,
      move_dir = 0,
   })

   current_game_state = game_state_playing
end

function run_animations()
   for obj in all(g_anims) do
      if costatus(obj.co) != 'dead' then
         coresume(obj.co)
      else
         del(g_anims, obj)
      end
   end
end

function calc_player_speed(dir)
   -- player.speed_x *= player.move_dir * friction
   player.speed_x += dir * acceleration
   if abs(player.speed_x) > max_speed then
      player.speed_x = dir * max_speed
   end
   return player.speed_x
end

function move_player()
   if btn(b_right) then
      local next_x = player.x + calc_player_speed(1)
      player.x = next_x < 120 and next_x or player.x
      player.move_dir = 1
   elseif btn(b_left) then
      local next_x = player.x + calc_player_speed(-1)
      player.x = next_x > 0 and next_x or player.x
      player.move_dir = -1
   elseif player.move_dir != 0 and abs(player.speed_x) > 0 then
      -- Apply friction slowly, make it feel slidey
      if (frame_count%3==0) then
         player.speed_x = player.speed_x * friction
      end
      local next_x = player.x + player.speed_x
      player.x = (next_x < 120 and next_x > 0) and next_x or player.x
   end
end

obstacle_frequency = {
   {rock=1},
   {rock=2},
   {missile=1},
   {rock=3},
   {rock=3, missile=1},
   {rock=4},
   {rock=4, missile=1},
   {rock=5},
   {rock=5},
   {rock=5, missile=1},
   {rock=5, missile=2},
   {rock=6, missile=1},
   {rock=6},
   {rock=6, missile=2},
   {rock=7},
   {rock=7, missile=2},
}

function rand_tile_x()
   local x = randx(127)
   return x - (x % 8)
end

function populate_obstacles()
   if #obstacles == 0 and #obstacle_frequency > 0 then
      local next_obstacles = deli(obstacle_frequency, 1)

      for n = 1, (next_obstacles.rock or 0) do
         local rock_x  = rand_tile_x(x)
         local angle_x = rock_x < 65 and rnd() or -rnd()
         local rock = make_obj({
               type = 'rock',
               x = rock_x,
               y = 128 + (8 + n * 3) * n,
               angle = angle_x,
               sprite = 15+randx(3),
               speed = 1 + n/3,
               last_collide = rnd() -- make equality check easier
         })
         -- dump_once(rock)
         add(obstacles, rock)
      end

      for n = 1, (next_obstacles.missile or 0) do
         local rock_x  = rand_tile_x(x)
         local angle_x = rock_x < 65 and rnd() or -rnd()
         local missile = make_obj({
               type = 'missile',
               x = rock_x,
               y = 160 + (n * 30) * n,
               angle = angle_x,
               sprite = 21,
               speed = 3 + n/3,
               last_collide = rnd() -- make equality check easier
         })
         -- dump_once(rock)
         add(obstacles, missile)
      end
   end
end

function rising_particles()
   if frame_count % 30 == 0 then
      local orig_x = 16 + randx(112)
      local p = make_obj({
            x = 16 + orig_x,
            y = 128,
            orig_x = orig_x,
            frames = 32 + randx(96),
            freq = 10 + randx(15),
            speed = 1 + rnd(),
            colour = ({silver, silver, white, dim_grey})[randx(4)]
      })
      add(heat_particles, p)
      animate_obj(p, function(p)
                     for f = 1, p.frames do
                        p.x = p.orig_x+sin(p.y/127)*p.freq
                        p.y -= p.speed
                        yield()
                     end
                     p.alive = false
      end)
   end
end

function make_rock_particles()
   for ob in all(obstacles) do
      if ob.type == 'rock' then
         local p = make_obj({
               x = ob.x + randx(8),
               y = ob.y + randx(8) + 4,
               frames = 50 + randx(50),
               colour = white
         })
         add(rock_particles, p)
         animate_obj(p, function()
                        for f = 1, p.frames do
                           if f > 85 then
                              p.colour = dim_grey
                           elseif f > 65 then
                              p.colour = silver
                           elseif f > 50 then
                              p.colour = white
                           elseif f > 20 then
                              p.colour = silver
                           elseif f > 15 then
                              p.colour = red
                           elseif f > 10 then
                              p.colour = orange
                           elseif f > 5 then
                              p.colour = yellow
                           end
                           yield()
                        end
                        p.alive = false
         end)
      elseif ob.type == 'missile' then
         local p = make_obj({
               x = ob.x + randx(3),
               y = ob.y + randx(6) + 2,
               frames = 30 + randx(10),
               colour = white
         })
         add(rock_particles, p)
         animate_obj(p, function()
                        for f = 1, p.frames do
                           if f > 29 then
                              p.colour = silver
                           elseif f > 23 then
                              p.colour = white
                           elseif f > 18 then
                              p.colour = silver
                           elseif f > 13 then
                              p.colour = red
                           elseif f > 10 then
                              p.colour = orange
                           elseif f > 7 then
                              p.colour = yellow
                           end
                           yield()
                        end
                        p.alive = false
         end)

      end
   end
end

function handle_obstacle_collision()
   for obstacle in all(obstacles) do
      obstacle.y = obstacle.y - obstacle.speed
      -- debug('angle', obstacle.angle, ' adds ', next_x)
      local next_x = obstacle.x + obstacle.angle
      if next_x < 0 then
         obstacle.angle = abs(obstacle.angle)
      elseif next_x > 120 then
         obstacle.angle = -obstacle.angle
      else
         obstacle.x += obstacle.angle
      end
      for ob2 in all(obstacles) do
         if obstacle != ob2 and obstacle.last_collide != ob2.last_collide then
            local o1x1 = obstacle.x + 8
            local o2x1 = ob2.x + 8
            if obstacle.y > ob2.y and obstacle.y<(ob2.y+8) then
               if obstacle.x > ob2.x and obstacle.x < o2x1 then
                  obstacle.angle = -obstacle.angle
                  obstacle.last_collide = ob2
               elseif o1x1 < o2x1 and o1x1 > ob2.x then
                  ob2.angle = -ob2.angle
                  ob2.last_collide = obstacle
               end
            end
         end
      end
   end
end

function detect_player_collision()
   -- Make bounding box small than sprite
   local px1 = player.x + 1
   local px2 = player.x + 6
   local py1 = player.y + 1
   local py2 = player.y + 6
   for obstacle in all(obstacles) do
      local ox1 = obstacle.x + 1
      local ox2 = obstacle.x + 6
      local oy1 = obstacle.y + 1
      local oy2 = obstacle.y + 6

      -- If the player is above the obstacle detect stuff.
      if py1 < oy2 then
         -- bottom line intersection with top line
         if py2 >= oy1 and py2 <= oy2
            and ((px1 >= ox1 and px1 <= ox2) or (px2 >= ox1 and px2 <= ox2))
         then
            debug('bottom of ', player, ' collided with ', obstacle)
            return true
         -- left line intersects with top line
         elseif px1 >= ox1 and px1 <= ox2
            and ((py1 >= oy1 and py1 <= oy2) or (py2 >= oy1 and py2 <= oy2))
         then
            debug('left of ', player, ' collided with ', obstacle)
            return true
         -- right line intersects with top line
         elseif px2 >= ox1 and px2 <= ox2
            and ((py1 >= oy1 and py1 <= oy2) or (py2 >= oy1 and py2 <= oy2))
         then
            dump_once('right of ', player, ' collided with ', obstacle)
            return true
         end
      end
   end
end

function drop_off_screen_obstacles()
   for idx,obstacle in pairs(obstacles) do
      if obstacle.y < -8 then
         deli(obstacles, idx)
      end
   end
end

function drop_dead_particles()
   for idx, p in pairs(heat_particles) do
      if not p.alive then
         deli(heat_particles, idx)
      end
   end
   for idx, p in pairs(rock_particles) do
      if not p.alive then
         deli(rock_particles, idx)
      end
   end
end

function _update()
   frame_count += 1

   if current_game_state != game_state_playing then
      return
   end

   if frame_count % 30 == 0 then
      depth_count += 1
   end

   run_animations()

   move_player()

   populate_obstacles()

   rising_particles()

   make_rock_particles()

   handle_obstacle_collision()

   if detect_player_collision() then
      current_game_state = game_state_crashed
   end

   drop_off_screen_obstacles()

   drop_dead_particles()
end

bg_y = 120
function _draw()
   cls(black)

   if depth_count > 2 then
      for n = 0, 7 do
         local offset = n*17
         spr(32, 1 +  offset, bg_y)
         spr(33, 9 +  offset, bg_y)
         spr(34, 17 + offset, bg_y)
      end
      rectfill(0, bg_y+8, 127, 127, dim_grey)
      -- This is gross but effective
      bg_y -= 1
   end

   for p in all(heat_particles) do
      pset(p.x, p.y, p.colour)
   end

   for p in all(rock_particles) do
      pset(p.x, p.y, p.colour)
   end

   for obstacle in all(obstacles) do
      spr(obstacle.sprite, obstacle.x, obstacle.y)
      -- rect(obstacle.x + 1, obstacle.y + 1, obstacle.x + 6, obstacle.y + 6, lime)
   end
   
   print(depth_count .. 'M', 1, 1, white)
   -- print('cool', 16, 16, frame_count % 16)
   spr(player.sprite, player.x, player.y)
   -- rect(player.x + 1, player.y + 1, player.x + 6, player.y + 6, lime)

   if current_game_state != game_state_playing then
      rectfill(32, 24, 96, 48, white)
      print('science over', 36, 42, red)
   end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000aaafaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000accafa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000aaaafa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000accaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005550000555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000555000554550044455550000000000000000000aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555550044445504444445500000000000000000aa8aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000
05444450044444404444444400000000000000000a9e9a0000000000000000000000000000000000000000000000000000000000000000000000000000000000
444444500444444044444444000000000000000000787a0000000000000000000000000000000000000000000000000000000000000000000000000000000000
4994444409444440994444440000000000000000007ea00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00994994099444900999499000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00099900009999900009990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05000000000000500500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000005000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55000500005500000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05000000050050500000550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000050550550005005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555505050000500550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
180400001a6301a6301a6301a6301a6301a6301a63019630186301663015630146301463014630186301c62020610246102560000600006000060000600006000060000600006000060000600006000060000600
