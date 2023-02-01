pico-8 cartridge // http://www.pico-8.com
version 39
__lua__
-- tephra toil
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
   air_streaks = {}
   heat_particles = {}
   rock_particles = {}

   frame_count = 0
   depth_count = 0

   player = make_obj({
      x = 32,
      y = 12,
      default_y = 12,
      frames = 22,
      sprite = 1,
      speed_x = 0,
      move_dir = 0,
      diving = false,
      health = 3,
      default_health = 3,
      iframes = false,
      scanned = 0
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
   -- A judder or slow down or something would be better.
   if not player.iframes then
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

   if btnp(b_x) then
      if not player.diving then
         player.diving = true
         animate_obj(player, function()
                        player.from = player.y
                        player.to   = player.y + 24
                        -- debug('player pre dive ', player)
                        animate_move_y(player)

                        -- debug('player mid dive ', player)
                        player.from = player.y
                        player.to   = player.default_y
                        animate_move_y(player)

                        -- debug('player fin dive ', player)
                        player.diving = false
         end)
      else
         -- todo ?
      end
   end
end

obstacle_frequency = {
   {rock=1},
   {lump=1},
   {rock=2},
   {missile=1},
   {rock=3},
   {rock=3, missile=1},
   {rock=3, missile=1, lump=1},
   {rock=4, lump=2},
   {rock=4, missile=1},
   {rock=5},
   {rock=5, lump=2},
   {rock=5, missile=1},
   {rock=5, missile=2, lump=1},
   {rock=6, missile=1, lump=1},
   {rock=6},
   {rock=6, missile=2, lump=2},
   {rock=7, lump=1},
   {rock=7, missile=2},
   {rock=7, missile=2},
   {rock=7, missile=2},
   {rock=7, missile=2, lump=2},
   {rock=4, missile=3},
   {rock=4, missile=3, lump=1},
   {rock=4, missile=4},
   {rock=4, missile=4},
   {rock=3, missile=5},
}

function rand_tile_x()
   local x = randx(127)
   return x - (x % 8)
end

function make_obstacle(obj)
   return make_obj(merge({
                         closest = false,
                         scan_time = 0,
                         distance_from_pp = 128,
                         data_scanned = false,
                         }, obj))
end

function make_rock()
   local rock_x  = rand_tile_x()
   local angle_x = rock_x < 65 and rnd() or -rnd()
   local depth_speed = depth_count / 30
   return make_obstacle({
         type = 'rock',
         x = rock_x,
         y = 128,
         angle = angle_x,
         sprite = 15+randx(3),
         speed = depth_speed + 1,
         last_collide = rnd(), -- make equality check easier
         scan_length = 25,
   })
end

function make_missile()
   local rock_x  = rand_tile_x()
   local angle_x = rock_x < 65 and rnd() or -rnd()
   local depth_speed = depth_count / 30
   return make_obstacle({
         type = 'missile',
         x = rock_x,
         y = 160,
         angle = angle_x,
         sprite = 21,
         speed = depth_speed + 3,
         last_collide = rnd(), -- make equality check easier
         scan_length = 15,
   })
end

function make_lump()
   local rock_x  = rand_tile_x()
   local angle_x = rock_x < 65 and rnd() or -rnd()
   local depth_speed = depth_count / 30
   return make_obstacle({
         type = 'lump',
         x = rock_x,
         y = 128,
         angle = angle_x,
         sprite = {24,25,40,41},
         speed = depth_speed + 0.7,
         last_collide = rnd(), -- make equality check easier
         scan_length = 45
   })
end

function populate_obstacles()
   if #obstacle_frequency > 0 and frame_count % 80 == 0 then
      local next_obstacles = deli(obstacle_frequency, 1)

      local depth_speed = depth_count / 30
      for n = 1, (next_obstacles.rock or 0) do
         local rock = make_rock()
         rock.y     += (8 + n * 3) * n
         rock.speed += n / 3
         -- dump_once(rock)
         add(obstacles, rock)
      end

      for n = 1, (next_obstacles.missile or 0) do
         local missile = make_missile()
         missile.y     += (n * 30) * n
         missile.speed += n / 3
         -- dump_once(rock)
         add(obstacles, missile)
      end

      for n = 1, (next_obstacles.lump or 0) do
         local lump = make_lump()
         lump.y     += (n * 30) * n
         lump.speed += n / 3
         -- dump_once(rock)
         add(obstacles, lump)
      end
   end

   if frame_count % 90 == 0 then
      local obstacle = ({make_rock, make_missile, make_lump})[randx(3)]()
      obstacle.y += 30
      obstacle.speed += depth_count / 20
      add(obstacles, obstacle)
   end
end

function falling_air_streaks()
   if frame_count % 30 == 0 then
      local streak = make_obj({
            x = rand_tile_x(),
            y = 128,
            length = 12,
            frames = 141,
            speed = 2 + rnd(),
            colour = silver,
      })
      add(air_streaks, streak)
      animate_obj(streak, function(s)
                     for f = 1, s.frames do
                        s.y -= s.speed
                        yield()
                     end
                     s.alive = false
      end)
   end
end

function rising_heat_particles()
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
      elseif ob.type == 'lump' then
         for _ = 1, 4 do
            local p = make_obj({
                  x = ob.x + randx(12),
                  y = ob.y + randx(14) + 2,
                  frames = 20 + randx(20),
                  colour = white
            })
            add(rock_particles, p)
            animate_obj(p, function()
                           for f = 1, p.frames do
                              if f > 20 then
                                 p.colour = dim_grey
                              elseif f > 15 then
                                 p.colour = white
                              elseif f > 10 then
                                 p.colour = silver
                              elseif f > 5 then
                                 p.colour = yellow
                              end
                              yield()
                           end
                           p.alive = false
            end)
         end
      end
   end
end

function move_obstacles()
   for obstacle in all(obstacles) do
      obstacle.y = obstacle.y - obstacle.speed
      -- debug('angle', obstacle.angle, ' adds ', next_x)
      local next_x = obstacle.x + obstacle.angle
      if next_x < 0 then
         obstacle.angle = abs(obstacle.angle)
      elseif next_x > 120 or (obstacle.type == 'lump' and next_x > 112) then
         obstacle.angle = -obstacle.angle
      else
         obstacle.x += obstacle.angle
      end
   end
end

function handle_obstacle_collision()
   for obstacle in all(obstacles) do
      for ob2 in all(obstacles) do
         if obstacle != ob2 and obstacle.last_collide != ob2.last_collide then
            local o1x1 = obstacle.x + (obstacle.type == 'lump' and 16 or 8)
            local o2x1 = ob2.x + (ob2.type == 'lump' and 16 or 8)
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
      local is_lump = obstacle.type == 'lump'
      local ox1 = obstacle.x + 1
      local ox2 = obstacle.x + (is_lump and 14 or 6)
      local oy1 = obstacle.y + 1
      local oy2 = obstacle.y + (is_lump and 14 or 6)

      -- If the player is above the obstacle detect stuff.
      if py1 < oy2 then
         -- bottom line intersection with top line
         if py2 >= oy1 and py2 <= oy2
            and ((px1 >= ox1 and px1 <= ox2) or (px2 >= ox1 and px2 <= ox2))
         then
            -- debug('bottom of ', player, ' collided with ', obstacle)
            return true
         -- left line intersects with top line
         elseif px1 >= ox1 and px1 <= ox2
            and ((py1 >= oy1 and py1 <= oy2) or (py2 >= oy1 and py2 <= oy2))
         then
            -- debug('left of ', player, ' collided with ', obstacle)
            return true
         -- right line intersects with top line
         elseif px2 >= ox1 and px2 <= ox2
            and ((py1 >= oy1 and py1 <= oy2) or (py2 >= oy1 and py2 <= oy2))
         then
            -- dump_once('right of ', player, ' collided with ', obstacle)
            return true
         end
      end
   end
end

function detect_proximity()
   local prox = 128
   local nearest = nil
   for o in all(obstacles) do
      o.closest = false
      local a = abs(o.y - player.y)
      local b = abs(o.x - player.x)
      local d = sqrt((a * a) + (b * b))

      if o.y > player.y and d < prox then
         nearest = o
         o.distance_from_pp = d
         prox = d
      end
   end
   if nearest then
      nearest.closest = true
      nearest.scan_time += 1
      if not nearest.data_scanned and nearest.scan_time >= nearest.scan_length then
         player.scanned += 1
         nearest.data_scanned = true
      end
   end
end

function handle_player_collision()
   if not player.iframes and detect_player_collision() then
      player.health = max(0, player.health - 1)
      player.iframes = true
      player.speed_x = 0
      animate(function()
            for i = 1,44 do
               if i % 5 == 0 then
                  player.sprite = player.sprite == 1 and 2 or 1
               end
               yield()
            end
            player.sprite = 1
            player.iframes = false
      end)
   end
end

function drop_off_screen_obstacles()
   for idx,obstacle in pairs(obstacles) do
      if obstacle.y < -17 then
         deli(obstacles, idx)
      end
   end
end

function drop_dead_particles()
   for idx, p in pairs(air_streaks) do
      if not p.alive then
         deli(air_streaks, idx)
      end
   end
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
      -- help find weird memory bug hopefully
      debug('memory usage: ', stat(0))
   elseif stat(0) > 800 then
      debug('BAD memory usage: ', stat(0))
   end

   run_animations()

   falling_air_streaks()
   rising_heat_particles()
   make_rock_particles()

   populate_obstacles()
   move_obstacles()
   handle_obstacle_collision()

   move_player()
   handle_player_collision()
   detect_proximity()

   if player.health == 0 then
      current_game_state = game_state_crashed
      debug('end game memory usage: ', stat(0))
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
      --fillp(∧)
      rectfill(0, bg_y+8, 127, 127, dim_grey)
      --fillp()
      -- This is gross but effective
      bg_y -= 1
   end

   for s in all(air_streaks) do
      line(s.x, s.y, s.x, s.y - s.length, s.colour)
   end

   for p in all(heat_particles) do
      pset(p.x, p.y, p.colour)
   end

   for p in all(rock_particles) do
      pset(p.x, p.y, p.colour)
   end

   local closest = nil
   for obstacle in all(obstacles) do
      if obstacle.type == 'lump' then
         sspr(8*8, 8, 16, 16, obstacle.x, obstacle.y)
      else
         spr(obstacle.sprite, obstacle.x, obstacle.y)
         -- rect(obstacle.x + 1, obstacle.y + 1, obstacle.x + 6, obstacle.y + 6, lime)
      end
      if obstacle.closest then
         closest = obstacle
         -- rect(obstacle.x + 1, obstacle.y + 1, obstacle.x + 6, obstacle.y + 6, lime)
         line(obstacle.x + 4, obstacle.y + 4, player.x + 4, player.y + 4, white)
         print('dist ' .. tostr(obstacle.distance_from_pp), 1, 60, white)
      end
   end

   -- print('cool', 16, 16, frame_count % 16)
   spr(player.sprite, player.x, player.y)
   -- sspr(3*8, 0, 16, 8, player.x-8, player.y+8, 32, 24)
   -- rect(player.x + 1, player.y + 1, player.x + 6, player.y + 6, lime)

   --rectfill(0, 0, 128, 7, dim_grey)
   print('depth ' .. depth_count .. 'M', 1, 1, white)
   -- print('health ', 36, 1, white)
   for i = 1,player.default_health do
      print('♥', 36 + (i*6), 1, (player.health >= i and red or navy))
   end

   print('scanned ' .. tostr(player.scanned), 64, 1, white)
   if closest then
      local pct = min(closest.scan_time, closest.scan_length) / closest.scan_length
      rectfill(105, 1, 105 + (20 * pct), 6, white)
   end

   if current_game_state != game_state_playing then
      rectfill(32, 24, 96, 48, white)
      print('science over', 42, 36, red)
   end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaaa0000111c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000aaafaa00111c11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000accafa001dd111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000aaaafa001111f1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000accaaa001dd1f1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaaa000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005550000555000000000000000000000000000000000000000000000000004444000000000000000000000000000000000000000000000000000000
000555000554550044455550000000000000000000aa000000000000000000000044444444440000000000000000000000000000000000000000000000000000
00555550044445504444445500000000000000000aa8aa0000000000000000000444444444444000000000000000000000000000000000000000000000000000
05444450044444404444444400000000000000000a9e9a0000000000000000004444444444444400000000000000000000000000000000000000000000000000
444444500444444044444444000000000000000000787a0000000000000000004444999999944440000000000000000000000000000000000000000000000000
4994444409444440994444440000000000000000007ea00000000000000000004499998899944440000000000000000000000000000000000000000000000000
00994994099444900999499000000000000000000000000000000000000000004499888889994444000000000000000000000000000000000000000000000000
0009990000999990000999000000000000000000000000000000000000000000499988aaa8994444000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000499988a7a89944d0000000000000000000000000000000000000000000000000
0500000000000050050000000000000000000000000000000000000000000000449998aa88994dd0000000000000000000000000000000000000000000000000
0000000000000500000000500000000000000000000000000000000000000000d44999888994dd00000000000000000000000000000000000000000000000000
5500050000550000050000000000000000000000000000000000000000000000ddd49999994dd000000000000000000000000000000000000000000000000000
050000000500505000005500000000000000000000000000000000000000000000dd444494dd0000000000000000000000000000000000000000000000000000
0000005055055000500550000000000000000000000000000000000000000000000dddd44dd00000000000000000000000000000000000000000000000000000
00555505050000500550000000000000000000000000000000000000000000000000000ddd000000000000000000000000000000000000000000000000000000
55555555555555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
180400001a6301a6301a6301a6301a6301a6301a63019630186301663015630146301463014630186301c62020610246102560000600006000060000600006000060000600006000060000600006000060000600
