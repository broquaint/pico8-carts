----------------------
-- ANIMATION functions --
----------------------

function wait(n)
   for _ = 1,n do yield() end
end

function delay(f, n)
   animate(function() wait(n) f() end)
end

function animate(f)
   animate_object_with({}, f)
end

function animate_object_with(obj, animation)
   obj.co = cocreate(function()
         obj.animating = true
         animation(obj)
         obj.animating = false
         if(obj.cb) obj.cb(obj)
   end)
   coresume(obj.co)
   add(anims, obj)
end

function run_animations()
   for obj in all(anims) do
      if costatus(obj.co) != 'dead' then
         local active, ex = coresume(obj.co)
         if(ex) dump('ERROR coroutine failed: ', ex)
      else
         del(anims, obj)
      end
   end
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

-- function animate_move(obj)
--    for f = 1, obj.frames do
--       -- if(obj.crashed or obj.collected) return
--       obj.y = lerp(obj.from, obj.to, easein(f/obj.frames))
--       yield()
--    end
-- end
