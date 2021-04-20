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

function delay(f, n)
   animate(function() for _=1,n do yield() end f() end)
end

function animate(f)
   animate_obj({}, f)
end

anims={}
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

function animate_move(obj)
   function easein(t)
      return t*t
   end

   function lerp(a,b,t)
      return a+(b-a)*t
   end

   animate_obj(obj, function()
              for f = 1, obj.frames do
                 if(obj.crashed) return
                 obj.y = lerp(obj.from, obj.to, easein(f/obj.frames))
                 yield()
              end
   end)
end

g_fuel_max = 50

function start_escape()
   cam_x = 0
   cam_speed = 1

   player_x = 16
   player_y = 64
   player_speed_vert  = 0
   player_speed_horiz = 0

   player_fuel = g_fuel_max

   frame_count = 0

   collided = { up = false, down = false}
end

o_stalactite = 'stalactite'
o_fuel_ring  = 'fuel_ring'
o_form       = 'platonic_form'

forms = {
   { name = 'square',   spr = {2,  18, 11, 11} },
   { name = 'circle',   spr = {17, 17, 14, 14} },
   { name = 'triangle', spr = {34, 18, 11, 11} },
   { name = 'diamond',  spr = {49, 17, 14, 14} },
   -- TODO Colours
}

function generate_terrain()
   terrain={up={},down={}}
   objects={}

   local lvl={up={},down={}}

   -- Generate slopes
   for l = 1,10 do
      local go_up       = randx(2) > 1
      local offset_up   = randx(15) + (l*3)
      local offset_down = randx(15) + (l*3)
      for _ = 1,16 do
         local up = 8 + randx(15) + offset_up
         add(lvl.up,   up)
         local down = 128 - (randx(30) + offset_down)
         -- Prevent up and down meeting in the middle.
         if (down-up) < 15 then
            local wasd=down
            down = up + 20
            dump('rounded down from ', wasd, ' to ', down, ', up is ', up)
         end
         add(lvl.down, down)
         -- Random slopes so the middle isn't totally safe
         offset_up   = max(1, offset_up   + (go_up and -2 or 2))
         offset_down = max(1, offset_down + (go_up and  2 or -2))
      end
   end

   local function calc_terrain_step(terr, from, to, x, tc)
      local step = -(from-to) / 8
      local y    = from
      for j = 1,8 do
         local tex_col = ({azure,lime,red,yellow})[randx(4)]
         local texture = make_obj({c=tex_col,offset=randx(20),wink=white})
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
   local colours = {{dim_grey,silver},{magenta,violet},{silver,white}}
   -- Calculate terrain
   local x = 0
   for i = 1, #lvl.up - 2, 2 do
      local tc_down = colours[i < 60 and 1 or i < 120 and 2 or 3]

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
      if gap > 20 then
         if x % 160 == 0 and #lvl_forms > 0 then
            local form_spr = lvl_forms[1]
            del(lvl_forms, form_spr)
            local form = make_obj({
                  type=o_form,
                  y=up_y+flr(gap/2),
                  x=x,
                  spr = form_spr.spr,
                  name = form_spr.name,
                  collected=false
            })
            add(objects, form)
         elseif x % 128 == 0 and randx(3) > 1 then
            local oy  = up_y - 6
            local obj = make_obj({
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
            add(objects, obj)
         elseif x % 96 == 0 then -- and randx(5) > 3 then
            local ring = make_obj({
                  type=o_fuel_ring,
                  y=up_y+randx(gap),
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

function _init()
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
g_td = 15

function did_collide(terr, x, y, test)
   local px0 = x + cam_x
   local px1 = px0 + 8
   local py0 = y
   local py1 = py0 + 8

   for idx, pos in pairs(terr) do
      if test(pos, px0, px1, py0, py1) then
         -- dump_once('collided at\n', terrain.up[idx], '\n', terrain.down[idx])
         return true
      end
   end

   return false
end

function did_collide_up(x, y)
   local function coll_test(pos, px0, px1, py0, py1)
      local pos_top = max(1, pos.y)
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
   local next_f = player_fuel - n
   player_fuel = next_f >= 0 and next_f or 0
end

ring_streak = 0
collected_forms = {}
collecting_form = false
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
               collecting_form = obj
               add(collected_forms, obj)
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
               end)
               return g_min_speed
            end
         end
      end
   end
end

claw = make_obj({length=0,anim_at=18,extending=false,extended=false})
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
      for _=1,10 do yield() end
      local fc = frame_count
      while btn(b_x) and (frame_count - fc) < 70 and not collecting_form do yield() end
      claw.extended=false

      for f=1,15 do
         if f % 3 == 0 then
            claw.length -= 0.5
            claw.anim_at = max(11, claw.anim_at-1)
         end
         yield()
      end

      claw.extending = false
   end

   claw.extending=true
   animate(anim)
end

function _update()
   frame_count += 1

   run_animations()

   if btn(b_x) and not claw.extending then
      extend_claw()
   end

   local next_x = player_x
   local next_y = player_y
   local next_s = cam_speed

   if not collecting_form then
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
      collided = { up = true,  down = false }
      player_speed_horiz = 0
      cam_speed = g_min_speed
   elseif did_collide_down(next_x, next_y) then
      collided = { up = false, down = true }
      player_speed_horiz = 0
      cam_speed = g_min_speed
   else
      local new_s = check_objects(next_x, next_y)
      if(new_s) next_s = min(g_max_speed, new_s)
      collided = { up = false, down = false }
   end

   if (not collided.up and next_y < player_y)
   or (not collided.down and next_y > player_y) then
      player_y = flr(next_y)
   end

   if not collided.up and not collided.down then
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
   else
      consume_fuel(0.5)
      ring_streak = 0
   end

   for obj in all(objects) do
      if not obj.animating and obj.alive and on_screen(obj.x) then
         if obj.type == o_stalactite and not obj.crashed and obj.x - (cam_x+player_x) < 60 then
            animate_move(obj)
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
   for f=1,60 do yield() end
   -- Move it off screen
   r.x = -1
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
   pset(x,   y,   t.wink)
   pset(x-1, y,   c)
   pset(x+1, y,   c)
   pset(x,   y-1, c)
   pset(x,   y+1, c)
   if frame_count % 30 == 0 then
      t.wink = t.wink == white and navy or white
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

function _draw()
   cls(navy)

   draw_terrain(terrain.up, function(t)
                   local from_y = t.y - 4
                   rectfill(t.x, from_y, t.x+2, t.y, brown)
                   rectfill(t.x, 0, t.x+2, from_y, black)
                   if t.texture then
                      draw_terrain_texture(t.x, from_y - t.texture.offset, t.texture)
                   end
   end)
   draw_terrain(terrain.down, function(t)
                   local w      = t.x + 2
                   local to_y   = t.y + g_td
                   rectfill(t.x, t.y, w, to_y, t.colour)
                   rectfill(t.x, 128, w, to_y, black)
                   if t.texture then
                      draw_terrain_texture(t.x, to_y + t.texture.offset, t.texture)
                   end
   end)

   local ring_halves = {}
   for obj in all(objects) do
      if on_screen(obj.x) then
         if obj.type == o_stalactite then
            local s = obj.crashed and 4 or (obj.alive and 2 or 3)
            spr(s, obj.x, obj.y)
         elseif obj.type == o_fuel_ring then
            draw_ring_half(obj, 'back')
            add(ring_halves, obj)
         elseif obj.type == o_form then
            local s = copy_table(obj.spr)
            add(s, obj.x)
            add(s, obj.y)
            add(s, obj.dw or s[3])
            add(s, obj.dh or s[4])
            sspr(unpack(s))
         end
      end
   end

   local px = flr(player_x + cam_x)
   -- Player "ship"
   spr(1, px, player_y)
   if claw.extending then
      line(px+8, player_y+4, px+8+claw.length, player_y+4, green)
      spr(claw.anim_at, px+8+claw.length, player_y)
   else
      spr(11, px+8, player_y)
   end
   -- "thruster" on ship
   line(px-1, player_y+2, px-1,player_y+6, silver)
   -- "exhaust" from thruster
   if not collided.up and not collided.down then
      sspr(4, 10, 3, 5, px - (3+flr(cam_speed)), player_y+2, 2+cam_speed, 5)
      local vert_thrust_cols = {[0]=red,[1]=orange,[2]=yellow,[3]=white}
      local col = vert_thrust_cols[flr(abs(player_speed_vert))]
      if player_speed_vert > 0 then
         line(px + 2, player_y-1, px+5, player_y-1, col)
      elseif player_speed_vert < 0 then
         line(px + 2, player_y+8, px+5, player_y+8, col)
      end
   end

   for obj in all(ring_halves) do
      draw_ring_half(obj, 'front')
   end

   rectfill(cam_x, 0, cam_x+128, 8, silver)
   print('fuel ', cam_x+2, 2, white)
   local fuel_bar_width = 78 * (player_fuel/g_fuel_max)
   rectfill(cam_x+20, 1, cam_x+20+fuel_bar_width, 7, player_fuel > 15 and yellow or orange)
   print(nice_pos(player_fuel), cam_x+22, 2, player_fuel > 30 and orange or red)
   print('⧗'..nice_pos(frame_count/30), cam_x+99, 2, white)

   if(DEBUG) print(dumper('<| ', cam_x, ' -> ', cam_speed, ' @> ', player_speed_horiz, ' @^ ', player_speed_vert, ' F',frame_count), cam_x + 2, 11, yellow)
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
0000000065aaaa56000000000000000000000000a0000000aa00000009900000009a0000000a0000000000000000000000000000000000000000000000000000
000000806aacaca6000000000000000000000000a0000000aa0000000990000000a90000000a0000000000000000000000000000000000000000000000000000
000008a06aacaca60000000000000000000000000a00000900a00000900a00000a00900000a00000000000000000000000000000000000000000000000000000
00008a706a9aaaa60000000000000000000000000a00000900a00000900a00000a00900000a00000000000000000000000000000000000000000000000000000
000008a06aa99aa600000000000000000000000000a00090000a000a0000a000a00009000a000000000000000000000000000000000000000000000000000000
0000008065aaaa56000000000000000000000000000aa9000000aaa000000aaa00000099a0000000000000000000000000000000000000000000000000000000
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000aaaaa90000000000000000000000000000aa00000000554777777774550055477777777455005547777777745500554777777774550
00aaaaaaaaa999000000aaaaaaa900000090000000000000000000aaa9000000058888888888885005cccccccccccc50053333333333335005aaaaaaaaaaaa50
00aaaaaaaaaaa900000aaaaaaaaa900000a900000000000000000aaaaa900000048888888888884004cccccccccccc40043333333333334004aaaaaaaaaaaa40
00a7777aaaaaa90000aaaa77aaaaa90000aa9000000000000000aa7aaaa90000078888888888887007cccccccccccc70073333333333337007aaaaaaaaaaaa70
00a7777aaaaaaa000aaaa777aaaaaa9000aaaa0000000000000aa77aaaaa9000078888888888887007cccccccccccc70073333333333337007aaaaaaaaaaaa70
00a77aaaaaaaaa000aaa777aaaaaaaa000aaaaa00000000000aa777aaaaaa900078888888888887007cccccccccccc70073333333333337007aaaaaaaaaaaa70
00a77aaaaaaaaa000aa7777aaaaaaaa000aaaaaa000000000aaaaaaaaaaaaaa0078888888888887007cccccccccccc70073333333333337007aaaaaaaaaaaa70
00aaaaaaaaaaaa000aa77aaaaaaaaaa000aaaaaaa00000000aaaaaaaaaaaaaa0078888888888887007cccccccccccc70073333333333337007aaaaaaaaaaaa70
00aaaaaaaaaaaa000aaaaaaaaaaaaaa000aaaaaaaa000000009aaaaaaaaaaa00078888888888887007cccccccccccc70073333333333337007aaaaaaaaaaaa70
00aaaaaaaaaaaa0009aaaaaaaaaaaaa000a7aaaaaaa000000009aaaaaaaaa000078888888888887007cccccccccccc70073333333333337007aaaaaaaaaaaa70
009aaaaaaaaaaa00009aaaaaaaaaaa0000a77aaaaaa9000000009aaaaaaa0000078888888888887007cccccccccccc70073333333333337007aaaaaaaaaaaa70
009aaaaaaaaaaa000009aaaaaaaaa00000a777aaaaaa9000000009aaaaa00000048888888888884004cccccccccccc40043333333333334004aaaaaaaaaaaa40
00999aaaaaaaaa0000009aaaaaaa000000aaaaaaaaaaa9000000009aaa000000058888888888885005cccccccccccc50053333333333335005aaaaaaaaaaaa50
0000000000000000000009aaaaa0000000000000000000000000000aa00000000554777777774550055477777777455005547777777745500554777777774550
__sfx__
4905000000520005220f5220f51111511115111252112521135201353118510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4904000000530005320f5320f52111521115211253112531135301354118510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4903000000530005320f5320f52111521115211253112531135301354118510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4902000000530005320f5320f52111521115211253112531135301354118510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
490400001572415726135261353110731107310073500300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
870700000a6440a637096270461310510105250000000000000000000010520000000000010505105001071000000105051050510505107250000000000000000000000000000000000010505000000000000000
c30500000463607124071310912109135000000000000000000000000009110000001510000000000000000000000000000000009710151051510500000000000000000000000000000009715000000000015105
