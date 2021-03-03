pico-8 cartridge // http://www.pico-8.com
version 30
__lua__

-- Brain won't map colours to numbers so get computer to do it
black    = 0 navy     = 1 magenta  = 2 green    = 3
brown    = 4 dim_grey = 5 silver   = 6 white    = 7
red      = 8 orange   = 9 yellow   = 10 lime    = 11
azure    = 12 violet  = 13 salmon  = 14 coral   = 15

dir_left  = -1
dir_right = 1

b_left  = ⬅️ b_right = ➡️
b_down  = ⬇️ b_up    = ヌて●
b_x     = ❎  b_z     = 🅾️

g_friction  = 0.9
g_top_speed = 3
g_edge_rhs  = 64
g_edge_lhs  = 16
g_racing_line = 118
g_car_line    = g_racing_line - 6

r_step = 1 / 360

spr_tree  = { 0, 32, 8, 16 }
spr_shrub = { 8, 32, 16, 8 }

function _init()
   car = {
      x = 16,
      y = g_car_line,
      speed = 0,
      accel = 0.6,
      dy = 0,
      jumping = false,
      past = {},
      len = 0,
      boosted_at = false,
   }

   scene = {
      -- Trees
      { spr = tree_spr, at = { 64, 85 } },
      { spr = tree_spr, at = { 160, 85 } },
      { spr = tree_spr, at = { 220, 85 } },
      -- Shrub
      { spr = spr_shrub, at = { 32, 95 } },
      { spr = spr_shrub, at = { 96, 95 } },
      { spr = spr_shrub, at = { 130, 95 } },
   }

   ramps = {
      { angle = 30, length = 45, at = { 100, g_racing_line } },
      { angle = 50, length = 40, at = { 255, g_racing_line } },
   }

   boosters = {
      { length = 16, boost = 1.5, at = { 50, g_racing_line } }
   }
end

function track_car()
   while #car.past > 50 do
      deli(car.past, 1)
   end

   -- add(car.past, {x = car.x, y = car.y + 8})
end

function respect_incline(r)
   car.speed -= 0.1
   car.dy += 0.2
end

function apply_gravity()
   car.dy += 0.08 -- gravity
   if(car.dy > 0) car.dy *= 1.01
   car.y  += car.dy

   -- TODO Implement a bounce!
   if car.y > g_car_line then
      car.y = g_car_line
      car.dy = 0
      car.jumping = false
   else
      car.jumping = true
      -- debug('car.y = ', car.y, ', car.dy = ', car.dy)
   end
end

function on_ramp()
   for r in all(ramps) do
      local rx1 = ramp_trig(r)
      if (car.x+4) > r.at[1] and (car.x+4) < rx1 then
         return r
      end
   end
   return false
end

function on_booster()
   for b in all(boosters) do
      if (car.x+4) > b.at[1] and (car.x+4) < (b.at[1] + b.length)
      and car.y == g_car_line then
         return b
      end
   end
   return false
end

function update_car()
   local accelerating = btn(b_right) or btn(b_left)

   if btn(b_right) then
      if (car.speed + car.accel) < g_top_speed then
         car.speed += car.accel
      end
   end

   if btn(b_left) then
      -- TODO Speed going backward should be lower
      if abs(car.speed - car.accel) < g_top_speed then
         car.speed -= car.accel
      end
   end

   local r = on_ramp()
   if not car.boosted_at or t() - car.boosted_at > 0.5 then
      -- TODO Make this more gradual, probably need to move away from linear speed.
      car.speed *= g_friction
      if not accelerating then
         car.speed *= g_friction
      end

      if r then
         -- TODO Improve friction relative to ramp.
         car.speed *= g_friction * 0.95 - (r.angle/1000)
      end

      car.boosted_at = false
   end

   local b = on_booster()
   if b and not car.boosted then
      car.speed += b.boost
      car.boosted_at = t()
   end

   track_car()

   local next_pos = car.x + car.speed
   if next_pos > g_edge_lhs and next_pos < g_edge_rhs then
      -- TODO throttle movement when in the air
      car.x += car.speed
   elseif next_pos > g_edge_rhs then
      car.x = g_edge_rhs
   end

   -- TODO Handle landing on a ramp!
   if r and not car.jumping then
      -- These are offsets relative to where the car is on the ramp.
      local car_x = (car.x+4) - r.at[1]
      local car_y = max(1, g_car_line - car.y)
      -- Rough calculation of the current position along the hypoteneuse.
      -- It's rough because car_y is basically a reasonable guess.
      local len   = sqrt((car_x*car_x)+(car_y*car_y))
      local new_y = len * sin(r.angle * r_step)
      car.y = min(g_car_line, g_car_line + new_y)
      -- debug('car ', flr(car.x+4), ' x ', flr(car.y), ' car_x ', car_x, ' x ', car_y, ' car len ', flr(len), ' r.len ', r.length, ' x0/y0 ', r.at, ' -> x1/y1 ', {ramp_trig(r)})
      car.len = len

      if btn(b_right) then
         local new_dy = car.dy - (0.008 * r.angle)
         car.dy = abs(new_dy) > 1.7 and -1.7 or new_dy
      elseif btn(b_left) then
         car.dy += 0.1
      end

      if not accelerating then
          respect_incline(r)
      end
   else
      apply_gravity()
   end
end

function populate_future_scene()
   local last_obj = scene[#scene]
   if last_obj.at[1] < 120 then
      local new_x   = 150 + randx(50)
      local new_obj = randx(2) == 1
         and { spr = spr_tree,  at = { new_x, 85 } }
         or  { spr = spr_shrub, at = { new_x, 95 } }
      add(scene, new_obj)
   end
end

function populate_future_ramps()
   local last_ramp = ramps[#ramps]
   if last_ramp.at[1] < 220 then
      add(ramps, {
             angle = randx(45) + 10,
             length = randx(40) + 20,
             at = { 460, g_racing_line }
      })
      if randx(2) == 1 then
         add(boosters, {
                length = randx(30) + 10,
                boost = 1 + rnd(),
                at = { 400, g_racing_line }
         })
      end
   end
end

function update_scene()
   for obj in all(scene) do
      obj.at[1] += -car.speed
   end

   populate_future_scene()

   for r in all(ramps) do
      r.at[1] += -car.speed
   end

   populate_future_ramps()


   for b in all(boosters) do
      b.at[1] += -car.speed
   end
end

function _update()
   update_scene()
   update_car()
end

function ramp_trig(r, angle)
   angle = angle == nil and r.angle or angle
   local x  = r.at[1] + (r.length * cos(angle * r_step))
   local y  = r.at[2] + (r.length * sin(angle * r_step))
   return x, y
end

function draw_scene()
   for obj in all(scene) do
      if obj.at[1] > -16 and obj.at[1] < 128 then
         local s = copy_table(obj.spr)
         add(s, obj.at[1] * 1.15)
         add(s, obj.at[2])
         sspr(unpack(s))
      end
   end

   for r in all(ramps) do
      if r.at[1] > -r.length and r.at[1] < 128 then
         local rx = r.at[1]
         local ry = r.at[2]
         local x, y = ramp_trig(r)
         -- Slope
         line(rx, ry, x, y, yellow)

         local slope = r.angle
         -- Fill the ramp with solid colour.
         while slope >= 0 do
            local lx, ly = ramp_trig(r, slope)
            local d   = r.angle - slope
            local col = (d < 5) and yellow or (d < 20) and orange or red
            line(rx, ry, x, ly, col)
            slope -= 1
         end
      end
   end

   for b in all(boosters) do
      if b.at[1] > -b.length and b.at[1] < 128 then
         local bx0 = b.at[1]
         local bx1 = bx0 + b.length
         line(bx0, g_racing_line, bx1, g_racing_line, yellow)
         line(bx0, g_racing_line + 1, bx1, g_racing_line + 1, orange)
         line(bx0, g_racing_line + 2, bx1, g_racing_line + 2, red)
      end
   end
end

function draw_car_debug()
   if(not DEBUG_GFX) return

   for pos in all(car.past) do
      pset(pos.x, pos.y, white)
   end

   local r = on_ramp()
   if r then
      line(r.at[1], r.at[2], (car.x+4), car.y+8, lime)
      line(r.at[1], r.at[2], r.at[1]+car.len, r.at[2], azure)
   end

end

function _draw()
   cls(silver)

   rectfill(0, 100, 128, 105, violet)
   rectfill(0, 105, 128, 128, navy)

   draw_scene()

   draw_car_debug()
   spr(1, car.x, car.y)
end

-- ## Util functions ## --
DEBUG_GFX = false
DEBUG = true

function dumper(...)
   local res = ''
   for v in all({...}) do
      if type(v) == 'table' then
         res = res .. tbl_to_str(v)
      elseif type(v) == 'number' then
         res = res .. ( v % 1 == 0 and v or nice_pos(v) )
      else
         res = res .. tostr(v)
      end
   end
   return res
end

function debug(...)
   if(not DEBUG) return

   printh(dumper(...))
end

function tbl_to_str(a)
   local res = '{'
   for k, v in pairs(a) do
      local lhs = type(k) != 'number' and k .. ' => ' or ''
      res = res .. lhs .. dumper(v) .. ', '
   end
   return sub(res, 0, #res - 2) .. "}"
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

-- Random index.
function randx(n)
   return flr(rnd(n)) + 1
end

function nice_pos(inms)
   local sec = flr(inms)
   local ms  = flr(inms * 100 % 100)
   if(ms == 0) then
      ms = '00'
   elseif(ms < 10) then
      ms = '0' .. ms
   end
   return sec .. '.' .. ms
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000009aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000099999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700955995590000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000055005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00033300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000003333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000033333733000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000033733333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000333333333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333330000373337373000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333333000333733333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03344433000044455440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
