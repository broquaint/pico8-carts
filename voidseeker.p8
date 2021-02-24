pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
-- void seeker
-- by broquaint

-- constants

-- Brain won't map colours to numbers so get computer to do it
black    = 0 navy     = 1 magenta  = 2 green    = 3
brown    = 4 dim_grey = 5 silver   = 6 white    = 7
red      = 8 orange   = 9 yellow   = 10 lime    = 11
azure    = 12 violet  = 13 salmon  = 14 coral   = 15

left  = -1
right = 1

drop_normal = 1
drop_slow   = 2
drop_fast   = 4

sfx_drop_tbl = {
   [drop_normal] = 1,
   [drop_slow]   = 3,
   [drop_fast]   = 2
}

facing_right_spr = 4
facing_left_spr  = 3

gapspr={2,5,6}

warp_item_spr = 16
item_warp     = 'warp'
grav_item_spr  = 17
item_grav_belt = 'grav belt'
shoes_item_spr   = 18
item_speed_shoes = 'fast boots'

state_level_end = 'end of level'
state_running   = 'running'
state_no_void   = 'no void'
state_menu      = 'menu'

lower_limit = 13

normal_gravity = 0.2
gravity = normal_gravity -- Not constant, changes for slow falls etc
jump_velocity = 1.6
speed_boost = 0.02
max_speed = 3.5
normal_friction = 0.8
friction = normal_friction
normal_acceleration = 0.5
acceleration = normal_acceleration

function _init()
   reset_game_vars()
   reset_level_vars()
   gamestate = state_menu
   cartdata("broquaint_findthegap")
   -- dset(0,0) -- reset score
end

function reset_game_vars()
   level = 1
   current_item = {}
   dx = 0
   dy = 6
end

function reset_level_vars()
   gravity = normal_gravity
   x = 0
   y = 0
   dx = 0
   dy = 0
   jumping = false
   falling = true -- Fall into the level
   moving  = false
   bouncing = false
   wiping = false
   direction = 1
   jumped_from = 0
   floors_dropped = 0
   grav_fuel = 2

   acceleration = has_speed_shoes() and normal_acceleration + speed_boost or normal_acceleration

   bonus_level = level % 10 == 0

   floor = 1
   floor_unlocked = true

   sticky_floor = -1
   bouncy_floor = -1

   -- Only have "flavour" floors after 5th level.
   if level > 5 then
      if level < 20 then
         if not bonus_level and randn(3) == 2 then
            -- Never the first or last floor.
            sticky_floor = randn(5) + 1
         else
            bouncy_floor = randn(5) + 1
         end
      -- After 20th level allow >1 flavour floor.
      else
         local rem = level % 10
         if not bonus_level and rem % 3 == 0 then
            sticky_floor = randn(5) + 1
            bouncy_floor = sticky_floor > 3 and 2 or 4
         elseif rem % 4 == 0 then
            bouncy_floor = randn(5) + 1
         elseif not bonus_level and rem % 2 == 0 then
            sticky_floor = randn(5) + 1
         end
      end
   end

   key_set = {}

   timers_seen = 0
   timer_at = {}
   if(not bonus_level) then
      local base_time = 35 - flr(level / 10)
      local pressure  = level * 0.5
      if level > 10 then
         time_limit = base_time - min(pressure, lower_limit)
      else
         time_limit = base_time - level
      end
   else
      time_limit = max(15 - (level/10), 9)
   end
   extra_time = 0

   begin = t()
   gamestate = state_running
   lvldone = nil
   in_void = false
   new_highscore = false

   set_items()
   set_gaps()
   set_keys()
   set_launchers()
   set_bouncers()
end

function has_warp(item)
   if(item == nil) item = current_item
   return item[4] == item_warp
end

function has_grav_belt(item)
   if(item == nil) item = current_item
   return item[4] == item_grav_belt
end

function has_speed_shoes(item)
   if(item == nil) item = current_item
   return item[4] == item_speed_shoes
end

function is_pos_in_set(pos_set, pos)
   for p in all(pos_set) do
      if(pos[1] == p[1]) return true
   end
   return false
end

function find_free_tile(known, tile_gen)
   local new_y   = floor * 16 - 8
   local new_pos = tile_gen()
   -- Enter loop if the new tile position is already present to generate a new position.
   while(is_pos_in_set(known, new_pos)) do
      new_pos = tile_gen()
   end
   return new_pos
end

function find_free_item_tile(known, tile_gen)
   local to_consider = copy_table(item_set)
   for v in all(known) do
      add(to_consider, v)
   end
   return find_free_tile(to_consider, tile_gen)
end

function set_gaps()
   gap_set = {}

   local function gap_gen()
      local x1 = randn(14) * 8
      local sprite
      if level == 1 then
         sprite = gapspr[1]
      elseif level == 2 or bonus_level then
         sprite = ({2,6})[randn(2)]
      else
         sprite = gapspr[randn(#gapspr)]
      end
      return { x1, x1 + 8, sprite }
   end
   for iy=1,7 do
      local gapcount = randn(not bonus_level and 2 or 1)

      -- Ensure sticky floors always have 2 gaps.
      if(iy == sticky_floor and gapcount < 2) gapcount += 1

      local gaps = {}
      for idx=1,gapcount do
         -- Jam the gap sprite onto the position.
         add(gaps, find_free_tile(gaps, gap_gen))
         if iy == bouncy_floor then
            gaps[#gaps][3] = gapspr[1]
         end
      end

      -- If the current item or grav belt is warp always ensure 1 slow gap.
      if (has_warp() or has_grav_belt()) and iy != bouncy_floor and
         every(gaps, function(g) return fget(g[3]) != drop_slow end) then
         -- Don't add another gap if there's already 3
         if(#gaps == 3) then
            gaps[#gaps][3] = gapspr[2]
         else
            local gap = find_free_tile(gaps, gap_gen)
            gap[3] = gapspr[2]
            add(gaps, gap)
         end
      end

      -- If the current item is speed shoes ensure no fast gaps.
      if has_speed_shoes() then
         for gap in all(gaps) do
            if(gap[3] == 6) gap[3] = 5
         end
      end

      -- Ensure there's at least one non-slow gap.
      if every(gaps, function(g) return fget(g[3]) == drop_slow end) then
         -- Don't add another gap if there's already 3
         if(#gaps == 3) then
            gaps[#gaps][3] = gapspr[1]
         else
            local gap = find_free_tile(gaps, gap_gen)
            gap[3] = gapspr[1]
            add(gaps, gap)
         end
      end

      gap_set[iy] = gaps
   end
end

function set_keys()
   key_set = {{}}

   for iy = 2,7 do
      local function key_gen()
         local y_offset = 8
         if(level > 5 and randn(4) > 3) y_offset = 13
         return {(randn(15) * 8), iy * 16 - y_offset}
      end
      local keys = {}
      if not bonus_level and level > 3 and randn(10) < level then
         local key_count = #gap_set[iy]
         for _ = 1, key_count do
            add(keys, find_free_item_tile(keys, key_gen))
         end
      end
      key_set[iy] = keys
   end
   -- Ensure at least one floor is free of keys.
   key_set[randn(#key_set - 2) + 2] = {}
   add(key_set, {})
end

function set_launchers()
   local function find_free_floor_tile(launchers, iy)
      local to_consider = copy_table(launchers)
      for v in all(gap_set[iy]) do add(to_consider, v) end
      -- if level < 15 then
      for v in all(item_set[iy]) do add(to_consider, v) end
      for v in all(key_set[iy]) do add(to_consider, v) end
      -- end
      -- printh('considering: ', to_consider)
      return find_free_tile(
         to_consider, function() return {((randn(13) + 1) * 8), iy * 16 - 8} end
      )
   end

   launcher_set = {{}}

   local seen = 0
   for iy = 2,7 do
      local launchers = {}
      local lcount = level < 8 and 1 or (level < 18 or bonus_level) and 2 or 3
      -- Add launcher 1 in 4 times if it's after level 8, it's a regular floor,
      -- once generate up to 1 before level 8, 2 before level 18, 3 before level 28
      -- then an aribtrary amount after that.
      for _ = 1, lcount do
         if randn(4) == 2 and level > 3
            and (iy != sticky_floor and iy != bouncy_floor)
            and ((level < 8 and seen < 1) and (level < 18 and seen < 2) or (level < 28 and seen < 3) or (level > 31)) then
            add(launchers, find_free_floor_tile(launchers, iy))
         end
      end
      seen += #launchers > 0 and 1 or 0
      launcher_set[iy] = launchers
   end

   add(launcher_set, {})
   -- printh('launchers: ' .. arr_to_str(launcher_set))
end

function set_bouncers()
   local function find_free_floor_tile(bouncers, iy)
      local to_consider = copy_table(bouncers)
      for v in all(gap_set[iy]) do add(to_consider, v) end
      -- if level < 15 then
      for v in all(item_set[iy]) do add(to_consider, v) end
      for v in all(key_set[iy]) do add(to_consider, v) end
      for v in all(launcher_set[iy]) do add(to_consider, v) end
      -- end
      -- printh('considering: ', to_consider)
      return find_free_tile(
         to_consider, function() return {((randn(14) + 1) * 8), iy * 16 - 8} end
      )
   end

   bouncer_set = {{}}

   local seen = 0
   for iy = 2,7 do
      local bouncers = {}
      local bcount = level < 6 and 1 or (level < 16 or bonus_level) and 2 or 3
      for _ = 1, bcount do
         if randn(4) == 2 and level > 6
            and (iy != sticky_floor and iy != bouncy_floor)
            and ((level < 8 and seen < 1) and (level < 18 and seen < 2) or (level < 28 and seen < 3) or (level > 31)) then
            add(bouncers, find_free_floor_tile(bouncers, iy))
         end
      end
      seen += #bouncers > 0 and 1 or 0
      bouncer_set[iy] = bouncers
   end

   add(bouncer_set, {})
end

function set_items()
   item_set = {}
   if level > 3 and not bonus_level and level % 2 == 0 then
      local possible_items = shuffle({
         {8,   warp_item_spr,  item_warp},
         {64,  shoes_item_spr, item_speed_shoes},
         {112, grav_item_spr,  item_grav_belt}
      })
      for item in all(possible_items) do
         if current_item[4] != item[3] then
            local item_y = (randn(6) + 1) * 16 - 8
            add(item_set, {item[1], item_y, item[2], item[3]})
            break
         end
      end
   end
end

function above_gap()
   for gap in all(gap_set[floor] or {{-1,-1}}) do
      if((x + 2) > gap[1] and (x + 4) < gap[2]) return gap
   end
   return false
end

function progress_floor()
   falling = true
   floor += 1
   floors_dropped += 1

   floor_locked = #key_set[floor] > 0

   timer_max = min(flr(floor/5), 2)
   -- If before the last floor and after level 5 and there's either
   -- a increasingly likely chance or a launcher below and a timer hasn't
   -- been seen yet and it's not a bonus level and the current item
   -- isn't speed shoes then generate a timer.
   if floor < 7 and level > 5
   and (randn(15) < level or #launcher_set[floor+1] > 0)
   and timers_seen < timer_max and not bonus_level and not has_speed_shoes() then
      timers_seen += 1
      local timer_gen = function () return {(randn(15) * 8), floor * 16 - 8, floor} end
      -- TODO handle bouncers
      timer_at = find_free_item_tile(key_set[floor], timer_gen)
   end
end

function start_jump()
   jumping = true
   jumped_from = x
   dy -= jump_velocity
   if(sticky_floor == floor) acceleration = normal_acceleration
   sfx(0)
end

function compute_gap_effect(gap)
   local effect = fget(gap[3])
   if(effect == drop_normal) then
      dy = 1
      acceleration = has_speed_shoes() and normal_acceleration + speed_boost or normal_acceleration
   elseif(effect == drop_slow) then
      slow_gap_fall()
   elseif(effect == drop_fast) then
      dy = 3.5
      -- No boost with speed shoes.
      acceleration += has_speed_shoes() and 0 or 0.3
   end
end

function slow_gap_fall()
   -- Not so slow if the gap is jumped into.
   if has_grav_belt() or (floors_dropped == 1 and jumping) then
      gravity *= 0.3
      dy *= 0.3
   elseif floors_dropped > 1 then
      dy += 1
   else
      y += 1 -- Indicate movement .. not ideal though.
      gravity = 0.01
      dy = 0.01
      acceleration = has_speed_shoes() and normal_acceleration or normal_acceleration * 0.7
   end
end

function apply_gravity()
   dy += gravity
   y  += dy

   local player_feet = y + 8
   local next_floor  = floor * 16

   if gamestate == state_level_end then return end

   if dy >= 0 and (player_feet >= next_floor) then
      local gap    = above_gap()
      local effect = gap and fget(gap[3])

      if gap and not floor_locked then
         progress_floor()
         compute_gap_effect(gap)

         if floors_dropped == 1 then
            if effect == drop_slow and jumping then
               sfx(17)
            else
               sfx(sfx_drop_tbl[effect])
            end
         else
            sfx(13 + floors_dropped)
         end

         jumping = false
      else
         -- Handle the void floor so the player is placed on the "surface"
         y = next_floor - (floor == 8 and 10 or 8)
         dy = 0

         if bouncy_floor == floor then
            -- Reset gravity otherwise bouncing from a slow gap is bugged.
            gravity = normal_gravity
            start_jump()
         else
            -- Reset gravity after slow falls
            gravity = normal_gravity
            falling = false
            jumping = false
            grav_fuel = 2

            if sticky_floor == floor then
               -- dx = direction * (speed * 0.2)
               if has_speed_shoes() then
                  acceleration *= 0.05
               else
                  acceleration *= 0.2
               end
            end

            if floors_dropped > 1 and not has_speed_shoes() then
               -- dx += floors_dropped / 2
               if has_speed_shoes() then
                  acceleration += (floors_dropped / 2) * 0.07
               else
                  acceleration += 0.3
               end
               info_flash('speed boost!', 1)
               flash(function() pal(brown, red) end, 0.5)
               delay(function() flash(function() pal(brown, orange) end, 0.5) end, 0.5)
               delay(function() pal(brown, brown) end, 1.1)
            end

            floors_dropped = 0
         end
      end
   elseif has_grav_belt() and dy <= 0 then
      if flr(player_feet / 16) < (floor - 1) then
         if(floor != 1) then
            floor -= 1
            sfx(21)
         end
      end
   end
end

function bound_movement(cx)
   if cx < 0 then
      if has_warp() then
         return 120, 14
      else
         return 0
      end
   elseif cx >= 120 then
      if has_warp() then
         return 0, 13
      else
         return 120
      end
   else
      return cx
   end
end

function move_player_horizontal(direction_moved)
   if direction_moved == left or direction_moved == right then
      direction = direction_moved
   elseif not has_speed_shoes() then
      return
   end

   -- If speed shoes are possessed then compute movement based on momentum
   if has_speed_shoes() then
      x = bound_movement(x + dx)

      dx *= friction
      if(not moving) dx *= friction

      if direction_moved == left then
         dx = dx - acceleration
      elseif direction_moved == right then
         dx = dx + acceleration
      end
   -- Otherwise movement maps directly to input.
   else
      local speed = min(max_speed, acceleration * 3.5)
      local warp_sfx
      if direction == left then
         x, warp_sfx = bound_movement(x - speed)
      elseif direction == right then
         x, warp_sfx = bound_movement(x + speed)
      end
      if(warp_sfx != nil) sfx(warp_sfx)
   end

   if(abs(dx) > max_speed) dx = max_speed * direction
end

function _update()
   run_delays()

   if(gamestate == state_menu) then
      if(btn(5)) then
         gamestate = state_running
         sfx(9)
      end
      return
   end

   local running_time = t() - begin - extra_time

   if gamestate == state_level_end then
      -- Short grace period so X doesn't instantly proceed/retry
      -- which can be jarring.
      if btnp(5) and not wiping then
         local wipe_start = t()
         flash(function() wipe_screen(t() - wipe_start) end, 1)
         -- Reset the level at the point should be full
         delay(reset_level_vars, 0.5)
         wiping = true
      end
      -- Fall through the void and move towards the center.
      if(y < 150) then
         apply_gravity()
         if((x + 8) < 64 or x > 64) x += dx
      end
   elseif(gamestate == state_no_void) then
      if btn(5) and not wiping and t() - lvldone > 0.5 then
         local wipe_start = t()
         flash(function() wipe_screen(t() - wipe_start) end, 1)
         -- Reset the level at the point should be full
         delay(function()
               reset_game_vars()
               reset_level_vars()
         end, 0.5)
         wiping = true
         sfx(9)
      end
   else
      if(running_time > time_limit) then
         printh("Ran out of time at " .. t() .. " started " .. begin .. " extra time " .. extra_time .. " - time limit was " .. time_limit)
         gamestate = state_no_void
         sfx(6)
         local hiscore = dget(0)
         if(hiscore < level) then
            dset(0, level)
            new_highscore = true
         end
         return
      end

      local dir = btn(0) and 'left ' or 'right';
      local msg = dir .. 'dx was ' .. dx .. ' @ ' .. x
      move_player_horizontal(btn(0) and left or btn(1) and right or nil)
      -- if(t() % 0.25 == 0) printh(msg .. ', dx now ' .. dx .. ' @ ' .. x)

      moving = btn(0) or btn(1)

      if(not jumping and not falling and not floor_locked) then
         local gap = above_gap()
         if gap then
            compute_gap_effect(gap)

            -- printh("dx = " .. dx .. " speed = " .. speed)

            progress_floor()

            if has_grav_belt() and fget(gap[3]) == drop_slow then
               sfx(17)
            else
               sfx(sfx_drop_tbl[fget(gap[3])])
            end
         end
      end

      if not jumping and y == (floor * 16 - 8) then
         for launcher in all(launcher_set[floor]) do
            local lx = launcher[1]
            local ly = launcher[2]
            if (x + 4) > launcher[1] and x < (launcher[1] + 5) then
               jumping = true
               gravity *= 0.9
               dy -= 2.5
               floor -= 1
               sfx(18)
               flash(function() line(lx + 2, ly + 5, lx + 5, ly + 5, azure) end, 0.7)
               flash(function() line(lx + 3, ly + 4, lx + 4, ly + 4, white) end, 0.5)

               break
            end
         end
      end

      if y >= (floor * 16 - 8) and y < (floor * 16 - 4) then
         for bouncer in all(bouncer_set[floor]) do
            local bx1 = bouncer[1] + 2
            local bx2 = bx1 + 3
            local px1 = flr(x + 1)
            local px2 = flr(px1 + 5)

            if not bouncing
               and (
                     (direction == right and px2 >= bx1 and px2 < bx2)
                  or (direction == left  and px1 <= bx2 and px1 > bx1)
               )
            then
               if has_speed_shoes() then
                  dx = -dx
                  bouncing = true
                  -- Avoid getting stuck etc
                  delay(function() bouncing = false end, 0.2)
               else
                  -- Shonky emulation of being pushed back
                  local accel_was = acceleration
                  acceleration = -(acceleration + 0.8)
                  move_player_horizontal(direction)
                  delay(function()
                        if bouncing then
                           acceleration = abs(accel_was)
                           bouncing = false
                        end
                  end, 0.2)
                  bouncing = true
               end

               local by = bouncer[2]
               flash(
                  function()
                     line(bx1 - 1, by + 5, bx1 - 1, by + 6, azure)
                     line(bx2 + 1, by + 5, bx2 + 1, by + 6, azure)
                  end, 0.7
               )
               flash(function()
                     line(bx1 - 2, by + 5, bx1 - 2, by + 6, white)
                     line(bx2 + 2, by + 5, bx2 + 2, by + 6, white)
               end, 0.5)
               sfx(20)

               break
            end
         end
      end

      -- This should be after the falling check so a) you can't just spam
      -- jump to avoid slow gaps and b) so you can fall straight through gaps below.
      if not falling and not jumping and btnp(5) and y % 8 == 0 then
         start_jump()
      end

      if has_grav_belt() and grav_fuel > 0 and btnp(5) then
         if jumping and dy >= -0.25 then
            -- Basically acts like a double jump
            dy -= jump_velocity + 0.2
            grav_fuel -= 0.7
            sfx(0)
            local at_x = x
            local at_y = y
            flash(function()
                  line(at_x+1, at_y+9,  at_x+5, at_y+9,  lime)
                  line(at_x+2, at_y+10, at_x+4, at_y+10, green)
            end, 0.2)
            delay(function()
                  flash(function()
                        line(at_x+1, at_y+9,  at_x+5, at_y+9,  green)
                        line(at_x+2, at_y+10, at_x+4, at_y+10, dim_grey)
                  end, 0.1)
            end, 0.2)
         end
      end

      if not falling or bouncy_floor == floor then
         if floor_locked then
            local keys = key_set[floor]
            for idx,key in pairs(keys) do
               if  ((x + 6) > key[1] and x < (key[1] + 6))
                  and (y <= key[2] or flr(y - 2) == key[2]) then
                  deli(keys, idx)
                  sfx(4)
                  break
               end
            end

            if(#keys == 0) floor_locked = false
         end

         if #timer_at > 0 and timer_at[3] == floor and (x + 6) > timer_at[1] and x < (timer_at[1] + 6) then
            timer_at = {}
            extra_time += 3
            sfx(7)
            info_flash('+3s')
         end

         for idx, item in pairs(item_set) do
            if y == item[2] and (x + 6) > item[1] and x < (item[1] + 6) then
               if not has_speed_shoes(item) then
                  -- Reset speed if we're switching from speed shoes.
                  -- dx = normal_speed
                  -- speed = normal_speed
                  acceleration = normal_acceleration
                  friction = normal_friction
                  pal(brown, brown)
               else
                  -- dx = normal_speed + 1.4
                  -- speed = dx
                  acceleration += speed_boost
                  friction = 0.95
                  -- Luckily the only use of brown is in the shoes.
                  pal(brown, red)
               end

               if has_warp(item) then
                  local start_fade = t()
                  flash(function()
                        local d = t() - start_fade
                        local colour = d < 0.3 and silver or d < 0.6 and violet or dim_grey
                        line(0, 0, 0, 128, colour)
                        line(127, 1, 127, 128, colour)
                  end, 1)
               elseif has_warp() then
                  local start_fade = t()
                  flash(function()
                        local d = t() - start_fade
                        local colour = d < 0.3 and dim_grey or d < 0.6 and violet or silver
                        line(0, 0, 0, 128, colour)
                        line(127, 1, 127, 128, colour)
                  end, 1)
               end

               current_item = item
               deli(item_set, idx)
               sfx(12)
               info_flash(item[4])
            end
         end
      end

      if jumping or falling then
         apply_gravity()
      end

      if(y >= 118) then
         local offset  = time_limit - running_time
         local void_x1 = 64 - offset
         local void_x2 = 64 + offset

         if((x + 8) > void_x1 and x < void_x2) then
            falling = true
            dy = 0.1
            apply_gravity()
            dx = (x + 8) < 64 and 2 or -2
            if(lvldone == nil) then
               delay(function() sfx(8) end, 0.3)
               gamestate = state_level_end
               lvldone = t()
               level += 1
            end
         end
      end
   end
end

function wipe_screen(tw)
   local ry1 = tw < 0.5 and 0 or flr((tw - 0.5) * 256)
   local ry2 = tw < 0.5 and flr(tw * 256) or 128
   rectfill(0, ry1, 128, ry2, black)
   rectfill(0, ry1 - 2, 128, ry2 - 2, dim_grey)
   rectfill(0, ry1 - 3 , 128, ry2 - 3, silver)
   rectfill(0, ry1 - 4, 128, ry2 - 4, white)
   rectfill(0, ry1 - 5, 128, ry2 - 5, azure)
   rectfill(0, ry1 - 6, 128, ry2 - 6, white)
   rectfill(0, ry1 - 7, 128, ry2 - 7, silver)
   rectfill(0, ry1 - 8, 128, ry2 - 8, dim_grey)
   rectfill(0, ry1 - 9, 128, ry2 - 9, black)
end

function draw_keys(keys)
   for key in all(keys) do
      local key_x = key[1]
      local key_y = key[2]
      local at = t() * 10 % 10
      local spr_idx = 7
      if(at % 10 < 2) then
         spr_idx = 7
      elseif(at % 10 < 4) then
         spr_idx = 8
      elseif(at % 10 < 6) then
         spr_idx = 7
      elseif(at % 10 < 8) then
         spr_idx = 9
      else
         spr_idx = 7
      end
      spr(spr_idx, key_x, key_y)
      -- rect(key_x,key_y,key_x+8,key_y+8,7)
   end
end

function draw_timer_at(timer_x, timer_y)
   local at = t() * 10 % 10
   local offset = 1
   if(at % 10 < 2) then
      offset = 0
   elseif(at % 10 < 4) then
      offset = -1
   elseif(at % 10 < 6) then
      offset = 0
   elseif(at % 10 < 8) then
      offset = 1
   else
      offset = 0
   end
   spr(14, timer_x, timer_y + offset)
end

function draw_void(running_time)
   -- Draw the void layer.
   local outer_colour
   local inner_colour
   local time_left = time_limit - running_time
   if gamestate == state_menu or time_left > 10 then
      outer_colour = white
      inner_colour = silver
   elseif time_left > 8 then
      outer_colour = silver
      inner_colour = yellow
   elseif time_left > 5 then
      outer_colour = yellow
      inner_colour = salmon
   elseif time_left > 2 then
      outer_colour = salmon
      inner_colour = red
   elseif time_left > 0 then
      outer_colour = black
      inner_colour = red
   else
      outer_colour = black
      inner_colour = black
   end

   line(0, 126, 128, 126,  outer_colour)
   line(0, 127, 128, 127,  outer_colour)
   line(28, 126, 100, 126, inner_colour)
   line(32, 127, 96, 127,  inner_colour)

   local offset  = time_limit - running_time
   local void_x1 = 64 - offset -- 32 + flr(running_time) + offset
   local void_x2 = 64 + offset

   -- The void has ended
   if(void_x1 >= 64) return

   if(void_x1 <= 64) then
      line(void_x1 - 4, 126, void_x2 + 4, 126, 5)
      line(void_x1, 126, void_x2, 126, 0)
   end
   if(void_x1 <= 60) then
      line(void_x1, 127, void_x2, 127, 5)
      line(void_x1 + 4, 127, void_x2 - 4, 127, 0)
   end
end

function _draw()
   if(gamestate == state_menu) then
      draw_menu()
   else
      draw_game()
   end
end

function draw_menu()
   cls(1)
   map(0, 16)
   -- rect(32, 32, 96, 96, 12)
   draw_keys({{64, 56}})
   draw_timer_at(104, 56)
   local at = flr(t() % 1 * 100)
   local facing = direction == 1 and facing_right_spr or facing_left_spr
   if(at < 25 or (at > 50 and at < 75)) then
      spr(facing + 20, 8, 56)
   else
      spr(facing, 8, 56)
   end
   if(dget(0) > 0) then
      print('high score: level ' .. dget(0), 20, 80, 7)
   end
   print("press ❎ to start game", 20, 40, 7)
   print("to move use ⬅️➡️", 20, 100, 7)
   print("and press ❎ to jump", 20, 110, 7)
   draw_void(0)
end

function draw_game()
   cls(1)
   map(1)

   for iy=1,7 do
      local liney = iy * 16
      local locked = key_set[iy] != nil and #key_set[iy] or 0
      if(iy == sticky_floor) then
         line(0, liney, 128, liney, 3)
      elseif (iy == bouncy_floor) then
         line(0, liney, 128, liney, 12)
      end
      for idx, gap in pairs(gap_set[iy]) do
         -- An indication that the floor is locked.
         if(locked > 0) then
            -- Show "locked" status of gaps.
            if(idx <= locked) then
               spr(gap[3] + 40, gap[1], liney)
            else
               spr(gap[3] + 56, gap[1], liney)
            end
            line(gap[1] + 1, liney, gap[2] - 1, liney, 13)
         else
            spr(gap[3], gap[1], liney)
         end
      end

      for launcher in all(launcher_set[iy]) do
         spr(12, launcher[1], launcher[2])
      end
      for bouncer in all(bouncer_set[iy]) do
         spr(13, bouncer[1], bouncer[2])
      end
   end

   local running_time = t() - begin
   draw_void(running_time - extra_time) 

   for iy in all({floor, floor + 1}) do
      local keys = key_set[iy] or {}
      if iy == floor and (not falling or bouncy_floor == floor) then
         draw_keys(keys)
      else
         for key in all(keys) do
            rectfill(key[1], key[2], key[1] + 2, key[2] + 2, 10)
            pset(key[1] + 2, key[2] + 2, 9)
         end
      end
   end

   if(#timer_at > 0) then
      draw_timer_at(timer_at[1], timer_at[2])
   end

   for item in all(item_set) do
      spr(item[3], item[1], item[2])
   end

   if not has_warp() then
      line(0, 0, 0, 128, 7)
      line(127, 1, 127, 128, 7)
   end

   if gamestate != state_no_void and #current_item > 0 then
      spr(current_item[3], 118, 0)
   end

   if jumping and sticky_floor == floor and floors_dropped == 0 and (y+8) < floor * 16 then
      line(jumped_from,     floor * 16, x,     y + 8, 11)
      line(jumped_from + 4, floor * 16, x + 4, y + 8, 11)
   end

   local facing = direction == 1 and facing_right_spr or facing_left_spr
   if(gamestate == state_no_void) then
      spr(facing + 7, x, y)
   else
      local at = flr(t() % 1 * 100)
      if(falling) then
         if(at < 25 or (at > 50 and at < 75)) then
            spr(facing + 52, x, y)
         else
            spr(facing, x, y)
         end
      elseif(moving) then
         if(at < 25 or (at > 50 and at < 75)) then
            spr(facing + 20, x, y)
         else
            spr(facing + 36, x, y)
         end
      else
         spr(facing, x, y)
      end
   end

   local msg = ''
   if(gamestate == state_running) then
      if(bonus_level) then
         msg = '★ challenge '
      end
      msg = msg .. 'level ' .. level .. ' ⧗' .. nice_time((time_limit - running_time) + extra_time) .. 's'
   elseif(gamestate == state_no_void) then
      msg = 'void missed'
      if(new_highscore) then
         msg = msg .. ' ★ new hi score ' .. level
      else
         msg = msg .. ', reached lvl ' .. level
      end
      print('press ❎ to retry', 2, 120, 12)
   else
      msg = 'entered void with ' .. nice_time((time_limit - (lvldone - begin)) + extra_time) .. 's left'
      print('press ❎ to proceed', 2, 120, 12)
   end

--   print(msg .. ': '.. lvltime .. 's [' .. x .. " x " .. y .. '] ', 0, 0, 12)
   print(msg, 2, 1, 12)

   run_flashes()
end

delays = {}
function delay(f, n)
   local started = t()
   local co
   co = function()
         if (t() - started) < n then
            return
         end

         f()

         for idx, v in pairs(delays) do
            if v == co then
               deli(delays, idx)
               break
            end
         end
   end
   add(delays, co)
end

flashes = {}
-- Momentary display
function flash(f, n)
   local started = t()
   local on_level = level
   local co
   co = function()
         if (t() - started) < n then
            if((gamestate == state_running or wiping) and level == on_level) f()
            return
         end

         for idx, v in pairs(flashes) do
            if v == co then
               deli(flashes, idx)
               break
            end
         end
   end
   add(flashes, co)
end

function flash_then(f, g, n)
   -- Run flash for specified period
   flash(f, n)
   -- Run delayed function on the subsequent frame (ish)
   delay(g, n + 0.34, 'flash delay')
end

-- Only run in _update because probably don't need to draw with a delay?
function run_delays()
   for co in all(delays) do
      co()
   end
end

-- Only run in _draw because probably only need for rendering?
function run_flashes()
   for co in all(flashes) do
      co()
   end
end

info_flashing = false
function info_flash(msg, flash_length)
   -- Not enough room for flashes on bonus levels ATM
   if(bonus_level) return
   if(flash_length == nil) flash_length = 3
   if not info_flashing then
      info_flashing = true
      flash_then(
         function()
            local colour = ((t() * 10 % 10) < 5) and 11 or 3
            print(msg, 72, 1, colour)
         end,
         function() info_flashing = false end,
         flash_length
      )
   end
end

function nice_time(inms)
   local sec = flr(inms)
   local ms  = flr(inms * 100 % 100)
   if(ms == 0) then
      ms = '00'
   elseif(ms < 10) then
      ms = '0' .. ms
   end
   return sec .. '.' .. ms
end

function copy_table(tbl)
   local ret = {}
   for i,v in pairs(tbl) do
      if(type(v) == 'table') then
         ret[i] = copy_table(v)
      else
         ret[i] = v
      end
   end
   return ret
end

function randn(n)
   return flr(rnd(n)) + 1
end

function every(t, f)
   for v in all(t) do
      if not f(v) then
         return false
      end
   end
   return true
end

function debug(...)
   local res = ''
   for v in all({...}) do
      res = res .. (type(v) == 'table' and arr_to_str(v) or tostr(v))
   end
   printh(res)
end

-- Not supporting non-array tables as not using them.
function arr_to_str(a)
   local res = '{'
   for v in all(a) do
      if(type(v) == 'table') then
         res = res .. arr_to_str(v)
      else
         res = res .. tostr(v)
      end
      res = res .. ", "
   end
   return sub(res, 0, #res - 2) .. "}"
end

function shuffle(a)
   local copy = copy_table(a)
   local res = {}
   for _ = 1, #copy do
      local idx = randn(#copy)
      add(res, copy_table(copy[idx]))
      deli(copy, idx)
   end
   return res
end

__gfx__
000000001aaaaaa101d666d10000000000000000012ddd21013bbb31000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaeeaeea11d161d100aaaa0000aaaa001121d1211131b13100000000000000000aa0000000aaaa0000aaaa0000000000000000000066660000000000
00700700aefaefaa111515110acacaa00aacaca011121211111313110aa00000000000000aaaaaa00aaaaaa00aaaaaa000000000000000000677c76000000000
00077000aaaaaaaa111151110acacaa00aacaca011112111111131110aaa99900aa000000aa090900acacaa00aacaca000000000000000000677c76000000000
00077000aaaaaaaa111111110aaaa9a00a9aaaa011111111111111110aa090900aaa9990000000000aaaaaa00aaaaaa00000000000000000067cc76000000000
00700700a9eaae9a111111110aa99aa00aa99aa01111111111111111000000000aa0a0a0000000000aa99aa00aa99aa00000000000cccc000677776000000000
00000000aaeeeeaa1111111100aaaa0000aaaa00111111111111111100000000000000000000000000aaaa0000aaaa0000cccc0000cccc000066660000000000
000000001aaaaaa1111111110440044004400440111111111111111100000000000000000000000005500550055005500dddddd0000dd0000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000a00c00000000000000000000000000000000000000000000000aaaa0000aaaa0000000000000000000000000000000000000000000000000000000000
ca0000ac0ccc060000000000000000000000000000000000000000000acacaa00aacaca000000000000000000000000000000000000000000000000000000000
ca0000ac0070060008900890000000000000000000000000000000000acacaa00aacaca000000000000000000000000000000000000000000000000000000000
aa0000aa5565565508890889000000000000000000000000000000000aaaa9a00a9aaaa000000000000000000000000000000000000000000000000000000000
9a0000a9006007000aaa0aaa000000000000000000000000000000000aa99aa00aa99aa000000000000000000000000000000000000000000000000000000000
a000000a0060ccc00000000000000000000000000000000000000000044aaa0000aaa44000000000000000000000000000000000000000000000000000000000
0000000000000c000000000000000000000000000000000000000000000004400440000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000077777777777777770000000000000000000000000000000001d666d10000000000000000012ddd21013bbb3100000000
0000000000000000000000000000000056005600560056000000000000aaaa0000aaaa000000000011da6ad10000000000000000112ada21113aba3100000000
000000000000000000000000000000000000000000000000000000000acacaa00aacaca000000000116595610000000000000000116292611163936100000000
000000000000000000000000000000000000000000000000000000000acacaa00aacaca000000000116656610000000000000000116626611166366100000000
000000000000000000000000000000000000000000000000000000000aaaa9a00a9aaaa000000000111111110000000000000000111111111111111100000000
000000000000000000000000000000000000000000000000000000000aa99aa00aa99aa000000000111111110000000000000000111111111111111100000000
0000000000000000000000000000000000000000000000000000000000aaa440044aaa0000000000111111110000000000000000111111111111111100000000
00000000000000000000000000000000000000000000000000000000044000000000044000000000111111110000000000000000111111111111111100000000
000000000000000070d666d0702ddd20703bbb30000000000000000000000000000000000000000001d666d10000000000000000012ddd21013bbb3100000000
000000000000000000d060d00020d0200030b030000000000000000000aaaa0000aaaa000000000011d161d100000000000000001121d1211131b13100000000
000000000000000000050500000202000003030000000000000000000acacaa00aacaca000000000116515610000000000000000116212611163136100000000
000000000000000000005000000020000000300000000000000000000acacaa00aacaca000000000116656610000000000000000116626611166366100000000
000000000000000000000000000000000000000000000000000000000aaaa9a00a9aaaa000000000111111110000000000000000111111111111111100000000
000000000000000000000000000000000000000000000000000000000aa99aa00aa99aa000000000111111110000000000000000111111111111111100000000
0000000000000000000000000000000000000000000000000000000004aaaa4004aaaa4000000000111111110000000000000000111111111111111100000000
00000000000000000000000000000000000000000000000000000000004004000040040000000000111111110000000000000000111111111111111100000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000077700000007770000000000000000000000000000000777777770000000000000000000000000000000000000000000000000000000000000000000000
00000066600000006660000000000000000000000777000006666666666000000000000000000000077700000000000000000000000000000000000000000000
000000ccc0000000ccc00000000000077700000006660000ccccccccccc000000000000000000000066600000000000000000000000000000000000000000000
000000ccc0000000ccc0000000000006660000000ccc0000ccc00000ccc0000000000000000000000ccc00000000000000000000000000000000000000000000
000000ccc0000000ccc000000000000ccc0000000ccc0000ccc000000000000000000000000000000ccc00000000000000000000000000000000000000000000
000000cccc00000cccc0000000000000000000000ccc0000cccc00000000000000000000000000000ccc00777000000000000000000000000000000000000000
000000ccccc000ccccc000777777000ccc000ccccccc00000ccccc000000007777770000777777000ccc06660000777777000777000000000000000000000000
0000000cccc000cccc0006666666600ccc00cccccccc000000cccccc0000066666666006666666600cccccc00006666666600666666600000000000000000000
00000000cccc0cccc0000cccccccc00ccc00cccccccc0000000ccccccc000ccc00ccc00ccc00ccc00ccccc00000ccc00ccc00cccccccc0000000000000000000
000000000ccc0ccc00000ccc00ccc00ccc00ccc00ccc0000000000ccccc00cccccccc00cccccccc00ccccc00000cccccccc00ccc00ccc0000000000000000000
000000000ccccccc00000ccc00ccc00ccc00ccc00ccc0000cc000000ccc00ccccccc000ccccccc000cccccc0000ccccccc000ccc000000000000000000000000
0000000000ccccc000000cccccccc00ccc00cccccccc0000ccc00000ccc00ccc0000000ccc0000000ccc0ccc000ccc0000000ccc000000000000000000000000
0000000000ccccc000000cccccccc00ccc00cccccccc0000ccccccccccc00cccccccc00cccccccc00ccc00ccc00cccccccc00ccc000000000000000000000000
00000000000ccc00000000cccccc000ccc000cccccc000000ccccccccc0000ccccccc000ccccccc00ccc000cc000ccccccc00ccc000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111777111111177711111111111111111111111111111117777777711111111111111111111111111111111111111111111111111111111111111
11111111111111666111111166611111111111111111111117771111166666666661111111111111111111111777111111111111111111111111111111111111
11111111111111ccc1111111ccc11111111111177711111116661111ccccccccccc1111111111111111111111666111111111111111111111111111111111111
11111111111111ccc1111111ccc1111111111116661111111ccc1111ccc11111ccc1111111111111111111111ccc111111111111111111111111111111111111
11111111111111ccc1111111ccc111111111111ccc1111111ccc1111ccc111111111111111111111111111111ccc111111111111111111111111111111111111
11111111111111cccc11111cccc1111111111111111111111ccc1111cccc11111111111111111111111111111ccc117771111111111111111111111111111111
11111111111111ccccc111ccccc111777777111ccc111ccccccc11111ccccc111111117777771111777777111ccc166611117777771117771111111111111111
111111111111111cccc111cccc1116666666611ccc11cccccccc111111cccccc1111166666666116666666611cccccc111166666666116666666111111111111
1111111111111111cccc1cccc1111cccccccc11ccc11cccccccc1111111ccccccc111ccc11ccc11ccc11ccc11ccccc11111ccc11ccc11cccccccc11111111111
11111111111111111ccc1ccc11111ccc11ccc11ccc11ccc11ccc1111111111ccccc11cccccccc11cccccccc11ccccc11111cccccccc11ccc11ccc11111111111
11111111111111111ccccccc11111ccc11ccc11ccc11ccc11ccc1111cc111111ccc11ccccccc111ccccccc111cccccc1111ccccccc111ccc1111111111111111
111111111111111111ccccc111111cccccccc11ccc11cccccccc1111ccc11111ccc11ccc1111111ccc1111111ccc1ccc111ccc1111111ccc1111111111111111
111111111111111111ccccc111111cccccccc11ccc11cccccccc1111ccccccccccc11cccccccc11cccccccc11ccc11ccc11cccccccc11ccc1111111111111111
1111111111111111111ccc11111111cccccc111ccc111cccccc111111ccccccccc1111ccccccc111ccccccc11ccc111cc111ccccccc11ccc1111111111111111
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111777177717771177117711111177777111111777117711111177177717771777177711111177177717771777111111111111111111111
11111111111111111111717171717111711171111111771717711111171171711111711117117171717117111111711171717771711111111111111111111111
11111111111111111111777177117711777177711111777177711111171171711111777117117771771117111111711177717171771111111111111111111111
11111111111111111111711171717111117111711111771717711111171171711111117117117171717117111111717171717171711111111111111111111111
11111111111111111111711171717771771177111111177777111111171177111111771117117171717117111111777171717171777111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111aaaa111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111116666111111111111111111
111111111aacaca11111111111111111111111111111111111111111111111111aa11111111111111111111111111111111111111677c7611111111111111111
111111111aacaca11111111111111111111111111111111111111111111111111aaa9991111111111111111111111111111111111677c7611111111111111111
111111111a9aaaa11111111111111111111111111111111111111111111111111aa1919111111111111111111111111111111111167cc7611111111111111111
111111111aa99aa11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111167777611111111111111111
1111111111aaa4411111111111111111111111111111111111111111111111111111111111111111111111111111111111111111116666111111111111111111
11111111144111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
777777777777777777777777777777777777777771d666d1777777777777777777777777712ddd2177777777777777777777777777777777713bbb3177777777
561156115611561156115611561156115611561111d161d15611561156115611561156111121d121561156115611561156115611561156111131b13156115611
11111111111111111111111111111111111111111115151111111111111111111111111111121211111111111111111111111111111111111113131111111111
11111111111111111111111111111111111111111111511111111111111111111111111111112111111111111111111111111111111111111111311111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111777117711111777117717171777111117171177177711111177777111777771111111111111111111111111111111111111111111111
11111111111111111111171171711111777171717171711111117171711171111111777117717711777111111111111111111111111111111111111111111111
11111111111111111111171171711111717171717171771111117171777177111111771117717711177111111111111111111111111111111111111111111111
11111111111111111111171171711111717171717771711111117171117171111111777117717711777111111111111111111111111111111111111111111111
11111111111111111111171177111111717177111711777111111771771177711111177777111777771111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111777177117711111177717771777117711771111117777711111177711771111177717171777177711111111111111111111111111111
11111111111111111111717171717171111171717171711171117111111177171771111117117171111117117171777171711111111111111111111111111111
11111111111111111111777171717171111177717711771177717771111177717771111117117171111117117171717177711111111111111111111111111111
11111111111111111111717171717171111171117171711111711171111177171771111117117171111117117171717171111111111111111111111111111111
11111111111111111111717171717771111171117171777177117711111117777711111117117711111177111771717171111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
77777777777777777777777777555500000000000000000000000000000000000000000000000000000000000000000000055557777777777777777777777777
77777777777777777777777777777755550000000000000000000000000000000000000000000000000000000000000555577777777777777777777777777777

__gff__
0000010000020400000000000000000000010000000000000000000000000000010204000808000000000100000204000000010204000000000001000002040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2626260023262626260023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2626262626262626262626000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252525252525252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000016161616160000000000000035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2424242424242424242424242525252525252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524242425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000003500000000000000000035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00404142434445464748494a4b4c4d4d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00505152535455565758595a5b5c5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f606162636465666768696a6b6c6d6d6f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0080817183848586870000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0090919293949596970000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a0a1a2a3a4a5a6a70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2424242424322424243324242424342400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010400000f7111172114721150211c0211f02121021220201e7200e7100d7100a7100571002715140000100013000190001900019000190003a00024000001000010000000000010000000000000000000000000
090400001a5441a54019540175401555013550105400c540085400054507500025000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050000225502255022540205401f5301e5301b520145200c5200955005500005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c0000125701156011560115501055010540105400f5400f5400e5400d5400d5300c5300c5400a5400953007520045100050006300085000750006500055000450004500035000250000500005000000000000
4905000024114201201e1301e130201212412028130281352b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0106000012600126001460014600126211262314633146330e6210e62305613056130e6000e600056000560000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000013554135521355210541105441054113552135520d5540d5510c5410c5450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0114000018710187511d7520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a000013134151311513113142131421314210131101300a10009101091010b1010e1011210112101121050d4000d4000d40000000000000000000000000000000000000000000000000000000000000000000
010800001c0371c0411f0411f050180551d0051f00021003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000140d0500d0500d050000000705007050070500c0500c0500c05000000070500805003050040000c0500c0500c0500000000000000000000000000000000000000000000000000000000000000000000000
001000140000000000000000022000220102301223013220000000000000000000000000009230092400a23007220022100020002200022000220000000000000000000000000000000000000000000000000000
1109000018754187511c7501c7511f750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
090800001f52421521235250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0108000023524215211f5250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
090600001f7441f740217402173300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600002174421740247402473300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040000125701156011560115501055010540105400f5400f5400e5400d5400d5300c5300c5400a5400953007520045100000000000000000000000000000000000000000000000000000000000000000000000
0b0600000455407551025410254104551055530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55060000260341e03621050220502305523053290002a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09060000220531f046210402204023034000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
490400001c1341c1311f1311f13121141211450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0a0b4344

