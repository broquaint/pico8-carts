pico-8 cartridge // http://www.pico-8.com
version 30
__lua__

delays = {}
function delay(f, n)
   local started = t()
   local co
   co = cocreate(function()
         while (t() - started) < n do
            yield()
         end
      
         f()
         for idx, v in pairs(delays) do
            if v == co then
               deli(delays, idx)
               break
            end
         end
   end)
   add(delays, co)
end

flashes = {}
-- Momentary display
function flash(f, n)
   local started = t()
   local co
   co = cocreate(function()
         while (t() - started) < n do
            f()
            yield()
         end

         for idx, v in pairs(flashes) do
            if v == co then
               deli(flashes, idx)
               break
            end
         end
   end)
   add(flashes, co)
end

function run_coroutines()
   for co in all(delays) do
      coresume(co)
   end
   for co in all(flashes) do
      coresume(co)
   end
end

function _update()
end

function _draw()
   cls()
   print('testing testing 1 2 3', 0, 0, 7)
   run_coroutines()
end

function _init()
   delay(
      function()
         print('flashing for 3 ...', 0, 20, 11)
         flash(
            function()
               print('hi o/', 0, 40, 13)
            end,
            3
         )
      end,
      2
   )
end

-- Glyphs when using glyph in the PICO-8 editor.
-- …∧░➡️⧗▤⬆️☉🅾️◆
-- █★⬇️✽●♥웃⌂⬅️:"
-- ▥❎🐱ˇ▒♪😐<>?   


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
