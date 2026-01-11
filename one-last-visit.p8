pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- oNE lAST vISIT
-- bY: MOOFYS, eLHOMBRELLAVE, mAKU

-->8
-- main

-- gameplay
function make_pantry()
    local left=41
    local right=55
    local top=0
    local wall_start=10
    local bottom=15

    mset(left,top,58)
    for y=top+1,wall_start-1 do mset(left,y,57) end
    mset(left,wall_start,62)

    for x=left+1,left+2 do
        for y=wall_start,wall_start+5 do mset(x,y,68) end
    end

    for x=left+1,right-1 do
        mset(x,top,59)
        for y=top+1,top+3 do mset(x,y,31) end
        for y=top+4,top+5 do mset(x,y,70) end
        for y=top+5,wall_start-1 do mset(x,y,68) end
    end

    mset(right-2,wall_start,56)
    mset(right-1,wall_start,59)

    mset(right,top,60)
    for y=top+1,wall_start-1 do mset(right,y,57) end
    mset(right,wall_start,62)

    local backyard_key=make_giver(47*8,7*8,"backyard key")
    add(objects,backyard_key)

    pantry_blockade.dead=true

end



-- visuals

-- message system from my old game wumpus world, by claude

messages={}

function add_message(text)
-- adds a new message to the notification system
	add(messages, {
		text = text,
		time = 150 -- 5 seconds at 30fps = 150 frames
	})
end

function update_messages()
-- updates message timers and removes expired ones
	for i = #messages, 1, -1 do
		messages[i].time -= 1
		if messages[i].time <= 0 then
			deli(messages, i)
		end
	end
end

function draw_messages()
	-- draws all active messages stacked from bottom-left upwards
	local y = 126 -- start near bottom

	for i = #messages, 1, -1 do
		local msg = messages[i]
		local txt = msg.text
		local txt_width = #txt * 4 + 4
		local x = 2 -- left-aligned

		-- background box
		rectfill(x, y - 8, x + txt_width, y, 0)

		-- text
		print(txt, x + 2, y - 6, 7)

		-- move up for next message
		y -= 10
	end
end

-- dialogue system by claude

dialogue={
    active=false,
    x=0,
    y=0,
    texts={}, -- table of dialogue strings
    current_idx=1, -- which dialogue we're on
    text="",
    lines={},
    width=0,
    height=0,
    char_idx=0,
    char_timer=0,
    char_speed=1, -- frames per char (lower=faster)
    max_width=75, -- max box width in pixels
    padding=4,
    border=1,
    input_delay=0 -- add this new field
}

function swap_case(text)
    local result=""
    for i=1,#text do
        local c=sub(text,i,i)
        local byte=ord(c)
        -- uppercase (65-90) -> lowercase (97-122)
        if byte>=65 and byte<=90 then
            result=result..chr(byte+32)
        -- lowercase (97-122) -> uppercase (65-90)
        elseif byte>=97 and byte<=122 then
            result=result..chr(byte-32)
        else
            result=result..c
        end
    end
    return result
end

function spawn_dialogue(x,y,texts)
    dialogue.active=true
    dialogue.x=x
    dialogue.y=y
    -- handle single string or table
    if type(texts)=="string" then
        dialogue.texts={swap_case(texts)}
    else
        local swapped={}
        for t in all(texts) do
            add(swapped,swap_case(t))
        end
        dialogue.texts=swapped
    end
    dialogue.current_idx=1
    dialogue.char_idx=0
    dialogue.char_timer=0
    dialogue.input_delay=5 -- add a 5 frame delay before accepting input
    load_current_dialogue()
end

function load_current_dialogue()
    dialogue.text=dialogue.texts[dialogue.current_idx]
    dialogue.char_idx=0
    dialogue.char_timer=0
    -- pre-calculate word wrapping without hyphenation
    local all_lines=wrap_text_no_hyphen(dialogue.text,dialogue.max_width)
    
    -- if more than 3 lines, split into multiple dialogues
    if #all_lines > 3 then
        -- take first 3 lines for current dialogue
        dialogue.lines={}
        for i=1,3 do
            add(dialogue.lines,all_lines[i])
        end
        
        -- reconstruct remaining text from remaining lines
        local remaining_text=""
        for i=4,#all_lines do
            if remaining_text!="" then
                remaining_text=remaining_text.." "
            end
            remaining_text=remaining_text..all_lines[i]
        end
        
        -- insert remaining text as next dialogue
        local new_texts={}
        for i=1,dialogue.current_idx do
            add(new_texts,dialogue.texts[i])
        end
        add(new_texts,remaining_text)
        for i=dialogue.current_idx+1,#dialogue.texts do
            add(new_texts,dialogue.texts[i])
        end
        dialogue.texts=new_texts
    else
        dialogue.lines=all_lines
    end
    
    -- calculate box dimensions
    dialogue.width=get_max_line_width(dialogue.lines)
    dialogue.height=#dialogue.lines*6
end

function wrap_text_no_hyphen(text,max_w)
    local lines={}
    local words=split_words(text)
    local line=""
    local line_w=0
    
    for word in all(words) do
        local word_w=#word*4
        
        if line=="" then
            -- first word on line, always add it
            line=word
            line_w=word_w
        elseif line_w+4+word_w<=max_w then
            -- word fits on current line with space
            line=line.." "..word
            line_w=line_w+4+word_w
        else
            -- word doesn't fit, start new line
            add(lines,line)
            line=word
            line_w=word_w
        end
    end
    
    -- add last line
    if line!="" then
        add(lines,line)
    end
    return lines
end

function split_words(text)
    local words={}
    local word=""
    for i=1,#text do
        local c=sub(text,i,i)
        if c==" " then
            if word!="" then
                add(words,word)
                word=""
            end
        else
            word=word..c
        end
    end
    if word!="" then
        add(words,word)
    end
    return words
end

function get_max_line_width(lines)
    local max_w=0
    for line in all(lines) do
        local w=#line*4
        if w>max_w then
            max_w=w
        end
    end
    return max_w
end

function is_dialogue_finished()
    -- count total chars in current dialogue
    local total_chars=0
    for line in all(dialogue.lines) do
        total_chars+=#line
    end
    return dialogue.char_idx>=total_chars
end

function update_dialogue()
    if not dialogue.active then return end
    
    -- countdown input delay
    if dialogue.input_delay > 0 then
        dialogue.input_delay -= 1
        -- still update character animation during delay
        local total_chars=0
        for line in all(dialogue.lines) do
            total_chars+=#line
        end
        if dialogue.char_idx<total_chars then
            dialogue.char_timer+=1
            if dialogue.char_timer>=dialogue.char_speed then
                dialogue.char_timer=0
                dialogue.char_idx+=1
            end
        end
        return -- don't process button input yet
    end
    
    -- count total chars in all lines
    local total_chars=0
    for line in all(dialogue.lines) do
        total_chars+=#line
    end
    -- animate character appearance
    if dialogue.char_idx<total_chars then
        dialogue.char_timer+=1
        if dialogue.char_timer>=dialogue.char_speed then
            dialogue.char_timer=0
            dialogue.char_idx+=1
        end
    end
    -- handle z button press
    if btnp(🅾️) then -- z button
        if is_dialogue_finished() then
            -- move to next dialogue or close
            if dialogue.current_idx<#dialogue.texts then
                dialogue.current_idx+=1
                dialogue.input_delay=5 -- reset delay for next dialogue
                load_current_dialogue()
            else
                close_dialogue()
            end
        else
            -- skip to end of current dialogue
            dialogue.char_idx=total_chars
        end
    end
end

function draw_dialogue()
    if not dialogue.active then return end
    local d=dialogue
    local p=d.padding
    local b=d.border
    -- calculate box dimensions first (add space for button icon)
    local bw=d.width+(p*2)+(b*2)+8 -- +8 for button icon space
    local bh=d.height+(p*2)+(b*2)
    -- calculate top-left corner
    -- x is now center, so subtract half width
    -- y is bottom of box, so subtract height
    local bx=d.x-(bw/2)
    local by=d.y-bh
    -- draw border
    rectfill(bx-b,by-b,bx+bw+b,by+bh+b,7)
    -- draw black background
    rectfill(bx,by,bx+bw,by+bh,0)
    -- draw text with character animation
    local chars_drawn=0
    local tx=bx+p
    local ty=by+p
    for line in all(d.lines) do
        local visible_chars=min(#line,d.char_idx-chars_drawn)
        if visible_chars>0 then
            local visible_text=sub(line,1,visible_chars)
            print(visible_text,tx,ty,7)
        end
        chars_drawn+=#line
        ty+=6
        if chars_drawn>=d.char_idx then
            break
        end
    end
    
    -- draw button icon if dialogue is finished
    if is_dialogue_finished() then
        local icon_x=bx+bw-10 -- moved 4px more to the left (was -6)
        local icon_y=by+bh-6
        print("🅾️",icon_x,icon_y,7)
    end
end

function close_dialogue()
    dialogue.active=false
end

-- fade system by claude
function start_fade()
    fade_state = 1
    fade_timer = 0
end

function update_fade()
    if fade_state == 0 then return end
    
    fade_timer += 1
    
    if fade_state == 1 then
        -- fading to white
        if fade_timer >= fade_duration then
            fade_state = 2
            fade_timer = 0
        end
    elseif fade_state == 2 then
        -- stay white
        if fade_timer >= white_duration then
            fade_state = 3
            fade_timer = 0
        end
    elseif fade_state == 3 then
        -- fade back to normal
        if fade_timer >= fade_duration then
            fade_state = 0
            fade_timer = 0
        end
    end
end

function draw_fade()
    if fade_state == 0 then return end
    
    local amt = 0
    
    if fade_state == 1 then
        amt = fade_timer / fade_duration
    elseif fade_state == 2 then
        amt = 1
    elseif fade_state == 3 then
        amt = 1 - (fade_timer / fade_duration)
    end
    
    -- apply white overlay
    if amt > 0 then
        for i=0,15 do
            local c = i
            if amt >= 0.8 then c = 7
            elseif amt >= 0.6 then c = min(c+2,7)
            elseif amt >= 0.4 then c = min(c+1,7)
            elseif amt >= 0.2 then 
                if c < 6 then c = min(c+1,7) end
            end
            pal(i,c)
        end
    end
end

function draw_base_map(timeshift)
    pal(15,0)
    local x0=timeshift and 61 or 0
    local x1=timeshift and 120 or 59
    local y0=0
    local y1=31
    
    for x=x0,x1 do
        for y=y0,y1 do
            local tile=mget(x,y)
            spr(tile,x*8,y*8)
        end
    end

    pal()
end

function draw_map_over(timeshift)
    pal(15,0)
    local x0=timeshift and 61 or 0
    local x1=timeshift and 120 or 59
    local y0=0
    local y1=31

    for x=x0,x1 do
        for y=y0,y1 do
            local tile=mget(x,y)
            if fget(tile,1) then spr(tile,x*8,y*8) end
        end
    end
    pal()
end



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
            ["bedroom key"]=55,
            ["moofys' Wumpus (easter egg)"]=177,
            ["Elhombrellave's key (easter egg)"]=176,
            ["Maku's musical note (easter egg)"]=178
        }
    },
    chair=64,
    interact=32,
    safe={
        closed=96,
        open=99
    }
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

        first_timeshift=true,

        second_timeshift=false,

        entered_backyard=false,

        can_win=false,

        pantry_seen=false,

        inventory={},

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
            if not self.timeshift then
                if self.x>60*8 then
                    self.timeshift=true
                    music(1)
                end
            else
                if self.x<60*8 then
                    self.timeshift=false
                    music(2)
                end
            end
            self:check_objects(objects)
            if not dialogue.active and not self.safecracking then
                self:input()
            else
                self.dx=0
                self.dy=0
            end
            self:handle_horizontal_movement()
            self:handle_vertical_movement()
            if flr(self.y/8)==15 and (flr(self.x/8)==28 or flr(self.x/8)==29) then
                if not self.entered_backyard then
                    spawn_dialogue(player.x,player.y-16,"Hmm, I should probably fix this place up before I leave")
                    self.entered_backyard=true
                elseif not self.can_win and (present_flower_patch.dead and present_seesaw.dead) then
                    spawn_dialogue(player.x,player.y-16,"Everything seems to be much better now, I guess it's time to leave")
                    self.can_win=true
                    for x=24,26 do
                        for y=25,30 do
                            mset(x,y,79)
                        end
                    end
                end
            end

            if self.can_win and (flr(self.y/8)==29 and (flr(self.x/8)==24 or flr(self.x/8)==25 or flr(self.x/8)==26)) then
                win()
            end
            
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
                if self.dx>0 and (fget(mget((self.x+(offset))/8,(y_base+i)/8),0) or fget(mget((self.x+(offset))/8,(y_base+i)/8),7)) then return true,1
                elseif self.dx<0 and (fget(mget((self.x-(offset))/8,(y_base+i)/8),0) or fget(mget((self.x-(offset))/8,(y_base+i)/8),7)) then return true,-1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        check_solid_vertical=function(self)
            local offset=2
            local y_base=self.y+10
            for i=-(self.w/3),(self.w/3),2 do
                if self.dy<0 and (fget(mget((self.x+i)/8,(y_base-(offset))/8),0) or fget(mget((self.x+i)/8,(y_base-(offset))/8),7)) then return true,-1
                elseif self.dy>=0 and (fget(mget((self.x+i)/8,(y_base+(offset))/8),0) or fget(mget((self.x+i)/8,(y_base+(offset))/8),7)) then return true,1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        get_item=function(self, item)
            add(self.inventory,item)
            local text="Got "..item.."!"
            text=swap_case(text)
            add_message(text)
        end,

        has_item=function(self, item)
            for i in all(self.inventory) do
                if i==item then return true end
            end
            return false
        end,

        remove_item=function(self, item)
            del(self.inventory,item)
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
        end,

        draw_exclamation=function(self)
            if self.nearby_interactable and not self.interacting then spr(sprites.interact,self.x-4,self.y-self.h/2-10) end
        end,

        draw_hud=function(self)
            -- draw inventory
            local start_x=128-12 -- right side of screen with small margin (128-8-4)
            local start_y=8 -- 8 pixels from top
            local slot_size=10 -- spacing between slots

            pal(15,0)
            
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

        snap_tile_x=71,
        snap_tile_y=20,

        interactable=true,
        interacting=false,

        dead=false,

        interact=function(self)
            if self.x==self.snap_tile_x*8 and self.y==self.snap_tile_y*8-4 then
                if not (player.x==self.snap_tile_x*8 and player.y==self.snap_tile_y*8-12) then
                    player.x=self.snap_tile_x*8
                    player.y=self.snap_tile_y*8-12
                    player.interacting=false
                else
                    player:get_item("bedroom key")
                    self.interactable=false
                    self.interacting=false
                    player.interacting=false
                    mset(70,15,197)
                    mset(71,15,198)
                    sfx(14)
                end
            end
        end,

        update=function(self)
            if self.interacting then
                if not (self.x==self.snap_tile_x*8 and self.y==self.snap_tile_y*8-4) then
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
                        self.x=self.snap_tile_x*8
                        self.y=self.snap_tile_y*8-4
                        -- stop interaction
                        self.interacting=false
                        player.interacting=false
                        shelf.dead=true
                        sfx(15)
                    end
                else
                    player.x=self.snap_tile_x*8
                    player.y=self.snap_tile_y*8-12
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
                if self.dy<0 and (fget(mget((self.x+i)/8,(self.y-(offset))/8),0) or fget(mget((self.x+i)/8,(self.y-(offset))/8),7)) then return true,-1
                elseif self.dy>=0 and (fget(mget((self.x+i)/8,(self.y+(offset))/8),0) or fget(mget((self.x+i)/8,(self.y+(offset))/8),7)) then return true,1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        check_solid_horizontal=function(self)
            if self.x<=7 then return true end
            local offset=self.w/2
            for i=-(self.w/3),(self.w/3),2 do
                if self.dx>0 and (fget(mget((self.x+(offset))/8,(self.y+i)/8),0) or fget(mget((self.x+(offset))/8,(self.y+i)/8),7)) then return true,1
                elseif self.dx<0 and (fget(mget((self.x-(offset))/8,(self.y+i)/8),0) or fget(mget((self.x-(offset))/8,(self.y+i)/8),7)) then return true,-1 end
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
                if player.first_timeshift then
                    spawn_dialogue(player.x,player.y-16,{"WHOA!","WHAT JUST HAPPENED!?","This looks just like it did back in the day...","Did I just... time-travel...?"})
                    player.first_timeshift=false
                    player.second_timeshift=true
                elseif player.second_timeshift then
                    spawn_dialogue(player.x,player.y-16,{"And now I'm back...?","I mean... I guess I've seen weirder stuff"})
                    player.second_timeshift=false
                else
                    sfx(13)
                end
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

        w=24, -- width
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
                sfx(14)
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
                            sfx(16)
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
            if not self.interactable then
                pal(8,5)
                pal(13,5)
                pal(2,5)
                pal(9,5)
            end

            local x_base=self.x-(self.w/2)
            local y_base=self.y-(self.h/2)
            local sprite_tl=self.open and sprites.safe.open or sprites.safe.closed
            local sprite_tm=sprite_tl+1      -- top middle
            local sprite_tr=sprite_tl+2      -- top right
            local sprite_ml=sprite_tl+16     -- middle left
            local sprite_mm=sprite_ml+1      -- middle middle
            local sprite_mr=sprite_ml+2      -- middle right
            
            -- Draw 3x2 sprite grid (24x16 pixels)
            spr(sprite_tl, x_base, y_base, 1, 1, false, false)
            spr(sprite_tm, x_base+8, y_base, 1, 1, false, false)
            spr(sprite_tr, x_base+16, y_base, 1, 1, false, false)
            spr(sprite_ml, x_base, y_base+8, 1, 1, false, false)
            spr(sprite_mm, x_base+8, y_base+8, 1, 1, false, false)
            spr(sprite_mr, x_base+16, y_base+8, 1, 1, false, false)

            pal()

            -- draw code input interface if safecracking
            if player.safecracking then
                local cell_size=12
                local spacing=2
                local total_width=(cell_size*4)+(spacing*3)
                local total_height=cell_size
                
                local box_x=player.x-(total_width/2)
                local box_y=player.y-16-total_height
                
                for i=1,4 do
                    local x=box_x+((i-1)*(cell_size+spacing))
                    
                    rectfill(x,box_y,x+cell_size-1,box_y+cell_size-1,0)
                    
                    local border_col=7
                    if i==self.current_digit then
                        border_col=12
                    end
                    rect(x,box_y,x+cell_size-1,box_y+cell_size-1,border_col)
                    
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

function make_giver(s_x, s_y, reward)
-- makes an object that gets added to your inventory when interacted with
    local g={
            x=s_x,
            y=s_y,
            w=8, -- width
            h=8, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                player:get_item(reward)
                self.dead=true
                player.interacting=false
                self.interacting=false
                sfx(14)
            end,

            update=function(self)
            end,

            draw=function(self)
                spr(sprites.player.inventory[reward],self.x,self.y,1,1,false,false)
            end,
        }

    return g
end

function make_desk(s_x, s_y)
    local d={
            x=s_x,
            y=s_y,
            w=24, -- width
            h=16, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                if player:has_item("paper") then
                    if player.pantry_seen then
                        spawn_dialogue(player.x,player.y-16,{"Alright, I'll write grandma a reminder to get the construction company to begin work on that pantry earlier","Aaaand...","Done!","I really hope this works..."})
                        make_pantry()
                        player.interacting=false
                        self.interacting=false
                        self.dead=true
                        player:remove_item("paper")
                        sfx(14)
                    else
                        spawn_dialogue(player.x,player.y-16,"I could write something here, but what?")
                        player.interacting=false
                        self.interacting=false
                    end
                else
                    if player.pantry_seen then
                        spawn_dialogue(player.x,player.y-16,"If I had some paper I could write grandma a reminder to get the construction company to begin work on the pantry earlier")
                    else
                        spawn_dialogue(player.x,player.y-16,"If I had some paper I guess I could write something here, but what?")
                    end
                    player.interacting=false
                    self.interacting=false
                end
            end,

            update=function(self)
            end,

            draw=function(self)

            end,
        }

    return d
end

function make_plant(s_x, s_y)
    local p={
            x=s_x,
            y=s_y,
            w=8, -- width
            h=8, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                spawn_dialogue(player.x,player.y-16,{"Hmm, I'm pretty sure this plant blooms into grandma's favorite flower"})
                player:get_item("plant")
                self.dead=true
                player.interacting=false
                self.interacting=false
                sfx(14)
            end,

            update=function(self)
            end,

            draw=function(self)
                spr(sprites.player.inventory.plant,self.x,self.y,1,1,false,false)
            end,
        }

    return p
end

function make_sink(s_x, s_y)
    local s={
            x=s_x,
            y=s_y,
            w=16, -- width
            h=24, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                if player:has_item("empty bucket") then
                    player:remove_item("empty bucket")
                    player:get_item("water bucket")
                    player.interacting=false
                    self.interacting=false
                    past_sink.dead=true
                    present_sink.dead=true
                    sfx(16)
                else
                    spawn_dialogue(player.x,player.y-16,"There's running water here if I ever need it")
                    player.interacting=false
                    self.interacting=false
                end
            end,

            update=function(self)
            end,

            draw=function(self)

            end,
        }

    return s
end

function make_flower_patch(s_x, s_y)
    local fp={
            x=s_x,
            y=s_y,
            w=24, -- width
            h=32, -- height

            interactable=true,
            interacting=false,
            dead=false,

            planted=false,

            interact=function(self)
                if self.planted then
                    if player:has_item("water bucket") then
                        player:remove_item("water bucket")
                        local i=0
                        for x=31,33 do
                            for y=10,13 do
                                mset(x,y,160+i)
                                i+=1
                            end
                        end
                        present_flower_patch.dead=true
                        local new_present_flower_patch=make_talkative(present_flower_patch.x,present_flower_patch.y,"This looks great!")
                        add(objects,new_present_flower_patch)
                        self.dead=true
                        sfx(16)
                        spawn_dialogue(player.x,player.y-16,"All done! Let's hope this looks better in the future")
                    else
                        spawn_dialogue(player.x,player.y-16,"Now I have to water it")
                    end
                else
                    if player:has_item("plant") then
                        player:remove_item("plant")
                        mset(92,12,172)
                        self.planted=true
                        spawn_dialogue(player.x,player.y-16,"Now I have to water it")
                    else
                        spawn_dialogue(player.x,player.y-16,"I'm sure I could plant something here!")
                    end
                end
                self.interacting=false
                player.interacting=false
            end,

            update=function(self)
            end,

            draw=function(self)

            end,
        }
    return fp
end

function make_past_bedroom_door(s_x, s_y)
    local pbd={
            x=s_x,
            y=s_y,
            w=16, -- width
            h=32, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                if player:has_item("bedroom key") then
                    for x=self.x/8,self.x/8+1 do
                        for y=self.y/8-3,self.y/8 do
                            mset(x,y,68)
                        end
                    end
                    player:remove_item("bedroom key")
                    self.dead=true
                    sfx(15)
                else
                    spawn_dialogue(player.x,player.y-16,"Grandma always used to hide the key from me when I was left alone, it has to be near here")
                end
                self.interacting=false
                player.interacting=false
            end,

            update=function(self)
            end,

            draw=function(self)

            end,
        }
    return pbd
end

function make_past_backyard_door(s_x ,s_y)
    local pbd={
            x=s_x,
            y=s_y,
            w=16, -- width
            h=32, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                if player:has_item("backyard key") then
                    for x=self.x/8,self.x/8+1 do
                        for y=self.y/8-3,self.y/8 do
                            mset(x,y,68)
                        end
                    end
                    if present_backyard_door.dead then player:remove_item("backyard key") end
                    self.dead=true
                    sfx(15)
                else
                    spawn_dialogue(player.x,player.y-16,"If I recall correctly I left a copy of this door's key in the old unfinished pantry")
                end
                self.interacting=false
                player.interacting=false
            end,

            update=function(self)
            end,

            draw=function(self)

            end,
        }
    return pbd
end

function make_present_backyard_door(s_x ,s_y)
    local pbd={
            x=s_x,
            y=s_y,
            w=16, -- width
            h=32, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                if player:has_item("backyard key") then
                    for x=self.x/8,self.x/8+1 do
                        for y=self.y/8-3,self.y/8 do
                            mset(x,y,68)
                        end
                    end
                    if past_backyard_door.dead then player:remove_item("backyard key") end
                    self.dead=true
                    sfx(15)
                else
                    spawn_dialogue(player.x,player.y-16,"If I recall correctly I left a copy of this door's key in the old unfinished pantry")
                end
                self.interacting=false
                player.interacting=false
            end,

            update=function(self)
            end,

            draw=function(self)

            end,
        }
    return pbd
end

function make_seesaw(s_x, s_y)
    local s={
            x=s_x,
            y=s_y,
            w=32, -- width
            h=16, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                if player:has_item("hammer") then
                    spawn_dialogue(player.x,player.y-16,"Let's fix it!")
                    mset(20,8,128)
                    mset(21,8,129)
                    mset(22,8,130)
                    mset(23,8,131)
                    mset(20,9,144)
                    mset(21,9,145)
                    mset(22,9,146)
                    mset(23,9,147)
                    self.dead=true
                    player:remove_item("hammer")
                    sfx(14)
                else
                    spawn_dialogue(player.x,player.y-16,"It's broken! I bet I could fix this with a hammer")
                end
                self.interacting=false
                player.interacting=false
            end,

            update=function(self)
            end,

            draw=function(self)

            end,
        }
    return s
end

function make_pantry_blockade(s_x, s_y)
        local s={
            x=s_x,
            y=s_y,
            w=8, -- width
            h=8, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                spawn_dialogue(player.x,player.y-16,{"Wait... There's supposed to be a pantry here!", "It was unfinished, but I was hoping the construction company wouldn't just abandon it...", "They didn't even bother painting the wall the right!"})
                player.pantry_seen=true
                player.interacting=false
                self.interacting=false
            end,

            update=function(self) end,

            draw=function(self) end,
        }
    return s
end

function make_easter_egg(s_x, s_y, reward, visible)
    local e={
            x=s_x,
            y=s_y,
            w=8, -- width
            h=8, -- height

            interactable=true,
            interacting=false,
            dead=false,

            interact=function(self)
                player:get_item(reward)
                self.dead=true
                player.interacting=false
                self.interacting=false
                sfx(14)
            end,

            update=function(self)
            end,

            draw=function(self)
                if visible then spr(sprites.player.inventory[reward],self.x,self.y,1,1,false,false) end
            end,
        }

    return e
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



function _init()
-- runs once at the start
    enter_menu()
end

function _update60()
-- runs at 60fps
    if state=="playing" then update_game()
    elseif state=="menu" then update_menu()
    elseif state=="win" then update_win() end
end

function _draw()
-- runs at 60fps
    if state=="playing" then draw_game()
    elseif state=="menu" then draw_menu()
    elseif state=="win" then draw_win() end
    print()
end

function spawn_player()
    s_x=24*8 -- spawn x position
    s_y=23*8 -- spawn y position
    player=make_player(s_x,s_y)
    cam=make_camera(player)
end

function spawn_objects()
    local chair=make_chair(107*8,21*8-1)
    local clock_1,clock_1_m=make_clock(23*8,21*8)
    local safe=make_safe(75*8+4,6*8)
    local empty_bucket=make_giver(22*8,13*8,"empty bucket")
    shelf=make_talkative(70*8,18*8,"Looks like there's a key on the top shelf, if I could stand on something I might reach it")
    local paper=make_giver(107*8,23*8-4,"paper")
    local desk=make_desk(65*8,18*8)
    local plant=make_plant(65*8,22*8)
    pantry_blockade=make_pantry_blockade(42*8,15*8)
    local past_seesaw=make_talkative(82*8,9*8,"Grandpa and I used to play here all the time, no wonder his hips hurt so much whenever I came over!")
    present_seesaw=make_seesaw(21*8,9*8)
    past_sink=make_sink(109*8,16*8)
    present_sink=make_sink(48*8,16*8)
    local fridge=make_talkative(98*8,16*8,"Full of fresh groceries!")
    wall_marks=make_talkative(96*8,20*8,{"There's a couple markings on the wall, we used to make one each year on my birthday to mark how tall I was getting","Last one says: 14 years old, 5\"1'"})
    local past_bedroom_door=make_past_bedroom_door(74*8,17*8)
    present_backyard_door=make_present_backyard_door(28*8,20*8)
    past_backyard_door=make_past_backyard_door(89*8,20*8)
    present_flower_patch=make_talkative(31*8,12*8,"This looks a bit dead, I bet it would look a lot better with something planted! But it'd take too long to grow...")
    local past_flower_patch=make_flower_patch(92*8,12*8)
    local photo=make_talkative(71*8,6*8,{"It's a photo of grandma and grandpa.","After grandpa passed she started feeling lonely and kept his old tools on that safe over as if they were treasures..."})
    local eg_note=make_easter_egg(66*8,6*8,"Maku's musical note (easter egg)",false)
    local eg_key=make_easter_egg(96*8,27*8,"Elhombrellave's key (easter egg)",false)
    local eg_wumpus=make_easter_egg(9*8,8*8,"moofys' Wumpus (easter egg)",true)
    objects={
        chair,
        clock_1,clock_1_m,
        safe,
        empty_bucket,
        shelf,
        paper,
        plant,
        desk,
        pantry_blockade,
        past_seesaw,present_seesaw,
        past_sink,present_sink,
        fridge,
        wall_marks,
        past_bedroom_door,
        present_backyard_door,past_backyard_door,
        present_flower_patch,past_flower_patch,
        photo,
        eg_key,eg_note,eg_wumpus
    }
end

function init_fade_vars()
    fade_state = 0
    fade_timer = 0
    fade_duration = 30
    white_duration = 15
end

function update_objects()
    for obj in all(objects) do
        if obj.dead then del(objects,obj) end
        obj:update()
    end
end

function start_game()
    spawn_player()
    spawn_objects()
    init_fade_vars()
    spawn_dialogue(player.x,player.y-16,{"So this old place finally got sold, huh","I used to spend lots of time here with grandma... Good times...", "I wanna have a look at the backyard, it was always so peaceful there", "Huh, isn't the time on that clock wrong?"})
    music(2)
    state="playing"
end

function update_game()
    player:update()
    update_objects()
    update_fade()
    cam:update()
    update_dialogue()
    update_messages()
end

function draw_game()
    cls(0)

    camera(cam:cam_pos())

    draw_fade()

    draw_base_map(player.timeshift)

    for obj in all(objects) do
        pal(15,0)
        obj:draw()
        pal()
    end

    player:draw()

    draw_fade()

    draw_map_over(player.timeshift)

    player:draw_exclamation()

    draw_dialogue()

    camera(0,0)

    player:draw_hud()

    draw_messages()
end

function win()
    state="win"
    music(3)
end

function enter_menu()
    state="menu"
    music(3)
end

-- menu and win system by claude

function update_win()
    -- go back to menu
    if btnp(❎) then
        enter_menu()
    end
end

function draw_win()
    cls(0)
    
    -- draw "thanks for playing!" at top middle
    local title="tHANKS FOR PLAYING!"
    local title_w=#title*4
    print(title,64-title_w/2,20,7)
    
    -- draw "game by:" label
    local label="gAME BY:"
    local label_w=#label*4
    print(label,64-label_w/2,40,6)
    
    -- draw credits text centered, starting lower than credits screen
    local credits={
        "pAOLO 'MOOFYS' pORTUGAL",
        "aGUSTIN 'eLHOMBRELLAVE' cABRAL",
        "mANUEL 'mAKU' kARADJIAN",
    }
    
    local start_y=52  -- moved down a bit more to make room for label
    local line_spacing=8
    
    for i=1,#credits do
        local line=credits[i]
        local line_w=#line*4
        local y=start_y+(i-1)*line_spacing
        print(line,64-line_w/2,y,7)
    end
    
    -- draw back instruction at bottom left
    print("❎ to go to main menu",2,115,6)
end

menu={
    state="main", -- "main" or "credits"
    selected=1, -- which button is selected (1=play, 2=credits)
    buttons={"play","credits"}
}
function update_menu()
    if menu.state=="main" then
        -- navigate menu
        if btnp(⬆️) then
            menu.selected=max(1,menu.selected-1)
        elseif btnp(⬇️) then
            menu.selected=min(2,menu.selected+1)
        elseif btnp(🅾️) then
            if menu.selected==1 then
                start_game()
            elseif menu.selected==2 then
                menu.state="credits"
            end
        end
    elseif menu.state=="credits" then
        -- go back from credits
        if btnp(❎) then
            menu.state="main"
        end
    end
end

function draw_menu()
    cls(0)
    
    if menu.state=="main" then
        -- draw title at top middle
        local title="oNE lAST vISIT"
        local title_w=#title*4
        print(title,64-title_w/2,20,7)
        
        -- draw sprites under the title
        local sprite_block_w = 16  -- 2 sprites wide
        local sprite_x = 64 - sprite_block_w/2
        local sprite_y = 28  -- below the title

        spr(194,sprite_x,sprite_y)
        spr(195,sprite_x+8,sprite_y)
        spr(210,sprite_x,sprite_y+8)
        spr(211,sprite_x+8,sprite_y+8)
        spr(226,sprite_x,sprite_y+16)
        spr(227,sprite_x+8,sprite_y+16)
        spr(242,sprite_x,sprite_y+24)
        spr(243,sprite_x+8,sprite_y+24)

        
        -- draw buttons in lower middle (moved up from 80 to 70)
        local button_y=70
        local button_spacing=16
        
        for i=1,#menu.buttons do
            local btn_text=menu.buttons[i]
            local btn_w=#btn_text*4
            local y=button_y+(i-1)*button_spacing
            
            -- draw selection indicator
            if i==menu.selected then
                print(">",64-btn_w/2-8,y,12)
            end
            
            -- draw button text
            local color=i==menu.selected and 7 or 6
            print(btn_text,64-btn_w/2,y,color)
        end
        
        -- draw instructions at bottom left (moved up from 120 to 115)
        print("⬆️⬇️ to navigate",2,115,6)
        print("🅾️ (z) to select",2,121,6)
        
    elseif menu.state=="credits" then
        -- draw "game by:" label
        local label="gAME BY:"
        local label_w=#label*4
        print(label,64-label_w/2,20,6)
        
        -- draw credits text centered, starting from top middle
        local credits={
            "pAOLO 'MOOFYS' pORTUGAL",
            "aGUSTIN 'eLHOMBRELLAVE' cABRAL",
            "mANUEL 'mAKU' kARADJIAN",
        }
        
        local start_y=32  -- moved down slightly to make room for label
        local line_spacing=8
        
        for i=1,#credits do
            local line=credits[i]
            local line_w=#line*4
            local y=start_y+(i-1)*line_spacing
            print(line,64-line_w/2,y,7)
        end
        
        -- draw back instruction at bottom left (moved up from 120 to 115)
        print("❎ to go back",2,115,6)
    end
end

__gfx__
00000000000001111110000000000111111000000000011111100000000001111110000000000111111000000000011111100000000001111110000055555555
00000000000019999991000000001999999100000000199999910000000019999991000000001999999100000000199999910000000019999991000055555555
000000000001999999991000000199999999100000019999999910000001999999991000000199999999100000019999999910000001999999991000dddddddd
000000000019999999999100001999999999910000199999999991000019999999999100001999999999910000199999999991000019999999999100dddddddd
000000000199999999999910019999999999991001999999999999100199999999999910019999999999991001999999999999100199999999999910dddddddd
000000000111111111111110011111111111111001111111111111100111111111111110011111111111111001111111111111100111111111111110dddddddd
00000000199199199191919119919919919191911991991991919191199191999199199119919199919919911991919991991991199191999199199155555555
00000000199199199191919119919919919191911991991991919191199191999199199119919199919919911991919991991991199191999199199155555555
00888800011111111111111001111111111111100111111111111110011111111111111001111111111111100111111111111110011111111111111066666666
08000080001ffffffffff100001ffffffffff100001ffffffffff100001ffffffffff100001ffffffffff100001ffffffffff100001ffffffffff10066666666
80700708001ff7ffff7ff100001ff7ffff7ff100001ff7ffff7ff100001ffffffff7f100001ffffffff7f100001ffffffff7f100001ffffffff7f10066666666
80077008001ff7ffff7ff100001ff7ffff7ff100001ff7ffff7ff100001ffffffff7f100001ffffffff7f100001ffffffff7f100001ffffffff7f10066666666
80077008001ffffffffff100001ffffffffff100001ffffffffff100001ffffffffff100001ffffffffff100001ffffffffff100001ffffffffff10066666666
807007080001ffffffff10000001ffffffff10000001ffffffff10000001ffffffff10000001ffffffff10000001ffffffff10000001ffffffff100066666666
08000080000011ffff110000000011ffff110000000011ffff110000000011ffff110000000011ffff110000000011ffff110000000011ffff11000066666666
00888800000115555551100000011555555110000001555555551000000015555551000000001555555100000000155555510000000015555551000066666666
00011000000155555555100000015555555510000001f555555f1000000015155551000000001515115100000000151555510000000015555551110066666666
001991000001f555555f10000001f555555f10000001f555555f1000000015111551000000001511ff1100000000111555510000000015555155ff1066666666
001991000001f555555f10000001f555555f10000001f555555f10000000151ff151000000001551ff1100000001ff1555510000000015555515ff1066666666
001991000001f444444f10000001f444444f100000001444444100000000141ff141000000001444114100000001ff1414410000000014444441110066666666
00199100000014111141000000001411114100000000141111410000000014411441000000011441144410000000114411441100000014411441000066666666
00011000000014100141000000001210014100000000141001210000000012211221000000122221012221000001222100122210000012211221000066666666
00199100000012100121000000001110012100000000121001110000000012221222100000122111012210000001221100122100000012221222100066666666
00011000000011100111000000000000011100000000111000000000000001110111000000011100001100000000111000011000000001110111000066666666
05555550000010000000010001111110011111100000100000000110000001105555555555dddd5555555555555555555555555555dddd5555dddd5555dddd55
555555550001610000001b101ffffff11cccccc1000161000001166100011aa15555555555dddd5555555555555555555555555555dddd5555dddd5555dddd55
55555555001676100000131011ffff1111cccc110016661000161661001a1aa1dddddddd55dddd5555dddddddddddddddddddd5555dddddddddddd55dddddd55
555555550167776100013310151111511511115100016661010161100101a110dddddddd55dddd5555dddddddddddddddddddd5555dddddddddddd55dddddd55
555555551677761001133110155555511555555100141610161610001a1a1000dddddddd55dddd5555dddddddddddddddddddd5555dddddddddddd55dddddd55
5555555501676100144444410155551001555510014101000161000001a10000dddddddd55dddd5555dddddddddddddddddddd5555dddddddddddd55dddddd55
555555550016100001444410015555100155551014100000161000001a10000055dddd5555dddd5555dddd555555555555dddd55555555555555555555dddd55
055555500001000000111100001111000011110011000000010000000100000055dddd5555dddd5555dddd555555555555dddd55555555555555555555dddd55
003333333333330065666665566666564444444477777777777777773333333366ffffffffffff667ffffffffffffffffffffff744ff444444444444aaaaaaaa
0366666666666630556666655666665544444444777777ee77777777333333336f555555555555f6f444444444444444444444ffff44f44444444444aaaaaaaa
36444444444444636665555555555666444444447777777777777777333333336f666666666665f67f44455554444445555444f7f4444fffffff4444aaaaaaaa
34444444444444436656666666666566444444447777778877777777333333336f666666666665f67f44566665444456666544f7f4444f555555f444aaaaaaaa
34444444444444436656655665566566444444447777777777777777333333336f666666666665f67f45666666555566666654f7f4444f5555555f44aaaaaaaa
34444444444444436656565665656566444444447777777777777777333333336f666666666665f67f56666666655666666665f7f4444f5555555ff4aaaaaaaa
3444444444444443665655655655656644444444777777bb77777777333333336f66f666666665f67f56666666655666666665f7f4444f55555ff4f4aaaaaaaa
03555555555555305556665665666555444444447777777777777777333333336f66f666666665f67f56666666655666666665f7f4444ffffff444f4aaaaaaaa
34444444444444435556665665666555dddddddd777777774ffffffffffffff47f66f666666665f74f55555555555555555555f4f4444f44444444f444444444
34444444444444436656556556556566dddddddd77777777f66666666666666f7f66f666666665f7f5777777777777777777775ff4444f44444444f444444444
34444444444444436656565665656566dddddddd77777777f64444444444446f7f666666666665f7f5777777777777777777775ff4444f44444444f444444444
34433333333334436656655665566566dddddddd77777799f44444444444444f7ffffffffffffff74f55555555555555555555f4f4444f44444444f444444444
34430000000034436656666666666566dddddddd77777777f44444444444444f7f555555555555f74f22222222222222222222f4f4444f44444444f444444444
33330000000033336665555555555666dddddddd77777777f44444444444444f7f666666666665f74f22222222222222222222f4f4444f44444444f444444444
00000000000000005566666556666655dddddddd777777aaf44444444444444f7f66f666666665f74f22222222222222222222f4f4444f44444444f444444444
00000000000000006566666556666656dddddddd77777777f44444444444444f7f66f666666665f74f22222222222222222222f4f4444f44444444f444444444
77777fffffffffffffffffff77777ffffffffffffffffffff44444444444444f7f66f666666665f74f22222222222222222222f4f4444f44444444f40fffffff
77777f76666666666666666f77777f666666f5555555555ff44444444444444f7f66f666666665f74f22222222222222222222f4f4444ffffff444f400f0000f
77777f7666ffffffffffff6f7777f6666666f5555885555ff44444444444444f7f66f666666665f74f22222222222222222222f4f4444f55555ff4f400f0000f
77777f7655f5555555555f6f777f6aa66666f5588888855ff44444444444444f7f66f666666665f74f22222222222222222222f4f4444f5555555ff400f0000f
77777f765aa5555555555f6f777f6aa66666f8888888885ff44444444444444f7f66f666666665f74f22222222222222222222f4f4444f5555555f4400f0000f
77777f765aa55aa555555f6f777f6aa66666f8888822285ff44444444444444f7f66f666666665f74f22222222222222222222f4f4444f555555f4440f0000f0
77777f7655f5aaaa51115f6f7777f6666666f8888222d85ff44444444444444f7f666666666665f7f4444444444444444444444fff44ffffffff4444f1f00f1f
77777f7666f5aaaa51115f6f77777f666666f888222dd85ff44444444444444f7f666666666665f74f46656566565665566664f444ff4444444444440f0000f0
44444f7666f5aaaa51115f6f4444f6666666f8222ddd285ff44444444444444f4f666666666665f44f44444444444444444444f455dddd555555555555555555
44444f7655f5aaaa55555f6f444f6aa66666f22d9d22285ff44444444444444f4f666666666665f44f45555555555555555554f455dddd555555555555555555
44444f765aa5aaaa55555f6f444f6aa66666f2dd2222885ff44444444444444f4f666666666665f44f44455544555544555444f455dddd5555dddddddddddd55
44444f765aa55aa555555f6f444f6aa66666fdd22228855ff44444444444444f4f666666666665f44f44445444455444454444f455dddd5555dddddddddddd55
44444f7655f5555555555f6f4444f6666666f2228888555ff44444444444444f4f666666666665f44f44444444444444444444f455dddd5555dddddddddddd55
44444f7666ffffffffffff6f44444f666666f2888555555ff44444444444444f44ffffffffffff444f44444444444444444444f455dddd5555dddddddddddd55
44444f76666666666666666f44444f666666f8855555555ff44444444444444f444fff4444fff4444f4ffffffffffffffffff4f455dddd5555dddd5555dddd55
44444fffffffffffffffffff44444fffffffffffffffffff4ffffffffffffff4444444444444444444f444444444444444444f4455dddd5555dddd5555dddd55
33333333333333333333333333333333333333333333333333333333333333334ffffffffffffffffffffffffffffff47777fff7777777777777444447777777
333fffff3333333333333333fffff33333333333333333333333333333333333f666666666666666666666666666666f777faaaf7777777777774acc47777777
33f99999f33333333333333f99999f3333333333333333333333333333333333f644444444444444444444444444446f77faaaaaf777777777774ccc47777777
333ff9ff3333333333333333ff9ff33333333333333333333333333333333333f444444444444444444444444444444f77fffffff777777777774bbb47777777
3333f9f33333333ff33333333f9f333333333333333333ff33ff333333333333f444444444444444444444444444444f7777fcf77777777777774bbb47777777
3333f9f33333333ff33333333f9f33333339999933333f88ffaaf33333333333f444444444444444444444444444444f777fcccf777777777777444447777777
3333fffffffffff88fffffffffff333333333933333ffa88aaaf333333333333f444444444444444444444444444444f7ffffffffffffff77ffffffffffffff7
333faaaaaaaaaaf88faaaaaaaaaaf333333339333ffaaaffaff3333333333333f444444444444444444444444444444ff55555555555555ff55555555555555f
3333ffffffffffffffffffffffff3333333339fffaaafffff333333333333333f444444444444444444444444444444ff55555555555555ff55555555555555f
333333333333333ff33333333333333333333ffaaaff33ff3333333333339333f444444444444444444444444444444ff55ffffffffff55ff55ffffffffff55f
333333333333333ff3333333333333333333faaaff3333ff3333333333339333f444444444444444444444444444444ff5f44444a4444f5ff5f44444a4444f5f
33333333333333ffff333333333333333fffaaff33333ffff3333399999393334ffffffffffffffffffffffffffffff4f5f4444a44444f5ff5f4444a44444f5f
3333333333333fccccf33333333333333faaaf333333fccccf33333fffffff3f44444f44f44444444444444f44f44444f55ffffffffff55ff55ffffffffff55f
333333333333fccccccf3333333333333ffff333333fccccccf333faaaaaaaf344444f44f44444444444444f44f44444f55555555555555ff55555555555555f
333333333333ffffffff33333333333333333333333ffffffff3333fffffff3344444f44f44444444444444f44f444444ffffffffffffff44ffffffffffffff4
3333333333333333333333333333333333333333333333333333333333333333444444ff4444444444444444ff44444444444444444444444444444444444444
3e33333333333e333e3333333e333333333333333333333333333333333333333333333333333333333333e33333333344444444555555550000000044444446
33333e333e333333333e33e3333e33e33e3333e33e333e333333333333333e3e333e3e333333333333333e3e33e3333344444444555555550000000046444444
3e33333e33333e333e333333e3333e333ee33333e3e33e33333e3e3333e33ee333e33e3333e3e33333ee3e33333333e344444444dddddddd0000000044444444
333e33333333333333333333333333333333333333333333e33e33333ee333333e3333333e33e33333e33333e333333344bb4444dddddddd0000000044464644
333333333e3333e3333e3e33e33333e333333ee333333333333e333333e3333333e33333333e3e33333333333333333344bb4444dddddddd0000000044444444
33e333e333333333e333333333e333333e33ee3333333e3333333e3e33333e33333333ee33333e3333333333333e333344444444dddddddd0000000044644444
e3333e3333e33333333333e3333e33333e3333333ee33e33e3e33e33333333333ee33e333e333333e3e33333e333333e44444444555555550000000044446446
33333333333e33333333333333333333333333333333333333333333333333333333333333e333333e3333333333333344444444555555550000000044444444
00000ff0099999900fffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044444444
000ff22f9979979900f0000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044464444
00f2f22f9099990900f0000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000046446464
0f0f2ff09097790900f0000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044644444
f2f2f0009009900900f000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044444464
0f2f0000990000990ff00f1f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044446464
f2f0000009000090f1f000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000046444644
0f000000909009090f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044444444
66666666666666660000000000000000000000006ffffffffffffff6ffffffffffffffff77777777777777777ffffffffffffffffffffff7ffffffffffffffff
66666ffffff6666600000ffffff0000000000000f44444444444444ff56556655665565f7777777777777777f4444444444444444444444ff44444444444444f
6666f444444f66660000f444444f000000000000f4ffffffffffff4ff56556655665565f7777777777ff7777f444ffffffffffffffff444ff44444444444444f
666f44444444f666000f44444444f00000000000f4f5555555555f4ff56666666666665f777777777f77f777f44f5555555555555555f44ff44444444444444f
6ff4444444444ff60ff4444444444ff000000000f4f5555555555f4ff55555555555555f777777777f77f777f44f5555555555555555f44ff44444444444444f
f4444ffffff4444ff4444ffffff4444f00000000f4f5555555555f4fffffffffffffffff77777777f7777777f44f5555555555555555f44ff44444444444444f
f444f666666f444ff444f666666f444f00000000f4ffffffffffff4ff666666ff666666f77777777f7777777f444ffffffffffffffff444ff44444444444444f
6fff66555566fff60fff66555566fff000000000f4f4cd4bfd44bf4ff666666ff666666f77777777f7777777f4444444444444444444444ff44444444444444f
77f6655556566f7700f6655556566f0000000000f4f2cdebfd49bf4ff6666f6ff6f6666ffffff88fffccffff4ffffffffffffffffffffff4f44444444444444f
77f6655565566f7700f6655565566f0000000000f4f2cdebfd49bf4ff6666f6ff6f6666f566666555556666544f4444f44a44a44f4444f44f44444444444444f
77f6655655566f7700f6655655566f0000000000f4ffffffffffff4ff666666ff666666f566666655566666544f4444f444aa444f4444f44f44444444444444f
77f6655555566f7700f6655555566f0000000000f4f3448f11222f4ff666666ff666666f566666666666666544f4aa4f44444444f4aa4f44f44444444444444f
77f6655655566f7700f6655655566f0000000000f4f34d8f11888f4fffffffffffffffff555555555555555544f4444ffffffffff4444f44f44444444444444f
77ff66555566ff7700ff66555566ff0000000000f4f34d8f11eeef4ff55555555555555fffffffffffffffff44ffffff44444444ffffff44f44444444444444f
77f4f666666f4f7700f4f666666f4f0000000000f4ffffffffffff4ff55555555555555f6666666ff666666644f4444f44444444f4444f44f44444444444444f
77f44ffffff44f7700f44ffffff44f0000000000f44444444444444fffffffffffffffff6666666ff6666666444ffff4444444444ffff444f44444444444444f
7ffffffffffffff77ffffffffffffff700000000f4ffffffffffff4fffffffffffffffff66666f6ff6f66666000000000000000000000000f4444444444ff44f
f44444444444444ff44444444444444f00000000f4f4444444444f4ff56666666666665f66666f6ff6f66666000000000000000000000000f4444444444ff44f
7f44444444444ff70f44444444444ff000000000f4f44aaaaaa44f4ff56666666666665f6666666ff6666666000000000000000000000000f44444444444444f
77ff444444444f7700ff444444444f0000000000f4f4444444444f4ff56666666666665f6666666ff6666666000000000000000000000000f44444444444444f
777ffffffffff777000ffffffffff00000000000f4ffffffffffff4ff55555555555555fffffffffffffffff000000000000000000000000f44444444444444f
777f44444444f777000f44444444f00000000000f44444444444444fffffffffffffffff5555555555555555000000000000000000000000f44444444444444f
777f4f4f4f4ff777000f4f4f4f4ff00000000000f44444444444444ff666666ff666666f5555555555555555000000000000000000000000f44444444444444f
777ff4f4f4f4f777000ff4f4f4f4f00000000000f4ffffffffffff4ff666666ff666666fffffffffffffffff000000000000000000000000f44444444444444f
444f4f4f4f4ff444000f4f4f4f4ff00000000000f4f4444444444f4ff6666f6ff6f6666f6ffffffffffffff6000000000000000000000000f44444444444444f
444ff4f4f4f4f444000ff4f4f4f4f00000000000f4f44aaaaaa44f4ff6666f6ff6f6666ff44444444444444f000000000000000000000000f44444444444444f
444f4f4f4f4ff444000f4f4f4f4ff00000000000f4f4444444444f4ff666666ff666666ff4ffffffffffff4f000000000000000000000000f44444444444444f
444ff4f4f4f4f444000ff4f4f4f4f00000000000f4ffffffffffff4ff666666ff666666ff4f5555555555f4f000000000000000000000000f44444444444444f
44f4444444444f4400f4444444444f0000000000f44444444444444ffffffffffffffffff4f5a5a555aa5f4f000000000000000000000000f44444444444444f
4ff4444444444ff40ff4444444444ff000000000f44444444444444ff55555555555555ff4f5aaaaaaaa5f4f000000000000000000000000f44444444444444f
f44444444444444ff44444444444444f00000000f44444444444444ff55555555555555ff4ffffffffffff4f000000000000000000000000f44444444444444f
4ffffffffffffff40ffffffffffffff0000000004ffffffffffffff4fffffffffffffffff4f4cd4bfd44bf4f000000000000000000000000ffffffffffffffff
__label__
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
00000000000000000000000000000000000007700000000000007000000000000000000070700000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000070707700777000007000077007707770000070707770077077707770000000000000000000000000000000000000
00000000000000000000000000000000000070707070770000007000707070000700000070700700700007000700000000000000000000000000000000000000
00000000000000000000000000000000000070707070700000007000777000700700000077700700007007000700000000000000000000000000000000000000
00000000000000000000000000000000000077007070077000007770707077000700000007007770770077700700000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000ffffff0000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000f444444f000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000f44444444f00000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000ff4444444444ff000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000f4444ffffff4444f00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000f444f666666f444f00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000fff66555566fff000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000f6655556566f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000f6655565566f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000f6655655566f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000f6655555566f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000f6655655566f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000ff66555566ff0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000f4f666666f4f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000f44ffffff44f0000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000007ffffffffffffff700000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000f44444444444444f00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000f44444444444ff000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000ff444444444f0000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000ffffffffff00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000f44444444f00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000f4f4f4f4ff00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000ff4f4f4f4f00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000f4f4f4f4ff00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000ff4f4f4f4f00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000f4f4f4f4ff00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000ff4f4f4f4f00000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000f4444444444f0000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000ff4444444444ff000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000f44444444444444f00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000ffffffffffffff000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000181000000000000000000000000000001000000000000000000000000000000020000000000000000030101020103030300000000000101000101010101010100010101010101010101010101010101010101010000000101010101010100000001010100000001010101010101020202
0101010101010101010101010001010101010101010101010101010100010101000000000000000000000000000000010000010101000000000000000000000001010101000101010101010101010101010101010001010101010101010101010101010100010101010101000000010101010101000101010101010000000101
__map__
000000003a3b3b3b3b3b3b3b3b3b3b3b3c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a3b3b3b3b3b3b3b3b3b3b3b3c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000391f1f1f1f1f1f1f1f1f1f1f39000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000391f1f1f1f1f1f1f1f1f1f1f390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000391f1f1f1f1f1f1f1f1f1f1f39000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000391f1f1f1f1f1f1f1f1f1f1f390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000391f1f1f1f1f1f1f1f1f1f1f393b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3c0000000000000000000000000000000000000000000000391f1f1f1f1f1f1f1f1f1f1f39adadadadad3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3c00000000000000000000000000000000000000000000000000
00000000394646464646464646464646391f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f390000000000000000000000000000000000000000000000394646464646464646464646391f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f3900000000000000000000000000000000000000000000000000
00000000394646464646464646464646391f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f390000000000000000000000000000000000000000000000398c8d4a4b4c8e8f46606162391f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f3900000000000000000000000000000000000000000000000000
00000000394444444444444444444444391f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f390000000000000000000000000000000000000000000000399c9d5a5b5c9e9f44707172391f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f3900000000000000000000000000000000000000000000000000
00000000394444444444444444444444394747474747474747474747474747474747474747474747473900000000000000000000000000000000000000000000003944446a6b6c444444444444394747474747474747474747474747474747474747474747473900000000000000000000000000000000000000000000000000
00000000394444444444444444444444394747478485868747474747474747474747474747474747473900000000000000000000000000000000000000000000003944447a7b7c444444444444394747478081828347474747474747474747474747474747473900000000000000000000000000000000000000000000000000
0000000039444444444444444444444439474747949596974747474747474747474747474747474747390000000000000000000000000000000000000000000000394444444444444444444444394747479091929347474747474747474747474747474747473900000000000000000000000000000000000000000000000000
00000000394444444444444444444444394747474747474747474747474747afbfbf477e3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3c0000000000000000000000394444444444444444444444394747474747474747474747474747afbfbf473a3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3c00000000000000000000000000
000000003d3b3b3b3b3b3b3b3c44443a3e4747474747474747474747474747bfafbf477d2f2f2f2f2f1f54542f2f2f2f2f2f2f2f2f3900000000000000000000003d3b3b3b3b3b3b3b3c44443a3e4747474747474747474747474747bfafbf47392f2f2f2f2f1f1f1f2f2f2f2f2f2f2f2f2f3900000000000000000000000000
3a3b3b3b0f3b3b3b3b3b3b3b3e44443d0f3b3b3b7f47474747474747474747afbfbf477d2f2f2f2f2f1f54542f2f2f2f2f2f2f2f2f39000000000000003a3b3b3b0f3b3b3b3b3b3b3b3e44443d0f3b3b3b7f47474747474747474747afbfbf47392f2f2f2f2f1f1f1f2f2f2f2f2f2f2f2f2f3900000000000000000000000000
391f1f1f1f1f1f1f1f1f1f1f1f44441f1f2f2f2f7d47474747474747474747bfafbf47391f1f1f1f1f1f54541f1f1f1f1f1f1f1f1f3900000000000000391f1f1f1f1f1f1f1f1f1f1f1f44441f1f2f2f2f7d47474747474747474747bfafbf47391f48491f1f1f1f1f1f1f1f1f1f1f1f1f1f3900000000000000000000000000
391f2f2f2f2f2f2f2f2f2f2f1f44441f1f2f2f2f7d474747474747474747474747474739464646464646545446464646c9ca4646463900000000000000391f2f2f2f2f2f2f2f2f2f2f1fcecf1f1f2f2f2f7d474747474747474747474747474739465859464646464646464646c9ca4646463900000000000000000000000000
391f1f1f1f1f1f1f1f1f1f1f1f44441f1f1f1f1f3d3b3b3b3b3b3b3b47473b3b3b3b3b3e46464646464654544646c7c8d9dae7e8463900000000000000391f1f1f1f1f1f1f1ff9fa1f1fdedf1f1f1f1f1f3d3b3b3b3b3b3b3b47473b3b3b3b3b3e46686946464646464646c7c8d9dae7e8463900000000000000000000000000
39464646464646464646464646444446464646461f2f2f2f2f2f2f2f47472f2f2f2f2f1f44444444444444444444d7d8e9eaf7f8443900000000000000394646464646464646d5d64646eeef46464646461f2f2f2f2f2f2f2f47472f2f2f2f2f1f44787944444444444444d7d8e9eaf7f8443900000000000000000000000000
39464646464646464646464646444446464646461f2f2f2f2f2f2f2fcecf2f2f2f2f2f1f44444444444444444444444444444444443900000000000000394646cbcccd464646e5e64646feff46464646461f2f2f2f2f2f2f2fcecf2f2f2f2f2f1f44444444444444444444444444444444443900000000000000000000000000
39444444444444444444444444444444444444441f1f1fc0c11f1f1fdedf1f1f1f1f1f1f44444444444444444444444444444444443900000000000000394444dbdcdd444444f5f64444444444444444441f1f1fc0c11f1f1fdedf1f1f1f1f1f1f44444444444444444444444444444444443900000000000000000000000000
3944444444444444444444444444444444444444464646d0d1464646eeef464646464646444444444444444444444444444444444439000000000000003944444444444444444444444444444444444444464646d0d1464646eeef46464646464544444444444444444444444444444444443900000000000000000000000000
3944444444444444444444444444444444444444464646e0e1464646feff464646464646444444444444444444444444444444444439000000000000003944444444444444444444444444444444444444464646e0e1464646feff46464646465544444444444444444444444444444444443900000000000000000000000000
3944444444444444444444444444444444444444444444f0f1444444444444444444444444444444444444444444444444444444443900000000000000394d4e5657444444444444444444444444444444444444f0f1444444444444444444444444444444444444444444444444444444443900000000000000000000000000
39444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443900000000000000395d5e666744444444444444444444444444444444444444444444444444444444444444444444444444444488898a8b44444444443900000000000000000000000000
39444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443900000000000000396d6e767744444444444444444444444444444444444444444444444444444444444444444444444444444498999a9b44444444443900000000000000000000000000
3944444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444390000000000000039444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443900000000000000000000000000
3d3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b7f4444447e3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3e000000000000003d3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b7f4444447e3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3e00000000000000000000000000
1f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f7d4444447d2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f000000000000001f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f7d4444447d2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f00000000000000000000000000
1f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f7d4444447d2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f000000000000001f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f7d4444447d2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f00000000000000000000000000
1f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f7d4444447d2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f000000000000001f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f7d4444447d2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f00000000000000000000000000
4646464646464646464646464646464646464646464646394444443946464646464646464646464646464646464646464646464646460000000000000046464646464646464646464646464646464646464646463944444439464646464646464646464646464646464646464646464646464600000000000000000000000000
4646464646464646464646464646464646464646464646394444443946464646464646464646464646464646464646464646464646460000000000000046464646464646464646464646464646464646464646463944444439464646464646464646464646464646464646464646464646464600000000000000000000000000
0000000000000000000000000000000000000000000000395f5f5f390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000395f5f5f39000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
491800200c0331b300276151b300246151b3000c0003f4000c0331b300276161b30024615246003f3003f2000c0331b300276151b300246151b300246003f2000c0331b300276161b300246153f7001b3000c000
00140020021000210002140020200e11502040021200e01002140020200e11002045021200e010021400e01502140020200e01002145020200e11002040021200e01002040021250e110020400e110021450e010
011400201b754187501b7521d55427552295502e754297521f7521b7501b554185501b7541f7501f7502455229754277541b750185521d7541f550227521f5501f5501f7501b7501855016750187541d7501f754
001400000a750057500a15003750057500c7500a7500515007750057500f15003750111500075003750077500c1500a7500a75007750057501315003750007500075005150057500c75005750037500715000750
010900000005000050030500305003050050500505007050070500a0500a0500c0500c0500f0500f0501105011050130501305016050160501805018050000000000000000000000000000000000000000000000
011400000005200052000520005200052000520005200052000520005200052000520005200052000520005208052080520805208052080520805208052080520805208052080520805208052080520805208052
6f1800201802418022180221802222020220202202122022200222002220022200221f0201f0201f0251f0001802418022180221802222020220202402022020200222002220022200221f0201f0201f0251f000
011800000071700727007370071700727007370071700727007370071700727007370071700727007370073700717007270071700727007170072700717007270071700727007170072700717007270071700727
501e00200000000021110240c0200a0200a0200a02500000000001802424024220201f0201d0221d02200000160001600016024160201b0201302013020130002400024000240242402022022220222400022000
491e00000c0230c023276001b300246151b3000c0003f4000c0231b300276161b30024615246003f3003f2000c0001b3000c0231b300246151b300246003f2000c0231b300276161b300246153f7001b3000c000
011200200c0230c000276001b3002461524600246153f4000c0231b3001b3000c02324615246153f3003f2000c0233f0000c0231b300246151b300246151b3000c0231b300276001b300246153f5000c02324615
511200200a0400a0400f0440f0420f0420f0420f0450f000130400f0400c0400f0401104416042180421804213040110400c0440c0420c0420c0420c0450f0001104413040180401604013044110420f0420f042
551200202b5202e52000500305202e5202752227522005000050000500305200050033520005000050000500335202e5203052235522005000050000500305202b520005002e520005002e5202b5222b52229500
0010000004630056350760006600086000a60008600086000a6000c60000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
001000000050030550375500050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
001000000c03300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000761105610026100261002615036000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
03 00010243
03 00060744
03 08094344
03 0a0b0c44

