pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- keeping it short

#include utils.lua

function make_obj(attr)
   return merge({
      x = nil, y = nil,
      from = nil, to = nil,
      frames = nil,
      animating = false,
      }, attr)
end

function wait(n)
   for _ = 1,n do yield() end
end

function delay(f, n)
   animate(function() wait(n) f() end)
end

function animate(f)
   animate_obj({}, f)
end

function animate_obj(obj, animation)
   obj.co = cocreate(function()
         obj.animating = true
         animation(obj)
         obj.animating = false
         if(obj.cb) obj.cb(obj)
   end)
   coresume(obj.co)
   add(anims, obj)
end

function easein(t)
   return t*t
end
function easeoutquad(t)
  t-=1
  return 1-t*t
end
function lerp(a,b,t)
   return a+(b-a)*t
end

function animate_move(obj)
   for f = 1, obj.frames do
      if(obj.crashed or obj.collected) return
      obj.y = lerp(obj.from, obj.to, easein(f/obj.frames))
      yield()
   end
end

g_fuel_max = 55.5

game_state_menu       = 'menu'
game_state_gaming     = 'gaming'
game_state_splaining  = 'exposition'
game_state_level_done = 'lvldone'
game_state_level_fail = 'lvlfail'
game_state_complete   = 'complete'

function in_state(...)
   for v in all({...}) do
      if v == current_state then
         return true
      end
   end
   return false
end

function set_state(s)
   last_transition = frame_count
   current_state = s
end

function start_escape()
   current_state = game_state_menu

   cam_x = 0
   cam_speed = 1

   player_x = 16
   player_y = 64
   player_speed_vert  = 0
   player_speed_horiz = 0

   player_fuel = g_fuel_max
   player_crashing = false

   frame_count = 0
   last_transition = 0

   started_at = 0
   finished_at = 0

   set_collided()

   ring_streak     = 0
   collected_rings = 0
   collected_seeds = 0
   collected_forms = {}
   collecting_form = false

   claw = make_obj({length=0,anim_at=18,extending=false,extended=false})
end

o_stalactite = 'stalactite'
o_seed       = 'seed'
o_fuel_ring  = 'fuel_ring'
o_form       = 'platonic_form'

all_forms = {
   {
      { name = 'square',   spr = {2,  18, 11, 11}, icon_spr = 64 },
      { name = 'circle',   spr = {17, 17, 14, 14}, icon_spr = 65 },
      { name = 'triangle', spr = {34, 18, 11, 11}, icon_spr = 66 },
      { name = 'diamond',  spr = {49, 17, 14, 14}, icon_spr = 67 },
   },
   {
      { name = 'red',    spr = {65,  17, 14, 14}, icon_spr = 68 },
      { name = 'blue',   spr = {81,  17, 14, 14}, icon_spr = 69 },
      { name = 'green',  spr = {97,  17, 14, 14}, icon_spr = 70 },
      { name = 'yellow', spr = {113, 17, 14, 14}, icon_spr = 71 },
   },
   {
      { name = 'one',   spr = {34, 50, 11, 11}, icon_spr = 72 },
      { name = 'two',   spr = {48, 50, 17, 11}, icon_spr = 73 },
      { name = 'three', spr = {64, 48, 17, 17}, icon_spr = 74 },
      { name = 'four',  spr = {80, 48, 17, 17}, icon_spr = 75 },
   },
}

function generate_terrain()
   terrain={up={},down={}}
   objects={}

   local lvl={up={},down={}}

   local towards={
      {{16,32}, {120, 96}},
      {{32,48}, {96, 120}},
      {{48,16}, {120, 64}},
      {{16,32}, {64,  96}},
      {{32,24}, {96, 108}},
   }

   local section_length = 64
   -- Generate slopes
   for l = 1,5 do
      local seclen = l == 5 and 32 or section_length

      local up_from = towards[l][1][1]
      local up_to   = towards[l][1][2]
      local up_step = -((up_from-up_to)/seclen)
      local up_rand = randx(2) > 1 and randx(15) or -randx(15)

      local down_from = towards[l][2][1]
      local down_to   = towards[l][2][2]
      local down_step = -(down_from-down_to)/seclen
      local down_rand = randx(2) > 1 and randx(15) or -randx(15)

      local up_offset = up_step
      local down_offset = down_step
      for _ = 1,seclen do
         local up = (up_from + up_offset) + randx(10) + up_rand
         up_offset += up_step
         add(lvl.up, up)

         local down = min(127, (down_from + down_offset) + -randx(15) + down_rand)
         if (down-up) < 15 then
            local wasd=down
            down = up + 20
            -- dump('rounded down from ', wasd, ' to ', down, ', up is ', up)
         end

         down_offset += down_step
         add(lvl.down, down)
      end
   end

   local function calc_terrain_step(terr, from, to, x, tc)
      local step = -(from-to) / 8
      local y    = from
      for j = 1,8 do
         local tex_col = ({azure,lime,red,yellow})[randx(4)]
         local texture = make_obj({c=tex_col,offset=randx(20),colours={}})
         add(terr, {
                x=x, y=y, colour=tc,
                from=from, to=to,
                texture=(randx(20)<2 and texture)
         })
         x+=2
         y+=step
      end
   end

   local lvl_forms = shuffle(forms)
   local colours = {{black,dim_grey},{dim_grey,magenta},{magenta,violet},{violet,silver}}
   -- Calculate terrain
   local x = 0
   local n = #lvl.up / 4
   for i = 1, #lvl.up - 2, 2 do
      local tc_down = colours[i < n and 1 or i < (n*2) and 2 or i < (n*3) and 3 or 4]

      local from, to = lvl.down[i], lvl.down[i+1]
      local tc = from > to and tc_down[1] or tc_down[2]

      calc_terrain_step(terrain.up,   lvl.up[i], lvl.up[i+1], x)
      calc_terrain_step(terrain.down, from,      to,          x, tc)

      x += 16
      i += 1

      from, to = lvl.down[i], lvl.down[i+1]
      tc = from > to and tc_down[1] or tc_down[2]

      calc_terrain_step(terrain.up,   lvl.up[i],   lvl.up[i+1],   x)
      calc_terrain_step(terrain.down, lvl.down[i], lvl.down[i+1], x, tc)

      x += 16

      local up_y   = terrain.up[#terrain.up].y
      local down_y = terrain.down[#terrain.down].y
      local gap    = down_y - up_y
      -- Don't consider the gap as it will always be in the middle
      if x % 1024 == 0 and #lvl_forms > 0 then
         local form_spr = lvl_forms[1]
         del(lvl_forms, form_spr)
         local form = make_obj(merge(copy_table(form_spr), {
            type=o_form,
            y=up_y+flr(gap/2),
            x=x,
            collected=false
         }))
         add(objects, form)
      else
         if gap > 20 and i < (section_length * 4) then
            if x % 128 == 0 and randx(3) > 1 then
               local oy  = up_y - 6
               local stalactite = make_obj({
                     type=o_stalactite,
                     y=oy, x=x,
                     from=oy, to=down_y,
                     frames=40,
                     alive=true,
                     crashed=false,
                     cb=function(o)
                        if(on_screen(o.x) and not o.crashed) sfx(8)
                        o.alive=false
                        end
               })
               local seed = make_obj({
                     type=o_seed,
                     y=down_y, x=x,
                     from=down_y-6, to=up_y+flr(gap/4),
                     frames=45,
                     alive=true,
                     apogee=false,
                     collected=false,
                     cur_spr=27,
               })
               add(objects, randx(2) > 1 and stalactite or seed)
            elseif x % 144 == 0 then -- and randx(5) > 3 then
               local ring = make_obj({
                     type=o_fuel_ring,
                     y=up_y+randx(gap-g_td),
                     x=x,
                     anim_at=1,
                     fuel_used=false,
                     crashed=false,
                     alive=true
               })
               add(objects, ring)
            end
         end
      end
   end
end

function init_globals()
   anims={}
   exit_stars={}
   for i = 1,16 do
      add(exit_stars, make_obj({x=randx(128), y=randx(128), idx=i,colour=black,trail={}}))
   end
   bobbing = make_obj({})
   form_show = make_obj({forms={}})
   forms = all_forms[randx(#all_forms)]
end

function _init()
   camera()
   init_globals()
   start_escape()
   generate_terrain()
end

function run_animations()
   for obj in all(anims) do
      if costatus(obj.co) != 'dead' then
         coresume(obj.co)
      else
         del(anims, obj)
      end
   end
end

g_max_speed = 6
g_min_speed = 1

g_friction = 0.9
g_accel_fwd  = 0.2
g_accel_back = 0.4
g_accel_vert = 0.3

-- td = terrain_depth
g_td = 10

function did_collide(terr, x, y, test)
   local px0 = x + cam_x
   local px1 = px0 + 8
   local py0 = y
   local py1 = py0 + 8

   for idx, pos in pairs(terr) do
      if on_screen(pos.x) and test(pos, px0, px1, py0, py1) then
         -- dump_once('collided at\n', terrain.up[idx], '\n', terrain.down[idx])
         return true
      end
   end

   return false
end

function did_collide_up(x, y)
   local function coll_test(pos, px0, px1, py0, py1)
      local pos_top = max(1, pos.y - 2)
      return ((px0 >= pos.x and px0 <= (pos.x+2))
           or (px1 >= pos.x and px1 <= (pos.x+2)))
         and py0 < pos_top
   end

   return did_collide(terrain.up, x, y, coll_test)
end

function did_collide_down(x, y)
   local function coll_test(pos, px0, px1, py0, py1)
      return ((px0 >= pos.x and px0 <= (pos.x+2))
           or (px1 >= pos.x and px1 <= (pos.x+2)))
         and py1 > (pos.y+g_td)
   end

   return did_collide(terrain.down, x, y, coll_test)
end

function consume_fuel(n)
   if(current_state == game_state_level_done) return
   local next_f = player_fuel - n
   player_fuel = next_f >= 0 and next_f or 0
end

function check_objects(x, y)
   local px0 = x + cam_x + 1
   local px1 = px0 + 6
   local py0 = y + 1
   local py1 = py0 + 6

   for obj in all(objects) do
      if on_screen(obj.x) then
         if obj.type == o_stalactite and obj.alive and not obj.crashed then
            local sx0 = obj.x
            local sx1 = sx0 + 8
            local sy0 = obj.y
            local sy1 = sy0 + 8
            if  ((px0 > sx0 and px0 < sx1) or (px1 > sx0 and px1 < sx1))
            and ((py0 > sy0 and py0 < sy1) or (py1 > sy0 and py1 < sy1)) then
               consume_fuel(7)
               obj.crashed = true
               ring_streak = 0
               sfx(7)
               animate(function()
                     local orig_x = obj.x
                     local orig_s = cam_speed
                     for f=1,49 do
                        if f % 10 == 0 then
                           obj.x = obj.x > 0 and -1 or orig_x
                        end
                        yield()
                     end
                     obj.x = -1
               end)
               return g_min_speed
            end
         elseif obj.type == o_seed and not obj.collected and not obj.crashed then
            if claw.extended then
               local cx1 = px1+8+claw.length
               local cy0 = py0+4
               local cy1 = cy0+4
               if  (cx1 >= obj.x and cx1 < obj.x+8)
               and (cy0 >= obj.y and cy1 <= (obj.y+8)) then
                  obj.collected = true
                  obj.cur_spr = 31
                  sfx(11)
                  collected_seeds += 1
                  animate(function()
                        while claw.extending do
                           obj.x = flr(player_x + cam_x) + 11 + claw.length
                           yield()
                        end
                        obj.x = -1
                  end)
                  return
               end
            end
            local sx0 = obj.x
            local sx1 = sx0 + 8
            local sy0 = obj.y
            local sy1 = sy0 + 8
            if  ((px0 > sx0 and px0 < sx1) or (px1 > sx0 and px1 < sx1))
            and ((py0 > sy0 and py0 < sy1) or (py1 > sy0 and py1 < sy1)) then
               consume_fuel(4)
               obj.crashed = true
               ring_streak = 0
               if(not obj.apogee) sfx(12)
               animate(function()
                     local orig_x = obj.x
                     local orig_s = cam_speed
                     for f=1,49 do
                        if f % 10 == 0 then
                           obj.x = obj.x > 0 and -1 or orig_x
                        end
                        yield()
                     end
                     obj.x = -1
               end)
               return g_min_speed
            end
         elseif obj.type == o_fuel_ring and not obj.fuel_used and not obj.crashed then
            if px1 > (obj.x+4) then
               local ry0 = obj.y
               local ry1 = ry0 + 14
               if py0 > ry0 and py1 < ry1 then
                  player_fuel = min(g_fuel_max, player_fuel + 4)
                  obj.fuel_used = frame_count
                  delay(function() obj.x = -1 end, 45)
                  sfx(ring_streak)
                  ring_streak = min(3, ring_streak+1)
                  collected_rings += 1
                  return cam_speed * 1.5
               elseif (py0 < ry0 and py1 > ry0) or (py0 < ry1 and py1 > ry1) then
                  obj.crashed = true
                  consume_fuel(2)
                  animate_obj(obj, animate_ring_crash)
                  ring_streak = 0
                  sfx(5)
               end
            end
         elseif obj.type == o_form and not obj.collected and claw.extended then
            local cx1 = px1+8+claw.length
            local cy0 = py0+4
            local cy1 = cy0+4
            if  (cx1 >= obj.x and cx1 < obj.x+8)
            and (cy0 >= obj.y and cy1 <= (obj.y+obj.spr[4]+4)) then
               obj.collected = true
               sfx(4)
               collecting_form = obj
               player_speed_vert  = 0
               animate(function()
                     obj.dw = obj.spr[3]
                     obj.dh = obj.spr[4]
                     while claw.extending do
                        obj.x = flr(player_x + cam_x) + 11 + claw.length
                        obj.dw = max(0, obj.dw - 0.25)
                        obj.dh = max(0, obj.dw - 0.25)
                        obj.y += 0.15
                        yield()
                     end
                     obj.x = -1
                     collecting_form = false
                     player_fuel = min(g_fuel_max, player_fuel + 15)
                     add(collected_forms, obj)
               end)
               return g_min_speed
            end
         end
      end
   end
end

function extend_claw()
   local function anim()
      for f=1,10 do
         if f % 2 == 0 then
            claw.length += 0.5
            claw.anim_at = min(15, claw.anim_at+1)
         end
         yield()
      end

      claw.extended=true
      -- Have it extend for at least 0.3s
      wait(10)
      local fc = frame_count
      while btn(b_x) and (frame_count - fc) < 70 and not collecting_form do yield() end
      claw.extended=false

      if(not collecting_form) sfx(10)
      for f=1,15 do
         if f % 3 == 0 then
            claw.length -= 0.5
            claw.anim_at = max(11, claw.anim_at-1)
         end
         yield()
      end

      claw.extending = false
   end

   sfx(9)
   claw.extending=true
   animate(anim)
end

function animate_seed(obj)
   local function launch()
      obj.cur_spr+=1
      wait(7)
      obj.cur_spr+=1
      wait(4)
      obj.cur_spr+=1
      wait(2)
      animate_move(obj)
      obj.apogee = true
      if not obj.collected and on_screen(obj.x) then
         sfx(12)
         obj.circ_colour = white
         obj.circ_size = 2
         wait(1)

         obj.circ_size = 3
         wait(2)

         obj.circ_colour = azure
         obj.circ_size = 4

         wait(3)
         obj.circ_size = 5

         wait(3)
         obj.circ_colour = violet
         obj.circ_size = 6
         wait(2)
         obj.circ_size = 7
         wait(3)
         obj.circ_colour = magenta
         obj.circ_size = 8
         wait(10)
         obj.x = -1
         obj.alive = false
      end
   end
   if not obj.animating and not obj.apogee then
      animate_obj(obj, launch)
   end
end

function set_collided(c)
   if c != nil then
      collided = merge(collided, c)
      collided.t = true
   else
      collided = { up = false, down = false, t = false }
   end
end

function crash_judder()
   if(player_crashing) return

   consume_fuel(4)
   ring_streak = 0
   player_crashing = true
   player_speed_horiz = 0
   player_speed_vert = 0
   cam_speed = g_min_speed
   sfx(6)

   animate(function()
      local offset = (collided.up and 1 or -1) * 0.25
      local judder = -1
      for i = 1, 25 do
         player_y += offset
         if i % 5 == 0 then
            player_x += judder
            judder = -judder
         end
         yield()
      end
      set_collided()
      player_crashing = false
   end)
   end

function update_level()
   if current_state != game_state_level_done and player_fuel == 0 and (player_crashing or collided.t) then
      set_state(game_state_level_fail)
      return
   end

   if current_state != game_state_level_done and btnp(b_x) and not claw.extending and not player_crashing then
      extend_claw()
   end

   if current_state != game_state_level_done and (cam_x+player_x) > terrain.up[#terrain.up].x then
      set_state(game_state_level_done)
      finished_at = t()
   end

   local next_x = player_x
   local next_y = player_y
   local next_s = cam_speed

   if not collecting_form and not player_crashing then
      if player_fuel > 0 then
         if btn(b_right) then
            player_speed_horiz = min(g_max_speed, player_speed_horiz == 0 and 1 or player_speed_horiz + g_accel_fwd)
            next_s = min(g_max_speed, max(0.2, cam_speed) * 1.1)
         elseif btn(b_left) then
            player_speed_horiz = max(-2.5, player_speed_horiz == 0 and -1 or player_speed_horiz - g_accel_back)
            next_s = max(g_min_speed, cam_speed * 0.95)
            if flr(cam_speed) > g_min_speed then
               consume_fuel(max(0.05, cam_speed * 0.1))
            end
         else
            player_speed_horiz *= g_friction
         end
      end

      if btn(b_up) then
         player_speed_vert = player_speed_vert == 0 and -1 or (player_speed_vert - g_accel_vert)
      elseif btn(b_down) then
         player_speed_vert = player_speed_vert == 0 and 1 or (player_speed_vert + g_accel_vert)
      else
         player_speed_vert = abs(player_speed_vert) > 0.5 and player_speed_vert * g_friction or 0
      end
   end

   next_y = player_speed_vert > 0 and flr(player_speed_vert + next_y) or -flr(-player_speed_vert) + next_y

   if did_collide_up(next_x, next_y) then
      set_collided({ up = true })
      crash_judder()
   elseif did_collide_down(next_x, next_y) then
      set_collided({ down = true })
      crash_judder()
   else
      local new_s = check_objects(next_x, next_y)
      if(new_s) next_s = min(g_max_speed, new_s)
      set_collided()
   end

   if (not collided.up and next_y < player_y)
   or (not collided.down and next_y > player_y) then
      player_y = flr(next_y)
   end

   if not collided.t then
      next_x += player_speed_horiz
      if next_x > 16 and next_x < 64 then
         player_x = flr(next_x)
      end

      cam_speed = next_s

      cam_x += flr(cam_speed)

      camera(flr(cam_x))

      if frame_count % 30 == 0 then
         consume_fuel(max(1, cam_speed * 0.5))
      end
   end

   for obj in all(objects) do
      if not obj.animating and obj.alive and on_screen(obj.x) then
         if obj.type == o_stalactite and not obj.crashed and obj.x - (cam_x+player_x) < 60 then
            animate_obj(obj, animate_move)
         elseif obj.type == o_seed and not obj.apogee and obj.x - (cam_x+player_x) < 80 then
            animate_seed(obj)
         elseif obj.type == o_fuel_ring and not(obj.fuel_used or obj.crashed) then
            animate_obj(obj, function(r) animate_ring(r) end)
         end
      end
   end
end

ring_sprites = {
   {40, 1, 9, 14},
   {49, 1, 9, 14},
   {58, 1, 9, 14},
   {67, 1, 9, 14},
}

function animate_ring(r)
   while on_screen(r.x) do
      for frame = 1,28 do
         if(r.crashed or r.fuel_used) return
         r.anim_at = -flr(-(frame/7))
         yield()
      end
   end
end

function animate_ring_crash(r)
   r.crashed = 1
   for f=1,119 do
      if f % 30 == 0 then
         r.crashed += 1
      end
      yield()
   end
   wait(60)
   -- Move it off screen
   r.x = -1
end

function bob_ship()
   local orig_y = player_y
   local offset = 5
   local from = player_y
   local to   = player_y + offset
   local frames = 75
   while current_state == game_state_menu do
      for f = 1, frames do
         if(current_state != game_state_menu) return
         player_y = lerp(from, to, easeoutquad(f/frames))
         yield()
      end
      from, to = to, to + (to == orig_y and offset or -offset)
      wait(10)
   end
end

function _update()
   frame_count += 1

   run_animations()

   if current_state == game_state_menu then
      if btnp(b_x) then
         set_state(game_state_splaining)
         -- sfx?
      end
      if not bobbing.animating then
         animate_obj(bobbing, bob_ship)
      end
   elseif current_state == game_state_splaining then
      if btnp(b_x) and (frame_count - last_transition) > 15 then
         set_state(game_state_gaming)
         started_at = t()
      end
   elseif current_state == game_state_level_fail then
      if btnp(b_x) and (frame_count - last_transition) > 15 then
         _init()
         current_state = game_state_gaming
         -- sfx?
      end
   else
      if current_state == game_state_level_done then
         if btnp(b_x) and frame_count - last_transition > 60 then
            _init()
            return
            -- sfx?
         end
      end
      update_level()
   end
end

function on_screen(x)
   local pcx = x - cam_x
   return pcx > -10 and pcx < 132
end

function draw_terrain(terr, do_draw)
   local px0 = player_x + cam_x
   local px1 = px0 + 8
   local py0 = player_y
   local py1 = py0 + 8

   for pos in all(terr) do
      if on_screen(pos.x) then
         do_draw(pos)
      end
   end
end

function draw_terrain_texture(x, y, t)
   local c = t.c
   pset(x,   y,   t.wink or 'white')
   pset(x-1, y,   c)
   pset(x+1, y,   c)
   pset(x,   y-1, c)
   pset(x,   y+1, c)
   if not t.animating then
      t.animating = true
      delay(function()
            if(#t.colours == 0) t.colours = {white,silver,dim_grey,silver,white}
            local idx = randx(#t.colours)
            t.wink = t.colours[idx]
            deli(t.colours, idx);
            t.animating = false
      end, randx(15)+10)
   end
end

function draw_ring_half(ring, side)
   -- One side of the ring
   local rs = copy_table(ring_sprites[ring.anim_at])

   if side == 'back' then
      rs[3] = flr(rs[3] / 2)
      add(rs, ring.x)
   elseif side == 'front' then
      rs[1] = rs[1] + flr(rs[3] / 2)
      rs[3] = -flr(-(rs[3] / 2))
      add(rs, ring.x+4)
      if(ring.crashed) rs[#rs] += ring.crashed
   end

   if ring.fuel_used then
      if frame_count - ring.fuel_used < 30 then
         pal(orange, brown)
         pal(yellow, orange)
      else
         pal(orange, magenta)
         pal(yellow, brown)
      end
   end

   add(rs, ring.y)
   sspr(unpack(rs))

   pal()
end

function draw_form_warning()
   local rhs = flr(screen_width + cam_x)

   for obj in all(objects) do
      if obj.type == o_form and obj.x > rhs and (obj.x - rhs) < 220 then
         if frame_count % 30 > 15 then
            line(cam_x+127, obj.y - 4, cam_x+127, obj.y + 16, yellow)
            line(cam_x+126, obj.y - 4, cam_x+126, obj.y + 16, orange)
         end
      end
   end
end

function animate_form_show(fs)
   while current_state == game_state_menu do
      for af in all(all_forms) do
         local offset = 0
         fs.forms = {}
         local fx = 128
         for i, f in pairs(af) do
            add(fs.forms, make_obj(merge(copy_table(f), {
                                             y=42,
                                             x=fx+offset,
                                             collected=false
            })))
            offset += 19
         end
         while fx > -80 do
            if(current_state != game_state_menu) return
            for f in all(fs.forms) do
               f.x -= 1
            end
            fx -= 1

            yield()
         end
      end
   end
end

function draw_form(obj)
   local s = copy_table(obj.spr)
   add(s, obj.x)
   add(s, obj.y)
   add(s, obj.dw or s[3])
   add(s, obj.dh or s[4])
   sspr(unpack(s))
end

function draw_menu()
   sspr(2, 97, 81, 15, 20, 2)

   print('press ❎ to begin', 32, 80, white)

   print('the forms', 32, 32, white)
   if not form_show.animating then
      animate_obj(form_show, animate_form_show)
   else
      for f in all(form_show.forms) do
         draw_form(f)
      end
   end
end

dazzling = {
   on = false,
   colour = white
}
function anim_dazzle(d)
   local c = {white,yellow,orange}
   while current_state != game_state_menu do
      local rem = frame_count % 30
      d.colour = rem < 10 and white or rem < 20 and yellow or orange
      yield()
   end
   d.on = false
end

function draw_exposition()
   -- Probably unnecessary.
   rectfill(0, 0, 128, 96, navy)

   local msg = [[
you are deep within plato's
allegorical cave where the
forms have been found - it's
your mission to retrieve them
and establish
]]
    print(msg, 8, 8, white)
    print('kallipolis!', 64, 32, dazzling.colour)

    if not dazzling.on then
       animate_obj(dazzling, anim_dazzle)
       dazzling.on = true
    end

    msg = [[
grab the forms with your claw
by pressing ❎ when they are
in reach.

pass through fuel rings to
top up your rapidly depleting
fuel and avoid the dangers of
the cave.

press ❎ to start
]]

   print(msg, 8, 46, white)
end

function draw_fail()
   rectfill(cam_x+6, 14, cam_x+112, 38, black)
   print("cave over", cam_x+8, 16, white)
   print("kallipolis isn't to be ...", cam_x+8, 22, white)
   if (frame_count - last_transition) > 30 then
      print('press ❎ to retry', cam_x+8, 32, white)
   end
end

function animate_star_twinkle(star)
   wait(star.idx*10)
   local start_frame = frame_count
   while current_state != game_state_menu do
      local rem = frame_count - start_frame
      star.colour = rem < 30 and black or rem < 45 and navy or rem < 70 and dim_grey or rem < 85 and silver or white
      if rem > 100 then
         star.colour = rem % 100 < 50 and yellow or white
      end
      yield()
   end
end

win_states = {
   [0] = {'tyranny',     red},
   [1] = {'democracy',   salmon},
   [2] = {'oligarchy',   coral},
   [3] = {'timocracy',   orange},
   [4] = {'aristocracy', yellow},
}

function draw_exit()
   local exit_x = terrain.up[#terrain.up].x
   rectfill(exit_x+5, 0, cam_x+128, 128, black)

   local up_y   = terrain.up[#terrain.up].y
   local down_y = terrain.down[#terrain.down].y
   for i = 0,48 do
      line(exit_x+5, up_y,   exit_x+i, 0,   i > 36 and violet or navy)
      line(exit_x+5, down_y, exit_x+i, 127, i > 36 and violet or navy)
   end

   for idx,star in pairs(exit_stars) do
      local sx = cam_x+star.x
      if sx > (exit_x+128) then
         if star.animating then
            pset(star.x + cam_x, star.y, star.colour)
         else
            animate_obj(star, animate_star_twinkle)
         end
      end
   end

   local msg_x = max(exit_x + 64, cam_x + 8)
   rectfill(msg_x-4, 32, msg_x+64, 96, black)
   local msg = [[
congratulations! you made it
out of the allegorical cave!

]]
    print(msg, msg_x, 32, white)
    print('kallipolis', msg_x, 48, dazzling.colour)
    print('can be established', msg_x+43, 48, white)
    local cf = #collected_forms
    local ws = win_states[cf]
    local indefinite = (cf == 4 or cf == 2) and 'an' or 'a'
    local offset     = (cf == 4 or cf == 2) and 24   or 20
    print('as '..indefinite, msg_x, 56, white)
    print(ws[1]..'.', msg_x+offset, 56, ws[2])

    if not dazzling.on then
       animate_obj(dazzling, anim_dazzle)
       dazzling.on = true
    end

    local rt = nice_pos(finished_at - started_at)
    print('escaped in '..rt..'s', msg_x, 96, white)
    rt = count(objects, function(o) return o.type == o_fuel_ring end)
    print(
       dumper('fuel rings flown through ', collected_rings, '/', rt), msg_x, 102
    )
    if collected_seeds > 0 then
       rt = count(objects, function(o) return o.type == o_fuel_ring end)
       print(
          dumper('socraseeds grabbed ', collected_seeds, '/', rt), msg_x, 108
       )
    end
end

function draw_level()
   if in_state(game_state_gaming, game_state_level_fail) then
      draw_terrain(terrain.up, function(t)
                      local from_y = t.y - 4
                      rectfill(t.x, from_y, t.x+2, t.y, brown)
                      rectfill(t.x, 0, t.x+2, from_y, black)
                      if t.texture then
                         draw_terrain_texture(t.x, from_y - t.texture.offset, t.texture)
                      end
      end)
   end

   draw_terrain(terrain.down, function(t)
                   local w      = t.x + 2
                   local to_y   = t.y + g_td
                   rectfill(t.x, t.y, w, to_y, t.colour)
                   rectfill(t.x, 128, w, to_y, black)
                   if t.texture then
                      draw_terrain_texture(t.x, to_y + t.texture.offset, t.texture)
                   end
   end)

   if (cam_x+128) > terrain.up[#terrain.up].x then
      draw_exit()
   end

   local ring_halves = {}
   for obj in all(objects) do
      if on_screen(obj.x) then
         if obj.type == o_stalactite then
            local s = obj.crashed and 4 or (obj.alive and 2 or 3)
            spr(s, obj.x, obj.y)
         elseif obj.type == o_seed then
            if not obj.apogee then
               spr(obj.cur_spr, obj.x, obj.y)
            elseif not obj.collected then
               circfill(obj.x+4, obj.y+4, obj.circ_size, obj.circ_colour)
            end
         elseif obj.type == o_fuel_ring then
            draw_ring_half(obj, 'back')
            add(ring_halves, obj)
         elseif obj.type == o_form then
            draw_form(obj)
         end
      end
   end

   local px = flr(player_x + cam_x)
   if current_state != game_state_splaining then
      -- Player "ship"
      spr(1, px, player_y)
      if claw.extending then
         line(px+8, player_y+4, px+8+claw.length, player_y+4, green)
         spr(claw.anim_at, px+8+claw.length, player_y)
      else
         spr(11, px+8, player_y)
      end
   end

   if not player_crashing and in_state(game_state_gaming, game_state_level_done) and player_fuel > 0 then
      -- "thruster" on ship
      line(px-1, player_y+2, px-1,player_y+6, silver)

      -- "exhaust" from thruster
      if not collided.t then
         sspr(4, 10, 3, 5, px - (3+flr(cam_speed)), player_y+2, 2+cam_speed, 5)
         local vert_thrust_cols = {[0]=red,[1]=orange,[2]=yellow,[3]=white}
         local col = vert_thrust_cols[flr(abs(player_speed_vert))]
         if player_speed_vert > 0 then
            line(px + 2, player_y-1, px+5, player_y-1, col)
         elseif player_speed_vert < 0 then
            line(px + 2, player_y+8, px+5, player_y+8, col)
         end
      end
   end

   draw_form_warning()

   for obj in all(ring_halves) do
      draw_ring_half(obj, 'front')
   end
end

function draw_ui()
   rectfill(cam_x, 0, cam_x+128, 8, dim_grey)

   print('fuel ', cam_x+2, 2, white)
   local fuel_bar_width = 70 * (player_fuel/g_fuel_max)
   local fboffset = cam_x+19
   rectfill(fboffset, 1, fboffset+70, 7, silver)
   rectfill(fboffset, 1, fboffset+fuel_bar_width, 7, player_fuel > 15 and yellow or orange)
   print(nice_pos(player_fuel), cam_x+22, 2, player_fuel > 30 and orange or red)

   local ficon_offset = cam_x+91
   for i = 1, #forms do
      local missing_form = true
      for j = 1, #collected_forms do
         if collected_forms[j].name  == forms[i].name then
            spr(forms[i].icon_spr, ficon_offset, 0)
            missing_form = false
         end
      end
      if missing_form then
         rectfill(ficon_offset+2, 2, ficon_offset+6, 6, white)
      end
      ficon_offset += 8
   end

   if(DEBUG) print(dumper('<| ', cam_x, ' -> ', cam_speed, ' @> ', player_speed_horiz, ' @^ ', player_speed_vert, ' F',frame_count), cam_x + 2, 122, yellow)
end

function _draw()
   cls(navy)

   draw_level()
   if current_state == game_state_menu then
      draw_menu()
   elseif current_state == game_state_splaining then
      draw_exposition()
   else
      draw_ui()
      if current_state == game_state_level_fail then
         draw_fail()
      end
   end
end

__gfx__
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000065aaaa560550055000000550055005500009aa000000aaa000000aaa000000a990000000000000000000000000000000000000000000000000000000
007007006aacaca6065555600005556006555560009000a0000a000a0000a000a0000a000900000000000000000000000b0000000bb000000bb000000bb33000
000770006aacaca60665566000655660006566600900000a00900000a00a00000a00a0000090000000000000b0000000b0b00000b0300000b0330000b0000000
000770006a9aaaa60066660000665600000556000900000a00900000a00a00000900a0000090000000000000b0000000b3000000b3000000b0000000b0000000
007007006aa99aa6006666001165560000065600a0000000a9000000aa900000009a0000000a000000000000b0000000b0b00000b0300000b0330000b0000000
0000000065aaaa56000770000115711000005000a0000000a900000009900000009a0000000a000000000000000000000b0000000bb000000bb000000bb33000
0000000006666660000000000000001100000000a0000000aa00000009900000009a0000000a0000000000000000000000000000000000000000000000000000
0000000006666660000000000000000000000000a0000000aa00000009900000009a0000000a0000000000000000000000000000000000000000000000000000
0000000065aaaa56000000000000000000000000a0000000aa00000009900000009a0000000a0000000000000000000000000000000000000022220000222200
000000806aacaca6000000000000000000000000a0000000aa0000000990000000a90000000a000000000000000000000000000000222200002ee200007ee700
000008a06aacaca60000000000000000000000000a00000900a00000900a00000a00900000a00000000000000000000000222200002ee20002eeee2002eeee20
00008a706a9aaaa60000000000000000000000000a00000900a00000900a00000a00900000a000000000000000222200002ee20002eeee2002eeee2002feef20
000008a06aa99aa600000000000000000000000000a00090000a000a0000a000a00009000a00000000000000112ee21112eeee2102eeee20002ee200002ff200
0000008065aaaa56000000000000000000000000000aa9000000aaa000000aaa00000099a0000000000000001111111111111111111111110022220000222200
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000aaaa00000000000000000000000000000aa00000000999777777779990099977777777999009997777777799900999777777779990
00aaaaaaaaa999000000aaaaaaa900000090000000000000000000aaa9000000098888888888889009cccccccccccc90093333333333339009aaaaaaaaaaaa90
00aaaaaaaaaaa900000aaaaaaaaa900000a900000000000000000aaaaa900000098888888888e89009cccccccccc1c90093333333333b39009aaaaaaaaaa9a90
00a7777aaaaaa90000aaaa77aaaaa90000aa9000000000000000aa7aaaa9000007888888888e887007ccccccccc1cc7007333333333b337007aaaaaaaaa9aa70
00a7777aaaaaaa0000aaa777aaaaaa0000aaaa0000000000000aa77aaaaa90000788888888e8887007cccccccc1ccc700733333333b3337007aaaaaaaa9aaa70
00a77aaaaaaaaa000aaa777aaaaaaaa000aaaaa00000000000aa777aaaaaa900078888888e88887007ccccccc1cccc70073333333b33337007aaaaaaa9aaaa70
00a77aaaaaaaaa000aa7777aaaaaaaa000aaaaaa000000000aaaaaaaaaaaaaa007888888e888887007cccccc1ccccc7007333333b333337007aaaaaa9aaaaa70
00aaaaaaaaaaaa000aa77aaaaaaaaaa000aaaaaaa00000000aaaaaaaaaaaaaa00788888e8888887007ccccc1cccccc700733333b3333337007aaaaa9aaaaaa70
00aaaaaaaaaaaa000aaaaaaaaaaaaaa000aaaaaaaa000000009aaaaaaaaaaa00078888e88888887007cccc1ccccccc70073333b33333337007aaaa9aaaaaaa70
00aaaaaaaaaaaa0000aaaaaaaaaaaa0000a7aaaaaaa000000009aaaaaaaaa00007888e888888887007ccc1cccccccc7007333b333333337007aaa9aaaaaaaa70
009aaaaaaaaaaa00009aaaaaaaaaaa0000a77aaaaaa9000000009aaaaaaa00000788e8888888887007cc1ccccccccc700733b3333333337007aa9aaaaaaaaa70
009aaaaaaaaaaa000009aaaaaaaaa00000a777aaaaaa9000000009aaaaa00000098e88888888889009c1cccccccccc90093b33333333339009a9aaaaaaaaaa90
00999aaaaaaaaa0000009aaaaaaa000000aaaaaaaaaaa9000000009aaa000000098888888888889009cccccccccccc90093333333333339009aaaaaaaaaaaa90
0000000000000000000000aaaa00000000000000000000000000000aa00000000999777777779990099977777777999009997777777799900999777777779990
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0dddddd000daad000d000000000d00000777777707777777077777770777777700000000000000000000000009a009a000000000000000000000000000000000
0daaaaa00daaaad00ad0000000dad0000788888607ccccc60733333607aaaaa600000000000000000009a0000aa00aa000000000000000000000000000000000
0daaaaa00aaaaaa00aad00000daaad000788888607ccccc60733333607aaaaa60009a00009a009a0000aa0000000000000000000000000000000000000000000
0daaaaa00aaaaaa00aaad000daaaaad00788888607ccccc60733333607aaaaa6000aa0000aa00aa0000000000000000000000000000000000000000000000000
0daaaaa00daaaad00aaaad000daaad000788888607ccccc60733333607aaaaa6000000000000000009a009a009a009a000000000000000000000000000000000
0daaaaa000daad000aaaaad000dad0000788888607ccccc60733333607aaaaa600000000000000000aa00aa00aa00aa000000000000000000000000000000000
000000000000000000000000000d0000076666660766666607666666076666660000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000099aaaaa00000099aaaaa099aaaaa00000000000000000000000000000000
000300000000000000000000000000000000000000000000000000000000000000009adddaa0000009aadaaa09aadaaa00000000000000000000000000000000
00333330000000000000000000000000000000000000000000000000000000000000aadaaaa000000aadadaa0aadadaa00000000000000000000000000000000
00033424000000000000000000000000000099aaaaaa0000099aaaa0099aaaa00000aadaaaa000000aadadaa0aadadaa00000000000000000000000000000000
0003432220000000000000000000000000009aaddaaa000009dddaa009dddaa00000aadaaa9000000adaaada0adaaada00000000000000000000000000000000
000422222200000000000000000000000000aaaddaaa00000adaada00adaada00000aaaaa99000000addddd90addddd900000000000000000000000000000000
000422222222200000000000000000000000aadaadaa00000adddaa00adddaa000000000000000000aaaaa990aaaaa990000000000000000a000000000000000
00044222222d220000000000000000000000aaddddaa00000adaada00adaada0099aaaa099aaaa00000000000000000000000000000000000000000000000000
000044222222d22000000000000000000000adaaaada00000addda900addda9009addda09addda00099aaaaa099aaaaa00000000000000000000000000000000
000044222222dd2000000000000000000000adaaaad900000aaaa9900aaaa9900aadaaa0aadaaa0009aadaaa09aadaaa00000000000000000000000000000000
000004442222d22000000000000000000000aaaaaa99000000000000000000000aadaaa0aadaaa000aadadaa0aadadaa00000000000000000000000000000000
00000044222d22200000000000000000000000000000000000000000000000000aadaa90aadaa9000aadadaa0aadadaa00000000000000000000000000000000
00000004442224400000000000000000000000000000000000000000000000000aaaa990aaaa99000adaaada0adaaada00000000000000000000000000000000
000000004444440000000000000000000000000000000000000000000000000000000000000000000addddd90addddd900000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaa990aaaaa9900000000000000000000000000000000
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
00000000000000000000000000000000000009a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0090000000a000000000000000000000000009a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
009a00000aa00000000000000000000000009aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
009aa000aaa00000000000000000000000009aaa00009a09a0000000000000000000000000000000000000000000000000000000000000000000000000000000
009a9a0aa9a09a000000000000000a000009aaaaa0009a09a00000000000000000000009a0000000000000000000000000000000000000000000000000000000
009a09aa09a09a000000000000000a000009a009a0009a09a00000000000000000000009a0000000000000000000000000000000000000000000000000000000
009a009009a000000000000000000a000009a009a0009a09a0000000000000000000000000000000000000000000000000000000000000000000000000000000
009a000009a09a09a09a009a0009aa00009aaaaaaa009a09a009a0009aa009aa0090aa09a009a0009aa000000000000000000000000000000000000000000000
009a000009a09a09aaaa0900a0900a00009a00009a009a09a0900a0900a09000a09a0009a0900a09000000000000000000000000000000000000000000000000
009a000009a09a00aaa009aaa0900a0009aa00009aa09a09a09aaa0900a09000a0900009a09aaa009a0000000000000000000000000000000000000000000000
009a000009a09a09aaaa090000900a0009a0000009a09a09a090000900a09000a0900009a090000000a000000000000000000000000000000000000000000000
009a000009a09a09a09a009aa009aa0009a0000009a09a09a009aa009aa009aa00900009a009aa099a0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000
0099999999999999999999999999999999999999999999999999990900a099999999999999999999999000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000009aa000000000000000000000000000000000000000000000000000000000000000000000
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111191111111a111111111111111111111111119a11111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111119a11111aa111111111111111111111111119a11111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111119aa111aaa11111111111111111111111119aaa1111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111119a9a1aa9a19a111111111111111a1111119aaa11119a19a1111111111111111111111111111111111111111111111111111111111111
111111111111111111119a19aa19a19a111111111111111a111119aaaaa1119a19a11111111111111111111119a1111111111111111111111111111111111111
111111111111111111119a119119a111111111111111111a111119a119a1119a19a11111111111111111111119a1111111111111111111111111111111111111
111111111111111111119a111119a19a19a19a119a1119aa111119a119a1119a19a1111111111111111111111111111111111111111111111111111111111111
111111111111111111119a111119a19a19aaaa1911a1911a11119aaaaaaa119a19a119a1119aa119aa1191aa19a119a1119aa111111111111111111111111111
111111111111111111119a111119a19a11aaa119aaa1911a11119a11119a119a19a1911a1911a19111a19a1119a1911a19111111111111111111111111111111
111111111111111111119a111119a19a19aaaa191111911a1119aa11119aa19a19a19aaa1911a19111a1911119a19aaa119a1111111111111111111111111111
111111111111111111119a111119a19a19a19a119aa119aa1119a1111119a19a19a191111911a19111a1911119a191111111a111111111111111111111111111
1111111111111111111111111111111111111111111111111119a1111119a19a19a119aa119aa119aa11911119a119aa199a1111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111a111111111111111111111111111111111111111111111111111
1111111111111111111199999999999999999999999999999999999999999999999999991911a199999999999999999999999111111111111111111111111111
111111111111111111111111111111111111111111111111111111111111111111111111119aa111111111111111111111111111111111111111111111111111
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
11111111111111111111111111111111777177717771177117711111177777111111777117711111777177711771777177111111111111111111111111111111
11111111111111111111111111111111717171717111711171111111771717711111171171711111717171117111171171711111111111111111111111111111
11111111111111111111111111111111777177117711777177711111777177711111171171711111771177117111171171711111111111111111111111111111
11111111111111111111111111111111711171717111117111711111771717711111171171711111717171117171171171711111111111111111111111111111
11111111111111111111111111111111711171717771771177111111177777111111171177111111777177717771777171711111111111111111111111111111
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
11111111111111111666666111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111165aaaa5611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111116aacaca611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111116aacaca6b1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111116a9aaaa6b1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111116aa99aa6b1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111165aaaa5611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111666666111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
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
11111111111111111111111111111111111111111111111100000000000000005555555555555555555111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111100000000000000005555555555555555555551111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111110000000000000000005555555555555555555555555111111111111111111111005555555555511111
11111111111111115551111111111111111111111111000000000000000000005555555555555555555555555551111111111111110000005555555555555555
11111111111100005555511111111111111111111111000000000000000000005555555555555555555555555555555111111100000000005555555555555555
11111111110000005555555111111111111111111100000000000000000000005555555555555555555555555555555551000000000000005555555555555555
11111111000000005555555551111111111111110000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
11111100000000005555555551111111111111110000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
11000000000000005555555555511111111111000000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
00000000000000005555555555555111111100000000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
00000000000000005555555555555551111100000000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
00000000000000005555555555555555510000000000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
00000000000000005555555555555555000000000000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
00000000000000005555555555555555000000000000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
00000000000000005555555555555555000000000000000000000000000000005555555555555555555555555555555500000000000000005555555555555555
00000000000000005555555555555555000000000000000000000000000000000000000000000000005555555555555500000000000000005555555555555555
00000000000000005555555555555555000000000000000000000000000000000000000000000000000055555555555500000000000000005555555555555555
00000000000000005555555555555555000000000000000000000000000000000000000000000000000000005555555500000000000000000000000000555555
00000000000000000055555555555555000000000000000000000000000000000000000000000000000000000055555500000000000000000000000000000000
00000000000000000000555555555555000000000000000000000000000000000000000000000000000000000000005500000000000000000000000000000000
00000000000000000000005555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000055555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000055555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000005555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c6c000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000b5b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
490500001d520005220f5220f51111511115111252112521135201353118510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4904000000530005320f5320f52111521115211253112531135301354118510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4903000000530005320f5320f52111521115211253112531135301354118510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4902000000530005320f5320f52111521115211253112531135301354118510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
510a000018524185211852118521185211f5311f5311f5311f5372153721537215372153500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
490400001572415726135261353110731107310073500300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
87060000136341362121621216201c6301c5211d5211f521000000000018200135241352115521105001c7001c700105001050018514185111a51100000000000000000000000000000000000000000000000000
870700000a6440a637096270461310510105250000000000000000000010520000000000010505105001071000000105051050510505107250000000000000000000000000000000000010505000000000000000
c30500000463607124071310912109135000000000000000000000000009110000001510000000000000000000000000000000009710151051510500000000000000000000000000000009715000000000015105
490600001a5241c5111d5111f5111f525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001f5241d5111d5111c5111a5250000000000000001a5001c5001d5001f5001f50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
530c00001053610530135301353015540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7b0800001f6441f63113544105310e5310e5310c5210c5210c5250000000000095010211000000045000410004110000000410500000041150000000000000000000000000000000000000000000000000000000
