-- entities

sprites={
    player={
        still=1,
        walk={
            ver_1=3,
            ver_2=5,
            hor_1=7,
            hor_2=9,
            hor_3=11
        },
        pull=13,
        inventory={
            base=48,
            ["paper"]=49,
            ["plant"]=50,
            ["empty bucket"]=51,
            ["water bucket"]=52,
            ["hammer"]=53,
            ["backyard key"]=54,
            ["bedroom key"]=55
        }
    },
    chair=64,
    interact=32,
    safe={
        closed=96,
        open=98
    }
}

flags={
    solid=0,
    barrier=7
}

-- the player and camera logic are taken and adapted from the advanced micro platformer - starting kit by @matthughson
-- it can be found here: https://www.lexaloffle.com/bbs/?tid=28793

function make_player(s_x,s_y)
-- creates a new player character
    local p={
        x=s_x,
        y=s_y,
        dx=0, -- speed on x axis
        dy=0, -- speed on y axis
        acc=0.05,
        max_dx=1,
        max_dy=1,

        w=16, -- width
        h=24, -- height

        interact_range=2, -- how close to be to interact
        nearby_interactable=nil, -- object player can interact with right now
        interacting=false, -- is the player interacting with anything?

        timeshift=false,

        safecracking=false,

        inventory={"paper","plant","empty bucket","water bucket","backyard key"},

        unlocked_rooms={},

        anims={
            -- frames indicates how long each sprite is shown
            -- sprites indicates which sprites are shown
            ["still"]={
                frames=60,
                sprites={sprites.player.still}
            },
            ["walk_ver"]={
                frames=15,
                sprites={sprites.player.walk.ver_1,sprites.player.walk.ver_2}
            },
            ["walk_hor"]={
                frames=15,
                sprites={sprites.player.walk.hor_1,sprites.player.walk.hor_2,sprites.player.walk.hor_1,sprites.player.walk.hor_3}
            },
            ["pull"]={
                frames=60,
                sprites={sprites.player.pull}
            }
        },

        -- animation variables
        curranim="still", -- start off standing still
        currsprite=1, -- at the first sprite
        anim_timer=1, -- amount of frames that must pass until the next sprite
        flipx=false, -- should the sprite be flipped?

        --request new animation to play.
        set_anim=function(self, anim)
            if anim==self.curranim then return end -- exit if we don't need to change the animation
            local a=self.anims[anim]
            self.anim_timer=a.frames
            self.curranim=anim
            self.currsprite=1
        end,

        -- call once per frame
        update=function(self)
            self.timeshift=self.x>60*8
            self:check_objects(objects)
            if not dialogue.active and not self.safecracking then
                self:input()
            else
                self.dx=0
                self.dy=0
            end
            self:handle_horizontal_movement()
            self:handle_vertical_movement()
            self:handle_animations()
        end,

        input=function(self)
            if btn(⬅️) then
                if self.dx>0 then self.dx=0 end
                self.dx-=self.acc
                if not self.interacting then self.flipx=true end
            elseif btn(➡️) then
                if self.dx<0 then self.dx=0 end
                self.dx+=self.acc
                if not self.interacting then self.flipx=false end
            else
                self.dx=0
            end
            self.dx=mid(-self.max_dx,self.dx,self.max_dx) -- limit horizontal speed

            if btn(⬆️) then
                if self.dy>0 then self.dy=0 end
                self.dy-=self.acc
            elseif btn(⬇️) then
                if self.dy<0 then self.dy=0 end
                self.dy+=self.acc
            else
                self.dy=0
            end
            self.dy=mid(-self.max_dy,self.dy,self.max_dy) -- limit vertical speed

            if btnp(🅾️) then
                if self.nearby_interactable and not self.interacting then
                    self.nearby_interactable.interacting=true
                    self.interacting=true
                    self.nearby_interactable:interact()
                elseif self.interacting then
                    self.interacting=false
                    for obj in all(objects) do
                        if obj.interacting then
                            obj.interacting=false
                        end
                    end
                end
            end

            -- normalize diagonal speed
            if self.dx!=0 and self.dy!=0 then
                local norm=sqrt(self.dx^2+self.dy^2)
                self.dx=self.dx/norm
                self.dy=self.dy/norm
            end
        end,

        check_objects=function(self)
            self.nearby_interactable=nil
            for obj in all(objects) do
                if obj.interactable then
                    -- player's bottom 16x8 pixel area bounds
                    local p_left=self.x-8
                    local p_right=self.x+8
                    local p_top=self.y+2
                    local p_bottom=self.y+10
                    
                    -- object bounds
                    local obj_left=obj.x-(obj.w/2)
                    local obj_right=obj.x+(obj.w/2)
                    local obj_top=obj.y-(obj.h/2)
                    local obj_bottom=obj.y+(obj.h/2)
                    
                    -- check if player's bottom area is within interact_range of any side of the object
                    local h_overlap=p_right>=obj_left-self.interact_range and p_left<=obj_right+self.interact_range
                    local v_overlap=p_bottom>=obj_top-self.interact_range and p_top<=obj_bottom+self.interact_range
                    
                    if h_overlap and v_overlap then
                        self.nearby_interactable=obj
                        break
                    end
                end
            end
        end,

        handle_horizontal_movement=function(self)
            self.x+=self.dx
            local col,dir=self:check_solid_horizontal()
            if col then
                self.dx=0
                local offset=6
                if dir==1 then -- right
                    self.x=flr((self.x+offset)/8)*8-offset
                else -- left
                    self.x=ceil((self.x-offset)/8)*8+offset
                end
            end
        end,

        handle_vertical_movement=function(self)
            self.y+=self.dy
            local col,dir=self:check_solid_vertical()
            if col then
                self.dy=0
                local offset=2
                local y_base=self.y+10
                if dir==1 then -- down
                    self.y=flr((y_base+offset)/8)*8-offset-10.1
                else -- up
                    self.y=ceil((y_base-offset)/8)*8+offset-10
                end
            end
        end,

        check_solid_horizontal=function(self)
            local offset=6
            local y_base=self.y+10
            for i=-2,2,2 do -- only check bottom 4 pixels vertically
                if self.dx>0 and (fget(mget((self.x+(offset))/8,(y_base+i)/8),flags.solid) or fget(mget((self.x+(offset))/8,(y_base+i)/8),flags.barrier)) then return true,1
                elseif self.dx<0 and (fget(mget((self.x-(offset))/8,(y_base+i)/8),flags.solid) or fget(mget((self.x-(offset))/8,(y_base+i)/8),flags.barrier)) then return true,-1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        check_solid_vertical=function(self)
            local offset=2
            local y_base=self.y+10
            for i=-(self.w/3),(self.w/3),2 do
                if self.dy<0 and (fget(mget((self.x+i)/8,(y_base-(offset))/8),flags.solid) or fget(mget((self.x+i)/8,(y_base-(offset))/8),flags.barrier)) then return true,-1
                elseif self.dy>=0 and (fget(mget((self.x+i)/8,(y_base+(offset))/8),flags.solid) or fget(mget((self.x+i)/8,(y_base+(offset))/8),flags.barrier)) then return true,1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        get_item=function(self, item)
            add(self.inventory,item)
        end,

        handle_animations=function(self)
            if self.interacting then
                self:set_anim("pull")
            else
                if self.dx!=0 then
                    self:set_anim("walk_hor")
                elseif self.dy!=0 then
                    self:set_anim("walk_ver")
                else
                    self:set_anim("still")
                end
            end

            -- animation timer
            self.anim_timer-=1
            if self.anim_timer<=0 then
                self.currsprite+=1
                local a=self.anims[self.curranim]
                self.anim_timer=a.frames
                if self.currsprite>#a.sprites then self.currsprite=1 end -- loop
            end
        end,

        draw=function(self)
            local a=self.anims[self.curranim]
            local sprite_tl=a.sprites[self.currsprite]
            local sprite_tr=sprite_tl+1
            local sprite_ml=sprite_tl+16
            local sprite_mr=sprite_ml+1
            local sprite_bl=sprite_ml+16
            local sprite_br=sprite_bl+1
            
            if self.dy<0 then pal(7,15) else pal(7,1) end -- this removes the eyes if the player is moving up to not make a new sprite from the back
            
            -- draw 3x2 sprite grid
            local x_base=self.x-(self.w/2)
            local y_base=self.y-(self.h/2)

            spr(self.flipx and sprite_tr or sprite_tl, x_base, y_base, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_tl or sprite_tr, x_base+8, y_base, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_mr or sprite_ml, x_base, y_base+8, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_ml or sprite_mr, x_base+8, y_base+8, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_br or sprite_bl, x_base, y_base+16, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_bl or sprite_br, x_base+8, y_base+16, 1, 1, self.flipx, false)
            
            pal()

        if self.nearby_interactable and not self.interacting then
                spr(sprites.interact,self.x-4,self.y-self.h/2-10)
            end
        end,

        draw_hud=function(self)
            -- draw inventory
            local start_x=128-12 -- right side of screen with small margin (128-8-4)
            local start_y=8 -- 8 pixels from top
            local slot_size=10 -- spacing between slots

            pal(2,0)
            
            for i=1,#self.inventory do
                local item=self.inventory[i]
                local y_pos=start_y+(i-1)*slot_size
                
                spr(sprites.player.inventory.base,start_x,y_pos) -- draw base inventory slot
                if item then spr(sprites.player.inventory[item],start_x,y_pos) end -- draw item sprite on top
            end

            pal()
        end
    }
    return p
end

function make_chair(s_x, s_y)
-- creates a chair object
    local c={
        x=s_x,
        y=s_y,
        dx=0,
        dy=0,

        w=16, -- width
        h=16, -- height

        snap_tile_x=6,
        snap_tile_y=26,

        interactable=true,
        interacting=false,

        dead=false,

        interact=function(self)
            if self.x==self.snap_tile_x*8+4 and self.y==self.snap_tile_y*8+4 then
                if not (player.x==self.snap_tile_x*8+4 and player.y==self.snap_tile_y*8-4) then
                    player.x=self.snap_tile_x*8+4
                    player.y=self.snap_tile_y*8-4
                    player.interacting=false
                else
                    player:get_item("bedroom key")
                    self.interactable=false
                    self.interacting=false
                    player.interacting=false
                end
            end
        end,

        update=function(self)
            if self.interacting then
                if not (self.x==self.snap_tile_x*8+4 and self.y==self.snap_tile_y*8+4) then
                    self.dx=player.dx
                    self.dy=player.dy
                    self:handle_horizontal_movement()
                    self:handle_vertical_movement()

                    -- snap player to side of chair based on their position
                    if player.x < self.x then
                        -- player is on the left
                        player.x=self.x-8
                        player.flipx=false
                    elseif player.x > self.x then
                        -- player is on the right
                        player.x=self.x+8
                        player.flipx=true
                    end
                    player.y=self.y-4
                    
                    -- check if chair bottom touches the snap position
                    local chair_bottom_tile_x=flr(self.x/8)
                    local chair_bottom_tile_y=flr((self.y+4)/8)
                    
                    if chair_bottom_tile_x==self.snap_tile_x and chair_bottom_tile_y==self.snap_tile_y then
                        -- snap chair to exact position
                        self.x=self.snap_tile_x*8+4
                        self.y=self.snap_tile_y*8+4
                        -- stop interaction
                        self.interacting=false
                        player.interacting=false
                    end
                else
                    player.x=self.snap_tile_x*8+4
                    player.y=self.snap_tile_y*8-4
                    player.dx=0
                    player.dy=0
                    player:set_anim("still")
                end
            else
                self.dx=0
                self.dy=0
            end
        end,

        handle_horizontal_movement=function(self)
            self.x+=self.dx

            local col,dir=self:check_solid_horizontal()
            local offset=self.w/2
            if col then
                self.dx=0
                player.dx=0
                if dir==1 then -- right
                    self.x=flr((self.x+(offset))/8)*8-(offset)
                else -- left
                    self.x=ceil((self.x-(offset))/8)*8+(offset)
                end
            end
        end,

        handle_vertical_movement=function(self)
            self.y+=self.dy

            local col,dir=self:check_solid_vertical()
            local offset=self.h/2
            if col then
                self.dy=0
                player.dy=0
                if dir==1 then -- down
                    self.y=flr((self.y+(offset))/8)*8-(offset)
                else -- up
                    self.y=ceil((self.y-(offset))/8)*8+(offset)
                end
            end
        end,

        check_solid_vertical=function(self)
            local offset=self.h/2
            for i=-(self.w/3),(self.w/3),2 do
                if self.dy<0 and (fget(mget((self.x+i)/8,(self.y-(offset))/8),flags.solid) or fget(mget((self.x+i)/8,(self.y-(offset))/8),flags.barrier)) then return true,-1
                elseif self.dy>=0 and (fget(mget((self.x+i)/8,(self.y+(offset))/8),flags.solid) or fget(mget((self.x+i)/8,(self.y+(offset))/8),flags.barrier)) then return true,1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        check_solid_horizontal=function(self)
            if self.x<=7 then return true end
            local offset=self.w/2
            for i=-(self.w/3),(self.w/3),2 do
                if self.dx>0 and (fget(mget((self.x+(offset))/8,(self.y+i)/8),flags.solid) or fget(mget((self.x+(offset))/8,(self.y+i)/8),flags.barrier)) then return true,1
                elseif self.dx<0 and (fget(mget((self.x-(offset))/8,(self.y+i)/8),flags.solid) or fget(mget((self.x-(offset))/8,(self.y+i)/8),flags.barrier)) then return true,-1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        draw=function(self)
            local x_base=self.x-(self.w/2)
            local y_base=self.y-(self.h/2)
            pal(3,0)
            local sprite_tl=sprites.chair
            local sprite_tr=sprite_tl+1
            local sprite_ml=sprite_tl+16
            local sprite_mr=sprite_ml+1
            spr(sprite_tl, x_base, y_base, 1, 1, false, false)
            spr(sprite_tr, x_base+8, y_base, 1, 1, false, false)
            spr(sprite_ml, x_base, y_base+8, 1, 1, false, false)
            spr(sprite_mr, x_base+8, y_base+8, 1, 1, false, false)
            pal()
        end,
    }
    return c
end

function make_clock(s_x, s_y)
-- creates a clock object and its mirror
    local function make_base_clock(b_x, b_y, offset)
        local c={
            x=b_x,
            y=b_y,
            w=16, -- width
            h=16, -- height
            interactable=true,
            interacting=false,
            dead=false,
            interact=function(self)
                start_fade()
                player.x+=offset
                player.interacting=false
                cam=make_camera(player)
            end,
            update=function(self)
            end,
            draw=function(self)
            end,
        }
        return c
    end
    local c1=make_base_clock(s_x,s_y,61*8)
    local c2=make_base_clock(s_x+61*8,s_y,-61*8)
    return c1,c2
end

function make_talkative(s_x, s_y, dialogue)
-- creates an object with just dialogue

    local t={
        x=s_x,
        y=s_y,

        w=8, -- width
        h=8, -- height

        interactable=true,
        interacting=false,

        dead=false,

        interact=function(self)
            if not dialogue.active then
                spawn_dialogue(player.x,player.y-16,dialogue)
                player.interacting=false
                self.interacting=false
            end
        end,

        update=function(self) end,

        draw=function(self) end,
    }

    return t
end

function make_safe(s_x, s_y)
-- creates a safe requiring a combination 
    local s={
        x=s_x,
        y=s_y,

        w=16, -- width
        h=16, -- height

        interactable=true,
        interacting=false,

        open=false,

        dead=false,

        -- safecracking system by claude
        code={0,0,0,0}, -- the 4 digits the player is entering
        current_digit=1, -- which digit is selected (1-4)
        correct_code={1,4,5,1}, -- the correct combination
        input_delay=0, -- delay before accepting input

        interact=function(self)
            if not self.open then
                if player.safecracking then
                    player.interacting=false
                    self.interacting=false
                elseif not dialogue.active then
                    spawn_dialogue(player.x,player.y-16,{"There's a note here, it reads:","'Password: My little angel's age and height'"})
                    player.interacting=false
                    self.interacting=false
                    player.safecracking=true
                    self.input_delay=5
                end
            else
                player:get_item("hammer")
                player.interacting=false
                self.interacting=false
                self.interactable=false
            end
        end,

        update=function(self)
            if player.safecracking then

                player.dx=0
                player.dy=0
                player.x=self.x
                player.y=self.y+8
                player.set_anim("still")

                if not dialogue.active then

                    -- countdown input delay
                    if self.input_delay > 0 then
                        self.input_delay -= 1
                        return
                    end

                    -- handle input for safe cracking
                    if btnp(⬅️) then
                        self.current_digit=max(1,self.current_digit-1)
                    elseif btnp(➡️) then
                        self.current_digit=min(4,self.current_digit+1)
                    elseif btnp(⬆️) then
                        self.code[self.current_digit]=(self.code[self.current_digit]+1)%10
                    elseif btnp(⬇️) then
                        self.code[self.current_digit]=(self.code[self.current_digit]-1+10)%10
                    elseif btnp(🅾️) then
                        -- check if code is correct
                        local correct=true
                        for i=1,4 do
                            if self.code[i]!=self.correct_code[i] then
                                correct=false
                                break
                            end
                        end
                        
                        if correct then
                            self.open=true
                        else
                        end
                        
                        player.safecracking=false
                        player.interacting=false
                        self.interacting=false
                    end
                end
            end
        end,

        draw=function(self)
            if not self.interactable then pal(8,5) end

            local x_base=self.x-(self.w/2)
            local y_base=self.y-(self.h/2)
            local sprite_tl=self.open and sprites.safe.open or sprites.safe.closed
            local sprite_tr=sprite_tl+1
            local sprite_ml=sprite_tl+16
            local sprite_mr=sprite_ml+1
            spr(sprite_tl, x_base, y_base, 1, 1, false, false)
            spr(sprite_tr, x_base+8, y_base, 1, 1, false, false)
            spr(sprite_ml, x_base, y_base+8, 1, 1, false, false)
            spr(sprite_mr, x_base+8, y_base+8, 1, 1, false, false)

            pal()

            -- draw code input interface if safecracking
            if player.safecracking then
                local cell_size=12
                local spacing=2
                local total_width=(cell_size*4)+(spacing*3)
                local total_height=cell_size
                
                -- position above the safe (similar to dialogue positioning)
                local box_x=player.x-(total_width/2)
                local box_y=player.y-16-total_height
                
                for i=1,4 do
                    local x=box_x+((i-1)*(cell_size+spacing))
                    
                    -- draw cell background
                    rectfill(x,box_y,x+cell_size-1,box_y+cell_size-1,0)
                    
                    -- draw cell border (white for unselected, blue for selected)
                    local border_col=7
                    if i==self.current_digit then
                        border_col=12 -- light blue
                    end
                    rect(x,box_y,x+cell_size-1,box_y+cell_size-1,border_col)
                    
                    -- draw the number centered in the cell
                    local num_str=tostr(self.code[i])
                    local text_x=x+4
                    local text_y=box_y+3
                    print(num_str,text_x,text_y,7)
                end
            end
        end,
    }

    return s
end

function make_camera(target)
-- creates a new camera
    local c=
    {
        tar=target,--target to follow.
        pos={x=target.x,y=target.y},
       
        --how far from center of screen target must
        --be before camera starts following.
        --allows for movement in center without camera
        --constantly moving.
        pull_threshold=16,

        --min and max positions of camera.
        --the edges of the level.
        pos_min={x=1,y=1},
        pos_max={x=128*8,y=64*8},
       
        shake_remaining=0,
        shake_force=0,

        update=function(self)

            self.shake_remaining=max(0,self.shake_remaining-1)
           
            --follow target outside of
            --pull range.
            if self:pull_max_x()<self.tar.x then
                self.pos.x+=min(self.tar.x-self:pull_max_x(),4)
            end
            if self:pull_min_x()>self.tar.x then
                self.pos.x+=min((self.tar.x-self:pull_min_x()),4)
            end
            if self:pull_max_y()<self.tar.y then
                self.pos.y+=min(self.tar.y-self:pull_max_y(),4)
            end
            if self:pull_min_y()>self.tar.y then
                self.pos.y+=min((self.tar.y-self:pull_min_y()),4)
            end

            --lock to edge
            if(self.pos.x<self.pos_min.x)self.pos.x=self.pos_min.x
            if(self.pos.x>self.pos_max.x)self.pos.x=self.pos_max.x
            if(self.pos.y<self.pos_min.y)self.pos.y=self.pos_min.y
            if(self.pos.y>self.pos_max.y)self.pos.y=self.pos_max.y
        end,

        cam_pos=function(self)
            return self.pos.x-64,self.pos.y-64
        end,

        pull_max_x=function(self)
            return self.pos.x+self.pull_threshold
        end,

        pull_min_x=function(self)
            return self.pos.x-self.pull_threshold
        end,

        pull_max_y=function(self)
            return self.pos.y+self.pull_threshold
        end,

        pull_min_y=function(self)
            return self.pos.y-self.pull_threshold
        end,
    }

    return c
end