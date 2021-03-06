pico-8 cartridge // http://www.pico-8.com
version 30
__lua__

-- Brain won't map colours to numbers so get computer to do it
black    = 0 navy     = 1 magenta  = 2 green    = 3
brown    = 4 dim_grey = 5 silver   = 6 white    = 7
red      = 8 orange   = 9 yellow   = 10 lime    = 11
azure    = 12 violet  = 13 salmon  = 14 coral   = 15

screen_width = 128

dir_left  = -1
dir_right = 1

b_left  = ⬅️ b_right = ➡️
b_down  = ⬇️ b_up    = ヌて●
b_x     = ❎  b_z     = 🅾️

g_dt           = 1/30
g_friction     = 0.9
g_air_friction = 0.98
g_top_speed    = 3
g_top_boost    = 10

g_edge_rhs  = 64
g_edge_lhs  = 16

g_racing_line = 118
g_car_line    = g_racing_line - 6

r_step = 1 / 360

spr_tree   = { 0,  32, 8,  16 }
spr_shrub  = { 8,  32, 16, 8  }
spr_player = { 8,  0,  8,  8  }
spr_boost  = { 16, 0,  8,  8  }
spr_flag   = { 24, 32, 16, 16 }

function _init()
   car = {
      x = 16,
      y = g_car_line,
      dir = dir_right,
      speed = 0,
      accel = 0.4,
      dy = 0,
      jumping = false,
      past = {},
      len = 0,
      boosted_at = false,
      boost_meter = 0
   }

   level = {
      length = 1000
   }

   -- This needs to be first as it's the measure of when to wrap.
   scene = { make_obj({ 0, 88 }, { spr = spr_flag }, 0) }

   ramps = {}
   boosters = {}
   platforms = {}

   populate_scenery()
   populate_geometry()
end

function wrap_point() return scene[1].at[1] end

function make_obj(pos, attr, wrap_at)
   if(wrap_at == nil) wrap_at = wrap_point()
   return merge(
      { at = pos, orig_at = copy_table(pos) },
      attr
   )
end

function make_bg_spr(spr, at) return make_obj(at, { spr = spr }) end
function make_ramp(attr, at) return make_obj({ attr.x, g_racing_line }, attr) end
function make_booster(attr, at) return make_obj({ attr.x, g_racing_line }, attr) end

function populate_scenery()
   local x = 15
   local last_point = level.length - screen_width

   while x < last_point do
      local new_x   = x + randx(50)
      local new_obj = randx(2) == 1
         and make_bg_spr(spr_tree,  { new_x, 85 })
         or  make_bg_spr(spr_shrub, { new_x, 95 })

      add(scene, new_obj)

      x += 60 -- Seems about right?
--      debug('added scenery ', scene[#scene])
   end
end

function populate_geometry()
   local x = 30
   local last_point = level.length - screen_width

   while x < last_point do
      local new_x = x + randx(30)

      add(boosters, make_booster(
             { x = new_x, boost = 1.2 + rnd(), length = randx(30) + 10 }
      ))

      add(ramps, make_ramp(
             { x = new_x + 50, angle = randx(25) + 10, length = randx(20) + 30 }
      ))

      x += 300
   end
end

----------------------
-- UPDATE functions --
----------------------

function track_car()
   if(not DEBUG_GFX) return

   while #car.past > 50 do
      deli(car.past, 1)
   end

   add(car.past, {x = car.x, y = car.y + 8})
end

function respect_incline(r)
   car.speed -= 0.1
   car.dy += 0.2
end

function apply_gravity()
   -- The number used here feels about right, is arbitrary.
   car.dy += 35 * g_dt
   car.y += car.dy * g_dt

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

function still_boosting()
   local boost_active = car.boosted_at and t() - car.boosted_at < 0.5
   local boost_power  = car.boost_meter > 0
   return boost_active or boost_power
end

function update_car()
   local accelerating = btn(b_right) or btn(b_left)

   local sw = car.speed
   if btn(b_right) then
      if car.dir != dir_right and car.speed >= 0 then
         car.dir = dir_right
      end

      if (car.speed + car.accel) < g_top_speed then
         car.speed += car.accel
      end
   end

   if btn(b_left) then
      if car.dir != dir_left and car.speed < 0 then
         car.dir = dir_left
      end

      if not car.jumping and abs(car.speed - car.accel) < g_top_speed then
         car.speed -= car.accel
      end
      -- Allow slowing down back to normal speed
      -- TODO handle going left!
      if car.jumping and car.speed > g_top_speed then
         car.speed -= car.accel/3
      end
   end

   -- debug('was going ', sw, ' now going ', car.speed, ' with boost ', car.boost_meter, ' boost amt ', car.boost_was, ' last boost at ', car.boosted_at)

   local r = on_ramp()

   if not still_boosting() then
      -- TODO Make this more gradual, probably need to move away from linear speed.
      if not car.jumping then
         car.speed *= g_friction
         if not accelerating  then
            car.speed *= g_friction
         end
      else
         car.speed *= g_air_friction
      end

      if r then
         -- TODO Improve friction relative to ramp.
         car.speed *= g_friction * 0.95 - (r.angle/1000)
      end

      car.boosted_at = false
   end

   -- Reduce boost if on the ground or in the air and "breaking"
   if still_boosting() and (not car.jumping and t() - car.boosted_at > 0.3) or btn(b_left) then
      if car.boost_meter > 0 then
         car.boost_meter -= 1
      end
   end

   local b = on_booster()
   if b and car.speed < g_top_boost then
      -- TODO implement a max speed ... but going insanely fast is fun.
      car.speed += sgn(car.speed) * b.boost
      car.boosted_at  = t()
      car.boost_meter = 32
      car.boost_was   = b.boost
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
         local new_dy = car.dy - (0.03 * r.angle)
         if(car.boosted_at) new_dy *= 3
         car.dy = abs(new_dy) > 32 and -32 or new_dy
      elseif btn(b_left) then
         car.speed -= car.accel
         car.dy += 10
      end

      if not accelerating then
          respect_incline(r)
      end
   else
      apply_gravity()
   end
end

function should_wrap_level()
   local wp = wrap_point()
   return wp < -level.length or wp > 129
end

function horizon_offset(y)
   return y - (0.1 * (g_car_line - car.y))
end

function update_scene()
   for obj in all(scene) do
      obj.at[1] += -car.speed
      obj.at[2] = horizon_offset(obj.orig_at[2])
   end

   for r in all(ramps) do
      r.at[1] += -car.speed
   end

   for b in all(boosters) do
      b.at[1] += -car.speed
   end

   for p in all(platforms) do
      p.at[1] += -car.speed
   end
end

function reset_scene(reset_x)
   foreach(scene,     reset_x)
   foreach(ramps,     reset_x)
   foreach(boosters,  reset_x)
   foreach(platforms, reset_x)
end

function _update()
   local function reset_x_right(obj) obj.at[1] = obj.orig_at[1] + screen_width end
   local function reset_x_left(obj)  obj.at[1] = -((level.length - screen_width) - obj.orig_at[1]) end
   if should_wrap_level() then
      reset_scene((wrap_point() < 0) and reset_x_right or reset_x_left)
   else
      update_scene()
   end

   update_car()
end

----------------------
-- DRAW functions --
----------------------

function ramp_trig(r, angle)
   angle = angle == nil and r.angle or angle
   local x  = r.at[1] + (r.length * cos(angle * r_step))
   local y  = r.at[2] + (r.length * sin(angle * r_step))
   return x, y
end

function render_sprite(sxywh, x, y, flip_x, flip_y)
   local s = copy_table(sxywh)
   add(s, x)
   add(s, y)
   add(s, sxywh[3])
   add(s, sxywh[4])
   if(flip_x != nil) add(s, flip_x)
   if(flip_y != nil) add(s, flip_y)
   sspr(unpack(s)) -- Could be done with spr, too lazy to change.
end

function draw_scene()
   for obj in all(scene) do
      if obj.at[1] > -16 and obj.at[1] < 128 then
         -- Flag fiddliness, prolly worth splitting it out.
         if obj.spr == spr_flag then
            palt(0, false)
            palt(1, true)
         else
            palt()
         end
         render_sprite(obj.spr, obj.at[1], obj.at[2])
      end
   end

   palt()

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


   for p in all(platforms) do
      if p.at[1] > -p.length and p.at[1] < 128 then
         local px = p.at[1]
         local py = p.at[2]
         rectfill(px, py, px + p.length, py - 2, orange)
      end
   end
end

function draw_ewe_ai()
   rectfill(92, 2, 124, 8, white)
   if car.boost_meter > 0 then
      rectfill(92, 2, 92 + car.boost_meter, 8, orange)
      print('boost', 94, 3, yellow)
   else
      print('boost', 94, 3, salmon)
   end

   print(dumper('@ ', flr(car.x), 'x', flr(car.y), ' - ', flr(wrap_point())), 2, 2, azure)
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

function draw_car()
   draw_car_debug()

   local flip = car.dir == dir_left
   if still_boosting() then
      local bx = flip and car.x + 8 or car.x - 8
      render_sprite(spr_boost, bx, car.y, flip)
   end

   render_sprite(spr_player, car.x, car.y, flip)
end

function _draw()
   cls(silver)

   draw_ewe_ai()

   -- Background layer.
   rectfill(0, horizon_offset(100), 128, 105, violet)
   rectfill(0, 105, 128, 128, navy)

   draw_scene()

   draw_car()
end

----------------------
-- UTILITY functions --
----------------------

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

function merge(t1,t2)
   for k,v in pairs(t2) do t1[k] = v end
   return t1
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
0000000000aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aacaca00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000aacaca00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000a9aaaa000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000aa99aa00007999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000566665000aa889a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000575665750007999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000500005000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000009aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000099999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000955995590000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00033300000000000000000011555511111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000003333330000011555511111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000033333733000011155770077007710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000033733333300011155770077007710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000333333333300011155007700770010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333330000373337373000011155007700770010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333333000333733333000011155770077007710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03344433000044455440000011155770077007710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000011155111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000011155111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000011155111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000011155131111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000013155131111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04444440000000000000000013155331111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04444440000000000000000011353311111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000011333311111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
